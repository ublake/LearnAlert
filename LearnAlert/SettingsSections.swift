import MessageUI
import SwiftUI
import SwiftData
import UserNotifications

struct SettingsHeroSection: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var body: some View {
        HStack(spacing: 14) {
            Image("LearnAlertLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 58, height: 58)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text("LearnAlert")
                    .font(.custom("Poppins-SemiBold", size: 22))
                    .foregroundStyle(LearnAlertStyle.textPrimary)
                Text("Version \(version)")
                    .font(.custom("Poppins-Regular", size: 11))
                .foregroundStyle(LearnAlertStyle.textSecondary)
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 22)
    }
}

struct SettingsStatusSection: View {
    let permissionStatus: UNAuthorizationStatus
    let openSystemSettings: () -> Void

    private var notificationsAllowed: Bool {
        switch permissionStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("STATUS")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Image(systemName: notificationsAllowed ? "bell.badge.fill" : "bell.slash.fill")
                    .font(.title3)
                    .foregroundStyle(notificationsAllowed ? LearnAlertStyle.aqua : LearnAlertStyle.coral)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(notificationsAllowed ? "Notifications ready" : "Notifications need attention")
                        .font(.custom("Poppins-SemiBold", size: 14))
                        .foregroundStyle(LearnAlertStyle.textPrimary)
                    Text(notificationsAllowed ? "LearnAlert can deliver study cards." : "Allow alerts in iOS Settings.")
                        .font(.custom("Poppins-Regular", size: 10))
                        .foregroundStyle(LearnAlertStyle.textSecondary)
                }

                Spacer()

                Button("Settings", action: openSystemSettings)
                    .font(.custom("Poppins-SemiBold", size: 10))
                    .buttonStyle(.bordered)
                    .tint(LearnAlertStyle.appAccentForeground)
            }
            .padding(15)
            .nativeGlass(cornerRadius: 16)
        }
        .padding(.horizontal)
    }
}

struct SettingsLearningSection: View {
    @ObservedObject var engine: StudyEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("LEARNING")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                SettingsToggleRow(
                    title: "Smart Review",
                    subtitle: "Prioritize cards that are due",
                    systemImage: "brain.head.profile",
                    isOn: $engine.smartSRS
                )

                Divider().padding(.leading, 50).opacity(0.45)

                AlertPaceControls(settings: $engine.settings, automaticCount: engine.automaticDailyCount)
                    .padding(14)
                Divider().padding(.leading, 50).opacity(0.45)

                DeckScheduleTimingFields(settings: $engine.settings).padding(14)
                Divider().padding(.leading, 50).opacity(0.45)

                HStack(spacing: 12) {
                    SettingsRowIcon(systemName: "stopwatch.fill")
                    Text("Stop alerts")
                        .font(.custom("Poppins-Medium", size: 13))
                    Spacer()
                    Menu {
                        Picker("Stop alerts", selection: $engine.stopCondition) {
                            Text("Deck Learnt").tag("Until Deck Learnt")
                            Text("Day Ends").tag("Until Day Ends")
                            Text("Until I say so").tag("Until I say so")
                        }
                    } label: {
                        SettingsMenuLabel(text: stopLabel)
                    }
                }
                .padding(14)
            }
            .foregroundStyle(LearnAlertStyle.textPrimary)
            .nativeGlass(cornerRadius: 16)
        }
        .padding(.horizontal)
        .onAppear { engine.selectSettings(for: nil) }
    }

    private var stopLabel: String {
        switch engine.stopCondition {
        case "Until Deck Learnt": return "Deck learnt"
        case "Until Day Ends": return "Day ends"
        default: return "Until I say so"
        }
    }
}

struct SettingsAlertSoundSection: View {
    @Binding var alertSound: String
    var availableSounds: [AlertSoundOption] = AlertSoundOption.allSounds

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ALERT SOUND")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                SettingsRowIcon(systemName: "speaker.wave.2.fill")
                VStack(alignment: .leading, spacing: 2) {
                    Text("Alert sound")
                        .font(.custom("Poppins-Medium", size: 13))
                    Text("Selecting one plays a preview")
                        .font(.custom("Poppins-Regular", size: 9))
                        .foregroundStyle(LearnAlertStyle.textSecondary)
                }
                Spacer()
                Picker("Alert sound", selection: $alertSound) {
                    ForEach(availableSounds) { sound in
                        Text(sound.name).tag(sound.id)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .tint(LearnAlertStyle.appAccentForeground)
                .font(.custom("Poppins-Medium", size: 13))
                .controlSize(.large)
            }
            .padding(14)
            .foregroundStyle(LearnAlertStyle.textPrimary)
            .nativeGlass(cornerRadius: 16)
        }
        .padding(.horizontal)
    }

    private func soundLabel(_ sound: String) -> String {
        AlertSoundOption.displayName(for: sound)
    }
}

struct SettingsAppearanceSection: View {
    @Binding var appearanceMode: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("APPEARANCE")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                SettingsRowIcon(systemName: "circle.lefthalf.filled")
                Text("Appearance")
                    .font(.custom("Poppins-Medium", size: 13))
                Spacer()
                Picker("Appearance", selection: $appearanceMode) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .tint(LearnAlertStyle.appAccentForeground)
                .controlSize(.large)
            }
            .padding(14)
            .foregroundStyle(LearnAlertStyle.textPrimary)
            .nativeGlass(cornerRadius: 16)
        }
        .padding(.horizontal)
    }
}

private struct SettingsToggleRow: View {
    let title: LocalizedStringResource
    let subtitle: LocalizedStringResource
    let systemImage: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 12) {
                SettingsRowIcon(systemName: systemImage)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.custom("Poppins-Medium", size: 13))
                    Text(subtitle)
                        .font(.custom("Poppins-Regular", size: 9))
                        .foregroundStyle(LearnAlertStyle.textSecondary)
                }
            }
        }
        .tint(LearnAlertStyle.appAccentForeground)
        .padding(14)
    }
}

private struct SettingsRowIcon: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(LearnAlertStyle.appAccentForeground)
            .frame(width: 34, height: 34)
            .background(LearnAlertStyle.appAccent.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .accessibilityHidden(true)
    }
}

private struct SettingsMenuLabel: View {
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Text(text).lineLimit(1)
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 8, weight: .bold))
        }
        .font(.custom("Poppins-Medium", size: 10))
        .foregroundStyle(LearnAlertStyle.appAccentForeground)
    }
}

struct SettingsNavigationRow: View {
    let title: LocalizedStringResource
    let subtitle: LocalizedStringResource?
    let systemImage: String
    let isHighlighted: Bool

    init(title: LocalizedStringResource, subtitle: LocalizedStringResource? = nil, systemImage: String, isHighlighted: Bool = false) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.isHighlighted = isHighlighted
    }

    var body: some View {
        HStack(spacing: 12) {
            SettingsRowIcon(systemName: systemImage)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.custom("Poppins-Medium", size: 13))
                if let subtitle {
                    Text(subtitle)
                        .font(.custom("Poppins-Regular", size: 9))
                        .foregroundStyle(LearnAlertStyle.textSecondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(LearnAlertStyle.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .foregroundStyle(
            isHighlighted
                ? AnyShapeStyle(LearnAlertStyle.appAccentForeground)
                : AnyShapeStyle(.secondary)
        )
        .background(isHighlighted ? LearnAlertStyle.courseLavender.opacity(0.72) : Color.gray.opacity(0.16))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct SettingsVersionRow: View {
    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "Version \(version) (\(build))"
    }

    var body: some View {
        HStack {
            Label("LearnAlert", systemImage: "info.circle.fill")
                .font(.custom("Poppins-Medium", size: 12))
            Spacer()
            Text(versionText)
                .font(.custom("Poppins-Regular", size: 10))
                .foregroundStyle(LearnAlertStyle.textSecondary)
        }
        .padding(14)
        .foregroundStyle(LearnAlertStyle.textPrimary)
        .nativeGlass(cornerRadius: 16)
    }
}

struct SettingsPreferencesGroup: View {
    @Binding var alertSound: String
    var availableSounds: [AlertSoundOption] = AlertSoundOption.allSounds
    @Binding var appearanceMode: String
    @Binding var deckCreaturesHaveFaces: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Preferences")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(LearnAlertStyle.textSecondary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                Menu {
                    Picker("Alert Sound", selection: $alertSound) {
                        ForEach(availableSounds) { sound in
                            Text(sound.name).tag(sound.id)
                        }
                    }
                    .pickerStyle(.inline)
                } label: {
                    SettingsPreferenceLabel(title: "Alert Sound", systemImage: "speaker.wave.2.fill", value: AlertSoundOption.displayName(for: alertSound))
                }
                .accessibilityLabel("Alert Sound")
                .accessibilityValue(AlertSoundOption.displayName(for: alertSound))

                Divider().overlay(LearnAlertStyle.cardBorder).padding(.leading, 64)

                Menu {
                    Picker("Appearance", selection: $appearanceMode) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    .pickerStyle(.inline)
                } label: {
                    SettingsPreferenceLabel(title: "Appearance", systemImage: "circle.lefthalf.filled", value: appearanceMode == "light" ? "Light" : appearanceMode == "dark" ? "Dark" : "System")
                }
                .accessibilityLabel("Appearance")
                .accessibilityValue(appearanceMode == "light" ? "Light" : appearanceMode == "dark" ? "Dark" : "System")
            }
            .buttonStyle(.plain)
            .settingsGlassSurface(cornerRadius: 20)
        }
        .padding(.horizontal, 20)
    }
}

private struct SettingsPreferenceLabel: View {
    let title: LocalizedStringResource
    let systemImage: String
    let value: String
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(spacing: 14) {
            SettingsRowIcon(systemName: systemImage)
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
                : AnyLayout(HStackLayout(spacing: 12))
            layout {
                Text(title).font(.body.weight(.medium)).foregroundStyle(LearnAlertStyle.textPrimary)
                if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 8) }
                Text(value).font(.subheadline).foregroundStyle(LearnAlertStyle.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(LearnAlertStyle.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .contentShape(Rectangle())
    }
}

struct SettingsSupportGroup: View {
    @State private var activeSafariURL: URL?
    @State private var showingAIConsentReview = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Information")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(LearnAlertStyle.textSecondary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                NavigationLink {
                    WhatsNewView()
                } label: {
                    SettingsGroupedRow(title: "What’s New", systemImage: "sparkles")
                }

                settingsDivider

                NavigationLink {
                    ManageMyDataView()
                } label: {
                    SettingsGroupedRow(title: "Manage My Data", systemImage: "externaldrive.fill")
                }

                settingsDivider

                NavigationLink {
                    FeedbackView()
                } label: {
                    SettingsGroupedRow(title: "Send Feedback", systemImage: "paperplane.fill")
                }

                settingsDivider

                Button {
                    activeSafariURL = URL(string: "https://learnalertapp.com/terms")
                } label: {
                    SettingsGroupedRow(title: "Terms and Conditions", systemImage: "doc.text.fill")
                }
                .buttonStyle(.plain)

                settingsDivider

                Button {
                    activeSafariURL = URL(string: "https://learnalertapp.com/privacy-policy")
                } label: {
                    SettingsGroupedRow(title: "Privacy Policy", systemImage: "lock.shield.fill")
                }
                .buttonStyle(.plain)

                settingsDivider

                Button {
                    showingAIConsentReview = true
                } label: {
                    SettingsGroupedRow(title: "AI Terms & Data Privacy", systemImage: "sparkles")
                }
                .buttonStyle(.plain)

                settingsDivider

                NavigationLink {
                    HelpView()
                } label: {
                    SettingsGroupedRow(title: "Help", systemImage: "questionmark.circle.fill")
                }
            }
            .foregroundStyle(LearnAlertStyle.textPrimary)
            .settingsGlassSurface(cornerRadius: 20)
        }
        .padding(.horizontal, 20)
        .sheet(isPresented: Binding(
            get: { activeSafariURL != nil },
            set: { if !$0 { activeSafariURL = nil } }
        )) {
            if let url = activeSafariURL {
                SafariView(url: url)
                    .ignoresSafeArea()
            }
        }
        .sheet(isPresented: $showingAIConsentReview) {
            AIConsentSheet(
                onAccept: {
                    showingAIConsentReview = false
                },
                onCancel: {
                    showingAIConsentReview = false
                }
            )
        }
    }

    private var settingsDivider: some View {
        Divider().overlay(LearnAlertStyle.cardBorder).padding(.leading, 64)
    }
}

private struct SettingsGroupedRow: View {
    let title: LocalizedStringResource
    let systemImage: String

    var body: some View {
        HStack(spacing: 14) {
            SettingsRowIcon(systemName: systemImage)
            Text(title)
                .font(.body.weight(.medium))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(LearnAlertStyle.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .contentShape(Rectangle())
    }
}

struct ManageMyDataView: View {
    @Environment(\.modelContext) private var context
    @Query private var decks: [Deck]

    @State private var showingDeleteDecksConfirmation = false
    @State private var showingDataShare = false
    @State private var exportedDataURL: URL?

    @State private var isDeletingDecks = false
    @State private var deletionProgress = 0.0
    @State private var deletionStatus = "Preparing your library"
    @State private var deletionError: String?
    @State private var totalCardsToDelete = 0
    @State private var showingDeleteCompleteAlert = false
    @State private var completedSummaryMessage = ""

    var body: some View {
        ZStack {
            LearnAlertStyle.courseCanvas
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(spacing: 0) {
                        Button(action: handleDownloadData) {
                            dataRow(
                                title: "Download Data",
                                detail: "Export your decks and cards",
                                systemImage: "arrow.down.doc.fill",
                                roleColor: LearnAlertStyle.appAccentForeground
                            )
                        }
                        .buttonStyle(.plain)

                        Divider().padding(.leading, 58).opacity(0.45)

                        Button(role: .destructive) {
                            showingDeleteDecksConfirmation = true
                        } label: {
                            dataRow(
                                title: "Delete All Decks",
                                detail: "Permanently remove every deck and card",
                                systemImage: "trash.fill",
                                roleColor: .red
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .settingsGlassSurface(cornerRadius: 18)

                    Text("Deletion actions require confirmation and can’t be undone.")
                        .font(.custom("Poppins-Regular", size: 11, relativeTo: .caption))
                        .foregroundStyle(LearnAlertStyle.textSecondary)
                        .padding(.horizontal, 4)
                }
                .padding(20)
            }

            if isDeletingDecks {
                deletionProgressOverlay
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isDeletingDecks)
        .navigationTitle("Manage My Data")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Delete every deck?",
            isPresented: $showingDeleteDecksConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete All Decks", role: .destructive) {
                executeDeleteAllDecks()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This permanently deletes all decks and cards from this device.")
        }
        .alert("Decks Deleted", isPresented: $showingDeleteCompleteAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(completedSummaryMessage)
        }
        .alert("Couldn’t delete all decks", isPresented: Binding(get: { deletionError != nil }, set: { if !$0 { deletionError = nil } })) {
            Button("OK", role: .cancel) { deletionError = nil }
        } message: {
            Text(deletionError ?? "Please try again.")
        }
        .interactiveDismissDisabled(isDeletingDecks)
        .navigationBarBackButtonHidden(isDeletingDecks)
        .sheet(isPresented: $showingDataShare) {
            if let exportedDataURL {
                ActivityShareSheet(items: [exportedDataURL])
            }
        }
    }

    private var deletionProgressOverlay: some View {
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 28)).foregroundStyle(.red)
                Text("Deleting decks & cards").font(.headline)
                Text(deletionStatus).font(.subheadline).foregroundStyle(.white.opacity(0.7))
                ProgressView(value: deletionProgress).tint(.red)
                if totalCardsToDelete > 0 {
                    Text("\(totalCardsToDelete.formatted()) cards")
                        .font(.caption.monospacedDigit()).foregroundStyle(.white.opacity(0.65))
                }
            }
            .foregroundStyle(.white).padding(24).frame(maxWidth: 360)
            .background(Color(red: 0.12, green: 0.12, blue: 0.14), in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.15), lineWidth: 1))
            .shadow(color: .black.opacity(0.4), radius: 24, y: 10).padding(32)
        }
    }

    private func executeDeleteAllDecks() {
        guard !isDeletingDecks else { return }
        isDeletingDecks = true
        deletionProgress = 0; totalCardsToDelete = 0
        deletionStatus = "Preparing your library"
        HapticFeedback.impact(.medium)
        InteractionSoundPlayer.shared.play(.deleteDeck)
        Task { @MainActor in
            defer { isDeletingDecks = false }
            do {
                // Flush outstanding edits before another context changes the store.
                try context.save()
                let container = context.container
                let result = try await Task.detached(priority: .userInitiated) {
                    let worker = LibraryDataWorker(modelContainer: container)
                    return try await worker.deleteAll { update in
                        await MainActor.run {
                            deletionProgress = update.fraction
                            deletionStatus = update.message
                            totalCardsToDelete = update.cards
                        }
                    }
                }.value
                context.processPendingChanges()
                StudyEngine.shared.stopAlerts()
                HapticFeedback.success()
                InteractionSoundPlayer.shared.play(.correct)
                completedSummaryMessage = result.decks == 0 && result.cards == 0
                    ? "No decks or cards found to delete."
                    : "Successfully removed \(result.decks) \(result.decks == 1 ? "deck" : "decks") and \(result.cards) \(result.cards == 1 ? "card" : "cards")."
                showingDeleteCompleteAlert = true
            } catch {
                deletionError = "Deletion could not finish. Your library will show what remains. Please try again."
            }
        }
    }

    private func handleDownloadData() {
        exportedDataURL = makeDataExportFile()
        showingDataShare = exportedDataURL != nil
    }

    private func makeDataExportFile() -> URL? {
        var lines = ["LearnAlert Data Export", "Generated: \(Date().formatted())", ""]
        for deck in decks.sorted(by: { $0.orderIndex < $1.orderIndex }) {
            lines.append("# \(deck.name)")
            lines.append("Created: \(deck.creationDate.formatted())")
            for card in deck.cards {
                lines.append("- [\(card.cardType.title)] \(card.question)")
                if card.cardType == .matching {
                    for index in card.matchingLeftItems.indices where card.matchingRightItems.indices.contains(index) {
                        lines.append("  \(card.matchingLeftItems[index]) = \(card.matchingRightItems[index])")
                    }
                } else {
                    lines.append("  Answer: \(card.correctAnswer)")
                    if !card.options.isEmpty {
                        let optionsList = card.options.joined(separator: " | ")
                        lines.append("  Options: \(optionsList)")
                    }
                }
            }
            lines.append("")
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("LearnAlert-Data-Export.txt")
        do {
            try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    private func dataRow(
        title: LocalizedStringResource,
        detail: LocalizedStringResource,
        systemImage: String,
        roleColor: Color
    ) -> some View {
        HStack(spacing: 13) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(roleColor)
                .frame(width: 32, height: 32)
                .background(roleColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.custom("Poppins-Medium", size: 13, relativeTo: .body))
                Text(detail)
                    .font(.custom("Poppins-Regular", size: 10, relativeTo: .caption))
                    .foregroundStyle(LearnAlertStyle.textSecondary)
            }
            Spacer()
        }
        .foregroundStyle(roleColor == .red ? AnyShapeStyle(Color.red) : AnyShapeStyle(LearnAlertStyle.textPrimary))
        .padding(14)
        .contentShape(Rectangle())
    }
}

struct WhatsNewView: View {
    var body: some View {
        ZStack {
            LearnAlertStyle.courseCanvas
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("RELEASE HISTORY")
                        .font(.caption.bold())
                        .foregroundStyle(LearnAlertStyle.textSecondary)

                    ReleaseNotesEntry(
                        version: "1.1.0",
                        badgeText: "Current Version",
                        badgeColor: LearnAlertStyle.appAccentForeground,
                        isCurrent: true,
                        highlights: [
                            .init(title: "Shared decks & profiles", detail: "Discover and share decks, create a character avatar, and show creators some love."),
                            .init(title: "Language decks", detail: "Explore Spanish and Korean vocabulary, grammar, and everyday conversations. Add independent topic decks to your library."),
                            .init(title: "Import from Anki", detail: "Bring your .apkg decks into LearnAlert with images, audio, and custom card layouts."),
                            .init(title: "More ways to make flashcards", detail: "Create image-only cards, animated front-and-back cards, and audio or image answer choices."),
                            .init(title: "Smarter study alerts", detail: "Schedule your decks with individual settings, specific daily times, and improved expandable notification cards.")
                        ]
                    )

                    ReleaseNotesEntry(
                        version: "1.0.0",
                        title: "Release"
                    )
                }
                .padding(20)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("What’s New")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(LearnAlertStyle.courseCanvas, for: .navigationBar)
    }
}

private struct ReleaseNotesHighlight {
    let title: LocalizedStringResource
    let detail: LocalizedStringResource
}

private struct ReleaseNotesEntry: View {
    let version: String
    var title: LocalizedStringResource? = nil
    var detail: LocalizedStringResource? = nil
    var badgeText: String? = nil
    var badgeColor: Color = LearnAlertStyle.appAccentForeground
    var isCurrent: Bool = false
    var highlights: [ReleaseNotesHighlight] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(version)
                    .font(.custom("Poppins-SemiBold", size: 16))

                if let badgeText {
                    Text(badgeText)
                        .font(.custom("Poppins-SemiBold", size: 10))
                        .foregroundStyle(badgeColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(badgeColor.opacity(0.14), in: Capsule())
                }

                Spacer()
            }

            if let title {
                Text(title)
                    .font(.custom("Poppins-Medium", size: 13))
                    .foregroundStyle(LearnAlertStyle.textSecondary)
            }

            if let detail, !detail.key.isEmpty {
                Text(detail)
                    .font(.custom("Poppins-Regular", size: 12))
                    .foregroundStyle(LearnAlertStyle.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !highlights.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(highlights.indices, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(highlights[index].title)
                                .font(.custom("Poppins-Medium", size: 13))
                            Text(highlights[index].detail)
                                .font(.custom("Poppins-Regular", size: 12))
                                .foregroundStyle(LearnAlertStyle.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(LearnAlertStyle.textPrimary)
        .padding(14)
        .settingsGlassSurface(cornerRadius: 16)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isCurrent ? LearnAlertStyle.appAccent.opacity(0.45) : Color.clear, lineWidth: 1.2)
        )
    }
}

// MARK: - Mail Composer Representable
struct MailComposeView: UIViewControllerRepresentable {
    let recipient: String
    let subject: String
    let body: String
    let onFinish: (MFMailComposeResult) -> Void

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: MailComposeView

        init(parent: MailComposeView) {
            self.parent = parent
        }

        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            controller.dismiss(animated: true) {
                self.parent.onFinish(result)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setToRecipients([recipient])
        composer.setSubject(subject)
        composer.setMessageBody(body, isHTML: false)
        return composer
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
}

// MARK: - Feedback View
struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var feedbackText = ""
    @State private var showingInAppMail = false
    @State private var showingFallbackOptions = false
    @State private var copiedMessage = false
    @State private var copiedEmail = false
    @State private var sentSuccessAlert = false

    private let supportEmail = "contact@learnalertapp.com"

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    private var formattedEmailBody: String {
        let deviceModel = UIDevice.current.model
        let sysVersion = UIDevice.current.systemVersion
        let userContent = feedbackText.trimmingCharacters(in: .whitespacesAndNewlines)
        return """
        \(userContent.isEmpty ? "[Please describe your thoughts or issue here]" : userContent)

        ---
        App: LearnAlert v\(appVersion) (\(buildNumber))
        Device: \(deviceModel), iOS \(sysVersion)
        """
    }

    var body: some View {
        ZStack {
            LearnAlertStyle.courseCanvas
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("SHARE YOUR THOUGHTS")
                            .font(.caption.bold())
                            .foregroundStyle(LearnAlertStyle.textSecondary)

                        Text("We would love to hear your ideas, feedback, or any issues you encounter. Your input directly shapes upcoming updates.")
                            .font(.custom("Poppins-Regular", size: 13, relativeTo: .subheadline))
                            .foregroundStyle(LearnAlertStyle.textPrimary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("YOUR MESSAGE")
                            .font(.caption.bold())
                            .foregroundStyle(LearnAlertStyle.textSecondary)

                        ZStack(alignment: .topLeading) {
                            if feedbackText.isEmpty {
                                Text("Tell us what is on your mind...")
                                    .font(.custom("Poppins-Regular", size: 14))
                                    .foregroundStyle(LearnAlertStyle.textSecondary.opacity(0.7))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .allowsHitTesting(false)
                            }

                            TextEditor(text: $feedbackText)
                                .scrollContentBackground(.hidden)
                                .font(.custom("Poppins-Regular", size: 14))
                                .foregroundStyle(LearnAlertStyle.textPrimary)
                                .padding(12)
                                .frame(minHeight: 150)
                        }
                        .settingsGlassSurface(cornerRadius: 16)
                    }

                    // Main Action: Continue to email
                    Button(action: handleContinueToEmail) {
                        HStack(spacing: 8) {
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 15, weight: .semibold))
                            Text("Continue to email")
                                .font(.custom("Poppins-SemiBold", size: 15, relativeTo: .body))
                        }
                        .foregroundStyle(LearnAlertStyle.appAccentInk)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(LearnAlertStyle.appAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: LearnAlertStyle.appAccent.opacity(0.35), radius: 10, y: 4)
                    }
                    .buttonStyle(.plain)

                    // Fallback Options if email client is unavailable
                    if showingFallbackOptions {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundStyle(LearnAlertStyle.appAccentForeground)
                                Text("No Email App Found")
                                    .font(.custom("Poppins-SemiBold", size: 13))
                                    .foregroundStyle(LearnAlertStyle.textPrimary)
                            }

                            Text("We couldn’t open an email composer automatically. Your message is safely kept above. You can copy your message and support email below to send via your webmail or preferred client:")
                                .font(.custom("Poppins-Regular", size: 12))
                                .foregroundStyle(LearnAlertStyle.textSecondary)
                                .lineSpacing(2)

                            HStack(spacing: 10) {
                                Button {
                                    UIPasteboard.general.string = formattedEmailBody
                                    withAnimation(.snappy) { copiedMessage = true }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        withAnimation(.snappy) { copiedMessage = false }
                                    }
                                } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: copiedMessage ? "checkmark" : "doc.on.doc")
                                            .font(.system(size: 11, weight: .semibold))
                                        Text(copiedMessage ? "Copied!" : "Copy message")
                                            .font(.custom("Poppins-Medium", size: 12))
                                    }
                                    .foregroundStyle(LearnAlertStyle.textPrimary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 38)
                                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)

                                Button {
                                    UIPasteboard.general.string = supportEmail
                                    withAnimation(.snappy) { copiedEmail = true }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        withAnimation(.snappy) { copiedEmail = false }
                                    }
                                } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: copiedEmail ? "checkmark" : "envelope")
                                            .font(.system(size: 11, weight: .semibold))
                                        Text(copiedEmail ? "Copied!" : "Copy support email")
                                            .font(.custom("Poppins-Medium", size: 12))
                                    }
                                    .foregroundStyle(LearnAlertStyle.textPrimary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 38)
                                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(14)
                        .settingsGlassSurface(cornerRadius: 14)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // Direct Support Email Link
                    VStack(spacing: 6) {
                        Text("Or email us directly at:")
                            .font(.custom("Poppins-Medium", size: 13, relativeTo: .subheadline))
                            .foregroundStyle(LearnAlertStyle.textSecondary)

                        Button {
                            UIPasteboard.general.string = supportEmail
                            withAnimation(.snappy) { copiedEmail = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation(.snappy) { copiedEmail = false }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: copiedEmail ? "checkmark.circle.fill" : "envelope.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                Text(copiedEmail ? "Email Copied to Clipboard!" : supportEmail)
                                    .font(.custom("Poppins-SemiBold", size: 15, relativeTo: .body))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.70)
                            }
                            .foregroundStyle(LearnAlertStyle.appAccentForeground)
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 10)
                }
                .padding(20)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("Send Feedback")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(LearnAlertStyle.courseCanvas, for: .navigationBar)
        .sheet(isPresented: $showingInAppMail) {
            MailComposeView(
                recipient: supportEmail,
                subject: "LearnAlert User Feedback",
                body: formattedEmailBody,
                onFinish: { result in
                    if result == .sent {
                        feedbackText = ""
                        sentSuccessAlert = true
                    }
                }
            )
        }
        .alert("Feedback Sent", isPresented: $sentSuccessAlert) {
            Button("Done") { dismiss() }
        } message: {
            Text("Thank you for your feedback! It helps us improve LearnAlert.")
        }
    }

    private func handleContinueToEmail() {
        // 1. Check if Apple’s in-app mail composer is available on device
        if MFMailComposeViewController.canSendMail() {
            showingInAppMail = true
            return
        }

        // 2. Otherwise, attempt to open the system default email app via mailto
        let subject = "LearnAlert User Feedback"
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: formattedEmailBody)
        ]

        if let mailtoURL = components.url, UIApplication.shared.canOpenURL(mailtoURL) {
            UIApplication.shared.open(mailtoURL, options: [:]) { success in
                if !success {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) {
                        showingFallbackOptions = true
                    }
                }
            }
        } else {
            // 3. If that fails, show clear fallback UI with Copy message & Copy support email
            withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) {
                showingFallbackOptions = true
            }
        }
    }
}

