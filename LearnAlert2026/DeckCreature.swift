import Foundation
import SwiftUI

struct DeckCreatureAppearance: Equatable, Sendable {
    struct RGB: Equatable, Sendable {
        let red: Double
        let green: Double
        let blue: Double

        var color: Color {
            Color(red: red, green: green, blue: blue)
        }
    }

    struct Palette: Equatable, Sendable {
        let front: RGB
        let middle: RGB
        let back: RGB
        let accent: RGB
        let ink: RGB
    }

    enum MouthStyle: Int, Sendable {
        case smile
        case tinySmile
        case openSmile
    }

    let palette: Palette
    let eyeSpacing: Double
    let eyeHeight: Double
    let pupilOffset: Double
    let pupilScale: Double
    let mouthStyle: MouthStyle
    let frontTilt: Double
    let layerTilts: [Double]
    let layerOffsets: [Double]
    let tabOnLeadingEdge: Bool
    let bookmarkOnLeadingEdge: Bool

    static func make(stableID: String, savedSeed: Int64?) -> Self {
        var generator = DeckCreatureGenerator(stableID: stableID, savedSeed: savedSeed)
        let palette = palettes[generator.nextInt(upperBound: palettes.count)]
        let frontTilt = generator.nextDouble(in: -1.3...1.3)
        var tilts = [frontTilt]
        var offsets = [0.0]

        for layer in 1..<8 {
            let direction = layer.isMultiple(of: 2) ? 1.0 : -1.0
            tilts.append(generator.nextDouble(in: 1.1...3.8) * direction)
            offsets.append(generator.nextDouble(in: -2.6...2.6))
        }

        return Self(
            palette: palette,
            eyeSpacing: generator.nextDouble(in: 15.5...22.0),
            eyeHeight: generator.nextDouble(in: -1.5...1.0),
            pupilOffset: generator.nextDouble(in: -1.4...1.4),
            pupilScale: generator.nextDouble(in: 0.88...1.12),
            mouthStyle: MouthStyle(rawValue: generator.nextInt(upperBound: 3)) ?? .smile,
            frontTilt: frontTilt,
            layerTilts: tilts,
            layerOffsets: offsets,
            tabOnLeadingEdge: generator.nextBool(),
            bookmarkOnLeadingEdge: generator.nextBool()
        )
    }

    static func growth(for cardCount: Int) -> Double {
        min(max(log2(Double(max(cardCount, 0)) + 1) / 8, 0), 1)
    }

    static func visibleLayerCount(for cardCount: Int) -> Int {
        min(8, 1 + Int(floor(growth(for: cardCount) * 7)))
    }

    static func newSavedSeed(excluding current: Int64?) -> Int64 {
        let value = DeckCreatureStableHash.hash(UUID().uuidString)
        let candidate = Int64(bitPattern: value == 0 ? 1 : value)
        return candidate == current ? candidate &+ 1 : candidate
    }

    private static let palettes: [Palette] = [
        Palette(front: RGB(red: 0.35, green: 0.67, blue: 0.98), middle: RGB(red: 0.67, green: 0.84, blue: 1.00), back: RGB(red: 0.86, green: 0.93, blue: 1.00), accent: RGB(red: 1.00, green: 0.72, blue: 0.29), ink: RGB(red: 0.08, green: 0.18, blue: 0.31)),
        Palette(front: RGB(red: 0.38, green: 0.78, blue: 0.65), middle: RGB(red: 0.65, green: 0.90, blue: 0.79), back: RGB(red: 0.84, green: 0.96, blue: 0.90), accent: RGB(red: 0.96, green: 0.52, blue: 0.48), ink: RGB(red: 0.07, green: 0.24, blue: 0.20)),
        Palette(front: RGB(red: 0.61, green: 0.52, blue: 0.93), middle: RGB(red: 0.78, green: 0.72, blue: 0.98), back: RGB(red: 0.91, green: 0.88, blue: 1.00), accent: RGB(red: 1.00, green: 0.76, blue: 0.35), ink: RGB(red: 0.17, green: 0.12, blue: 0.34)),
        Palette(front: RGB(red: 0.98, green: 0.56, blue: 0.49), middle: RGB(red: 1.00, green: 0.75, blue: 0.68), back: RGB(red: 1.00, green: 0.90, blue: 0.86), accent: RGB(red: 0.25, green: 0.73, blue: 0.72), ink: RGB(red: 0.34, green: 0.12, blue: 0.11)),
        Palette(front: RGB(red: 0.95, green: 0.70, blue: 0.30), middle: RGB(red: 1.00, green: 0.84, blue: 0.52), back: RGB(red: 1.00, green: 0.94, blue: 0.76), accent: RGB(red: 0.44, green: 0.51, blue: 0.91), ink: RGB(red: 0.28, green: 0.20, blue: 0.06)),
        Palette(front: RGB(red: 0.92, green: 0.47, blue: 0.67), middle: RGB(red: 0.98, green: 0.70, blue: 0.82), back: RGB(red: 1.00, green: 0.88, blue: 0.93), accent: RGB(red: 0.32, green: 0.70, blue: 0.91), ink: RGB(red: 0.31, green: 0.09, blue: 0.20)),
        Palette(front: RGB(red: 0.31, green: 0.72, blue: 0.81), middle: RGB(red: 0.59, green: 0.86, blue: 0.91), back: RGB(red: 0.82, green: 0.95, blue: 0.96), accent: RGB(red: 0.99, green: 0.62, blue: 0.33), ink: RGB(red: 0.05, green: 0.22, blue: 0.27)),
        Palette(front: RGB(red: 0.49, green: 0.61, blue: 0.91), middle: RGB(red: 0.70, green: 0.78, blue: 0.98), back: RGB(red: 0.87, green: 0.91, blue: 1.00), accent: RGB(red: 0.50, green: 0.80, blue: 0.55), ink: RGB(red: 0.10, green: 0.16, blue: 0.34))
    ]
}

private struct DeckCreatureGenerator {
    private var state: UInt64

    init(stableID: String, savedSeed: Int64?) {
        let seedText = savedSeed.map(String.init) ?? "default"
        state = DeckCreatureStableHash.hash("\(stableID)|\(seedText)")
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }

    mutating func nextInt(upperBound: Int) -> Int {
        Int(next() % UInt64(upperBound))
    }

    mutating func nextDouble(in range: ClosedRange<Double>) -> Double {
        let unit = Double(next() >> 11) / 9_007_199_254_740_992
        return range.lowerBound + unit * (range.upperBound - range.lowerBound)
    }

    mutating func nextBool() -> Bool {
        next().isMultiple(of: 2)
    }
}

private enum DeckCreatureStableHash {
    static func hash(_ text: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        return hash
    }
}

struct DeckCreatureView: View {
    let stableID: String
    let appearanceSeed: Int64?
    let cardCount: Int
    var isCelebrating = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bounceOffset: CGFloat = 0

    init(stableID: UUID, appearanceSeed: Int64?, cardCount: Int, isCelebrating: Bool = false) {
        self.init(stableID: stableID.uuidString.lowercased(), appearanceSeed: appearanceSeed, cardCount: cardCount, isCelebrating: isCelebrating)
    }

    init(stableID: String, appearanceSeed: Int64?, cardCount: Int, isCelebrating: Bool = false) {
        self.stableID = stableID
        self.appearanceSeed = appearanceSeed
        self.cardCount = max(cardCount, 0)
        self.isCelebrating = isCelebrating
    }

    private var appearance: DeckCreatureAppearance {
        DeckCreatureAppearance.make(stableID: stableID, savedSeed: appearanceSeed)
    }

    private var growth: Double {
        DeckCreatureAppearance.growth(for: cardCount)
    }

    private var visibleLayers: Int {
        DeckCreatureAppearance.visibleLayerCount(for: cardCount)
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let cardWidth = width * (0.72 + growth * 0.06)
            let cardHeight = height * (0.58 + growth * 0.08)
            let centerY = height * 0.61

            ZStack {
                creatureBackdrop

                ForEach(Array((0..<visibleLayers).reversed()), id: \.self) { layer in
                    creatureCard(layer: layer, width: cardWidth, height: cardHeight)
                        .position(
                            x: width / 2 + appearance.layerOffsets[layer],
                            y: centerY - CGFloat(layer) * 2.8
                        )
                }
            }
            .offset(y: bounceOffset)
        }
        .accessibilityHidden(true)
        .task(id: isCelebrating) {
            guard isCelebrating, !reduceMotion else { return }
            withAnimation(.spring(duration: 0.24, bounce: 0.48)) { bounceOffset = -8 }
            try? await Task.sleep(for: .milliseconds(220))
            withAnimation(.spring(duration: 0.28, bounce: 0.38)) { bounceOffset = 0 }
        }
    }

    private var creatureBackdrop: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [appearance.palette.back.color.opacity(0.82), appearance.palette.middle.color.opacity(0.28)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                Circle()
                    .fill(Color.white.opacity(0.30))
                    .frame(width: 40, height: 40)
                    .blur(radius: 9)
                    .offset(x: 25, y: -20)
            }
    }

    @ViewBuilder
    private func creatureCard(layer: Int, width: CGFloat, height: CGFloat) -> some View {
        let isFront = layer == 0
        let fill = layerColor(layer)

        ZStack {
            RoundedRectangle(cornerRadius: max(8, width * 0.12), style: .continuous)
                .fill(fill)
                .overlay {
                    RoundedRectangle(cornerRadius: max(8, width * 0.12), style: .continuous)
                        .stroke(Color.white.opacity(isFront ? 0.56 : 0.42), lineWidth: 0.8)
                }
                .shadow(color: appearance.palette.ink.color.opacity(isFront ? 0.18 : 0.10), radius: isFront ? 5 : 2, y: isFront ? 3 : 1)

            if isFront {
                frontCardDetails(width: width, height: height)
            } else {
                Capsule()
                    .fill(Color.white.opacity(0.38))
                    .frame(width: width * 0.46, height: 2)
                    .offset(y: height * 0.22)
            }
        }
        .frame(width: width, height: height)
        .rotationEffect(.degrees(appearance.layerTilts[layer]))
    }

    private func frontCardDetails(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            CardCreatureFace(appearance: appearance)
                .frame(width: width * 0.55, height: height * 0.46)
                .offset(y: -1)

            if visibleLayers >= 4 {
                Capsule()
                    .fill(appearance.palette.accent.color)
                    .frame(width: 17, height: 7)
                    .offset(
                        x: appearance.tabOnLeadingEdge ? -width * 0.31 : width * 0.31,
                        y: -height * 0.46
                    )
            }

            if visibleLayers >= 7 {
                BookmarkShape()
                    .fill(appearance.palette.accent.color)
                    .frame(width: 9, height: 21)
                    .offset(
                        x: appearance.bookmarkOnLeadingEdge ? -width * 0.39 : width * 0.39,
                        y: -height * 0.20
                    )
            }

            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { _ in
                    Capsule()
                        .fill(Color.white.opacity(0.32))
                        .frame(width: width * 0.13, height: 1.5)
                }
            }
            .offset(y: height * 0.32)
        }
    }

    private func layerColor(_ layer: Int) -> Color {
        if layer == 0 { return appearance.palette.front.color }
        if layer.isMultiple(of: 2) { return appearance.palette.back.color }
        return appearance.palette.middle.color
    }
}

private struct CardCreatureFace: View {
    let appearance: DeckCreatureAppearance

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: appearance.eyeSpacing) {
                eye
                eye
            }
            .offset(y: appearance.eyeHeight)

            mouth
                .frame(width: mouthWidth, height: 7)
        }
    }

    private var eye: some View {
        ZStack {
            Capsule()
                .fill(Color.white.opacity(0.94))
                .frame(width: 13, height: 16)
            Circle()
                .fill(appearance.palette.ink.color)
                .frame(width: 6.2 * appearance.pupilScale, height: 6.2 * appearance.pupilScale)
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(Color.white.opacity(0.92))
                        .frame(width: 2.1, height: 2.1)
                }
                .offset(x: appearance.pupilOffset, y: 1)
        }
    }

    @ViewBuilder
    private var mouth: some View {
        switch appearance.mouthStyle {
        case .smile, .tinySmile:
            SmileShape()
                .stroke(appearance.palette.ink.color, style: StrokeStyle(lineWidth: 2, lineCap: .round))
        case .openSmile:
            Capsule()
                .fill(appearance.palette.ink.color)
                .overlay(alignment: .bottom) {
                    Capsule()
                        .fill(appearance.palette.accent.color)
                        .frame(height: 2.5)
                        .padding(.horizontal, 2)
                        .padding(.bottom, 1)
                }
        }
    }

    private var mouthWidth: CGFloat {
        appearance.mouthStyle == .tinySmile ? 9 : 14
    }
}

private struct SmileShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.25))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.25),
            control: CGPoint(x: rect.midX, y: rect.maxY)
        )
        return path
    }
}

private struct BookmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: rect.origin)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - rect.width * 0.38))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct DeckCreaturePreviewGallery: View {
    private let counts = [0, 1, 10, 30, 75, 150, 500]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 132))], spacing: 14) {
                ForEach(counts, id: \.self) { count in
                    VStack(spacing: 8) {
                        DeckCreatureView(
                            stableID: "preview-deck-\(count)",
                            appearanceSeed: nil,
                            cardCount: count
                        )
                        .frame(width: 104, height: 94)
                        Text("\(count) cards · \(DeckCreatureAppearance.visibleLayerCount(for: count)) layers")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
            .padding()
        }
        .background(LearnAlertStyle.courseCanvas)
    }
}

#Preview("Creature Growth · Light") {
    DeckCreaturePreviewGallery()
        .preferredColorScheme(.light)
}

#Preview("Creature Growth · Dark") {
    DeckCreaturePreviewGallery()
        .preferredColorScheme(.dark)
}
