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
    var optionImageNames: [String] = []
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
    var optionImageNames: [String] = []
    var previewMode = false
    var isTutorial = false
    var openApp: () -> Void = { }
    var onContentHeightChange: ((CGFloat) -> Void)? = nil

    @FocusState private var isAnswerFieldFocused: Bool

    @Environment(\.colorScheme) private var systemColorScheme

    @State private var selectedAnswer: String? = nil
    @State private var isRevealed = false
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
        let mode = UserDefaults(suiteName: "group.com.learnalert.shared")?.string(forKey: "appearanceMode") ?? "system"
        if mode == "light" { return .light }
        if mode == "dark" { return .dark }
        return systemColorScheme
    }

    private var customTheme: String {
        UserDefaults(suiteName: "group.com.learnalert.shared")?.string(forKey: "notificationCustomTheme") ?? "default"
    }

    private var isCompactLayout: Bool {
        let layout = UserDefaults(suiteName: "group.com.learnalert.shared")?.string(forKey: "notificationCustomLayout") ?? "automatic"
        return layout == "compact"
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
    private var activeQuestion: String { sessionCard?.question ?? question }
    private var activeOptions: [String] { sessionCard?.options ?? options }
    private var activeCorrectAnswer: String { sessionCard?.correctAnswer ?? correctAnswer }
    private var activeHint: String { sessionCard?.hint ?? hint }
    private var activeMatchingLeftItems: [String] { sessionCard?.matchingLeftItems ?? matchingLeftItems }
    private var activeMatchingRightItems: [String] { sessionCard?.matchingRightItems ?? matchingRightItems }
    private var activePromptImageName: String? { sessionCard?.promptImageName ?? promptImageName }
    private var activeOptionImageNames: [String] { sessionCard?.optionImageNames ?? optionImageNames }

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
                        if !activeHint.isEmpty && selectedAnswer == nil && !isRevealed && !isGraded && !isSkipped {
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
                            Image(systemName: showingControls ? "xmark" : "gearshape.fill")
                                .font(.system(size: isCompactLayout ? 13 : 14, weight: .semibold))
                                .foregroundStyle(textColorPrimary)
                                .frame(width: isCompactLayout ? 32 : 36, height: isCompactLayout ? 32 : 36)
                                .notificationLiquidGlass(cornerRadius: isCompactLayout ? 16 : 18, isLight: isLight)
                        }
                        .accessibilityLabel(showingControls ? "Close controls" : "Study controls")
                    }
                }

                if showingControls {
                    notificationControls
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Question Box & Prompt Image
                if activeCardType != "matching" {
                    VStack(spacing: 12) {
                        if let promptImg = activePromptImageName, !promptImg.isEmpty,
                           let uiImage = CardImageStore.loadImage(named: promptImg) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 180)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .shadow(color: Color.black.opacity(0.12), radius: 6, y: 3)
                        }

                        Text(activeQuestion)
                            .font(.system(size: isCompactLayout ? 16 : 18, weight: .bold))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(textColorPrimary)
                            .lineSpacing(3)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, isCompactLayout ? 12 : 20)
                    .padding(.horizontal, isCompactLayout ? 14 : 18)
                    .notificationLiquidGlass(cornerRadius: 20, isLight: isLight)
                }

                // Card Type Presentation: Matching Pairs
                if activeCardType == "matching" {
                    VStack(spacing: 14) {
                        if !activeQuestion.isEmpty {
                            Text(activeQuestion)
                                .font(.system(size: 15, weight: .semibold))
                                .multilineTextAlignment(.leading)
                                .foregroundStyle(textColorPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 4)
                        }

                        HStack(alignment: .top, spacing: 10) {
                            // Left column (terms)
                            VStack(spacing: 8) {
                                ForEach(activeMatchingLeftItems, id: \.self) { item in
                                    let isMatched = isCorrectlyMatched(item)
                                    let isSelected = selectedMatchingLeft == item
                                    Button {
                                        guard !isMatched else { return }
                                        withAnimation(.snappy) {
                                            selectedMatchingLeft = isSelected ? nil : item
                                        }
                                    } label: {
                                        Text(item)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(textColorPrimary)
                                            .multilineTextAlignment(.center)
                                            .padding(10)
                                            .frame(maxWidth: .infinity, minHeight: 48)
                                            .notificationLiquidGlass(
                                                cornerRadius: 12,
                                                tint: matchingLeftTint(item),
                                                isLight: isLight,
                                                customBorderColor: matchingLeftBorder(item)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(isMatched || isGraded)
                                }
                            }

                            // Right column (definitions/targets)
                            VStack(spacing: 8) {
                                ForEach(activeMatchingRightItems, id: \.self) { target in
                                    let assignedTerm = matchingAssignments[target]
                                    let isCorrect = matchingResults[target] == true
                                    Button {
                                        guard let left = selectedMatchingLeft else { return }
                                        let matchCorrect = isCorrectMatch(left: left, right: target)
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                                            matchingAssignments[target] = left
                                            matchingResults[target] = matchCorrect
                                            selectedMatchingLeft = nil
                                            if !matchCorrect {
                                                hadMatchingMistake = true
                                                NotificationFeedbackSoundPlayer.shared.play(named: "incorrect")
                                            } else {
                                                NotificationFeedbackSoundPlayer.shared.play(named: "correct")
                                            }
                                            if matchingAssignments.count == activeMatchingRightItems.count &&
                                                matchingResults.values.allSatisfy({ $0 }) {
                                                gradeCard(isCorrect: !hadMatchingMistake)
                                            }
                                        }
                                    } label: {
                                        VStack(spacing: 2) {
                                            Text(target)
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundStyle(textColorPrimary)
                                                .lineLimit(2)
                                                .minimumScaleFactor(0.8)
                                            if let assigned = assignedTerm {
                                                Text("→ \(assigned)")
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundStyle(isCorrect ? Color.green : Color.red)
                                            }
                                        }
                                        .padding(10)
                                        .frame(maxWidth: .infinity, minHeight: 48)
                                        .notificationLiquidGlass(
                                            cornerRadius: 12,
                                            tint: matchingRightTint(target),
                                            isLight: isLight,
                                            customBorderColor: matchingRightBorder(target)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(matchingAssignments[target] != nil && matchingResults[target] == true || selectedMatchingLeft == nil || isGraded)
                                }
                            }
                        }

                        if hadMatchingMistake && !isGraded {
                            Button {
                                withAnimation(.snappy) {
                                    matchingAssignments.removeAll()
                                    matchingResults.removeAll()
                                    selectedMatchingLeft = nil
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.counterclockwise")
                                    Text("Reset Mismatches")
                                }
                                .font(.caption.bold())
                                .foregroundStyle(textColorSecondary)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 12)
                                .notificationLiquidGlass(cornerRadius: 10, isLight: isLight)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Card Type Presentation: Fill in the Blank
                else if activeCardType == "fill_blank" {
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
                    VStack(spacing: 11) {
                        ForEach(Array(activeOptions.enumerated()), id: \.offset) { index, option in
                            Button {
                                guard selectedAnswer == nil else { return }
                                isAnswerFieldFocused = false
                                withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
                                    selectedAnswer = option
                                    let correct = (option == activeCorrectAnswer)
                                    gradeCard(isCorrect: correct)
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    if activeOptionImageNames.indices.contains(index),
                                       let optImg = CardImageStore.loadImage(named: activeOptionImageNames[index]) {
                                        Image(uiImage: optImg)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 44, height: 44)
                                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    }

                                    Text(option)
                                        .font(.system(size: 15, weight: .semibold))
                                        .multilineTextAlignment(.leading)
                                        .foregroundStyle(optionTextColor(for: option))
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    if selectedAnswer != nil {
                                        if option == activeCorrectAnswer {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 18, weight: .bold))
                                                .foregroundStyle(Color.green)
                                        } else if option == selectedAnswer {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 18, weight: .bold))
                                                .foregroundStyle(Color.red)
                                        }
                                    }
                                }
                                .padding(.vertical, 15)
                                .padding(.horizontal, 18)
                                .notificationLiquidGlass(
                                    cornerRadius: 16,
                                    tint: optionGlassTint(for: option),
                                    isLight: isLight,
                                    customBorderColor: optionBorderColor(for: option)
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(selectedAnswer != nil)
                        }
                    }
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
                                Text(activeCorrectAnswer)
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

                if showingHint && !activeHint.isEmpty {
                    Text(activeHint)
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
            if !previewMode {
                loadAvailableDecks()
                persistStudyHandoff()
            }
        }
        .onChange(of: activeCardId) { _, _ in
            if !previewMode { persistStudyHandoff() }
        }
        .onChange(of: selectedAnswer) { _, _ in
            if !previewMode { persistStudyHandoff() }
        }
        .onChange(of: isGraded) { _, _ in
            if !previewMode { persistStudyHandoff() }
        }
        .onChange(of: showingHint) { _, _ in
            if !previewMode { persistStudyHandoff() }
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

        let unseenCards = deck.cards.filter { !seenCardIds.contains($0.id.uuidString) }
        let nextCard: Flashcard?
        if let card = unseenCards.first {
            nextCard = card
        } else {
            seenCardIds.removeAll()
            let sortedCards = deck.cards.sorted { $0.studyPriority > $1.studyPriority }
            nextCard = sortedCards.first
        }

        guard let cardToStudy = nextCard else {
            statusMessage = "This deck has no cards."
            return
        }

        seenCardIds.insert(cardToStudy.id.uuidString)
        withAnimation(.snappy) {
            sessionCard = NotificationSessionCard(
                id: cardToStudy.id.uuidString,
                deckId: deck.id.uuidString,
                deckName: deck.name,
                deckType: deck.deckType,
                cardType: cardToStudy.cardType.rawValue,
                question: cardToStudy.question,
                options: cardToStudy.options,
                correctAnswer: cardToStudy.correctAnswer,
                hint: cardToStudy.hint,
                matchingLeftItems: cardToStudy.matchingLeftItems,
                matchingRightItems: cardToStudy.matchingRightItems,
                promptImageName: cardToStudy.promptImageName,
                optionImageNames: cardToStudy.optionImageNames
            )
            selectedAnswer = nil
            lastAnswerWasCorrect = nil
            isRevealed = false
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
    }

    private func stopScheduledAlerts() {
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

    private func gradeCard(isCorrect: Bool) {
        isAnswerFieldFocused = false
        NotificationFeedbackSoundPlayer.shared.play(named: isCorrect ? "correct" : "incorrect")
        lastAnswerWasCorrect = isCorrect

        if let defaults = UserDefaults(suiteName: "group.com.learnalert.shared") {
            defaults.set(Date().timeIntervalSince1970, forKey: "lastNotificationAnsweredTimestamp")
            defaults.set(isCorrect, forKey: "lastNotificationWasCorrect")
            defaults.set(activeCardId, forKey: "lastNotificationCardId")
            defaults.set(true, forKey: "lastNotificationWasGraded")
            defaults.synchronize()
        }

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
            card.processAnswer(isCorrect: isCorrect)
            try? context.save()

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
                let stopCondition = sharedDefaults?.string(forKey: "extensionStopCondition") ?? "Until Deck Learnt"
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
        guard !activeDeckId.isEmpty, !activeCardId.isEmpty,
              let defaults = UserDefaults(suiteName: "group.com.learnalert.shared") else { return }
        defaults.set(activeDeckId, forKey: "handoffDeckId")
        defaults.set(activeCardId, forKey: "handoffCardId")
        defaults.set(selectedAnswer, forKey: "handoffSelectedAnswer")
        defaults.set(lastAnswerWasCorrect, forKey: "handoffWasCorrect")
        defaults.set(isGraded, forKey: "handoffWasGraded")
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

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    func didReceive(_ notification: UNNotification) {
        let content = notification.request.content
        let userInfo = content.userInfo

        if let courseId = userInfo["courseId"] as? String, let course = CourseCurriculumCatalog.course(for: courseId) {
            let courseView = CourseNotificationSessionView(course: course, requestId: notification.request.identifier, reviewOnly: userInfo["courseReviewOnly"] as? Bool ?? false) { [weak self] in
                UserDefaults(suiteName: "group.com.learnalert.shared")?.set(courseId, forKey: "handoffCourseId")
                self?.extensionContext?.performNotificationDefaultAction()
            }
            show(AnyView(courseView))
            preferredContentSize = CGSize(width: view.bounds.width, height: 540)
            return
        }

        let cardId = userInfo["cardId"] as? String ?? ""
        let deckId = userInfo["deckId"] as? String ?? ""
        let deckName = userInfo["deckName"] as? String ?? "Deck"
        let deckType = userInfo["deckType"] as? String ?? "Quiz"
        let cardType = userInfo["cardType"] as? String ?? ""
        let isRandom = userInfo["isRandom"] as? Bool ?? false
        let progress = userInfo["progress"] as? String ?? "-"
        let question = userInfo["question"] as? String ?? content.body
        let options = userInfo["options"] as? [String] ?? []
        let correctAnswer = userInfo["correctAnswer"] as? String ?? ""
        let hint = userInfo["hint"] as? String ?? ""
        let matchingLeftItems = userInfo["matchingLeftItems"] as? [String] ?? []
        let matchingRightItems = userInfo["matchingRightItems"] as? [String] ?? []
        let promptImageName = userInfo["promptImageName"] as? String
        let optionImageNames = userInfo["optionImageNames"] as? [String] ?? []

        let isTutorial = userInfo["isTutorial"] as? Bool ?? false
        if isTutorial || content.categoryIdentifier == "FLASHCARD_TEST" {
            self.extensionContext?.notificationActions = []
        }

        let swiftUIView = FlashcardNotificationView(
            cardId: cardId,
            deckId: deckId,
            deckName: deckName,
            deckType: deckType,
            cardType: cardType,
            isRandom: isRandom,
            progress: progress,
            question: question,
            options: options,
            correctAnswer: correctAnswer,
            hint: hint,
            matchingLeftItems: matchingLeftItems,
            matchingRightItems: matchingRightItems,
            promptImageName: promptImageName,
            optionImageNames: optionImageNames,
            isTutorial: isTutorial,
            openApp: { [weak self] in
                self?.openHostApp(deckId: deckId)
            },
            onContentHeightChange: { [weak self] newHeight in
                guard let self = self else { return }
                let targetSize = CGSize(width: self.view.bounds.width, height: newHeight)
                if abs(self.preferredContentSize.height - newHeight) > 2 {
                    self.preferredContentSize = targetSize
                }
            }
        )

        if let existing = hostingController {
            existing.rootView = AnyView(swiftUIView)
        } else {
            let hosting = UIHostingController(rootView: AnyView(swiftUIView))
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
            self.hostingController = hosting
        }
    }

    private func show(_ root: AnyView) {
        if let existing = hostingController { existing.rootView = root; return }
        let hosting = UIHostingController(rootView: root)
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
