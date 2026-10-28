import SwiftUI
import SwiftData

struct DeckStudyView: View {
    @Bindable var deck: Deck
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var practiceSessions = PracticeSessionStore()
    @StateObject private var ankiCache = AnkiStudyRenderCache()
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(AnkiStudyPresentation.storageKey, store: UserDefaults(suiteName: "group.com.learnalert.shared"))
    private var ankiPresentationRaw = AnkiStudyPresentation.revealBelow.rawValue
    @State private var studyQueue: [Flashcard] = []
    @State private var queueIDs: [UUID] = []
    @State private var allCards: [Flashcard] = []
    @State private var shortReviews = AnkiSessionReviewQueue()
    @State private var localAnkiStates: [UUID: Data] = [:]
    @State private var waitingForReview = false
    @State private var ratingCounts: [AnkiReviewRating: Int] = [:]
    @State private var reviewedAnkiIDs: Set<UUID> = []
    @State private var reviewedCardIDs: Set<UUID> = []
    @State private var answerCount = 0
    @State private var reviewError: String?
    @State private var cardIndex = 0
    @State private var selectedAnswer: String?
    @State private var typedAnswer = ""
    @State private var isRevealed = false
    @State private var hasViewedImageBack = false
    @State private var isGraded = false
    @State private var correctCount = 0
    @State private var showingHint = false
    @State private var hasRecordedHint = false
    @State private var didApplyInitialState = false
    @State private var loadingFailed = false
    @State private var choosingSession = false
    @State private var activeSession: PracticeSessionSnapshot?
    @State private var isComplete = false

    let initialCardId: UUID?
    let initialSelectedAnswer: String?
    let initialWasCorrect: Bool?
    let initialWasGraded: Bool
    let initialHintVisible: Bool
    let initialWasRevealed: Bool
    let initialImageBackViewed: Bool
    let notificationRequestID: String?

    init(deck: Deck, initialCardId: UUID? = nil, initialSelectedAnswer: String? = nil,
         initialWasCorrect: Bool? = nil, initialWasGraded: Bool = false,
         initialHintVisible: Bool = false, initialWasRevealed: Bool = false,
         initialImageBackViewed: Bool = false, notificationRequestID: String? = nil) {
        self.deck = deck; self.initialCardId = initialCardId
        self.initialSelectedAnswer = initialSelectedAnswer; self.initialWasCorrect = initialWasCorrect
        self.initialWasGraded = initialWasGraded; self.initialHintVisible = initialHintVisible
        self.initialWasRevealed = initialWasRevealed; self.initialImageBackViewed = initialImageBackViewed
        self.notificationRequestID = notificationRequestID
    }

    private var currentCard: Flashcard? { studyQueue.indices.contains(cardIndex) ? studyQueue[cardIndex] : nil }
    private var ankiPresentation: AnkiStudyPresentation { AnkiStudyPresentation(rawValue: ankiPresentationRaw) ?? .revealBelow }
    private var isAnkiOnly: Bool { !allCards.isEmpty && allCards.allSatisfy { $0.cardType == .anki } }
    private var nextAnkiReview: Date? {
        allCards.filter { $0.cardType == .anki }.map(\.ankiPracticeReviewState)
            .filter { $0.reviewCount > 0 }.map(\.dueDate).min()
    }
    private var resumableSessions: [PracticeSessionSnapshot] {
        let ids = Set(allCards.map(\.id))
        return practiceSessions.sessions.filter { $0.originalCardIDs.contains(where: ids.contains) }
    }

    var body: some View {
        ZStack {
            QuizTheme.canvas.ignoresSafeArea()
            if loadingFailed {
                ContentUnavailableView {
                    Label("Practice sessions unavailable", systemImage: "externaldrive.badge.exclamationmark")
                } description: {
                    Text("Your saved sessions couldn’t be opened. Try again to keep that progress safe.")
                } actions: {
                    Button("Try again") { Task { await preparePractice() } }
                    Button("Close", action: closePractice)
                }
            } else if !didApplyInitialState {
                ProgressView("Loading deck…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if allCards.isEmpty {
                QuizEmptyState(onClose: closePractice)
            } else if choosingSession {
                PracticeSessionPicker(deckName: deck.name, sessions: resumableSessions,
                    onResume: resume, onNew: { startNewSession() }, onClose: closePractice)
            } else if isComplete {
                if isAnkiOnly {
                    AnkiStudySummaryView(counts: ratingCounts, cardCount: reviewedAnkiIDs.count,
                        nextReview: nextAnkiReview, onClose: closePractice)
                } else {
                    QuizResultsView(deckID: deck.id, appearanceSeed: deck.appearanceSeed, colorHex: deck.colorHex,
                        deckName: deck.name, score: correctCount * 30, correctCount: correctCount,
                        totalCount: max(answerCount, reviewedCardIDs.count),
                        isReviewOnly: allCards.allSatisfy { $0.cardType.isReviewOnly },
                        onRestart: { startNewSession() }, onClose: closePractice)
                }
            } else if waitingForReview, let date = shortReviews.nextDate {
                AnkiLearningWaitView(nextReview: date, onReady: { resumeLearning() },
                    onReviewEarly: { resumeLearning(early: true) }, onFinish: closePractice)
            } else if let card = currentCard {
                QuizSessionView(deckName: deck.name, question: card.studyQuestion, cardType: card.cardType,
                    options: card.options, matchingLeftItems: card.matchingLeftItems, matchingRightItems: card.matchingRightItems,
                    correctAnswer: card.correctAnswer, hint: card.hint, promptImageName: card.promptImageName,
                    answerImageName: card.answerImageName, optionImageNames: card.optionImageNames,
                    promptAudioName: card.promptAudioName, readingPrompt: card.readingPrompt,
                    ankiContent: card.ankiContent, ankiRenderer: card.cardType == .anki ? ankiCache.renderer(for: card.id) : nil,
                    ankiReviewOptions: card.cardType == .anki ? AnkiReviewScheduling.options(for: localState(for: card), at: Date()) : [],
                    ankiPresentation: ankiPresentation, fieldMedia: card.fieldMedia, correctOptionIndex: card.resolvedCorrectOptionIndex,
                    cardNumber: min(allCards.count, reviewedCardIDs.count + (reviewedCardIDs.contains(card.id) ? 0 : 1)),
                    cardCount: allCards.count, correctCount: correctCount, selectedAnswer: selectedAnswer,
                    typedAnswer: $typedAnswer, isRevealed: $isRevealed, hasViewedImageBack: hasViewedImageBack, isGraded: isGraded,
                    showingHint: showingHint, onSelect: { selectOption($0, for: card) },
                    onReveal: { withAnimation(.snappy) { isRevealed = true }; checkpoint() },
                    onImageBackViewed: { hasViewedImageBack = true; checkpoint() },
                    onGrade: { grade(card, isCorrect: $0) }, onAnkiGrade: { rateAnki(card, rating: $0) },
                    onToggleHint: toggleHint, onSkip: { skip(card) }, onContinue: { submitAndAdvance(card) }, onClose: closePractice)
                    .id(card.id)
                    .task(id: "\(card.id)-\(colorScheme)-\(ankiPresentationRaw)") { prefetchAnki() }
            } else {
                ProgressView("Loading deck…").frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await Task.yield(); await preparePractice() }
        .onDisappear { checkpoint(immediately: true); ankiCache.clear() }
        .onChange(of: scenePhase) { _, phase in if phase != .active { checkpoint(immediately: true) } }
        .onChange(of: isRevealed) { _, _ in checkpoint() }
        .onChange(of: typedAnswer) { _, _ in checkpoint() }
        .onChange(of: practiceSessions.errorMessage) { _, message in if let message { reviewError = message } }
        .alert("Practice progress", isPresented: Binding(get: { reviewError != nil }, set: { if !$0 { reviewError = nil } })) {
            Button("OK") { reviewError = nil }
        } message: { Text(reviewError ?? "Please try again.") }
    }

    private func preparePractice() async {
        guard !didApplyInitialState || loadingFailed else { return }
        allCards = deck.cards
        guard await practiceSessions.load(deckID: deck.id), !Task.isCancelled else { loadingFailed = true; return }
        do { try migratePracticeStates() }
        catch {
            loadingFailed = true
            reviewError = "Your previous Anki practice couldn’t be saved. Try again before starting a new session."
            return
        }
        loadingFailed = false; didApplyInitialState = true
        if initialCardId != nil || notificationRequestID != nil { startNewSession(applyHandoff: true) }
        else if !resumableSessions.isEmpty { choosingSession = true }
        else { startNewSession() }
    }

    private func migratePracticeStates() throws {
        let legacy = practiceSessions.legacyAnkiStates()
        var changed = false
        do {
            for card in allCards where card.cardType == .anki && card.ankiPracticeReviewStateData == nil {
                guard let data = legacy[card.id] else { continue }
                card.ankiPracticeReviewStateData = data
                changed = true
            }
            if changed { try context.save() }
        } catch {
            context.rollback()
            throw error
        }
    }

    private func startNewSession(applyHandoff: Bool = false) {
        ankiCache.clear()
        allCards = deck.cards.sorted {
            $0.orderIndex == $1.orderIndex ? $0.id.uuidString < $1.id.uuidString : $0.orderIndex < $1.orderIndex
        }
        let now = Date()
        let entries = allCards.map { (card: $0, state: $0.cardType == .anki ? $0.ankiPracticeReviewState : nil) }
        studyQueue = entries.filter { $0.state.map { $0.reviewCount == 0 || $0.dueDate <= now } ?? true }
            .sorted { first, second in
                func rank(_ state: AnkiReviewState?) -> Int {
                    guard let state, state.reviewCount > 0 else { return 2 }
                    return state.phase == .review ? 1 : 0
                }
                let firstRank = rank(first.state), secondRank = rank(second.state)
                if firstRank != secondRank { return firstRank < secondRank }
                if firstRank < 2, let firstDate = first.state?.dueDate, let secondDate = second.state?.dueDate,
                   firstDate != secondDate { return firstDate < secondDate }
                if first.card.orderIndex != second.card.orderIndex { return first.card.orderIndex < second.card.orderIndex }
                return first.card.id.uuidString < second.card.id.uuidString
            }.map(\.card)
        queueIDs = studyQueue.map(\.id)
        shortReviews = .init()
        localAnkiStates = Dictionary(uniqueKeysWithValues: allCards.compactMap { card in
            card.ankiPracticeReviewStateData.map { (card.id, $0) }
        })
        for entry in entries {
            if let state = entry.state, state.reviewCount > 0, state.phase != .review, state.dueDate > now {
                shortReviews.schedule(entry.card.id, due: state.dueDate, repeatsInSession: true)
            }
        }
        ratingCounts = [:]; reviewedAnkiIDs = []; reviewedCardIDs = []
        answerCount = 0; correctCount = 0; cardIndex = studyQueue.isEmpty ? -1 : 0; resetCardState()
        waitingForReview = studyQueue.isEmpty && shortReviews.nextDate != nil
        isComplete = studyQueue.isEmpty && !waitingForReview
        choosingSession = false
        activeSession = PracticeSessionSnapshot(deckID: deck.id, createdAt: now, updatedAt: now,
            originalCardIDs: allCards.map(\.id), queueIDs: queueIDs)
        if applyHandoff, let id = initialCardId, let card = allCards.first(where: { $0.id == id }) {
            studyQueue.removeAll { $0.id == id }; studyQueue.insert(card, at: 0)
            queueIDs.removeAll { $0 == id }; queueIDs.insert(id, at: 0)
            cardIndex = 0; waitingForReview = false; isComplete = false
            selectedAnswer = initialSelectedAnswer; isGraded = initialWasGraded
            isRevealed = initialWasRevealed || (initialWasGraded && initialSelectedAnswer == nil)
            hasViewedImageBack = initialImageBackViewed || initialWasRevealed || initialWasGraded
            showingHint = initialHintVisible; hasRecordedHint = initialHintVisible
            if initialWasGraded {
                // Acknowledging a notification never replays its rating into practice history.
                reviewedCardIDs.insert(id); answerCount = 1
                correctCount = initialWasCorrect == true ? 1 : 0
                if card.cardType == .anki { reviewedAnkiIDs.insert(id) }
            }
        }
        checkpoint(immediately: true)
    }

    private func resume(_ saved: PracticeSessionSnapshot) {
        ankiCache.clear()
        let lookup = Dictionary(deck.cards.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let validIDs = Set(lookup.keys)
        let savedIndex = min(max(0, saved.cardIndex), saved.queueIDs.count)
        let index = saved.isComplete ? saved.queueIDs.count
            : saved.waitingForReview && saved.isGraded ? min(savedIndex + 1, saved.queueIDs.count) : savedIndex
        let savedCurrentID = saved.queueIDs.indices.contains(index) ? saved.queueIDs[index] : nil
        let prefix = saved.queueIDs.prefix(index).compactMap { lookup[$0] }
        let now = Date()
        var queuedAnkiIDs = Set<UUID>()
        var remaining: [Flashcard] = []
        shortReviews = .init()
        allCards = saved.originalCardIDs.compactMap { lookup[$0] }
        // The bookmark supplies position; the card supplies the latest learning state.
        // A newer session's ratings cannot be rewound by opening an older bookmark.
        for id in saved.queueIDs.dropFirst(index) {
            guard let card = lookup[id] else { continue }
            guard card.cardType == .anki else { remaining.append(card); continue }
            guard queuedAnkiIDs.insert(id).inserted else { continue }
            let state = card.ankiPracticeReviewState
            if (id == savedCurrentID && saved.isGraded) || state.reviewCount == 0 || state.dueDate <= now {
                remaining.append(card)
            }
        }
        let remainingIDs = Set(remaining.map(\.id))
        var newlyDue: [(card: Flashcard, state: AnkiReviewState)] = []
        for card in allCards where card.cardType == .anki && !saved.isComplete {
            let state = card.ankiPracticeReviewState
            guard state.reviewCount > 0 else { continue }
            if !remainingIDs.contains(card.id) && state.dueDate <= now {
                newlyDue.append((card, state))
            } else if state.phase != .review && state.dueDate > now {
                shortReviews.schedule(card.id, due: state.dueDate, repeatsInSession: true)
            }
        }
        // Keep the bookmarked card on screen; newly due reviews follow it.
        let reviewInsertionIndex = savedCurrentID != nil && remaining.first?.id == savedCurrentID ? 1 : 0
        remaining.insert(contentsOf: newlyDue.sorted { first, second in
            if (first.state.phase == .review) != (second.state.phase == .review) { return first.state.phase != .review }
            if first.state.dueDate != second.state.dueDate { return first.state.dueDate < second.state.dueDate }
            return first.card.orderIndex == second.card.orderIndex ? first.card.id.uuidString < second.card.id.uuidString
                : first.card.orderIndex < second.card.orderIndex
        }.map(\.card), at: reviewInsertionIndex)
        studyQueue = prefix + remaining
        queueIDs = studyQueue.map(\.id)
        cardIndex = remaining.isEmpty ? max(-1, studyQueue.count - 1) : prefix.count
        reviewedCardIDs = saved.reviewedCardIDs.intersection(validIDs)
        reviewedAnkiIDs = saved.reviewedAnkiIDs.intersection(validIDs)
        correctCount = saved.correctCount; answerCount = saved.answerCount
        selectedAnswer = saved.selectedAnswer; isRevealed = saved.isRevealed
        typedAnswer = saved.typedAnswer
        hasViewedImageBack = saved.hasViewedImageBack; isGraded = saved.isGraded
        showingHint = saved.showingHint; hasRecordedHint = saved.hasRecordedHint
        localAnkiStates = Dictionary(uniqueKeysWithValues: allCards.compactMap { card in
            card.ankiPracticeReviewStateData.map { (card.id, $0) }
        })
        ratingCounts = Dictionary(saved.ratingCounts.compactMap { key, value in AnkiReviewRating(rawValue: key).map { ($0, value) } }, uniquingKeysWith: +)
        if savedCurrentID != currentCard?.id { resetCardState() }
        if saved.isComplete {
            waitingForReview = false; isComplete = true
        } else {
            waitingForReview = remaining.isEmpty && shortReviews.nextDate != nil
            isComplete = remaining.isEmpty && !waitingForReview
        }
        activeSession = saved
        activeSession?.originalCardIDs = allCards.map(\.id)
        choosingSession = false
        checkpoint(immediately: true)
    }

    private func checkpoint(immediately: Bool = false) {
        guard !choosingSession, !loadingFailed, var session = activeSession else { return }
        session.updatedAt = Date()
        session.queueIDs = queueIDs; session.cardIndex = cardIndex
        session.reviewedCardIDs = reviewedCardIDs; session.answerCount = answerCount; session.correctCount = correctCount
        session.selectedAnswer = selectedAnswer; session.isRevealed = isRevealed
        session.typedAnswer = typedAnswer
        session.hasViewedImageBack = hasViewedImageBack; session.isGraded = isGraded
        session.showingHint = showingHint; session.hasRecordedHint = hasRecordedHint
        session.waitingForReview = waitingForReview; session.isComplete = isComplete
        session.localAnkiStates = localAnkiStates; session.pendingAnkiReviews = shortReviews.pending
        session.ratingCounts = Dictionary(uniqueKeysWithValues: ratingCounts.map { ($0.key.rawValue, $0.value) })
        session.reviewedAnkiIDs = reviewedAnkiIDs
        activeSession = session
        practiceSessions.save(session, immediately: immediately)
    }

    private func closePractice() { checkpoint(immediately: true); dismiss() }
    private func localState(for card: Flashcard) -> AnkiReviewState {
        card.ankiPracticeReviewState
    }

    private func prefetchAnki() {
        guard let card = currentCard, let content = card.ankiContent else { ankiCache.clear(); return }
        let next: (UUID, AnkiCardContent)?
        if studyQueue.indices.contains(cardIndex + 1), let content = studyQueue[cardIndex + 1].ankiContent {
            next = (studyQueue[cardIndex + 1].id, content)
        } else { next = nil }
        ankiCache.prepare(current: (card.id, content, isRevealed), next: next,
            configuration: .init(dark: colorScheme == .dark, reduceMotion: reduceMotion, presentation: ankiPresentation))
    }

    private func selectOption(_ option: String, for card: Flashcard) {
        guard !isGraded && selectedAnswer == nil else { return }
        selectedAnswer = option
        grade(card, isCorrect: CardChoiceIdentity.index(option, options: card.options) == card.resolvedCorrectOptionIndex)
    }
    private func toggleHint() {
        hasRecordedHint = true
        withAnimation(.snappy) { showingHint.toggle() }
        checkpoint()
    }
    private func skip(_ card: Flashcard) {
        InteractionSoundPlayer.shared.play(.skip)
        requeue(card); advance()
    }
    private func requeue(_ card: Flashcard) {
        let remaining = studyQueue.dropFirst(min(cardIndex + 1, studyQueue.count))
        if !remaining.contains(where: { $0.id == card.id }) {
            let index = min(cardIndex + 3, studyQueue.count)
            studyQueue.insert(card, at: index); queueIDs.insert(card.id, at: index)
        }
    }
    private func recordPracticeAnswer(_ card: Flashcard, correct: Bool) {
        reviewedCardIDs.insert(card.id); answerCount += 1
        if correct { correctCount += 1 }
    }
    private func grade(_ card: Flashcard, isCorrect: Bool) {
        guard !isGraded else { return }
        InteractionSoundPlayer.shared.play(isCorrect ? .correct : .incorrect)
        recordPracticeAnswer(card, correct: isCorrect)
        if !isCorrect { requeue(card) }
        isGraded = true
        checkpoint()
    }
    private func rateAnki(_ card: Flashcard, rating: AnkiReviewRating) {
        guard card.cardType == .anki, isRevealed, !isGraded else { return }
        let option: AnkiReviewOption
        do {
            option = try card.recordAnkiPracticeReview(rating: rating)
            try context.save()
        } catch {
            context.rollback()
            reviewError = "Your Anki rating couldn’t be saved. Please try that rating again."
            return
        }
        localAnkiStates[card.id] = card.ankiPracticeReviewStateData
        shortReviews.schedule(card.id, due: option.nextReviewDate, repeatsInSession: option.shouldRepeatInSession)
        ratingCounts[rating, default: 0] += 1; reviewedAnkiIDs.insert(card.id)
        recordPracticeAnswer(card, correct: rating.wasCorrect)
        InteractionSoundPlayer.shared.play(rating.wasCorrect ? .correct : .incorrect)
        isGraded = true
        checkpoint(); advance()
    }
    private func submitAndAdvance(_ card: Flashcard) {
        guard card.cardType != .images || CardImageStore.loadImage(named: card.promptImageName) != nil else { return }
        if card.cardType == .images, let back = card.answerImageName, !back.isEmpty {
            guard hasViewedImageBack, CardImageStore.loadImage(named: back) != nil else { return }
        }
        if card.cardType.isReviewOnly {
            if !isGraded { recordPracticeAnswer(card, correct: true); isGraded = true; checkpoint() }
            advance(); return
        }
        guard isGraded else { return }
        advance()
    }
    private func resetCardState() {
        selectedAnswer = nil; isRevealed = false; hasViewedImageBack = false
        typedAnswer = ""
        isGraded = false; showingHint = false; hasRecordedHint = false
    }
    private func advance() {
        enqueueReadyReviews()
        guard cardIndex + 1 < studyQueue.count else {
            withAnimation(.snappy) { waitingForReview = shortReviews.nextDate != nil; isComplete = !waitingForReview }
            checkpoint(immediately: true); return
        }
        withAnimation(.snappy) { cardIndex += 1; resetCardState() }
        checkpoint()
    }
    private func enqueueReadyReviews(early: Bool = false) {
        let ids = shortReviews.takeReady(at: Date(), reviewEarly: early)
        guard !ids.isEmpty else { return }
        let lookup = Dictionary(allCards.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let cards = ids.compactMap { lookup[$0] }
        let index = min(cardIndex + 1, studyQueue.count)
        // A due repeat replaces any later copy rather than appearing twice.
        let readyIDs = Set(cards.map(\.id))
        let earlier = Array(studyQueue.prefix(index))
        let later = studyQueue.dropFirst(index).filter { !readyIDs.contains($0.id) }
        studyQueue = earlier + later
        queueIDs = studyQueue.map(\.id)
        studyQueue.insert(contentsOf: cards, at: index); queueIDs.insert(contentsOf: cards.map(\.id), at: index)
    }
    private func resumeLearning(early: Bool = false) {
        guard waitingForReview else { return }
        let oldCount = studyQueue.count
        enqueueReadyReviews(early: early)
        guard studyQueue.count > oldCount else { return }
        waitingForReview = false
        // Ready cards were inserted after the currently completed card.
        advance()
    }
}

private struct PracticeSessionPicker: View {
    let deckName: String
    let sessions: [PracticeSessionSnapshot]
    let onResume: (PracticeSessionSnapshot) -> Void
    let onNew: () -> Void
    let onClose: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text(deckName).font(.title2.bold()).foregroundStyle(QuizTheme.ink)
                    Spacer()
                    Button(action: onClose) { Image(systemName: "xmark").frame(width: 44, height: 44) }
                        .accessibilityLabel("Close practice")
                }
                Text("Your practice sessions").font(.headline).foregroundStyle(QuizTheme.ink)
                Text("Pick up where you left off. Practice stays separate from notification learning.")
                    .font(.subheadline).foregroundStyle(QuizTheme.inkSecondary)
                ForEach(sessions) { session in
                    Button { onResume(session) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: session.isComplete ? "checkmark.circle" : "play.circle.fill")
                                .font(.title2).foregroundStyle(QuizTheme.green)
                            VStack(alignment: .leading, spacing: 5) {
                                Text("\(session.reviewedCount)/\(session.totalCount) reviewed")
                                    .font(.headline).foregroundStyle(QuizTheme.ink)
                                Text(session.updatedAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                                    .font(.caption).foregroundStyle(QuizTheme.inkSecondary)
                            }
                            Spacer(minLength: 8)
                            Text(session.isComplete ? "Results" : "Resume")
                                .font(.subheadline.weight(.semibold)).foregroundStyle(QuizTheme.ink)
                        }
                        .padding(16).background(QuizTheme.surface, in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(QuizTheme.border, lineWidth: 1))
                    }.buttonStyle(.plain)
                }
                Button("Start a new session", action: onNew).buttonStyle(QuizActionButtonStyle())
                    .padding(.top, 4)
            }.padding(20).frame(maxWidth: 640).frame(maxWidth: .infinity)
        }
    }
}

private struct AnkiLearningWaitView: View {
    let nextReview: Date
    let onReady: () -> Void
    let onReviewEarly: () -> Void
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 52, weight: .light)).foregroundStyle(.blue)
                .symbolEffect(.pulse)
            Text("A little breathing room")
                .font(.title2.bold()).foregroundStyle(QuizTheme.ink)
            VStack(spacing: 8) {
                Text("Your next learning card is ready in")
                Text(timerInterval: Date()...max(Date(), nextReview), countsDown: true)
                    .font(.title.monospacedDigit().weight(.semibold)).foregroundStyle(QuizTheme.ink)
            }.foregroundStyle(QuizTheme.inkSecondary)
            Text("You can leave now. Your review time is saved.")
                .font(.subheadline).foregroundStyle(QuizTheme.inkSecondary)
                .multilineTextAlignment(.center)
            Spacer()
            Button("Done for now", action: onFinish).buttonStyle(QuizActionButtonStyle())
            Button("Review early", action: onReviewEarly)
                .font(.subheadline.weight(.semibold)).padding(.bottom, 16)
        }
        .padding(28)
        .task(id: nextReview) {
            do { try await Task.sleep(for: .seconds(max(0, nextReview.timeIntervalSinceNow))) }
            catch { return }
            guard !Task.isCancelled else { return }
            onReady()
        }
    }
}

private struct AnkiStudySummaryView: View {
    let counts: [AnkiReviewRating: Int]
    let cardCount: Int
    let nextReview: Date?
    let onClose: () -> Void

    private var reviews: Int { counts.values.reduce(0, +) }
    var body: some View {
        VStack(spacing: 26) {
            Spacer()
            Image(systemName: "checkmark.rectangle.stack.fill")
                .font(.system(size: 58, weight: .light)).foregroundStyle(.teal)
            Text(reviews == 0 ? "You're caught up" : "Nice work today")
                .font(.title2.bold()).foregroundStyle(QuizTheme.ink)
            if reviews > 0 {
                Text("\(reviews) reviews · \(cardCount) cards")
                    .font(.subheadline).foregroundStyle(QuizTheme.inkSecondary)
                HStack(spacing: 8) {
                    ForEach(AnkiReviewRating.allCases) { rating in
                        VStack(spacing: 6) {
                            Text("\(counts[rating, default: 0])").font(.title2.bold().monospacedDigit())
                            Text(rating.title).font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(rating.reviewTint)
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(rating.reviewTint.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
            if let date = nextReview {
                VStack(spacing: 6) {
                    Text("Next review").font(.caption).foregroundStyle(QuizTheme.inkSecondary)
                    Text(date, style: .relative).font(.headline).foregroundStyle(QuizTheme.ink)
                }
            }
            Spacer()
            Button("Done", action: onClose).buttonStyle(QuizActionButtonStyle())
        }.padding(28)
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
    var promptImageName: String? = nil
    var answerImageName: String? = nil
    var optionImageNames: [String] = []
    var promptAudioName: String? = nil
    var readingPrompt: String? = nil
    var ankiContent: AnkiCardContent? = nil
    var ankiRenderer: AnkiCardRenderer? = nil
    var ankiReviewOptions: [AnkiReviewOption] = []
    var ankiPresentation: AnkiStudyPresentation = .revealBelow
    @State private var ankiIsLoading = true
    var fieldMedia: [String: CardFieldMedia] = [:]
    var correctOptionIndex: Int? = nil
    let cardNumber: Int
    let cardCount: Int
    let correctCount: Int
    let selectedAnswer: String?
    @Binding var typedAnswer: String
    @Binding var isRevealed: Bool
    let hasViewedImageBack: Bool
    let isGraded: Bool
    let showingHint: Bool
    let onSelect: (String) -> Void
    let onReveal: () -> Void
    let onImageBackViewed: () -> Void
    let onGrade: (Bool) -> Void
    let onAnkiGrade: (AnkiReviewRating) -> Void
    let onToggleHint: () -> Void
    let onSkip: () -> Void
    let onContinue: () -> Void
    let onClose: () -> Void

    private var canContinue: Bool {
        if cardType == .images {
            guard CardImageStore.loadImage(named: promptImageName) != nil else { return false }
            return !hasImageBack || (hasViewedImageBack && CardImageStore.loadImage(named: answerImageName) != nil)
        }
        return cardType.isReviewOnly || isGraded
    }
    private var hasImageBack: Bool { answerImageName?.isEmpty == false }
    private var actionTitle: LocalizedStringKey {
        if cardType == .images { return "REVIEWED" }
        return cardNumber >= cardCount ? "FINISH" : "CONTINUE"
    }

    var body: some View {
        VStack(spacing: 0) {
            QuizHeader(deckName: deckName, correctCount: correctCount, onClose: onClose)
                .padding(.horizontal, 20)
                .padding(.top, 8)

            QuizProgress(cardNumber: cardNumber, cardCount: cardCount)
                .padding(.horizontal, 20)
                .padding(.top, 16)

            if cardType == .anki, let ankiContent {
                VStack(spacing: 16) {
                    AnkiStudyCardView(content: ankiContent, showingBack: $isRevealed, centered: true,
                        renderer: ankiRenderer, isEnabled: !isGraded, loadingChanged: { ankiIsLoading = $0 })
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    AnkiReviewControls(isRevealed: isRevealed, isGraded: isGraded, options: ankiReviewOptions,
                        tapToFlip: ankiPresentation == .tapToFlip,
                        onReveal: onReveal, onGrade: onAnkiGrade)
                        .disabled(ankiIsLoading)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 16)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if cardType == .anki {
                            ContentUnavailableView("Card unavailable", systemImage: "rectangle.slash", description: Text("Re-import this Anki deck to restore its content."))
                        } else if cardType == .images {
                            Group {
                                if hasImageBack {
                                    ImageCardFlipView(isShowingBack: $isRevealed,
                                        onBackViewed: {
                                            if CardImageStore.loadImage(named: answerImageName) != nil { onImageBackViewed() }
                                        }) {
                                        imageFace(promptImageName)
                                    } back: {
                                        imageFace(answerImageName)
                                    }
                                } else {
                                    imageFace(promptImageName)
                                }
                            }
                            .frame(maxWidth: .infinity).frame(height: 420)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        } else if let promptImg = promptImageName, !promptImg.isEmpty,
                           let uiImage = CardImageStore.loadImage(named: promptImg) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(QuizTheme.border, lineWidth: 1)
                                )
                                .frame(maxWidth: .infinity, alignment: .center)
                        }

                        if cardType != .images && cardType != .anki && !(cardType == .fillBlank && !options.isEmpty) && !question.isEmpty {
                            CardQuestionContent(question: question, readingPrompt: readingPrompt, media: .init(audio: promptAudioName))
                                .font(.custom("Poppins-SemiBold", size: 22, relativeTo: .title2))
                                .foregroundStyle(QuizTheme.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if let promptAudioName, cardType == .images || question.isEmpty || (cardType == .fillBlank && !options.isEmpty) {
                            CardAudioPlaybackButton(name: promptAudioName)
                        }

                        switch cardType {
                        case .images, .anki:
                            EmptyView()
                        case .vocabulary:
                            CardFieldContent(text: correctAnswer, media: fieldMedia["answer"] ?? .init()).font(.title3.weight(.semibold))
                        case .multipleChoice:
                            CardMediaChoiceList(options: options, fields: fieldMedia, correctIndex: correctOptionIndex,
                                selection: selectedAnswer, isGraded: isGraded, onSelect: onSelect)
                        case .tapReveal:
                            QuizRevealCard(
                                answer: correctAnswer,
                                media: fieldMedia["answer"] ?? .init(),
                                isRevealed: isRevealed,
                                isGraded: isGraded,
                                onReveal: onReveal,
                                onGrade: onGrade
                            )
                        case .fillBlank:
                            if !options.isEmpty {
                                CardBlankChoicePanel(prompt: question, options: options, answerIndex: correctOptionIndex ?? options.firstIndex(of: correctAnswer), fields: fieldMedia, isGraded: isGraded, onGrade: onGrade)
                            } else if correctAnswer.isEmpty {
                                QuizRevealCard(answer: "", media: fieldMedia["answer"] ?? .init(), isRevealed: isRevealed, isGraded: isGraded, onReveal: onReveal, onGrade: onGrade)
                            } else {
                                QuizFillBlankCard(answer: correctAnswer, isGraded: isGraded, onGrade: onGrade, response: $typedAnswer)
                                if isGraded { CardFieldContent(media: fieldMedia["answer"] ?? .init()) }
                            }
                        case .matching:
                            CardMediaMatchingBoard(left: matchingLeftItems, right: matchingRightItems, fields: fieldMedia, isGraded: isGraded, onGrade: onGrade)
                        }

                        if !cardType.isReviewOnly || (fieldMedia["hint"] ?? .init()).hasContent(hint) {
                            QuizUtilityControls(
                                hint: hint,
                                media: fieldMedia["hint"] ?? .init(),
                                showingHint: showingHint,
                                isGraded: isGraded,
                                onToggleHint: onToggleHint,
                                onSkip: onSkip
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 38)
                    .padding(.bottom, 24)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if cardType != .anki || isGraded {
            Button(actionTitle, action: onContinue)
                .buttonStyle(QuizActionButtonStyle())
                .disabled(!canContinue)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(QuizTheme.canvas)
            }
        }
    }

    @ViewBuilder private func imageFace(_ name: String?) -> some View {
        if let image = CardImageStore.loadImage(named: name) {
            Image(uiImage: image).resizable().scaledToFit()
        } else {
            ContentUnavailableView("Image unavailable", systemImage: "photo",
                description: Text("Open the card editor to upload the picture again."))
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

private struct QuizRevealCard: View {
    let answer: String
    var media = CardFieldMedia()
    let isRevealed: Bool
    let isGraded: Bool
    let onReveal: () -> Void
    let onGrade: (Bool) -> Void

    var body: some View {
        VStack(spacing: 16) {
            if isRevealed {
                CardFieldContent(text: answer, media: media)
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
    @Binding var response: String
    private var wasCorrect: Bool {
        response.trimmingCharacters(in: .whitespacesAndNewlines)
            .localizedCaseInsensitiveCompare(answer.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
    }

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
                    onGrade(correct)
                }
                .buttonStyle(QuizActionButtonStyle())
                .disabled(response.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private var borderColor: Color {
        guard isGraded else { return QuizTheme.border }
        return wasCorrect ? QuizTheme.green : LearnAlertStyle.coral
    }
}

private struct QuizUtilityControls: View {
    let hint: String
    var media = CardFieldMedia()
    let showingHint: Bool
    let isGraded: Bool
    let onToggleHint: () -> Void
    let onSkip: () -> Void

    var body: some View {
        if !isGraded {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    if media.hasContent(hint) {
                        Button(showingHint ? "HIDE HINT" : "HINT", action: onToggleHint)
                    }
                    Button("SKIP", action: onSkip)
                }
                .font(.custom("Poppins-SemiBold", size: 13, relativeTo: .caption))
                .foregroundStyle(QuizTheme.inkSecondary)

                if showingHint, media.hasContent(hint) {
                    CardFieldContent(text: hint, media: media)
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
    let colorHex: String
    let deckName: String
    let score: Int
    let correctCount: Int
    let totalCount: Int
    let isReviewOnly: Bool
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
                isCelebrating: true,
                colorHex: colorHex
            )
            .frame(width: 154, height: 138)

            Text("Results of \(deckName)")
                .font(.custom("Poppins-SemiBold", size: 22, relativeTo: .title2))
                .foregroundStyle(QuizTheme.ink)
                .multilineTextAlignment(.center)
                .padding(.top, 18)

            QuizResultsCard(score: score, correctCount: correctCount, totalCount: totalCount, isReviewOnly: isReviewOnly)
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
    let isReviewOnly: Bool

    var body: some View {
        VStack(spacing: 0) {
            if !isReviewOnly {
                QuizResultRow(icon: "star.fill", title: "SCORE GAINED", value: "\(score)")
                Divider().opacity(0.4)
            }
            QuizResultRow(
                icon: "checkmark",
                title: isReviewOnly ? "CARDS REVIEWED" : "CORRECT ANSWERS",
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
            : LearnAlertStyle.lightBorderColor
    })
}

private struct QuizVocabularyCard: View {
    let definition: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "character.book.closed.fill")
                    .font(.caption.bold())
                    .foregroundStyle(LearnAlertStyle.cyan)
                Text("DEFINITION")
                    .font(.custom("Poppins-Bold", size: 11))
                    .foregroundStyle(LearnAlertStyle.cyan)
            }

            Text(definition)
                .font(.custom("Poppins-Medium", size: 16, relativeTo: .body))
                .foregroundStyle(QuizTheme.ink)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(QuizTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(QuizTheme.border, lineWidth: 1)
        )
    }
}
