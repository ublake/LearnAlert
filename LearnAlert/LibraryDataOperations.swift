import Foundation
import SwiftData

nonisolated struct LibraryDeletionProgress: Sendable {
    let fraction: Double
    let message: String
    let cards: Int
    let decks: Int
}

nonisolated struct LibraryDeletionResult: Sendable {
    let cards: Int
    let decks: Int
}

nonisolated struct DeckPreviewSummary: Sendable {
    var cardCount = 0
    var dueCount = 0
    var masteredCount = 0
    var sectionCounts: [UUID: Int] = [:]
    var uncategorizedCount = 0
    var cardIDs: [UUID] = []
}

/// Constructed in a detached task so database scans and bulk changes never run
/// on the UI executor. Only counts and IDs cross back to the view's context.
@ModelActor
actor LibraryDataWorker {
    func deleteAll(progress: @Sendable (LibraryDeletionProgress) async -> Void) async throws -> LibraryDeletionResult {
        modelContext.autosaveEnabled = false
        let cards = try modelContext.fetchCount(FetchDescriptor<Flashcard>())
        let decks = try modelContext.fetchCount(FetchDescriptor<Deck>())
        await progress(.init(fraction: 0.1, message: "Removing cards", cards: cards, decks: decks))
        do {
            // Store-level deletes avoid loading card HTML, media and relationship
            // arrays, as well as thousands of individual observation updates.
            try modelContext.delete(model: Flashcard.self)
            await progress(.init(fraction: 0.7, message: "Removing folders and decks", cards: cards, decks: decks))
            try modelContext.delete(model: DeckSection.self)
            try modelContext.delete(model: Deck.self)
            await progress(.init(fraction: 0.9, message: "Saving your library", cards: cards, decks: decks))
            try modelContext.save()
            await progress(.init(fraction: 1, message: "Done", cards: cards, decks: decks))
            return .init(cards: cards, decks: decks)
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    func preview(deckID: UUID, search: String, section: String, now: Date = Date()) throws -> DeckPreviewSummary {
        var descriptor = FetchDescriptor<Flashcard>(predicate: #Predicate { $0.deck?.id == deckID },
            sortBy: [SortDescriptor(\Flashcard.orderIndex)])
        // In particular, do not fault the external HTML/CSS payload just to count
        // cards or locate a search result. Visible rows request that separately.
        descriptor.propertiesToFetch = [\.id, \.orderIndex, \.section, \.question, \.correctAnswer,
            \.hint, \.optionsData, \.matchingPairsData, \.cardTypeRaw, \.ankiReviewStateData,
            \.reviewCount, \.masteryScore, \.lastReviewedDate]
        var summary = DeckPreviewSummary()
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let sectionID = UUID(uuidString: section)
        try modelContext.enumerate(descriptor, batchSize: 256) { card in
            try Task.checkCancellation()
            summary.cardCount += 1
            if let id = card.section?.id { summary.sectionCounts[id, default: 0] += 1 }
            else { summary.uncategorizedCount += 1 }
            if card.cardType == .anki {
                let state = card.ankiReviewState
                if state.dueDate <= now { summary.dueCount += 1 }
                if state.interval >= 7 * AnkiReviewScheduling.day { summary.masteredCount += 1 }
            } else {
                if card.nextReviewDate <= now { summary.dueCount += 1 }
                if card.interval >= 7 { summary.masteredCount += 1 }
            }
            if section == "NONE", card.section != nil { return }
            if let sectionID, card.section?.id != sectionID { return }
            if !query.isEmpty && !DeckDetailSnapshot.matches(card, query: query) { return }
            summary.cardIDs.append(card.id)
        }
        return summary
    }
}
