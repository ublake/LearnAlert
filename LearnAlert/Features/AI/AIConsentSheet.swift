import SwiftUI

nonisolated enum AIConsentManager {
    static let consentKey = "learnalert_ai_data_sharing_consent_version"
    // Increment when the disclosure or the scope of data sharing changes.
    static let currentVersion = 1

    static var hasConsented: Bool {
        UserDefaults.standard.integer(forKey: consentKey) == currentVersion
    }

    static func grantConsent() {
        UserDefaults.standard.set(currentVersion, forKey: consentKey)
    }

    static func revokeConsent() {
        UserDefaults.standard.removeObject(forKey: consentKey)
    }
}

struct AIConsentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AIConsentManager.consentKey) private var consentVersion = 0
    @State private var activeSafariURL: URL?

    let onAccept: () -> Void
    var onCancel: (() -> Void)? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                LearnAlertStyle.courseCanvas
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(LearnAlertStyle.indigo.opacity(0.18))
                                        .frame(width: 48, height: 48)
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 22, weight: .semibold))
                                        .foregroundStyle(LearnAlertStyle.indigo)
                                }

                                Text("AI Deck Generation")
                                    .font(.custom("Poppins-SemiBold", size: 21, relativeTo: .title3))
                                    .foregroundStyle(LearnAlertStyle.textPrimary)
                                    .accessibilityAddTraits(.isHeader)

                                Text("When you send an AI request, LearnAlert shares the included study material through its servers with third-party AI providers to generate or revise flashcards.")
                                    .font(.subheadline)
                                    .foregroundStyle(LearnAlertStyle.textPrimary)
                            }

                            VStack(alignment: .leading, spacing: 12) {
                                consentFeatureRow(
                                    icon: "text.alignleft",
                                    provider: "Cheaper Inference",
                                    detail: "Processes notes, chat messages, and card content in text requests."
                                )

                                consentFeatureRow(
                                    icon: "doc.on.doc",
                                    provider: "OpenAI",
                                    detail: "Processes uploaded documents or photos and the instructions and chat included with them."
                                )
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .settingsGlassSurface(cornerRadius: 16)

                            Text("Please do not submit sensitive personal, private, or confidential information.")
                                .font(.subheadline)
                                .foregroundStyle(LearnAlertStyle.textSecondary)

                            Text("You can withdraw permission for future AI requests in Settings.")
                                .font(.subheadline)
                                .foregroundStyle(LearnAlertStyle.textSecondary)

                            VStack(alignment: .leading, spacing: 8) {
                                ViewThatFits(in: .horizontal) {
                                    HStack(spacing: 8) { legalLinks }
                                    VStack(alignment: .leading, spacing: 8) { legalLinks }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                    }

                    VStack(spacing: 6) {
                        if consentVersion == AIConsentManager.currentVersion {
                            Button(role: .destructive) {
                                AIConsentManager.revokeConsent()
                            } label: {
                                Text("Withdraw AI Permission")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                            }
                            .buttonStyle(.bordered)
                            .tint(LearnAlertStyle.destructiveRed)
                        } else {
                            Button {
                                AIConsentManager.grantConsent()
                                dismiss()
                                onAccept()
                            } label: {
                                Text("Allow AI Data Sharing")
                                    .font(.headline)
                                    .foregroundStyle(LearnAlertStyle.appAccentInk)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity, minHeight: 50)
                                    .background(LearnAlertStyle.appAccent, in: RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                        }

                        Button {
                            dismiss()
                            onCancel?()
                        } label: {
                            if consentVersion == AIConsentManager.currentVersion {
                                Text("Done")
                            } else {
                                Text("Not Now")
                            }
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(LearnAlertStyle.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: Binding(
                get: { activeSafariURL != nil },
                set: { if !$0 { activeSafariURL = nil } }
            )) {
                if let url = activeSafariURL {
                    SafariView(url: url)
                        .ignoresSafeArea()
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder private var legalLinks: some View {
        legalLink("Terms", icon: "doc.text.fill", url: "https://learnalertapp.com/terms")
        legalLink("Privacy Policy", icon: "hand.raised.fill", url: "https://learnalertapp.com/privacy-policy")
    }

    private func legalLink(_ label: LocalizedStringResource, icon: String, url: String) -> some View {
        Button {
            activeSafariURL = URL(string: url)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(LearnAlertStyle.appAccentForeground)
                    .accessibilityHidden(true)
                Text(label)
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .accessibilityHidden(true)
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(LearnAlertStyle.textPrimary)
            .padding(.horizontal, 10)
            .frame(minHeight: 44)
            .background(LearnAlertStyle.insetSurface, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func consentFeatureRow(icon: String, provider: String, detail: LocalizedStringResource) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(LearnAlertStyle.appAccentForeground)
                .frame(width: 22, height: 22)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: provider)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LearnAlertStyle.textPrimary)

                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(LearnAlertStyle.textSecondary)
            }
        }
    }
}
