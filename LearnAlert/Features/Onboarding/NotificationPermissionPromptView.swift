//
//  NotificationPermissionPromptView.swift
//  LearnAlert
//
//  Created by Blake Miller on 2/19/26.
//

import SwiftUI
import UserNotifications

struct NotificationPermissionPromptModal: View {
    let targetDeckName: String
    let onSaveAvailability: (Int, Int, Int, Int) -> Void
    let onStudyInAppOnly: () -> Void
    let onOpenSettings: () -> Void
    let onDismiss: () -> Void

    @State private var draft: DeckAlertSettings
    @State private var showingAvailability = false
    @State private var isRequesting = false
    @State private var isSettingsDenied = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    init(
        targetDeckName: String,
        initialSettings: DeckAlertSettings,
        onSaveAvailability: @escaping (Int, Int, Int, Int) -> Void,
        onStudyInAppOnly: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.targetDeckName = targetDeckName
        self.onSaveAvailability = onSaveAvailability
        self.onStudyInAppOnly = onStudyInAppOnly
        self.onOpenSettings = onOpenSettings
        self.onDismiss = onDismiss
        _draft = State(initialValue: initialSettings)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(colorScheme == .dark ? 0.60 : 0.30)
                .ignoresSafeArea()
                .onTapGesture {
                    if !isRequesting { onDismiss() }
                }

            ViewThatFits(in: .vertical) {
                modalContent
                    .fixedSize(horizontal: false, vertical: true)

                ScrollView {
                    modalContent
                }
                .scrollIndicators(.hidden)
            }
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .appCardSurface(cornerRadius: 26, shadow: false)
            .frame(maxWidth: 420)
            .padding(.horizontal, 22)
            .padding(.vertical, 24)
        }
        .task { await refreshPermission() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, !isRequesting else { return }
            Task { await refreshPermission() }
        }
        .accessibilityAction(.escape) {
            if !isRequesting { onDismiss() }
        }
    }

    private var modalContent: some View {
        VStack(spacing: 20) {
            Image(systemName: showingAvailability ? "clock.fill" : isSettingsDenied ? "bell.slash.fill" : "bell.badge.fill")
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(LearnAlertStyle.appAccentForeground)
                .frame(width: 60, height: 60)
                .background(LearnAlertStyle.appAccent.opacity(0.20), in: Circle())

            VStack(spacing: 8) {
                Text(title)
                    .font(.custom("Poppins-SemiBold", size: 20, relativeTo: .title3))
                    .foregroundStyle(LearnAlertStyle.textPrimary)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.custom("Poppins-Regular", size: 13, relativeTo: .subheadline))
                    .foregroundStyle(LearnAlertStyle.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if showingAvailability {
                availabilityFields
            }

            VStack(spacing: 6) {
                Button(action: performPrimaryAction) {
                    HStack(spacing: 8) {
                        if isRequesting {
                            ProgressView().tint(LearnAlertStyle.appAccentInk)
                        } else {
                            Image(systemName: showingAvailability ? "checkmark" : isSettingsDenied ? "gearshape.fill" : "bell.fill")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        Text(primaryActionTitle)
                            .font(.custom("Poppins-SemiBold", size: 15, relativeTo: .headline))
                    }
                    .foregroundStyle(LearnAlertStyle.appAccentInk)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 48)
                    .background(LearnAlertStyle.appAccent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isRequesting)

                HStack(spacing: 12) {
                    Button(action: onDismiss) {
                        Text("Skip")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }

                    Rectangle()
                        .fill(LearnAlertStyle.cardBorder)
                        .frame(width: 1, height: 14)

                    Button(action: onStudyInAppOnly) {
                        Text("Study In-App")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                }
                .font(.custom("Poppins-Medium", size: 13, relativeTo: .subheadline))
                .foregroundStyle(LearnAlertStyle.textSecondary)
                .buttonStyle(.plain)
                .disabled(isRequesting)
            }
        }
        .padding(24)
    }

    private var title: String {
        if showingAvailability {
            return AppLocalization.string("When are you available?")
        }
        return AppLocalization.string(isSettingsDenied ? "Notifications Disabled" : "Enable Notifications")
    }

    private var message: String {
        if showingAvailability {
            return AppLocalization.string("Choose a daily time range for your alerts. You can change it anytime in Alert Settings.")
        }
        return AppLocalization.string(
            isSettingsDenied
                ? "Alerts are currently turned off in iOS Settings. You can enable them to receive lock screen cards, or continue studying in-app."
                : "Receive spaced repetition flashcards directly on your lock screen throughout the day."
        )
    }

    private var primaryActionTitle: LocalizedStringKey {
        if showingAvailability { return "Save" }
        return isSettingsDenied ? "Open iOS Settings" : "Allow Notifications"
    }

    private var availabilityFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(targetDeckName)
                .font(.custom("Poppins-Medium", size: 12, relativeTo: .caption))
                .foregroundStyle(LearnAlertStyle.textSecondary)
                .lineLimit(2)

            VStack(spacing: 14) {
                DatePicker("Starts daily", selection: time(hour: \.startHour, minute: \.startMinute), displayedComponents: .hourAndMinute)

                Rectangle()
                    .fill(LearnAlertStyle.cardBorder)
                    .frame(height: 1)

                DatePicker("Finishes daily", selection: time(hour: \.endHour, minute: \.endMinute), displayedComponents: .hourAndMinute)
            }
            .datePickerStyle(.compact)
            .font(.custom("Poppins-Medium", size: 13, relativeTo: .subheadline))
            .foregroundStyle(LearnAlertStyle.textPrimary)
            .tint(LearnAlertStyle.appAccentForeground)
            .padding(14)
            .background(LearnAlertStyle.insetSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            if draft.endHour * 60 + draft.endMinute <= draft.startHour * 60 + draft.startMinute {
                Text("Ends the next day")
                    .font(.custom("Poppins-Regular", size: 11, relativeTo: .caption))
                    .foregroundStyle(LearnAlertStyle.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func time(
        hour: WritableKeyPath<DeckAlertSettings, Int>,
        minute: WritableKeyPath<DeckAlertSettings, Int>
    ) -> Binding<Date> {
        Binding(get: {
            Calendar.current.date(
                bySettingHour: draft[keyPath: hour],
                minute: draft[keyPath: minute],
                second: 0,
                of: Date()
            ) ?? Date()
        }, set: { date in
            draft[keyPath: hour] = Calendar.current.component(.hour, from: date)
            draft[keyPath: minute] = Calendar.current.component(.minute, from: date)
        })
    }

    private func performPrimaryAction() {
        if showingAvailability {
            onSaveAvailability(draft.startHour, draft.startMinute, draft.endHour, draft.endMinute)
        } else if isSettingsDenied {
            onOpenSettings()
        } else {
            isRequesting = true
            Task { @MainActor in
                let granted = await NotificationManager.shared.requestPermission()
                isRequesting = false
                if granted {
                    HapticFeedback.success()
                    withAnimation(.snappy) {
                        isSettingsDenied = false
                        showingAvailability = true
                    }
                } else {
                    HapticFeedback.warning()
                    isSettingsDenied = true
                }
            }
        }
    }

    @MainActor
    private func refreshPermission() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard !isRequesting else { return }
        withAnimation(.snappy) {
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                isSettingsDenied = false
                showingAvailability = true
            case .denied:
                isSettingsDenied = true
                showingAvailability = false
            case .notDetermined:
                isSettingsDenied = false
                showingAvailability = false
            @unknown default:
                break
            }
        }
    }
}
