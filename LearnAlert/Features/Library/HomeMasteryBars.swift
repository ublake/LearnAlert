import SwiftUI

struct HomeMasteryBars: View {
    let summary: DeckLibrarySummary
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            let widths = segmentWidths(in: geometry.size.width)
            HStack(spacing: 0) {
                segment("rectangle.stack.fill", width: widths[0], light: "#8192B0", dark: "#ADC0DE",
                        lightInk: "#435477", darkInk: "#D3E0F8")
                segment("clock.badge.exclamationmark", width: widths[1], light: "#8745EE", dark: "#B07AFF",
                        lightInk: "#6330AD", darkInk: "#DBC2FF")
                segment("checkmark.seal.fill", width: widths[2], light: "#12B981", dark: "#42E8A3",
                        lightInk: "#18785C", darkInk: "#A1F2CE")
            }
        }
        .frame(height: 18)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(summary.masteredCount) mastered, \(summary.learningCount) learning, \(summary.needToLearnCount) need to learn")
        .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: summary)
    }

    private func segment(_ icon: String, width: CGFloat, light: String, dark: String,
                         lightInk: String, darkInk: String) -> some View {
        let tint = Color(hex: colorScheme == .dark ? dark : light)
        return Rectangle()
            .fill(tint.opacity(colorScheme == .dark ? 0.40 : 0.34))
            .frame(width: width, height: 18)
            .overlay {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(hex: colorScheme == .dark ? darkInk : lightInk))
                    .accessibilityHidden(true)
            }
    }

    /// Keep icons visible, then distribute the remaining space proportionally.
    private func segmentWidths(in width: CGFloat) -> [CGFloat] {
        let width = max(0, width)
        let minimums: [CGFloat] = [26, 26, 26]
        let minimumTotal = minimums.reduce(0, +)
        guard width > minimumTotal else {
            return minimums.map { $0 * width / minimumTotal }
        }

        var weights = [summary.needToLearnCount, summary.learningCount, summary.masteredCount].map { CGFloat(max(0, $0)) }
        if weights.reduce(0, +) == 0 { weights[0] = 1 }
        var sizes = [CGFloat](repeating: 0, count: 3)
        var remaining = [0, 1, 2]
        var available = width
        while !remaining.isEmpty {
            let total = remaining.reduce(CGFloat.zero) { $0 + weights[$1] }
            let proposed = remaining.map { total > 0 ? available * weights[$0] / total : available / CGFloat(remaining.count) }
            let small = remaining.indices.filter { proposed[$0] < minimums[remaining[$0]] }
            if small.isEmpty {
                for (position, index) in remaining.enumerated() { sizes[index] = proposed[position] }
                break
            }
            let clamped = small.map { remaining[$0] }
            for index in clamped {
                sizes[index] = minimums[index]
                available -= minimums[index]
            }
            remaining.removeAll { clamped.contains($0) }
        }
        return sizes
    }
}
