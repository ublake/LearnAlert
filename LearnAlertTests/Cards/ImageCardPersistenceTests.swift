import Foundation
import SwiftData
import Testing
@testable import LearnAlert

@Suite("Image card persistence")
@MainActor
struct ImageCardPersistenceTests {
    @Test("Single and two-sided image cards retain empty text and independent media after reopening")
    func reopensBothLayouts() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = directory.appendingPathComponent("Images.sqlite")
        let singleID: UUID
        let twoSidedID: UUID
        do {
            let container = try makeContainer(at: store)
            let context = ModelContext(container)
            let deck = Deck(name: "Visual study")
            let single = Flashcard(question: "", cardType: .images, promptImageName: "single.jpg")
            let twoSided = Flashcard(question: "", cardType: .images,
                                    promptImageName: "front.jpg", answerImageName: "back.jpg")
            singleID = single.id
            twoSidedID = twoSided.id
            deck.cards = [single, twoSided]
            single.deck = deck
            twoSided.deck = deck
            context.insert(deck)
            twoSided.processAnswer(isCorrect: true)
            try context.save()
        }
        let reopened = try makeContainer(at: store)
        let context = ModelContext(reopened)
        let cards = try context.fetch(FetchDescriptor<Flashcard>())
        #expect(cards.count == 2)
        let single = try #require(cards.first { $0.id == singleID })
        let twoSided = try #require(cards.first { $0.id == twoSidedID })
        #expect(single.promptImageName == "single.jpg")
        #expect(single.answerImageName == nil)
        #expect(twoSided.promptImageName == "front.jpg")
        #expect(twoSided.answerImageName == "back.jpg")
        #expect(twoSided.reviewCount == 1)
        #expect(twoSided.deck?.cards.count == 2)
        for card in cards {
            #expect(card.cardType == .images)
            #expect(card.question.isEmpty && card.correctAnswer.isEmpty && card.options.isEmpty && card.hint.isEmpty)
        }
    }

    private func makeContainer(at url: URL) throws -> ModelContainer {
        try ModelContainer(for: Deck.self, DeckSection.self, Flashcard.self,
                           configurations: ModelConfiguration(url: url, cloudKitDatabase: .none))
    }
}
