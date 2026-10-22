import Foundation
import CoreGraphics

/// Activities belong to the course curriculum, independently of FlashcardType.
public struct CourseActivity: Codable, Hashable {
    public enum Kind: String, Codable { case teach, trace, buildBlock, placeTokens, listenChoose, situation, matchPairs }
    public enum Layout: String, Codable { case beside, below, besideWithFinal, belowWithFinal, inline }
    public let kind: Kind
    public let sequence: Int
    public var rule: String? = nil
    public var example: String? = nil
    public var symbol: String? = nil
    public var layout: Layout = .inline
    public var tokens: [String] = []
    public var slots: [String] = []
    public var slotLabels: [String] = []
    public var optionHints: [String: String] = [:]
    public var readingCue: String? = nil
    public var practiceGroup: String? = nil
    /// Additive presentation contract. Existing kind/options/slots remain a playable fallback.
    public var exercise: CourseExercise? = nil
}

struct CourseTraceGuidance {
    let attempt: Int
    var needsHelp = false
    var elapsed: TimeInterval = 0
    var showsGuide: Bool { attempt <= 2 || needsHelp || elapsed >= 60 }
    var highlightsDirection: Bool { needsHelp || elapsed >= 60 }
}

struct CoursePlacementState {
    var values: [String?]
    var selectedToken: String?
    var hadMistake = false
    init(count: Int) { values = Array(repeating: nil, count: count) }
    var filled: Bool { !values.isEmpty && values.allSatisfy { $0 != nil } }
    mutating func place(_ token: String, in slot: Int, available: [String]) -> Bool {
        guard values.indices.contains(slot), available.contains(token) else { return false }
        values[slot] = token
        selectedToken = nil
        return true
    }
    mutating func check(expected: [String]) -> Bool {
        let correct = values.count == expected.count && zip(values, expected).allSatisfy { $0.0 == $0.1 }
        if !correct { hadMistake = true }
        return correct
    }
}

/// Normalized stroke guides, with ordered geometric checking rather than handwriting recognition.
enum HangulStrokeGuide {
    static func strokes(for symbol: String) -> [[CGPoint]] {
        func p(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x, y: y) }
        switch symbol {
        case "ㅏ": return [[p(0.44, 0.18), p(0.44, 0.82)], [p(0.44, 0.49), p(0.75, 0.49)]]
        case "ㅓ": return [[p(0.25, 0.49), p(0.57, 0.49)], [p(0.57, 0.18), p(0.57, 0.82)]]
        case "ㅗ": return [[p(0.50, 0.25), p(0.50, 0.64)], [p(0.20, 0.64), p(0.80, 0.64)]]
        case "ㅜ": return [[p(0.20, 0.38), p(0.80, 0.38)], [p(0.50, 0.38), p(0.50, 0.77)]]
        case "ㅡ": return [[p(0.18, 0.50), p(0.82, 0.50)]]
        case "ㅣ": return [[p(0.50, 0.18), p(0.50, 0.82)]]
        case "ㄱ": return [[p(0.22, 0.25), p(0.76, 0.25), p(0.76, 0.78)]]
        case "ㄴ": return [[p(0.25, 0.20), p(0.25, 0.76), p(0.80, 0.76)]]
        case "ㅁ": return [[p(0.25, 0.24), p(0.25, 0.76)], [p(0.25, 0.24), p(0.75, 0.24), p(0.75, 0.76)], [p(0.25, 0.76), p(0.75, 0.76)]]
        case "ㄷ": return [[p(0.24, 0.24), p(0.78, 0.24)], [p(0.24, 0.24), p(0.24, 0.77), p(0.78, 0.77)]]
        case "ㄹ": return [[p(0.22, 0.23), p(0.76, 0.23), p(0.76, 0.48)], [p(0.22, 0.48), p(0.76, 0.48)], [p(0.22, 0.48), p(0.22, 0.77), p(0.78, 0.77)]]
        case "ㅂ": return [[p(0.27, 0.20), p(0.27, 0.78)], [p(0.73, 0.20), p(0.73, 0.78)], [p(0.27, 0.48), p(0.73, 0.48)], [p(0.27, 0.78), p(0.73, 0.78)]]
        case "ㅅ": return [[p(0.50, 0.22), p(0.43, 0.48), p(0.21, 0.77)], [p(0.46, 0.43), p(0.77, 0.77)]]
        case "ㅈ": return [[p(0.22, 0.23), p(0.78, 0.23)], [p(0.50, 0.23), p(0.43, 0.49), p(0.21, 0.78)], [p(0.46, 0.44), p(0.77, 0.78)]]
        case "ㅎ": return [[p(0.35, 0.17), p(0.65, 0.17)], [p(0.22, 0.32), p(0.78, 0.32)], (0...32).map { index in
            let angle = -Double.pi / 2 - Double(index) / 32 * 2 * Double.pi
            return p(0.5 + cos(angle) * 0.22, 0.63 + sin(angle) * 0.20)
        }]
        case "ㅇ": return [(0...32).map { index in
            let angle = -Double.pi / 2 - Double(index) / 32 * 2 * Double.pi
            return p(0.5 + cos(angle) * 0.29, 0.5 + sin(angle) * 0.29)
        }]
        default: return []
        }
    }

    static func accepts(_ input: [CGPoint], target: [CGPoint], tolerance: CGFloat = 0.13) -> Bool {
        let length = zip(input, input.dropFirst()).reduce(CGFloat.zero) { $0 + distance($1.0, $1.1) }
        guard input.count >= 2, length > 0.15, let first = input.first, let last = input.last,
              let start = target.first, let end = target.last,
              distance(first, start) < tolerance * 1.5, distance(last, end) < tolerance * 1.5 else { return false }
        let samples = resample(target)
        // A fast straight stroke may deliver only its endpoints. Judge its path,
        // rather than requiring a particular number of touchscreen events.
        let drawn = resample(input)
        let onGuide = drawn.filter { point in samples.contains { distance(point, $0) < tolerance } }.count
        let covered = samples.filter { point in drawn.contains { distance(point, $0) < tolerance } }.count
        guard Double(onGuide) / Double(drawn.count) >= 0.8,
              Double(covered) / Double(max(1, samples.count)) >= 0.85 else { return false }
        // Follow the guide in order, including a closed circle's direction.
        var cursor = 0
        for point in samples {
            guard let next = drawn.indices.dropFirst(cursor).first(where: { distance(drawn[$0], point) < tolerance }) else { return false }
            cursor = next
        }
        return true
    }

    private static func distance(_ lhs: CGPoint, _ rhs: CGPoint) -> CGFloat { hypot(lhs.x - rhs.x, lhs.y - rhs.y) }
    private static func resample(_ points: [CGPoint]) -> [CGPoint] {
        guard points.count > 1 else { return points }
        return zip(points, points.dropFirst()).flatMap { start, end in
            let steps = max(1, Int(ceil(distance(start, end) / 0.02)))
            return (0...steps).map { index in
                let t = CGFloat(index) / CGFloat(steps)
                return CGPoint(x: start.x + (end.x - start.x) * t, y: start.y + (end.y - start.y) * t)
            }
        }
    }
}

extension CourseActivity {
    private enum CodingKeys: String, CodingKey {
        case kind, sequence, rule, example, symbol, layout, tokens, slots, slotLabels, optionHints, readingCue, practiceGroup, exercise
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(kind: try c.decode(Kind.self, forKey: .kind), sequence: try c.decode(Int.self, forKey: .sequence))
        rule = try c.decodeIfPresent(String.self, forKey: .rule)
        example = try c.decodeIfPresent(String.self, forKey: .example)
        symbol = try c.decodeIfPresent(String.self, forKey: .symbol)
        layout = try c.decodeIfPresent(Layout.self, forKey: .layout) ?? .inline
        tokens = try c.decodeIfPresent([String].self, forKey: .tokens) ?? []
        slots = try c.decodeIfPresent([String].self, forKey: .slots) ?? []
        slotLabels = try c.decodeIfPresent([String].self, forKey: .slotLabels) ?? []
        optionHints = try c.decodeIfPresent([String: String].self, forKey: .optionHints) ?? [:]
        readingCue = try c.decodeIfPresent(String.self, forKey: .readingCue)
        practiceGroup = try c.decodeIfPresent(String.self, forKey: .practiceGroup)
        exercise = try c.decodeIfPresent(CourseExercise.self, forKey: .exercise)
    }
}


/// Stable lexical senses recur across contexts; concepts identify the particular skill.
public struct CourseLearningGraph: Codable, Hashable {
    public var vocabulary: [String: CourseLexicalSense]
    public var concepts: [String: CourseConcept]
    public var starter: CourseStarterDefinition? = nil
}
public struct CourseLexicalSense: Codable, Hashable {
    public var lemma: String
    public var meaning: String
    public var locale: String
    public var article: String?
    public var image: String?
}
public struct CourseConcept: Codable, Hashable {
    public var title: String
    public var prerequisiteIDs: [String]
    public var vocabularyIDs: [String]
}
public struct CoursePictureChoice: Codable, Hashable, Identifiable {
    public var id: String
    public var image: String
    /// English task equivalent, without spelling the Spanish answer.
    public var description: String
}
public struct CourseWordTile: Codable, Hashable, Identifiable {
    public var id: String
    public var text: String
}
public struct CourseExercise: Codable, Hashable {
    // Strings deliberately keep future optional metadata decodable by this reader.
    public var format: String // pictureChoice, wordBank, exposure
    public var vocabularyIDs: [String]
    public var conceptIDs: [String]
    public var pictures: [CoursePictureChoice]?
    public var correctChoiceID: String?
    public var tiles: [CourseWordTile]?
    public var acceptedOrders: [[String]]? // tile text, not occurrence identity
    public var choices: [CourseWordTile]? = nil
    public var pairs: [CourseExercisePair]? = nil
    public var prerequisiteIDs: [String]? = nil
    public var stimulusText: String? = nil
    public var stimulusCount: Int? = nil
    public var usesPracticeRenderer: Bool { ["pictureChoice", "choice", "matching", "wordBank", "exposure"].contains(format) }
}

struct CoursePairDecision: Codable, Equatable {
    var firstRightID: String
    var independent: Bool
    var assisted: Bool
    var usedElimination: Bool
}

/// Pure, serializable reducer. Duplicate words are different finite tile instances.
struct CourseExerciseState: Codable, Equatable {
    var attemptID = UUID().uuidString
    var selectedIDs: [String] = []
    var choiceID: String?
    var result: Bool?
    var usedHelp = false
    var revision: Int = 0
    var activePairID: String? = nil
    var pairChoices: [String: String]? = nil
    var pairOrder: [String]? = nil
    // Missing on pre-v5 drafts means unknown history: never infer independence.
    var pairDecisions: [String: CoursePairDecision]? = [:]

    /// Stable within an attempt (including relaunch), varied across new attempts.
    func orderedIDs(_ ids: [String]) -> [String] {
        func rank(_ id: String) -> UInt64 {
            var value = (attemptID + ":" + id).utf8.reduce(UInt64(14695981039346656037)) { ($0 ^ UInt64($1)) &* 1099511628211 }
            value = (value ^ (value >> 30)) &* 0xbf58476d1ce4e5b9
            value = (value ^ (value >> 27)) &* 0x94d049bb133111eb
            return value ^ (value >> 31)
        }
        return ids.sorted { rank($0) == rank($1) ? $0 < $1 : rank($0) < rank($1) }
    }
    mutating func append(_ id: String, exercise: CourseExercise) {
        guard result == nil, exercise.tiles?.contains(where: { $0.id == id }) == true,
              !selectedIDs.contains(id) else { return }
        selectedIDs.append(id); revision += 1
    }
    mutating func remove(_ id: String) {
        guard result == nil, selectedIDs.contains(id) else { return }
        selectedIDs.removeAll { $0 == id }; revision += 1
    }
    mutating func move(_ id: String, before target: String, exercise: CourseExercise) {
        guard result == nil, id != target, selectedIDs.contains(target),
              exercise.tiles?.contains(where: { $0.id == id }) == true else { return }
        selectedIDs.removeAll { $0 == id }
        guard let index = selectedIDs.firstIndex(of: target) else { return }
        selectedIDs.insert(id, at: index); revision += 1
    }
    mutating func select(_ id: String, exercise: CourseExercise) {
        guard result == nil, (exercise.pictures?.contains(where: { $0.id == id }) == true || exercise.choices?.contains(where: { $0.id == id }) == true) else { return }
        choiceID = id; revision += 1
    }
    mutating func selectPair(_ id: String, exercise: CourseExercise) {
        guard result == nil, exercise.pairs?.contains(where: { $0.id == id }) == true, pairChoices?[id] == nil else { return }
        activePairID = id; revision += 1
    }
    mutating func matchPair(_ id: String, exercise: CourseExercise) {
        guard result == nil, let left = activePairID, exercise.pairs?.contains(where: { $0.id == id }) == true,
              pairChoices?.values.contains(id) != true else { return }
        if pairChoices == nil { pairChoices = [:] }; if pairOrder == nil { pairOrder = [] }
        if var decisions = pairDecisions {
            let forced = decisions.keys.filter { $0 != left }.count >= (exercise.pairs?.count ?? 0) - 1
            if var decision = decisions[left] {
                decision.assisted = decision.assisted || usedHelp
                decision.usedElimination = decision.usedElimination || forced
                decisions[left] = decision
            } else {
                decisions[left] = CoursePairDecision(firstRightID: id, independent: !forced, assisted: usedHelp, usedElimination: forced)
            }
            pairDecisions = decisions
        }
        pairChoices?[left] = id; pairOrder?.append(left); activePairID = nil; revision += 1
    }
    mutating func clearPair(_ id: String) {
        guard result == nil, pairChoices?[id] != nil else { return }
        pairChoices?.removeValue(forKey: id); pairOrder?.removeAll { $0 == id }; revision += 1
    }
    /// Every host must carry forward first-response and assistance history.
    func preservesEvidence(from old: CourseExerciseState, exercise: CourseExercise) -> Bool {
        guard !old.usedHelp || usedHelp else { return false }
        guard exercise.format == "matching" else { return true }
        guard let previous = old.pairDecisions else { return pairDecisions == nil }
        guard let decisions = pairDecisions else { return false }
        for (id, prior) in previous {
            guard let next = decisions[id], next.firstRightID == prior.firstRightID,
                  next.independent == prior.independent,
                  !prior.assisted || next.assisted,
                  !prior.usedElimination || next.usedElimination else { return false }
        }
        let additions = decisions.keys.filter { previous[$0] == nil }
        guard additions.count <= 1 else { return false }
        if let id = additions.first {
            let forced = previous.count >= (exercise.pairs?.count ?? 0) - 1
            guard old.activePairID == id, old.pairChoices?[id] == nil,
                  let right = pairChoices?[id], exercise.pairs?.contains(where: { $0.id == right }) == true,
                  old.pairChoices?.values.contains(right) != true,
                  decisions[id] == CoursePairDecision(firstRightID: right, independent: !forced, assisted: usedHelp, usedElimination: forced) else { return false }
        }
        return true
    }
    func canSubmit(_ exercise: CourseExercise) -> Bool {
        switch exercise.format {
        case "exposure": return true
        case "pictureChoice": return choiceID != nil && exercise.pictures?.contains(where: { $0.id == choiceID }) == true
        case "choice": return choiceID != nil && exercise.choices?.contains(where: { $0.id == choiceID }) == true
        case "matching": return !(exercise.pairs ?? []).isEmpty && exercise.pairs?.allSatisfy { pairChoices?[$0.id] != nil } == true
        case "wordBank": return !selectedIDs.isEmpty
        default: return false
        }
    }
    @discardableResult mutating func submit(_ exercise: CourseExercise) -> Bool? {
        guard result == nil, canSubmit(exercise) else { return nil }
        switch exercise.format {
        case "exposure": result = true
        case "pictureChoice", "choice": result = choiceID == exercise.correctChoiceID
        case "matching": result = exercise.pairs?.allSatisfy { pairChoices?[$0.id] == $0.id } == true
        case "wordBank":
            let tiles = exercise.tiles ?? []
            guard Set(tiles.map(\.id)).count == tiles.count,
                  selectedIDs.allSatisfy({ id in tiles.contains { $0.id == id } }) else { return nil }
            let words = selectedIDs.compactMap { id in tiles.first { $0.id == id }?.text }
            result = exercise.acceptedOrders?.contains(words) == true
        default: return nil
        }
        revision += 1
        return result
    }
}

struct CourseExerciseEvidence: Codable {
    var attemptID: String
    var courseID: String
    var cardID: String
    var vocabularyIDs: [String]
    var conceptIDs: [String]
    var mode: String // exposure, recognition, supportedConstruction
    var correct: Bool
    var assisted: Bool
    var timestamp: Date
    var pairEvidence: [CoursePairEvidence]? = nil
}


public struct CourseExercisePair: Codable, Hashable, Identifiable {
    public var id: String
    public var label: String
    public var image: String
    public var description: String
    public var vocabularyIDs: [String]
    public var conceptIDs: [String]
}
struct CoursePairEvidence: Codable {
    var pairID: String
    var correct: Bool
    var vocabularyIDs: [String]
    var conceptIDs: [String]
    var firstRightID: String? = nil
    var assisted: Bool? = nil
    var usedElimination: Bool? = nil
}
public struct CourseStarterDefinition: Codable, Hashable {
    public var id: String
    public var revision: String
    public var lessonIDs: [String]
    public var assessment: CourseAssessmentBlueprint
}
public struct CourseAssessmentBlueprint: Codable, Hashable {
    public var id: String
    public var title: String
    public var revision: String
    public var lessonIDs: [String]
    public var forms: [String: [CourseAssessmentItem]]
    public var objectiveIDs: [String]
    public var passingTotal: Int
    public var passingPerObjective: Int
}
public struct CourseAssessmentItem: Codable, Hashable, Identifiable {
    public var id: String { card.id }
    public var card: CourseLessonCard
    public var objectiveID: String
    public var remediationLessonIDs: [String]
}
struct CourseRouteAssignment: Codable {
    var revision: String
    var lessonIDs: [String]
    var originalContinueLessonID: String?
    var starterSelected: Bool
    var returningLearner: Bool
}
struct CourseAssessmentAttempt: Codable, Identifiable {
    var id: String
    var courseID: String
    var blueprint: CourseAssessmentBlueprint
    var formID: String
    var items: [CourseAssessmentItem]
    var states: [String: CourseExerciseState]
    var skippedIDs: [String] = []
    var index = 0
    var finalizedAt: Date? = nil
    var passed: Bool? = nil
    var activeItem: CourseAssessmentItem? { items.indices.contains(index) ? items[index] : nil }
    var score: Int { items.filter { !skippedIDs.contains($0.id) && states[$0.id]?.result == true }.count }
    func score(objectiveID: String) -> Int { items.filter { $0.objectiveID == objectiveID && !skippedIDs.contains($0.id) && states[$0.id]?.result == true }.count }
    var remediationLessonIDs: [String] { Array(Set(items.filter { skippedIDs.contains($0.id) || states[$0.id]?.result != true }.flatMap(\.remediationLessonIDs))).sorted() }
}
