import SwiftUI

enum AIConsentManager {
    private static let consentKey = "learnalert_ai_terms_consent_granted"

    static var hasConsented: Bool {
        UserDefaults.standard.bool(forKey: consentKey)
    }

    static func grantConsent() {
        UserDefaults.standard.set(true, forKey: consentKey)
    }

    static func revokeConsent() {
        UserDefaults.standard.set(false, forKey: consentKey)
    }
}

struct AIConsentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
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
                            // Header Icon & Title
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
                                    .font(.custom("Poppins-SemiBold", size: 21))
                                    .foregroundStyle(LearnAlertStyle.textPrimary)

                                Text("LearnAlert uses artificial intelligence (OpenAI) to generate flashcards and summarize your study materials.")
                                    .font(.custom("Poppins-Regular", size: 13))
                                    .foregroundStyle(LearnAlertStyle.textSecondary)
                                    .lineSpacing(2)
                            }

                            // Compact Key Information
                            VStack(spacing: 12) {
                                consentFeatureRow(
                                    icon: "lock.shield.fill",
                                    title: "Privacy & Protection",
                                    detail: "Your notes, documents, or photos are securely processed to build flashcards. We do not sell your personal data."
                                )

                                consentFeatureRow(
                                    icon: "exclamationmark.triangle.fill",
                                    title: "Content Guidelines",
                                    detail: "Please do not submit sensitive personal, private, or confidential information."
                                )
                            }
                            .padding(14)
                            .settingsGlassSurface(cornerRadius: 16)

                            // Direct Links to Terms & Privacy
                            VStack(alignment: .leading, spacing: 8) {
                                Text("By continuing, you agree to our terms:")
                                    .font(.custom("Poppins-Medium", size: 12))
                                    .foregroundStyle(LearnAlertStyle.textSecondary)

                                HStack(spacing: 8) {
                                    Button {
                                        activeSafariURL = URL(string: "https://learnalertapp.com/terms")
                                    } label: {
                                        HStack(spacing: 5) {
                                            Image(systemName: "doc.text.fill")
                                                .font(.system(size: 11))
                                                .foregroundStyle(LearnAlertStyle.indigo)
                                            Text("Terms")
                                                .font(.custom("Poppins-Medium", size: 12))
                                            Spacer()
                                            Image(systemName: "arrow.up.right")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundStyle(LearnAlertStyle.textSecondary.opacity(0.8))
                                        }
                                        .foregroundStyle(LearnAlertStyle.textPrimary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 8)
                                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    }
                                    .buttonStyle(.plain)

                                    Button {
                                        activeSafariURL = URL(string: "https://learnalertapp.com/privacy-policy")
                                    } label: {
                                        HStack(spacing: 5) {
                                            Image(systemName: "hand.raised.fill")
                                                .font(.system(size: 11))
                                                .foregroundStyle(LearnAlertStyle.indigo)
                                            Text("Privacy Policy")
                                                .font(.custom("Poppins-Medium", size: 12))
                                            Spacer()
                                            Image(systemName: "arrow.up.right")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundStyle(LearnAlertStyle.textSecondary.opacity(0.8))
                                        }
                                        .foregroundStyle(LearnAlertStyle.textPrimary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 8)
                                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.top, 2)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                    }

                    // Action Buttons
                    VStack(spacing: 10) {
                        Button {
                            AIConsentManager.grantConsent()
                            dismiss()
                            onAccept()
                        } label: {
                            Text("Agree & Continue")
                                .font(.custom("Poppins-SemiBold", size: 15))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(LearnAlertStyle.indigo)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .shadow(color: LearnAlertStyle.indigo.opacity(0.35), radius: 8, y: 3)
                        }
                        .buttonStyle(.plain)

                        Button {
                            dismiss()
                            onCancel?()
                        } label: {
                            Text("Not Now")
                                .font(.custom("Poppins-Medium", size: 14))
                                .foregroundStyle(LearnAlertStyle.textSecondary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 38)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                        onCancel?()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(LearnAlertStyle.textSecondary.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
            }
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

    private func consentFeatureRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(LearnAlertStyle.indigo)
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.custom("Poppins-SemiBold", size: 13))
                    .foregroundStyle(LearnAlertStyle.textPrimary)

                Text(detail)
                    .font(.custom("Poppins-Regular", size: 12))
                    .foregroundStyle(LearnAlertStyle.textSecondary)
                    .lineSpacing(1.5)
            }
        }
    }
}
