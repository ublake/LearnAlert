import AVKit
import AVFoundation
import SwiftUI
import UserNotifications

struct WelcomeOnboardingView: View {
    @Environment(\.openURL) private var openURL
    @State private var page = 0
    @State private var tutorialStep = 0
    @State private var selectedDeckName: String? = nil
    @State private var isBouncingHint = false
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var isRequestingPermission = false

    let completion: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            // Full-screen edge-to-edge dark background filling behind Dynamic Island / notch
            Color(red: 0.08, green: 0.10, blue: 0.17)
                .ignoresSafeArea()

            CoursezyBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top Progress Bar (Visible during setup, hidden during full-screen lockscreen/meme scenes)
                if tutorialStep < 2 || page == 0 {
                    HStack(spacing: 8) {
                        Capsule()
                            .fill(page >= 0 ? LearnAlertStyle.indigo : Color.white.opacity(0.18))
                            .frame(height: 4)
                        Capsule()
                            .fill(page >= 1 ? LearnAlertStyle.indigo : Color.white.opacity(0.18))
                            .frame(height: 4)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 6)
                    .padding(.bottom, 6)
                    .transition(.opacity)
                }

                if page == 0 {
                    NotificationPermissionIntroPage(
                        status: notificationStatus,
                        isRequesting: isRequestingPermission,
                        requestPermission: requestNotificationPermission,
                        openSettings: openSystemSettings,
                        startTutorial: {
                            InteractionSoundPlayer.shared.play(.selection)
                            withAnimation(.spring(response: 0.42, dampingFraction: 0.76)) {
                                page = 1
                            }
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.98)),
                        removal: .opacity.combined(with: .move(edge: .leading))
                    ))
                } else {
                    AlertsTutorialView(
                        step: $tutorialStep,
                        selectedDeckName: $selectedDeckName,
                        onBack: {
                            withAnimation(.spring(response: 0.42, dampingFraction: 0.76)) {
                                page = 0
                            }
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .trailing)),
                        removal: .opacity.combined(with: .scale(scale: 0.98))
                    ))
                }
            }

            // Step 3, 4 & 5: Dropdown Notification Replica & Fullscreen Lock Screen Overlay at Root Level (extends to tippy top!)
            if page == 1 && tutorialStep >= 3 {
                ZStack(alignment: .top) {
                    LockScreenBackdropView(isMastered: tutorialStep == 5)
                        .ignoresSafeArea()
                        .onTapGesture {
                            if tutorialStep == 3 {
                                withAnimation(.spring(response: 0.44, dampingFraction: 0.74)) {
                                    tutorialStep = 4
                                }
                            }
                        }

                    if tutorialStep == 5 {
                        // Step 5: Mastered Card centered on screen with standalone button at bottom
                        TutorialMasteredView(completion: completion)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.95).combined(with: .opacity),
                                removal: .opacity
                            ))
                    } else {
                        VStack(spacing: 12) {
                            // Notification Replica (Compact or Expanded)
                            FakeTutorialNotification(
                                step: $tutorialStep,
                                deckTitle: selectedDeckName ?? "Mental Math"
                            )
                            .padding(.horizontal, 14)
                            .padding(.top, 54)
                            .transition(.move(edge: .top).combined(with: .opacity))

                            if tutorialStep == 3 {
                                HStack(spacing: 6) {
                                    Image(systemName: "hand.tap.fill")
                                        .offset(y: isBouncingHint ? 2 : -2)
                                    Text("Press and hold notification to expand")
                                        .font(.custom("Poppins-SemiBold", size: 13))
                                }
                                .foregroundStyle(.white)
                                .shadow(color: Color.black.opacity(0.5), radius: 6, y: 2)
                                .padding(.top, 6)
                                .onAppear {
                                    withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                                        isBouncingHint = true
                                    }
                                }
                            }

                            Spacer()
                        }
                    }
                }
                .ignoresSafeArea()
                .transition(.opacity)
                .zIndex(50)
            }

            // Step 2: SpongeBob "ONE HOUR LATER..." Meme Scene at Root Level (extends to tippy top!)
            if page == 1 && tutorialStep == 2 {
                SpongeBobTimeCardView(isActive: tutorialStep == 2) {
                    InteractionSoundPlayer.shared.play(.receiveFrom)
                    withAnimation(.spring(response: 0.46, dampingFraction: 0.72)) {
                        tutorialStep = 3
                    }
                }
                .ignoresSafeArea()
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await refreshNotificationStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Task { await refreshNotificationStatus() }
        }
    }

    @MainActor
    private func requestNotificationPermission() {
        isRequestingPermission = true
        InteractionSoundPlayer.shared.play(.selection)
        Task {
            _ = await NotificationManager.shared.requestPermission()
            await refreshNotificationStatus()
            isRequestingPermission = false
            if notificationStatus == .authorized {
                HapticFeedback.success()
                withAnimation(.spring(response: 0.42, dampingFraction: 0.76)) {
                    page = 1
                }
            }
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

// MARK: - Page 1: Video Preview & Clean Simple Intro (Full Height Layout)
private struct NotificationPermissionIntroPage: View {
    let status: UNAuthorizationStatus
    let isRequesting: Bool
    let requestPermission: () -> Void
    let openSettings: () -> Void
    let startTutorial: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            // Top Headline & Subheadline above the video
            VStack(spacing: 4) {
                Text("Study without opening the app")
                    .font(.custom("Poppins-SemiBold", size: 22))
                    .foregroundStyle(Color.white)
                    .multilineTextAlignment(.center)

                Text("We won’t send you notifications until you specifically schedule a study deck in the app.")
                    .font(.custom("Poppins-Regular", size: 13))
                    .foregroundStyle(Color.white.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 4)

            // Video Player automatically expands and is centered nicely
            OnboardingVideoPlayerView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.5), radius: 18, y: 8)
                .padding(.bottom, 6)

            // Bottom: Notifications status & Action Buttons directly below video
            VStack(spacing: 10) {
                if status == .authorized {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(LearnAlertStyle.lime)
                        Text("Notifications enabled!")
                            .font(.custom("Poppins-Medium", size: 14))
                            .foregroundStyle(Color.white)
                    }
                    .frame(maxWidth: .infinity)

                    Button(action: startTutorial) {
                        Label("Try the Interactive Demo", systemImage: "arrow.right")
                            .font(.custom("Poppins-SemiBold", size: 15))
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                    }
                    .foregroundStyle(.white)
                    .background(LearnAlertStyle.indigo)
                    .clipShape(Capsule())
                    .shadow(color: LearnAlertStyle.indigo.opacity(0.40), radius: 10, y: 4)

                } else if status == .denied {
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Color.orange)
                            Text("Notifications are disabled in Settings.")
                                .font(.custom("Poppins-Medium", size: 13))
                                .foregroundStyle(Color.white)
                        }
                        .frame(maxWidth: .infinity)

                        Button(action: openSettings) {
                            Label("Open iOS Settings", systemImage: "gear")
                                .font(.custom("Poppins-SemiBold", size: 15))
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                        }
                        .foregroundStyle(.white)
                        .background(LearnAlertStyle.indigo)
                        .clipShape(Capsule())
                        .shadow(color: LearnAlertStyle.indigo.opacity(0.35), radius: 8, y: 4)

                        Button("Continue anyway", action: startTutorial)
                            .font(.custom("Poppins-Regular", size: 13))
                            .foregroundStyle(Color.white.opacity(0.65))
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    VStack(spacing: 8) {
                        Button(action: requestPermission) {
                            HStack(spacing: 8) {
                                if isRequesting {
                                    ProgressView().tint(.white)
                                } else {
                                    Image(systemName: "bell.badge.fill")
                                }
                                Text("Turn on Notifications")
                                    .font(.custom("Poppins-SemiBold", size: 15))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                        }
                        .foregroundStyle(.white)
                        .background(LearnAlertStyle.indigo)
                        .clipShape(Capsule())
                        .shadow(color: LearnAlertStyle.indigo.opacity(0.45), radius: 10, y: 5)
                        .disabled(isRequesting)

                        Button("Maybe Later", action: startTutorial)
                            .font(.custom("Poppins-Regular", size: 13))
                            .foregroundStyle(Color.white.opacity(0.65))
                            .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 12)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Onboarding Looping Video Player (Aspect Fill / No Letterboxing)
private struct OnboardingVideoPlayerView: View {
    @State private var player: AVQueuePlayer?
    @State private var playerLooper: AVPlayerLooper?

    var body: some View {
        ZStack {
            Color.black

            if let player {
                AVPlayerAspectFillView(player: player)
                    .allowsHitTesting(false)
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            player?.pause()
        }
    }

    private func setupPlayer() {
        guard player == nil else {
            player?.play()
            return
        }

        // Search for preview1.mp4 in bundle
        let url = Bundle.main.url(forResource: "preview1", withExtension: "mp4")
            ?? Bundle.main.url(forResource: "preview1", withExtension: "mp4", subdirectory: "Videos")

        guard let url else { return }

        let item = AVPlayerItem(url: url)
        let queuePlayer = AVQueuePlayer(playerItem: item)
        queuePlayer.isMuted = true
        let looper = AVPlayerLooper(player: queuePlayer, templateItem: item)

        self.player = queuePlayer
        self.playerLooper = looper
        queuePlayer.play()
    }
}

// MARK: - UIViewRepresentable to adjust vertical video framing (crop top ~20%, extend to bottom)
private struct AVPlayerAspectFillView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.playerLayer.player = player
        return view
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        uiView.playerLayer.player = player
    }

    class PlayerUIView: UIView {
        let playerLayer = AVPlayerLayer()

        override init(frame: CGRect) {
            super.init(frame: frame)
            clipsToBounds = true
            playerLayer.videoGravity = .resizeAspectFill
            layer.addSublayer(playerLayer)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            let viewWidth = bounds.width
            let viewHeight = bounds.height
            guard viewWidth > 0, viewHeight > 0 else { return }

            // Video original aspect ratio is 1320 x 2868 (~1 : 2.173)
            let videoAspect: CGFloat = 2868.0 / 1320.0
            let naturalHeight = viewWidth * videoAspect

            // Align the bottom of the video exactly to the bottom of the box,
            // shifting the video all the way upward so the very bottom is 100% visible.
            let layerY = viewHeight - naturalHeight

            playerLayer.frame = CGRect(
                x: 0,
                y: layerY,
                width: viewWidth,
                height: naturalHeight
            )
        }
    }
}

// MARK: - Mini Lock Screen Notification Visual Mock (Clean Apple lockscreen style)
private struct LockScreenNotificationMock: View {
    @State private var isGlowPulse = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image("AppLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 22, height: 22)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                Text("LEARNALERT")
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.85))

                Spacer()

                Text("now")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.55))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Mental Math")
                    .font(.custom("Poppins-SemiBold", size: 12))
                    .foregroundStyle(Color.white.opacity(0.65))
                Text("Press and hold to answer")
                    .font(.custom("Poppins-Regular", size: 13.5))
                    .foregroundStyle(Color.white.opacity(0.95))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(red: 0.12, green: 0.15, blue: 0.24).opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isGlowPulse ? LearnAlertStyle.indigo.opacity(0.6) : Color.white.opacity(0.2), lineWidth: 1.2)
        )
        .shadow(color: LearnAlertStyle.indigo.opacity(isGlowPulse ? 0.18 : 0.08), radius: 14, y: 5)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                isGlowPulse = true
            }
        }
    }
}

// MARK: - Page 2: Interactive Tutorial with Real Homepage Deck Picker & SpongeBob Meme
private struct AlertsTutorialView: View {
    @Binding var step: Int
    @Binding var selectedDeckName: String?
    let onBack: () -> Void

    @State private var selectedDeckCardCount: String? = nil

    private let availableDecks = [
        ("Mental Math", "5 cards"),
        ("Spanish Vocab", "8 cards"),
        ("Biology Trivia", "6 cards")
    ]

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    // Header Bar
                    HStack {
                        Button(action: onBack) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.8))
                                .frame(width: 36, height: 36)
                                .background(Color.white.opacity(0.12), in: Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 0.8))
                        }

                        Spacer()

                        Text("Interactive Tutorial")
                            .font(.custom("Poppins-SemiBold", size: 15))
                            .foregroundStyle(Color.white)

                        Spacer()

                        Color.clear.frame(width: 36, height: 36)
                    }
                    .padding(.top, 4)

                    // Dynamic Guidance Callout (Centered & Full Width)
                    HStack(spacing: 12) {
                        Image(systemName: guidanceIcon)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(LearnAlertStyle.indigo)

                        Text(guidanceText)
                            .font(.custom("Poppins-Medium", size: 13))
                            .foregroundStyle(Color.white)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(red: 0.12, green: 0.15, blue: 0.24).opacity(0.85))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .animation(.easeInOut(duration: 0.25), value: step)

                    // Real Homepage Alert Control Card Mock (Extended Full Width)
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Alert schedule")
                                    .font(.custom("Poppins-SemiBold", size: 17, relativeTo: .headline))
                                    .foregroundStyle(Color.white)
                                Text("Select what deck you want to schedule:")
                                    .font(.custom("Poppins-Regular", size: 11, relativeTo: .caption2))
                                    .foregroundStyle(Color.white.opacity(0.65))
                            }
                            Spacer()
                            ScheduleStatusDot(isActive: step >= 2)
                        }

                        // Real Homepage-style Menu Deck Selector
                        Menu {
                            ForEach(availableDecks, id: \.0) { deck in
                                Button(deck.0) {
                                    handleDeckSelection(name: deck.0, count: deck.1)
                                }
                            }
                        } label: {
                            TutorialDeckPickerLabel(
                                selectedDeck: selectedDeckName,
                                cardCount: selectedDeckCardCount
                            )
                        }
                        .disabled(step > 1)

                        // Real Homepage-style Schedule Alerts Action Button
                        HStack(spacing: 10) {
                            Button {
                                handleScheduleAlerts()
                            } label: {
                                Label("Schedule alerts", systemImage: "bell.badge.fill")
                                    .font(.custom("Poppins-SemiBold", size: 12, relativeTo: .caption))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                            }
                            .foregroundStyle(.white)
                            .background(selectedDeckName == nil ? Color.white.opacity(0.15) : LearnAlertStyle.indigo)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .shadow(color: (selectedDeckName == nil ? Color.clear : LearnAlertStyle.indigo).opacity(0.35), radius: 8, y: 3)
                            .disabled(selectedDeckName == nil || step > 1)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color(red: 0.12, green: 0.15, blue: 0.24).opacity(0.85))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)


        }
    }

    private var guidanceIcon: String {
        switch step {
        case 0: return "hand.tap.fill"
        case 1: return "bell.badge.fill"
        case 2: return "clock.fill"
        case 3: return "arrow.down"
        case 4: return "checkmark.circle"
        default: return "sparkles"
        }
    }

    private var guidanceText: String {
        switch step {
        case 0:
            return "Tap 'Choose a deck' to select which flashcard set to study."
        case 1:
            return "Deck selected! Now tap 'Schedule alerts' below."
        case 2:
            return "Going about your day..."
        case 3:
            return "A notification arrived! Press and hold to reveal the quiz."
        case 4:
            return "Answer without opening the app. Tap the correct answer."
        default:
            return "Awesome! You just mastered studying on your lock screen."
        }
    }

    private func handleDeckSelection(name: String, count: String) {
        InteractionSoundPlayer.shared.play(.selection)
        HapticFeedback.impact(.light)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            selectedDeckName = name
            selectedDeckCardCount = count
            if step == 0 { step = 1 }
        }
    }

    private func handleScheduleAlerts() {
        HapticFeedback.success()
        withAnimation(.easeInOut(duration: 0.35)) {
            step = 2
        }
    }
}

// MARK: - Tutorial Deck Picker Label (Matches Homepage DeckPickerLabel)
private struct TutorialDeckPickerLabel: View {
    let selectedDeck: String?
    let cardCount: String?

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(selectedDeck ?? "Choose a deck")
                    .font(.custom("Poppins-Medium", size: 13, relativeTo: .subheadline))
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(cardCount ?? "Nothing selected")
                    .font(.custom("Poppins-Regular", size: 10, relativeTo: .caption2))
                    .foregroundStyle(Color.white.opacity(0.60))
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption.bold())
                .foregroundStyle(Color.white.opacity(0.60))
        }
        .foregroundStyle(Color.white)
        .padding(.horizontal, 14)
        .frame(height: 52)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(selectedDeck == nil ? LearnAlertStyle.indigo.opacity(0.6) : Color.white.opacity(0.14), lineWidth: 1)
        }
    }
}

private struct ScheduleStatusDot: View {
    let isActive: Bool

    var body: some View {
        Circle()
            .fill(isActive ? LearnAlertStyle.lime : Color.gray.opacity(0.4))
            .frame(width: 10, height: 10)
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.5), lineWidth: 1.5)
            )
    }
}

// MARK: - SpongeBob "ONE HOUR LATER..." Time Card Meme
private struct SpongeBobTimeCardView: View {
    let isActive: Bool
    let onContinue: () -> Void
    @State private var timeOffset: CGFloat = 0
    @State private var textScale: CGFloat = 1.0
    @State private var textOpacity: Double = 1.0
    @State private var autoDismissTask: Task<Void, Never>? = nil

    var body: some View {
        ZStack {
            TropicalBackgroundView()

            VStack(spacing: 6) {
                Text("ONE HOUR")
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .foregroundStyle(Color(red: 0.10, green: 0.35, blue: 0.82))
                    .shadow(color: Color(red: 0.05, green: 0.15, blue: 0.45), radius: 0, x: 3, y: 3)
                    .shadow(color: Color.black.opacity(0.4), radius: 6, x: 4, y: 4)

                Text("LATER...")
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .foregroundStyle(Color(red: 0.10, green: 0.35, blue: 0.82))
                    .shadow(color: Color(red: 0.05, green: 0.15, blue: 0.45), radius: 0, x: 3, y: 3)
                    .shadow(color: Color.black.opacity(0.4), radius: 6, x: 4, y: 4)
            }
            .rotationEffect(.degrees(-3))
            .scaleEffect(textScale)
            .opacity(textOpacity)
            .offset(y: timeOffset)

            VStack {
                Spacer()
                Text("* French narrator voice: Meanwhile, going about your day... *")
                    .font(.custom("Poppins-Regular", size: 11.5))
                    .italic()
                    .foregroundStyle(Color.black.opacity(0.78))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.45), in: Capsule())
                    .padding(.bottom, 28)
            }
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture {
            autoDismissTask?.cancel()
            onContinue()
        }
        .onAppear {
            InteractionSoundPlayer.shared.play(.oneHourLater)
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                timeOffset = 5
            }
            autoDismissTask?.cancel()
            autoDismissTask = Task {
                try? await Task.sleep(for: .milliseconds(3000))
                if !Task.isCancelled {
                    onContinue()
                }
            }
        }
        .onDisappear {
            autoDismissTask?.cancel()
        }
    }
}

// MARK: - Tropical Background Pattern for SpongeBob Meme (DrawingGroup cached for GPU performance)
private struct TropicalBackgroundView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.85, blue: 0.28),
                    Color(red: 0.94, green: 0.76, blue: 0.22),
                    Color(red: 0.96, green: 0.83, blue: 0.30)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height

                Group {
                    TropicalStamp(isPineapple: true)
                        .position(x: w * 0.15, y: h * 0.18)
                        .rotationEffect(.degrees(15))

                    TropicalStamp(isPineapple: false)
                        .position(x: w * 0.82, y: h * 0.16)
                        .rotationEffect(.degrees(-20))

                    TropicalStamp(isPineapple: false)
                        .position(x: w * 0.12, y: h * 0.55)
                        .rotationEffect(.degrees(10))

                    TropicalStamp(isPineapple: true)
                        .position(x: w * 0.86, y: h * 0.58)
                        .rotationEffect(.degrees(-15))

                    TropicalStamp(isPineapple: false)
                        .position(x: w * 0.20, y: h * 0.85)
                        .rotationEffect(.degrees(-12))

                    TropicalStamp(isPineapple: true)
                        .position(x: w * 0.80, y: h * 0.84)
                        .rotationEffect(.degrees(18))
                }
                .opacity(0.32)
            }
        }
        .drawingGroup()
        .ignoresSafeArea()
    }
}

private struct TropicalStamp: View {
    let isPineapple: Bool

    var body: some View {
        if isPineapple {
            VStack(spacing: -5) {
                // Bunched overlapping pineapple crown leaves radiating from center
                ZStack(alignment: .bottom) {
                    // Back layer outer spreading leaves
                    HStack(spacing: 12) {
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 16, weight: .bold))
                            .rotationEffect(.degrees(-42))
                            .offset(x: 2, y: 3)
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 16, weight: .bold))
                            .rotationEffect(.degrees(42))
                            .offset(x: -2, y: 3)
                    }
                    .foregroundStyle(Color(red: 0.28, green: 0.48, blue: 0.12))

                    // Mid layer angled leaves
                    HStack(spacing: 4) {
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 18, weight: .bold))
                            .rotationEffect(.degrees(-20))
                            .offset(y: 1)
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 18, weight: .bold))
                            .rotationEffect(.degrees(20))
                            .offset(y: 1)
                    }
                    .foregroundStyle(Color(red: 0.33, green: 0.55, blue: 0.14))

                    // Center tall upright leaf
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 21, weight: .bold))
                        .offset(y: -3)
                        .foregroundStyle(Color(red: 0.38, green: 0.62, blue: 0.16))
                }
                .frame(width: 44, height: 26)

                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Color(red: 0.88, green: 0.55, blue: 0.12))
                    .frame(width: 38, height: 48)
                    .overlay(
                        ZStack {
                            Path { path in
                                path.move(to: CGPoint(x: 5, y: 10))
                                path.addLine(to: CGPoint(x: 33, y: 38))
                                path.move(to: CGPoint(x: 5, y: 22))
                                path.addLine(to: CGPoint(x: 27, y: 44))
                                path.move(to: CGPoint(x: 33, y: 10))
                                path.addLine(to: CGPoint(x: 5, y: 38))
                                path.move(to: CGPoint(x: 33, y: 22))
                                path.addLine(to: CGPoint(x: 11, y: 44))
                            }
                            .stroke(Color(red: 0.72, green: 0.40, blue: 0.08), lineWidth: 1.2)
                        }
                    )
            }
        } else {
            ZStack {
                ForEach(0..<5) { i in
                    Circle()
                        .fill(Color(red: 0.90, green: 0.40, blue: 0.25).opacity(0.85))
                        .frame(width: 22, height: 22)
                        .offset(y: -12)
                        .rotationEffect(.degrees(Double(i) * 72))
                }
                Circle()
                    .fill(Color(red: 0.98, green: 0.88, blue: 0.35))
                    .frame(width: 12, height: 12)
            }
            .frame(width: 44, height: 44)
        }
    }
}

// MARK: - Deck-Specific Tutorial Questions
private struct TutorialDeckQuestion {
    let question: String
    let options: [String]
    let correctAnswer: String
    let hintMessage: String

    static func question(for deckTitle: String) -> TutorialDeckQuestion {
        switch deckTitle {
        case "Spanish Vocab":
            return TutorialDeckQuestion(
                question: "What does \"Hola\" mean in English?",
                options: ["Hello", "Goodbye", "Please", "Thank you"],
                correctAnswer: "Hello",
                hintMessage: "Not quite — \"Hola\" means \"Hello\". Give Hello a try!"
            )
        case "Biology Trivia":
            return TutorialDeckQuestion(
                question: "Which organ pumps blood in the body?",
                options: ["Heart", "Lungs", "Brain", "Stomach"],
                correctAnswer: "Heart",
                hintMessage: "Not quite — the heart pumps blood. Give Heart a try!"
            )
        default: // Mental Math or fallback
            return TutorialDeckQuestion(
                question: "What is 9 × 8?",
                options: ["63", "72", "81", "89"],
                correctAnswer: "72",
                hintMessage: "Not quite — 9 × 8 = 72. Give 72 a try!"
            )
        }
    }
}

// MARK: - Slide-down Fake Notification
private struct FakeTutorialNotification: View {
    @Binding var step: Int
    let deckTitle: String
    @State private var selectedAnswer: String?
    @State private var showFeedbackText = false

    private var deckQuestion: TutorialDeckQuestion {
        TutorialDeckQuestion.question(for: deckTitle)
    }

    var body: some View {
        VStack(spacing: 14) {
            // Notification Top Header Bar
            HStack(spacing: 9) {
                Image("AppLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 30, height: 30)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Text("LEARNALERT")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.85))

                Spacer()

                Text("now")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.55))
            }

            if step == 3 {
                // Compact lock screen banner view
                VStack(alignment: .leading, spacing: 4) {
                    Text(deckTitle)
                        .font(.custom("Poppins-SemiBold", size: 14))
                        .foregroundStyle(Color.white)
                    Text("Press and hold to answer")
                        .font(.custom("Poppins-Regular", size: 14))
                        .foregroundStyle(Color.white.opacity(0.9))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 2)



            } else {
                // Expanded flashcard question & answers view
                VStack(spacing: 12) {
                    Text(deckQuestion.question)
                        .font(.custom("Poppins-SemiBold", size: 18))
                        .foregroundStyle(Color.white)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 4)

                    VStack(spacing: 9) {
                        ForEach(deckQuestion.options, id: \.self) { answer in
                            Button {
                                handleAnswerSelection(answer)
                            } label: {
                                HStack {
                                    Text(answer)
                                        .font(.custom("Poppins-SemiBold", size: 15))
                                    Spacer()
                                    if selectedAnswer == answer {
                                        Image(systemName: answer == deckQuestion.correctAnswer ? "checkmark.circle.fill" : "xmark.circle.fill")
                                            .font(.system(size: 16, weight: .bold))
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                                .foregroundStyle(selectedAnswer == answer ? .white : Color.white)
                                .background(answerBackground(answer))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(selectedAnswer == answer ? Color.clear : Color.white.opacity(0.15), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if showFeedbackText && selectedAnswer != deckQuestion.correctAnswer {
                        Text(deckQuestion.hintMessage)
                            .font(.custom("Poppins-Regular", size: 12))
                            .foregroundStyle(Color.red)
                            .transition(.opacity)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.55), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.28), radius: 24, y: 10)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 12)
                .onEnded { value in
                    guard step == 3, value.translation.height > 25 else { return }
                    withAnimation(.spring(response: 0.44, dampingFraction: 0.74)) {
                        step = 4
                    }
                }
        )
        .onLongPressGesture(minimumDuration: 0.25) {
            if step == 3 {
                InteractionSoundPlayer.shared.play(.selection)
                HapticFeedback.impact(.medium)
                withAnimation(.spring(response: 0.44, dampingFraction: 0.74)) {
                    step = 4
                }
            }
        }
        .onTapGesture {
            if step == 3 {
                withAnimation(.spring(response: 0.44, dampingFraction: 0.74)) {
                    step = 4
                }
            }
        }
    }

    private func handleAnswerSelection(_ answer: String) {
        selectedAnswer = answer
        if answer == deckQuestion.correctAnswer {
            InteractionSoundPlayer.shared.play(.correct)
            HapticFeedback.success()
            showFeedbackText = false
            Task {
                try? await Task.sleep(for: .milliseconds(650))
                withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                    step = 5
                }
            }
        } else {
            InteractionSoundPlayer.shared.play(.incorrect)
            HapticFeedback.warning()
            withAnimation(.snappy) {
                showFeedbackText = true
            }
        }
    }

    private func answerBackground(_ answer: String) -> Color {
        guard let selectedAnswer else { return Color.white.opacity(0.08) }
        if answer == deckQuestion.correctAnswer && selectedAnswer == deckQuestion.correctAnswer { return LearnAlertStyle.lime }
        if answer == selectedAnswer { return LearnAlertStyle.coral }
        return Color.white.opacity(0.08)
    }
}

// MARK: - Fullscreen Lock Screen & Completion Backdrop (Completely covers previous UI)
private struct LockScreenBackdropView: View {
    let isMastered: Bool

    var body: some View {
        ZStack {
            // Fullscreen seamless dark backdrop completely obscuring previous setup UI
            Color(red: 0.05, green: 0.07, blue: 0.12)
                .ignoresSafeArea()

            if !isMastered {
                // Subtle authentic lock screen depth gradient
                LinearGradient(
                    colors: [
                        Color(red: 0.06, green: 0.08, blue: 0.14),
                        Color(red: 0.04, green: 0.05, blue: 0.10)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // Lock Screen Clock & Date Watermark
                VStack(spacing: 4) {
                    Text(Date().formatted(.dateTime.weekday(.wide).month().day()))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.72))
                    Text(Date().formatted(.dateTime.hour().minute()))
                        .font(.system(size: 68, weight: .thin, design: .rounded))
                        .foregroundStyle(.white.opacity(0.90))
                    Spacer()
                }
                .padding(.top, 28)
            } else {
                // Fullscreen blur + luminous radial aura for You're All Set
                RadialGradient(
                    colors: [
                        LearnAlertStyle.indigo.opacity(0.24),
                        LearnAlertStyle.mint.opacity(0.16),
                        Color.primary.opacity(0.06)
                    ],
                    center: .center,
                    startRadius: 20,
                    endRadius: 420
                )
                .ignoresSafeArea()
            }
        }
    }
}

// MARK: - Tutorial Completion & Older Notifications Tip (Dark Mode UI with Centered Card and Standalone Bottom Button)
private struct TutorialMasteredView: View {
    let completion: () -> Void
    @State private var cooldownRemaining: Int = 5

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Centered "You're All Set!" Content Card
            VStack(spacing: 20) {
                // Glowing Celebration Badge
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [LearnAlertStyle.lime.opacity(0.40), LearnAlertStyle.lime.opacity(0.05)],
                                center: .center,
                                startRadius: 5,
                                endRadius: 46
                            )
                        )
                        .frame(width: 92, height: 92)

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [LearnAlertStyle.lime, LearnAlertStyle.mint],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 66, height: 66)
                        .shadow(color: LearnAlertStyle.lime.opacity(0.50), radius: 14, y: 4)

                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.white)
                }
                .padding(.top, 4)

                VStack(spacing: 8) {
                    Text("You're All Set!")
                        .font(.custom("Poppins-SemiBold", size: 24))
                        .foregroundStyle(Color.white)

                    Text("You just answered a flashcard without ever leaving your lock screen! (not actually since its a tutorial haha but you get it)")
                        .font(.custom("Poppins-Regular", size: 14))
                        .foregroundStyle(Color.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, 4)
                }

                // High-contrast Pro Tip Box (Extended Full Width)
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.yellow)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pro Tip for Older Alerts")
                            .font(.custom("Poppins-SemiBold", size: 13.5))
                            .foregroundStyle(Color.white)

                        Text("If an alert is in Notification Center, press and hold it anytime — or swipe left and tap View — to expand the flashcard.")
                            .font(.custom("Poppins-Regular", size: 12))
                            .foregroundStyle(Color.white.opacity(0.80))
                            .lineSpacing(2.5)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color(red: 0.12, green: 0.14, blue: 0.22).opacity(0.96))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.40),
                                Color.white.opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: Color.black.opacity(0.55), radius: 30, y: 12)
            .padding(.horizontal, 18)

            Spacer()

            // Standalone Action Button at the very bottom of the screen
            Button(action: {
                guard cooldownRemaining == 0 else { return }
                InteractionSoundPlayer.shared.play(.selection)
                HapticFeedback.success()
                completion()
            }) {
                HStack(spacing: 8) {
                    if cooldownRemaining > 0 {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 15))
                        Text("Start Learning (\(cooldownRemaining)s)")
                            .font(.custom("Poppins-SemiBold", size: 15))
                    } else {
                        Label("Start Learning", systemImage: "sparkles")
                            .font(.custom("Poppins-SemiBold", size: 16))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
            }
            .foregroundStyle(cooldownRemaining > 0 ? Color.white.opacity(0.55) : Color.white)
            .background(
                cooldownRemaining > 0
                    ? Color(red: 0.22, green: 0.24, blue: 0.32)
                    : LearnAlertStyle.indigo
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(cooldownRemaining > 0 ? Color.white.opacity(0.12) : Color.clear, lineWidth: 1)
            )
            .shadow(
                color: cooldownRemaining > 0 ? Color.clear : LearnAlertStyle.indigo.opacity(0.40),
                radius: 10,
                y: 4
            )
            .disabled(cooldownRemaining > 0)
            .animation(.easeInOut(duration: 0.25), value: cooldownRemaining)
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            while cooldownRemaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                cooldownRemaining = max(0, cooldownRemaining - 1)
            }
        }
    }
}
