import SwiftUI

struct HomeMasteryBars: View {
    let summary: DeckLibrarySummary
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            // Leave the trailing alert button its own hit area on narrow tiles.
            let columnWidth = min(32, max(0, (geometry.size.width - 43) / 3))
            HStack(alignment: .bottom, spacing: 0) {
                bar("checkmark.seal.fill", count: summary.masteredCount, width: columnWidth, light: "#44856C", dark: "#9BD5B3")
                bar("clock.badge.exclamationmark", count: summary.learningCount, width: columnWidth, light: "#8060B4", dark: "#B9A2E0")
                bar("rectangle.stack.fill", count: summary.needToLearnCount, width: columnWidth, light: "#AA6945", dark: "#E6B298")
            }
            .frame(height: 62, alignment: .bottom)
        }
        .frame(height: 62)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(summary.masteredCount) mastered, \(summary.learningCount) learning, \(summary.needToLearnCount) need to learn")
        .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: summary)
    }

    private func bar(_ icon: String, count: Int, width: CGFloat, light: String, dark: String) -> some View {
        let tint = Color(hex: colorScheme == .dark ? dark : light)
        let fraction = CGFloat(count) / CGFloat(max(1, summary.cardCount))
        return VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .frame(height: 16)
                .accessibilityHidden(true)
            UnevenRoundedRectangle(topLeadingRadius: 9, topTrailingRadius: 9)
                .fill(tint.opacity(colorScheme == .dark ? 0.9 : 0.75))
                .frame(height: 42 * fraction)
        }
        .frame(width: width)
    }
}
