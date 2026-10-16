import Foundation
import SwiftData
import Testing
@testable import LearnAlert

@Suite("Card field media")
@MainActor
struct CardFieldMediaTests {
    @Test("Every field and the correct media-only choice survive store reopening")
    func persistsFieldsAndIdentity() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Cards.sqlite")
        let fields: [String: CardFieldMedia] = ["prompt": .init(audio: "question.wav"), "option:0": .init(image: "a.jpg"),
            "option:1": .init(audio: "b.wav"), "hint": .init(image: "hint.jpg", audio: "hint.wav")]
        do {
            let container = try ModelContainer(for: Deck.self, DeckSection.self, Flashcard.self, configurations: ModelConfiguration(url: url, cloudKitDatabase: .none))
            let context = ModelContext(container)
            let card = Flashcard(question: "", options: ["", ""], cardType: .multipleChoice)
            card.correctOptionIndex = 1; card.fieldMedia = fields
            card.processAnswer(isCorrect: true)
            context.insert(card); try context.save()
        }
        let container = try ModelContainer(for: Deck.self, DeckSection.self, Flashcard.self, configurations: ModelConfiguration(url: url, cloudKitDatabase: .none))
        let card = try #require(ModelContext(container).fetch(FetchDescriptor<Flashcard>()).first)
        #expect(card.fieldMedia == fields)
        #expect(card.options == ["", ""] && card.question.isEmpty && card.correctAnswer.isEmpty)
        #expect(card.resolvedCorrectOptionIndex == 1 && card.reviewCount == 1)
        #expect(CardChoiceIdentity.index(CardChoiceIdentity.value(0), options: card.options) == 0)
        #expect(CardChoiceIdentity.index(CardChoiceIdentity.value(1), options: card.options) == 1)
    }
    @Test("Old attachment columns and text-based answer identities remain compatible")
    func legacyCompatibilityAndRemoval() {
        let card = Flashcard(question: "Question", options: ["A", "B"], correctAnswer: "B", promptImageName: "prompt.jpg", answerImageName: "back.jpg", optionImageNames: ["", "choice.jpg"])
        card.promptAudioName = "prompt.wav"
        #expect(card.fieldMedia["prompt"] == .init(image: "prompt.jpg", audio: "prompt.wav"))
        #expect(card.fieldMedia["option:1"]?.image == "choice.jpg")
        #expect(card.resolvedCorrectOptionIndex == 1)
        #expect(CardChoiceIdentity.index("B", options: card.options) == 1)
        #expect(CardChoiceIdentity.index("learnalert-choice:99", options: card.options) == nil)
        card.fieldMedia = ["answer": .init(audio: "answer.wav")]
        #expect(card.promptImageName == nil && card.promptAudioName == nil && card.answerImageName == nil)
        #expect(card.optionImageNames == ["", ""])
        #expect(card.fieldMedia == ["answer": .init(audio: "answer.wav")])
    }
    @Test("Image/audio-only fields are content; an empty attachment is not")
    func contentRequirements() {
        #expect(CardFieldMedia(audio: "sound.wav").hasContent(""))
        #expect(CardFieldMedia(image: "picture.jpg").hasContent("  "))
        #expect(!CardFieldMedia(image: "", audio: "").hasContent(" \n"))
        #expect(CardFieldMedia().hasContent("Word"))
    }
}
