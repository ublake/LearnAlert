import Foundation
import SwiftData
import Testing
@testable import LearnAlert

private actor DeletionReports {
    var updates: [LibraryDeletionProgress] = []
    func append(_ update: LibraryDeletionProgress) { updates.append(update) }
}

@MainActor
@Suite("Large library operations", .serialized)
struct LibraryPerformanceTests {
    private func fixture() throws -> (ModelContainer, URL) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let config = ModelConfiguration(url: directory.appendingPathComponent("test.sqlite"), cloudKitDatabase: .none)
        return (try ModelContainer(for: Deck.self, DeckSection.self, Flashcard.self, configurations: config), directory)
    }

    @Test("Bulk deletion removes a large library and orphan rows without per-card delays")
    func bulkDeletion() async throws {
        let (container, directory) = try fixture()
        defer { try? FileManager.default.removeItem(at: directory) }
        let context = container.mainContext
        let deck = Deck(name: "Disposable bulk deletion fixture")
        let section = DeckSection(title: "Fixture folder", deck: deck)
        let cards = (0..<5_000).map { index in
            let card = Flashcard(question: "Card \(index)", deck: deck, section: section, cardType: .anki)
            card.orderIndex = index
            return card
        }
        deck.cards = cards; deck.sections = [section]; context.insert(deck)
        context.insert(Flashcard(question: "Orphan fixture card"))
        context.insert(DeckSection(title: "Orphan fixture folder"))
        try context.save()
        let reports = DeletionReports()
        let start = ContinuousClock.now
        let result = try await Task.detached {
            let worker = LibraryDataWorker(modelContainer: container)
            return try await worker.deleteAll { await reports.append($0) }
        }.value
        let elapsed = start.duration(to: .now)
        #expect(result.cards == 5_001 && result.decks == 1)
        let verification = ModelContext(container)
        #expect(try verification.fetchCount(FetchDescriptor<Flashcard>()) == 0)
        #expect(try verification.fetchCount(FetchDescriptor<DeckSection>()) == 0)
        #expect(try verification.fetchCount(FetchDescriptor<Deck>()) == 0)
        context.processPendingChanges()
        #expect(try context.fetchCount(FetchDescriptor<Deck>()) == 0)
        let events = await reports.updates
        #expect(events.map(\.fraction) == events.map(\.fraction).sorted())
        #expect(events.last?.fraction == 1 && events.allSatisfy { $0.cards == 5_001 })
        // The old hard-coded 8ms minimum alone cost over 40 seconds for this fixture.
        #expect(elapsed < .seconds(40))
        Attachment.record("5001 cards + folders + deck: \(elapsed)", named: "bulk-deletion-timing.txt")
    }

    @Test("Background preview retains study order, search, folder filtering and exact header counts")
    func previewParity() async throws {
        let (container, directory) = try fixture()
        defer { try? FileManager.default.removeItem(at: directory) }
        let context = container.mainContext, now = Date()
        let deck = Deck(name: "Preview fixture")
        let section = DeckSection(title: "Folder", deck: deck)
        let cards = (0..<480).map { index in
            let card = Flashcard(question: index.isMultiple(of: 17) ? "Needle \(index)" : "Card \(index)",
                correctAnswer: "Answer", deck: deck, section: index.isMultiple(of: 2) ? section : nil,
                cardType: index.isMultiple(of: 3) ? .anki : .multipleChoice)
            card.orderIndex = index
            if index.isMultiple(of: 5) { card.masteryScore = 3; card.lastReviewedDate = now }
            return card
        }
        deck.cards = cards; deck.sections = [section]; context.insert(deck); try context.save()
        let deckID = deck.id
        for filter in ["ALL", "NONE", section.id.uuidString] {
            for query in ["", "  NEEDLE "] {
                let summary = try await Task.detached {
                    let worker = LibraryDataWorker(modelContainer: container)
                    return try await worker.preview(deckID: deckID, search: query, section: filter, now: now)
                }.value
                let expected = DeckDetailSnapshot(cards: cards, searchText: query, selectedSectionFilter: filter, now: now)
                #expect(summary.cardCount == expected.cardCount && summary.dueCount == expected.dueCount)
                #expect(summary.masteredCount == expected.masteredCount && summary.sectionCounts == expected.sectionCounts)
                #expect(summary.cardIDs == expected.filteredCards.map(\.id))
                let firstPage = Array(summary.cardIDs.prefix(60))
                let visible = try context.fetch(FetchDescriptor<Flashcard>(predicate: #Predicate { firstPage.contains($0.id) }))
                #expect(Set(visible.map(\.id)) == Set(firstPage))
            }
        }
    }

    @Test("Anki preview cache refreshes edited HTML and handles malformed content")
    func ankiPreviewCache() async throws {
        let id = UUID()
        let front = AnkiCardContent(frontHTML: "First", backHTML: "Answer", css: "", mediaFolder: "", templateOrdinal: 0, noteType: "Basic", tags: [])
        var updated = front; updated.frontHTML = "Edited"
        let first = try JSONEncoder().encode(front), second = try JSONEncoder().encode(updated)
        let values = await Task.detached {
            [AnkiLibraryPreview.prepare(cardID: id, data: first).content?.frontHTML,
             AnkiLibraryPreview.prepare(cardID: id, data: second).content?.frontHTML,
             AnkiLibraryPreview.prepare(cardID: id, data: Data("bad".utf8)).content?.frontHTML]
        }.value
        #expect(values == ["First", "Edited", nil])
    }
}
