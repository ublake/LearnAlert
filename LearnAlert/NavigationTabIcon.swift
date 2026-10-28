import SwiftUI

/// Keep Apple's symbol shapes and animate only when a destination becomes selected.
struct NavigationTabIcon: View {
    let tab: Int
    let outlineSymbol: String
    let selectedSymbol: String
    let isSelected: Bool
    let size: CGFloat
    var weight: Font.Weight = .semibold
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectionPulse = 0

    private var symbol: some View {
        Image(systemName: isSelected ? selectedSymbol : outlineSymbol)
            .symbolRenderingMode(.monochrome)
            .font(.system(size: size, weight: weight))
            .foregroundStyle(isSelected ? LearnAlertStyle.appAccentForeground : LearnAlertStyle.textSecondary)
    }

    var body: some View {
        Group {
            if reduceMotion {
                symbol
            } else {
                symbol
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.bounce.up.byLayer, options: .nonRepeating.speed(1.3),
                                  value: tab == 0 ? selectionPulse : 0)
                    .symbolEffect(.wiggle.custom(angle: 8).byLayer, options: .nonRepeating.speed(1.3),
                                  value: tab == 1 ? selectionPulse : 0)
                    .symbolEffect(.wiggle.right.byLayer, options: .nonRepeating.speed(1.4),
                                  value: tab == 2 ? selectionPulse : 0)
                    .symbolEffect(.rotate.clockwise, options: .nonRepeating.speed(1.5),
                                  value: tab == 3 ? selectionPulse : 0)
            }
        }
        .frame(width: size * 1.28, height: size * 1.12)
        .onChange(of: isSelected) { _, selected in
            if selected && !reduceMotion { selectionPulse += 1 }
        }
        .accessibilityHidden(true)
    }
}
