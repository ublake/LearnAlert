import SwiftUI
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
                HStack(spacing: 6) {
                    Text("Version \(version)")
                    Text("BETA")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(0.7)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(LearnAlertStyle.indigo.opacity(0.12))
                        .clipShape(Capsule())
                }
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
    let isScheduleActive: Bool
    let activeDeckName: String
    let nextAlertDate: Date?
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

            VStack(spacing: 12) {
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

                Divider().opacity(0.45)

                HStack(spacing: 12) {
                    Image(systemName: isScheduleActive ? "clock.badge.checkmark.fill" : "clock")
                        .foregroundStyle(isScheduleActive ? LearnAlertStyle.indigo : LearnAlertStyle.textSecondary)
                        .frame(width: 30)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(isScheduleActive ? activeDeckName : "No active schedule")
                            .font(.custom("Poppins-Medium", size: 13))
                            .foregroundStyle(LearnAlertStyle.textPrimary)
                            .lineLimit(1)
                        if let nextAlertDate {
                            Text("Next · \(nextAlertDate.formatted(date: .omitted, time: .shortened))")
                                .font(.custom("Poppins-Regular", size: 10))
                                .foregroundStyle(LearnAlertStyle.textSecondary)
                        }
                    }

                    Spacer()

                    Circle()
                        .fill(isScheduleActive ? LearnAlertStyle.aqua : LearnAlertStyle.textSecondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
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

    private var stopLabel: String {
        switch engine.stopCondition {
        case "Until Deck Learnt": return "Deck learnt"
        case "Until Day Ends": return "Day ends"
        default: return "Manually"
        }
    }
}

struct SettingsNotificationSection: View {
    @ObservedObject var engine: StudyEngine
    @Binding var alertSound: String
    @Binding var reduceEffects: Bool
    let availableSounds: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("NOTIFICATIONS")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    SettingsRowIcon(systemName: "clock.fill")
                    Text("Default window")
                        .font(.custom("Poppins-Medium", size: 13))
                    Spacer()
                    Menu {
                        Picker("Start time", selection: $engine.startHour) {
                            ForEach(0...23, id: \.self) { hour in
                                Text(hourLabel(hour)).tag(hour)
                            }
                        }
                    } label: {
                        SettingsMenuLabel(text: hourLabel(engine.startHour))
                    }
                    Text("–")
                        .foregroundStyle(LearnAlertStyle.textSecondary)
                    Menu {
                        Picker("End time", selection: $engine.endHour) {
                            ForEach(0...23, id: \.self) { hour in
                                if hour != engine.startHour {
                                    Text(hourLabel(hour)).tag(hour)
                                }
                            }
                        }
                    } label: {
                        SettingsMenuLabel(text: hourLabel(engine.endHour))
                    }
                }
                .padding(14)

                Divider().padding(.leading, 50).opacity(0.45)

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
                    Menu {
                        Picker("Alert sound", selection: $alertSound) {
                            ForEach(availableSounds, id: \.self) { sound in
                                Text(soundLabel(sound)).tag(sound)
                            }
                        }
                    } label: {
                        SettingsMenuLabel(text: soundLabel(alertSound))
                    }
                }
                .padding(14)

                Divider().padding(.leading, 50).opacity(0.45)

                SettingsToggleRow(
                    title: "Reduce Effects",
                    subtitle: "Calm decorative motion and reflections",
                    systemImage: "circle.lefthalf.filled",
                    isOn: $reduceEffects
                )
            }
            .foregroundStyle(LearnAlertStyle.textPrimary)
            .nativeGlass(cornerRadius: 16)
        }
        .padding(.horizontal)
        .onChange(of: engine.startHour) { _, startHour in
            if engine.endHour == startHour {
                engine.endHour = (startHour + 1) % 24
            }
        }
    }

    private func hourLabel(_ hour: Int) -> String {
        Calendar.current.date(from: DateComponents(hour: hour))?.formatted(date: .omitted, time: .shortened) ?? "\(hour):00"
    }

    private func soundLabel(_ sound: String) -> String {
        guard sound != "Default" else { return sound }
        let number = sound.replacingOccurrences(of: "alert", with: "").replacingOccurrences(of: ".wav", with: "")
        return "Sound \(number)"
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

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(LearnAlertStyle.indigo)
            .frame(width: 28, height: 28)
            .background(LearnAlertStyle.courseLavender)
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

    init(title: LocalizedStringResource, subtitle: LocalizedStringResource? = nil, systemImage: String) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
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
        .padding(14)
        .foregroundStyle(LearnAlertStyle.textPrimary)
        .interactiveGlass(cornerRadius: 16)
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
            Label("LearnAlert Beta", systemImage: "info.circle.fill")
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

struct WhatsNewView: View {
    var body: some View {
        ZStack {
            CoursezyBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.largeTitle)
                            .foregroundStyle(LearnAlertStyle.indigo)
                        Text("Built for better study moments")
                            .font(.custom("Poppins-SemiBold", size: 22))
                        Text("Thanks for helping test LearnAlert. Here’s what’s new in this beta.")
                            .font(.custom("Poppins-Regular", size: 13))
                            .foregroundStyle(LearnAlertStyle.textSecondary)
                    }
                    .coursezyCard()

                    WhatsNewItem(icon: "sparkles.rectangle.stack.fill", title: "LearnAlert AI", detail: "Chat naturally, upload study material, and review a temporary deck before saving.")
                    WhatsNewItem(icon: "bell.and.waves.left.and.right.fill", title: "Smarter alerts", detail: "Schedule real cards, preview sounds, and follow upcoming notifications from the live timeline.")
                    WhatsNewItem(icon: "square.grid.2x2.fill", title: "More ways to learn", detail: "Practice with reveal, quiz, type-to-answer, and matching cards.")
                    WhatsNewItem(icon: "books.vertical.fill", title: "Expanded Discover", detail: "Explore larger language collections and ready-made study decks.")

                    Text("Beta software may still have rough edges. Please use Help to report anything that doesn’t feel right.")
                        .font(.custom("Poppins-Regular", size: 11))
                        .foregroundStyle(LearnAlertStyle.textSecondary)
                        .padding(.horizontal, 4)
                }
                .padding(20)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("What’s New")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct WhatsNewItem: View {
    let icon: String
    let title: LocalizedStringResource
    let detail: LocalizedStringResource

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            SettingsRowIcon(systemName: icon)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.custom("Poppins-SemiBold", size: 14))
                Text(detail)
                    .font(.custom("Poppins-Regular", size: 11))
                    .foregroundStyle(LearnAlertStyle.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .foregroundStyle(LearnAlertStyle.textPrimary)
        .coursezyCard(cornerRadius: 16, padding: 14)
    }
}
