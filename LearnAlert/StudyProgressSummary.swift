import Foundation

/// Read-only statistics for the ordinary decks in the library.
@MainActor
struct StudyProgressSummary {
    struct DeckProgress: Identifiable {
        let id: UUID
        let name: String
        let colorHex: String
        let isCommunity: Bool
        let cardCount: Int
        let reviewedCardCount: Int
        let masteredCardCount: Int
        let masteryFraction: Double
    }

    let decks: [DeckProgress]
    let reviewCount: Int
    let cardCount: Int
    let reviewedCardCount: Int
    let masteredCardCount: Int
    let quizReviewCount: Int
    let quizCorrectCount: Int

    var learningCardCount: Int { max(0, reviewedCardCount - masteredCardCount) }
    var newCardCount: Int { max(0, cardCount - reviewedCardCount) }
    var quizAccuracy: Double? {
        quizReviewCount > 0 ? Double(quizCorrectCount) / Double(quizReviewCount) : nil
    }

    init(decks sourceDecks: [Deck]) {
        var seenDeckIDs = Set<UUID>()
        let ordinaryDecks = sourceDecks.filter { seenDeckIDs.insert($0.id).inserted }
        var seenCardIDs = Set<UUID>()
        let ordinaryCards = ordinaryDecks.flatMap(\.cards).filter { seenCardIDs.insert($0.id).inserted }
        self.decks = ordinaryDecks.map { deck in
            let cards = deck.cards
            return DeckProgress(id: deck.id, name: deck.name, colorHex: deck.colorHex,
                isCommunity: deck.sourceCommunityID != nil,
                cardCount: cards.count,
                reviewedCardCount: cards.filter { $0.reviewCount > 0 || $0.masteryScore > 0 }.count,
                masteredCardCount: cards.filter { $0.masteryScore >= 3 }.count,
                masteryFraction: Double(cards.reduce(0) { $0 + min(3, max(0, $1.masteryScore)) }) / Double(max(1, cards.count * 3)))
        }
        reviewCount = ordinaryCards.reduce(0) { $0 + max(0, $1.reviewCount) }
        cardCount = ordinaryCards.count
        reviewedCardCount = ordinaryCards.filter { $0.reviewCount > 0 || $0.masteryScore > 0 }.count
        masteredCardCount = ordinaryCards.filter { $0.masteryScore >= 3 }.count

        // Read-through and self-rated cards acknowledge study; they do not
        // provide an objective right/wrong quiz result.
        let quizCards = ordinaryCards.filter { [.multipleChoice, .matching, .fillBlank].contains($0.cardType) }
        quizReviewCount = quizCards.reduce(0) { $0 + max(0, $1.reviewCount) }
        quizCorrectCount = quizCards.reduce(0) { $0 + min(max(0, $1.correctCount), max(0, $1.reviewCount)) }
    }
}
