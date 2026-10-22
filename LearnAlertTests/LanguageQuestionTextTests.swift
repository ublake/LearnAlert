import Foundation
import SwiftData
import Testing
@testable import LearnAlert

@MainActor
@Suite("Concise language questions")
struct LanguageQuestionTextTests {
    @Test("Conversation prompts keep just the actual question, without generic reply instructions")
    func conversation() {
        #expect(LanguageQuestionText.concise("Someone asks “¿Cómo se llama usted?” Choose the relevant reply.") == "¿Cómo se llama usted?")
        #expect(LanguageQuestionText.concise("Someone asks “¿Dónde está el sofá?” Choose a location reply.") == "¿Dónde está el sofá?")
        #expect(LanguageQuestionText.concise("Someone says “Gracias”. Choose “You are welcome”.") == "Gracias")
        #expect(LanguageQuestionText.concise("Someone asks “¿Tienes dos libros?” Choose a clear negative answer.") == "¿Tienes dos libros?\nAnswer no.")
        #expect(LanguageQuestionText.concise("Someone addresses you respectfully: “¿Tiene usted un libro?” Choose your affirmative reply.") == "¿Tiene usted un libro?\nAnswer yes.")
    }

    @Test("Translation and reading wrappers disappear while meaningful questions remain")
    func translationAndContext() {
        #expect(LanguageQuestionText.concise("Choose the Korean for: I have two books.") == "I have two books.")
        #expect(LanguageQuestionText.concise("What does ‘학교에 가요.’ mean?") == "학교에 가요.")
        #expect(LanguageQuestionText.concise("Choose the plural phrase meaning “the blue books”.") == "the blue books")
        #expect(LanguageQuestionText.concise("Read: “No hay café. Hay agua.” Which drink is available?") == "“No hay café. Hay agua.” Which drink is available?")
        let indirect = "A friend says “내일 바빠요.” Choose the indirect statement."
        #expect(LanguageQuestionText.concise(indirect) == indirect)
        let formal = "You address Ana and Eva as vosotras. Which phrase means “your keys” in that address form?"
        #expect(LanguageQuestionText.concise(formal) == formal)
        #expect(LanguageQuestionText.concise("Choose the missing form: Tú ___ estudiante.") == "Tú ___ estudiante.")
    }

    @Test("Saved language cards use the same copy in preview, practice and notification payloads")
    func savedCards() {
        let prompt = "Someone asks “¿Cómo se llama usted?” Choose the relevant reply."
        let card = Flashcard(question: prompt, options: ["Me llamo Elena.", "Estoy en casa."], correctAnswer: "Me llamo Elena.")
        #expect(card.studyQuestion == prompt) // Personal and Anki cards keep their authored wording.
        card.sourceCourseCardID = "es-sp-people-02-07"
        card.reviewCount = 9; card.masteryScore = 2
        #expect(card.studyQuestion == "¿Cómo se llama usted?")
        #expect(card.question == prompt && card.reviewCount == 9 && card.masteryScore == 2)
        #expect(card.options == ["Me llamo Elena.", "Estoy en casa."])
        card.question = "What is this?"; card.promptImageName = "course-vocab-apple"
        #expect(card.studyQuestion.isEmpty)
        card.promptImageName = nil; #expect(card.studyQuestion == "What is this?")
        card.promptImageName = ""; #expect(card.studyQuestion == "What is this?")
    }

    @Test("Every bundled projected prompt is stable after repeated cleanup")
    func bundledAudit() {
        for course in CourseCurriculumCatalog.bundledCourses {
            for card in LanguageDeckProjection.topics(course).flatMap(\.cards) {
                let clean = LanguageQuestionText.concise(card.question, hasPromptImage: card.resolvedFieldMedia["prompt"]?.image != nil)
                #expect(clean == card.question)
                #expect(!clean.contains("Choose the relevant reply"))
                #expect(!clean.hasPrefix("Choose the Korean for:"))
            }
        }
    }

    @Test("Published collections simplify copy without changing any card identity, answer or attachment")
    func authoredCollection() throws {
        let original = CourseLessonCard(id: "reply", question: "Someone asks “¿Cómo se llama usted?” Choose the relevant reply.",
            options: ["Me llamo Elena.", "Estoy en casa."], correctAnswer: "Me llamo Elena.", hint: "A name", promptAudioName: "recording.mp3", correctOptionIndex: 0)
        let lesson = CourseLesson(id: "names", lessonNumber: 1, title: "Names", subtitle: "", cards: [original])
        let unit = CourseUnit(id: "unit", unitNumber: 1, title: "Unit", subtitle: "", colorHex: "#123456", badgeIcon: "book", lessons: [lesson])
        let course = CourseDefinition(id: "copy-fixture", title: "Spanish", language: "Spanish", flagEmoji: "🇪🇸", levelTag: "", colorHex: "#123456", summary: "", estimatedHours: 0, outcomes: [], units: [unit], presentation: "deck_collection")
        let clean = try #require(LanguageDeckProjection.topics(course).first?.cards.first)
        var expected = original; expected.question = "¿Cómo se llama usted?"
        #expect(clean == expected && course.units[0].lessons[0].cards[0] == original)
        let container = try ModelContainer(for: Deck.self, DeckSection.self, Flashcard.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let before = try LanguageTopicStore.open(course: course, topic: .init(id: lesson.id, title: lesson.title, cards: [original]), context: container.mainContext, learningSnapshot: .init())
        let card = try #require(before.cards.first); card.reviewCount = 7; card.masteryScore = 2
        let id = card.id
        let after = try LanguageTopicStore.open(course: course, topic: LanguageDeckProjection.topics(course)[0], context: container.mainContext, learningSnapshot: .init())
        #expect(after.id == before.id && after.cards[0].id == id)
        #expect(after.cards[0].question == expected.question && after.cards[0].reviewCount == 7 && after.cards[0].masteryScore == 2)
    }
}
