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

                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // Header Icon & Title
                            VStack(alignment: .leading, spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill(LearnAlertStyle.indigo.opacity(0.18))
                                        .frame(width: 54, height: 54)
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 26, weight: .semibold))
                                        .foregroundStyle(LearnAlertStyle.indigo)
                                }

                                Text("AI Features & Data Processing")
                                    .font(.custom("Poppins-SemiBold", size: 22))
                                    .foregroundStyle(LearnAlertStyle.textPrimary)

                                Text("LearnAlert uses artificial intelligence to generate flashcards, summarize study materials, and detect document structures.")
                                    .font(.custom("Poppins-Regular", size: 14))
                                    .foregroundStyle(LearnAlertStyle.textSecondary)
                                    .lineSpacing(2)
                            }

                            // Bullet Points
                            VStack(spacing: 14) {
                                consentFeatureRow(
                                    icon: "network",
                                    title: "AI Provider: OpenAI",
                                    detail: "Content you submit (notes, text, uploaded documents, or images) is securely processed by OpenAI to create and refine your study materials."
                                )

                                consentFeatureRow(
                                    icon: "lock.shield.fill",
                                    title: "Your Privacy & Protection",
                                    detail: "We do not sell your personal data. Do not upload sensitive personal, confidential, or private credentials."
                                )

                                consentFeatureRow(
                                    icon: "arrow.triangle.2.circlepath.doc.on.clipboard",
                                    title: "Document Analysis",
                                    detail: "When you upload multi-page PDFs or materials, page snippets may be analyzed by our backend and OpenAI to identify sections and headings."
                                )
                            }
                            .padding(16)
                            .settingsGlassSurface(cornerRadius: 16)

                            // Legal links
                            HStack(spacing: 16) {
                                Button {
                                    activeSafariURL = URL(string: "https://learnalertapp.com/privacy-policy")
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "hand.raised.fill")
                                            .font(.system(size: 11))
                                        Text("Privacy Policy")
                                    }
                                    .font(.custom("Poppins-Medium", size: 12))
                                    .foregroundStyle(LearnAlertStyle.indigo)
                                    .underline()
                                }
                                .buttonStyle(.plain)

                                Text("•")
                                    .foregroundStyle(LearnAlertStyle.textSecondary.opacity(0.4))

                                Button {
                                    activeSafariURL = URL(string: "https://learnalertapp.com/terms")
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "doc.text.fill")
                                            .font(.system(size: 11))
                                        Text("Terms of Service")
                                    }
                                    .font(.custom("Poppins-Medium", size: 12))
                                    .foregroundStyle(LearnAlertStyle.indigo)
                                    .underline()
                                }
                                .buttonStyle(.plain)
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 4)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 24)
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
                                .frame(height: 40)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(
                        Rectangle()
                            .fill(LearnAlertStyle.courseCanvas.opacity(0.95))
                            .ignoresSafeArea()
                    )
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
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func consentFeatureRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(LearnAlertStyle.indigo)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.custom("Poppins-SemiBold", size: 13))
                    .foregroundStyle(LearnAlertStyle.textPrimary)

                Text(detail)
                    .font(.custom("Poppins-Regular", size: 12))
                    .foregroundStyle(LearnAlertStyle.textSecondary)
                    .lineSpacing(2)
            }
        }
    }
}
