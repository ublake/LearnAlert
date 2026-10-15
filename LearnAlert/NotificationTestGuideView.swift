import SwiftUI

/// A preview alert teaches the notification gesture instead of opening a synthetic deck.
struct NotificationTestGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    #if targetEnvironment(simulator)
    @State private var gesture: AlertPreviewGesture = .swipe
    #else
    @State private var gesture: AlertPreviewGesture = .hold
    #endif

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Try it inside the alert")
                            .font(StudyStudioStyle.title(24))
                            .foregroundStyle(LearnAlertStyle.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                        Text("This test has no deck to open. Expand the alert to see your colors and try an answer.")
                            .font(.subheadline)
                            .foregroundStyle(LearnAlertStyle.textSecondary)
                    }
                    Spacer(minLength: 8)
                    Button("Close", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly)
                        .font(.body.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .background(LearnAlertStyle.insetSurface, in: Circle())
                }

                HStack(spacing: 8) {
                    ForEach(AlertPreviewGesture.allCases) { option in
                        Button {
                            gesture = option
                        } label: {
                            Text(option.title)
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .foregroundStyle(gesture == option ? LearnAlertStyle.appAccentInk : LearnAlertStyle.textSecondary)
                                .background(gesture == option ? LearnAlertStyle.appAccent : LearnAlertStyle.insetSurface,
                                    in: RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(gesture == option ? .isSelected : [])
                    }
                }

                Group {
                    if reduceMotion {
                        AlertGestureIllustration(gesture: gesture, phase: 2)
                    } else {
                        Color.clear
                            .phaseAnimator([0, 1, 2, 3]) { _, phase in
                                AlertGestureIllustration(gesture: gesture, phase: phase)
                            } animation: { phase in
                                .easeInOut(duration: phase == 2 ? 1.8 : 1.1)
                            }
                            .id(gesture)
                    }
                }
                .frame(height: 192)
                .frame(maxWidth: .infinity)
                .background(LearnAlertStyle.insetSurface.opacity(0.6), in: RoundedRectangle(cornerRadius: 24))
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 8) {
                    Text(gesture == .hold ? "Hold, then answer" : "Swipe left, then View")
                        .font(.headline)
                        .foregroundStyle(LearnAlertStyle.textPrimary)
                    Text(gesture == .hold
                        ? "On iPhone, touch and hold the notification until the question opens. Answer right there."
                        : "Swipe down from the top to find the alert. Swipe left on it, then tap View. This works in the simulator, too.")
                        .font(.subheadline)
                        .foregroundStyle(LearnAlertStyle.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(24)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .background(LearnAlertStyle.courseCanvas)
        .safeAreaInset(edge: .bottom) {
            Button { dismiss() } label: {
                Text("Got it")
                    .font(.headline)
                    .foregroundStyle(LearnAlertStyle.appAccentInk)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(LearnAlertStyle.appAccent, in: RoundedRectangle(cornerRadius: 18))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(LearnAlertStyle.courseCanvas)
        }
        .tint(LearnAlertStyle.appAccentForeground)
        .presentationDetents([.height(620), .large])
        .presentationDragIndicator(.visible)
    }
}

private enum AlertPreviewGesture: String, CaseIterable, Identifiable {
    case hold, swipe
    var id: Self { self }
    var title: String { self == .hold ? "Touch & hold" : "Swipe & View" }
}

private struct AlertGestureIllustration: View {
    let gesture: AlertPreviewGesture
    let phase: Int

    private var expanded: Bool { gesture == .hold && (phase == 2 || phase == 3) }
    private var swiped: Bool { gesture == .swipe && phase > 0 }

    var body: some View {
        ZStack {
            if gesture == .swipe && !expanded {
                HStack {
                    Spacer()
                    Text("View")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LearnAlertStyle.appAccentInk)
                        .frame(width: 64, height: 72)
                        .background(LearnAlertStyle.appAccent, in: RoundedRectangle(cornerRadius: 16))
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "bell.badge.fill")
                        .foregroundStyle(LearnAlertStyle.appAccentForeground)
                    Text("LearnAlert")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    if expanded {
                        Image(systemName: "sparkle")
                            .foregroundStyle(LearnAlertStyle.appAccentForeground)
                    }
                }
                Text(expanded ? "Your question opens here" : "Your study alert")
                    .font(.subheadline)
                    .foregroundStyle(LearnAlertStyle.textSecondary)
                if expanded {
                    HStack(spacing: 8) {
                        ForEach(0..<2) { index in
                            HStack(spacing: 8) {
                                Image(systemName: index == 0 ? "checkmark.circle.fill" : "circle")
                                Text("Answer")
                                    .font(.caption.weight(.medium))
                            }
                            .foregroundStyle(LearnAlertStyle.appAccentForeground)
                            .frame(maxWidth: .infinity, minHeight: 32)
                            .background(LearnAlertStyle.appAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
            .foregroundStyle(LearnAlertStyle.textPrimary)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LearnAlertStyle.courseSurface, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(LearnAlertStyle.cardBorder, lineWidth: 1))
            .shadow(color: LearnAlertStyle.cardShadow, radius: 8, y: 4)
            .offset(x: swiped ? -80 : 0)
            .scaleEffect(gesture == .hold && phase == 1 ? 0.97 : 1)

            Image(systemName: "hand.point.up.left.fill")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(LearnAlertStyle.appAccentForeground)
                .padding(8)
                .background(LearnAlertStyle.courseSurface.opacity(0.9), in: Circle())
                .overlay(Circle().stroke(LearnAlertStyle.appAccentForeground.opacity(phase == 1 ? 0.7 : 0), lineWidth: 2)
                    .scaleEffect(phase == 1 ? 1.2 : 0.8))
                .offset(x: swiped ? -32 : 64, y: expanded ? 40 : 24)
                .opacity(expanded ? 0 : 1)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: 360, maxHeight: .infinity)
        .clipped()
    }
}
