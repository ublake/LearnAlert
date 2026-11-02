import SwiftUI

struct TutorialCompletionView: View {
    let onContinue: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false

    var body: some View {
        ZStack {
            LearnAlertStyle.courseCanvas.ignoresSafeArea()

            VStack {
                Spacer(minLength: 24)

                VStack(spacing: 20) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(LearnAlertStyle.appAccentForeground)
                        .frame(width: 76, height: 76)
                        .background(LearnAlertStyle.appAccent.opacity(0.22), in: Circle())
                        .scaleEffect(reduceMotion || hasAppeared ? 1 : 0.88)
                        .accessibilityHidden(true)

                    VStack(spacing: 10) {
                        Text("You’re all set")
                            .font(.custom("Poppins-SemiBold", size: 30, relativeTo: .largeTitle))
                            .foregroundStyle(LearnAlertStyle.textPrimary)
                            .accessibilityAddTraits(.isHeader)

                        Text("Answer a few questions in your alerts, then get back to your day.")
                            .font(.custom("Poppins-Regular", size: 15, relativeTo: .body))
                            .foregroundStyle(LearnAlertStyle.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: reduceMotion || hasAppeared ? 0 : 8)

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 28)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button(action: onContinue) {
                Text("Continue")
                    .font(.custom("Poppins-SemiBold", size: 16, relativeTo: .headline))
                    .foregroundStyle(LearnAlertStyle.appAccentInk)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(LearnAlertStyle.appAccent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .frame(maxWidth: 360)
            .padding(.horizontal, 28)
            .padding(.top, 12)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity)
            .background(LearnAlertStyle.courseCanvas)
        }
        .interactiveDismissDisabled()
        .onAppear {
            guard !hasAppeared else { return }
            withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.5, dampingFraction: 0.82)) {
                hasAppeared = true
            }
        }
    }
}
