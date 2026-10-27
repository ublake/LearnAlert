import SwiftUI
//
//  Deck.swift
//  LearnAlert
//
//  Created by Blake Miller on 2/19/26.
//

import Foundation
import SwiftData
import CryptoKit

enum FlashcardType: String, Codable, CaseIterable, Identifiable {
    case vocabulary = "vocabulary"
    case multipleChoice = "multiple_choice"
    case tapReveal = "tap_reveal"
    case matching = "matching"
    case fillBlank = "fill_blank"
    case images = "images"
    case anki = "anki"

    var id: String { rawValue }
    var title: String {
        switch self {
        case .vocabulary: "Vocabulary"
        case .multipleChoice: "Quiz Style"
        case .tapReveal: "Tap to Reveal"
        case .matching: "Match Pairs"
        case .fillBlank: "Fill in the Blank"
        case .images: "Images"
        case .anki: "Anki"
        }
    }
    var icon: String {
        switch self {
        case .vocabulary: "character.book.closed.fill"
        case .multipleChoice: "list.bullet.circle"
        case .tapReveal: "rectangle.on.rectangle"
        case .matching: "arrow.left.arrow.right"
        case .fillBlank: "text.cursor"
        case .images: "photo.on.rectangle"
        case .anki: "rectangle.stack.badge.play"
        }
    }

    var subtitle: String {
        switch self {
        case .multipleChoice: "Practice with 4 options and immediate feedback"
        case .tapReveal: "Front-and-back flip with self assessment"
        case .vocabulary: "Word, pronunciation, and dictionary definition"
        case .fillBlank: "Fill a sentence by typing or choosing an answer"
        case .matching: "Connect paired terms and definitions"
        case .images: "Review one picture or reveal an image on the back"
        case .anki: "Imported Anki templates, formatting, and media"
        }
    }

    var isReviewOnly: Bool { self == .vocabulary || self == .images }
}

struct DeckLibrarySummary: Equatable {
    let cardCount: Int
    let cycleStreak: Int
    let cycleProgress: Double
    let masteredCount: Int
    let learningCount: Int
    let needToLearnCount: Int
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
    var sourcePremadeID: String?
    var sourceCommunityID: String?
    var sourceAnkiDeckID: String?
    var publishedCommunityID: String?
    var communityCategory: String?
    var communityDescription: String?
    var alertSettingsData: Data?
    var bundleUnlockedLevelID: String?
    /// One-time archive import must never undo a later explicit progress reset.
    var legacyLanguageHistoryImported: Bool?

    var alertSettings: DeckAlertSettings? {
        get { alertSettingsData.flatMap { try? JSONDecoder().decode(DeckAlertSettings.self, from: $0) } }
        set { alertSettingsData = newValue.flatMap { try? JSONEncoder().encode($0) } }
    }

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
        get {
            // SwiftData property access is expensive inside a sort comparator.
            // Read each order value once before comparing plain integers.
            (storedCards ?? []).map { ($0.orderIndex, $0) }
                .sorted { $0.0 < $1.0 }.map { $0.1 }
        }
        set {
            storedCards = newValue
        }
    }

    var sections: [DeckSection] {
        get {
            storedSections?.sorted(by: { $0.orderIndex < $1.orderIndex }) ?? []
        }
        set {
            storedSections = newValue
        }
    }

    /// Counts do not need study order or faults for each card's orderIndex.
    var cardCount: Int { storedCards?.count ?? 0 }

    /// Home uses one unordered traversal instead of sorting the entire deck for
    /// each count, progress label, progress color, and streak label.
    var librarySummary: DeckLibrarySummary {
        let cards = storedCards ?? []
        var streak = 0
        var totalMastery = 0
        var mastered = 0
        var learning = 0
        for card in cards {
            streak = max(streak, card.streak)
            totalMastery += min(card.masteryScore, 3)
            if card.masteryScore >= 3 { mastered += 1 }
            else if card.reviewCount > 0 || card.masteryScore > 0 { learning += 1 }
        }
        return DeckLibrarySummary(cardCount: cards.count, cycleStreak: streak,
            cycleProgress: cards.isEmpty ? 0 : Double(totalMastery) / (Double(cards.count) * 3),
            masteredCount: mastered, learningCount: learning,
            needToLearnCount: cards.count - mastered - learning)
    }

    var cycleStreak: Int {
        storedCards?.reduce(0) { max($0, $1.streak) } ?? 0
    }

    var cycleProgress: Double {
        let cards = storedCards ?? []
        guard !cards.isEmpty else { return 0.0 }
        let totalMastery = cards.reduce(0) { $0 + min($1.masteryScore, 3) }
        let maxPossibleMastery = cards.count * 3
        return Double(totalMastery) / Double(maxPossibleMastery)
    }

    init(name: String, colorHex: String = "#00FFFF", deckType: String = "Quiz", appearanceSeed: Int64? = nil, orderIndex: Int = 0) {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.deckType = deckType
        self.creationDate = Date()
        self.orderIndex = orderIndex
        self.appearanceSeed = appearanceSeed ?? Int64.random(in: 1...Int64.max)
        self.storedCards = []
        self.storedSections = []
    }

    func assignCardToSection(card: Flashcard, suggestedCategory: String?) {
        guard let cat = suggestedCategory?.trimmingCharacters(in: .whitespacesAndNewlines), !cat.isEmpty else { return }
        if let existing = sections.first(where: { $0.title.caseInsensitiveCompare(cat) == .orderedSame || $0.name.caseInsensitiveCompare(cat) == .orderedSame }) {
            card.section = existing
            if !existing.cards.contains(where: { $0.id == card.id }) {
                existing.cards.append(card)
            }
        } else {
            let sectionColors = ["#00FFFF", "#FF007F", "#7928CA", "#0070F3", "#38EF7D", "#FF9900"]
            let color = sectionColors[sections.count % sectionColors.count]
            let newSection = DeckSection(title: cat, summary: "", colorHex: color, orderIndex: sections.count, deck: self)
            sections.append(newSection)
            card.section = newSection
            newSection.cards.append(card)
        }
    }
}

@Model
class DeckSection {
    var id: UUID = UUID()
    var title: String = ""
    var summary: String = ""
    var colorHex: String = "#00FFFF"
    var orderIndex: Int = 0
    var sourcePageNumber: Int?
    var sourceCourseUnitID: String?

    var name: String {
        get { title }
        set { title = newValue }
    }

    var deck: Deck?

    @Relationship(deleteRule: .nullify, inverse: \Flashcard.section)
    private var storedCards: [Flashcard]?

    var cards: [Flashcard] {
        get {
            (storedCards ?? []).map { ($0.orderIndex, $0) }
                .sorted { $0.0 < $1.0 }.map { $0.1 }
        }
        set {
            storedCards = newValue
        }
    }

    init(title: String = "", name: String? = nil, summary: String = "", colorHex: String = "#00FFFF", orderIndex: Int = 0, sourcePageNumber: Int? = nil, deck: Deck? = nil) {
        self.id = UUID()
        self.title = name ?? title
        self.summary = summary
        self.colorHex = colorHex
        self.orderIndex = orderIndex
        self.sourcePageNumber = sourcePageNumber
        self.deck = deck
        self.storedCards = []
    }
}

@Model
class Flashcard {
    var id: UUID = UUID()
    var question: String = ""
    var optionsData: Data = Data()
    var correctAnswer: String = ""
    var hint: String = ""
    var orderIndex: Int = 0
    var cardTypeRaw: String = FlashcardType.multipleChoice.rawValue
    var matchingPairsData: Data = Data()
    var promptImageName: String?
    var answerImageName: String?
    var promptAudioName: String?
    var readingPrompt: String?
    var fieldMediaData: Data?
    var correctOptionIndex: Int?
    @Attribute(.externalStorage) var ankiContentData: Data?
    /// Optional additive storage keeps existing local and CloudKit cards migratable.
    var ankiReviewStateData: Data?
    var sourceAnkiCardID: String?
    var sourceCourseCardID: String?
    /// Authored topic identity survives flattening a language level into one study deck.
    var sourceCourseTopicID: String?
    var sourceCourseTopicImportance: Int?

    /// Also covers topic decks saved before the course copy was simplified.
    var studyQuestion: String {
        guard sourceCourseCardID != nil else { return question }
        return LanguageQuestionText.concise(question, hasPromptImage: promptImageName?.isEmpty == false)
    }

    var ankiContent: AnkiCardContent? {
        get { ankiContentData.flatMap { try? JSONDecoder().decode(AnkiCardContent.self, from: $0) } }
        set { ankiContentData = newValue.flatMap { try? JSONEncoder().encode($0) } }
    }
    var ankiReviewState: AnkiReviewState {
        get {
            if let data = ankiReviewStateData,
               let state = try? JSONDecoder().decode(AnkiReviewState.self, from: data) { return state }
            return AnkiReviewScheduling.migratingLegacy(reviewCount: reviewCount,
                lastReviewedDate: lastReviewedDate, nextReviewDate: legacyNextReviewDate,
                interval: legacyReviewInterval)
        }
        set { ankiReviewStateData = try? JSONEncoder().encode(newValue) }
    }

    func ankiReviewOptions(at date: Date = Date()) -> [AnkiReviewOption] {
        AnkiReviewScheduling.options(for: ankiReviewState, at: date)
    }

    @discardableResult
    func recordAnkiReview(rating: AnkiReviewRating, at date: Date = Date()) -> AnkiReviewOption {
        let option = AnkiReviewScheduling.option(for: rating, state: ankiReviewState, at: date)
        guard cardType == .anki else { return option }
        recordAggregateReview(wasCorrect: rating.wasCorrect, at: date)
        // The aggregate powers the app's Known/mastered summaries. Keep it in
        // step with Anki graduation rather than requiring three Easy ratings.
        if option.nextState.phase == .review { masteryScore = 3 }
        else if rating == .again { masteryScore = 0 }
        else { masteryScore = min(2, masteryScore) }
        ankiReviewState = option.nextState
        return option
    }
    var optionImageNamesData: Data = Data()

    var fieldMedia: [String: CardFieldMedia] {
        get {
            var fields = fieldMediaData.flatMap { try? JSONDecoder().decode([String: CardFieldMedia].self, from: $0) } ?? [:]
            // Existing cards and community downloads retain their original attachment columns.
            fields["prompt", default: .init()].image = promptImageName
            fields["prompt", default: .init()].audio = promptAudioName
            fields["answer", default: .init()].image = answerImageName
            for (index, name) in optionImageNames.enumerated() { fields["option:\(index)", default: .init()].image = name.isEmpty ? nil : name }
            return fields.filter { !$0.value.isEmpty }
        }
        set {
            let fields = newValue.filter { !$0.value.isEmpty }
            fieldMediaData = try? JSONEncoder().encode(fields)
            promptImageName = fields["prompt"]?.image
            promptAudioName = fields["prompt"]?.audio
            answerImageName = fields["answer"]?.image
            optionImageNames = options.indices.map { fields["option:\($0)"]?.image ?? "" }
        }
    }

    var resolvedCorrectOptionIndex: Int? {
        if let correctOptionIndex, options.indices.contains(correctOptionIndex) { return correctOptionIndex }
        return options.firstIndex(of: correctAnswer)
    }

    // Study state
    var reviewCount: Int = 0
    var correctCount: Int = 0
    var masteryScore: Int = 0
    var lastReviewedDate: Date?
    var streak: Int = 0
    var longestStreak: Int = 0
    var deck: Deck?
    var section: DeckSection?

    var cardType: FlashcardType {
        get {
            FlashcardType(rawValue: cardTypeRaw) ?? .multipleChoice
        }
        set {
            cardTypeRaw = newValue.rawValue
        }
    }

    var options: [String] {
        get {
            (try? JSONDecoder().decode([String].self, from: optionsData)) ?? []
        }
        set {
            optionsData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    var optionImageNames: [String] {
        get {
            (try? JSONDecoder().decode([String].self, from: optionImageNamesData)) ?? []
        }
        set {
            optionImageNamesData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    var matchingPairs: [MatchingPair] {
        get {
            (try? JSONDecoder().decode([MatchingPair].self, from: matchingPairsData)) ?? []
        }
        set {
            matchingPairsData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    var matchingLeftItems: [String] {
        get {
            matchingPairs.map(\.leftItem)
        }
        set {
            var pairs = matchingPairs
            for (idx, item) in newValue.enumerated() {
                if idx < pairs.count {
                    pairs[idx].leftItem = item
                } else {
                    pairs.append(MatchingPair(leftItem: item, rightItem: ""))
                }
            }
            if newValue.count < pairs.count {
                pairs = Array(pairs.prefix(newValue.count))
            }
            matchingPairs = pairs
        }
    }

    var matchingRightItems: [String] {
        get {
            matchingPairs.map(\.rightItem)
        }
        set {
            var pairs = matchingPairs
            for (idx, item) in newValue.enumerated() {
                if idx < pairs.count {
                    pairs[idx].rightItem = item
                } else {
                    pairs.append(MatchingPair(leftItem: "", rightItem: item))
                }
            }
            if newValue.count < pairs.count {
                pairs = Array(pairs.prefix(newValue.count))
            }
            matchingPairs = pairs
        }
    }

    init(
        question: String,
        options: [String] = [],
        correctAnswer: String = "",
        hint: String = "",
        deck: Deck? = nil,
        section: DeckSection? = nil,
        cardType: FlashcardType = .multipleChoice,
        matchingPairs: [MatchingPair] = [],
        matchingLeftItems: [String] = [],
        matchingRightItems: [String] = [],
        promptImageName: String? = nil,
        answerImageName: String? = nil,
        optionImageNames: [String] = [],
        sourceLocator: String? = nil,
        sourceExcerpt: String? = nil,
        tags: [String] = []
    ) {
        self.id = UUID()
        self.question = question
        self.correctAnswer = correctAnswer
        self.hint = hint
        self.orderIndex = 0
        self.cardTypeRaw = cardType.rawValue
        self.deck = deck
        self.section = section
        self.promptImageName = promptImageName
        self.answerImageName = answerImageName
        self.optionsData = (try? JSONEncoder().encode(options)) ?? Data()
        self.optionImageNamesData = (try? JSONEncoder().encode(optionImageNames)) ?? Data()
        
        if !matchingPairs.isEmpty {
            self.matchingPairsData = (try? JSONEncoder().encode(matchingPairs)) ?? Data()
        } else if !matchingLeftItems.isEmpty || !matchingRightItems.isEmpty {
            var pairs: [MatchingPair] = []
            let count = max(matchingLeftItems.count, matchingRightItems.count)
            for i in 0..<count {
                let left = i < matchingLeftItems.count ? matchingLeftItems[i] : ""
                let right = i < matchingRightItems.count ? matchingRightItems[i] : ""
                pairs.append(MatchingPair(leftItem: left, rightItem: right))
            }
            self.matchingPairsData = (try? JSONEncoder().encode(pairs)) ?? Data()
        } else {
            self.matchingPairsData = Data()
        }
    }

    func recordReview(wasCorrect: Bool) {
        if cardType == .anki {
            recordAnkiReview(rating: wasCorrect ? .good : .again)
            return
        }
        recordAggregateReview(wasCorrect: wasCorrect, at: Date())
        // Whole-collection alerts and topic study share the same authored card.
        // Copy review state only; each deck keeps its own editable presentation.
        if deck?.sourceKind == "managedLanguage", let courseID = deck?.sourceId,
           let sourceID = sourceCourseCardID, let context = modelContext {
            let descriptor = FetchDescriptor<Flashcard>(predicate: #Predicate { $0.sourceCourseCardID == sourceID })
            for sibling in (try? context.fetch(descriptor)) ?? [] where sibling.id != id && sibling.deck?.sourceKind == "managedLanguage" && sibling.deck?.sourceId == courseID {
                sibling.reviewCount = reviewCount; sibling.correctCount = correctCount
                sibling.masteryScore = masteryScore; sibling.lastReviewedDate = lastReviewedDate
                sibling.streak = streak; sibling.longestStreak = longestStreak
            }
        }
    }

    private func recordAggregateReview(wasCorrect: Bool, at date: Date) {
        reviewCount += 1
        lastReviewedDate = date
        if wasCorrect {
            correctCount += 1
            streak += 1
            if streak > longestStreak {
                longestStreak = streak
            }
            masteryScore = min(masteryScore + 1, 3)
        } else {
            streak = 0
            masteryScore = max(masteryScore - 1, 0)
        }
    }

    var accuracy: Double {
        guard reviewCount > 0 else { return 0.0 }
        return Double(correctCount) / Double(reviewCount)
    }

    var isNew: Bool {
        reviewCount == 0
    }

    var interval: Int {
        if cardType == .anki { return max(0, Int(ankiReviewState.interval / AnkiReviewScheduling.day)) }
        switch masteryScore {
        case 0: return 0
        case 1: return 1
        case 2: return 3
        case 3: return 7
        default: return 14
        }
    }

    func processAnswer(isCorrect: Bool) {
        recordReview(wasCorrect: isCorrect)
    }

    func recordHintUsed() {
        // Record hint usage
    }

    func recordSkip() {
        // Record skip
    }

    var isLearned: Bool {
        masteryScore >= 3
    }

    var nextReviewDate: Date {
        cardType == .anki ? ankiReviewState.dueDate : legacyNextReviewDate
    }

    private var legacyNextReviewDate: Date {
        guard let last = lastReviewedDate else { return Date.distantPast }
        return last.addingTimeInterval(legacyReviewInterval)
    }

    private var legacyReviewInterval: TimeInterval {
        let hours: Double
        switch masteryScore {
        case 0: hours = 1
        case 1: hours = 4
        case 2: hours = 12
        case 3: hours = 24
        default: hours = 48
        }
        return hours * 3600
    }

    var tags: [String] {
        if let secName = section?.name { return [secName] }
        return []
    }

    var sourceExcerpt: String? {
        get { nil }
        set { }
    }

    var sourceLocator: String? {
        get { section?.name }
        set { }
    }

    var studyPriority: Double {
        if isNew { return 100.0 }
        let overdueSeconds = Date().timeIntervalSince(nextReviewDate)
        let masteryWeight = Double(3 - min(masteryScore, 3)) * 10.0
        return masteryWeight + (overdueSeconds / 3600.0)
    }

    func resetProgress() {
        reviewCount = 0
        correctCount = 0
        masteryScore = 0
        streak = 0
        longestStreak = 0
        lastReviewedDate = nil
        ankiReviewStateData = nil
    }
}

struct MatchingPair: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var leftItem: String
    var rightItem: String

    init(leftItem: String, rightItem: String) {
        self.id = UUID()
        self.leftItem = leftItem
        self.rightItem = rightItem
    }
}



struct AlertSoundOption: Identifiable, Hashable {
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

enum DeckColorPalette {
    static let palette = [
        "#3B82C4", // Ocean Blue
        "#5B70E0", // Indigo
        "#2A9D8F", // Emerald Teal
        "#39D0BC", // Aqua
        "#C05A78", // Rose
        "#B8793E", // Warm Amber
        "#7654A8", // Purple
        "#3D8A59"  // Forest Green
    ]

    static func suggestedColor(existingColors: [String]) -> String {
        for color in palette {
            if !existingColors.contains(where: { $0.caseInsensitiveCompare(color) == .orderedSame }) {
                return color
            }
        }
        return palette.first ?? "#5B70E0"
    }

    static func takeNextColor(existingColors: [String]) -> String {
        suggestedColor(existingColors: existingColors)
    }
}

import UIKit

public enum CardImageStore {
    public static let appGroupIdentifier = "group.com.learnalert.shared"

    public static var imagesDirectoryURL: URL {
        let baseURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = baseURL.appendingPathComponent("CardImages", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    public static func saveImage(_ image: UIImage, name: String? = nil) -> String? {
        // Editing a bundled picture creates a private copy instead of shadowing shared course art.
        let filename = name.flatMap { $0.hasPrefix("course-vocab-") || $0.hasPrefix("catalog:") ? nil : $0 } ?? "\(UUID().uuidString).jpg"
        let fileURL = imagesDirectoryURL.appendingPathComponent(filename)

        let maxDim: CGFloat = 1200
        let size = image.size
        let targetSize: CGSize
        if size.width > maxDim || size.height > maxDim {
            let ratio = min(maxDim / size.width, maxDim / size.height)
            targetSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        } else {
            targetSize = size
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        guard let data = resizedImage.jpegData(compressionQuality: 0.82) else { return nil }
        do {
            try data.write(to: fileURL, options: .atomic)
            return filename
        } catch {
            print("Failed to save card image: \(error)")
            return nil
        }
    }

    /// Built-in course art also resolves in ordinary study and the notification extension.
    private static let vocabularyImages: [String: UIImage] = {
        guard let atlas = UIImage(named: "CourseVocabularyAtlas")?.cgImage else { return [:] }
        let names = ["apple", "banana", "orange", "grapes", "cat", "dog", "rabbit", "bird",
                     "coffee", "water", "rice", "milk", "book", "bag", "chair", "clock"]
        let side = CGFloat(atlas.width) / 4
        var result: [String: UIImage] = [:]
        for (index, name) in names.enumerated() {
            let rect = CGRect(x: CGFloat(index % 4) * side, y: CGFloat(index / 4) * side,
                              width: side, height: side)
            if let crop = atlas.cropping(to: rect) { result["course-vocab-" + name] = UIImage(cgImage: crop) }
        }
        return result
    }()

    public static func loadImage(named filename: String?) -> UIImage? {
        guard let filename, !filename.isEmpty else { return nil }
        // These immutable book attachments were accidentally published as the
        // complete 4x4 atlas. Resolve the intended tile even from an old cache.
        if legacyBookAttachments.contains(filename.lowercased()) {
            return vocabularyImages["course-vocab-book"]
        }
        if let image = vocabularyImages[filename] { return image }
        if let url = ManagedCatalogMedia.url(reference: filename) { return UIImage(contentsOfFile: url.path) }
        let fileURL = imagesDirectoryURL.appendingPathComponent(filename)
        if let image = UIImage(contentsOfFile: fileURL.path) {
            return image
        }
        if let bundleImage = UIImage(named: filename) {
            return bundleImage
        }
        return nil
    }

    private static let legacyBookAttachments: Set<String> = [
        "catalog:a5d45561-825b-440d-a9aa-98f4be7b5b8f", // Spanish
        "catalog:44b87db9-c0a5-4e3e-a58c-55a3aec07388"  // Korean
    ]

    public static func deleteImage(named filename: String?) {
        guard let filename, !filename.isEmpty, !filename.hasPrefix("catalog:") else { return }
        let fileURL = imagesDirectoryURL.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: fileURL)
    }
}

public enum NotificationTheme: String, CaseIterable, Identifiable {
    case defaultTheme = "default"
    case midnight = "midnight"
    case aurora = "aurora"
    case sunset = "sunset"
    case slate = "slate"
    case light = "light"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .defaultTheme: "Luminous"
        case .midnight: "Midnight OLED"
        case .aurora: "Emerald Aurora"
        case .sunset: "Sunset Glow"
        case .slate: "Minimal Slate"
        case .light: "Pure Light"
        }
    }

    public var subtitle: String {
        switch self {
        case .defaultTheme: "Cosmic indigo & radiant ambient orbs"
        case .midnight: "True deep black with midnight accents"
        case .aurora: "Electric emerald & mint aura"
        case .sunset: "Warm twilight plum & coral glow"
        case .slate: "Understated frosted titanium"
        case .light: "Clean alabaster light surface"
        }
    }

    public var accentColor: Color {
        switch self {
        case .defaultTheme: Color(red: 0.36, green: 0.44, blue: 0.88)
        case .midnight: Color(red: 0.55, green: 0.65, blue: 1.00)
        case .aurora: Color(red: 0.18, green: 0.80, blue: 0.55)
        case .sunset: Color(red: 1.00, green: 0.45, blue: 0.38)
        case .slate: Color(red: 0.60, green: 0.65, blue: 0.75)
        case .light: Color(red: 0.20, green: 0.55, blue: 0.95)
        }
    }

    /// The same light palette is used by Customize and the expanded notification.
    public var lightBackdropColors: [Color] {
        switch self {
        case .defaultTheme: [Color(red: 157/255, green: 187/255, blue: 242/255), Color(red: 187/255, green: 199/255, blue: 244/255)]
        case .midnight: [Color(red: 161/255, green: 176/255, blue: 211/255), Color(red: 204/255, green: 212/255, blue: 229/255)]
        case .aurora: [Color(red: 112/255, green: 213/255, blue: 174/255), Color(red: 156/255, green: 220/255, blue: 205/255)]
        case .sunset: [Color(red: 244/255, green: 173/255, blue: 147/255), Color(red: 237/255, green: 178/255, blue: 200/255)]
        case .slate: [Color(red: 174/255, green: 185/255, blue: 206/255), Color(red: 204/255, green: 213/255, blue: 227/255)]
        case .light: [Color(red: 237/255, green: 243/255, blue: 250/255), Color(red: 216/255, green: 230/255, blue: 244/255)]
        }
    }

    public func previewGradient(isLight: Bool) -> LinearGradient {
        isLight ? LinearGradient(colors: lightBackdropColors, startPoint: .topLeading, endPoint: .bottomTrailing) : previewGradient
    }

    public var previewGradient: LinearGradient {
        switch self {
        case .defaultTheme:
            return LinearGradient(colors: [Color(red: 0.20, green: 0.24, blue: 0.55), Color(red: 0.08, green: 0.10, blue: 0.25)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .midnight:
            return LinearGradient(colors: [Color(red: 0.10, green: 0.12, blue: 0.20), Color(red: 0.02, green: 0.02, blue: 0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .aurora:
            return LinearGradient(colors: [Color(red: 0.05, green: 0.30, blue: 0.22), Color(red: 0.02, green: 0.15, blue: 0.12)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .sunset:
            return LinearGradient(colors: [Color(red: 0.35, green: 0.12, blue: 0.25), Color(red: 0.15, green: 0.05, blue: 0.15)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .slate:
            return LinearGradient(colors: [Color(red: 0.22, green: 0.25, blue: 0.30), Color(red: 0.12, green: 0.14, blue: 0.18)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .light:
            return LinearGradient(colors: [Color(red: 0.96, green: 0.97, blue: 1.0), Color(red: 0.85, green: 0.90, blue: 0.96)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

/// Carries test-alert appearance across processes, including builds without a shared container.
public nonisolated struct NotificationAppearance: Equatable {
    public var theme: NotificationTheme
    public var layout: NotificationLayoutMode
    public var mode: String

    public init(theme: NotificationTheme, layout: NotificationLayoutMode, mode: String) {
        self.theme = theme
        self.layout = layout
        self.mode = ["light", "dark"].contains(mode) ? mode : "system"
    }

    public static func saved(in defaults: UserDefaults? = UserDefaults(suiteName: "group.com.learnalert.shared")) -> Self {
        Self(theme: NotificationTheme(rawValue: defaults?.string(forKey: "notificationCustomTheme") ?? "") ?? .defaultTheme,
             layout: NotificationLayoutMode(rawValue: defaults?.string(forKey: "notificationCustomLayout") ?? "") ?? .automatic,
             mode: defaults?.string(forKey: "appearanceMode") ?? "system")
    }

    public var userInfo: [String: String] {
        ["notificationCustomTheme": theme.rawValue, "notificationCustomLayout": layout.rawValue, "appearanceMode": mode]
    }

    public static func resolve(userInfo: [AnyHashable: Any], fallback: Self = .saved()) -> Self {
        Self(theme: (userInfo["notificationCustomTheme"] as? String).flatMap(NotificationTheme.init(rawValue:)) ?? fallback.theme,
             layout: (userInfo["notificationCustomLayout"] as? String).flatMap(NotificationLayoutMode.init(rawValue:)) ?? fallback.layout,
             mode: (userInfo["appearanceMode"] as? String).flatMap { ["system", "light", "dark"].contains($0) ? $0 : nil } ?? fallback.mode)
    }
}

public enum NotificationLayoutMode: String, CaseIterable, Identifiable {
    case automatic = "automatic"
    case compact = "compact"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .automatic: "Automatic"
        case .compact: "Compact"
        }
    }

    public var subtitle: String {
        switch self {
        case .automatic: "Adaptive standard layout with spacious padding"
        case .compact: "Reduced padding for fast, focused study"
        }
    }
}

@MainActor
enum LanguageTopicStore {
    private static func type(for value: String) -> FlashcardType {
        switch value {
        case "matching": return .matching
        case "fillBlank", "fill_blank": return .fillBlank
        case "vocabulary": return .vocabulary
        case "tapReveal", "tap_reveal": return .tapReveal
        default: return .multipleChoice
        }
    }
    static func open(course: CourseDefinition, topic: LanguageDeckProjection.Topic, context: ModelContext) throws -> Deck {
        let source = "language:\(course.id):\(topic.id)"
        let existing = try context.fetch(FetchDescriptor<Deck>())
        let found = existing.first(where: { $0.sourcePremadeID == source })
        if let found { return found }
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        let fingerprintData = try encoder.encode(topic.cards)
        let fingerprint = "language-deck-v1:" + SHA256.hash(data: fingerprintData).map { String(format: "%02x", $0) }.joined()
        if let found, found.sourceText == fingerprint { return found }
        let deck = found ?? Deck(name: topic.title, colorHex: course.colorHex, deckType: "Quiz")
        let savedCards = Dictionary(deck.cards.compactMap { card in card.sourceCourseCardID.map { ($0, card) } }, uniquingKeysWith: { a, _ in a })
        deck.name = topic.title; deck.colorHex = course.colorHex
        deck.sourcePremadeID = source; deck.sourceKind = "managedLanguage"; deck.sourceId = course.id
        let old = existing.filter { $0.sourcePremadeID == "course:\(course.id)" || ["languageTopic", "managedLanguage"].contains($0.sourceKind ?? "") && $0.sourceId == course.id }.flatMap(\.cards)
        let learning = try? LegacyLanguageHistory.load()
        let progress = Dictionary(old.compactMap { card in card.sourceCourseCardID.map { ($0, card) } }, uniquingKeysWith: { a, b in a.reviewCount >= b.reviewCount ? a : b })
        deck.cards = topic.cards.enumerated().map { index, definition in
            let card = savedCards[definition.id] ?? Flashcard(question: definition.question, options: definition.options, correctAnswer: definition.correctAnswer,
                cardType: type(for: definition.cardType),
                matchingLeftItems: definition.matchingLeftItems, matchingRightItems: definition.matchingRightItems)
            card.question = definition.question; card.options = definition.options; card.correctAnswer = definition.correctAnswer; card.hint = ""
            card.cardType = type(for: definition.cardType)
            card.matchingLeftItems = definition.matchingLeftItems; card.matchingRightItems = definition.matchingRightItems
            card.sourceCourseTopicID = topic.id
            card.sourceCourseTopicImportance = nil
            card.sourceCourseCardID = definition.id; card.orderIndex = index; card.fieldMedia = definition.resolvedFieldMedia; card.correctOptionIndex = definition.correctOptionIndex
            card.readingPrompt = definition.readingPrompt
            if savedCards[definition.id] == nil, let previous = progress[definition.id] {
                card.reviewCount = previous.reviewCount; card.correctCount = previous.correctCount; card.masteryScore = previous.masteryScore
                card.lastReviewedDate = previous.lastReviewedDate; card.streak = previous.streak; card.longestStreak = previous.longestStreak
            }
            if savedCards[definition.id] == nil, let record = learning?.record(courseID: course.id, cardID: definition.id), (record.reviewCount > card.reviewCount || card.reviewCount == 0 && record.masteryScore > card.masteryScore) {
                card.reviewCount = record.reviewCount; card.correctCount = record.correctCount; card.masteryScore = record.masteryScore
                card.lastReviewedDate = record.lastReviewedDate; card.streak = record.streak; card.longestStreak = max(card.longestStreak, record.streak)
            }
            return card
        }
        deck.sourceText = fingerprint
        if learning != nil { deck.legacyLanguageHistoryImported = true }
        if found == nil { context.insert(deck) }
        do { try context.save() } catch { if found == nil { context.delete(deck) }; throw error }
        return deck
    }
}
