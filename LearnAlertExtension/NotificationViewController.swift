//
//  NotificationViewController.swift
//  LearnAlertExtension
//
//  Created by Blake Miller on 2/19/26.
//

import UIKit
import UserNotifications
import UserNotificationsUI
import SwiftUI
import SwiftData
import AVFoundation

private struct NotificationSessionCard {
    let id: String
    let deckId: String
    let deckName: String
    let deckType: String
    let cardType: String
    let question: String
    let options: [String]
    let correctAnswer: String
    let hint: String
    let matchingLeftItems: [String]
    let matchingRightItems: [String]
    var promptImageName: String? = nil
    var answerImageName: String? = nil
    var ankiContentData: Data? = nil
    var fieldMedia: [String: CardFieldMedia] = [:]
    var correctOptionIndex: Int? = nil
    var optionImageNames: [String] = []
    var readingPrompt: String? = nil
}

private struct NotificationDeckChoice: Identifiable {
    let id: UUID
    let name: String
}

@MainActor
private final class NotificationFeedbackSoundPlayer {
    static let shared = NotificationFeedbackSoundPlayer()
    private var player: AVAudioPlayer?

    private init() {}

    func play(named name: String) {
        guard let url = soundURL(named: name),
              let player = try? AVAudioPlayer(contentsOf: url) else { return }
        self.player = player
        player.prepareToPlay()
        player.play()
    }

    private func soundURL(named name: String) -> URL? {
        if let bundledURL = Bundle.main.url(forResource: name, withExtension: "mp3") {
            return bundledURL
        }

        let hostAppURL = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return Bundle(url: hostAppURL)?.url(forResource: name, withExtension: "mp3")
    }
}

private struct NotificationContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        if next > 0 { value = next }
    }
}

struct FlashcardNotificationView: View {
    var cardId: String
    var deckId: String
    var deckName: String
    var deckType: String
    var cardType: String = ""
    var isRandom: Bool
    var progress: String
    var question: String
    var options: [String]
    var correctAnswer: String
    var hint: String
    var matchingLeftItems: [String] = []
    var matchingRightItems: [String] = []
    var promptImageName: String? = nil
    var answerImageName: String? = nil
    var ankiContentData: Data? = nil
    var fieldMedia: [String: CardFieldMedia] = [:]
    var correctOptionIndex: Int? = nil
    var optionImageNames: [String] = []
    var notificationRequestID: String? = nil
    var readingPrompt: String? = nil
    var previewMode = false
    var isTutorial = false
    var isCustomizationTest = false
    var appearance = NotificationAppearance.saved()
    var openApp: () -> Void = { }
    var onContentHeightChange: ((CGFloat) -> Void)? = nil

    @State private var ankiIsLoading = true
    @State private var ankiReviewOptions: [AnkiReviewOption] = []
    @State private var ankiFutureReviewDate: Date?
    @FocusState private var isAnswerFieldFocused: Bool

    @Environment(\.colorScheme) private var systemColorScheme
    @Environment(\.notificationViewportCompact) private var viewportCompact
    @Environment(\.notificationViewportHeight) private var viewportHeight

    @State private var selectedAnswer: String? = nil
    @State private var isRevealed = false
    @State private var hasViewedImageBack = false
    @State private var isGraded = false
    @State private var isSkipped = false
    @State private var showingHint = false
    @State private var showingControls = false
    @State private var sessionCard: NotificationSessionCard?
    @State private var completedCount = 0
    @State private var lastAnswerWasCorrect: Bool?
    @State private var seenCardIds: Set<String> = []
    @State private var availableDecks: [NotificationDeckChoice] = []
    @State private var statusMessage: String?
    @State private var typedAnswer = ""
    @State private var selectedMatchingLeft: String?
    @State private var matchingAssignments: [String: String] = [:]
    @State private var matchingResults: [String: Bool] = [:]
    @State private var hadMatchingMistake = false

    // Session Stats
    @State private var unlearnedCount: Int = 0
    @State private var learningCount: Int = 0
    @State private var masteredCount: Int = 0

    private var cardProgressionText: String {
        if progress.contains("/") {
            return progress
        }
        if !progress.isEmpty && progress != "-" && !progress.lowercased().contains("tutorial") {
            return progress
        }
        return "\(completedCount + 1)/10"
    }

    // MARK: - Appearance & Customization Dynamics
    private var effectiveColorScheme: ColorScheme {
        let mode = appearance.mode
        if mode == "light" { return .light }
        if mode == "dark" { return .dark }
        return systemColorScheme
    }

    private var customTheme: String {
        appearance.theme.rawValue
    }

    private var isCompactLayout: Bool {
        appearance.layout == .compact || viewportCompact
    }

    private var isLight: Bool {
        if customTheme == "light" { return true }
        return effectiveColorScheme == .light
    }

    private var textColorPrimary: Color {
        isLight ? Color(red: 0.10, green: 0.13, blue: 0.24) : Color.white
    }

    private var textColorSecondary: Color {
        isLight ? Color(red: 0.22, green: 0.29, blue: 0.39) : Color.white.opacity(0.68)
    }

    private var activeCardId: String { sessionCard?.id ?? cardId }
    private var activeDeckId: String { sessionCard?.deckId ?? deckId }
    private var activeDeckName: String { sessionCard?.deckName ?? deckName }
    private var activeDeckType: String { sessionCard?.deckType ?? deckType }
    private var activeCardType: String {
        sessionCard?.cardType ?? (cardType.isEmpty ? (activeOptions.count >= 2 ? "multiple_choice" : "tap_reveal") : cardType)
    }

    private var activeAnkiContent: AnkiCardContent? {
        let data = sessionCard == nil ? ankiContentData : sessionCard?.ankiContentData
        return data.flatMap { try? JSONDecoder().decode(AnkiCardContent.self, from: $0) }
    }
    private var activeQuestion: String { sessionCard?.question ?? question }
    private var activeOptions: [String] { sessionCard?.options ?? options }
    private var activeCorrectAnswer: String { sessionCard?.correctAnswer ?? correctAnswer }
    private var activeHint: String { sessionCard?.hint ?? hint }
    private var activeMatchingLeftItems: [String] { sessionCard?.matchingLeftItems ?? matchingLeftItems }
    private var activeMatchingRightItems: [String] { sessionCard?.matchingRightItems ?? matchingRightItems }
    private var activePromptImageName: String? {
        if let sessionCard { return sessionCard.promptImageName }
        return promptImageName
    }
    private var activeAnswerImageName: String? {
        if let sessionCard { return sessionCard.answerImageName }
        return answerImageName
    }
    private var hasImageBack: Bool { activeAnswerImageName?.isEmpty == false }
    private var canReviewImages: Bool {
        guard CardImageStore.loadImage(named: activePromptImageName) != nil else { return false }
        return !hasImageBack || (hasViewedImageBack && CardImageStore.loadImage(named: activeAnswerImageName) != nil)
    }
    private var activeOptionImageNames: [String] { sessionCard?.optionImageNames ?? optionImageNames }
    private var activeMedia: [String: CardFieldMedia] {
        var fields = sessionCard?.fieldMedia ?? fieldMedia
        if fields["prompt"] == nil { fields["prompt"] = .init(image: activePromptImageName) }
        if fields["answer"] == nil { fields["answer"] = .init(image: activeAnswerImageName) }
        for (i, name) in activeOptionImageNames.enumerated() where fields["option:\(i)"] == nil && !name.isEmpty { fields["option:\(i)"] = .init(image: name) }
        return fields
    }
    private var activeCorrectIndex: Int? { sessionCard?.correctOptionIndex ?? correctOptionIndex ?? activeOptions.firstIndex(of: activeCorrectAnswer) }
    private var hasHint: Bool { (activeMedia["hint"] ?? .init()).hasContent(activeHint) }


    private var isAppOpen: Bool {
        UserDefaults(suiteName: "group.com.learnalert.shared")?.bool(forKey: "isAppInForeground") ?? false
    }

    private var notificationControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Notification Controls", systemImage: "slider.horizontal.3")
                .font(.headline.bold())
                .foregroundStyle(textColorPrimary)

            // Change Active Deck in Mini-Session
            if !availableDecks.isEmpty {
                Menu {
                    ForEach(availableDecks) { deck in
                        Button(deck.name) {
                            loadNextCard(from: deck.id)
                            showingControls = false
                        }
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "rectangle.stack.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Change mini-session deck")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                    }
                    .foregroundStyle(textColorPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(
                        isLight
                            ? Color.white.opacity(0.60)
                            : Color.white.opacity(0.08)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }

            // Stop Scheduled Alerts
            Button(role: .destructive) {
                stopScheduledAlerts()
                showingControls = false
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "bell.slash.fill")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Stop scheduled notifications")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                }
                .foregroundStyle(Color.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.red.opacity(isLight ? 0.12 : 0.20))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)

            if let statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(textColorSecondary)
            }
        }
        .padding(14)
        .notificationLiquidGlass(cornerRadius: 18, isLight: isLight)
    }

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
            VStack(spacing: isCompactLayout ? 10 : 18) {
                // Header Bar: Deck Name, Hint, Controls
                HStack(alignment: .top, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "rectangle.stack.fill")
                            .font(.system(size: isCompactLayout ? 12 : 13, weight: .bold))
                            .foregroundStyle(Color(red: 0.12, green: 0.50, blue: 0.98))
                        Text(activeDeckName)
                            .font(.system(size: isCompactLayout ? 12 : 13, weight: .bold))
                            .foregroundStyle(textColorPrimary)
                    }
                    .padding(.top, 4)

                    Spacer()

                    HStack(spacing: 8) {
                        if hasHint && selectedAnswer == nil && !isRevealed && !isGraded && !isSkipped {
                            Button {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    showingHint.toggle()
                                    if showingHint { recordHintUsed() }
                                }
                            } label: {
                                Image(systemName: showingHint ? "lightbulb.slash.fill" : "lightbulb.fill")
                                    .font(.system(size: isCompactLayout ? 13 : 14, weight: .semibold))
                                    .foregroundStyle(Color.orange)
                                    .frame(width: isCompactLayout ? 32 : 36, height: isCompactLayout ? 32 : 36)
                                    .notificationLiquidGlass(cornerRadius: isCompactLayout ? 16 : 18, tint: Color.orange.opacity(0.12), isLight: isLight)
                            }
                            .accessibilityLabel(showingHint ? "Hide hint" : "Show hint")
                        }

                        Button {
                            withAnimation(.snappy) { showingControls.toggle() }
                        } label: {
                            Image(systemName: showingControls && !isCustomizationTest ? "xmark" : "gearshape.fill")
                                .font(.system(size: isCompactLayout ? 13 : 14, weight: .semibold))
                                .foregroundStyle(isCustomizationTest ? textColorSecondary : textColorPrimary)
                                .frame(width: isCompactLayout ? 32 : 36, height: isCompactLayout ? 32 : 36)
                                .notificationLiquidGlass(cornerRadius: isCompactLayout ? 16 : 18, isLight: isLight)
                        }
                        .disabled(isCustomizationTest)
                        .opacity(isCustomizationTest ? 0.45 : 1)
                        .accessibilityLabel(showingControls && !isCustomizationTest ? "Close controls" : "Study controls")
                        .accessibilityHint(isCustomizationTest ? "Unavailable in a test alert" : "")
                    }
                }

                if showingControls && !isCustomizationTest {
                    notificationControls
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Question Box & Prompt Image
                if activeCardType != "images" && activeCardType != "anki" && !(activeCardType == "fill_blank" && !activeOptions.isEmpty) {
                    VStack(spacing: 12) {
                        CardQuestionContent(question: activeQuestion, readingPrompt: sessionCard?.readingPrompt ?? readingPrompt,
                                            media: activeMedia["prompt"] ?? .init(), imageHeight: 160)
                            .font(.system(size: isCompactLayout ? 16 : 18, weight: .bold))
                            .foregroundStyle(textColorPrimary).frame(maxWidth: .infinity)

                    }
                    .padding(.vertical, isCompactLayout ? 12 : 20)
                    .padding(.horizontal, isCompactLayout ? 14 : 18)
                    .notificationLiquidGlass(cornerRadius: 20, isLight: isLight)
                }

                // Image cards are self-review, before the empty-options reveal fallback.
                if activeCardType == "anki" {
                    if let content = activeAnkiContent {
                        AnkiCardView(content: content, showingBack: isRevealed, compact: true, centered: true, animatedReveal: true,
                            loadingChanged: { ankiIsLoading = $0 })
                            .frame(height: min(isCompactLayout ? 260 : 320, max(120, viewportHeight - 180)))
                            .foregroundStyle(textColorPrimary).tint(textColorPrimary)
                            .environment(\.colorScheme, isLight ? .light : .dark)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        if let date = ankiFutureReviewDate, !isGraded {
                            VStack(spacing: 8) {
                                Text("Next review in \(AnkiReviewScheduling.intervalLabel(max(0, date.timeIntervalSinceNow)))")
                                    .font(.subheadline).foregroundStyle(textColorSecondary)
                                Button("Review early") { ankiFutureReviewDate = nil }
                                    .buttonStyle(.bordered).font(.subheadline.weight(.semibold))
                            }
                        } else {
                        AnkiReviewControls(isRevealed: isRevealed, isGraded: isGraded, options: ankiReviewOptions,
                            onReveal: { withAnimation(.snappy) { isRevealed = true } },
                            onGrade: { gradeAnki($0) })
                            .disabled(ankiIsLoading)
                        }
                    } else {
                        Button("Open this Anki card in LearnAlert", action: openApp)
                            .buttonStyle(.borderedProminent)
                    }
                } else if activeCardType == "images" {
                    VStack(spacing: 14) {
                        Group {
                            if hasImageBack {
                                ImageCardFlipView(isShowingBack: $isRevealed,
                                    onBackViewed: {
                                        if CardImageStore.loadImage(named: activeAnswerImageName) != nil { hasViewedImageBack = true }
                                    }) {
                                    imageFace(activePromptImageName)
                                } back: {
                                    imageFace(activeAnswerImageName)
                                }
                                .id(activeCardId)
                            } else {
                                imageFace(activePromptImageName)
                            }
                        }
                        .frame(maxWidth: .infinity).frame(height: isCompactLayout ? 280 : 340)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                        if isGraded {
                            Label("Reviewed", systemImage: "checkmark")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(textColorSecondary)
                        } else {
                            Button {
                                guard !isGraded, canReviewImages else { return }
                                gradeCard(isCorrect: true, playFeedback: false)
                            } label: {
                                Label("Reviewed", systemImage: "checkmark")
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(textColorPrimary)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .notificationLiquidGlass(cornerRadius: 14, isLight: isLight)
                            }
                            .buttonStyle(.plain)
                            .disabled(!canReviewImages)
                        }
                    }
                }

                // Card Type Presentation: Matching Pairs
                else if activeCardType == "matching" {
                    CardMediaMatchingBoard(left: activeMatchingLeftItems, right: activeMatchingRightItems,
                        fields: activeMedia, isGraded: isGraded, onGrade: { gradeCard(isCorrect: $0) }).id(activeCardId)
                        .environment(\.colorScheme, isLight ? .light : .dark)
                }

                // Card Type Presentation: Fill in the Blank
                else if activeCardType == "fill_blank" && !activeOptions.isEmpty {
                    VStack(spacing: 12) {
                        if let prompt = activeMedia["prompt"], !prompt.isEmpty { CardFieldContent(media: prompt, imageHeight: 120) }
                        CardBlankChoicePanel(prompt: activeQuestion, options: activeOptions,
                            answerIndex: activeCorrectIndex, fields: activeMedia,
                            isGraded: isGraded, onGrade: { gradeCard(isCorrect: $0) }).id(activeCardId)
                    }.environment(\.colorScheme, isLight ? .light : .dark)
                }
                else if activeCardType == "fill_blank" && !activeCorrectAnswer.isEmpty {
                    VStack(spacing: 14) {
                        HStack(spacing: 10) {
                            TextField("Type your answer...", text: $typedAnswer)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(textColorPrimary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .notificationLiquidGlass(cornerRadius: 14, isLight: isLight)
                                .focused($isAnswerFieldFocused)
                                .id("fill_blank_field")
                                .submitLabel(.done)
                                .onSubmit { checkFillBlankAnswer() }
                                .disabled(isGraded)

                            Button {
                                checkFillBlankAnswer()
                            } label: {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundStyle(Color(red: 0.12, green: 0.50, blue: 0.98))
                            }
                            .disabled(typedAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGraded)
                        }

                        if isGraded {
                            HStack(spacing: 8) {
                                Image(systemName: lastAnswerWasCorrect == true ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(lastAnswerWasCorrect == true ? Color.green : Color.red)
                                Text(lastAnswerWasCorrect == true ? "Correct!" : "Correct answer: \(activeCorrectAnswer)")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(lastAnswerWasCorrect == true ? Color.green : Color.red)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity)
                            .notificationLiquidGlass(cornerRadius: 12, tint: (lastAnswerWasCorrect == true ? Color.green : Color.red).opacity(0.15), isLight: isLight)
                        }
                    }
                }

                // Card Type Presentation: Multiple Choice Options
                else if !activeOptions.isEmpty && activeCardType != "tap_reveal" {
                    CardMediaChoiceList(options: activeOptions, fields: activeMedia, correctIndex: activeCorrectIndex,
                        selection: selectedAnswer, isGraded: isGraded) { value in
                        guard selectedAnswer == nil else { return }
                        isAnswerFieldFocused = false
                        withAnimation(.snappy) {
                            selectedAnswer = value
                            gradeCard(isCorrect: CardChoiceIdentity.index(value, options: activeOptions) == activeCorrectIndex)
                        }
                    }.environment(\.colorScheme, isLight ? .light : .dark)
                }

                // Card Type Presentation: Tap to Reveal
                else if activeCardType == "tap_reveal" || activeOptions.isEmpty {
                    VStack(spacing: 12) {
                        if !isRevealed {
                            Button {
                                withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                                    isRevealed = true
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "hand.tap.fill")
                                    Text("Tap to Reveal")
                                        .font(.headline.weight(.semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .foregroundStyle(textColorPrimary)
                                .notificationLiquidGlass(cornerRadius: 16, isLight: isLight)
                            }
                            .buttonStyle(.plain)
                        } else {
                            VStack(spacing: 14) {
                                CardFieldContent(text: activeCorrectAnswer, media: activeMedia["answer"] ?? .init())
                                    .font(.title3.bold())
                                    .foregroundStyle(Color(red: 0.12, green: 0.50, blue: 0.98))
                                    .multilineTextAlignment(.center)
                                    .padding(.vertical, 18)
                                    .padding(.horizontal, 16)
                                    .frame(maxWidth: .infinity)
                                    .notificationLiquidGlass(cornerRadius: 16, tint: Color(red: 0.12, green: 0.50, blue: 0.98).opacity(0.12), isLight: isLight)

                                if !isGraded {
                                    HStack(spacing: 12) {
                                        Button {
                                            gradeReveal(correct: false)
                                        } label: {
                                            HStack(spacing: 6) {
                                                Image(systemName: "xmark")
                                                Text("Missed It")
                                            }
                                            .font(.headline.weight(.bold))
                                            .foregroundStyle(Color.red)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 14)
                                            .notificationLiquidGlass(cornerRadius: 14, tint: Color.red.opacity(0.16), isLight: isLight)
                                        }
                                        .buttonStyle(.plain)

                                        Button {
                                            gradeReveal(correct: true)
                                        } label: {
                                            HStack(spacing: 6) {
                                                Image(systemName: "checkmark")
                                                Text("Knew It!")
                                            }
                                            .font(.headline.weight(.bold))
                                            .foregroundStyle(Color.green)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 14)
                                            .notificationLiquidGlass(cornerRadius: 14, tint: Color.green.opacity(0.16), isLight: isLight)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                }

                if showingHint && hasHint {
                    CardFieldContent(text: activeHint, media: activeMedia["hint"] ?? .init())
                        .font(.subheadline.italic())
                        .foregroundStyle(Color.orange)
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .notificationLiquidGlass(cornerRadius: 12, tint: Color.orange.opacity(0.08), isLight: isLight)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // Card Progression Fraction & Skip Button (Aligned right)
                if selectedAnswer == nil && !isRevealed && !isGraded && !isSkipped {
                    HStack(alignment: .center) {
                        Color.clear
                            .frame(width: isCompactLayout ? 36 : 40, height: 1)

                        Spacer()

                        if !cardProgressionText.isEmpty {
                            Text(cardProgressionText)
                                .font(.system(size: isCompactLayout ? 12 : 13, weight: .semibold, design: .monospaced))
                                .foregroundStyle(textColorSecondary)
                        }

                        Spacer()

                        Button {
                            recordSkipAndAdvance()
                        } label: {
                            Image(systemName: "forward.fill")
                                .font(.system(size: isCompactLayout ? 13 : 14, weight: .semibold))
                                .foregroundStyle(textColorSecondary)
                                .frame(width: isCompactLayout ? 36 : 40, height: isCompactLayout ? 32 : 36)
                                .notificationLiquidGlass(cornerRadius: 10, isLight: isLight)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Skip")
                    }
                }

                // Post-Answer Study Stats & Next Card
                if isGraded {
                    VStack(spacing: 14) {
                        HStack(spacing: 10) {
                            NotificationStat(title: "Unlearned", value: unlearnedCount, icon: "sparkles", isLight: isLight)
                            NotificationStat(title: "Learning", value: learningCount, icon: "brain.head.profile", isLight: isLight)
                            NotificationStat(title: "Mastered", value: masteredCount, icon: "checkmark.seal.fill", isLight: isLight)
                        }

                        Button {
                            advanceToNextCard()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.system(size: 16, weight: .bold))
                                Text("Next Card")
                                    .font(.system(size: 15, weight: .bold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundStyle(.white)
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
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .shadow(color: Color(red: 0.12, green: 0.50, blue: 0.98).opacity(0.35), radius: 8, y: 3)
                        }
                        .buttonStyle(.plain)
                    }
                    .transition(.opacity)
                }
            }
            .padding(isCompactLayout ? 12 : 18)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(
                        key: NotificationContentHeightKey.self,
                        value: geo.size.height
                    )
                }
            )
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxWidth: .infinity, alignment: .top)
        .background(NotificationBackdrop(theme: customTheme, isLight: isLight))
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onPreferenceChange(NotificationContentHeightKey.self) { height in
            if height > 50 {
                onContentHeightChange?(height)
            }
        }
        .onChange(of: isAnswerFieldFocused) { _, focused in
            if focused {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    scrollProxy.scrollTo("fill_blank_field", anchor: .center)
                }
            }
        }
        }
        .onAppear {
            seenCardIds.insert(activeCardId)
            loadAnkiReviewOptions()
            if !previewMode {
                loadAvailableDecks()
                persistStudyHandoff()
            }
        }
        .onChange(of: activeCardId) { _, _ in
            loadAnkiReviewOptions()
            if !previewMode { persistStudyHandoff() }
        }
        .onChange(of: selectedAnswer) { _, _ in
            if !previewMode { persistStudyHandoff() }
        }
        .onChange(of: isGraded) { _, _ in
            if !previewMode { persistStudyHandoff() }
        }
        .onChange(of: isRevealed) { _, _ in
            if !previewMode { persistStudyHandoff() }
        }
        .onChange(of: hasViewedImageBack) { _, _ in
            if !previewMode { persistStudyHandoff() }
        }
        .onChange(of: showingHint) { _, _ in
            if !previewMode { persistStudyHandoff() }
        }
    }

    @ViewBuilder private func imageFace(_ name: String?) -> some View {
        if let image = CardImageStore.loadImage(named: name) {
            Image(uiImage: image).resizable().scaledToFit()
        } else {
            VStack(spacing: 8) {
                Label("Image unavailable", systemImage: "photo").font(.headline)
                Text("Open the app to add the picture again.").font(.subheadline)
            }
            .foregroundStyle(textColorSecondary)
        }
    }

    // MARK: - Option Color Logic
    private func optionTextColor(for option: String) -> Color {
        guard let selected = selectedAnswer else { return textColorPrimary }
        if option == activeCorrectAnswer {
            return isLight ? Color(red: 0.05, green: 0.45, blue: 0.20) : Color.white
        }
        if option == selected {
            return isLight ? Color(red: 0.70, green: 0.12, blue: 0.15) : Color.white
        }
        return textColorSecondary.opacity(0.6)
    }

    private func optionGlassTint(for option: String) -> Color? {
        guard let selected = selectedAnswer else {
            return isLight ? Color.white.opacity(0.65) : Color.white.opacity(0.08)
        }
        if option == activeCorrectAnswer {
            return Color.green.opacity(isLight ? 0.22 : 0.32)
        }
        if option == selected {
            return Color.red.opacity(isLight ? 0.20 : 0.30)
        }
        return isLight ? Color.white.opacity(0.35) : Color.white.opacity(0.04)
    }

    private func optionBorderColor(for option: String) -> Color? {
        guard let selected = selectedAnswer else { return nil }
        if option == activeCorrectAnswer { return Color.green.opacity(0.85) }
        if option == selected { return Color.red.opacity(0.85) }
        return nil
    }

    private func matchingLeftTint(_ item: String) -> Color? {
        if selectedMatchingLeft == item { return Color.cyan.opacity(0.30) }
        guard let target = matchingAssignments.first(where: { $0.value == item })?.key,
              let result = matchingResults[target] else { return nil }
        return result ? Color.green.opacity(0.24) : Color.red.opacity(0.24)
    }

    private func matchingLeftBorder(_ item: String) -> Color? {
        if selectedMatchingLeft == item { return Color.cyan.opacity(0.85) }
        guard let target = matchingAssignments.first(where: { $0.value == item })?.key,
              let result = matchingResults[target] else { return nil }
        return result ? Color.green.opacity(0.9) : Color.red.opacity(0.9)
    }

    private func matchingRightTint(_ target: String) -> Color? {
        guard let result = matchingResults[target] else { return nil }
        return result ? Color.green.opacity(0.24) : Color.red.opacity(0.24)
    }

    private func matchingRightBorder(_ target: String) -> Color? {
        guard let result = matchingResults[target] else { return nil }
        return result ? Color.green.opacity(0.9) : Color.red.opacity(0.9)
    }

    private func checkFillBlankAnswer() {
        let entered = typedAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !entered.isEmpty else { return }
        isAnswerFieldFocused = false
        let expected = activeCorrectAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        gradeCard(isCorrect: entered.localizedCaseInsensitiveCompare(expected) == .orderedSame)
    }

    // MARK: - Logic Helpers
    private func loadAvailableDecks() {
        let context = ModelContext(SharedDatabase.shared.container)
        let descriptor = FetchDescriptor<Deck>(sortBy: [SortDescriptor(\.name)])
        guard let decks = try? context.fetch(descriptor) else { return }
        availableDecks = decks.map { NotificationDeckChoice(id: $0.id, name: $0.name) }
    }

    private func recordHintUsed() {
        guard !previewMode,
              let uuid = UUID(uuidString: activeCardId) else { return }
        let context = ModelContext(SharedDatabase.shared.container)
        let descriptor = FetchDescriptor<Flashcard>(predicate: #Predicate { $0.id == uuid })
        guard let card = try? context.fetch(descriptor).first else { return }
        card.recordHintUsed()
        try? context.save()
    }

    private func recordSkipAndAdvance() {
        isAnswerFieldFocused = false
        NotificationFeedbackSoundPlayer.shared.play(named: "skip")
        if !previewMode, let uuid = UUID(uuidString: activeCardId) {
            let context = ModelContext(SharedDatabase.shared.container)
            let descriptor = FetchDescriptor<Flashcard>(predicate: #Predicate { $0.id == uuid })
            if let card = try? context.fetch(descriptor).first {
                card.recordSkip()
                try? context.save()
            }
        }
        advanceToNextCard()
    }

    private func advanceToNextCard() {
        isAnswerFieldFocused = false
        if previewMode {
            withAnimation(.snappy) {
                selectedAnswer = nil
                isRevealed = false
                hasViewedImageBack = false
                isGraded = false
                isSkipped = false
                showingHint = false
                typedAnswer = ""
                selectedMatchingLeft = nil
                matchingAssignments = [:]
                matchingResults = [:]
                hadMatchingMistake = false
            }
            return
        }

        let context = ModelContext(SharedDatabase.shared.container)
        guard let uuid = UUID(uuidString: activeCardId) else { return }
        let descriptor = FetchDescriptor<Flashcard>(predicate: #Predicate { $0.id == uuid })
        guard let card = try? context.fetch(descriptor).first,
              let deck = card.deck else {
            openApp()
            return
        }
        loadNextCard(from: deck.id)
    }

    private func loadNextCard(from deckId: UUID) {
        let context = ModelContext(SharedDatabase.shared.container)
        let descriptor = FetchDescriptor<Deck>(predicate: #Predicate { $0.id == deckId })
        guard let deck = try? context.fetch(descriptor).first else { return }

        if LanguageBundleStudy.isBundle(deck), let courseID = deck.sourceId,
           let course = CourseCurriculumCatalog.course(for: courseID) {
            _ = try? LanguageTopicStore.collection(course: course, context: context)
        }
        let cards = LanguageBundleStudy.cards(deck)
        let now = Date()
        let eligible = cards.filter { $0.cardType != .anki || $0.isNew || $0.nextReviewDate <= now }
        let unseenCards = eligible.filter { !seenCardIds.contains($0.id.uuidString) }
        let nextCard: Flashcard?
        if LanguageBundleStudy.isBundle(deck), LanguageBundleStudy.smartReviewEnabled(deck) {
            let seen = Set(seenCardIds.compactMap(UUID.init(uuidString:)))
            if let card = LanguageBundleStudy.selection(deck, count: 1, now: now, excluding: seen).first {
                nextCard = card
            } else {
                seenCardIds.removeAll()
                // Completing a pass may repeat older material, but keep the last
                // question out while any different eligible choice remains.
                let last = UUID(uuidString: activeCardId).map { Set([$0]) } ?? []
                nextCard = LanguageBundleStudy.selection(deck, count: 1, now: now, excluding: last).first
                    ?? LanguageBundleStudy.selection(deck, count: 1, now: now).first
            }
        } else if let card = unseenCards.first {
            nextCard = card
        } else {
            seenCardIds.removeAll()
            let sortedCards = eligible.sorted { $0.studyPriority > $1.studyPriority }
            nextCard = sortedCards.first
        }

        guard let cardToStudy = nextCard else {
            if let next = cards.filter({ $0.cardType == .anki }).map(\.nextReviewDate).min() {
                statusMessage = "You're caught up. Next review in \(AnkiReviewScheduling.intervalLabel(max(0, next.timeIntervalSinceNow)))."
            } else { statusMessage = "This deck has no cards." }
            return
        }

        seenCardIds.insert(cardToStudy.id.uuidString)
        if LanguageBundleStudy.smartReviewEnabled(deck) {
            LanguageBundleStudy.recordOpportunities([cardToStudy], deck: deck)
        }
        withAnimation(.snappy) {
            sessionCard = NotificationSessionCard(
                id: cardToStudy.id.uuidString,
                deckId: deck.id.uuidString,
                deckName: deck.name,
                deckType: deck.deckType,
                cardType: cardToStudy.cardType.rawValue,
                question: cardToStudy.studyQuestion,
                options: cardToStudy.options,
                correctAnswer: cardToStudy.correctAnswer,
                hint: cardToStudy.hint,
                matchingLeftItems: cardToStudy.matchingLeftItems,
                matchingRightItems: cardToStudy.matchingRightItems,
                promptImageName: cardToStudy.promptImageName,
                answerImageName: cardToStudy.answerImageName,
                ankiContentData: cardToStudy.ankiContentData,
                fieldMedia: cardToStudy.fieldMedia, correctOptionIndex: cardToStudy.resolvedCorrectOptionIndex,
                optionImageNames: cardToStudy.optionImageNames, readingPrompt: cardToStudy.readingPrompt
            )
            selectedAnswer = nil
            lastAnswerWasCorrect = nil
            isRevealed = false
            hasViewedImageBack = false
            isGraded = false
            isSkipped = false
            showingHint = false
            typedAnswer = ""
            selectedMatchingLeft = nil
            matchingAssignments = [:]
            matchingResults = [:]
            hadMatchingMistake = false
            statusMessage = nil
        }
        // A short repeat can have the same card ID but a different learning step.
        loadAnkiReviewOptions()
    }

    private func stopScheduledAlerts() {
        DailyDeckAlertScheduler.clear()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        let sharedDefaults = UserDefaults(suiteName: "group.com.learnalert.shared")
        sharedDefaults?.set(true, forKey: "extensionDidStopAlerts")
        sharedDefaults?.set("", forKey: "extensionActiveDeckName")
        statusMessage = "Scheduled notifications stopped."
    }

    private func gradeReveal(correct: Bool) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            isGraded = true
            showingHint = false
        }
        gradeCard(isCorrect: correct)
    }

    private func loadAnkiReviewOptions() {
        ankiFutureReviewDate = nil
        guard activeCardType == "anki" else { ankiReviewOptions = []; return }
        let now = Date()
        if !previewMode, let id = UUID(uuidString: activeCardId) {
            let context = ModelContext(SharedDatabase.shared.container)
            if let card = try? context.fetch(FetchDescriptor<Flashcard>(predicate: #Predicate { $0.id == id })).first {
                ankiReviewOptions = card.ankiReviewOptions(at: now)
                if !card.isNew && card.nextReviewDate > now { ankiFutureReviewDate = card.nextReviewDate }
                return
            }
        }
        ankiReviewOptions = AnkiReviewScheduling.options(for: AnkiReviewState(), at: now)
    }

    private func gradeAnki(_ rating: AnkiReviewRating) {
        guard activeCardType == "anki", isRevealed, !isGraded, ankiFutureReviewDate == nil else { return }
        gradeCard(isCorrect: rating.wasCorrect, ankiRating: rating)
    }

    private func gradeCard(isCorrect: Bool, playFeedback: Bool = true, ankiRating: AnkiReviewRating? = nil) {
        isAnswerFieldFocused = false
        if playFeedback {
            NotificationFeedbackSoundPlayer.shared.play(named: isCorrect ? "correct" : "incorrect")
        }
        lastAnswerWasCorrect = isCorrect

        if previewMode {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                unlearnedCount = 5
                learningCount = isCorrect ? 2 : 3
                masteredCount = isCorrect ? 1 : 0
                completedCount += 1
                isGraded = true
                showingHint = false
            }
            return
        }

        let container = SharedDatabase.shared.container
        let context = ModelContext(container)
        guard let uuid = UUID(uuidString: activeCardId) else { return }

        let descriptor = FetchDescriptor<Flashcard>(predicate: #Predicate { $0.id == uuid })
        if let card = try? context.fetch(descriptor).first {
            if let ankiRating { card.recordAnkiReview(rating: ankiRating, at: Date()) }
            else { card.processAnswer(isCorrect: isCorrect) }
            do { try context.save() }
            catch {
                context.rollback()
                statusMessage = "Review couldn't be saved. Please try again."
                return
            }
            AlertTimelineStore.shared.answered(notificationRequestID)
            if ankiRating != nil {
                Task { await AnkiReviewAlerts.reconcile(cardID: uuid) }
            }
            if let defaults = UserDefaults(suiteName: "group.com.learnalert.shared") {
                defaults.set(Date().timeIntervalSince1970, forKey: "lastNotificationAnsweredTimestamp")
                defaults.set(isCorrect, forKey: "lastNotificationWasCorrect")
                defaults.set(activeCardId, forKey: "lastNotificationCardId")
                defaults.set(true, forKey: "lastNotificationWasGraded")
                defaults.synchronize()
            }

            if let deck = card.deck {
                let unlearned = deck.cards.filter { $0.isNew }.count
                let learning = deck.cards.filter { !$0.isNew && $0.interval < 7 }.count
                let mastered = deck.cards.filter { !$0.isNew && $0.interval >= 7 }.count

                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    self.unlearnedCount = unlearned
                    self.learningCount = learning
                    self.masteredCount = mastered
                    self.completedCount += 1
                    self.isGraded = true
                    self.showingHint = false
                }

                let sharedDefaults = UserDefaults(suiteName: "group.com.learnalert.shared")
                let stopCondition = sharedDefaults?.string(forKey: "extensionStopCondition") ?? "Until I say so"
                if stopCondition == "Until Deck Learnt" {
                    let allLearned = deck.cards.allSatisfy { $0.isLearned || $0.interval >= 6 }
                    if allLearned {
                        stopScheduledAlerts()
                    }
                }
            }
        }
    }

    private func persistStudyHandoff() {
        guard !isTutorial, !activeDeckId.isEmpty, !activeCardId.isEmpty,
              let defaults = UserDefaults(suiteName: "group.com.learnalert.shared") else { return }
        defaults.set(activeDeckId, forKey: "handoffDeckId")
        defaults.set(activeCardId, forKey: "handoffCardId")
        defaults.set(notificationRequestID, forKey: "handoffNotificationRequestID")
        defaults.set(selectedAnswer, forKey: "handoffSelectedAnswer")
        defaults.set(lastAnswerWasCorrect, forKey: "handoffWasCorrect")
        defaults.set(isGraded, forKey: "handoffWasGraded")
        defaults.set(isRevealed, forKey: "handoffWasRevealed")
        defaults.set(hasViewedImageBack, forKey: "handoffImageBackViewed")
        defaults.set(showingHint, forKey: "handoffHintVisible")
        // Mark handoff originated from notification UI
        defaults.set(true, forKey: "handoffFromNotificationUI")
        defaults.set(Date().timeIntervalSince1970, forKey: "handoffTimestamp")
        defaults.synchronize()
    }

    private func isCorrectMatch(left: String, right: String) -> Bool {
        guard let index = activeMatchingRightItems.firstIndex(of: right),
              activeMatchingLeftItems.indices.contains(index) else { return false }
        return activeMatchingLeftItems[index] == left
    }

    private func isCorrectlyMatched(_ item: String) -> Bool {
        matchingAssignments.contains { target, term in term == item && matchingResults[target] == true }
    }
}

// MARK: - Notification Stat Capsule
private struct NotificationStat: View {
    let title: String
    let value: Int
    let icon: String
    var isLight: Bool = false

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption.bold())
                .foregroundStyle(Color(red: 0.12, green: 0.50, blue: 0.98))
            Text("\(value)")
                .font(.headline.bold().monospacedDigit())
                .foregroundStyle(isLight ? Color(red: 0.10, green: 0.13, blue: 0.24) : Color.white)
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(isLight ? Color(red: 0.40, green: 0.45, blue: 0.58) : Color.white.opacity(0.65))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .notificationLiquidGlass(cornerRadius: 12, isLight: isLight)
    }
}

// MARK: - Dynamic Liquid Glass Backdrop
private struct NotificationBackdrop: View {
    var theme: String = "default"
    var isLight: Bool

    var body: some View {
        ZStack {
            if isLight {
                LinearGradient(colors: (NotificationTheme(rawValue: theme) ?? .defaultTheme).lightBackdropColors,
                    startPoint: .topLeading, endPoint: .bottomTrailing)
            } else {
                switch theme {
                case "default":
                    LinearGradient(
                        colors: [
                            Color(red: 0.07, green: 0.09, blue: 0.20),
                            Color(red: 0.14, green: 0.11, blue: 0.28),
                            Color(red: 0.06, green: 0.18, blue: 0.28)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Circle().fill(Color(red: 0.10, green: 0.72, blue: 0.95).opacity(0.28))
                        .frame(width: 260, height: 260).blur(radius: 46).offset(x: 140, y: -180)
                    Circle().fill(Color(red: 0.90, green: 0.25, blue: 0.65).opacity(0.22))
                        .frame(width: 240, height: 240).blur(radius: 50).offset(x: -140, y: 200)
                    ForEach(0..<6, id: \.self) { index in
                        Circle().stroke(Color.white.opacity(0.06), lineWidth: 1)
                            .frame(width: CGFloat(110 + index * 42), height: CGFloat(110 + index * 42))
                            .offset(x: 140, y: -160)
                    }

                case "midnight":
                    Color(red: 0.02, green: 0.03, blue: 0.05)
                    Circle().fill(Color(red: 0.20, green: 0.35, blue: 0.70).opacity(0.15))
                        .frame(width: 280, height: 280).blur(radius: 60).offset(x: 120, y: -180)
                    Circle().fill(Color(red: 0.15, green: 0.25, blue: 0.50).opacity(0.12))
                        .frame(width: 240, height: 240).blur(radius: 60).offset(x: -120, y: 180)

                case "aurora":
                    LinearGradient(
                        colors: [
                            Color(red: 0.03, green: 0.10, blue: 0.14),
                            Color(red: 0.04, green: 0.18, blue: 0.18),
                            Color(red: 0.03, green: 0.09, blue: 0.16)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Circle().fill(Color(red: 0.10, green: 0.85, blue: 0.55).opacity(0.25))
                        .frame(width: 260, height: 260).blur(radius: 48).offset(x: 140, y: -180)
                    Circle().fill(Color(red: 0.08, green: 0.65, blue: 0.85).opacity(0.22))
                        .frame(width: 240, height: 240).blur(radius: 50).offset(x: -140, y: 200)
                    ForEach(0..<5, id: \.self) { index in
                        Circle().stroke(Color(red: 0.20, green: 0.90, blue: 0.60).opacity(0.06), lineWidth: 1)
                            .frame(width: CGFloat(110 + index * 42), height: CGFloat(110 + index * 42))
                            .offset(x: 140, y: -160)
                    }

                case "sunset":
                    LinearGradient(
                        colors: [
                            Color(red: 0.14, green: 0.05, blue: 0.18),
                            Color(red: 0.24, green: 0.08, blue: 0.20),
                            Color(red: 0.12, green: 0.04, blue: 0.14)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Circle().fill(Color(red: 0.95, green: 0.40, blue: 0.30).opacity(0.25))
                        .frame(width: 260, height: 260).blur(radius: 48).offset(x: 140, y: -180)
                    Circle().fill(Color(red: 0.80, green: 0.20, blue: 0.55).opacity(0.22))
                        .frame(width: 240, height: 240).blur(radius: 50).offset(x: -140, y: 200)
                    ForEach(0..<5, id: \.self) { index in
                        Circle().stroke(Color(red: 0.95, green: 0.45, blue: 0.35).opacity(0.06), lineWidth: 1)
                            .frame(width: CGFloat(110 + index * 42), height: CGFloat(110 + index * 42))
                            .offset(x: 140, y: -160)
                    }

                case "slate":
                    LinearGradient(
                        colors: [
                            Color(red: 0.08, green: 0.09, blue: 0.12),
                            Color(red: 0.12, green: 0.14, blue: 0.18),
                            Color(red: 0.09, green: 0.10, blue: 0.13)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Circle().fill(Color.white.opacity(0.04))
                        .frame(width: 260, height: 260).blur(radius: 40).offset(x: 120, y: -160)

                case "light":
                    LinearGradient(
                        colors: [
                            Color(red: 0.95, green: 0.96, blue: 0.98),
                            Color(red: 0.88, green: 0.91, blue: 0.96)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Circle().fill(Color(red: 0.20, green: 0.60, blue: 0.98).opacity(0.12))
                        .frame(width: 260, height: 260).blur(radius: 45).offset(x: 140, y: -180)

                default:
                    LinearGradient(
                        colors: [
                            Color(red: 0.07, green: 0.09, blue: 0.20),
                            Color(red: 0.14, green: 0.11, blue: 0.28),
                            Color(red: 0.06, green: 0.18, blue: 0.28)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
        }
        .clipped()
    }
}

// MARK: - Liquid Glass View Extension
private extension View {
    @ViewBuilder
    func notificationLiquidGlass(
        cornerRadius: CGFloat = 16,
        tint: Color? = nil,
        isLight: Bool = false,
        customBorderColor: Color? = nil
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(iOS 26.0, *) {
            self
                .glassEffect(.regular.tint(tint).interactive(), in: .rect(cornerRadius: cornerRadius))
                .overlay(
                    shape.stroke(
                        customBorderColor ?? (isLight ? Color.white.opacity(0.85) : Color.white.opacity(0.18)),
                        lineWidth: customBorderColor != nil ? 1.5 : 1
                    )
                )
                .shadow(
                    color: isLight ? Color.black.opacity(0.05) : Color.black.opacity(0.22),
                    radius: isLight ? 6 : 10,
                    y: isLight ? 2 : 4
                )
        } else {
            self
                .background(
                    tint ?? (isLight ? Color.white.opacity(0.65) : Color(red: 0.08, green: 0.10, blue: 0.20).opacity(0.65)),
                    in: shape
                )
                .background(.ultraThinMaterial, in: shape)
                .overlay(
                    shape.stroke(
                        customBorderColor ?? (isLight ? Color.white.opacity(0.88) : Color.white.opacity(0.20)),
                        lineWidth: customBorderColor != nil ? 1.5 : 1
                    )
                )
                .shadow(
                    color: isLight ? Color.black.opacity(0.05) : Color.black.opacity(0.22),
                    radius: isLight ? 6 : 10,
                    y: isLight ? 2 : 4
                )
        }
    }
}

// MARK: - View Controller LifeCycle
class NotificationViewController: UIViewController, UNNotificationContentExtension {

    private var hostingController: UIHostingController<AnyView>?
    private var measuredContentHeight: CGFloat = 540
    private var isCourseContent = false
    private var isAnkiContent = false
    private var coursePreservesDrawingHeight = false

    private func fitContent(_ height: CGFloat, preserveDrawingHeight: Bool = false) {
        measuredContentHeight = height
        coursePreservesDrawingHeight = preserveDrawingHeight
        // Use the active scene's display, never UIScreen.main or the bubble's own height.
        let scene = view.window?.windowScene
        let containerHeight = NotificationViewportGeometry.containerHeight(
            sceneHeight: scene?.effectiveGeometry.coordinateSpace.bounds.height,
            displayHeight: scene?.screen.coordinateSpace.bounds.height ?? 760)
        let requested = preserveDrawingHeight ? CGFloat(540) : height
        let targetHeight = NotificationViewportGeometry.preferredHeight(contentHeight: requested,
            containerHeight: containerHeight, baseline: isCourseContent ? 540 : isAnkiContent ? 500 : 300)
        let targetSize = CGSize(width: view.bounds.width, height: targetHeight)
        if abs(preferredContentSize.height - targetHeight) > 2 || abs(preferredContentSize.width - targetSize.width) > 2 {
            preferredContentSize = targetSize
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        fitContent(measuredContentHeight, preserveDrawingHeight: coursePreservesDrawingHeight)
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        view.setNeedsLayout()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: nil) { [weak self] _ in self?.view.setNeedsLayout() }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        KoreanSpeechManager.shared.stop()
        if isCourseContent { CardAudioPlayer.stopActive() }
        extensionContext?.mediaPlayingPaused()
    }

    func mediaPause() {
        KoreanSpeechManager.shared.stop()
        if isCourseContent { CardAudioPlayer.stopActive() }
        extensionContext?.mediaPlayingPaused()
    }

    func didReceive(_ notification: UNNotification) {
        if isCourseContent {
            KoreanSpeechManager.shared.stop()
            CardAudioPlayer.stopActive()
        }
        AlertTimelineStore.shared.delivered(notification)
        Task { try? await DailyDeckAlertScheduler.replenish() }
        let content = notification.request.content
        var userInfo = content.userInfo

        if let courseId = userInfo["courseId"] as? String {
            let profile = userInfo["courseDeliveryProfile"] as? String
            let required = userInfo["courseRequiredContracts"] as? [String]
            let catalog = profile == nil || profile == "legacy-v1" ? ManagedCatalogStore.legacyShared : profile == "practice-v1" ? ManagedCatalogStore.practiceV1Shared : ManagedCatalogStore.shared
            guard let course = catalog.course(for: courseId), CourseDeliveryContracts.notificationCanRender(profile: profile, contracts: required, course: course) else {
                isCourseContent = true
                fitContent(240)
                show(AnyView(VStack(alignment: .leading, spacing: 16) {
                    Text("Continue in LearnAlert").font(.title2.bold())
                    Text("Open the app to load the compatible course and keep your place.").foregroundStyle(.secondary)
                    Button("Open LearnAlert") { [weak self] in
                        let defaults = UserDefaults(suiteName: "group.com.learnalert.shared")
                        defaults?.set(courseId, forKey: "handoffCourseId")
                        defaults?.set(true, forKey: "handoffCourseOpenPath")
                        defaults?.synchronize()
                        self?.extensionContext?.performNotificationDefaultAction()
                    }.buttonStyle(.borderedProminent).frame(minHeight: 44)
                }.padding(24)))
                return
            }
            // Old course alerts are rendered and graded by the same deck UI.
            do {
                let context = ModelContext(SharedDatabase.shared.container)
                let deck = try LanguageTopicStore.collection(course: course, context: context)
                if let card = LanguageBundleStudy.smartReviewEnabled(deck)
                    ? LanguageBundleStudy.selection(deck, count: 1).first : LanguageBundleStudy.cards(deck).first {
                    userInfo["deckId"] = deck.id.uuidString; userInfo["cardId"] = card.id.uuidString
                    userInfo["deckName"] = deck.name; userInfo["cardType"] = card.cardType.rawValue
                    userInfo["question"] = card.studyQuestion; userInfo["options"] = card.options
                    userInfo["correctAnswer"] = card.correctAnswer
                }
            } catch {
                show(AnyView(Text("Open LearnAlert to load your language decks.").padding(24)))
                return
            }
        }

        isCourseContent = false
        isAnkiContent = (userInfo["cardType"] as? String) == "anki"
        coursePreservesDrawingHeight = false
        fitContent(540)

        let isRandom = userInfo["isRandom"] as? Bool ?? false
        let progress = userInfo["progress"] as? String ?? "-"
        var snapshot = NotificationSessionCard(
            id: userInfo["cardId"] as? String ?? "",
            deckId: userInfo["deckId"] as? String ?? "",
            deckName: userInfo["deckName"] as? String ?? "Deck",
            deckType: userInfo["deckType"] as? String ?? "Quiz",
            cardType: userInfo["cardType"] as? String ?? "",
            question: userInfo["question"] as? String ?? content.body,
            options: userInfo["options"] as? [String] ?? [],
            correctAnswer: userInfo["correctAnswer"] as? String ?? "",
            hint: userInfo["hint"] as? String ?? "",
            matchingLeftItems: userInfo["matchingLeftItems"] as? [String] ?? [],
            matchingRightItems: userInfo["matchingRightItems"] as? [String] ?? [],
            promptImageName: userInfo["promptImageName"] as? String,
            answerImageName: userInfo["answerImageName"] as? String,
            correctOptionIndex: userInfo["correctOptionIndex"] as? Int,
            optionImageNames: userInfo["optionImageNames"] as? [String] ?? []
        )

        let isTutorial = userInfo["isTutorial"] as? Bool ?? false
        let isCustomizationTest = userInfo["isCustomizationTest"] as? Bool == true ||
            (content.categoryIdentifier == "FLASHCARD_TEST" &&
             userInfo["isCustomizationTest"] == nil && snapshot.deckName == "Example")
        let isSynthetic = isTutorial || content.categoryIdentifier == "FLASHCARD_TEST" || isCustomizationTest
        if isSynthetic {
            self.extensionContext?.notificationActions = []
        } else if let cardId = UUID(uuidString: snapshot.id),
                  let deckId = UUID(uuidString: snapshot.deckId) {
            // Queued alerts may predate a card edit and refer to replaced image files.
            // Resolve the complete current card together, so a removed back cannot leak
            // back in from the old notification payload.
            let context = ModelContext(SharedDatabase.shared.container)
            let descriptor = FetchDescriptor<Flashcard>(predicate: #Predicate { $0.id == cardId })
            let scheduledCard = try? context.fetch(descriptor).first
            let deckDescriptor = FetchDescriptor<Deck>(predicate: #Predicate { $0.id == deckId })
            let resolvedDeck = scheduledCard?.deck?.id == deckId ? scheduledCard?.deck : try? context.fetch(deckDescriptor).first
            if let deck = resolvedDeck {
                if LanguageBundleStudy.isBundle(deck), let courseID = deck.sourceId,
                   let course = CourseCurriculumCatalog.course(for: courseID) {
                    _ = try? LanguageTopicStore.collection(course: course, context: context)
                }
                let pool = LanguageBundleStudy.cards(deck)
                let fallback = LanguageBundleStudy.smartReviewEnabled(deck)
                    ? LanguageBundleStudy.selection(deck, count: 1).first : pool.first
                if let card = LanguageBundleStudy.isBundle(deck)
                    ? (pool.first(where: { $0.id == scheduledCard?.id }) ?? fallback) : scheduledCard {
                snapshot = NotificationSessionCard(
                    id: card.id.uuidString, deckId: deck.id.uuidString,
                    deckName: deck.name, deckType: card.cardType.title,
                    cardType: card.cardType.rawValue, question: card.studyQuestion,
                    options: card.options, correctAnswer: card.correctAnswer, hint: card.hint,
                    matchingLeftItems: card.matchingLeftItems, matchingRightItems: card.matchingRightItems,
                    promptImageName: card.promptImageName, answerImageName: card.answerImageName,
                    ankiContentData: card.ankiContentData,
                    fieldMedia: card.fieldMedia, correctOptionIndex: card.resolvedCorrectOptionIndex,
                    optionImageNames: card.optionImageNames, readingPrompt: card.readingPrompt
                )
                }
            }
        }

        let swiftUIView = FlashcardNotificationView(
            cardId: snapshot.id,
            deckId: snapshot.deckId,
            deckName: snapshot.deckName,
            deckType: snapshot.deckType,
            cardType: snapshot.cardType,
            isRandom: isRandom,
            progress: progress,
            question: snapshot.question,
            options: snapshot.options,
            correctAnswer: snapshot.correctAnswer,
            hint: snapshot.hint,
            matchingLeftItems: snapshot.matchingLeftItems,
            matchingRightItems: snapshot.matchingRightItems,
            promptImageName: snapshot.promptImageName,
            answerImageName: snapshot.answerImageName,
            ankiContentData: snapshot.ankiContentData,
            fieldMedia: snapshot.fieldMedia, correctOptionIndex: snapshot.correctOptionIndex,
            optionImageNames: snapshot.optionImageNames,
            notificationRequestID: isSynthetic ? nil : notification.request.identifier,
            readingPrompt: snapshot.readingPrompt,
            isTutorial: isTutorial,
            isCustomizationTest: isCustomizationTest,
            appearance: .resolve(userInfo: userInfo),
            openApp: { [weak self] in
                self?.openHostApp(deckId: snapshot.deckId)
            },
            onContentHeightChange: { [weak self] newHeight in
                self?.fitContent(newHeight)
            }
        )

        show(AnyView(swiftUIView))
    }

    private func show(_ root: AnyView) {
        let wrapped = AnyView(NotificationViewportRoot(content: root).ignoresSafeArea(.container))
        if let existing = hostingController { existing.rootView = wrapped; return }
        let hosting = UIHostingController(rootView: wrapped)
        // The system already positions the notification; phone status/home insets
        // must not become padding inside its extension content.
        hosting.safeAreaRegions = []
        hosting.view.backgroundColor = .clear
        addChild(hosting)
        view.addSubview(hosting.view)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        hosting.didMove(toParent: self)
        hostingController = hosting
    }

    private func openHostApp(deckId: String) {
        if let url = URL(string: "learnalert://deck/\(deckId)") {
            var responder: UIResponder? = self
            while responder != nil {
                if let application = responder as? UIApplication {
                    application.open(url, options: [:], completionHandler: nil)
                    return
                }
                responder = responder?.next
            }
            extensionContext?.performNotificationDefaultAction()
        }
    }
}


private struct NotificationViewportCompactKey: EnvironmentKey {
    static let defaultValue = false
}
private struct NotificationViewportHeightKey: EnvironmentKey {
    static let defaultValue: CGFloat = 540
}
private extension EnvironmentValues {
    var notificationViewportHeight: CGFloat {
        get { self[NotificationViewportHeightKey.self] }
        set { self[NotificationViewportHeightKey.self] = newValue }
    }
    var notificationViewportCompact: Bool {
        get { self[NotificationViewportCompactKey.self] }
        set { self[NotificationViewportCompactKey.self] = newValue }
    }
}

/// The content stays mounted while its window changes display or size.
private struct NotificationViewportRoot: View {
    let content: AnyView
    var body: some View {
        GeometryReader { proxy in
            let usable = contentRect(proxy)
            content
                .environment(\.notificationViewportCompact, usable.width < 350 || usable.height < 450)
                .environment(\.notificationViewportHeight, usable.height)
                .frame(width: min(640, usable.width), height: usable.height)
                .clipped()
                .position(x: usable.midX, y: usable.midY)
        }
    }
    private func contentRect(_ proxy: GeometryProxy) -> CGRect {
        let bounds = CGRect(origin: .zero, size: proxy.size)
        var regions: [CGRect] = []
        if #available(iOS 27.1, *) {
            let divisions = proxy.reservedRegions(kind: .division, options: .includeInactive, layoutDirectionBehavior: .fixed)
            // Ordinary iPhone/iPad alerts already sit outside screen cutouts.
            // Only a folding display needs this additional avoidance within the bubble.
            guard !divisions.isEmpty else { return bounds }
            regions = divisions.filter(\.isActive).map(\.frame)
            regions += proxy.reservedRegions(kind: .occlusion, options: .includeInactive, layoutDirectionBehavior: .fixed)
                .filter(\.isActive).map(\.frame)
        }
        return NotificationViewportGeometry.usableRect(in: bounds, avoiding: regions)
    }
}
