import Foundation
import Testing
import UIKit
import ImageIO
@testable import LearnAlert

@Suite("Card image cropping")
@MainActor
struct CardImageCropTests {
    @Test("Crop presets keep their fixed landscape or portrait aspect")
    func presetSizes() {
        let horizontal = CardImageCropPreset.horizontal.fittedSize(in: CGSize(width: 330, height: 500))
        let vertical = CardImageCropPreset.vertical.fittedSize(in: CGSize(width: 330, height: 400))
        #expect(horizontal == CGSize(width: 330, height: 220))
        #expect(abs(vertical.width - 800 / 3) < 0.001)
        #expect(abs(vertical.height - 400) < 0.001)
        #expect(abs(horizontal.width / horizontal.height - 1.5) < 0.001)
        #expect(abs(vertical.width / vertical.height - 2 / 3) < 0.001)
    }

    @Test("Initial frame fills and centers images with different orientations")
    func centeredAspectFill() {
        let landscape = CardImageCropGeometry(imageSize: CGSize(width: 600, height: 400), cropSize: CGSize(width: 200, height: 300))
        #expect(landscape.scale == 0.75)
        #expect(landscape.sourceRect.minY == 0)
        #expect(abs(landscape.sourceRect.minX - 500 / 3) < 0.001)
        let portrait = CardImageCropGeometry(imageSize: CGSize(width: 400, height: 600), cropSize: CGSize(width: 300, height: 200))
        #expect(portrait.sourceRect.minX == 0)
        #expect(abs(portrait.sourceRect.minY - 500 / 3) < 0.001)
    }

    @Test("Zoom and pan cannot expose blank crop margins")
    func boundedTransforms() {
        for image in [CGSize(width: 300, height: 200), CGSize(width: 200, height: 300), CGSize(width: 1, height: 2000)] {
            for crop in [CGSize(width: 300, height: 200), CGSize(width: 200, height: 300)] {
                for zoom: CGFloat in [-100, 0, 1, 2, 4, 100, .nan, .infinity] {
                    for offset in [CGSize.zero, CGSize(width: 100000, height: -100000), CGSize(width: -100000, height: 100000)] {
                        let geometry = CardImageCropGeometry(imageSize: image, cropSize: crop, zoom: zoom, offset: offset)
                        let source = geometry.sourceRect
                        #expect(geometry.zoom >= 1 && geometry.zoom <= 4)
                        #expect(source.minX >= -0.001 && source.minY >= -0.001)
                        #expect(source.maxX <= image.width + 0.001 && source.maxY <= image.height + 0.001)
                        #expect(source.width > 0 && source.height > 0)
                        #expect(abs(source.width / source.height - crop.width / crop.height) < 0.001)
                    }
                }
            }
        }
        let invalid = CardImageCropGeometry(imageSize: .zero, cropSize: .zero, offset: CGSize(width: CGFloat.nan, height: CGFloat.infinity))
        #expect(invalid.offset == .zero)
        #expect(invalid.sourceRect.width.isFinite)
    }

    @Test("The confirmed crop saves the same panned region shown in the preview")
    func outputMatchesPan() throws {
        let image = splitImage()
        let left = CardImageCropGeometry(imageSize: image.size, cropSize: CGSize(width: 300, height: 200), zoom: 2,
                                        offset: CGSize(width: 150, height: 0))
        let leftImage = try #require(CardImageCropRenderer.croppedImage(image, geometry: left))
        #expect(leftImage.size == CGSize(width: 300, height: 200))
        #expect(sample(leftImage, x: 250, y: 100).red > 0.95)
        #expect(sample(leftImage, x: 250, y: 100).blue < 0.05)
        let right = CardImageCropGeometry(imageSize: image.size, cropSize: CGSize(width: 300, height: 200), zoom: 2,
                                         offset: CGSize(width: -150, height: 0))
        let rightImage = try #require(CardImageCropRenderer.croppedImage(image, geometry: right))
        #expect(sample(rightImage, x: 50, y: 100).blue > 0.95)
        #expect(sample(rightImage, x: 50, y: 100).red < 0.05)
    }

    @Test("Cropped output has bounded upright pixel dimensions regardless of display scale")
    func outputPixelLimit() throws {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 2400, height: 1600), format: format).image { context in
            UIColor.green.setFill(); context.fill(CGRect(x: 0, y: 0, width: 2400, height: 1600))
        }
        let geometry = CardImageCropGeometry(imageSize: image.size, cropSize: CGSize(width: 300, height: 200))
        let output = try #require(CardImageCropRenderer.croppedImage(image, geometry: geometry))
        #expect(output.scale == 1)
        #expect(output.imageOrientation == .up)
        #expect(output.cgImage?.width == 1200)
        #expect(output.cgImage?.height == 800)
    }

    @Test("Camera rotation and mirroring are baked into preview pixels")
    func normalizesOrientation() throws {
        let original = splitImage()
        let cgImage = try #require(original.cgImage)
        let rotated = CardImageCropRenderer.preparedImage(UIImage(cgImage: cgImage, scale: 1, orientation: .right))
        #expect(rotated.imageOrientation == .up)
        #expect(rotated.size == CGSize(width: 400, height: 600))
        #expect(sample(rotated, x: 200, y: 100).red > 0.95)
        #expect(sample(rotated, x: 200, y: 500).blue > 0.95)
        let mirrored = CardImageCropRenderer.preparedImage(UIImage(cgImage: cgImage, scale: 1, orientation: .upMirrored))
        #expect(sample(mirrored, x: 100, y: 200).blue > 0.95)
        #expect(sample(mirrored, x: 500, y: 200).red > 0.95)
    }

    @Test("Photo data is downsampled with EXIF rotation before editing")
    func preparesPhotoData() throws {
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(data, "public.jpeg" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, try #require(splitImage().cgImage), [kCGImagePropertyOrientation: 6] as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))
        let prepared = try #require(CardImageCropRenderer.preparedImage(from: data as Data, maximumPixelDimension: 120))
        #expect(prepared.imageOrientation == .up)
        #expect(prepared.cgImage?.width == 80)
        #expect(prepared.cgImage?.height == 120)
        #expect(sample(prepared, x: 40, y: 20).red > 0.9)
        #expect(sample(prepared, x: 40, y: 100).blue > 0.9)
        #expect(CardImageCropRenderer.preparedImage(from: Data("not a photo".utf8)) == nil)
    }

    private func splitImage() -> UIImage {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 600, height: 400), format: format).image { context in
            UIColor.red.setFill(); context.fill(CGRect(x: 0, y: 0, width: 300, height: 400))
            UIColor.blue.setFill(); context.fill(CGRect(x: 300, y: 0, width: 300, height: 400))
        }
    }

    private func sample(_ image: UIImage, x: Int, y: Int) -> (red: CGFloat, blue: CGFloat) {
        guard let cgImage = image.cgImage?.cropping(to: CGRect(x: x, y: y, width: 1, height: 1)) else { return (0, 0) }
        var bytes = [UInt8](repeating: 0, count: 4)
        let space = CGColorSpaceCreateDeviceRGB()
        bytes.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(data: buffer.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                          space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        return (CGFloat(bytes[0]) / 255, CGFloat(bytes[2]) / 255)
    }
}
