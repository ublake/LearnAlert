import Testing
import SwiftUI
import SwiftData
@testable import LearnAlert

@MainActor
@Suite("Simple language decks")
struct LanguageDeckTests {
    @Test("Both languages expose only regular ungated topic cards, without drawing or explanations")
    func projections() throws {
        for course in CourseCurriculumCatalog.bundledCourses {
            let topics = LanguageDeckProjection.topics(course)
            #expect(!topics.isEmpty)
            if course.language == "Spanish" {
                let apple = topics.flatMap(\.cards).first { $0.question == "la manzana" }
                #expect(apple?.options == ["", "", "", ""])
                #expect(apple?.resolvedFieldMedia["option:0"]?.image != nil)
            }
            #expect(Set(topics.map(\.id)).count == topics.count)
            let cards = topics.flatMap(\.cards)
            #expect(Set(cards.map(\.id)).count == cards.count)
            #expect(cards.allSatisfy { $0.activity == nil && $0.explanation == nil && $0.grammarNote == nil && $0.hint.isEmpty })
            #expect(cards.allSatisfy { ["multipleChoice","matching","fillBlank"].contains($0.cardType) })
            for card in cards where card.cardType != "matching" {
                #expect(card.options.count >= 2)
                #expect(card.resolvedCorrectOptionIndex != nil)
            }
            #expect(cards.contains { $0.resolvedFieldMedia.keys.contains { $0.hasPrefix("option:") } })
            // The migration adapter never mutates the published source document.
            if course.language == "Korean" { #expect(course.units.flatMap(\.lessons).flatMap(\.cards).contains { $0.activity?.kind == .trace }) }
        }
    }

    @Test("Generated quizzes choose distractors from the same topic")
    func relatedChoices() throws {
        let fruit = CourseLesson(id: "food", lessonNumber: 1, title: "Food", subtitle: "", cards: [.init(id: "fruit", question: "Match", options: [], correctAnswer: "", cardType: "matching", matchingLeftItems: ["manzana", "plátano"], matchingRightItems: ["apple", "banana"])])
        let sounds = CourseLesson(id: "sounds", lessonNumber: 2, title: "Sounds", subtitle: "", cards: [.init(id: "vowels", question: "Match", options: [], correctAnswer: "", cardType: "matching", matchingLeftItems: ["a", "e"], matchingRightItems: ["ah", "eh"])])
        let unit = CourseUnit(id: "topics", unitNumber: 1, title: "", subtitle: "", colorHex: "#75B9DA", badgeIcon: "rectangle.stack", lessons: [fruit, sounds])
        let course = CourseDefinition(id: "related-spanish", title: "Spanish", language: "Spanish", flagEmoji: "🇪🇸", levelTag: "", colorHex: "#75B9DA", summary: "", estimatedHours: 0, outcomes: [], units: [unit])
        let cards = try #require(LanguageDeckProjection.topics(course).first).cards
        let quiz = try #require(cards.first { $0.id == "fruit-pair-0-forward" })
        #expect(Set(quiz.options) == Set(["apple", "banana"]))
    }

    @Test("Authored collections retain exactly their editable cards")
    func authoredCollection() throws {
        let source = CourseCurriculumCatalog.koreanCourse
        let cards = [CourseLessonCard(id: "only-apple", question: "사과", options: ["apple", "water"], correctAnswer: "apple", correctOptionIndex: 0)]
        let lesson = CourseLesson(id: "fruit", lessonNumber: 1, title: "Fruit", subtitle: "", cards: cards)
        let unit = CourseUnit(id: "collection", unitNumber: 1, title: "", subtitle: "", colorHex: source.colorHex, badgeIcon: "rectangle.stack", lessons: [lesson])
        let course = CourseDefinition(id: "editable-korean", title: source.title, language: source.language, flagEmoji: source.flagEmoji, levelTag: "", colorHex: source.colorHex, summary: "", estimatedHours: 0, outcomes: [], units: [unit], presentation: "deck_collection")
        let decoded = try JSONDecoder().decode(CourseDefinition.self, from: JSONEncoder().encode(course))
        #expect(LanguageDeckProjection.topics(decoded).flatMap(\.cards) == cards)
    }

    @Test("Opening and refreshing a topic preserves deck, card and review identities")
    func stableTopicDecks() throws {
        let container = try ModelContainer(for: Deck.self, DeckSection.self, Flashcard.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let course = CourseCurriculumCatalog.koreanCourse
        let topic = try #require(LanguageDeckProjection.topics(course).first)
        let previous = Deck(name: "Old course", deckType: "Course"); previous.sourcePremadeID = "course:\(course.id)"
        let oldCard = Flashcard(question: "Old wording"); oldCard.sourceCourseCardID = topic.cards[0].id
        oldCard.reviewCount = 7; oldCard.correctCount = 5; oldCard.masteryScore = 2
        previous.cards = [oldCard]; context.insert(previous); try context.save()
        var snapshot = CourseLearningSnapshot()
        snapshot.courseSRS[course.id] = [topic.cards[1].id: .init(cardId: topic.cards[1].id, masteryScore: 3, reviewCount: 9, correctCount: 8)]
        let first = try LanguageTopicStore.open(course: course, topic: topic, context: context, learningSnapshot: snapshot)
        #expect(first.cards[1].reviewCount == 9 && first.cards[1].masteryScore == 3)
        let card = try #require(first.cards.first)
        #expect(first.deckType == "Quiz" && first.sourceKind == "languageTopic")
        #expect(card.reviewCount == 7 && card.correctCount == 5 && card.masteryScore == 2)
        card.reviewCount = 8; card.question = "My local edit"; let cardID = card.id; try context.save()
        let again = try LanguageTopicStore.open(course: course, topic: topic, context: context)
        #expect(again.id == first.id && again.cards.first?.id == cardID && again.cards.first?.reviewCount == 8)
        #expect(previous.cards.first?.reviewCount == 7)
        #expect(again.cards.first?.question == "My local edit")
        let all = try LanguageTopicStore.collection(course: course, context: context)
        let alertCard = try #require(all.cards.first { $0.sourceCourseCardID == card.sourceCourseCardID })
        #expect(alertCard.reviewCount == card.reviewCount)
        card.processAnswer(isCorrect: true); try context.save()
        #expect(alertCard.reviewCount == card.reviewCount && alertCard.masteryScore == card.masteryScore)
        alertCard.processAnswer(isCorrect: false); try context.save()
        #expect(card.reviewCount == alertCard.reviewCount && card.masteryScore == alertCard.masteryScore)
        #expect(card.question == "My local edit")
        #expect(first.cards.allSatisfy { [.multipleChoice,.matching,.fillBlank].contains($0.cardType) })
    }

    @Test("Blank choices insert, swap, deselect and clear without submitting prematurely")
    func blankChoices() {
        var state = BlankChoiceState()
        #expect(state.selected == nil && !state.isCorrect(answerIndex: 0))
        state.select(0); #expect(state.selected == 0 && state.isCorrect(answerIndex: 0))
        state.select(1); #expect(state.selected == 1 && !state.isCorrect(answerIndex: 0))
        state.select(1); #expect(state.selected == nil)
        state.select(0); state.clear(); #expect(state.selected == nil)
    }

    @Test("Blank sentences and neutral matching fit app and notification widths")
    func cardLayouts() throws {
        for width: CGFloat in [350, 402] {
            for scheme in [ColorScheme.light, .dark] {
                let blank = CardBlankChoicePanel(prompt: "Me gusta ___ por la mañana.", options: ["el café", "la casa", "el perro", "el libro"], answerIndex: 0, isGraded: false) { _ in }
                let renderer = ImageRenderer(content: blank.padding(16).frame(width: width)
                    .background(Color(.systemBackground)).environment(\.colorScheme, scheme))
                let image = try #require(renderer.uiImage)
                #expect(image.size.width == width && image.size.height < 600)
                Attachment.record(image, named: "blank-\(Int(width))-\(scheme).png", as: .png)
                let picture = try #require(LanguageDeckProjection.topics(CourseCurriculumCatalog.bundledCourses.first { $0.language == "Spanish" }!).flatMap(\.cards).first { $0.question == "la manzana" && $0.options.allSatisfy(\.isEmpty) })
                for field in picture.resolvedFieldMedia.values { #expect(CardImageStore.loadImage(named: field.image) != nil) }
                let grid = ImageRenderer(content: CardMediaChoiceList(options: picture.options, fields: picture.resolvedFieldMedia, correctIndex: 0, selection: nil, isGraded: false) { _ in }
                    .padding(16).frame(width: width).background(Color(.systemBackground)).environment(\.colorScheme, scheme))
                let gridImage = try #require(grid.uiImage)
                #expect(gridImage.size.height < 310)
                Attachment.record(gridImage, named: "pictures-\(Int(width))-\(scheme).png", as: .png)
                let matching = ImageRenderer(content: CardMediaMatchingBoard(left: ["hola","gracias"], right:["hello","thanks"], fields:[:], isGraded:false) { _ in }
                    .padding(16).frame(width:width).background(Color(.systemBackground)).environment(\.colorScheme,scheme))
                #expect(try #require(matching.uiImage).size.height < 400)
            }
        }
    }
}
