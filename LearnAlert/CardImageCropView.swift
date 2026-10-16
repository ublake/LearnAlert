import SwiftUI
import UIKit
import ImageIO

enum CardImageCropPreset: String, CaseIterable, Identifiable {
    case horizontal, vertical

    var id: String { rawValue }
    var title: String { self == .horizontal ? "Horizontal" : "Vertical" }
    var aspectRatio: CGFloat { self == .horizontal ? 3 / 2 : 2 / 3 }

    func fittedSize(in available: CGSize) -> CGSize {
        let width = max(1, min(available.width, available.height * aspectRatio))
        return CGSize(width: width, height: width / aspectRatio)
    }
}

/// All positions are measured from the center of a fixed crop window. Keeping the
/// same transform for the preview and renderer prevents a different saved crop.
struct CardImageCropGeometry {
    static let maximumZoom: CGFloat = 4

    let imageSize: CGSize
    let cropSize: CGSize
    let zoom: CGFloat
    let offset: CGSize

    init(imageSize: CGSize, cropSize: CGSize, zoom: CGFloat = 1, offset: CGSize = .zero) {
        self.imageSize = CGSize(width: Self.validDimension(imageSize.width), height: Self.validDimension(imageSize.height))
        self.cropSize = CGSize(width: Self.validDimension(cropSize.width), height: Self.validDimension(cropSize.height))
        self.zoom = zoom.isFinite ? min(Self.maximumZoom, max(1, zoom)) : 1
        let scale = max(self.cropSize.width / self.imageSize.width, self.cropSize.height / self.imageSize.height) * self.zoom
        let limitX = max(0, (self.imageSize.width * scale - self.cropSize.width) / 2)
        let limitY = max(0, (self.imageSize.height * scale - self.cropSize.height) / 2)
        self.offset = CGSize(
            width: offset.width.isFinite ? min(limitX, max(-limitX, offset.width)) : 0,
            height: offset.height.isFinite ? min(limitY, max(-limitY, offset.height)) : 0
        )
    }

    var scale: CGFloat { max(cropSize.width / imageSize.width, cropSize.height / imageSize.height) * zoom }
    var displayedImageSize: CGSize { CGSize(width: imageSize.width * scale, height: imageSize.height * scale) }

    var sourceRect: CGRect {
        let width = min(imageSize.width, cropSize.width / scale)
        let height = min(imageSize.height, cropSize.height / scale)
        let x = min(imageSize.width - width, max(0, (imageSize.width - width) / 2 - offset.width / scale))
        let y = min(imageSize.height - height, max(0, (imageSize.height - height) / 2 - offset.height / scale))
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private static func validDimension(_ value: CGFloat) -> CGFloat {
        value.isFinite && value > 0 ? value : 1
    }
}

enum CardImageCropRenderer {
    /// Downsamples before decoding a library photo, including its EXIF rotation.
    /// Call this directly after PhotosPicker loads Data to avoid decoding a huge
    /// original image just to show a small editing preview.
    static func preparedImage(from data: Data, maximumPixelDimension: Int = 2400) -> UIImage? {
        guard maximumPixelDimension > 0,
              let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maximumPixelDimension,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { return nil }
        return UIImage(cgImage: image)
    }

    static func preparedImage(_ image: UIImage, maximumPixelDimension: Int = 2400) -> UIImage {
        let pixels: CGSize
        if let cgImage = image.cgImage {
            let rotated = [.left, .leftMirrored, .right, .rightMirrored].contains(image.imageOrientation)
            pixels = CGSize(width: rotated ? cgImage.height : cgImage.width,
                            height: rotated ? cgImage.width : cgImage.height)
        } else {
            pixels = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        }
        let limit = CGFloat(max(1, maximumPixelDimension))
        if image.imageOrientation == .up, image.scale == 1,
           max(pixels.width, pixels.height) <= limit { return image }
        let ratio = min(1, limit / max(1, max(pixels.width, pixels.height)))
        let size = CGSize(width: max(1, floor(pixels.width * ratio)), height: max(1, floor(pixels.height * ratio)))
        return renderer(size: size).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
    }

    /// Returns upright pixels only. This does not write to CardImageStore; the
    /// caller persists the confirmed image using the existing card-save flow.
    static func croppedImage(_ image: UIImage, geometry: CardImageCropGeometry, maximumPixelDimension: Int = 1200) -> UIImage? {
        guard maximumPixelDimension > 0,
              abs(image.size.width - geometry.imageSize.width) < 0.5,
              abs(image.size.height - geometry.imageSize.height) < 0.5 else { return nil }
        let rect = geometry.sourceRect
        let ratio = min(1, CGFloat(maximumPixelDimension) / max(rect.width, rect.height))
        let size = CGSize(width: max(1, floor(rect.width * ratio)), height: max(1, floor(rect.height * ratio)))
        let scaleX = size.width / rect.width
        let scaleY = size.height / rect.height
        return renderer(size: size).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            image.draw(in: CGRect(x: -rect.minX * scaleX, y: -rect.minY * scaleY,
                                  width: image.size.width * scaleX, height: image.size.height * scaleY))
        }
    }

    private static func renderer(size: CGSize) -> UIGraphicsImageRenderer {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format)
    }
}

/// Presents a fixed crop window over a movable image. No files are created until
/// the caller receives and saves the confirmed image.
struct CardImageCropView: View {
    private let image: UIImage
    let onCancel: () -> Void
    let onConfirm: (UIImage) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var preset: CardImageCropPreset = .horizontal
    @State private var zoom: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var canvasSize: CGSize = .zero
    @State private var cropFailed = false
    @GestureState private var interaction = CropInteraction()

    init(image: UIImage, onCancel: @escaping () -> Void, onConfirm: @escaping (UIImage) -> Void) {
        self.image = CardImageCropRenderer.preparedImage(image)
        self.onCancel = onCancel
        self.onConfirm = onConfirm
    }

    private var cropSize: CGSize { preset.fittedSize(in: CGSize(width: max(1, canvasSize.width - 32), height: max(1, canvasSize.height - 32))) }
    private var geometry: CardImageCropGeometry { transform(cropSize: cropSize, interaction: interaction) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                HStack(spacing: 10) {
                    ForEach(CardImageCropPreset.allCases) { option in
                        Button {
                            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                                preset = option
                                reset()
                            }
                        } label: {
                            HStack(spacing: 9) {
                                RoundedRectangle(cornerRadius: 3).stroke(lineWidth: 1.7)
                                    .frame(width: option == .horizontal ? 25 : 17, height: option == .horizontal ? 17 : 25)
                                    .frame(width: 26, height: 26)
                                Text(option.title).font(.subheadline.weight(.semibold))
                            }
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .foregroundStyle(preset == option ? LearnAlertStyle.appAccentInk : LearnAlertStyle.textPrimary)
                            .background(preset == option ? LearnAlertStyle.appAccent : LearnAlertStyle.insetSurface,
                                        in: RoundedRectangle(cornerRadius: 13))
                            .overlay(RoundedRectangle(cornerRadius: 13).stroke(LearnAlertStyle.cardBorder, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(option.title) crop")
                        .accessibilityAddTraits(preset == option ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 20)

                cropCanvas

                HStack(spacing: 14) {
                    Image(systemName: "minus.magnifyingglass").accessibilityHidden(true)
                    Slider(value: Binding(get: { zoom }, set: { value in
                        let relativeZoom = value / zoom
                        let next = CardImageCropGeometry(imageSize: image.size, cropSize: cropSize, zoom: value,
                                                         offset: CGSize(width: offset.width * relativeZoom, height: offset.height * relativeZoom))
                        zoom = next.zoom
                        offset = next.offset
                    }), in: 1...CardImageCropGeometry.maximumZoom)
                    .accessibilityLabel("Image zoom")
                    .accessibilityValue("\(Int(zoom * 100)) percent")
                    Button("Reset", action: reset).font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(LearnAlertStyle.textSecondary)
                .padding(.horizontal, 22)

                Button("Confirm image", action: confirm)
                    .font(.headline)
                    .foregroundStyle(LearnAlertStyle.appAccentInk)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(LearnAlertStyle.appAccent, in: RoundedRectangle(cornerRadius: 16))
                    .buttonStyle(.plain)
                    .disabled(canvasSize.width <= 0 || canvasSize.height <= 0)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }
            .padding(.top, 12)
            .background(LearnAlertStyle.courseCanvas)
            .navigationTitle("Frame image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: onCancel) } }
            .tint(LearnAlertStyle.appAccentForeground)
            .alert("Couldn’t prepare image", isPresented: $cropFailed) {
                Button("OK", role: .cancel) { }
            } message: { Text("Try adjusting the frame or choosing another image.") }
        }
    }

    private var cropCanvas: some View {
        GeometryReader { proxy in
            let window = preset.fittedSize(in: CGSize(width: max(1, proxy.size.width - 32), height: max(1, proxy.size.height - 32)))
            let layout = transform(cropSize: window, interaction: interaction)
            let frame = CGRect(x: (proxy.size.width - window.width) / 2, y: (proxy.size.height - window.height) / 2,
                               width: window.width, height: window.height)
            ZStack {
                Color.black
                Image(uiImage: image).resizable().interpolation(.high)
                    .frame(width: layout.displayedImageSize.width, height: layout.displayedImageSize.height)
                    .background(.white)
                    .position(x: proxy.size.width / 2 + layout.offset.width, y: proxy.size.height / 2 + layout.offset.height)
                Path { path in
                    path.addRect(CGRect(origin: .zero, size: proxy.size))
                    path.addRect(frame)
                }
                .fill(.black.opacity(0.6), style: FillStyle(eoFill: true))
                Rectangle().stroke(.white, lineWidth: 2)
                    .frame(width: window.width, height: window.height)
                if interaction.isActive {
                    Path { path in
                        for part in 1...2 {
                            let x = frame.minX + frame.width * CGFloat(part) / 3
                            let y = frame.minY + frame.height * CGFloat(part) / 3
                            path.move(to: CGPoint(x: x, y: frame.minY)); path.addLine(to: CGPoint(x: x, y: frame.maxY))
                            path.move(to: CGPoint(x: frame.minX, y: y)); path.addLine(to: CGPoint(x: frame.maxX, y: y))
                        }
                    }.stroke(.white.opacity(0.4), lineWidth: 1)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
            .contentShape(Rectangle())
            .gesture(cropGesture(cropSize: window))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Image crop preview")
            .accessibilityHint("Drag to move the image. Pinch or use the zoom slider to resize it.")
            .accessibilityActions {
                Button("Move image left") { move(dx: -window.width * 0.1, dy: 0) }
                Button("Move image right") { move(dx: window.width * 0.1, dy: 0) }
                Button("Move image up") { move(dx: 0, dy: -window.height * 0.1) }
                Button("Move image down") { move(dx: 0, dy: window.height * 0.1) }
                Button("Center image", action: reset)
            }
            .onAppear { canvasSize = proxy.size }
            .onChange(of: proxy.size) { _, size in
                canvasSize = size
                let next = CardImageCropGeometry(imageSize: image.size, cropSize: cropSize, zoom: zoom, offset: offset)
                offset = next.offset
            }
        }
    }

    private func cropGesture(cropSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .simultaneously(with: MagnificationGesture())
            .updating($interaction) { value, state, _ in
                state.translation = value.first?.translation ?? .zero
                state.magnification = value.second ?? 1
                state.isActive = true
            }
            .onEnded { value in
                let next = transform(cropSize: cropSize, interaction: CropInteraction(
                    translation: value.first?.translation ?? .zero,
                    magnification: value.second ?? 1, isActive: false))
                zoom = next.zoom
                offset = next.offset
            }
    }

    private func transform(cropSize: CGSize, interaction: CropInteraction) -> CardImageCropGeometry {
        let requestedZoom = zoom * interaction.magnification
        let boundedZoom = min(CardImageCropGeometry.maximumZoom, max(1, requestedZoom))
        let relativeZoom = boundedZoom / zoom
        return CardImageCropGeometry(imageSize: image.size, cropSize: cropSize, zoom: boundedZoom,
            offset: CGSize(width: offset.width * relativeZoom + interaction.translation.width,
                           height: offset.height * relativeZoom + interaction.translation.height))
    }

    private func move(dx: CGFloat, dy: CGFloat) {
        offset = CardImageCropGeometry(imageSize: image.size, cropSize: cropSize, zoom: zoom,
                                       offset: CGSize(width: offset.width + dx, height: offset.height + dy)).offset
    }

    private func reset() { zoom = 1; offset = .zero }

    private func confirm() {
        guard let cropped = CardImageCropRenderer.croppedImage(image, geometry: geometry) else { cropFailed = true; return }
        onConfirm(cropped)
    }

    private struct CropInteraction {
        var translation: CGSize = .zero
        var magnification: CGFloat = 1
        var isActive = false
    }
}
