import SwiftUI

struct PrivacyPolicyView: View {
    @State private var showingSafari = false

    var body: some View {
        ZStack {
            LearnAlertStyle.courseCanvas
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    PrivacyPolicyIntro()

                    PrivacyPolicySection(
                        title: "1. On-Device Storage & No Accounts",
                        text: "All your decks, cards, review history, and streaks are stored locally on your device using Apple SwiftData. You do not need to register, log in, or provide personal credentials to use LearnAlert. If iCloud is enabled, your data syncs securely across your Apple devices using Apple's private CloudKit database."
                    )

                    PrivacyPolicySection(
                        title: "2. The \"No-Training\" Guarantee",
                        text: "We access third-party AI services strictly through enterprise and commercial API agreements. Your private study notes, attachments, text prompts, and flashcards are NOT used by OpenAI or LearnAlert to train public AI foundation models."
                    )

                    PrivacyPolicySection(
                        title: "3. What You Choose to Send",
                        text: "LearnAlert AI processes only the notes, text, documents, or photos you explicitly submit in the Generate Deck composer. Please never upload passwords, financial information, health records, government IDs, or other sensitive confidential information."
                    )

                    PrivacyPolicySection(
                        title: "4. Sub-processors (Apple Guideline 5.1.2(i))",
                        text: "To generate and refine interactive flashcard decks, submitted notes are securely transmitted over TLS 1.3/HTTPS to api.learnalertapp.com and provided to OpenAI, Inc. for processing. Uploaded study files receive a temporary identifier designed to expire within approximately 24 hours."
                    )

                    PrivacyPolicySection(
                        title: "5. Zero Advertising & Zero Tracking",
                        text: "LearnAlert contains no third-party advertisements, does not collect Apple's Identifier for Advertisers (IDFA), and does not sell, rent, or monetize your study data to data brokers or third parties."
                    )

                    PrivacyPolicySection(
                        title: "6. Data Retention & Instant Deletion",
                        text: "Generated cards remain a temporary draft until you tap \"Add Deck\". You can edit or permanently delete any card or deck at any time in the app, or wipe all data in Settings > Manage My Data. Deleting the app removes all local database records."
                    )

                    PrivacyPolicyContact(onOpenWebPolicy: {
                        showingSafari = true
                    })
                }
                .padding(20)
                .padding(.bottom, 30)
            }
        }
        .fullScreenCover(isPresented: $showingSafari) {
            SafariView(url: URL(string: "https://learnalertapp.com/privacy-policy")!)
                .ignoresSafeArea()
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PrivacyPolicyIntro: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "lock.shield.fill")
                    .font(.title2)
                    .foregroundStyle(LearnAlertStyle.indigo)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Your Privacy Matters")
                        .font(.custom("Poppins-SemiBold", size: 17, relativeTo: .headline))
                        .foregroundStyle(LearnAlertStyle.textPrimary)

                    Text("Effective: September 16, 2026")
                        .font(.custom("Poppins-Regular", size: 12, relativeTo: .caption))
                        .foregroundStyle(LearnAlertStyle.textSecondary)
                }
            }

            Text("LearnAlert is built on a Privacy-by-Design philosophy. Your study habits, notes, and progress stay strictly under your control.")
                .font(.custom("Poppins-Regular", size: 13, relativeTo: .subheadline))
                .foregroundStyle(LearnAlertStyle.textSecondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .settingsGlassSurface(cornerRadius: 18)
    }
}

private struct PrivacyPolicySection: View {
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

private struct PrivacyPolicyContact: View {
    let onOpenWebPolicy: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Questions & Web Policy")
                .font(.custom("Poppins-SemiBold", size: 14, relativeTo: .headline))
                .foregroundStyle(LearnAlertStyle.textPrimary)

            VStack(alignment: .leading, spacing: 10) {
                Button(action: onOpenWebPolicy) {
                    HStack(spacing: 8) {
                        Image(systemName: "safari.fill")
                            .font(.subheadline)
                        Text("View on learnalertapp.com/privacy-policy")
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
