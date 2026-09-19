import SwiftUI

struct TermsOfServiceView: View {
    @State private var showingSafari = false

    var body: some View {
        ZStack {
            LearnAlertStyle.courseCanvas
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    TermsIntroCard()

                    TermsSectionCard(
                        title: "1. Educational Use Only",
                        text: "LearnAlert is designed as a supplementary study and spaced-repetition tool. While our systems strive for high educational quality, we make no warranties or representations regarding test scores, course grades, academic admissions, or professional certifications. You are encouraged to verify study materials against your official course syllabus and textbooks."
                    )

                    TermsSectionCard(
                        title: "2. AI Generation & Synthetic Content",
                        text: "LearnAlert provides automated flashcard generation powered by third-party artificial intelligence models (such as OpenAI). AI-generated flashcards, summaries, and explanations are produced algorithmically and may occasionally contain inaccuracies or hallucinations. You are provided with full editing capabilities and are advised to review and verify all generated cards before adding them to your active study rotation."
                    )

                    TermsSectionCard(
                        title: "3. Your Content & Ownership",
                        text: "You retain ownership of any original study materials, notes, documents, or photos you submit to the app. You represent and warrant that you have the right to submit such materials and that your content does not violate third-party intellectual property rights."
                    )

                    TermsSectionCard(
                        title: "4. Acceptable Use",
                        text: "You agree not to submit unlawful, abusive, or infringing material, or sensitive personal data such as passwords, financial records, medical information, or government identification. You also agree not to reverse-engineer, disrupt, or place unreasonable load on the LearnAlert backend infrastructure."
                    )

                    TermsSectionCard(
                        title: "5. Intellectual Property",
                        text: "The LearnAlert application—including its design, branding, code, sound effects, visual assets, and user interface—is the intellectual property of LearnAlert. You are granted a personal, non-exclusive, non-transferable license to use the app for your personal educational study."
                    )

                    TermsSectionCard(
                        title: "6. Limitation of Liability",
                        text: "To the maximum extent permitted by applicable law, LearnAlert and its creators shall not be liable for any indirect, incidental, special, or consequential damages resulting from your use of the app, reliance on AI-generated materials, or academic outcomes."
                    )

                    TermsContactCard(onOpenWebTerms: {
                        showingSafari = true
                    })
                }
                .padding(20)
                .padding(.bottom, 30)
            }
        }
        .fullScreenCover(isPresented: $showingSafari) {
            SafariView(url: URL(string: "https://learnalertapp.com/terms")!)
                .ignoresSafeArea()
        }
        .navigationTitle("Terms & Conditions")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct TermsIntroCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "doc.text.fill")
                    .font(.title2)
                    .foregroundStyle(LearnAlertStyle.indigo)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Terms & Conditions")
                        .font(.custom("Poppins-SemiBold", size: 17, relativeTo: .headline))
                        .foregroundStyle(LearnAlertStyle.textPrimary)

                    Text("Effective: September 16, 2026")
                        .font(.custom("Poppins-Regular", size: 12, relativeTo: .caption))
                        .foregroundStyle(LearnAlertStyle.textSecondary)
                }
            }

            Text("Please review these terms governing your use of LearnAlert, including our AI-powered study and flashcard features.")
                .font(.custom("Poppins-Regular", size: 13, relativeTo: .subheadline))
                .foregroundStyle(LearnAlertStyle.textSecondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .settingsGlassSurface(cornerRadius: 18)
    }
}

private struct TermsSectionCard: View {
    let title: LocalizedStringResource
    let text: LocalizedStringResource

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.custom("Poppins-SemiBold", size: 14, relativeTo: .headline))
                .foregroundStyle(LearnAlertStyle.textPrimary)

            Text(text)
                .font(.custom("Poppins-Regular", size: 13, relativeTo: .subheadline))
                .foregroundStyle(LearnAlertStyle.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .settingsGlassSurface(cornerRadius: 16)
    }
}

private struct TermsContactCard: View {
    let onOpenWebTerms: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Questions & Web Version")
                .font(.custom("Poppins-SemiBold", size: 14, relativeTo: .headline))
                .foregroundStyle(LearnAlertStyle.textPrimary)

            VStack(alignment: .leading, spacing: 10) {
                Button(action: onOpenWebTerms) {
                    HStack(spacing: 8) {
                        Image(systemName: "safari.fill")
                            .font(.subheadline)
                        Text("View on learnalertapp.com/terms")
                            .font(.custom("Poppins-Medium", size: 13, relativeTo: .body))
                    }
                    .foregroundStyle(LearnAlertStyle.sky)
                }
                .buttonStyle(.plain)

                Link(destination: URL(string: "mailto:contact@learnalertapp.com")!) {
                    HStack(spacing: 8) {
                        Image(systemName: "envelope.fill")
                            .font(.subheadline)
                        Text("contact@learnalertapp.com")
                            .font(.custom("Poppins-Medium", size: 13, relativeTo: .body))
                            .lineLimit(1)
                            .minimumScaleFactor(0.70)
                            .allowsTightening(true)
                    }
                    .foregroundStyle(LearnAlertStyle.sky)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .settingsGlassSurface(cornerRadius: 16)
    }
}
