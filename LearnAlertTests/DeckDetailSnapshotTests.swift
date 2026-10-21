import Foundation
import Testing
@testable import LearnAlert

@MainActor
@Suite("Deck detail snapshots")
struct DeckDetailSnapshotTests {
    @Test("Header counts include regular and Anki review state without depending on the active filter")
    func headerStatistics() {
        let now = Date()
        let section = DeckSection(title: "One folder")
        let fresh = Flashcard(question: "New card", section: section)
        let known = Flashcard(question: "Known card", section: section)
        known.masteryScore = 3; known.lastReviewedDate = now
        let ankiKnown = Flashcard(question: "Known Anki", cardType: .anki)
        var knownState = AnkiReviewState()
        knownState.interval = 7 * AnkiReviewScheduling.day
        knownState.dueDate = now.addingTimeInterval(86_400)
        ankiKnown.ankiReviewState = knownState
        let ankiDue = Flashcard(question: "Due Anki", cardType: .anki)
        var dueState = AnkiReviewState()
        dueState.interval = 60; dueState.dueDate = now
        ankiDue.ankiReviewState = dueState
        let cards = [fresh, known, ankiKnown, ankiDue]
        let snapshot = DeckDetailSnapshot(cards: cards, searchText: "Known card", selectedSectionFilter: section.id.uuidString, now: now)
        #expect(snapshot.cardCount == 4)
        #expect(snapshot.dueCount == cards.filter { $0.nextReviewDate <= now }.count)
        #expect(snapshot.masteredCount == cards.filter { $0.interval >= 7 }.count)
        #expect(snapshot.dueCount == 2 && snapshot.masteredCount == 2)
        #expect(snapshot.sectionCounts[section.id] == 2 && snapshot.uncategorizedCount == 2)
        #expect(snapshot.filteredCards.map(\.id) == [known.id])
    }

    @Test("Search finds question, answer, choice, hint, and matching text while preserving order and folder groups")
    func searchAndGrouping() {
        let a = DeckSection(title: "First"), b = DeckSection(title: "Second")
        let question = Flashcard(question: "Needle in question", section: a)
        let answer = Flashcard(question: "Answer", correctAnswer: "NEEDLE", section: b)
        let option = Flashcard(question: "Choice", options: ["Needle"], section: a)
        let hint = Flashcard(question: "Hint", hint: "needle")
        let left = Flashcard(question: "Left", section: b, cardType: .matching,
            matchingPairs: [MatchingPair(leftItem: "Needle", rightItem: "Left answer")])
        let right = Flashcard(question: "Right", cardType: .matching,
            matchingPairs: [MatchingPair(leftItem: "Right prompt", rightItem: "Needle")])
        let unmatched = Flashcard(question: "No match", section: a)
        let cards = [question, answer, option, hint, left, right, unmatched]
        let snapshot = DeckDetailSnapshot(cards: cards, searchText: "  NeEdLe\n", selectedSectionFilter: "ALL")
        #expect(snapshot.filteredCards.map(\.id) == Array(cards.dropLast()).map(\.id))
        #expect(snapshot.groupedCards[a.id]?.map(\.id) == [question.id, option.id])
        #expect(snapshot.groupedCards[b.id]?.map(\.id) == [answer.id, left.id])
        #expect(snapshot.uncategorizedCards.map(\.id) == [hint.id, right.id])
        #expect(snapshot.sectionCounts[a.id] == 3)
        let folder = DeckDetailSnapshot(cards: cards, searchText: "needle", selectedSectionFilter: b.id.uuidString)
        #expect(folder.filteredCards.map(\.id) == [answer.id, left.id])
        let unsorted = DeckDetailSnapshot(cards: cards, searchText: "", selectedSectionFilter: "NONE")
        #expect(unsorted.filteredCards.map(\.id) == [hint.id, right.id])
        let whitespace = DeckDetailSnapshot(cards: cards, searchText: " \n ", selectedSectionFilter: "ALL")
        #expect(whitespace.filteredCards.map(\.id) == cards.map(\.id))
    }

    @Test("Render-time sharing gates preserve provenance and developer Anki controls")
    func provenanceGates() {
        let original = Deck(name: "Original")
        #expect(original.canPresentCommunitySharing)
        let downloaded = Deck(name: "Downloaded")
        downloaded.sourceCommunityID = UUID().uuidString
        let builtIn = Deck(name: "Built-in"); builtIn.sourcePremadeID = "test-built-in"
        let course = Deck(name: "Course", deckType: "Course")
        for deck in [downloaded, builtIn, course] {
            #expect(!deck.canPresentCommunitySharing)
            #expect(deck.provenanceSharingRestriction(allowAnkiUploads: true) != nil)
        }
        let anki = Deck(name: "Imported")
        anki.sourceKind = "anki"
        #expect(anki.canPresentCommunitySharing)
        #expect(anki.provenanceSharingRestriction(allowAnkiUploads: false) == "Uploading decks imported from Anki are not supported yet")
        #expect(anki.provenanceSharingRestriction(allowAnkiUploads: true) == nil)
        let legacyAnki = Deck(name: "Old import")
        legacyAnki.cards = [Flashcard(question: "Old Anki card", cardType: .anki)]
        #expect(legacyAnki.canPresentCommunitySharing)
        #expect(legacyAnki.sharingRestriction(allowAnkiUploads: false) != nil)
    }

    @Test("Legacy built-in content is still rejected by full publish validation")
    func legacyPublishingProtection() throws {
        let source = try #require(PremadeDeckCatalog.bundledDecks.first)
        let deck = Deck(name: "Renamed legacy import")
        deck.cards = source.cards.reversed().map {
            Flashcard(question: $0.question.uppercased(), correctAnswer: $0.correctAnswer,
                cardType: $0.cardType, matchingLeftItems: $0.matchingLeftItems, matchingRightItems: $0.matchingRightItems)
        }
        deck.cards.append(Flashcard(question: "Extra original question", correctAnswer: "Extra answer"))
        #expect(deck.canPresentCommunitySharing)
        #expect(!deck.canShareToCommunity)
        #expect(deck.sharingRestriction(allowAnkiUploads: true) == "Built-in decks can’t be published to the community.")
    }
}
