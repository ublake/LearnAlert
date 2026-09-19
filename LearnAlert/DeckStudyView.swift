import SwiftUI
import SwiftData

struct DeckStudyView: View {
    @Bindable var deck: Deck
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var studyQueue: [Flashcard] = []
    @State private var cardIndex = 0
    @State private var selectedAnswer: String?
    @State private var isRevealed = false
    @State private var isGraded = false
    @State private var correctCount = 0
    @State private var showingHint = false
    @State private var hasRecordedHint = false
    @State private var didApplyInitialState = false
    @State private var isComplete = false

    let initialCardId: UUID?
    let initialSelectedAnswer: String?
    let initialWasCorrect: Bool?
    let initialWasGraded: Bool
    let initialHintVisible: Bool

    init(
        deck: Deck,
        initialCardId: UUID? = nil,
        initialSelectedAnswer: String? = nil,
        initialWasCorrect: Bool? = nil,
        initialWasGraded: Bool = false,
        initialHintVisible: Bool = false
    ) {
        self.deck = deck
        self.initialCardId = initialCardId
        self.initialSelectedAnswer = initialSelectedAnswer
        self.initialWasCorrect = initialWasCorrect
        self.initialWasGraded = initialWasGraded
        self.initialHintVisible = initialHintVisible
    }

    private var currentCard: Flashcard? {
        studyQueue.indices.contains(cardIndex) ? studyQueue[cardIndex] : nil
    }

    var body: some View {
        ZStack {
            QuizTheme.canvas.ignoresSafeArea()

            if deck.cards.isEmpty {
                QuizEmptyState(onClose: dismiss.callAsFunction)
            } else if isComplete {
                QuizResultsView(
                    deckID: deck.id,
                    appearanceSeed: deck.appearanceSeed,
                    deckName: deck.name,
                    score: correctCount * 30,
                    correctCount: correctCount,
                    totalCount: deck.cards.count,
                    onRestart: restartCycle,
                    onClose: dismiss.callAsFunction
                )
            } else if let card = currentCard {
                QuizSessionView(
                    deckName: deck.name,
                    question: card.question,
                    cardType: card.cardType,
                    options: card.options,
                    matchingLeftItems: card.matchingLeftItems,
                    matchingRightItems: card.matchingRightItems,
                    correctAnswer: card.correctAnswer,
                    hint: card.hint,
                    cardNumber: cardIndex + 1,
                    cardCount: studyQueue.count,
                    correctCount: correctCount,
                    selectedAnswer: selectedAnswer,
                    isRevealed: isRevealed,
                    isGraded: isGraded,
                    showingHint: showingHint,
                    onSelect: { selectOption($0, for: card) },
                    onReveal: { withAnimation(.snappy) { isRevealed = true } },
                    onGrade: { grade(card, isCorrect: $0) },
                    onToggleHint: { toggleHint(for: card) },
                    onSkip: { skip(card) },
                    onContinue: { submitAndAdvance(card) },
                    onClose: dismiss.callAsFunction
                )
                .id(card.id)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear(perform: applyInitialStateIfNeeded)
    }

    private func setupStudyQueue() {
        guard studyQueue.isEmpty else { return }
        studyQueue = buildSmartStudyQueue()
    }

    private func buildSmartStudyQueue() -> [Flashcard] {
        deck.cards.sorted {
            if $0.studyPriority != $1.studyPriority {
                return $0.studyPriority > $1.studyPriority
            }
            if $0.accuracy != $1.accuracy {
                return $0.accuracy < $1.accuracy
            }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    private func selectOption(_ option: String, for card: Flashcard) {
        // Lock answer once clicked: ignore any subsequent clicks
        guard !isGraded && selectedAnswer == nil else { return }
        selectedAnswer = option
        let isCorrect = option == card.correctAnswer
        grade(card, isCorrect: isCorrect)
    }

    private func toggleHint(for card: Flashcard) {
        if !hasRecordedHint {
            card.recordHintUsed()
            hasRecordedHint = true
            try? context.save()
        }
        withAnimation(.snappy) { showingHint.toggle() }
    }

    private func skip(_ card: Flashcard) {
        InteractionSoundPlayer.shared.play(.skip)
        card.recordSkip()
        // Smart repetition: re-queue skipped card so user gets another chance to master it
        let reinsertIndex = min(cardIndex + 3, studyQueue.count)
        studyQueue.insert(card, at: reinsertIndex)
        try? context.save()
        advance()
    }

    private func grade(_ card: Flashcard, isCorrect: Bool) {
        guard !isGraded else { return }
        InteractionSoundPlayer.shared.play(isCorrect ? .correct : .incorrect)
        card.processAnswer(isCorrect: isCorrect)
        if isCorrect {
            correctCount += 1
        } else {
            // Smart repetition: re-queue missed card into the active study queue to master it
            let reinsertIndex = min(cardIndex + 3, studyQueue.count)
            studyQueue.insert(card, at: reinsertIndex)
        }
        isGraded = true
        try? context.save()
    }

    private func submitAndAdvance(_ card: Flashcard) {
        guard isGraded else { return }
        advance()
    }

    private func advance() {
        guard cardIndex + 1 < studyQueue.count else {
            withAnimation(.snappy) { isComplete = true }
            return
        }
        withAnimation(.snappy) {
            cardIndex += 1
            selectedAnswer = nil
            isRevealed = false
            isGraded = false
            showingHint = false
            hasRecordedHint = false
        }
    }

    private func restartCycle() {
        withAnimation(.snappy) {
            studyQueue = buildSmartStudyQueue()
            cardIndex = 0
            selectedAnswer = nil
            isRevealed = false
            isGraded = false
            correctCount = 0
            showingHint = false
            hasRecordedHint = false
            isComplete = false
        }
    }

    private func applyInitialStateIfNeeded() {
        guard !didApplyInitialState else { return }
        didApplyInitialState = true
        setupStudyQueue()

        if let initialCardId,
           let initialIndex = studyQueue.firstIndex(where: { $0.id == initialCardId }) {
            cardIndex = initialIndex
        }
        selectedAnswer = initialSelectedAnswer
        isGraded = initialWasGraded
        isRevealed = initialWasGraded && initialSelectedAnswer == nil
        showingHint = initialHintVisible
        hasRecordedHint = initialHintVisible
        correctCount = initialWasCorrect == true ? 1 : 0
    }
}

private struct QuizSessionView: View {
    let deckName: String
    let question: String
    let cardType: FlashcardType
    let options: [String]
    let matchingLeftItems: [String]
    let matchingRightItems: [String]
    let correctAnswer: String
    let hint: String
    let cardNumber: Int
    let cardCount: Int
    let correctCount: Int
    let selectedAnswer: String?
    let isRevealed: Bool
    let isGraded: Bool
    let showingHint: Bool
    let onSelect: (String) -> Void
    let onReveal: () -> Void
    let onGrade: (Bool) -> Void
    let onToggleHint: () -> Void
    let onSkip: () -> Void
    let onContinue: () -> Void
    let onClose: () -> Void

    private var canContinue: Bool { isGraded }
    private var actionTitle: LocalizedStringKey { cardNumber >= cardCount ? "FINISH" : "CONTINUE" }

    var body: some View {
        VStack(spacing: 0) {
            QuizHeader(deckName: deckName, correctCount: correctCount, onClose: onClose)
                .padding(.horizontal, 20)
                .padding(.top, 8)

            QuizProgress(cardNumber: cardNumber, cardCount: cardCount)
                .padding(.horizontal, 20)
                .padding(.top, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Text(question)
                        .font(.custom("Poppins-SemiBold", size: 22, relativeTo: .title2))
                        .foregroundStyle(QuizTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    switch cardType {
                    case .multipleChoice:
                        QuizOptions(
                            options: options,
                            selectedAnswer: selectedAnswer,
                            correctAnswer: correctAnswer,
                            isGraded: isGraded,
                            onSelect: onSelect
                        )
                    case .tapReveal:
                        QuizRevealCard(
                            answer: correctAnswer,
                            isRevealed: isRevealed,
                            isGraded: isGraded,
                            onReveal: onReveal,
                            onGrade: onGrade
                        )
                    case .fillBlank:
                        QuizFillBlankCard(answer: correctAnswer, isGraded: isGraded, onGrade: onGrade)
                    case .matching:
                        QuizMatchingCard(
                            leftItems: matchingLeftItems,
                            rightItems: matchingRightItems,
                            isGraded: isGraded,
                            onGrade: onGrade
                        )
                    }

                    QuizUtilityControls(
                        hint: hint,
                        showingHint: showingHint,
                        isGraded: isGraded,
                        onToggleHint: onToggleHint,
                        onSkip: onSkip
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 38)
                .padding(.bottom, 24)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button(actionTitle, action: onContinue)
                .buttonStyle(QuizActionButtonStyle())
                .disabled(!canContinue)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(QuizTheme.canvas)
        }
    }
}

private struct QuizHeader: View {
    let deckName: String
    let correctCount: Int
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Label("\(correctCount)", systemImage: "checkmark.circle.fill")
                .font(.custom("Poppins-SemiBold", size: 14, relativeTo: .subheadline))
                .foregroundStyle(QuizTheme.green)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(QuizTheme.surface, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(QuizTheme.border, lineWidth: 1))

            Text(deckName)
                .font(.custom("Poppins-SemiBold", size: 18, relativeTo: .headline))
                .foregroundStyle(QuizTheme.ink)
                .lineLimit(1)
                .frame(maxWidth: .infinity)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(QuizTheme.ink)
                    .frame(width: 24, height: 24)
                    .padding(6)
                    .background(QuizTheme.surface, in: Circle())
                    .overlay(Circle().stroke(QuizTheme.border, lineWidth: 1))
            }
            .frame(width: 44, height: 44)
            .buttonStyle(.plain)
            .accessibilityLabel("Close quiz")
        }
        .frame(minHeight: 44)
    }
}

private struct QuizProgress: View {
    let cardNumber: Int
    let cardCount: Int

    var body: some View {
        HStack(spacing: 12) {
            ProgressView(value: Double(cardNumber), total: Double(max(cardCount, 1)))
                .tint(QuizTheme.green)
                .scaleEffect(x: 1, y: 2)

            Text("\(cardNumber)/\(cardCount)")
                .font(.custom("Poppins-SemiBold", size: 14, relativeTo: .subheadline))
                .foregroundStyle(QuizTheme.inkSecondary)
                .monospacedDigit()
        }
    }
}

private struct QuizOptions: View {
    let options: [String]
    let selectedAnswer: String?
    let correctAnswer: String
    let isGraded: Bool
    let onSelect: (String) -> Void

    var body: some View {
        VStack(spacing: 12) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                Button {
                    onSelect(option)
                } label: {
                    QuizOptionRow(
                        letter: String(UnicodeScalar(65 + index) ?? "A"),
                        option: option,
                        isSelected: selectedAnswer == option,
                        isCorrect: option == correctAnswer,
                        isGraded: isGraded
                    )
                }
                .buttonStyle(.plain)
                .disabled(isGraded || selectedAnswer != nil) // Locked once an answer is selected
            }
        }
    }
}

private struct QuizOptionRow: View {
    let letter: String
    let option: String
    let isSelected: Bool
    let isCorrect: Bool
    let isGraded: Bool

    private var backgroundColor: Color {
        if !isGraded {
            return isSelected ? QuizTheme.selected : QuizTheme.surface
        }
        // When graded: show correct answer in green, chosen wrong answer in red, others dimmed
        if isCorrect {
            return QuizTheme.green
        }
        if isSelected && !isCorrect {
            return LearnAlertStyle.coral
        }
        return QuizTheme.surface.opacity(0.55)
    }

    private var borderColor: Color {
        if !isGraded {
            return isSelected ? Color.clear : QuizTheme.border
        }
        if isCorrect {
            return QuizTheme.green
        }
        if isSelected && !isCorrect {
            return LearnAlertStyle.coral
        }
        return QuizTheme.border.opacity(0.3)
    }

    private var textColor: Color {
        if !isGraded {
            return isSelected ? Color.white : QuizTheme.ink
        }
        if isCorrect || (isSelected && !isCorrect) {
            return Color.white
        }
        return QuizTheme.inkSecondary.opacity(0.65)
    }

    private var badgeFill: Color {
        if !isGraded {
            return isSelected ? Color.white.opacity(0.24) : QuizTheme.canvas
        }
        if isCorrect || (isSelected && !isCorrect) {
            return Color.white.opacity(0.25)
        }
        return QuizTheme.canvas.opacity(0.6)
    }

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(badgeFill)
                    .frame(width: 36, height: 36)

                if isGraded {
                    if isCorrect {
                        Image(systemName: "checkmark")
                            .font(.body.weight(.bold))
                            .foregroundStyle(.white)
                    } else if isSelected {
                        Image(systemName: "xmark")
                            .font(.body.weight(.bold))
                            .foregroundStyle(.white)
                    } else {
                        Text(letter)
                            .font(.custom("Poppins-SemiBold", size: 16, relativeTo: .body))
                            .foregroundStyle(QuizTheme.inkSecondary.opacity(0.65))
                    }
                } else if isSelected {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.bold))
                        .foregroundStyle(.white)
                } else {
                    Text(letter)
                        .font(.custom("Poppins-SemiBold", size: 16, relativeTo: .body))
                        .foregroundStyle(QuizTheme.ink)
                }
            }

            Text(option)
                .font(.custom("Poppins-SemiBold", size: 16, relativeTo: .body))
                .foregroundStyle(textColor)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(borderColor, lineWidth: isGraded && (isCorrect || isSelected) ? 2 : 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .animation(.easeOut(duration: 0.16), value: isSelected)
        .animation(.easeOut(duration: 0.2), value: isGraded)
    }
}

private struct QuizRevealCard: View {
    let answer: String
    let isRevealed: Bool
    let isGraded: Bool
    let onReveal: () -> Void
    let onGrade: (Bool) -> Void

    var body: some View {
        VStack(spacing: 16) {
            if isRevealed {
                Text(answer)
                    .font(.custom("Poppins-SemiBold", size: 20, relativeTo: .title3))
                    .foregroundStyle(QuizTheme.ink)
                    .frame(maxWidth: .infinity, minHeight: 100)
                    .padding()
                    .background(QuizTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(QuizTheme.border, lineWidth: 1))

                if !isGraded {
                    HStack(spacing: 12) {
                        Button("MISSED IT") { onGrade(false) }
                            .buttonStyle(QuizChoiceButtonStyle(color: LearnAlertStyle.coral))
                        Button("KNEW IT") { onGrade(true) }
                            .buttonStyle(QuizChoiceButtonStyle(color: QuizTheme.green))
                    }
                } else {
                    Text("Answer recorded")
                        .font(.custom("Poppins-SemiBold", size: 14, relativeTo: .subheadline))
                        .foregroundStyle(QuizTheme.inkSecondary)
                        .padding(.vertical, 8)
                }
            } else {
                Button("REVEAL ANSWER", action: onReveal)
                    .buttonStyle(QuizActionButtonStyle())
            }
        }
    }
}

private struct QuizFillBlankCard: View {
    let answer: String
    let isGraded: Bool
    let onGrade: (Bool) -> Void
    @State private var response = ""
    @State private var wasCorrect: Bool?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Type the missing answer", text: $response)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(QuizTheme.ink)
                .padding(16)
                .background(QuizTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(borderColor, lineWidth: isGraded ? 2 : 1)
                )
                .disabled(isGraded)

            if isGraded {
                HStack(spacing: 8) {
                    Image(systemName: wasCorrect == true ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(wasCorrect == true ? QuizTheme.green : LearnAlertStyle.coral)
                    Text(wasCorrect == true ? "Correct!" : "Answer: \(answer)")
                        .font(.custom("Poppins-SemiBold", size: 15, relativeTo: .subheadline))
                        .foregroundStyle(wasCorrect == true ? QuizTheme.green : LearnAlertStyle.coral)
                }
                .padding(.top, 4)
            } else {
                Button("CHECK ANSWER") {
                    let entered = response.trimmingCharacters(in: .whitespacesAndNewlines)
                    let expected = answer.trimmingCharacters(in: .whitespacesAndNewlines)
                    let correct = entered.localizedCaseInsensitiveCompare(expected) == .orderedSame
                    wasCorrect = correct
                    onGrade(correct)
                }
                .buttonStyle(QuizActionButtonStyle())
                .disabled(response.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private var borderColor: Color {
        guard isGraded, let wasCorrect else { return QuizTheme.border }
        return wasCorrect ? QuizTheme.green : LearnAlertStyle.coral
    }
}

private struct QuizMatchingCard: View {
    let leftItems: [String]
    let rightItems: [String]
    let isGraded: Bool
    let onGrade: (Bool) -> Void
    @State private var shuffledRightItems: [String] = []
    @State private var assignments: [String: String] = [:]
    @State private var selectedLeftItem: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Tap or drag each item onto its match.")
                .font(.custom("Poppins-Medium", size: 13, relativeTo: .subheadline))
                .foregroundStyle(QuizTheme.inkSecondary)

            HStack(alignment: .top, spacing: 12) {
                // Left Column
                VStack(spacing: 10) {
                    ForEach(leftItems, id: \.self) { item in
                        let isSelected = selectedLeftItem == item
                        let isAssigned = assignments.values.contains(item)
                        Button {
                            guard !isGraded else { return }
                            withAnimation(.snappy) {
                                selectedLeftItem = (selectedLeftItem == item ? nil : item)
                            }
                        } label: {
                            Text(item)
                                .font(.custom("Poppins-SemiBold", size: 14, relativeTo: .subheadline))
                                .foregroundStyle(QuizTheme.ink)
                                .frame(maxWidth: .infinity, minHeight: 54)
                                .padding(.horizontal, 10)
                                .background(isSelected ? Color.purple.opacity(0.18) : QuizTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(isSelected ? Color.purple : QuizTheme.border, lineWidth: isSelected ? 2 : 1)
                                )
                                .opacity(isAssigned && !isSelected ? 0.4 : 1)
                        }
                        .buttonStyle(.plain)
                        .draggable(item)
                    }
                }

                // Right Column
                VStack(spacing: 10) {
                    ForEach(shuffledRightItems, id: \.self) { target in
                        let assignedTerm = assignments[target]
                        let isTargetCorrect = isGraded && assignedTerm != nil && leftItems.firstIndex(of: assignedTerm!) == rightItems.firstIndex(of: target)
                        Button {
                            guard !isGraded else { return }
                            withAnimation(.snappy) {
                                if let selected = selectedLeftItem {
                                    assignments = assignments.filter { $0.value != selected }
                                    assignments[target] = selected
                                    selectedLeftItem = nil
                                } else if assignments[target] != nil {
                                    assignments.removeValue(forKey: target)
                                }
                            }
                        } label: {
                            VStack(spacing: 3) {
                                Text(target)
                                    .font(.custom("Poppins-SemiBold", size: 14, relativeTo: .subheadline))
                                if let term = assignedTerm {
                                    Text(term)
                                        .font(.custom("Poppins-Medium", size: 12, relativeTo: .caption))
                                        .foregroundStyle(isGraded ? (isTargetCorrect ? QuizTheme.green : LearnAlertStyle.coral) : QuizTheme.green)
                                } else {
                                    Text("Tap / Drop match")
                                        .font(.custom("Poppins-Regular", size: 11, relativeTo: .caption2))
                                        .foregroundStyle(QuizTheme.inkSecondary)
                                }
                            }
                            .foregroundStyle(QuizTheme.ink)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .padding(.horizontal, 10)
                            .background(QuizTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        isGraded && assignedTerm != nil
                                            ? (isTargetCorrect ? QuizTheme.green : LearnAlertStyle.coral)
                                            : QuizTheme.border,
                                        lineWidth: isGraded && assignedTerm != nil ? 2 : 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .dropDestination(for: String.self) { items, _ in
                            guard !isGraded, let item = items.first, leftItems.contains(item) else { return false }
                            assignments = assignments.filter { $0.value != item }
                            assignments[target] = item
                            return true
                        }
                    }
                }
            }

            if !isGraded {
                Button("CHECK MATCHES") { onGrade(matchesAreCorrect) }
                    .buttonStyle(QuizActionButtonStyle())
                    .disabled(assignments.count != min(leftItems.count, rightItems.count))
            }
        }
        .onAppear {
            if shuffledRightItems.isEmpty { shuffledRightItems = rightItems.shuffled() }
        }
    }

    private var matchesAreCorrect: Bool {
        guard leftItems.count == rightItems.count else { return false }
        return rightItems.indices.allSatisfy { assignments[rightItems[$0]] == leftItems[$0] }
    }
}

private struct QuizUtilityControls: View {
    let hint: String
    let showingHint: Bool
    let isGraded: Bool
    let onToggleHint: () -> Void
    let onSkip: () -> Void

    var body: some View {
        if !isGraded {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    if !hint.isEmpty {
                        Button(showingHint ? "HIDE HINT" : "HINT", action: onToggleHint)
                    }
                    Button("SKIP", action: onSkip)
                }
                .font(.custom("Poppins-SemiBold", size: 13, relativeTo: .caption))
                .foregroundStyle(QuizTheme.inkSecondary)

                if showingHint, !hint.isEmpty {
                    Label(hint, systemImage: "lightbulb.fill")
                        .font(.custom("Poppins-Regular", size: 14, relativeTo: .subheadline))
                        .foregroundStyle(QuizTheme.ink)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(QuizTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(QuizTheme.border, lineWidth: 1))
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
    }
}

private struct QuizResultsView: View {
    let deckID: UUID
    let appearanceSeed: Int64?
    let deckName: String
    let score: Int
    let correctCount: Int
    let totalCount: Int
    let onRestart: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(QuizTheme.ink)
                        .frame(width: 24, height: 24)
                        .padding(6)
                        .background(QuizTheme.surface, in: Circle())
                        .overlay(Circle().stroke(QuizTheme.border, lineWidth: 1))
                }
                .frame(width: 44, height: 44)
                .buttonStyle(.plain)
                .accessibilityLabel("Close results")
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            Spacer(minLength: 20)

            DeckCreatureView(
                stableID: deckID,
                appearanceSeed: appearanceSeed,
                cardCount: totalCount,
                isCelebrating: true
            )
            .frame(width: 154, height: 138)

            Text("Results of \(deckName)")
                .font(.custom("Poppins-SemiBold", size: 22, relativeTo: .title2))
                .foregroundStyle(QuizTheme.ink)
                .multilineTextAlignment(.center)
                .padding(.top, 18)

            QuizResultsCard(score: score, correctCount: correctCount, totalCount: totalCount)
                .padding(.horizontal, 20)
                .padding(.top, 52)

            Spacer()

            VStack(spacing: 12) {
                Button("KEEP PRACTICING / CYCLE DECK", action: onRestart)
                    .buttonStyle(QuizActionButtonStyle())

                Button("FINISH", action: onClose)
                    .font(.custom("Poppins-SemiBold", size: 15, relativeTo: .body))
                    .foregroundStyle(QuizTheme.inkSecondary)
                    .padding(.vertical, 8)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
    }
}

private struct QuizResultsCard: View {
    let score: Int
    let correctCount: Int
    let totalCount: Int

    var body: some View {
        VStack(spacing: 0) {
            QuizResultRow(icon: "star.fill", title: "SCORE GAINED", value: "\(score)")
            Divider().opacity(0.4)
            QuizResultRow(
                icon: "checkmark",
                title: "CORRECT ANSWERS",
                value: "\(correctCount)/\(totalCount)"
            )
        }
        .background(QuizTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(QuizTheme.border, lineWidth: 1))
    }
}

private struct QuizResultRow: View {
    let icon: String
    let title: LocalizedStringKey
    let value: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(QuizTheme.green)
                .frame(width: 36, height: 36)
                .background(QuizTheme.canvas, in: Circle())
            Text(title)
                .font(.custom("Poppins-Regular", size: 16, relativeTo: .body))
                .foregroundStyle(QuizTheme.ink)
            Spacer()
            Text(value)
                .font(.custom("Poppins-SemiBold", size: 16, relativeTo: .body))
                .foregroundStyle(QuizTheme.ink)
                .monospacedDigit()
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 72)
    }
}

private struct QuizEmptyState: View {
    let onClose: () -> Void

    var body: some View {
        ContentUnavailableView(
            "No Cards Yet",
            systemImage: "rectangle.stack.badge.plus",
            description: Text("Add cards before starting a study session.")
        )
        .foregroundStyle(QuizTheme.ink)
        .safeAreaInset(edge: .bottom) {
            Button("CLOSE", action: onClose)
                .buttonStyle(QuizActionButtonStyle())
                .padding(20)
        }
    }
}

private struct QuizActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("Poppins-SemiBold", size: 16, relativeTo: .body))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(isEnabled ? QuizTheme.green : Color.gray.opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(configuration.isPressed ? 0.78 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

private struct QuizChoiceButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("Poppins-SemiBold", size: 14, relativeTo: .subheadline))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(color.opacity(configuration.isPressed ? 0.72 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private enum QuizTheme {
    static let canvas = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.08, green: 0.09, blue: 0.14, alpha: 1.0)
            : UIColor(red: 0.929, green: 0.910, blue: 0.890, alpha: 1.0)
    })

    static let surface = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.14, green: 0.16, blue: 0.23, alpha: 1.0)
            : UIColor(red: 0.957, green: 0.953, blue: 0.965, alpha: 1.0)
    })

    static let ink = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.94, green: 0.95, blue: 0.98, alpha: 1.0)
            : UIColor(red: 0.098, green: 0.114, blue: 0.388, alpha: 1.0)
    })

    static let inkSecondary = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.62, green: 0.65, blue: 0.74, alpha: 1.0)
            : UIColor(red: 0.45, green: 0.47, blue: 0.58, alpha: 1.0)
    })

    static let green = Color(red: 0.192, green: 0.804, blue: 0.388)

    static let selected = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.16, green: 0.52, blue: 0.34, alpha: 1.0)
            : UIColor(red: 0.271, green: 0.769, blue: 0.525, alpha: 1.0)
    })

    static let border = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 1.0, alpha: 0.08)
            : UIColor(white: 0.0, alpha: 0.04)
    })
}
