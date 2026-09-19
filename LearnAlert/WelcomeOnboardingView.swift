import SwiftUI
import UserNotifications

struct WelcomeOnboardingView: View {
    @Environment(\.openURL) private var openURL
    @State private var page = 0
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var isRequestingPermission = false

    let completion: () -> Void

    var body: some View {
        ZStack {
            CoursezyBackground()

            VStack(spacing: 0) {
                // Top Progress Bar
                HStack(spacing: 8) {
                    Capsule()
                        .fill(page >= 0 ? LearnAlertStyle.indigo : Color.primary.opacity(0.12))
                        .frame(height: 4)
                    Capsule()
                        .fill(page >= 1 ? LearnAlertStyle.indigo : Color.primary.opacity(0.12))
                        .frame(height: 4)
                }
                .padding(.horizontal, 24)
                .padding(.top, 14)
                .padding(.bottom, 6)

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
                        onBack: {
                            withAnimation(.spring(response: 0.42, dampingFraction: 0.76)) {
                                page = 0
                            }
                        },
                        completion: completion
                    )
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .trailing)),
                        removal: .opacity.combined(with: .scale(scale: 0.98))
                    ))
                }
            }
        }
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

// MARK: - Page 1: Clean, Centered Value Intro & Permission
private struct NotificationPermissionIntroPage: View {
    let status: UNAuthorizationStatus
    let isRequesting: Bool
    let requestPermission: () -> Void
    let openSettings: () -> Void
    let startTutorial: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Mini Lock Screen Notification Visual Mock (Clean, realistic Apple lock screen banner)
                LockScreenNotificationMock()
                    .padding(.top, 10)

                // Headline & Core Proposition
                VStack(spacing: 8) {
                    Text("Study without opening an app.")
                        .font(.custom("Poppins-SemiBold", size: 25))
                        .foregroundStyle(LearnAlertStyle.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("LearnAlert delivers flashcards as lock screen notifications throughout your day. Just press and hold to answer in two seconds.")
                        .font(.custom("Poppins-Regular", size: 13.5))
                        .foregroundStyle(LearnAlertStyle.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, 10)
                }

                // Two High-Impact Highlight Pills
                HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(LearnAlertStyle.mint)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("2-Second Quizzes")
                                .font(.custom("Poppins-SemiBold", size: 12))
                                .foregroundStyle(LearnAlertStyle.textPrimary)
                            Text("Answer on lock screen")
                                .font(.custom("Poppins-Regular", size: 10.5))
                                .foregroundStyle(LearnAlertStyle.textSecondary)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .settingsGlassSurface(cornerRadius: 14)

                    HStack(spacing: 8) {
                        Image(systemName: "clock.badge.checkmark.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(LearnAlertStyle.sky)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Spaced Alerts")
                                .font(.custom("Poppins-SemiBold", size: 12))
                                .foregroundStyle(LearnAlertStyle.textPrimary)
                            Text("Smart daily intervals")
                                .font(.custom("Poppins-Regular", size: 10.5))
                                .foregroundStyle(LearnAlertStyle.textSecondary)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .settingsGlassSurface(cornerRadius: 14)
                }
                .padding(.horizontal, 4)

                // Permission Actions
                VStack(spacing: 12) {
                    if status == .authorized {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(LearnAlertStyle.lime)
                            Text("Notifications enabled!")
                                .font(.custom("Poppins-Medium", size: 14))
                                .foregroundStyle(LearnAlertStyle.textPrimary)
                        }

                        Button(action: startTutorial) {
                            Label("Try the Interactive Demo", systemImage: "arrow.right")
                                .font(.custom("Poppins-SemiBold", size: 15))
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                        }
                        .foregroundStyle(.white)
                        .background(LearnAlertStyle.indigo)
                        .clipShape(Capsule())
                        .shadow(color: LearnAlertStyle.indigo.opacity(0.32), radius: 10, y: 4)

                    } else if status == .denied {
                        VStack(spacing: 10) {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(Color.orange)
                                Text("Notifications are disabled in Settings.")
                                    .font(.custom("Poppins-Medium", size: 13))
                                    .foregroundStyle(LearnAlertStyle.textPrimary)
                            }

                            Button(action: openSettings) {
                                Label("Open iOS Settings", systemImage: "gear")
                                    .font(.custom("Poppins-SemiBold", size: 15))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                            }
                            .foregroundStyle(.white)
                            .background(LearnAlertStyle.indigo)
                            .clipShape(Capsule())
                            .shadow(color: LearnAlertStyle.indigo.opacity(0.26), radius: 8, y: 4)

                            Button("Continue anyway", action: startTutorial)
                                .font(.custom("Poppins-Regular", size: 13))
                                .foregroundStyle(LearnAlertStyle.textSecondary)
                        }
                    } else {
                        VStack(spacing: 9) {
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
                            .shadow(color: LearnAlertStyle.indigo.opacity(0.35), radius: 10, y: 5)
                            .disabled(isRequesting)

                            Text("Required to send you flashcard alerts throughout the day.")
                                .font(.custom("Poppins-Regular", size: 11.5))
                                .foregroundStyle(LearnAlertStyle.textSecondary)

                            Button("Maybe Later", action: startTutorial)
                                .font(.custom("Poppins-Regular", size: 13))
                                .foregroundStyle(LearnAlertStyle.textSecondary)
                                .padding(.top, 2)
                        }
                    }
                }
                .padding(.top, 4)
                .padding(.horizontal, 4)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 24)
        }
    }
}

// MARK: - Mini Lock Screen Notification Visual Mock (Clean Apple lockscreen style)
private struct LockScreenNotificationMock: View {
    @State private var isGlowPulse = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(LearnAlertStyle.indigo)
                        .frame(width: 22, height: 22)
                    Text("LA")
                        .font(.system(size: 8.5, weight: .black))
                        .foregroundStyle(.white)
                }

                Text("LEARNALERT")
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(Color.primary.opacity(0.85))

                Spacer()

                Text("now")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Mental Math")
                    .font(.custom("Poppins-SemiBold", size: 12))
                    .foregroundStyle(LearnAlertStyle.textSecondary)
                Text("Press and hold to answer")
                    .font(.custom("Poppins-Regular", size: 13.5))
                    .foregroundStyle(Color.primary.opacity(0.9))
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isGlowPulse ? LearnAlertStyle.indigo.opacity(0.4) : Color.white.opacity(0.4), lineWidth: 1.2)
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
    let onBack: () -> Void
    let completion: () -> Void

    // 0 = Select deck, 1 = Deck selected (ready to schedule), 2 = SpongeBob Meme, 3 = Notification dropped, 4 = Notification expanded, 5 = Mastered
    @State private var step = 0
    @State private var selectedDeckName: String? = nil
    @State private var selectedDeckCardCount: String? = nil
    @State private var isBouncingHint = false

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
                                .foregroundStyle(LearnAlertStyle.textSecondary)
                                .frame(width: 36, height: 36)
                                .background(.ultraThinMaterial, in: Circle())
                                .overlay(Circle().stroke(LearnAlertStyle.glassStroke, lineWidth: 0.8))
                        }

                        Spacer()

                        Text("Interactive Tutorial")
                            .font(.custom("Poppins-SemiBold", size: 15))
                            .foregroundStyle(LearnAlertStyle.textPrimary)

                        Spacer()

                        Color.clear.frame(width: 36, height: 36)
                    }
                    .padding(.top, 4)

                    // Dynamic Guidance Callout
                    HStack(spacing: 12) {
                        Image(systemName: guidanceIcon)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(LearnAlertStyle.indigo)

                        Text(guidanceText)
                            .font(.custom("Poppins-Medium", size: 13))
                            .foregroundStyle(LearnAlertStyle.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 0)
                    }
                    .padding(13)
                    .settingsGlassSurface(cornerRadius: 14)
                    .animation(.easeInOut(duration: 0.25), value: step)

                    // Real Homepage Alert Control Card Mock
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Alert schedule")
                                    .font(.custom("Poppins-SemiBold", size: 17, relativeTo: .headline))
                                    .foregroundStyle(LearnAlertStyle.textPrimary)
                                Text("Select what deck you want to schedule:")
                                    .font(.custom("Poppins-Regular", size: 11, relativeTo: .caption2))
                                    .foregroundStyle(LearnAlertStyle.textSecondary)
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
                            .background(selectedDeckName == nil ? Color.gray.opacity(0.34) : LearnAlertStyle.indigo)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .shadow(color: (selectedDeckName == nil ? Color.clear : LearnAlertStyle.indigo).opacity(0.28), radius: 8, y: 3)
                            .disabled(selectedDeckName == nil || step > 1)
                        }
                    }
                    .padding(18)
                    .settingsGlassSurface(cornerRadius: 20)

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }

            // Step 2: SpongeBob "ONE HOUR LATER..." Meme Scene
            if step == 2 {
                SpongeBobTimeCardView {
                    InteractionSoundPlayer.shared.play(.receiveFrom)
                    withAnimation(.spring(response: 0.46, dampingFraction: 0.72)) {
                        step = 3
                    }
                }
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.96).combined(with: .opacity),
                    removal: .opacity
                ))
                .zIndex(20)
            }

            // Step 3 & 4: Dropdown Notification Replica Overlay
            if step >= 3 {
                LockScreenBackdropView(isMastered: step == 5)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        if step == 3 {
                            withAnimation(.spring(response: 0.44, dampingFraction: 0.74)) {
                                step = 4
                            }
                        }
                    }

                VStack(spacing: 12) {
                    if step == 5 {
                        // Step 5: Mastered & Older Notifications Tip
                        TutorialMasteredCard(completion: completion)
                            .padding(.horizontal, 18)
                            .padding(.top, 60)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.95).combined(with: .opacity),
                                removal: .opacity
                            ))
                    } else {
                        // Notification Replica (Compact or Expanded)
                        FakeTutorialNotification(
                            step: $step,
                            deckTitle: selectedDeckName ?? "Mental Math"
                        )
                        .padding(.horizontal, 14)
                        .padding(.top, 16)
                        .transition(.move(edge: .top).combined(with: .opacity))

                        if step == 3 {
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
                    }

                    Spacer()
                }
                .zIndex(15)
            }
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
        InteractionSoundPlayer.shared.play(.scheduledAlerts)
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
                    .foregroundStyle(LearnAlertStyle.textSecondary)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption.bold())
                .foregroundStyle(LearnAlertStyle.textSecondary)
        }
        .foregroundStyle(LearnAlertStyle.textPrimary)
        .padding(.horizontal, 14)
        .frame(height: 52)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(selectedDeck == nil ? LearnAlertStyle.indigo.opacity(0.5) : LearnAlertStyle.glassStroke, lineWidth: 1)
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
    let onContinue: () -> Void
    @State private var timeOffset: CGFloat = 0
    @State private var textScale: CGFloat = 0.85
    @State private var textOpacity: Double = 0

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
            onContinue()
        }
        .task {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
                textScale = 1.0
                textOpacity = 1.0
            }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                timeOffset = 5
            }
            try? await Task.sleep(for: .milliseconds(4200))
            onContinue()
        }
    }
}

// MARK: - Tropical Background Pattern for SpongeBob Meme
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
    }
}

private struct TropicalStamp: View {
    let isPineapple: Bool

    var body: some View {
        if isPineapple {
            VStack(spacing: -3) {
                HStack(spacing: 2) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 15))
                        .rotationEffect(.degrees(-25))
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 18))
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 15))
                        .rotationEffect(.degrees(25))
                }
                .foregroundStyle(Color(red: 0.35, green: 0.58, blue: 0.15))

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
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(LearnAlertStyle.indigo)
                        .frame(width: 30, height: 30)

                    Text("LA")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(.white)
                }

                Text("LEARNALERT")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.primary.opacity(0.85))

                Spacer()

                Text("now")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.secondary)
            }

            if step == 3 {
                // Compact lock screen banner view
                VStack(alignment: .leading, spacing: 4) {
                    Text(deckTitle)
                        .font(.custom("Poppins-SemiBold", size: 14))
                        .foregroundStyle(Color.primary)
                    Text("Press and hold to answer")
                        .font(.custom("Poppins-Regular", size: 14))
                        .foregroundStyle(Color.primary.opacity(0.9))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 2)

                HStack {
                    Spacer()
                    Image(systemName: "chevron.compact.down")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.secondary.opacity(0.7))
                    Spacer()
                }
                .padding(.top, 2)

            } else {
                // Expanded flashcard question & answers view
                VStack(spacing: 12) {
                    Text(deckQuestion.question)
                        .font(.custom("Poppins-SemiBold", size: 18))
                        .foregroundStyle(Color.primary)
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
                                .foregroundStyle(selectedAnswer == answer ? .white : Color.primary)
                                .background(answerBackground(answer))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(selectedAnswer == answer ? Color.clear : Color.primary.opacity(0.10), lineWidth: 1)
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
        guard let selectedAnswer else { return Color.primary.opacity(0.06) }
        if answer == deckQuestion.correctAnswer && selectedAnswer == deckQuestion.correctAnswer { return LearnAlertStyle.lime }
        if answer == selectedAnswer { return LearnAlertStyle.coral }
        return Color.primary.opacity(0.06)
    }
}

// MARK: - Fullscreen Lock Screen & Completion Backdrop (Completely covers previous UI)
private struct LockScreenBackdropView: View {
    let isMastered: Bool

    var body: some View {
        ZStack {
            // Fullscreen material completely obscuring previous setup UI
            Rectangle()
                .fill(.ultraThickMaterial)
                .ignoresSafeArea()

            if !isMastered {
                // Dark authentic lock screen ambience covering everything
                Color(red: 0.05, green: 0.07, blue: 0.12)
                    .opacity(0.92)
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

// MARK: - Tutorial Completion & Older Notifications Tip (Bright, luminous card)
private struct TutorialMasteredCard: View {
    let completion: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
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
                    .foregroundStyle(colorScheme == .dark ? Color.white : LearnAlertStyle.textPrimary)

                Text("You just answered a flashcard without ever leaving your lock screen! (not actually since its a tutorial haha but you get it)")
                    .font(.custom("Poppins-Regular", size: 14))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.85) : LearnAlertStyle.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 4)
            }

            // High-contrast Pro Tip Box
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.yellow)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Pro Tip for Older Alerts")
                        .font(.custom("Poppins-SemiBold", size: 13.5))
                        .foregroundStyle(colorScheme == .dark ? Color.white : LearnAlertStyle.textPrimary)

                    Text("If an alert is in Notification Center, press and hold it anytime — or swipe left and tap View — to expand the flashcard.")
                        .font(.custom("Poppins-Regular", size: 12))
                        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.80) : LearnAlertStyle.textSecondary)
                        .lineSpacing(2.5)
                }
                Spacer(minLength: 0)
            }
            .padding(15)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.10) : Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.18) : Color.primary.opacity(0.08), lineWidth: 1)
            )

            // Primary Action Button
            Button(action: {
                InteractionSoundPlayer.shared.play(.selection)
                HapticFeedback.success()
                completion()
            }) {
                Label("Start Learning", systemImage: "sparkles")
                    .font(.custom("Poppins-SemiBold", size: 16))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
            }
            .foregroundStyle(.white)
            .background(LearnAlertStyle.indigo)
            .clipShape(Capsule())
            .shadow(color: LearnAlertStyle.indigo.opacity(0.40), radius: 10, y: 4)
            .padding(.top, 4)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    colorScheme == .dark
                    ? Color(red: 0.14, green: 0.16, blue: 0.25).opacity(0.96)
                    : Color.white.opacity(0.97)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            colorScheme == .dark ? Color.white.opacity(0.45) : Color.white,
                            colorScheme == .dark ? Color.white.opacity(0.12) : Color.white.opacity(0.6)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.45 : 0.16), radius: 30, y: 12)
    }
}
