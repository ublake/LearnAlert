import SwiftUI
//
//  Deck.swift
//  LearnAlert
//
//  Created by Blake Miller on 2/19/26.
//

import Foundation
import SwiftData

enum FlashcardType: String, CaseIterable, Identifiable {
    case vocabulary = "vocabulary"
    case multipleChoice = "multiple_choice"
    case tapReveal = "tap_reveal"
    case matching = "matching"
    case fillBlank = "fill_blank"

    var id: String { rawValue }
    var title: String {
        switch self {
        case .vocabulary: "Vocabulary"
        case .multipleChoice: "Quiz Style"
        case .tapReveal: "Tap to Reveal"
        case .matching: "Match Pairs"
        case .fillBlank: "Fill in the Blank"
        }
    }
    var icon: String {
        switch self {
        case .vocabulary: "character.book.closed.fill"
        case .multipleChoice: "list.bullet.circle"
        case .tapReveal: "rectangle.on.rectangle"
        case .matching: "arrow.left.arrow.right"
        case .fillBlank: "text.cursor"
        }
    }

    var subtitle: String {
        switch self {
        case .multipleChoice: "Practice with 4 options and immediate feedback"
        case .tapReveal: "Front-and-back flip with self assessment"
        case .vocabulary: "Word, pronunciation, and dictionary definition"
        case .fillBlank: "Type the missing keyword in context"
        case .matching: "Connect paired terms and definitions"
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
    var sourceCommunityID: String?
    var publishedCommunityID: String?
    var communityCategory: String?
    var communityDescription: String?

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
            storedCards?.sorted(by: { $0.orderIndex < $1.orderIndex }) ?? []
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

    var cycleStreak: Int {
        cards.map(\.streak).max() ?? 0
    }

    var cycleProgress: Double {
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

    var name: String {
        get { title }
        set { title = newValue }
    }

    var deck: Deck?

    @Relationship(deleteRule: .nullify, inverse: \Flashcard.section)
    private var storedCards: [Flashcard]?

    var cards: [Flashcard] {
        get {
            storedCards?.sorted(by: { $0.orderIndex < $1.orderIndex }) ?? []
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
    var promptAudioName: String?
    var optionImageNamesData: Data = Data()

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
        reviewCount += 1
        lastReviewedDate = Date()
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
        guard let last = lastReviewedDate else { return Date.distantPast }
        let hours: Double
        switch masteryScore {
        case 0: hours = 1
        case 1: hours = 4
        case 2: hours = 12
        case 3: hours = 24
        default: hours = 48
        }
        return last.addingTimeInterval(hours * 3600)
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
        let filename = name.flatMap { $0.hasPrefix("course-vocab-") ? nil : $0 } ?? "\(UUID().uuidString).jpg"
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

        let renderer = UIGraphicsImageRenderer(size: targetSize)
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
        if let image = vocabularyImages[filename] { return image }
        let fileURL = imagesDirectoryURL.appendingPathComponent(filename)
        if let image = UIImage(contentsOfFile: fileURL.path) {
            return image
        }
        if let bundleImage = UIImage(named: filename) {
            return bundleImage
        }
        return nil
    }

    public static func deleteImage(named filename: String?) {
        guard let filename, !filename.isEmpty else { return }
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
