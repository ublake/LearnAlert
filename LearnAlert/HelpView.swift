import SwiftData
import SwiftUI
import UserNotifications

struct HelpView: View {
    @Query private var decks: [Deck]
    @Environment(\.openURL) private var openURL
    @State private var selectedDeckId = "NONE"
    @State private var showingEmptyDeckAlert = false
    @State private var showingPermissionAlert = false
    @State private var testScheduledSuccess = false

    private var selectedDeck: Deck? {
        decks.first { $0.id.uuidString == selectedDeckId }
    }

    var body: some View {
        ZStack {
            LearnAlertStyle.courseCanvas
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HelpIntro()
                    HelpQuestions()
                    HelpContact()
                    NotificationTestSection(
                        decks: decks,
                        selectedDeckId: $selectedDeckId,
                        testScheduledSuccess: testScheduledSuccess,
                        testNotification: testNotification
                    )
                }
                .padding(20)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("Help")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(LearnAlertStyle.courseCanvas, for: .navigationBar)
        .alert("Empty Deck", isPresented: $showingEmptyDeckAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Add at least one card to this deck before testing a notification.")
        }
        .alert("Notifications Not Allowed", isPresented: $showingPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("LearnAlert needs notification permissions to send you flashcard alerts. Please allow Notifications in your iPhone Settings.")
        }
    }

    private func testNotification() {
        guard let selectedDeck, let card = selectedDeck.cards.randomElement() else {
            showingEmptyDeckAlert = true
            return
        }

        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .authorized, .provisional, .ephemeral:
                    triggerTestCard(card)

                case .notDetermined:
                    Task { @MainActor in
                        let granted = await NotificationManager.shared.requestPermission()
                        if granted {
                            triggerTestCard(card)
                        } else {
                            HapticFeedback.warning()
                            showingPermissionAlert = true
                        }
                    }

                case .denied:
                    HapticFeedback.warning()
                    showingPermissionAlert = true

                @unknown default:
                    HapticFeedback.warning()
                    showingPermissionAlert = true
                }
            }
        }
    }

    private func triggerTestCard(_ card: Flashcard) {
        NotificationManager.shared.scheduleRealCard(card, at: Date().addingTimeInterval(3), progress: "Test")
        HapticFeedback.success()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            testScheduledSuccess = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(4))
            withAnimation {
                testScheduledSuccess = false
            }
        }
    }
}

private struct HelpIntro: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "questionmark.bubble.fill")
                    .font(.title2)
                    .foregroundStyle(LearnAlertStyle.indigo)

                VStack(alignment: .leading, spacing: 2) {
                    Text("How can we help?")
                        .font(.custom("Poppins-SemiBold", size: 17, relativeTo: .headline))
                        .foregroundStyle(LearnAlertStyle.textPrimary)

                    Text("Frequently asked questions & support")
                        .font(.custom("Poppins-Regular", size: 12, relativeTo: .caption))
                        .foregroundStyle(LearnAlertStyle.textSecondary)
                }
            }

            Text("Find quick answers below. If something still isn’t working, contact the developer and include what you were trying to do.")
                .font(.custom("Poppins-Regular", size: 13, relativeTo: .subheadline))
                .foregroundStyle(LearnAlertStyle.textSecondary)
                .lineSpacing(2)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .settingsGlassSurface(cornerRadius: 18)
    }
}

private struct HelpQuestions: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("COMMON QUESTIONS")
                .font(.caption.bold())
                .foregroundStyle(LearnAlertStyle.textSecondary)

            DisclosureGroup {
                Text("Check that notifications are allowed in iOS Settings, LearnAlert scheduling is active, and your selected time range has not ended.")
                    .font(.custom("Poppins-Regular", size: 13, relativeTo: .subheadline))
                    .foregroundStyle(LearnAlertStyle.textSecondary)
                    .lineSpacing(2)
                    .padding(.top, 4)
            } label: {
                Text("Why didn’t I receive an alert?")
                    .font(.custom("Poppins-Medium", size: 14, relativeTo: .body))
                    .foregroundStyle(LearnAlertStyle.textPrimary)
            }
            .tint(LearnAlertStyle.indigo)

            Divider().opacity(0.4).overlay(LearnAlertStyle.hairline.opacity(0.3))

            DisclosureGroup {
                Text("Press and hold the notification banner to expand the interactive flashcard. A normal tap opens LearnAlert instead.")
                    .font(.custom("Poppins-Regular", size: 13, relativeTo: .subheadline))
                    .foregroundStyle(LearnAlertStyle.textSecondary)
                    .lineSpacing(2)
                    .padding(.top, 4)
            } label: {
                Text("Why won’t a notification open fully?")
                    .font(.custom("Poppins-Medium", size: 14, relativeTo: .body))
                    .foregroundStyle(LearnAlertStyle.textPrimary)
            }
            .tint(LearnAlertStyle.indigo)

            Divider().opacity(0.4).overlay(LearnAlertStyle.hairline.opacity(0.3))

            DisclosureGroup {
                Text("Paste notes or attach a supported file in Generate Deck. Review and edit the temporary cards before tapping Add Deck.")
                    .font(.custom("Poppins-Regular", size: 13, relativeTo: .subheadline))
                    .foregroundStyle(LearnAlertStyle.textSecondary)
                    .lineSpacing(2)
                    .padding(.top, 4)
            } label: {
                Text("How does AI deck generation work?")
                    .font(.custom("Poppins-Medium", size: 14, relativeTo: .body))
                    .foregroundStyle(LearnAlertStyle.textPrimary)
            }
            .tint(LearnAlertStyle.indigo)

            Divider().opacity(0.4).overlay(LearnAlertStyle.hairline.opacity(0.3))

            DisclosureGroup {
                Text("On-device data may be removed when the app is deleted. Download your data first if you want a personal copy.")
                    .font(.custom("Poppins-Regular", size: 13, relativeTo: .subheadline))
                    .foregroundStyle(LearnAlertStyle.textSecondary)
                    .lineSpacing(2)
                    .padding(.top, 4)
            } label: {
                Text("Will deleting the app remove my decks?")
                    .font(.custom("Poppins-Medium", size: 14, relativeTo: .body))
                    .foregroundStyle(LearnAlertStyle.textPrimary)
            }
            .tint(LearnAlertStyle.indigo)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .settingsGlassSurface(cornerRadius: 18)
    }
}

private struct HelpContact: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CONTACT")
                .font(.caption.bold())
                .foregroundStyle(LearnAlertStyle.textSecondary)

            Link(destination: URL(string: "mailto:contact@learnalertapp.com")!) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(LearnAlertStyle.indigo.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(LearnAlertStyle.indigo)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Email Support")
                            .font(.custom("Poppins-SemiBold", size: 14, relativeTo: .body))
                            .foregroundStyle(LearnAlertStyle.textPrimary)
                            .lineLimit(1)
                        Text("contact@learnalertapp.com")
                            .font(.custom("Poppins-Regular", size: 12, relativeTo: .caption))
                            .foregroundStyle(LearnAlertStyle.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.70)
                            .allowsTightening(true)
                    }
                    .layoutPriority(1)

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LearnAlertStyle.textSecondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(LearnAlertStyle.surfaceOutline(darkOpacity: 0.3), lineWidth: 0.75)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .settingsGlassSurface(cornerRadius: 18)
    }
}

private struct NotificationTestSection: View {
    let decks: [Deck]
    @Binding var selectedDeckId: String
    let testScheduledSuccess: Bool
    let testNotification: () -> Void

    private var selectedDeckName: String {
        decks.first { $0.id.uuidString == selectedDeckId }?.name ?? "Select a Deck"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("TRY A NOTIFICATION")
                .font(.caption.bold())
                .foregroundStyle(LearnAlertStyle.textSecondary)

            Text("Choose a deck and LearnAlert will send one test notification in about three seconds.")
                .font(.custom("Poppins-Regular", size: 13, relativeTo: .subheadline))
                .foregroundStyle(LearnAlertStyle.textSecondary)
                .lineSpacing(2)

            Menu {
                Picker("Deck", selection: $selectedDeckId) {
                    Text("Select a Deck").tag("NONE")
                    ForEach(decks) { deck in
                        Text(deck.name).tag(deck.id.uuidString)
                    }
                }
            } label: {
                HStack {
                    Text(selectedDeckName)
                        .font(.custom("Poppins-Medium", size: 14, relativeTo: .body))
                        .foregroundStyle(selectedDeckId == "NONE" ? LearnAlertStyle.textSecondary : LearnAlertStyle.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.bold())
                        .foregroundStyle(LearnAlertStyle.textSecondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(LearnAlertStyle.surfaceOutline(darkOpacity: 0.3), lineWidth: 0.75)
                )
            }

            Button(action: testNotification) {
                HStack(spacing: 8) {
                    if testScheduledSuccess {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.green)
                        Text("Alert Sent in 3s!")
                    } else {
                        Image(systemName: "bell.and.waves.left.and.right.fill")
                        Text("Try Notification")
                    }
                }
                .font(.custom("Poppins-SemiBold", size: 14))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
            }
            .foregroundStyle(.white)
            .background(
                selectedDeckId == "NONE"
                    ? AnyShapeStyle(Color.gray.opacity(0.35))
                    : AnyShapeStyle(
                        LinearGradient(
                            colors: testScheduledSuccess
                                ? [Color.green.opacity(0.85), Color.green]
                                : [LearnAlertStyle.indigo, LearnAlertStyle.indigo.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(selectedDeckId == "NONE" ? Color.clear : Color.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(
                color: selectedDeckId == "NONE" ? Color.clear : (testScheduledSuccess ? Color.green.opacity(0.3) : LearnAlertStyle.indigo.opacity(0.25)),
                radius: 8,
                y: 3
            )
            .disabled(selectedDeckId == "NONE")
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .settingsGlassSurface(cornerRadius: 18)
    }
}
