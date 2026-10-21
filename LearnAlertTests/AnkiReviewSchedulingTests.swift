import Foundation
import SwiftData
import Testing
@testable import LearnAlert

@Suite("Anki review scheduling")
@MainActor
struct AnkiReviewSchedulingTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("New cards preview four distinct delays without changing their state")
    func initialOptions() {
        let card = Flashcard(question: "Front", cardType: .anki)
        let options = card.ankiReviewOptions(at: now)
        #expect(options.map(\.rating) == [.again, .hard, .good, .easy])
        #expect(options.map(\.interval) == [60, 360, 600, 4 * 86_400])
        #expect(options.map(\.intervalLabel) == ["1m", "6m", "10m", "4d"])
        #expect(options.map(\.shouldRepeatInSession) == [true, true, true, false])
        #expect(options.allSatisfy { $0.nextReviewDate == now.addingTimeInterval($0.interval) })
        #expect(card.ankiReviewStateData == nil)
        #expect(card.reviewCount == 0 && card.correctCount == 0 && card.lastReviewedDate == nil)
    }

    @Test("Learning steps repeat short reviews, graduate on Good, and let Easy graduate immediately")
    func learningProgression() {
        let card = Flashcard(question: "Front", cardType: .anki)
        card.recordAnkiReview(rating: .good, at: now)
        #expect(card.ankiReviewState.phase == .learning && card.ankiReviewState.learningStep == 1)
        #expect(card.nextReviewDate == now.addingTimeInterval(600))
        let graduated = card.recordAnkiReview(rating: .good, at: now.addingTimeInterval(600))
        #expect(graduated.nextState.phase == .review && graduated.interval == 86_400)
        #expect(card.reviewCount == 2 && card.correctCount == 2 && card.streak == 2)
        #expect(card.ankiReviewState.ratingCounts.good == 2 && card.ankiReviewState.lastRating == .good)

        let failed = Flashcard(question: "Try again", cardType: .anki)
        failed.recordAnkiReview(rating: .good, at: now)
        failed.recordAnkiReview(rating: .again, at: now.addingTimeInterval(600))
        #expect(failed.ankiReviewState.learningStep == 0 && failed.ankiReviewState.lapses == 0)
        #expect(failed.ankiReviewOptions(at: now).first { $0.rating == .good }?.interval == 600)

        let easy = Flashcard(question: "Known", cardType: .anki)
        easy.recordAnkiReview(rating: .easy, at: now)
        #expect(easy.ankiReviewState.phase == .review)
        #expect(easy.nextReviewDate == now.addingTimeInterval(4 * 86_400))
    }

    @Test("Anki Known status follows graduation and relearning while ordinary cards retain incremental mastery")
    func phaseControlsMastery() {
        let card = Flashcard(question: "Known immediately", cardType: .anki)
        card.recordAnkiReview(rating: .easy, at: now)
        #expect(card.ankiReviewState.phase == .review && card.masteryScore == 3 && card.isLearned)
        #expect(card.reviewCount == 1 && card.correctCount == 1 && card.streak == 1)
        card.recordAnkiReview(rating: .again, at: now.addingTimeInterval(4 * 86_400))
        #expect(card.ankiReviewState.phase == .relearning && card.masteryScore == 0 && !card.isLearned)
        #expect(card.reviewCount == 2 && card.correctCount == 1 && card.streak == 0)
        card.recordAnkiReview(rating: .hard, at: now.addingTimeInterval(4 * 86_400 + 60))
        #expect(card.ankiReviewState.phase == .relearning && card.masteryScore == 1 && !card.isLearned)
        card.recordAnkiReview(rating: .good, at: now.addingTimeInterval(4 * 86_400 + 420))
        #expect(card.ankiReviewState.phase == .review && card.masteryScore == 3 && card.isLearned)
        #expect(card.reviewCount == 4 && card.correctCount == 3)

        let learning = Flashcard(question: "Learning", cardType: .anki)
        learning.recordAnkiReview(rating: .good, at: now)
        #expect(learning.masteryScore == 1 && !learning.isLearned)
        learning.recordAnkiReview(rating: .hard, at: now.addingTimeInterval(600))
        #expect(learning.masteryScore == 2 && !learning.isLearned)
        learning.recordAnkiReview(rating: .hard, at: now.addingTimeInterval(960))
        #expect(learning.masteryScore == 2 && !learning.isLearned)

        let quiz = Flashcard(question: "Regular", cardType: .multipleChoice)
        quiz.recordReview(wasCorrect: true)
        #expect(quiz.masteryScore == 1 && !quiz.isLearned && quiz.ankiReviewStateData == nil)
        quiz.recordReview(wasCorrect: true); quiz.recordReview(wasCorrect: true)
        #expect(quiz.masteryScore == 3 && quiz.isLearned)
        quiz.recordReview(wasCorrect: false)
        #expect(quiz.masteryScore == 2 && !quiz.isLearned && quiz.ankiReviewStateData == nil)
    }

    @Test("Mature ratings change intervals and ease, while failure enters retained-interval relearning")
    func matureAndRelearning() {
        var state = AnkiReviewState()
        state.phase = .review; state.reviewInterval = 20 * 86_400
        state.interval = state.reviewInterval; state.reviewCount = 15; state.lapses = 2
        let options = AnkiReviewScheduling.options(for: state, at: now)
        let expected: [TimeInterval] = [60, 24 * 86_400, 50 * 86_400, 65 * 86_400]
        #expect(options.map(\.interval) == expected)
        #expect(options[0].nextState.phase == .relearning && options[0].nextState.lapses == 3)
        #expect(options[0].nextState.reviewInterval == 4 * 86_400)
        #expect(options[1].nextState.easeFactor < state.easeFactor)
        #expect(options[2].nextState.easeFactor == state.easeFactor)
        #expect(options[3].nextState.easeFactor > state.easeFactor)
        let recovered = AnkiReviewScheduling.option(for: .good, state: options[0].nextState, at: now.addingTimeInterval(60))
        #expect(recovered.nextState.phase == .review && recovered.interval == 4 * 86_400)
        #expect(recovered.nextState.reviewCount == 17 && recovered.nextState.lapses == 3)
        #expect(recovered.nextState.ratingCounts.again == 1 && recovered.nextState.ratingCounts.good == 1)
        state.easeFactor = 1.3
        #expect(AnkiReviewScheduling.option(for: .hard, state: state, at: now).nextState.easeFactor == 1.3)
        #expect(AnkiReviewScheduling.option(for: .again, state: state, at: now).nextState.easeFactor == 1.3)
    }

    @Test("Schedule growth stays finite and distinct after a short mature interval")
    func finiteSchedule() {
        var state = AnkiReviewState()
        state.phase = .review; state.reviewInterval = 86_400; state.easeFactor = 1.3
        let expected: [TimeInterval] = [60, 2 * 86_400, 3 * 86_400, 4 * 86_400]
        let intervals = AnkiReviewScheduling.options(for: state, at: now).map(\.interval)
        #expect(intervals == expected)
        state.reviewInterval = .infinity; state.easeFactor = .nan
        #expect(AnkiReviewScheduling.options(for: state, at: now).allSatisfy { $0.interval.isFinite && $0.nextState.easeFactor.isFinite })
        state.reviewInterval = 1_000_000 * 86_400
        #expect(AnkiReviewScheduling.options(for: state, at: now).allSatisfy { $0.interval <= AnkiReviewScheduling.maximumInterval })
    }

    @Test("State decoding supplies additive defaults without inventing unknown rating history")
    func decodingDefaults() throws {
        var state = AnkiReviewState()
        state.phase = .review; state.reviewCount = 12; state.dueDate = now
        let data = try JSONEncoder().encode(state)
        var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "ratingCounts"); object.removeValue(forKey: "lastRating")
        let restored = try JSONDecoder().decode(AnkiReviewState.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(restored.reviewCount == 12 && restored.dueDate == now && restored.phase == .review)
        #expect(restored.ratingCounts.total == 0 && restored.lastRating == nil)
        let partial = try JSONDecoder().decode(AnkiReviewRatingCounts.self, from: Data("{\"good\":3}".utf8))
        #expect(partial.good == 3 && partial.again == 0 && partial.hard == 0 && partial.easy == 0)
    }

    @Test("Existing Anki counts, mastery, streak and exact due date survive lazy migration")
    func legacyProgress() {
        let card = Flashcard(question: "Existing import", cardType: .anki)
        card.reviewCount = 6; card.correctCount = 4; card.masteryScore = 2
        card.streak = 2; card.longestStreak = 3; card.lastReviewedDate = now
        #expect(card.nextReviewDate == now.addingTimeInterval(12 * 3_600))
        #expect(card.ankiReviewState.phase == .review && card.ankiReviewState.reviewCount == 6)
        #expect(card.ankiReviewState.ratingCounts.total == 0 && card.ankiReviewState.lastRating == nil)
        #expect(card.ankiReviewStateData == nil)
        let preview = card.ankiReviewOptions(at: now).first { $0.rating == .hard }
        let recorded = card.recordAnkiReview(rating: .hard, at: now)
        #expect(recorded == preview)
        #expect(card.reviewCount == 7 && card.correctCount == 5 && card.streak == 3 && card.masteryScore == 3)
        #expect(card.ankiReviewState.reviewCount == 7 && card.ankiReviewState.ratingCounts.hard == 1)
        #expect(card.lastReviewedDate == now && card.nextReviewDate == recorded.nextReviewDate)
        #expect(card.ankiReviewStateData != nil)
    }

    @Test("Other card types retain Boolean review behavior and Anki legacy Boolean calls use the same scheduler")
    func booleanCompatibility() {
        let quiz = Flashcard(question: "Quiz", cardType: .multipleChoice)
        quiz.recordReview(wasCorrect: true)
        #expect(quiz.reviewCount == 1 && quiz.correctCount == 1 && quiz.masteryScore == 1)
        #expect(quiz.ankiReviewStateData == nil)
        #expect(quiz.nextReviewDate == quiz.lastReviewedDate?.addingTimeInterval(4 * 3_600))
        quiz.recordReview(wasCorrect: false)
        #expect(quiz.reviewCount == 2 && quiz.correctCount == 1 && quiz.masteryScore == 0 && quiz.streak == 0)
        #expect(quiz.ankiReviewStateData == nil)
        let card = Flashcard(question: "Anki", cardType: .anki)
        card.recordReview(wasCorrect: true)
        card.recordReview(wasCorrect: false)
        #expect(card.reviewCount == 2 && card.correctCount == 1)
        #expect(card.ankiReviewState.reviewCount == 2 && card.ankiReviewState.lastRating == .again)
        #expect(card.ankiReviewState.ratingCounts.good == 1 && card.ankiReviewState.ratingCounts.again == 1)
        card.resetProgress()
        #expect(card.ankiReviewStateData == nil && card.isNew && card.ankiReviewState.ratingCounts.total == 0)
    }

    @Test("Relearning schedule, due date, rating counts and lapses survive closing and reopening storage")
    func persistedState() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = directory.appendingPathComponent("Reviews.sqlite")
        let id: UUID
        let expected: AnkiReviewState
        do {
            let container = try makeContainer(at: store), context = ModelContext(container)
            let card = Flashcard(question: "Persistent import", cardType: .anki)
            context.insert(card)
            card.recordAnkiReview(rating: .easy, at: now)
            card.recordAnkiReview(rating: .again, at: now.addingTimeInterval(4 * 86_400))
            id = card.id; expected = card.ankiReviewState
            try context.save()
        }
        let container = try makeContainer(at: store), context = ModelContext(container)
        let card = try #require(context.fetch(FetchDescriptor<Flashcard>()).first { $0.id == id })
        #expect(card.ankiReviewState == expected)
        #expect(card.ankiReviewState.phase == .relearning && card.ankiReviewState.lapses == 1)
        #expect(card.nextReviewDate == expected.dueDate && card.reviewCount == 2 && card.correctCount == 1)
        #expect(card.ankiReviewState.ratingCounts.easy == 1 && card.ankiReviewState.ratingCounts.again == 1)
    }

    private func makeContainer(at url: URL) throws -> ModelContainer {
        try ModelContainer(for: Deck.self, DeckSection.self, Flashcard.self,
            configurations: ModelConfiguration(url: url, cloudKitDatabase: .none))
    }
}
