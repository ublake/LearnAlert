import SwiftUI
import UserNotifications

struct NotificationCustomizeView: View {
    @AppStorage("notificationCustomTheme", store: UserDefaults(suiteName: "group.com.learnalert.shared"))
    private var storedThemeRaw: String = NotificationTheme.defaultTheme.rawValue

    @AppStorage("notificationCustomLayout", store: UserDefaults(suiteName: "group.com.learnalert.shared"))
    private var storedLayoutRaw: String = NotificationLayoutMode.automatic.rawValue

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL

    @State private var previewCardType: FlashcardType = .multipleChoice
    @State private var showingCardTypeSheet = false
    @State private var showingPermissionAlert = false
    @State private var testScheduledSuccess = false

    private var isLight: Bool { colorScheme == .light }

    private var currentTheme: NotificationTheme {
        NotificationTheme(rawValue: storedThemeRaw) ?? .defaultTheme
    }

    private var currentLayout: NotificationLayoutMode {
        NotificationLayoutMode(rawValue: storedLayoutRaw) ?? .automatic
    }

    private var isDefaultSettings: Bool {
        storedThemeRaw == NotificationTheme.defaultTheme.rawValue &&
        storedLayoutRaw == NotificationLayoutMode.automatic.rawValue
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerSection
                cardTypeSelectorSection
                layoutSection
                themeSection
                previewSection
                testSection
                footnoteSection

                Spacer().frame(height: 120)
            }
            .padding(.top, 14)
        }
        .background(LearnAlertStyle.courseCanvas.ignoresSafeArea())
        .sheet(isPresented: $showingCardTypeSheet) {
            cardTypePickerSheet
        }
        .alert("Notifications Not Allowed", isPresented: $showingPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("LearnAlert needs notification permissions to send you study alerts. Please allow Notifications in your iPhone Settings.")
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Customize")
                    .font(.custom("Poppins-Bold", size: 30, relativeTo: .largeTitle))
                    .foregroundStyle(LearnAlertStyle.textPrimary)
                Text("Make your study notifications yours.")
                    .font(.custom("Poppins-Regular", size: 13, relativeTo: .subheadline))
                    .foregroundStyle(LearnAlertStyle.textSecondary)
            }
            Spacer()

            Button(action: resetToDefault) {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.caption2.bold())
                    Text("Reset")
                        .font(.custom("Poppins-Medium", size: 12))
                }
                .foregroundStyle(isDefaultSettings ? LearnAlertStyle.textSecondary.opacity(0.35) : LearnAlertStyle.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.primary.opacity(isDefaultSettings ? 0.02 : 0.06), in: Capsule())
            }
            .disabled(isDefaultSettings)
            .accessibilityLabel("Reset appearance to default")
        }
        .padding(.horizontal, 20)
    }

    // MARK: - 1. Preview Card Type Selector
    private var cardTypeSelectorSection: some View {
        Button {
            showingCardTypeSheet = true
            HapticFeedback.selection()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(LearnAlertStyle.indigo.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: previewCardType.icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(LearnAlertStyle.indigo)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Preview card type")
                        .font(.custom("Poppins-Regular", size: 11))
                        .foregroundStyle(LearnAlertStyle.textSecondary)
                    Text(previewCardType.title)
                        .font(.custom("Poppins-SemiBold", size: 14))
                        .foregroundStyle(LearnAlertStyle.textPrimary)
                }

                Spacer()

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(LearnAlertStyle.textSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(LearnAlertStyle.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(LearnAlertStyle.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .accessibilityLabel("Preview card type: \(previewCardType.title)")
    }

    // MARK: - Card Type Picker Sheet
    private var cardTypePickerSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Select a card format to preview how it appears in rich notifications. This only changes the preview example.")
                        .font(.custom("Poppins-Regular", size: 13))
                        .foregroundStyle(LearnAlertStyle.textSecondary)
                        .padding(.horizontal, 20)
                        .padding(.top, 10)

                    VStack(spacing: 8) {
                        ForEach(FlashcardType.allCases) { type in
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                    previewCardType = type
                                }
                                HapticFeedback.selection()
                                showingCardTypeSheet = false
                            } label: {
                                HStack(spacing: 14) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(previewCardType == type ? LearnAlertStyle.indigo.opacity(0.15) : Color.primary.opacity(0.05))
                                            .frame(width: 40, height: 40)
                                        Image(systemName: type.icon)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(previewCardType == type ? LearnAlertStyle.indigo : LearnAlertStyle.textSecondary)
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(type.title)
                                            .font(.custom("Poppins-SemiBold", size: 15))
                                            .foregroundStyle(LearnAlertStyle.textPrimary)
                                        Text(type.subtitle)
                                            .font(.custom("Poppins-Regular", size: 12))
                                            .foregroundStyle(LearnAlertStyle.textSecondary)
                                            .lineLimit(2)
                                    }

                                    Spacer()

                                    if previewCardType == type {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(LearnAlertStyle.indigo)
                                    }
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(previewCardType == type ? LearnAlertStyle.indigo.opacity(0.08) : LearnAlertStyle.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(previewCardType == type ? LearnAlertStyle.indigo.opacity(0.5) : LearnAlertStyle.hairline, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 24)
            }
            .background(LearnAlertStyle.courseCanvas.ignoresSafeArea())
            .navigationTitle("Preview Card Type")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showingCardTypeSheet = false
                    }
                    .font(.custom("Poppins-SemiBold", size: 14))
                    .foregroundStyle(LearnAlertStyle.indigo)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - 2. Layout Section
    private var layoutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("LAYOUT")
                    .font(.custom("Poppins-SemiBold", size: 11, relativeTo: .caption))
                    .tracking(1.1)
                    .foregroundStyle(LearnAlertStyle.textSecondary)
                Spacer()
                Text(currentLayout.title)
                    .font(.custom("Poppins-Medium", size: 12))
                    .foregroundStyle(LearnAlertStyle.indigo)
            }

            HStack(spacing: 8) {
                ForEach(NotificationLayoutMode.allCases) { mode in
                    Button {
                        withAnimation(.snappy) {
                            storedLayoutRaw = mode.rawValue
                        }
                        HapticFeedback.selection()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: mode == .automatic ? "aspectratio.fill" : "arrow.down.right.and.arrow.up.left")
                                .font(.system(size: 13, weight: .semibold))
                            Text(mode.title)
                                .font(.custom("Poppins-Medium", size: 13))
                        }
                        .foregroundStyle(currentLayout == mode ? Color.white : LearnAlertStyle.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(
                            currentLayout == mode
                                ? AnyShapeStyle(LearnAlertStyle.indigo)
                                : AnyShapeStyle(Color.primary.opacity(0.04))
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(LearnAlertStyle.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(LearnAlertStyle.hairline, lineWidth: 1)
            )

            Text("Automatic matches standard notification spacing, while Compact condenses vertical padding for faster study.")
                .font(.custom("Poppins-Regular", size: 11))
                .foregroundStyle(LearnAlertStyle.textSecondary.opacity(0.85))
                .padding(.horizontal, 4)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - 3. Background Section
    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("BACKGROUND")
                    .font(.custom("Poppins-SemiBold", size: 11, relativeTo: .caption))
                    .tracking(1.1)
                    .foregroundStyle(LearnAlertStyle.textSecondary)
                Spacer()
                Text(currentTheme.title)
                    .font(.custom("Poppins-Medium", size: 12))
                    .foregroundStyle(LearnAlertStyle.indigo)
            }

            HStack(spacing: 8) {
                ForEach(NotificationTheme.allCases) { theme in
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            storedThemeRaw = theme.rawValue
                        }
                        HapticFeedback.selection()
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(theme.previewGradient)
                                .frame(height: 46)

                            if currentTheme == theme {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.white, lineWidth: 2.2)
                                    .shadow(color: Color.black.opacity(0.35), radius: 3)

                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(theme == .light ? Color.black : Color.white)
                            } else {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(theme.title)
                }
            }
            .padding(6)
            .background(LearnAlertStyle.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(LearnAlertStyle.hairline, lineWidth: 1)
            )
        }
        .padding(.horizontal, 20)
    }

    // MARK: - 4. Live Notification Preview Section
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("LIVE NOTIFICATION PREVIEW")
                .font(.custom("Poppins-SemiBold", size: 11, relativeTo: .caption))
                .tracking(1.1)
                .foregroundStyle(LearnAlertStyle.textSecondary)
                .padding(.horizontal, 20)

            NotificationSimulatedContainer(
                theme: currentTheme,
                layout: currentLayout,
                cardType: previewCardType,
                isLight: isLight
            )
            .padding(.horizontal, 20)
        }
    }

    // MARK: - 5. Test on Device Section
    private var testSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TEST ON DEVICE")
                .font(.custom("Poppins-SemiBold", size: 11, relativeTo: .caption))
                .tracking(1.1)
                .foregroundStyle(LearnAlertStyle.textSecondary)

            Button(action: sendTestNotification) {
                HStack(spacing: 10) {
                    if testScheduledSuccess {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                        Text("Alert Sent in 3s!")
                            .font(.custom("Poppins-SemiBold", size: 14))
                            .foregroundStyle(.white)
                    } else {
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                        Text("Send Test Notification")
                            .font(.custom("Poppins-SemiBold", size: 14))
                            .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    LinearGradient(
                        colors: testScheduledSuccess
                            ? [Color.green.opacity(0.9), Color.green]
                            : [LearnAlertStyle.indigo, LearnAlertStyle.indigo.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(
                    color: testScheduledSuccess ? Color.green.opacity(0.3) : LearnAlertStyle.indigo.opacity(0.3),
                    radius: 8,
                    y: 3
                )
            }
        }
        .padding(18)
        .background(LearnAlertStyle.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(LearnAlertStyle.hairline, lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }

    // MARK: - 6. Footnote Section
    private var footnoteSection: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .font(.caption)
                .foregroundStyle(LearnAlertStyle.textSecondary)
                .padding(.top, 1)
            Text("These settings change your expanded notifications. Touch and hold a notification to see your design.")
                .font(.custom("Poppins-Regular", size: 12))
                .foregroundStyle(LearnAlertStyle.textSecondary.opacity(0.85))
                .lineSpacing(2)
        }
        .padding(.horizontal, 24)
    }

    private func resetToDefault() {
        guard !isDefaultSettings else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            storedThemeRaw = NotificationTheme.defaultTheme.rawValue
            storedLayoutRaw = NotificationLayoutMode.automatic.rawValue
        }
        HapticFeedback.success()
    }

    private func sendTestNotification() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .authorized, .provisional, .ephemeral:
                    triggerNotification()

                case .notDetermined:
                    Task { @MainActor in
                        let granted = await NotificationManager.shared.requestPermission()
                        if granted {
                            triggerNotification()
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

    private func triggerNotification() {
        NotificationManager.shared.scheduleTutorialAlert(
            deckTitle: "Example",
            question: "Which planet is known for its rings?",
            options: ["Saturn", "Jupiter", "Mars", "Neptune"],
            correctAnswer: "Saturn",
            hint: "It is the sixth planet from the Sun."
        )

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

// MARK: - Matching Preview Model
private struct MatchingPreviewPair: Identifiable {
    let id = UUID()
    let left: String
    let right: String
}

// MARK: - Simulated Notification Container
private struct NotificationSimulatedContainer: View {
    let theme: NotificationTheme
    let layout: NotificationLayoutMode
    let cardType: FlashcardType
    let isLight: Bool

    // Preview Interactive State
    @State private var selectedQuizChoice: String? = nil
    @State private var isRevealed = false
    @State private var isGraded = false
    @State private var showingHint = false
    @State private var typedBlank = ""
    @State private var selectedMatchingLeft: String? = nil
    @State private var matchingAssignments: [String: String] = [:]
    @State private var matchingResults: [String: Bool] = [:]

    private var isCompact: Bool { layout == .compact }

    private var questionText: String {
        switch cardType {
        case .vocabulary:
            return "Ephemeral"
        case .multipleChoice:
            return "Which planet is known for its rings?"
        case .tapReveal:
            return "What is the capital of Australia?"
        case .matching:
            return "Match each learning strategy to its core concept:"
        case .fillBlank:
            return "Photosynthesis converts light into chemical _______ in plants."
        }
    }

    private var vocabularyDefinition: String {
        "Lasting for a very short time; fleeting or momentary in nature."
    }

    private var quizOptions: [String] {
        [
            "Saturn",
            "Jupiter",
            "Mars",
            "Neptune"
        ]
    }

    private var quizCorrectAnswer: String { "Saturn" }

    private var revealAnswer: String {
        "Canberra"
    }

    private var hintText: String {
        switch cardType {
        case .multipleChoice:
            return "It is the sixth planet from the Sun."
        case .tapReveal:
            return "Chosen as a compromise between Sydney and Melbourne."
        case .vocabulary:
            return ""
        case .matching:
            return "Connect cognitive techniques to their core definitions."
        case .fillBlank:
            return "Begins with the letter 'e'."
        }
    }

    private var matchingPreviewPairs: [MatchingPreviewPair] {
        [
            MatchingPreviewPair(left: "Spaced Repetition", right: "Expanding intervals"),
            MatchingPreviewPair(left: "Active Recall", right: "Retrieval practice"),
            MatchingPreviewPair(left: "Interleaving", right: "Mixed topics")
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            // Simulated iOS Notification Header Banner
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(LearnAlertStyle.indigo)
                        .frame(width: 20, height: 20)
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.white)
                }

                Text("LEARNALERT")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.secondary)

                Spacer()

                Text("now")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                isLight
                    ? Color(red: 0.94, green: 0.95, blue: 0.98).opacity(0.95)
                    : Color(red: 0.12, green: 0.14, blue: 0.18).opacity(0.95)
            )

            // Custom Notification Flashcard Canvas
            ZStack {
                NotificationThemeBackdrop(theme: theme, isLight: isLight)

                VStack(spacing: isCompact ? 10 : 16) {
                    // Top Deck & Header Bar
                    HStack(alignment: .top, spacing: 8) {
                        HStack(spacing: 5) {
                            Image(systemName: "books.vertical.fill")
                                .font(.caption2)
                            Text("Example")
                                .font(.system(size: isCompact ? 12 : 13, weight: .bold))
                        }
                        .foregroundStyle(textColorPrimary)
                        .padding(.top, 4)

                        Spacer()

                        HStack(spacing: 6) {
                            if cardType != .vocabulary && !hintText.isEmpty && !isGraded {
                                Button {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                        showingHint.toggle()
                                    }
                                } label: {
                                    Image(systemName: showingHint ? "lightbulb.slash.fill" : "lightbulb.fill")
                                        .font(.system(size: isCompact ? 12 : 13, weight: .bold))
                                        .foregroundStyle(Color.orange)
                                        .frame(width: isCompact ? 30 : 34, height: isCompact ? 30 : 34)
                                        .glassCard(cornerRadius: 10, tint: Color.orange.opacity(0.12), isLight: isLight)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(showingHint ? "Hide hint" : "Show hint")
                            }

                            Button {
                                // Settings preview
                            } label: {
                                Image(systemName: "gearshape.fill")
                                    .font(.system(size: isCompact ? 12 : 13, weight: .semibold))
                                    .foregroundStyle(textColorPrimary)
                                    .frame(width: isCompact ? 30 : 34, height: isCompact ? 30 : 34)
                                    .glassCard(cornerRadius: 10, isLight: isLight)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Interactive Card Area based on Card Type
                    VStack(alignment: .leading, spacing: isCompact ? 10 : 14) {
                        switch cardType {
                        case .vocabulary:
                            vocabularyPreview
                        case .multipleChoice:
                            multipleChoicePreview
                        case .tapReveal:
                            revealPreview
                        case .matching:
                            matchingPreview
                        case .fillBlank:
                            fillBlankPreview
                        }
                    }

                    // Bottom Hint / Skip Controls
                    if cardType != .vocabulary && !isGraded {
                        if showingHint && !hintText.isEmpty {
                            Text("Hint: \(hintText)")
                                .font(.system(size: 11, weight: .medium, design: .serif))
                                .italic()
                                .foregroundStyle(Color.orange)
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .glassCard(cornerRadius: 10, tint: Color.orange.opacity(0.08), isLight: isLight)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        HStack(alignment: .center) {
                            Color.clear
                                .frame(width: 36, height: 1)

                            Spacer()

                            Text("3/10")
                                .font(.system(size: isCompact ? 11 : 12, weight: .semibold, design: .monospaced))
                                .foregroundStyle(textColorSecondary)

                            Spacer()

                            Button {
                                withAnimation(.snappy) {
                                    resetPreviewInteractions()
                                }
                            } label: {
                                Image(systemName: "forward.fill")
                                    .font(.system(size: isCompact ? 12 : 13, weight: .bold))
                                    .foregroundStyle(textColorSecondary)
                                    .frame(width: 36, height: isCompact ? 30 : 34)
                                    .glassCard(cornerRadius: 10, isLight: isLight)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Skip")
                        }
                    }

                    // Next Card Post-Grading Button
                    if isGraded {
                        Button {
                            withAnimation(.snappy) {
                                resetPreviewInteractions()
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.right.circle.fill")
                                Text("Next Card (Preview)")
                            }
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: isCompact ? 40 : 44)
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.12, green: 0.50, blue: 0.98),
                                        Color(red: 0.20, green: 0.68, blue: 0.96)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(isCompact ? 12 : 18)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.20), radius: 16, y: 8)
        .onChange(of: cardType) { _, _ in
            resetPreviewInteractions()
        }
    }

    private func resetPreviewInteractions() {
        selectedQuizChoice = nil
        isRevealed = false
        isGraded = false
        showingHint = false
        typedBlank = ""
        selectedMatchingLeft = nil
        matchingAssignments.removeAll()
        matchingResults.removeAll()
    }

    // MARK: - Vocabulary Preview
    private var vocabularyPreview: some View {
        VStack(spacing: isCompact ? 8 : 12) {
            Text(questionText)
                .font(.system(size: isCompact ? 22 : 26, weight: .bold, design: .serif))
                .foregroundStyle(textColorPrimary)

            Text("/ɪˈfem(ə)rəl/ • adjective")
                .font(.system(size: isCompact ? 11 : 12, weight: .medium, design: .serif))
                .italic()
                .foregroundStyle(textColorSecondary)

            Text(vocabularyDefinition)
                .font(.system(size: isCompact ? 12 : 14, weight: .regular))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .foregroundStyle(textColorPrimary)
                .padding(isCompact ? 10 : 14)
                .frame(maxWidth: .infinity)
                .glassCard(cornerRadius: 12, isLight: isLight)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Multiple Choice Preview
    private var multipleChoicePreview: some View {
        VStack(alignment: .leading, spacing: isCompact ? 8 : 12) {
            Text(questionText)
                .font(.system(size: isCompact ? 13 : 15, weight: .semibold))
                .foregroundStyle(textColorPrimary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: isCompact ? 6 : 8) {
                ForEach(quizOptions, id: \.self) { option in
                    Button {
                        guard !isGraded else { return }
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            selectedQuizChoice = option
                            isGraded = true
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Text(option)
                                .font(.system(size: isCompact ? 12 : 13, weight: .medium))
                                .foregroundStyle(quizOptionTextColor(option))
                                .multilineTextAlignment(.leading)

                            Spacer()

                            if isGraded {
                                if option == quizCorrectAnswer {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.green)
                                } else if option == selectedQuizChoice {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(Color.red)
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, isCompact ? 9 : 11)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassCard(
                            cornerRadius: 10,
                            tint: quizOptionTint(option),
                            isLight: isLight,
                            customBorderColor: quizOptionBorder(option)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isGraded)
                }
            }
        }
    }

    // MARK: - Tap Reveal Preview
    private var revealPreview: some View {
        VStack(alignment: .leading, spacing: isCompact ? 10 : 14) {
            Text(questionText)
                .font(.system(size: isCompact ? 13 : 15, weight: .semibold))
                .foregroundStyle(textColorPrimary)

            if !isRevealed {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        isRevealed = true
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "hand.tap.fill")
                        Text("Tap to Reveal Answer")
                    }
                    .font(.system(size: isCompact ? 12 : 13, weight: .bold))
                    .foregroundStyle(textColorPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: isCompact ? 44 : 50)
                    .glassCard(cornerRadius: 12, isLight: isLight)
                }
                .buttonStyle(.plain)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ANSWER")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(LearnAlertStyle.sky)
                    Text(revealAnswer)
                        .font(.system(size: isCompact ? 13 : 14, weight: .medium))
                        .foregroundStyle(textColorPrimary)
                        .lineSpacing(3)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard(cornerRadius: 12, tint: Color.green.opacity(0.08), isLight: isLight)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))

                if !isGraded {
                    HStack(spacing: 8) {
                        Button {
                            withAnimation(.snappy) { isGraded = true }
                        } label: {
                            Label("Got it", systemImage: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.green)
                                .frame(maxWidth: .infinity)
                                .frame(height: 38)
                                .glassCard(cornerRadius: 10, tint: Color.green.opacity(0.12), isLight: isLight)
                        }

                        Button {
                            withAnimation(.snappy) { isGraded = true }
                        } label: {
                            Label("Missed", systemImage: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.red)
                                .frame(maxWidth: .infinity)
                                .frame(height: 38)
                                .glassCard(cornerRadius: 10, tint: Color.red.opacity(0.12), isLight: isLight)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Matching Preview
    private var matchingPreview: some View {
        VStack(alignment: .leading, spacing: isCompact ? 8 : 10) {
            Text(questionText)
                .font(.system(size: isCompact ? 12 : 14, weight: .semibold))
                .foregroundStyle(textColorPrimary)

            ForEach(matchingPreviewPairs) { pair in
                HStack(spacing: 6) {
                    Button {
                        withAnimation(.snappy) {
                            selectedMatchingLeft = pair.left
                        }
                    } label: {
                        Text(pair.left)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(textColorPrimary)
                            .padding(8)
                            .frame(maxWidth: .infinity)
                            .glassCard(
                                cornerRadius: 8,
                                tint: selectedMatchingLeft == pair.left ? LearnAlertStyle.indigo.opacity(0.20) : nil,
                                isLight: isLight
                            )
                    }
                    .buttonStyle(.plain)

                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(textColorSecondary)

                    Button {
                        if let selected = selectedMatchingLeft {
                            withAnimation(.snappy) {
                                matchingAssignments[selected] = pair.right
                                matchingResults[selected] = (pair.left == selected)
                                selectedMatchingLeft = nil
                                if matchingAssignments.count >= 3 {
                                    isGraded = true
                                }
                            }
                        }
                    } label: {
                        Text(matchingAssignments[pair.left] ?? pair.right)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(textColorPrimary)
                            .padding(8)
                            .frame(maxWidth: .infinity)
                            .glassCard(
                                cornerRadius: 8,
                                tint: matchingResults[pair.left] == true ? Color.green.opacity(0.15) : nil,
                                isLight: isLight
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Fill in Blank Preview
    private var fillBlankPreview: some View {
        VStack(alignment: .leading, spacing: isCompact ? 8 : 12) {
            Text(questionText)
                .font(.system(size: isCompact ? 13 : 15, weight: .semibold))
                .foregroundStyle(textColorPrimary)
                .lineSpacing(3)

            HStack(spacing: 8) {
                TextField("Type your answer...", text: $typedBlank)
                    .font(.system(size: 13))
                    .foregroundStyle(textColorPrimary)
                    .padding(10)
                    .glassCard(cornerRadius: 10, isLight: isLight)
                    .disabled(isGraded)

                Button {
                    guard !typedBlank.isEmpty else { return }
                    withAnimation(.snappy) { isGraded = true }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(LearnAlertStyle.indigo)
                }
                .buttonStyle(.plain)
                .disabled(isGraded || typedBlank.isEmpty)
            }

            if isGraded {
                HStack(spacing: 6) {
                    Image(systemName: typedBlank.lowercased().trimmingCharacters(in: .whitespaces) == "energy" ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(typedBlank.lowercased().trimmingCharacters(in: .whitespaces) == "energy" ? Color.green : Color.red)
                    Text("Correct answer: energy")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(textColorPrimary)
                }
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .glassCard(cornerRadius: 10, tint: Color.green.opacity(0.12), isLight: isLight)
            }
        }
    }

    private var isThemeLight: Bool {
        theme == .light || isLight
    }

    private var textColorPrimary: Color {
        isThemeLight ? Color(red: 0.10, green: 0.13, blue: 0.24) : Color.white
    }

    private var textColorSecondary: Color {
        isThemeLight ? Color(red: 0.38, green: 0.44, blue: 0.58) : Color.white.opacity(0.70)
    }

    private func quizOptionTextColor(_ option: String) -> Color {
        guard let selected = selectedQuizChoice else { return textColorPrimary }
        if option == quizCorrectAnswer { return Color.green }
        if option == selected { return Color.red }
        return textColorSecondary
    }

    private func quizOptionTint(_ option: String) -> Color? {
        guard let selected = selectedQuizChoice else { return nil }
        if option == quizCorrectAnswer { return Color.green.opacity(0.16) }
        if option == selected { return Color.red.opacity(0.16) }
        return nil
    }

    private func quizOptionBorder(_ option: String) -> Color? {
        guard let selected = selectedQuizChoice else { return nil }
        if option == quizCorrectAnswer { return Color.green.opacity(0.8) }
        if option == selected { return Color.red.opacity(0.8) }
        return nil
    }
}

// MARK: - Dynamic Theme Backdrop
struct NotificationThemeBackdrop: View {
    var theme: NotificationTheme
    var isLight: Bool

    var body: some View {
        ZStack {
            if isLight {
                switch theme {
                case .defaultTheme:
                    LinearGradient(
                        colors: [
                            Color(red: 0.93, green: 0.96, blue: 1.0),
                            Color(red: 0.88, green: 0.93, blue: 0.98),
                            Color(red: 0.93, green: 0.90, blue: 0.99)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                case .midnight:
                    LinearGradient(
                        colors: [
                            Color(red: 0.91, green: 0.93, blue: 0.96),
                            Color(red: 0.84, green: 0.87, blue: 0.92)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                case .aurora:
                    LinearGradient(
                        colors: [
                            Color(red: 0.90, green: 0.98, blue: 0.94),
                            Color(red: 0.82, green: 0.94, blue: 0.90)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                case .sunset:
                    LinearGradient(
                        colors: [
                            Color(red: 0.99, green: 0.92, blue: 0.92),
                            Color(red: 0.95, green: 0.88, blue: 0.95)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                case .slate:
                    LinearGradient(
                        colors: [
                            Color(red: 0.92, green: 0.93, blue: 0.95),
                            Color(red: 0.86, green: 0.88, blue: 0.91)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                case .light:
                    LinearGradient(
                        colors: [
                            Color(red: 0.97, green: 0.98, blue: 1.0),
                            Color(red: 0.90, green: 0.93, blue: 0.98)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            } else {
                switch theme {
                case .defaultTheme:
                    LinearGradient(
                        colors: [
                            Color(red: 0.08, green: 0.10, blue: 0.22),
                            Color(red: 0.04, green: 0.05, blue: 0.14)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .overlay {
                        Circle()
                            .fill(Color(red: 0.25, green: 0.40, blue: 0.95).opacity(0.35))
                            .frame(width: 220, height: 220)
                            .blur(radius: 40)
                            .offset(x: -80, y: -60)

                        Circle()
                            .fill(Color(red: 0.15, green: 0.80, blue: 0.95).opacity(0.20))
                            .frame(width: 180, height: 180)
                            .blur(radius: 40)
                            .offset(x: 100, y: 80)
                    }
                case .midnight:
                    Color(red: 0.03, green: 0.03, blue: 0.05)
                        .overlay {
                            Circle()
                                .fill(Color(red: 0.20, green: 0.30, blue: 0.55).opacity(0.18))
                                .frame(width: 240, height: 240)
                                .blur(radius: 60)
                        }
                case .aurora:
                    LinearGradient(
                        colors: [
                            Color(red: 0.02, green: 0.14, blue: 0.12),
                            Color(red: 0.01, green: 0.08, blue: 0.07)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .overlay {
                        Circle()
                            .fill(Color(red: 0.10, green: 0.85, blue: 0.55).opacity(0.28))
                            .frame(width: 220, height: 220)
                            .blur(radius: 50)
                            .offset(x: -60, y: -40)
                    }
                case .sunset:
                    LinearGradient(
                        colors: [
                            Color(red: 0.18, green: 0.06, blue: 0.15),
                            Color(red: 0.08, green: 0.02, blue: 0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .overlay {
                        Circle()
                            .fill(Color(red: 0.95, green: 0.35, blue: 0.40).opacity(0.28))
                            .frame(width: 200, height: 200)
                            .blur(radius: 45)
                            .offset(x: 80, y: -40)
                    }
                case .slate:
                    LinearGradient(
                        colors: [
                            Color(red: 0.13, green: 0.14, blue: 0.17),
                            Color(red: 0.08, green: 0.09, blue: 0.11)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                case .light:
                    LinearGradient(
                        colors: [
                            Color(red: 0.95, green: 0.96, blue: 0.98),
                            Color(red: 0.88, green: 0.91, blue: 0.96)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .overlay {
                        Circle()
                            .fill(Color(red: 0.20, green: 0.60, blue: 0.98).opacity(0.12))
                            .frame(width: 220, height: 220)
                            .blur(radius: 45)
                            .offset(x: -60, y: -40)
                    }
                }
            }
        }
    }
}

// MARK: - Glass Card Modifier
private struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 12
    var tint: Color? = nil
    var isLight: Bool = false
    var customBorderColor: Color? = nil

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(tint ?? (isLight ? Color.white.opacity(0.65) : Color.white.opacity(0.08)))
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        customBorderColor ?? (isLight ? Color.black.opacity(0.08) : Color.white.opacity(0.14)),
                        lineWidth: customBorderColor != nil ? 1.5 : 1
                    )
            }
    }
}

private extension View {
    func glassCard(cornerRadius: CGFloat = 12, tint: Color? = nil, isLight: Bool = false, customBorderColor: Color? = nil) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, tint: tint, isLight: isLight, customBorderColor: customBorderColor))
    }
}
