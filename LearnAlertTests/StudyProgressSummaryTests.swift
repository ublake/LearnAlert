import Foundation
import Testing
@testable import LearnAlert

@MainActor
@Suite("Study progress totals")
struct StudyProgressSummaryTests {
    @Test("Courses use shared progress once while ordinary and downloaded decks remain included")
    func combinesWithoutCourseCopies() throws {
        let course = self.course()
        let regular = Deck(name: "My deck")
        let question = Flashcard(question: "Question", correctAnswer: "Answer", cardType: .multipleChoice)
        question.reviewCount = 4; question.correctCount = 2; question.masteryScore = 1
        regular.cards = [question]
        let community = Deck(name: "Downloaded")
        community.sourceCommunityID = "public-deck"
        let word = Flashcard(question: "Word", correctAnswer: "Definition", cardType: .vocabulary)
        word.reviewCount = 3; word.correctCount = 3; word.masteryScore = 3
        community.cards = [word]
        let backingByType = Deck(name: "Course copy", deckType: "Course")
        let backingBySource = Deck(name: "Another copy")
        backingBySource.sourcePremadeID = "course:\(course.id)"
        for deck in [backingByType, backingBySource] {
            let copy = Flashcard(question: "Duplicated", correctAnswer: "A")
            copy.reviewCount = 999; copy.correctCount = 999; copy.masteryScore = 3
            deck.cards = [copy]
        }
        var snapshot = CourseLearningSnapshot()
        snapshot.progress[course.id] = ["lesson-one": .init(status: .completed, masteredCardIds: ["one", "two", "removed-card"])]
        snapshot.courseSRS[course.id, default: [:]]["one"] = CourseCardSRSRecord(cardId: "one", masteryScore: 3, reviewCount: 3, correctCount: 3)
        snapshot.courseSRS[course.id, default: [:]]["two"] = CourseCardSRSRecord(cardId: "two", masteryScore: 1, reviewCount: 2, correctCount: 1)
        snapshot.courseSRS[course.id, default: [:]]["removed-card"] = CourseCardSRSRecord(cardId: "removed-card", masteryScore: 3, reviewCount: 800, correctCount: 800)

        let summary = StudyProgressSummary(decks: [regular, community, backingByType, backingBySource, regular],
                                           courses: [course, course], snapshot: snapshot)
        #expect(summary.decks.count == 2 && summary.courses.count == 1)
        #expect(summary.decks.first { $0.id == community.id }?.isCommunity == true)
        #expect(summary.reviewCount == 12)
        #expect(summary.cardCount == 5 && summary.reviewedCardCount == 4)
        #expect(summary.masteredCardCount == 2 && summary.learningCardCount == 2 && summary.newCardCount == 1)
        #expect(summary.quizReviewCount == 4 && summary.quizCorrectCount == 2 && summary.quizAccuracy == 0.5)
        let progress = try #require(summary.courses.first)
        #expect(progress.completedLessonCount == 1 && progress.lessonCount == 2)
        #expect(progress.passedCheckpointCount == 0 && progress.checkpointCount == 1)
        #expect(progress.currentStep == "Next lesson")
        #expect(abs(progress.fraction - 1.0 / 3.0) < 0.001)
    }

    @Test("Read-through, picture, self-rated, and course reviews do not inflate quiz accuracy")
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
        var snapshot = CourseLearningSnapshot()
        snapshot.courseSRS[course().id, default: [:]]["one"] = CourseCardSRSRecord(cardId: "one", reviewCount: 100, correctCount: 100)
        let summary = StudyProgressSummary(decks: [deck], courses: [course()], snapshot: snapshot)
        #expect(summary.reviewCount == 407)
        #expect(summary.quizReviewCount == 7 && summary.quizCorrectCount == 4)
        #expect(abs((summary.quizAccuracy ?? 0) - 4.0 / 7.0) < 0.001)
    }

    @Test("Lesson fractions and passed checkpoints follow the same authoritative course gates")
    func checkpointProgress() throws {
        let course = self.course()
        var snapshot = CourseLearningSnapshot()
        snapshot.progress[course.id] = ["lesson-one": .init(status: .current, masteredCardIds: ["one"])]
        var summary = StudyProgressSummary(decks: [], courses: [course], snapshot: snapshot)
        #expect(abs((summary.courses.first?.fraction ?? 0) - 1.0 / 6.0) < 0.001)
        #expect(summary.reviewedCardCount == 1)
        snapshot.checkpoints[course.id] = ["unit-one": CourseCheckpointResult(checkpointId: "quiz-one", sectionId: "unit-one", score: 1, totalQuestions: 1, passed: true)]
        summary = StudyProgressSummary(decks: [], courses: [course], snapshot: snapshot)
        let progress = try #require(summary.courses.first)
        #expect(progress.fraction == 1)
        #expect(progress.completedLessonCount == 2 && progress.passedCheckpointCount == 1)
        #expect(progress.currentStep == "Course complete")
        #expect(summary.reviewCount == 0)
    }

    @Test("An empty library has stable zero totals and no invented accuracy")
    func emptyLibrary() {
        let summary = StudyProgressSummary(decks: [], courses: [], snapshot: CourseLearningSnapshot())
        #expect(summary.reviewCount == 0 && summary.cardCount == 0)
        #expect(summary.masteredCardCount == 0 && summary.learningCardCount == 0 && summary.newCardCount == 0)
        #expect(summary.quizAccuracy == nil)
    }

    private func course() -> CourseDefinition {
        let cards = [CourseLessonCard(id: "one", question: "One", correctAnswer: "A"),
                     CourseLessonCard(id: "two", question: "Two", correctAnswer: "B"),
                     CourseLessonCard(id: "three", question: "Three", correctAnswer: "C")]
        let first = CourseLesson(id: "lesson-one", lessonNumber: 1, title: "First lesson", subtitle: "", cards: Array(cards.prefix(2)))
        let second = CourseLesson(id: "lesson-two", lessonNumber: 2, title: "Next lesson", subtitle: "", cards: [cards[2]])
        let quiz = CourseCheckpointQuiz(id: "quiz-one", title: "First checkpoint", summary: "", questions: [CourseLessonCard(id: "quiz-question", question: "Check", correctAnswer: "A")])
        let unit = CourseUnit(id: "unit-one", unitNumber: 1, title: "Unit", subtitle: "", colorHex: "#7799AA", badgeIcon: "book", lessons: [first, second], checkpointQuiz: quiz)
        return CourseDefinition(id: "test-course", title: "Test course", language: "Korean", flagEmoji: "🇰🇷", levelTag: "Beginner", colorHex: "#7799AA", summary: "", estimatedHours: 1, outcomes: [], units: [unit])
    }
}
