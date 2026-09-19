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
    var previewMode = false
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

    // MARK: - Appearance Dynamics
    private var effectiveColorScheme: ColorScheme {
        let mode = UserDefaults(suiteName: "group.com.learnalert.shared")?.string(forKey: "appearanceMode") ?? "system"
        if mode == "light" { return .light }
        if mode == "dark" { return .dark }
        return systemColorScheme
    }

    private var isLight: Bool { effectiveColorScheme == .light }

    private var textColorPrimary: Color {
        isLight ? Color(red: 0.10, green: 0.13, blue: 0.24) : Color.white
    }

    private var textColorSecondary: Color {
        isLight ? Color(red: 0.38, green: 0.44, blue: 0.58) : Color.white.opacity(0.68)
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

    private var notificationControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Notification Controls", systemImage: "slider.horizontal.3")
                .font(.headline.bold())
                .foregroundStyle(textColorPrimary)

            if !availableDecks.isEmpty {
                Menu {
                    ForEach(availableDecks) { deck in
                        Button(deck.name) {
                            loadNextCard(from: deck.id)
                            statusMessage = "Studying \(deck.name)"
                            showingControls = false
                        }
                    }
                } label: {
                    Label("Change mini-session deck", systemImage: "rectangle.stack.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(textColorPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(isLight ? Color.white.opacity(0.60) : Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }

            Button(role: .destructive) {
                stopScheduledAlerts()
            } label: {
                Label("Stop scheduled notifications", systemImage: "bell.slash.fill")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.red.opacity(isLight ? 0.12 : 0.20))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

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
            VStack(spacing: 18) {
                // Header Bar: Deck Name, Progress, Controls
                HStack(spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "rectangle.stack.fill")
                            .font(.caption.bold())
                            .foregroundStyle(Color(red: 0.12, green: 0.50, blue: 0.98))
                        Text(activeDeckName.uppercased())
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(textColorSecondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .notificationLiquidGlass(cornerRadius: 10, isLight: isLight)

                    if !progress.isEmpty && progress != "-" {
                        Text(progress)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(textColorSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .notificationLiquidGlass(cornerRadius: 10, isLight: isLight)
                    }

                    Spacer()

                    Button {
                        withAnimation(.snappy) { showingControls.toggle() }
                    } label: {
                        Image(systemName: showingControls ? "xmark" : "gearshape.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(textColorPrimary)
                            .frame(width: 36, height: 36)
                            .notificationLiquidGlass(cornerRadius: 18, isLight: isLight)
                    }
                    .accessibilityLabel(showingControls ? "Close controls" : "Study controls")
                }

                if showingControls {
                    notificationControls
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Question Box
                if activeCardType != "matching" {
                    Text(activeQuestion)
                        .font(.system(size: 18, weight: .bold))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundStyle(textColorPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .padding(.horizontal, 18)
                        .notificationLiquidGlass(cornerRadius: 20, isLight: isLight)
                }

                // Dynamic Engine Interaction
                if isSkipped {
                    VStack(spacing: 12) {
                        Image(systemName: "forward.fill")
                            .font(.largeTitle)
                            .foregroundStyle(textColorSecondary)
                        Text("Skipped")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(textColorSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .notificationLiquidGlass(cornerRadius: 16, isLight: isLight)
                    .transition(.scale.combined(with: .opacity))
                } else {
                    if activeCardType == "multiple_choice" {
                        VStack(spacing: 11) {
                            ForEach(activeOptions, id: \.self) { option in
                                if selectedAnswer == nil || option == activeCorrectAnswer || option == selectedAnswer {
                                    Button(action: {
                                        guard selectedAnswer == nil else { return }
                                        withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
                                            selectedAnswer = option
                                        }
                                        gradeCard(isCorrect: option == activeCorrectAnswer)
                                    }) {
                                        HStack(spacing: 12) {
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
                                    .transition(.scale.combined(with: .opacity))
                                }
                            }
                        }
                    } else if activeCardType == "fill_blank" {
                        VStack(spacing: 12) {
                            TextField("Type your answer", text: $typedAnswer)
                                .id("fill_blank_field")
                                .font(.system(size: 16, weight: .medium))
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused($isAnswerFieldFocused)
                                .submitLabel(.done)
                                .onSubmit {
                                    checkFillBlankAnswer()
                                }
                                .padding(14)
                                .foregroundStyle(textColorPrimary)
                                .notificationLiquidGlass(
                                    cornerRadius: 14,
                                    tint: isGraded ? (lastAnswerWasCorrect == true ? Color.green.opacity(0.15) : Color.red.opacity(0.15)) : nil,
                                    isLight: isLight
                                )
                                .disabled(isGraded)

                            if isGraded {
                                Label(
                                    lastAnswerWasCorrect == true ? "Correct" : "Incorrect · Answer: \(activeCorrectAnswer)",
                                    systemImage: lastAnswerWasCorrect == true ? "checkmark.circle.fill" : "xmark.circle.fill"
                                )
                                .font(.subheadline.bold())
                                .foregroundStyle(lastAnswerWasCorrect == true ? Color.green : Color.red)
                            } else {
                                Button {
                                    checkFillBlankAnswer()
                                } label: {
                                    Text("Check Answer")
                                        .font(.headline.bold())
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .foregroundStyle(.white)
                                        .background(
                                            LinearGradient(
                                                colors: [Color(red: 0.12, green: 0.50, blue: 0.98), Color(red: 0.20, green: 0.68, blue: 0.96)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                }
                                .disabled(typedAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        }
                    } else if activeCardType == "matching" {
                        VStack(spacing: 12) {
                            Text("Tap a term, then tap its match")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(textColorSecondary)

                            HStack(alignment: .top, spacing: 10) {
                                VStack(spacing: 8) {
                                    ForEach(activeMatchingLeftItems, id: \.self) { item in
                                        Button(item) { selectedMatchingLeft = item }
                                            .font(.caption.bold())
                                            .foregroundStyle(textColorPrimary)
                                            .frame(maxWidth: .infinity, minHeight: 44)
                                            .notificationLiquidGlass(
                                                cornerRadius: 12,
                                                tint: matchingLeftTint(item),
                                                isLight: isLight,
                                                customBorderColor: matchingLeftBorder(item)
                                            )
                                            .disabled(isGraded || isCorrectlyMatched(item))
                                    }
                                }

                                VStack(spacing: 8) {
                                    ForEach(activeMatchingRightItems.reversed(), id: \.self) { match in
                                        Button {
                                            guard let selectedMatchingLeft else { return }
                                            matchingAssignments = matchingAssignments.filter { $0.value != selectedMatchingLeft }
                                            matchingAssignments[match] = selectedMatchingLeft
                                            let isCorrect = isCorrectMatch(left: selectedMatchingLeft, right: match)
                                            matchingResults[match] = isCorrect
                                            hadMatchingMistake = hadMatchingMistake || !isCorrect
                                            self.selectedMatchingLeft = nil
                                            let completedCorrectly = activeMatchingRightItems.allSatisfy { target in
                                                if target == match { return isCorrect }
                                                return matchingResults[target] == true
                                            }
                                            if completedCorrectly {
                                                gradeCard(isCorrect: !hadMatchingMistake && isCorrect)
                                            }
                                        } label: {
                                            VStack(spacing: 2) {
                                                Text(match)
                                                    .font(.caption.bold())
                                                    .foregroundStyle(textColorPrimary)
                                                if let term = matchingAssignments[match] {
                                                    Text(term)
                                                        .font(.caption2.bold())
                                                        .foregroundStyle(matchingResults[match] == true ? Color.green : Color.red)
                                                }
                                            }
                                            .frame(maxWidth: .infinity, minHeight: 44)
                                            .notificationLiquidGlass(
                                                cornerRadius: 12,
                                                tint: matchingRightTint(match),
                                                isLight: isLight,
                                                customBorderColor: matchingRightBorder(match)
                                            )
                                        }
                                        .disabled(isGraded || matchingResults[match] == true || selectedMatchingLeft == nil)
                                    }
                                }
                            }

                            if matchingResults.values.contains(false), !isGraded {
                                Button {
                                    let incorrectTargets = matchingResults.filter { !$0.value }.map(\.key)
                                    incorrectTargets.forEach {
                                        matchingAssignments.removeValue(forKey: $0)
                                        matchingResults.removeValue(forKey: $0)
                                    }
                                    selectedMatchingLeft = nil
                                } label: {
                                    Label("Try Again", systemImage: "arrow.counterclockwise")
                                        .font(.subheadline.bold())
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .foregroundStyle(Color.red)
                                        .notificationLiquidGlass(cornerRadius: 12, tint: Color.red.opacity(0.12), isLight: isLight)
                                }
                            }
                        }
                    } else {
                        // Tap to Reveal
                        if !isRevealed {
                            Button {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    isRevealed = true
                                    showingHint = false
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "hand.tap.fill")
                                    Text("Tap to Reveal")
                                        .font(.headline.bold())
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .foregroundStyle(textColorPrimary)
                                .notificationLiquidGlass(cornerRadius: 16, isLight: isLight)
                            }
                        } else {
                            VStack(spacing: 16) {
                                Text(activeCorrectAnswer)
                                    .font(.title3.bold())
                                    .foregroundStyle(Color(red: 0.10, green: 0.65, blue: 0.90))
                                    .multilineTextAlignment(.center)
                                    .padding(.vertical, 14)
                                    .padding(.horizontal, 16)
                                    .frame(maxWidth: .infinity)
                                    .notificationLiquidGlass(cornerRadius: 14, tint: Color.cyan.opacity(0.12), isLight: isLight)

                                if !isGraded {
                                    HStack(spacing: 12) {
                                        Button {
                                            gradeReveal(correct: false)
                                        } label: {
                                            HStack(spacing: 6) {
                                                Image(systemName: "xmark")
                                                Text("Missed It")
                                            }
                                            .font(.headline.bold())
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 13)
                                            .foregroundStyle(Color.red)
                                            .notificationLiquidGlass(cornerRadius: 12, tint: Color.red.opacity(0.14), isLight: isLight)
                                        }

                                        Button {
                                            gradeReveal(correct: true)
                                        } label: {
                                            HStack(spacing: 6) {
                                                Image(systemName: "checkmark")
                                                Text("Knew It!")
                                            }
                                            .font(.headline.bold())
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 13)
                                            .foregroundStyle(Color.green)
                                            .notificationLiquidGlass(cornerRadius: 12, tint: Color.green.opacity(0.14), isLight: isLight)
                                        }
                                    }
                                    .transition(.scale.combined(with: .opacity))
                                }
                            }
                        }
                    }

                    // HINT AND SKIP CONTROLS
                    if !isGraded && !isSkipped {
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                if !activeHint.isEmpty {
                                    Button {
                                        if !showingHint { recordHintUsed() }
                                        withAnimation(.spring) { showingHint.toggle() }
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: showingHint ? "lightbulb.slash.fill" : "lightbulb.fill")
                                            Text(showingHint ? "Hide Hint" : "Hint").fontWeight(.bold)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 11)
                                        .foregroundStyle(Color.orange)
                                        .notificationLiquidGlass(cornerRadius: 12, tint: Color.orange.opacity(0.10), isLight: isLight)
                                    }
                                }

                                Button {
                                    recordSkipAndAdvance()
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "forward.fill")
                                        Text("Skip").fontWeight(.bold)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 11)
                                    .foregroundStyle(textColorSecondary)
                                    .notificationLiquidGlass(cornerRadius: 12, isLight: isLight)
                                }
                            }

                            if showingHint {
                                Text(activeHint)
                                    .font(.subheadline.italic())
                                    .foregroundStyle(Color.orange)
                                    .padding(12)
                                    .frame(maxWidth: .infinity)
                                    .notificationLiquidGlass(cornerRadius: 12, tint: Color.orange.opacity(0.08), isLight: isLight)
                                    .transition(.move(edge: .top).combined(with: .opacity))
                            }
                        }
                        .transition(.opacity)
                    }
                }

                // POST-GRADE STATS & UNRESTRICTED STUDY FLOW
                if isGraded {
                    VStack(spacing: 14) {
                        HStack(spacing: 10) {
                            NotificationStat(title: "New", value: unlearnedCount, icon: "sparkles", isLight: isLight)
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
                    }
                    .transition(.opacity)
                }

                // BOTTOM RIGHT: Continue in App button
                HStack {
                    Spacer()

                    Button {
                        isAnswerFieldFocused = false
                        persistStudyHandoff()
                        openApp()
                    } label: {
                        HStack(spacing: 5) {
                            Text("Continue in App")
                                .font(.system(size: 12, weight: .semibold))
                            Image(systemName: "arrow.up.forward.app.fill")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .padding(.horizontal, 13)
                        .padding(.vertical, 7)
                        .foregroundStyle(isLight ? Color(red: 0.12, green: 0.48, blue: 0.96) : Color(red: 0.35, green: 0.70, blue: 1.0))
                        .notificationLiquidGlass(
                            cornerRadius: 10,
                            tint: isLight ? Color.white.opacity(0.65) : Color.white.opacity(0.08),
                            isLight: isLight
                        )
                    }
                }
                .padding(.top, 2)
            }
            .padding(18)
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
        .background(NotificationBackdrop(isLight: isLight))
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
            }
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
        guard let target = matchingAssignments.first(where: { $0.value == item })?.key,              let result = matchingResults[target] else { return nil }
        return result ? Color.green.opacity(0.24) : Color.red.opacity(0.24)
    }

    private func matchingLeftBorder(_ item: String) -> Color? {
        if selectedMatchingLeft == item { return Color.cyan.opacity(0.85) }
        guard let target = matchingAssignments.first(where: { $0.value == item })?.key,              let result = matchingResults[target] else { return nil }
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
                matchingRightItems: cardToStudy.matchingRightItems
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
        // REQUEST 8: Mark handoff originated from notification UI
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
    var isLight: Bool

    var body: some View {
        ZStack {
            if isLight {
                // Crisp luminous frosted light aesthetic
                LinearGradient(
                    colors: [
                        Color(red: 0.93, green: 0.96, blue: 1.0),
                        Color(red: 0.88, green: 0.93, blue: 0.98),
                        Color(red: 0.93, green: 0.90, blue: 0.99)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(Color(red: 0.20, green: 0.72, blue: 0.95).opacity(0.20))
                    .frame(width: 260, height: 260)
                    .blur(radius: 46)
                    .offset(x: 140, y: -180)

                Circle()
                    .fill(Color(red: 0.90, green: 0.35, blue: 0.65).opacity(0.14))
                    .frame(width: 240, height: 240)
                    .blur(radius: 50)
                    .offset(x: -140, y: 200)

                ForEach(0..<5, id: \.self) { index in
                    Circle()
                        .stroke(Color(red: 0.15, green: 0.45, blue: 0.85).opacity(0.05), lineWidth: 1)
                        .frame(
                            width: CGFloat(110 + index * 42),
                            height: CGFloat(110 + index * 42)
                        )
                        .offset(x: 140, y: -160)
                }
            } else {
                // Deep twilight & vibrant neon liquid glass aesthetic
                LinearGradient(
                    colors: [
                        Color(red: 0.07, green: 0.09, blue: 0.20),
                        Color(red: 0.14, green: 0.11, blue: 0.28),
                        Color(red: 0.06, green: 0.18, blue: 0.28)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(Color(red: 0.10, green: 0.72, blue: 0.95).opacity(0.28))
                    .frame(width: 260, height: 260)
                    .blur(radius: 46)
                    .offset(x: 140, y: -180)

                Circle()
                    .fill(Color(red: 0.90, green: 0.25, blue: 0.65).opacity(0.22))
                    .frame(width: 240, height: 240)
                    .blur(radius: 50)
                    .offset(x: -140, y: 200)

                ForEach(0..<6, id: \.self) { index in
                    Circle()
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                        .frame(
                            width: CGFloat(110 + index * 42),
                            height: CGFloat(110 + index * 42)
                        )
                        .offset(x: 140, y: -160)
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

// MARK: - Notification Content Extension UIViewController
class NotificationViewController: UIViewController, UNNotificationContentExtension {
    var hostingController: UIHostingController<FlashcardNotificationView>?
    private var isKeyboardActive = false

    override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)

        let swiftUIView = FlashcardNotificationView(
            cardId: "",
            deckId: "",
            deckName: "Loading...",
            deckType: "Quiz",
            cardType: "multiple_choice",
            isRandom: false,
            progress: "-",
            question: "...",
            options: ["...", "...", "...", "..."],
            correctAnswer: "...",
            hint: "",
            openApp: { [weak self] in
                self?.extensionContext?.performNotificationDefaultAction()
            },
            onContentHeightChange: { [weak self] height in
                self?.updatePreferredContentHeight(height)
            }
        )
        let hc = UIHostingController(rootView: swiftUIView)
        hc.view.translatesAutoresizingMaskIntoConstraints = false
        hc.view.backgroundColor = .clear

        self.addChild(hc)
        self.view.addSubview(hc.view)
        hc.didMove(toParent: self)

        NSLayoutConstraint.activate([
            hc.view.topAnchor.constraint(equalTo: view.topAnchor),
            hc.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hc.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hc.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        self.hostingController = hc
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func keyboardWillShow() {
        isKeyboardActive = true
    }

    @objc private func keyboardWillHide() {
        isKeyboardActive = false
    }

    private func updatePreferredContentHeight(_ height: CGFloat) {
        guard !isKeyboardActive else { return }
        var safeWidth = view.bounds.width
        if safeWidth <= 0 {
            safeWidth = view.window?.windowScene?.screen.bounds.width ?? 350
        }
        let targetHeight = max(height, 360)
        if abs(preferredContentSize.height - targetHeight) > 2 {
            preferredContentSize = CGSize(width: safeWidth, height: targetHeight)
        }
    }

    func didReceive(_ notification: UNNotification) {
        let userInfo = notification.request.content.userInfo
        let cardId = userInfo["cardId"] as? String ?? ""
        let deckId = userInfo["deckId"] as? String ?? ""
        let deckName = userInfo["deckName"] as? String ?? "Deck"
        let deckType = userInfo["deckType"] as? String ?? "Quiz"
        let cardType = userInfo["cardType"] as? String ?? ""
        let isRandom = userInfo["isRandom"] as? Bool ?? true
        let progress = userInfo["progress"] as? String ?? ""
        let question = userInfo["question"] as? String ?? "Error"
        let options = userInfo["options"] as? [String] ?? []
        let correctAnswer = userInfo["correctAnswer"] as? String ?? "Error"
        let hint = userInfo["hint"] as? String ?? ""
        let matchingLeftItems = userInfo["matchingLeftItems"] as? [String] ?? []
        let matchingRightItems = userInfo["matchingRightItems"] as? [String] ?? []

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.hostingController?.rootView = FlashcardNotificationView(
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
                openApp: { [weak self] in
                    self?.extensionContext?.performNotificationDefaultAction()
                },
                onContentHeightChange: { [weak self] height in
                    self?.updatePreferredContentHeight(height)
                }
            )

            self.hostingController?.view.setNeedsLayout()
            self.hostingController?.view.layoutIfNeeded()
        }
    }
}
