import SwiftUI
import UIKit

/// The learning-card palette shared by Discover and the notification studio.
enum StudyStudioStyle {
    static let violet = Color(hex: "#6961F5")
    static let blue = Color(hex: "#4868F8")
    static let rose = Color(hex: "#C65488")
    static let teal = Color(hex: "#237C76")
    static let mint = Color(hex: "#67DFA9")
    static let canvas = Color.adaptive(light: .white, dark: UIColor(red: 0.10, green: 0.12, blue: 0.19, alpha: 1))
    static let field = Color.adaptive(light: UIColor(red: 0.945, green: 0.950, blue: 0.974, alpha: 1), dark: UIColor(red: 0.16, green: 0.18, blue: 0.27, alpha: 1))
    static let ink = Color.adaptive(light: UIColor(red: 0.32, green: 0.37, blue: 0.50, alpha: 1), dark: UIColor(red: 0.91, green: 0.93, blue: 0.99, alpha: 1))
    static let secondary = Color.adaptive(light: UIColor(red: 0.43, green: 0.48, blue: 0.61, alpha: 1), dark: UIColor(red: 0.67, green: 0.71, blue: 0.82, alpha: 1))
    static let hairline = secondary.opacity(0.18)

    static func title(_ size: CGFloat = 28) -> Font { .custom("Poppins-SemiBold", size: size, relativeTo: .title) }
    static func heading(_ size: CGFloat = 18) -> Font { .custom("Poppins-SemiBold", size: size, relativeTo: .headline) }
    static func body(_ size: CGFloat = 14) -> Font { .custom("Poppins-Regular", size: size, relativeTo: .body) }
}

/// Compact 2-column category grid tile for the Discover hub
struct DiscoverCategoryTile: View {
    let title: String
    let subtitle: String
    let badge: String
    let symbol: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button {
            HapticFeedback.impact(.light)
            InteractionSoundPlayer.shared.play(.click)
            action()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center) {
                    Image(systemName: symbol)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                    Spacer(minLength: 4)

                    Text(badge)
                        .font(StudyStudioStyle.heading(10))
                        .foregroundStyle(.white.opacity(0.92))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3.5)
                        .background(.white.opacity(0.16), in: Capsule())
                        .lineLimit(1)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(StudyStudioStyle.heading(15))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Text(subtitle)
                        .font(StudyStudioStyle.body(11))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                HStack(spacing: 4) {
                    Text("Explore")
                        .font(StudyStudioStyle.heading(11))
                    Image(systemName: "arrow.forward")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(.white.opacity(0.9))
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 135, alignment: .topLeading)
            .background(color, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: color.opacity(0.22), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(badge), \(subtitle)")
        .accessibilityHint("Opens \(title)")
    }
}

struct StudyDestinationCard: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    let badge: String
    var symbol: String? = nil
    let color: Color
    var actionTitle = "Explore"
    let action: () -> Void

    var body: some View {
        Button {
            HapticFeedback.impact(.light)
            InteractionSoundPlayer.shared.play(.click)
            action()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center) {
                    Text(eyebrow)
                        .font(StudyStudioStyle.heading(10))
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.82))
                    Spacer()
                    Text(badge)
                        .font(StudyStudioStyle.heading(11))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.18), in: Capsule())
                }
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(StudyStudioStyle.title(18))
                            .lineLimit(1)
                        Text(subtitle)
                            .font(StudyStudioStyle.body(12))
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 6) {
                        Text(actionTitle)
                            .font(StudyStudioStyle.heading(12))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(color)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.white, in: Capsule())
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color, in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}
