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
    let onAllow: () -> Void
    let onStudyInAppOnly: () -> Void
    let onOpenSettings: () -> Void

    @State private var isRequesting = false
    @State private var isSettingsDenied = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            // Semi-transparent backdrop
            Color.black.opacity(0.60)
                .ignoresSafeArea()
                .onTapGesture {
                    onStudyInAppOnly()
                }

            // Centered Modal Box
            VStack {
                Spacer()

                VStack(spacing: 18) {
                    // Visual Icon
                    ZStack {
                        Circle()
                            .fill(LearnAlertStyle.indigo.opacity(0.18))
                            .frame(width: 64, height: 64)

                        Circle()
                            .stroke(LearnAlertStyle.indigo.opacity(0.35), lineWidth: 1.5)
                            .frame(width: 64, height: 64)

                        Image(systemName: isSettingsDenied ? "bell.slash.fill" : "bell.badge.fill")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: isSettingsDenied
                                        ? [Color.orange, Color.red]
                                        : [Color(red: 0.35, green: 0.70, blue: 1.0), LearnAlertStyle.indigo],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .padding(.top, 4)

                    // Header Text
                    VStack(spacing: 6) {
                        Text(isSettingsDenied ? "Notifications Disabled" : "Enable Notifications")
                            .font(.custom("Poppins-SemiBold", size: 20))
                            .foregroundStyle(Color.white)
                            .multilineTextAlignment(.center)

                        Text(
                            isSettingsDenied
                                ? "Alerts are currently turned off in iOS Settings. You can enable them to receive lock screen cards, or continue studying in-app."
                                : "Receive spaced repetition flashcards directly on your lock screen throughout the day."
                        )
                        .font(.custom("Poppins-Regular", size: 13))
                        .foregroundStyle(Color.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 6)
                    }

                    // Action Buttons
                    VStack(spacing: 10) {
                        if isSettingsDenied {
                            Button {
                                onOpenSettings()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "gearshape.fill")
                                        .font(.system(size: 14, weight: .bold))
                                    Text("Open iOS Settings")
                                        .font(.custom("Poppins-SemiBold", size: 15))
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .foregroundStyle(.white)
                                .background(LearnAlertStyle.indigo)
                                .clipShape(Capsule())
                                .shadow(color: LearnAlertStyle.indigo.opacity(0.40), radius: 8, y: 3)
                            }
                        } else {
                            Button {
                                isRequesting = true
                                Task { @MainActor in
                                    let granted = await NotificationManager.shared.requestPermission()
                                    isRequesting = false
                                    if granted {
                                        HapticFeedback.success()
                                        onAllow()
                                    } else {
                                        HapticFeedback.warning()
                                        isSettingsDenied = true
                                    }
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    if isRequesting {
                                        ProgressView().tint(.white)
                                    } else {
                                        Image(systemName: "bell.fill")
                                            .font(.system(size: 14, weight: .bold))
                                    }
                                    Text("Allow Notifications")
                                        .font(.custom("Poppins-SemiBold", size: 15))
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .foregroundStyle(.white)
                                .background(LearnAlertStyle.indigo)
                                .clipShape(Capsule())
                                .shadow(color: LearnAlertStyle.indigo.opacity(0.40), radius: 8, y: 3)
                            }
                            .disabled(isRequesting)
                        }

                        Button {
                            onStudyInAppOnly()
                        } label: {
                            Text("Study In-App")
                                .font(.custom("Poppins-Medium", size: 14))
                                .foregroundStyle(Color.white.opacity(0.65))
                                .padding(.vertical, 4)
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 24)
                .background(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(Color(red: 0.10, green: 0.12, blue: 0.20))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.55), radius: 26, y: 10)
                .padding(.horizontal, 22)

                Spacer()
            }
        }
        .task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            if settings.authorizationStatus == .denied {
                isSettingsDenied = true
            }
        }
        .preferredColorScheme(.dark)
    }
}
