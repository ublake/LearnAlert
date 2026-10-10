import SwiftUI
import UserNotifications

struct NotificationCustomizeView: View {
    @AppStorage("notificationCustomTheme", store: UserDefaults(suiteName: "group.com.learnalert.shared"))
    private var storedThemeRaw: String = NotificationTheme.defaultTheme.rawValue

    @AppStorage("notificationCustomLayout", store: UserDefaults(suiteName: "group.com.learnalert.shared"))
    private var storedLayoutRaw: String = NotificationLayoutMode.automatic.rawValue

    @AppStorage("appearanceMode") private var appearanceMode = "system"

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL

    @State private var previewCardType: FlashcardType = .multipleChoice
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
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Text("Customize").font(.largeTitle.weight(.bold)).foregroundStyle(StudyStudioStyle.ink)
                    Spacer()
                    Menu {
                        Menu("Preview format") {
                            ForEach(FlashcardType.allCases) { type in
                                Button { previewCardType = type } label: {
                                    if previewCardType == type { Label(type.title, systemImage: "checkmark") }
                                    else { Text(type.title) }
                                }
                            }
                        }
                        Button("Reset appearance", systemImage: "arrow.counterclockwise", action: resetToDefault)
                            .disabled(isDefaultSettings)
                    } label: {
                        Image(systemName: "ellipsis").font(.title3).frame(width: 44, height: 44)
                    }.accessibilityLabel("Appearance options")
                }
                NotificationSimulatedContainer(theme: currentTheme, layout: currentLayout,
                    cardType: previewCardType, isLight: isLight).id(previewCardType)
                CustomizeStyleControls(appearanceMode: $appearanceMode, layoutRaw: $storedLayoutRaw)
                VStack(alignment: .leading, spacing: 16) {
                    Text("Color").font(.headline).foregroundStyle(StudyStudioStyle.ink)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 8)], spacing: 12) {
                        ForEach(NotificationTheme.allCases) { theme in
                            let selected = currentTheme == theme
                            Button {
                                withAnimation(.snappy) { storedThemeRaw = theme.rawValue }
                                HapticFeedback.selection()
                            } label: {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(theme.previewGradient(isLight: isLight)).frame(width: 40, height: 40)
                                    .lightModeOutline(cornerRadius: 10, opacity: 0.75)
                                    .overlay {
                                        if selected { Image(systemName: "checkmark").font(.body.bold())
                                            .foregroundStyle(isLight || theme == .light ? Color(red: 0.10, green: 0.13, blue: 0.24) : .white) }
                                    }
                                    .padding(4)
                                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(selected ? StudyStudioStyle.ink : .clear, lineWidth: 2))
                            }.buttonStyle(.plain).frame(maxWidth: .infinity, minHeight: 48)
                                .accessibilityLabel(theme.title).accessibilityAddTraits(selected ? .isSelected : [])
                        }
                    }
                }
                VStack(spacing: 8) {
                    Button(action: sendTestNotification) {
                        Label(testScheduledSuccess ? "Sent · arrives in 3 seconds" : "Send a test alert",
                            systemImage: testScheduledSuccess ? "checkmark" : "bell")
                            .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 52)
                    }.buttonStyle(.bordered).tint(StudyStudioStyle.ink)
                    Text("Touch and hold your notification to expand it.")
                        .font(.footnote).foregroundStyle(StudyStudioStyle.secondary)
                }
            }.padding(.horizontal, 24).padding(.top, 16).padding(.bottom, 112)
                .frame(maxWidth: 600).frame(maxWidth: .infinity)
        }.background(StudyStudioStyle.canvas.ignoresSafeArea())
            .tint(StudyStudioStyle.blue)
            .alert("Notifications Not Allowed", isPresented: $showingPermissionAlert) {
                Button("Open Settings") { if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) } }
                Button("Cancel", role: .cancel) { }
            } message: { Text("Allow notifications in Settings to receive study alerts.") }
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

/// Two related preferences share one compact surface; native menus keep every option accessible.
struct CustomizeStyleControls: View {
    @Binding var appearanceMode: String
    @Binding var layoutRaw: String
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var symbolWidth = 20

    private var appearanceTitle: String {
        switch appearanceMode {
        case "light": "Light"
        case "dark": "Dark"
        default: "System"
        }
    }

    private var appearanceSymbol: String {
        switch appearanceMode {
        case "light": "sun.max"
        case "dark": "moon"
        default: "circle.lefthalf.filled"
        }
    }

    private var layout: NotificationLayoutMode {
        NotificationLayoutMode(rawValue: layoutRaw) ?? .automatic
    }

    var body: some View {
        let usesVerticalLayout = dynamicTypeSize.isAccessibilitySize
        let selectorLayout = usesVerticalLayout
            ? AnyLayout(VStackLayout(spacing: 0))
            : AnyLayout(HStackLayout(spacing: 0))

        selectorLayout {
            Menu {
                Picker("Appearance", selection: $appearanceMode) {
                    Label("System", systemImage: "circle.lefthalf.filled").tag("system")
                    Label("Light", systemImage: "sun.max").tag("light")
                    Label("Dark", systemImage: "moon").tag("dark")
                }
            } label: {
                selectorLabel("Appearance", value: appearanceTitle, symbol: appearanceSymbol)
            }
            .accessibilityLabel("Appearance")
            .accessibilityValue(appearanceTitle)

            Rectangle().fill(StudyStudioStyle.hairline)
                .frame(width: usesVerticalLayout ? nil : 1, height: usesVerticalLayout ? 1 : 32)
                .accessibilityHidden(true)

            Menu {
                Picker("Layout", selection: $layoutRaw) {
                    ForEach(NotificationLayoutMode.allCases) { mode in
                        Text(mode.title).tag(mode.rawValue)
                    }
                }
            } label: {
                selectorLabel("Layout", value: layout.title,
                    symbol: layout == .compact ? "rectangle.compress.vertical" : "rectangle.expand.vertical")
            }
            .accessibilityLabel("Layout")
            .accessibilityValue(layout.title)
        }
        .buttonStyle(.plain)
        .background(StudyStudioStyle.field, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .lightModeOutline(cornerRadius: 16)
        .onChange(of: appearanceMode) { _, _ in HapticFeedback.selection() }
        .onChange(of: layoutRaw) { _, _ in HapticFeedback.selection() }
    }

    private func selectorLabel(_ title: String, value: String, symbol: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol).font(.body).frame(width: symbolWidth)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.caption).foregroundStyle(StudyStudioStyle.secondary)
                Text(value).font(.subheadline.weight(.semibold))
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.down").font(.caption2.weight(.semibold))
                .foregroundStyle(StudyStudioStyle.secondary)
        }
        .foregroundStyle(StudyStudioStyle.ink)
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
        .contentShape(Rectangle())
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
                                Text("Try again")
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
        isThemeLight ? Color(red: 0.22, green: 0.29, blue: 0.39) : Color.white.opacity(0.70)
    }

    private func quizOptionTextColor(_ option: String) -> Color {
        guard let selected = selectedQuizChoice else { return textColorPrimary }
        if option == quizCorrectAnswer { return isThemeLight ? Color(red: 0.03, green: 0.36, blue: 0.18) : Color.green }
        if option == selected { return isThemeLight ? Color(red: 0.62, green: 0.10, blue: 0.12) : Color.red }
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
                LinearGradient(colors: theme.lightBackdropColors, startPoint: .topLeading, endPoint: .bottomTrailing)
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
