import SwiftUI
import SwiftData

struct DeckStudyView: View {
    @Bindable var deck: Deck
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @StateObject private var ankiCache = AnkiStudyRenderCache()
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var studyQueue: [Flashcard] = []
    @State private var allCards: [Flashcard] = []
    @State private var shortReviews = AnkiSessionReviewQueue()
    @State private var waitingForReview = false
    @State private var ratingCounts: [AnkiReviewRating: Int] = [:]
    @State private var reviewedAnkiIDs: Set<UUID> = []
    @State private var reviewError: String?
    @State private var cardIndex = 0
    @State private var selectedAnswer: String?
    @State private var isRevealed = false
    @State private var hasViewedImageBack = false
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
    let initialWasRevealed: Bool
    let initialImageBackViewed: Bool
    let notificationRequestID: String?

    init(
        deck: Deck,
        initialCardId: UUID? = nil,
        initialSelectedAnswer: String? = nil,
        initialWasCorrect: Bool? = nil,
        initialWasGraded: Bool = false,
        initialHintVisible: Bool = false,
        initialWasRevealed: Bool = false,
        initialImageBackViewed: Bool = false,
        notificationRequestID: String? = nil
    ) {
        self.deck = deck
        self.initialCardId = initialCardId
        self.initialSelectedAnswer = initialSelectedAnswer
        self.initialWasCorrect = initialWasCorrect
        self.initialWasGraded = initialWasGraded
        self.initialHintVisible = initialHintVisible
        self.initialWasRevealed = initialWasRevealed
        self.initialImageBackViewed = initialImageBackViewed
        self.notificationRequestID = notificationRequestID
    }

    private var currentCard: Flashcard? {
        studyQueue.indices.contains(cardIndex) ? studyQueue[cardIndex] : nil
    }
    private var isAnkiOnly: Bool { !allCards.isEmpty && allCards.allSatisfy { $0.cardType == .anki } }
    private var nextAnkiReview: Date? {
        allCards.filter { $0.cardType == .anki && !$0.isNew }.map(\.nextReviewDate).min()
    }

    var body: some View {
        ZStack {
            QuizTheme.canvas.ignoresSafeArea()

            if didApplyInitialState && allCards.isEmpty {
                QuizEmptyState(onClose: dismiss.callAsFunction)
            } else if isComplete {
                if isAnkiOnly {
                    AnkiStudySummaryView(counts: ratingCounts, cardCount: reviewedAnkiIDs.count,
                        nextReview: nextAnkiReview, onClose: dismiss.callAsFunction)
                } else {
                    QuizResultsView(
                    deckID: deck.id,
                    appearanceSeed: deck.appearanceSeed,
                    colorHex: deck.colorHex,
                    deckName: deck.name,
                    score: correctCount * 30,
                    correctCount: correctCount,
                    totalCount: allCards.count,
                    isReviewOnly: allCards.allSatisfy { $0.cardType.isReviewOnly },
                    onRestart: restartCycle,
                    onClose: dismiss.callAsFunction
                )
                }
            } else if waitingForReview, let date = shortReviews.nextDate {
                AnkiLearningWaitView(nextReview: date, onReady: { resumeLearning() },
                    onReviewEarly: { resumeLearning(early: true) },
                    onFinish: { isComplete = true })
            } else if let card = currentCard {
                QuizSessionView(
                    deckName: deck.name,
                    question: card.studyQuestion,
                    cardType: card.cardType,
                    options: card.options,
                    matchingLeftItems: card.matchingLeftItems,
                    matchingRightItems: card.matchingRightItems,
                    correctAnswer: card.correctAnswer,
                    hint: card.hint,
                    promptImageName: card.promptImageName,
                    answerImageName: card.answerImageName,
                    optionImageNames: card.optionImageNames,
                    promptAudioName: card.promptAudioName,
                    readingPrompt: card.readingPrompt,
                    ankiContent: card.ankiContent,
                    ankiRenderer: card.cardType == .anki ? ankiCache.renderer(for: card.id) : nil,
                    ankiReviewOptions: card.cardType == .anki ? card.ankiReviewOptions(at: Date()) : [],
                    fieldMedia: card.fieldMedia,
                    correctOptionIndex: card.resolvedCorrectOptionIndex,
                    cardNumber: cardIndex + 1,
                    cardCount: studyQueue.count,
                    correctCount: correctCount,
                    selectedAnswer: selectedAnswer,
                    isRevealed: $isRevealed,
                    hasViewedImageBack: hasViewedImageBack,
                    isGraded: isGraded,
                    showingHint: showingHint,
                    onSelect: { selectOption($0, for: card) },
                    onReveal: { withAnimation(.snappy) { isRevealed = true } },
                    onImageBackViewed: { hasViewedImageBack = true },
                    onGrade: { grade(card, isCorrect: $0) },
                    onAnkiGrade: { rateAnki(card, rating: $0) },
                    onToggleHint: { toggleHint(for: card) },
                    onSkip: { skip(card) },
                    onContinue: { submitAndAdvance(card) },
                    onClose: dismiss.callAsFunction
                )
                .id(card.id)
                .task(id: "\(card.id)-\(colorScheme)") { prefetchAnki() }
            } else {
                ProgressView("Loading deck…").frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await Task.yield(); applyInitialStateIfNeeded() }
        .onDisappear { ankiCache.clear() }
        .alert("Review couldn't be saved", isPresented: Binding(get: { reviewError != nil }, set: { if !$0 { reviewError = nil } })) {
            Button("OK") { reviewError = nil }
        } message: { Text(reviewError ?? "Please try again.") }
    }

    private func prefetchAnki() {
        guard let card = currentCard, let content = card.ankiContent else { ankiCache.clear(); return }
        let next: (UUID, AnkiCardContent)?
        if studyQueue.indices.contains(cardIndex + 1), let content = studyQueue[cardIndex + 1].ankiContent {
            next = (studyQueue[cardIndex + 1].id, content)
        } else { next = nil }
        ankiCache.prepare(current: (card.id, content, isRevealed), next: next,
            configuration: .init(dark: colorScheme == .dark, reduceMotion: reduceMotion))
    }

    private func setupStudyQueue() {
        allCards = deck.cards
        studyQueue = buildSmartStudyQueue()
        let queuedIDs = Set(studyQueue.map(\.id))
        for card in allCards where card.cardType == .anki && !queuedIDs.contains(card.id) {
                let state = card.ankiReviewState
                if state.phase != .review {
                    shortReviews.schedule(card.id, due: state.dueDate, repeatsInSession: true)
                }
        }
        if studyQueue.isEmpty && isAnkiOnly {
            waitingForReview = shortReviews.nextDate != nil
            isComplete = !waitingForReview
        }
    }

    private func buildSmartStudyQueue() -> [Flashcard] {
        let now = Date()
        return allCards.filter { $0.cardType != .anki || $0.isNew || $0.nextReviewDate <= now }.sorted {
            if $0.cardType == .anki && $1.cardType == .anki {
                if $0.isNew != $1.isNew { return !$0.isNew }
                if !$0.isNew && $0.nextReviewDate != $1.nextReviewDate { return $0.nextReviewDate < $1.nextReviewDate }
                if $0.orderIndex != $1.orderIndex { return $0.orderIndex < $1.orderIndex }
            }
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
        let isCorrect = CardChoiceIdentity.index(option, options: card.options) == card.resolvedCorrectOptionIndex
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
        if (try? context.save()) != nil { AlertTimelineStore.shared.answered(notificationRequestID) }
    }

    private func rateAnki(_ card: Flashcard, rating: AnkiReviewRating) {
        guard card.cardType == .anki, isRevealed, !isGraded else { return }
        let option = card.recordAnkiReview(rating: rating, at: Date())
        do { try context.save() }
        catch {
            context.rollback()
            reviewError = error.localizedDescription
            return
        }
        shortReviews.schedule(card.id, due: option.nextReviewDate, repeatsInSession: option.shouldRepeatInSession)
        ratingCounts[rating, default: 0] += 1
        reviewedAnkiIDs.insert(card.id)
        if rating.wasCorrect { correctCount += 1 }
        InteractionSoundPlayer.shared.play(rating.wasCorrect ? .correct : .incorrect)
        AlertTimelineStore.shared.answered(notificationRequestID)
        let cardID = card.id
        Task { await AnkiReviewAlerts.reconcile(cardID: cardID) }
        isGraded = true
        advance()
    }

    private func submitAndAdvance(_ card: Flashcard) {
        guard card.cardType != .images || CardImageStore.loadImage(named: card.promptImageName) != nil else { return }
        if card.cardType == .images, let back = card.answerImageName, !back.isEmpty {
            guard hasViewedImageBack, CardImageStore.loadImage(named: back) != nil else { return }
        }
        if card.cardType.isReviewOnly {
            // A notification may already have recorded this review before handing off.
            if !isGraded {
                        card.processAnswer(isCorrect: true)
                correctCount += 1
                if (try? context.save()) != nil { AlertTimelineStore.shared.answered(notificationRequestID) }
            }
            advance()
            return
        }
        guard isGraded else { return }
        advance()
    }

    private func advance() {
        enqueueReadyReviews()
        guard cardIndex + 1 < studyQueue.count else {
            withAnimation(.snappy) {
                waitingForReview = shortReviews.nextDate != nil
                isComplete = !waitingForReview
            }
            return
        }
        withAnimation(.snappy) {
            cardIndex += 1
            selectedAnswer = nil
            isRevealed = false
            hasViewedImageBack = false
            isGraded = false
            showingHint = false
            hasRecordedHint = false
        }
    }

    private func enqueueReadyReviews(early: Bool = false) {
        let ids = shortReviews.takeReady(at: Date(), reviewEarly: early)
        let lookup = Dictionary(uniqueKeysWithValues: allCards.map { ($0.id, $0) })
        let cards = ids.compactMap { lookup[$0] }
        studyQueue.insert(contentsOf: cards, at: min(cardIndex + 1, studyQueue.count))
    }

    private func resumeLearning(early: Bool = false) {
        guard waitingForReview else { return }
        let wasEmpty = studyQueue.isEmpty
        enqueueReadyReviews(early: early)
        if wasEmpty && !studyQueue.isEmpty { cardIndex = -1 }
        guard cardIndex + 1 < studyQueue.count else { return }
        waitingForReview = false
        advance()
    }

    private func restartCycle() {
        withAnimation(.snappy) {
                shortReviews = AnkiSessionReviewQueue()
            waitingForReview = false
            ratingCounts = [:]
            reviewedAnkiIDs = []
            allCards = deck.cards
            studyQueue = buildSmartStudyQueue()
            cardIndex = 0
            selectedAnswer = nil
            isRevealed = false
            hasViewedImageBack = false
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

        if let initialCardId, let initialCard = allCards.first(where: { $0.id == initialCardId }) {
            if initialCard.cardType == .anki {
                // An old delivered alert can refer to a card already reviewed.
                // Offer due cards or an explicit early-learning action instead.
                guard initialWasGraded || initialCard.isNew || initialCard.nextReviewDate <= Date() else { return }
                studyQueue.removeAll { $0.id == initialCardId }
                studyQueue.insert(initialCard, at: 0)
                waitingForReview = false
                isComplete = false
                if initialWasGraded {
                    let state = initialCard.ankiReviewState
                    shortReviews.schedule(initialCardId, due: state.dueDate, repeatsInSession: state.phase != .review)
                }
            } else if let initialIndex = studyQueue.firstIndex(where: { $0.id == initialCardId }) {
                cardIndex = initialIndex
            }
        }
        // A queued notification can belong to a level that is no longer active.
        // Its answer/grade must never be applied to the replacement current card.
        if let initialCardId, currentCard?.id != initialCardId { return }
        selectedAnswer = initialSelectedAnswer
        isGraded = initialWasGraded
        isRevealed = currentCard?.cardType == .images
            ? initialWasRevealed
            : initialWasRevealed || (initialWasGraded && initialSelectedAnswer == nil)
        hasViewedImageBack = initialImageBackViewed || initialWasRevealed || initialWasGraded
        showingHint = initialHintVisible
        hasRecordedHint = initialHintVisible
        correctCount = initialWasCorrect == true ? 1 : 0
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
    @State private var ankiIsLoading = true
    var fieldMedia: [String: CardFieldMedia] = [:]
    var correctOptionIndex: Int? = nil
    let cardNumber: Int
    let cardCount: Int
    let correctCount: Int
    let selectedAnswer: String?
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
                    AnkiCardView(content: ankiContent, showingBack: isRevealed, centered: true, animatedReveal: true,
                        renderer: ankiRenderer, loadingChanged: { ankiIsLoading = $0 })
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    AnkiReviewControls(isRevealed: isRevealed, isGraded: isGraded, options: ankiReviewOptions,
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
                                QuizFillBlankCard(answer: correctAnswer, isGraded: isGraded, onGrade: onGrade)
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
