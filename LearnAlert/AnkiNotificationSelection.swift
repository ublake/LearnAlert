import Foundation
import SwiftData

/// A compact projection of notification learning. HTML and media are fetched
/// only after a card has been chosen.
@MainActor
enum AnkiNotificationSelection {
    struct Candidate {
        let id: UUID
        let order: Int
        let isNew: Bool
        let isLearning: Bool
        let due: Date

        var priority: Int { isNew ? 2 : isLearning ? 0 : 1 }
        func eligible(at date: Date) -> Bool { isNew || due <= date }
    }

    static func candidates(deckID: UUID, sectionID: UUID?, in context: ModelContext) throws -> [Candidate] {
        let predicate: Predicate<Flashcard>
        if let sectionID {
            predicate = #Predicate { $0.deck?.id == deckID && $0.section?.id == sectionID && $0.cardTypeRaw == "anki" }
        } else {
            predicate = #Predicate { $0.deck?.id == deckID && $0.cardTypeRaw == "anki" }
        }
        var descriptor = FetchDescriptor<Flashcard>(predicate: predicate,
            sortBy: [SortDescriptor(\Flashcard.orderIndex)])
        descriptor.propertiesToFetch = [\.id, \.orderIndex, \.ankiReviewStateData, \.reviewCount,
                                        \.lastReviewedDate, \.masteryScore]
        var values: [Candidate] = []
        try context.enumerate(descriptor, batchSize: 200) { card in
            let state = card.ankiReviewState
            values.append(Candidate(id: card.id, order: card.orderIndex, isNew: card.isNew,
                isLearning: state.phase != .review, due: state.dueDate))
        }
        return values
    }

    static func next(in candidates: [Candidate], at date: Date = Date(), excluding: Set<UUID> = []) -> UUID? {
        candidates.lazy.filter { !excluding.contains($0.id) && $0.eligible(at: date) }.min { left, right in
            if left.priority != right.priority { return left.priority < right.priority }
            if !left.isNew && left.due != right.due { return left.due < right.due }
            if left.order != right.order { return left.order < right.order }
            return left.id.uuidString < right.id.uuidString
        }?.id
    }

    static func nextCard(deckID: UUID, sectionID: UUID?, excluding: Set<UUID>,
                         at date: Date = Date(), in context: ModelContext) throws -> Flashcard? {
        guard let id = next(in: try candidates(deckID: deckID, sectionID: sectionID, in: context),
                            at: date, excluding: excluding) else { return nil }
        return try context.fetch(FetchDescriptor<Flashcard>(predicate: #Predicate { $0.id == id })).first
    }

    static func isAnkiOnly(deckID: UUID, sectionID: UUID?, in context: ModelContext) throws -> Bool {
        let predicate: Predicate<Flashcard>
        if let sectionID {
            predicate = #Predicate { $0.deck?.id == deckID && $0.section?.id == sectionID && $0.cardTypeRaw != "anki" }
        } else {
            predicate = #Predicate { $0.deck?.id == deckID && $0.cardTypeRaw != "anki" }
        }
        return try context.fetchCount(FetchDescriptor<Flashcard>(predicate: predicate)) == 0
    }

    static func ordinaryCards(deckID: UUID, sectionID: UUID?, in context: ModelContext) throws -> [Flashcard] {
        let predicate: Predicate<Flashcard>
        if let sectionID {
            predicate = #Predicate { $0.deck?.id == deckID && $0.section?.id == sectionID && $0.cardTypeRaw != "anki" }
        } else {
            predicate = #Predicate { $0.deck?.id == deckID && $0.cardTypeRaw != "anki" }
        }
        let descriptor = FetchDescriptor<Flashcard>(predicate: predicate, sortBy: [SortDescriptor(\Flashcard.orderIndex)])
        var cards: [Flashcard] = []
        try context.enumerate(descriptor, batchSize: 200) { cards.append($0) }
        return cards.sorted {
            $0.orderIndex == $1.orderIndex ? $0.id.uuidString < $1.id.uuidString : $0.orderIndex < $1.orderIndex
        }
    }
}
