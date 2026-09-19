//
//  Deck.swift
//  LearnAlert
//
//  Created by Blake Miller on 2/19/26.
//

import Foundation
import SwiftData

enum FlashcardType: String, CaseIterable, Identifiable {
    case multipleChoice = "multiple_choice"
    case tapReveal = "tap_reveal"
    case matching = "matching"
    case fillBlank = "fill_blank"

    var id: String { rawValue }
    var title: String {
        switch self {
        case .multipleChoice: "Quiz Style"
        case .tapReveal: "Tap to Reveal"
        case .matching: "Match Pairs"
        case .fillBlank: "Fill in the Blank"
        }
    }
    var icon: String {
        switch self {
        case .multipleChoice: "list.bullet.circle"
        case .tapReveal: "rectangle.on.rectangle"
        case .matching: "arrow.left.arrow.right"
        case .fillBlank: "text.cursor"
        }
    }
}

@Model
class Deck {
    var id: UUID = UUID()
    var name: String = ""
    var colorHex: String = "#00FFFF"
    var deckType: String = "Quiz"
    var creationDate: Date = Date()
    var orderIndex: Int = 0
    var appearanceSeed: Int64?

    // AI & Source Context Caching Fields
    var sourceId: String?
    var sourceKind: String?
    var sourceName: String?
    var sourceText: String?
    var documentCoverageSummary: String?
    var chatHistoryData: Data?

    @Relationship(deleteRule: .cascade, originalName: "cards", inverse: \Flashcard.deck)
    private var storedCards: [Flashcard]?

    @Relationship(deleteRule: .cascade, originalName: "sections", inverse: \DeckSection.deck)
    private var storedSections: [DeckSection]?

    var cards: [Flashcard] {
        get { storedCards ?? [] }
        set { storedCards = newValue }
    }

    var sections: [DeckSection] {
        get { storedSections ?? [] }
        set { storedSections = newValue }
    }

    var totalReviews: Int {
        cards.reduce(0) { $0 + max($1.reviewCount, $1.lastReviewedDate != nil ? 1 : 0) }
    }

    var cycleStreak: Int {
        guard !cards.isEmpty else { return 0 }
        return totalReviews / cards.count
    }

    var cycleProgress: Double {
        guard !cards.isEmpty else { return 0 }
        let currentCycleReviews = totalReviews % cards.count
        return Double(currentCycleReviews) / Double(cards.count)
    }

    init(name: String, colorHex: String = "#00FFFF", deckType: String = "Quiz", orderIndex: Int = 0) {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.deckType = deckType
        self.creationDate = Date()
        self.orderIndex = orderIndex
        self.appearanceSeed = nil
        self.storedCards = []
        self.storedSections = []
    }

    @discardableResult
    func assignCardToSection(
        card: Flashcard,
        suggestedCategory: String?
    ) -> DeckSection? {
        let cleanName = (suggestedCategory ?? "General").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return nil }

        if let existing = sections.first(where: { $0.name.localizedCaseInsensitiveCompare(cleanName) == .orderedSame }) {
            card.section = existing
            return existing
        }

        let palette = [
            "#5B78C7", // Blue
            "#4D8B88", // Sage Teal
            "#758D54", // Olive Green
            "#A66F78", // Rose Berry
            "#A47D52", // Amber
            "#75689B", // Violet
            "#3B82F6", // Sky
            "#10B981"  // Emerald
        ]
        let colorHex = palette[sections.count % palette.count]
        let newSection = DeckSection(name: cleanName, colorHex: colorHex, orderIndex: sections.count)
        newSection.deck = self
        sections.append(newSection)
        card.section = newSection
        return newSection
    }
}

@Model
class DeckSection {
    var id: UUID = UUID()
    var name: String = ""
    var colorHex: String = "#00FFFF"
    var orderIndex: Int = 0
    var deck: Deck?

    @Relationship(deleteRule: .nullify, originalName: "cards", inverse: \Flashcard.section)
    private var storedCards: [Flashcard]?

    var cards: [Flashcard] {
        get { storedCards ?? [] }
        set { storedCards = newValue }
    }

    init(name: String, colorHex: String, orderIndex: Int = 0) {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.orderIndex = orderIndex
        self.storedCards = []
    }
}

@Model
class Flashcard {
    var id: UUID = UUID()
    var question: String = ""
    var options: [String] = []
    var correctAnswer: String = ""
    var hint: String = ""
    var cardTypeRawValue: String = ""
    var matchingLeftItems: [String] = []
    var matchingRightItems: [String] = []

    // Source Tracking & Categorization
    var sourceLocator: String?
    var sourceExcerpt: String?
    var tags: [String] = []

    var isNew: Bool = true
    var nextReviewDate: Date = Date()
    var easeFactor: Double = 2.5
    var interval: Int = 0

    // Learning signals used by the adaptive scheduler and study dashboard.
    var correctCount: Int = 0
    var incorrectCount: Int = 0
    var hintCount: Int = 0
    var skipCount: Int = 0
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var lastReviewedDate: Date?

    var deck: Deck?
    var section: DeckSection?

    init(
        question: String,
        options: [String],
        correctAnswer: String,
        hint: String = "",
        cardType: FlashcardType? = nil,
        matchingLeftItems: [String] = [],
        matchingRightItems: [String] = [],
        sourceLocator: String? = nil,
        sourceExcerpt: String? = nil,
        tags: [String] = []
    ) {
        self.id = UUID()
        self.question = question
        self.options = options
        self.correctAnswer = correctAnswer
        self.hint = hint
        self.cardTypeRawValue = cardType?.rawValue ?? ""
        self.matchingLeftItems = matchingLeftItems
        self.matchingRightItems = matchingRightItems
        self.sourceLocator = sourceLocator
        self.sourceExcerpt = sourceExcerpt
        self.tags = tags
        self.isNew = true
        self.nextReviewDate = Date()
        self.easeFactor = 2.5
        self.interval = 0
    }

    var reviewCount: Int { correctCount + incorrectCount }

    var cardType: FlashcardType {
        get { FlashcardType(rawValue: cardTypeRawValue) ?? (options.count >= 2 ? .multipleChoice : .tapReveal) }
        set { cardTypeRawValue = newValue.rawValue }
    }

    func resetProgress() {
        isNew = true
        nextReviewDate = Date()
        easeFactor = 2.5
        interval = 0
        correctCount = 0
        incorrectCount = 0
        hintCount = 0
        skipCount = 0
        currentStreak = 0
        longestStreak = 0
        lastReviewedDate = nil
    }

    var accuracy: Double {
        guard reviewCount > 0 else { return 0 }
        return Double(correctCount) / Double(reviewCount)
    }

    var studyPriority: Double {
        let errorPressure = Double(incorrectCount * 3 + hintCount * 2 + skipCount * 2)
        let confidence = Double(correctCount) + Double(currentStreak) * 0.5
        return errorPressure - confidence
    }

    func processAnswer(isCorrect: Bool) {
        lastReviewedDate = Date()

        if isCorrect {
            correctCount += 1
            currentStreak += 1
            longestStreak = max(longestStreak, currentStreak)
            easeFactor = min(3.0, easeFactor + 0.05)

            if interval == 0 { interval = 1 }
            else if interval == 1 { interval = 6 }
            else { interval = Int(round(Double(interval) * easeFactor)) }
            isNew = false
        } else {
            incorrectCount += 1
            currentStreak = 0
            interval = 0
            easeFactor = max(1.3, easeFactor - 0.2)
        }

        if let nextDate = Calendar.current.date(byAdding: .day, value: interval, to: Date()) {
            nextReviewDate = nextDate
        }
    }

    func recordHintUsed() {
        hintCount += 1
    }

    func recordSkip() {
        skipCount += 1
        currentStreak = 0
        nextReviewDate = Date()
    }
}

struct AlertSoundOption: Identifiable, Hashable, Sendable {
    let id: String
    let name: String

    static let allSounds: [AlertSoundOption] = [
        AlertSoundOption(id: "Default", name: "Default"),
        AlertSoundOption(id: "alert1.wav", name: "Level-up"),
        AlertSoundOption(id: "alert2.wav", name: "Pulse"),
        AlertSoundOption(id: "alert3.wav", name: "Breeze"),
        AlertSoundOption(id: "alert4.wav", name: "Echo"),
        AlertSoundOption(id: "alert5.wav", name: "Beacon")
    ]

    static func displayName(for id: String) -> String {
        allSounds.first { $0.id == id }?.name ?? id.replacingOccurrences(of: ".wav", with: "")
    }
}
