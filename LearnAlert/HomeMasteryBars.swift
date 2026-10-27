import SwiftUI

struct HomeMasteryBars: View {
    let summary: DeckLibrarySummary
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            bar("Mastered", count: summary.masteredCount, light: "#44856C", dark: "#9BD5B3")
            bar("Learning", count: summary.learningCount, light: "#8060B4", dark: "#B9A2E0")
            bar("Need to learn", count: summary.needToLearnCount, light: "#AA6945", dark: "#E6B298")
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(summary.masteredCount) mastered, \(summary.learningCount) learning, \(summary.needToLearnCount) need to learn")
        .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: summary)
    }

    private func bar(_ label: String, count: Int, light: String, dark: String) -> some View {
        let tint = Color(hex: colorScheme == .dark ? dark : light)
        let fraction = CGFloat(count) / CGFloat(max(1, summary.cardCount))
        return VStack(spacing: 3) {
            Text(count.formatted()).font(.caption2.weight(.semibold)).monospacedDigit()
                .foregroundStyle(LearnAlertStyle.textPrimary)
            UnevenRoundedRectangle(topLeadingRadius: 7, topTrailingRadius: 7)
                .fill(tint.opacity(colorScheme == .dark ? 0.9 : 0.75))
                .frame(width: 19, height: 30 * fraction)
                .frame(height: 30, alignment: .bottom)
                .overlay(alignment: .bottom) { Rectangle().fill(tint.opacity(0.2)).frame(height: 1) }
            Text(label).font(.caption2).foregroundStyle(LearnAlertStyle.textSecondary)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }
}
