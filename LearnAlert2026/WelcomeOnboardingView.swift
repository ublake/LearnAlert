import SwiftUI
import UserNotifications

struct WelcomeOnboardingView: View {
    @Environment(\.openURL) private var openURL
    @State private var page = 0
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var isRequestingPermission = false
    @State private var tutorialStep = 0
    @State private var showingFreeReveal = false

    let completion: () -> Void

    var body: some View {
        ZStack {
            LearnAlertBackground(emphasized: true)

            switch page {
            case 0:
                permissionPage
                    .transition(.opacity)
            case 1:
                AlertsTutorialView(step: $tutorialStep) {
                    withAnimation(.snappy) { page = 2 }
                }
                .transition(.opacity)
            default:
                FakePaywallView()
                    .transition(.opacity)
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await refreshNotificationStatus()
        }
        .task(id: page) {
            guard page == 2 else { return }
            try? await Task.sleep(for: .seconds(2))
            showingFreeReveal = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Task { await refreshNotificationStatus() }
        }
        .alert("Okay, we’re kidding 😂", isPresented: $showingFreeReveal) {
            Button("Let’s learn") {
                completion()
            }
        } message: {
            Text("LearnAlert has no ads, no subscriptions, and costs $0. It’s 100% free.")
        }
    }

    private var permissionPage: some View {
        VStack(spacing: 24) {
            HStack(spacing: 7) {
                Capsule().fill(Color.white).frame(height: 5)
                Capsule().fill(Color.white.opacity(0.25)).frame(height: 5)
                Capsule().fill(Color.white.opacity(0.25)).frame(height: 5)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            Spacer()

            Image(systemName: notificationStatus == .authorized ? "bell.badge.fill" : "bell.fill")
                .font(.system(size: 68))
                .foregroundStyle(notificationStatus == .authorized ? LearnAlertStyle.lime : .white)

            VStack(spacing: 10) {
                Text(notificationStatus == .authorized ? "Notifications enabled" : "First, enable notifications")
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)

                Text("LearnAlert teaches through timely flashcards, so notifications are required for the experience.")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.72))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 28)

            if notificationStatus == .authorized {
                Label("Ready for the tutorial", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(LearnAlertStyle.lime)
            } else {
                Button(action: notificationStatus == .denied ? openSystemSettings : requestNotificationPermission) {
                    Label(
                        notificationStatus == .denied ? "Open Settings" : "Allow Notifications",
                        systemImage: notificationStatus == .denied ? "gear" : "bell.badge"
                    )
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
                .foregroundStyle(.white)
                .interactiveGlass(cornerRadius: 16, tint: LearnAlertStyle.indigo)
                .disabled(isRequestingPermission)
                .padding(.horizontal, 28)
            }

            Spacer()

            Button("Start Tutorial") {
                withAnimation(.snappy) { page = 1 }
            }
            .font(.headline)
            .foregroundStyle(LearnAlertStyle.indigoDeep)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .disabled(notificationStatus != .authorized)
            .opacity(notificationStatus == .authorized ? 1 : 0.38)
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .foregroundStyle(.white)
    }

    @MainActor
    private func requestNotificationPermission() {
        isRequestingPermission = true
        Task {
            _ = await NotificationManager.shared.requestPermission()
            await refreshNotificationStatus()
            isRequestingPermission = false
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }

    @MainActor
    private func refreshNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationStatus = settings.authorizationStatus
    }
}

private struct AlertsTutorialView: View {
    @Binding var step: Int
    let completion: () -> Void

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Alerts Setup")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.top, 10)

                    TutorialCallout(text: instruction, direction: step == 5 ? "arrow.down" : "arrow.down.right")

                    tutorialControl(stepNumber: 0) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("SELECT DECK").font(.caption.bold()).foregroundStyle(.white.opacity(0.65))
                                Text("Mental Math").font(.headline)
                            }
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                        }
                    }

                    VStack(spacing: 0) {
                        tutorialControl(stepNumber: 1) {
                            TutorialSettingRow(title: "Stop Alerts", value: "Until Deck Learnt")
                        }
                        Divider().overlay(Color.white.opacity(0.16))
                        tutorialControl(stepNumber: 2) {
                            TutorialSettingRow(title: "Time Range", value: "10:00 to 19:00")
                        }
                    }
                    .interactiveGlass(cornerRadius: 18, tint: LearnAlertStyle.indigoDeep.opacity(0.35))

                    tutorialControl(stepNumber: 3) {
                        VStack(alignment: .leading, spacing: 13) {
                            HStack {
                                Text("DAILY VOLUME").font(.caption.bold())
                                Spacer()
                                Text("10 cards").font(.headline)
                            }
                            HStack(spacing: 0) {
                                ForEach(["3", "5", "7", "10", "15", "…"], id: \.self) { amount in
                                    Text(amount)
                                        .font(.subheadline.bold())
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(amount == "10" ? Color.white.opacity(0.22) : Color.clear)
                                }
                            }
                            .background(LearnAlertStyle.indigoDeep.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 11))
                        }
                    }

                    tutorialControl(stepNumber: 4) {
                        Label("Start Alerts", systemImage: "paperplane.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(LearnAlertStyle.indigo)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.bottom, 160)
            }

            if step >= 5 {
                Color.black.opacity(0.22).ignoresSafeArea()

                FakeTutorialNotification(step: $step, completion: completion)
                    .padding(.horizontal, 18)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private var instruction: String {
        switch step {
        case 0: return "Tap the deck picker. Mental Math is ready for you."
        case 1: return "This decides when your alert session stops."
        case 2: return "Choose the hours when learning alerts may arrive."
        case 3: return "Daily Volume controls how many cards you’ll see."
        case 4: return "Start Alerts schedules the session."
        case 5: return "A notification appears. Swipe down on it to expand."
        default: return "Answer without opening the app."
        }
    }

    private func tutorialControl<Content: View>(
        stepNumber: Int,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Button {
            guard step == stepNumber else { return }
            withAnimation(.snappy) { step += 1 }
        } label: {
            content()
                .padding(16)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .interactiveGlass(cornerRadius: 18, tint: LearnAlertStyle.indigoDeep.opacity(0.28))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(step == stepNumber ? Color.white : Color.white.opacity(0.12), lineWidth: step == stepNumber ? 3 : 1)
                .shadow(color: step == stepNumber ? Color.white.opacity(0.55) : .clear, radius: 10)
        )
        .disabled(step != stepNumber)
        .opacity(step < stepNumber ? 0.62 : 1)
    }
}

private struct TutorialSettingRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.white.opacity(0.72))
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}

private struct TutorialCallout: View {
    let text: String
    let direction: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: direction)
                .font(.title2.bold())
            Text(text)
                .font(.headline)
            Spacer()
        }
        .foregroundStyle(.white)
        .padding(15)
        .background(Color.white.opacity(0.13))
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .id(text)
        .transition(.opacity)
    }
}

private struct FakeTutorialNotification: View {
    @Binding var step: Int
    let completion: () -> Void
    @State private var selectedAnswer: String?

    var body: some View {
        VStack(spacing: 16) {
            if step == 5 {
                HStack(spacing: 12) {
                    Image(systemName: "brain.head.profile")
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("LearnAlert").font(.headline)
                        Text("Mental Math • now").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                Text("What is 9 × 8?")
                    .font(.title3.bold())

                Label("Swipe down to answer", systemImage: "chevron.down")
                    .font(.subheadline.bold())
                    .foregroundStyle(LearnAlertStyle.indigo)
            } else {
                Text("What is 9 × 8?")
                    .font(.title2.bold())

                ForEach(["63", "72", "81", "89"], id: \.self) { answer in
                    Button {
                        selectedAnswer = answer
                        if answer == "72" {
                            Task {
                                try? await Task.sleep(for: .milliseconds(500))
                                completion()
                            }
                        }
                    } label: {
                        HStack {
                            Text(answer)
                            Spacer()
                            if selectedAnswer == answer {
                                Image(systemName: answer == "72" ? "checkmark.circle.fill" : "xmark.circle.fill")
                            }
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(14)
                        .background(answerBackground(answer))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }

                if selectedAnswer != nil && selectedAnswer != "72" {
                    Text("Try again — the tutorial won’t judge.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
        .foregroundStyle(LearnAlertStyle.textPrimary)
        .background(Color.white.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.black.opacity(0.22), radius: 28, y: 12)
        .gesture(
            DragGesture(minimumDistance: 15)
                .onEnded { value in
                    guard step == 5, value.translation.height > 35 else { return }
                    withAnimation(.snappy) { step = 6 }
                }
        )
    }

    private func answerBackground(_ answer: String) -> Color {
        guard let selectedAnswer else { return LearnAlertStyle.indigo }
        if answer == "72" { return LearnAlertStyle.lime }
        if answer == selectedAnswer { return LearnAlertStyle.coral }
        return LearnAlertStyle.indigo.opacity(0.65)
    }
}

private struct FakePaywallView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "crown.fill")
                .font(.system(size: 58))
                .foregroundStyle(.yellow)

            VStack(spacing: 8) {
                Text("Unlock LearnAlert Ultra Max")
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)
                Text("The totally reasonable learning plan")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.68))
            }

            VStack(spacing: 12) {
                Label("Premium notifications", systemImage: "bell.badge.fill")
                Label("Unlimited flashcards", systemImage: "infinity")
                Label("Absolutely mysterious benefits", systemImage: "sparkles")
            }
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(22)
            .nativeGlass(cornerRadius: 20)

            VStack(spacing: 4) {
                Text("$99")
                    .font(.system(size: 68, weight: .black, design: .rounded))
                Text("per week, obviously")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.68))
            }

            Text("Loading extremely serious purchase options…")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.48))

            Spacer()
        }
        .foregroundStyle(.white)
        .padding(28)
    }
}
