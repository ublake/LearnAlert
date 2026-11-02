import Foundation
import Testing
@testable import LearnAlert

@MainActor
@Suite("Study progress totals")
struct StudyProgressSummaryTests {
    @Test("Ordinary and downloaded decks remain included without duplicate identities")
    func combinesWithoutCourseCopies() throws {
        let regular = Deck(name: "My deck")
        let question = Flashcard(question: "Question", correctAnswer: "Answer", cardType: .multipleChoice)
        question.reviewCount = 4; question.correctCount = 2; question.masteryScore = 1
        regular.cards = [question]
        let community = Deck(name: "Downloaded")
        community.sourceCommunityID = "public-deck"
        let word = Flashcard(question: "Word", correctAnswer: "Definition", cardType: .vocabulary)
        word.reviewCount = 3; word.correctCount = 3; word.masteryScore = 3
        community.cards = [word]
        let summary = StudyProgressSummary(decks: [regular, community, regular])
        #expect(summary.decks.count == 2)
        #expect(summary.decks.first { $0.id == community.id }?.isCommunity == true)
        #expect(summary.reviewCount == 7)
        #expect(summary.cardCount == 2 && summary.reviewedCardCount == 2)
        #expect(summary.masteredCardCount == 1 && summary.learningCardCount == 1 && summary.newCardCount == 0)
        #expect(summary.quizReviewCount == 4 && summary.quizCorrectCount == 2 && summary.quizAccuracy == 0.5)

    }

    @Test("Read-through, picture, self-rated, reviews do not inflate quiz accuracy")
    func quizAccuracyUsesObjectiveCards() {
        let deck = Deck(name: "Mixed study")
        for type: FlashcardType in [.vocabulary, .images, .tapReveal] {
            let card = Flashcard(question: "Review", correctAnswer: "A", cardType: type)
            card.reviewCount = 100; card.correctCount = 100
            deck.cards.append(card)
        }
        for (type, reviews, correct) in [(FlashcardType.multipleChoice, 4, 2), (.fillBlank, 2, 1), (.matching, 1, 1)] {
            let card = Flashcard(question: "Quiz", correctAnswer: "A", cardType: type)
            card.reviewCount = reviews; card.correctCount = correct
            deck.cards.append(card)
        }
        let summary = StudyProgressSummary(decks: [deck])
        #expect(summary.reviewCount == 307)
        #expect(summary.quizReviewCount == 7 && summary.quizCorrectCount == 4)
        #expect(abs((summary.quizAccuracy ?? 0) - 4.0 / 7.0) < 0.001)
    }


    @Test("An empty library has stable zero totals and no invented accuracy")
    func emptyLibrary() {
        let summary = StudyProgressSummary(decks: [])
        #expect(summary.reviewCount == 0 && summary.cardCount == 0)
        #expect(summary.masteredCardCount == 0 && summary.learningCardCount == 0 && summary.newCardCount == 0)
        #expect(summary.quizAccuracy == nil)
    }

}
