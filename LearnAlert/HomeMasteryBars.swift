import SwiftUI

struct HomeMasteryBars: View {
    let summary: DeckLibrarySummary
    var isPinned = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            let heights = segmentHeights(in: geometry.size.height)
            VStack(spacing: 0) {
                segment("rectangle.stack.fill", height: heights[0], light: "#758093", dark: "#A5AEBD", topInset: isPinned ? 24 : 0)
                segment("clock.badge.exclamationmark", height: heights[1], light: "#8060B4", dark: "#B9A2E0")
                segment("checkmark.seal.fill", height: heights[2], light: "#44856C", dark: "#9BD5B3")
            }
        }
        .frame(width: 32)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(summary.masteredCount) mastered, \(summary.learningCount) learning, \(summary.needToLearnCount) need to learn")
        .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: summary)
    }

    private func segment(_ icon: String, height: CGFloat, light: String, dark: String, topInset: CGFloat = 0) -> some View {
        let tint = Color(hex: colorScheme == .dark ? dark : light)
        return Rectangle()
            .fill(tint.opacity(colorScheme == .dark ? 0.9 : 0.75))
            .frame(height: height)
            .overlay {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(red: 0.10, green: 0.13, blue: 0.24))
                    .padding(.top, topInset)
                    .accessibilityHidden(true)
            }
    }

    /// Keep icons visible, then distribute the remaining space proportionally.
    /// Pinning reserves a small pocket in the grey segment for the corner pin.
    private func segmentHeights(in height: CGFloat) -> [CGFloat] {
        let height = max(0, height)
        let minimums: [CGFloat] = [isPinned ? 44 : 24, 24, 24]
        let minimumTotal = minimums.reduce(0, +)
        guard height > minimumTotal else {
            return minimums.map { $0 * height / minimumTotal }
        }

        var weights = [summary.needToLearnCount, summary.learningCount, summary.masteredCount].map { CGFloat(max(0, $0)) }
        if weights.reduce(0, +) == 0 { weights[0] = 1 }
        var sizes = [CGFloat](repeating: 0, count: 3)
        var remaining = [0, 1, 2]
        var available = height
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
