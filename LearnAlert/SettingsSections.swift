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
                    .tint(LearnAlertStyle.indigo)
            }
            .padding(15)
            .nativeGlass(cornerRadius: 16)
        }
        .padding(.horizontal)
    }
}

struct SettingsLearningSection: View {
    @ObservedObject var engine: StudyEngine

    private var volumeLabel: String {
        engine.volumeSelectionIndex == 5 ? "Custom · \(engine.customVolume)" : "\(engine.activeVolume) cards"
    }

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

                HStack(spacing: 12) {
                    SettingsRowIcon(systemName: "rectangle.stack.fill")
                    Text("Cards per session")
                        .font(.custom("Poppins-Medium", size: 13))
                    Spacer()
                    Menu {
                        Picker("Cards per session", selection: $engine.volumeSelectionIndex) {
                            ForEach(Array(engine.volumeOptions.enumerated()), id: \.offset) { index, count in
                                Text("\(count) cards").tag(index)
                            }
                            Text("Custom").tag(5)
                        }
                    } label: {
                        SettingsMenuLabel(text: volumeLabel)
                    }
                }
                .padding(14)

                if engine.volumeSelectionIndex == 5 {
                    Divider().padding(.leading, 50).opacity(0.45)
                    Stepper(value: $engine.customVolume, in: 1...50) {
                        Text("Custom amount · \(engine.customVolume)")
                            .font(.custom("Poppins-Regular", size: 12))
                    }
                    .padding(14)
                }

                Divider().padding(.leading, 50).opacity(0.45)

                HStack(spacing: 12) {
                    SettingsRowIcon(systemName: "sun.max.fill")
                    Text("Starts receiving")
                        .font(.custom("Poppins-Medium", size: 13))
                    Spacer()
                    DatePicker("", selection: startTimeBinding, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .tint(LearnAlertStyle.indigo)
                }
                .padding(14)

                Divider().padding(.leading, 50).opacity(0.45)

                HStack(spacing: 12) {
                    SettingsRowIcon(systemName: "moon.stars.fill")
                    Text("Finishes receiving")
                        .font(.custom("Poppins-Medium", size: 13))
                    Spacer()
                    DatePicker("", selection: endTimeBinding, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .tint(LearnAlertStyle.indigo)
                }
                .padding(14)

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
                            Text("Manually").tag("Until I say so")
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
    }

    private var startTimeBinding: Binding<Date> {
        Binding<Date>(
            get: {
                Calendar.current.date(
                    bySettingHour: engine.startHour,
                    minute: engine.startMinute,
                    second: 0,
                    of: Date()
                ) ?? Date()
            },
            set: { newDate in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                if let hour = components.hour { engine.startHour = hour }
                if let minute = components.minute { engine.startMinute = minute }
            }
        )
    }

    private var endTimeBinding: Binding<Date> {
        Binding<Date>(
            get: {
                Calendar.current.date(
                    bySettingHour: engine.endHour,
                    minute: engine.endMinute,
                    second: 0,
                    of: Date()
                ) ?? Date()
            },
            set: { newDate in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                if let hour = components.hour { engine.endHour = hour }
                if let minute = components.minute { engine.endMinute = minute }
            }
        )
    }

    private var stopLabel: String {
        switch engine.stopCondition {
        case "Until Deck Learnt": return "Deck learnt"
        case "Until Day Ends": return "Day ends"
        default: return "Manually"
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
                .tint(LearnAlertStyle.indigo)
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
                .tint(LearnAlertStyle.indigo)
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
        .tint(LearnAlertStyle.indigo)
        .padding(14)
    }
}

private struct SettingsRowIcon: View {
    let systemName: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(LearnAlertStyle.sky)
            .frame(width: 28, height: 28)
            .background(colorScheme == .dark ? Color.white.opacity(0.08) : LearnAlertStyle.courseLavender)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
        .foregroundStyle(LearnAlertStyle.indigo)
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
                ? AnyShapeStyle(LearnAlertStyle.indigo)
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
            Text("PREFERENCES")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    SettingsRowIcon(systemName: "speaker.wave.2.fill")
                    Text("Alert Sound")
                        .font(.custom("Poppins-Medium", size: 13, relativeTo: .body))
                    Spacer()
                    Picker("Alert Sound", selection: $alertSound) {
                        ForEach(availableSounds) { sound in
                            Text(sound.name).tag(sound.id)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .tint(LearnAlertStyle.figmaBlue)
                }
                .padding(14)

                settingsDivider

                HStack(spacing: 12) {
                    SettingsRowIcon(systemName: "circle.lefthalf.filled")
                    Text("Appearance")
                        .font(.custom("Poppins-Medium", size: 13, relativeTo: .body))
                    Spacer()
                    Picker("Appearance", selection: $appearanceMode) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .tint(LearnAlertStyle.figmaBlue)
                }
                .padding(14)

                settingsDivider

                HStack(spacing: 12) {
                    SettingsRowIcon(systemName: "eyes")
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Release the Card Gremlins")
                            .font(.custom("Poppins-Medium", size: 13, relativeTo: .body))
                        Text("Give your deck stacks tiny faces.")
                            .font(.custom("Poppins-Regular", size: 10, relativeTo: .caption))
                            .foregroundStyle(LearnAlertStyle.textSecondary)
                    }
                    Spacer()
                    Toggle("Release the Card Gremlins", isOn: $deckCreaturesHaveFaces)
                        .labelsHidden()
                        .tint(LearnAlertStyle.figmaBlue)
                }
                .padding(14)
            }
            .foregroundStyle(LearnAlertStyle.textPrimary)
            .settingsGlassSurface(cornerRadius: 18)
        }
        .padding(.horizontal)
    }

    private var settingsDivider: some View {
        Divider().padding(.leading, 54).opacity(0.45)
    }

    private func soundLabel(_ sound: String) -> String {
        AlertSoundOption.displayName(for: sound)
    }
}

struct SettingsSupportGroup: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("INFORMATION")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

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

                NavigationLink {
                    TermsOfServiceView()
                } label: {
                    SettingsGroupedRow(title: "Terms and Conditions", systemImage: "doc.text.fill")
                }

                settingsDivider

                NavigationLink {
                    PrivacyPolicyView()
                } label: {
                    SettingsGroupedRow(title: "Privacy Policy", systemImage: "lock.shield.fill")
                }

                settingsDivider

                NavigationLink {
                    HelpView()
                } label: {
                    SettingsGroupedRow(title: "Help", systemImage: "questionmark.circle.fill")
                }
            }
            .foregroundStyle(LearnAlertStyle.textPrimary)
            .settingsGlassSurface(cornerRadius: 18)
        }
        .padding(.horizontal)
    }

    private var settingsDivider: some View {
        Divider().padding(.leading, 54).opacity(0.45)
    }
}

private struct SettingsGroupedRow: View {
    let title: LocalizedStringResource
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            SettingsRowIcon(systemName: systemImage)
            Text(title)
                .font(.custom("Poppins-Medium", size: 13, relativeTo: .body))
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(LearnAlertStyle.textSecondary)
        }
        .padding(14)
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
    @State private var deletedCardsCount = 0
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
                                roleColor: LearnAlertStyle.figmaBlue
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
        .sheet(isPresented: $showingDataShare) {
            if let exportedDataURL {
                ActivityShareSheet(items: [exportedDataURL])
            }
        }
    }

    private var deletionProgressOverlay: some View {
        ZStack {
            Color.black.opacity(0.65)
                .ignoresSafeArea()
                .transition(.opacity)

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.18))
                        .frame(width: 64, height: 64)

                    Image(systemName: "trash.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Color.red)
                }

                VStack(spacing: 6) {
                    Text("Deleting Decks & Cards")
                        .font(.custom("Poppins-SemiBold", size: 17))
                        .foregroundStyle(Color.white)

                    Text("Permanently removing local cards and decks...")
                        .font(.custom("Poppins-Regular", size: 12))
                        .foregroundStyle(Color.white.opacity(0.7))
                }

                VStack(spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Deleting cards:")
                            .font(.custom("Poppins-Medium", size: 13))
                            .foregroundStyle(Color.white.opacity(0.8))

                        Spacer()

                        HStack(spacing: 2) {
                            Text("\(deletedCardsCount)")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.red)
                            Text(" / \(totalCardsToDelete)")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.7))
                        }
                        .contentTransition(.numericText())
                    }

                    GeometryReader { geo in
                        let progress = totalCardsToDelete > 0
                            ? min(1.0, Double(deletedCardsCount) / Double(totalCardsToDelete))
                            : 1.0
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.12))
                                .frame(height: 10)

                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.red, Color.orange],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(10, geo.size.width * CGFloat(progress)), height: 10)
                                .animation(.easeOut(duration: 0.12), value: progress)
                        }
                    }
                    .frame(height: 10)

                    HStack {
                        let pct = totalCardsToDelete > 0
                            ? Int((Double(deletedCardsCount) / Double(totalCardsToDelete)) * 100)
                            : 100
                        Text("\(pct)% completed")
                            .font(.custom("Poppins-Medium", size: 11))
                            .foregroundStyle(Color.white.opacity(0.55))

                        Spacer()
                    }
                }
                .padding(.horizontal, 4)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(red: 0.12, green: 0.12, blue: 0.14))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.5), radius: 30, y: 10)
            .padding(.horizontal, 32)
            .transition(.scale(scale: 0.9).combined(with: .opacity))
        }
    }

    private func executeDeleteAllDecks() {
        let decksToDelete = Array(decks)
        let totalDecks = decksToDelete.count
        let totalCards = decksToDelete.reduce(0) { $0 + $1.cards.count }

        totalCardsToDelete = totalCards
        deletedCardsCount = 0

        guard totalCards > 0 || totalDecks > 0 else {
            completedSummaryMessage = "No decks or cards found to delete."
            showingDeleteCompleteAlert = true
            return
        }

        isDeletingDecks = true
        HapticFeedback.impact(.medium)
        InteractionSoundPlayer.shared.play(.deleteDeck)

        Task { @MainActor in
            let targetDurationMs = 1200
            let perCardSleepMs = totalCards > 0 ? max(8, min(40, targetDurationMs / totalCards)) : 20

            for deck in decksToDelete {
                let cards = Array(deck.cards)
                for card in cards {
                    context.delete(card)
                    deletedCardsCount += 1
                    HapticFeedback.impact(.light)
                    try? await Task.sleep(for: .milliseconds(perCardSleepMs))
                }
                context.delete(deck)
            }

            try? context.save()
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

            try? await Task.sleep(for: .milliseconds(300))
            isDeletingDecks = false
            HapticFeedback.success()
            InteractionSoundPlayer.shared.play(.correct)
            completedSummaryMessage = "Successfully removed \(totalDecks) \(totalDecks == 1 ? "deck" : "decks") and \(totalCards) \(totalCards == 1 ? "card" : "cards")."
            showingDeleteCompleteAlert = true
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
            CoursezyBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("RELEASE HISTORY")
                        .font(.caption.bold())
                        .foregroundStyle(LearnAlertStyle.textSecondary)

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
    }
}

private struct ReleaseNotesEntry: View {
    let version: String
    let title: LocalizedStringResource
    var detail: LocalizedStringResource? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 13) {
            SettingsRowIcon(systemName: "app.badge.checkmark.fill")
            VStack(alignment: .leading, spacing: 2) {
                Text(version)
                    .font(.custom("Poppins-SemiBold", size: 16))
                Text(title)
                    .font(.custom("Poppins-Medium", size: 13))
                    .foregroundStyle(LearnAlertStyle.textSecondary)
                if let detail, !detail.key.isEmpty {
                    Text(detail)
                        .font(.custom("Poppins-Regular", size: 11))
                        .foregroundStyle(LearnAlertStyle.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
        }
        .foregroundStyle(LearnAlertStyle.textPrimary)
        .coursezyCard(cornerRadius: 16, padding: 14)
    }
}


// MARK: - Feedback View
struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var feedbackText = ""

    var body: some View {
        ZStack {
            // Darkened, calm, sleek background
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.08, blue: 0.12),
                    Color(red: 0.10, green: 0.11, blue: 0.17)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("SHARE YOUR THOUGHTS")
                            .font(.caption.bold())
                            .foregroundStyle(Color.white.opacity(0.65))

                        Text("We would love to hear your ideas, feedback, or any issues you encounter. Your input directly shapes upcoming updates.")
                            .font(.custom("Poppins-Regular", size: 13, relativeTo: .subheadline))
                            .foregroundStyle(Color.white.opacity(0.92))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("YOUR MESSAGE")
                            .font(.caption.bold())
                            .foregroundStyle(Color.white.opacity(0.65))

                        ZStack(alignment: .topLeading) {
                            if feedbackText.isEmpty {
                                Text("Tell us what is on your mind...")
                                    .font(.custom("Poppins-Regular", size: 14))
                                    .foregroundStyle(Color.white.opacity(0.38))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .allowsHitTesting(false)
                            }

                            TextEditor(text: $feedbackText)
                                .scrollContentBackground(.hidden)
                                .font(.custom("Poppins-Regular", size: 14))
                                .foregroundStyle(.white)
                                .padding(12)
                                .frame(minHeight: 150)
                        }
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                        )
                    }

                    Button(action: sendEmail) {
                        Label("Send Feedback", systemImage: "paperplane.fill")
                            .font(.custom("Poppins-SemiBold", size: 15, relativeTo: .body))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .background(LearnAlertStyle.indigo)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: LearnAlertStyle.indigo.opacity(0.35), radius: 10, y: 4)

                    VStack(spacing: 6) {
                        Text("Or email us at:")
                            .font(.custom("Poppins-Medium", size: 14, relativeTo: .subheadline))
                            .foregroundStyle(Color.white.opacity(0.65))

                        Link(destination: URL(string: "mailto:contact@learnalertapp.com")!) {
                            HStack(spacing: 6) {
                                Image(systemName: "envelope.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("contact@learnalertapp.com")
                                    .font(.custom("Poppins-SemiBold", size: 16, relativeTo: .body))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.70)
                                    .allowsTightening(true)
                            }
                            .foregroundStyle(LearnAlertStyle.cyan)
                        }
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
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private func sendEmail() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let subject = "LearnAlert User Feedback"
        let body = feedbackText.isEmpty
            ? "\n\n---\nApp Version: \(version)"
            : "\(feedbackText)\n\n---\nApp Version: \(version)"

        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "LearnAlert%20Feedback"
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        if let url = URL(string: "mailto:contact@learnalertapp.com?subject=\(encodedSubject)&body=\(encodedBody)") {
            openURL(url)
        }
    }
}

