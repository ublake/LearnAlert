import Foundation

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
    public var dialogues: [String: CourseDialogueDefinition]? = nil
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
    public var context: CourseExerciseContext? = nil
    public var models: [CourseRevealModel]? = nil
    public var showsMeaningLabels: Bool? = nil
    public var isMatching: Bool { ["matching", "textMatching"].contains(format) }
    public var isAppOnlyDialogue: Bool { context?.dialogueID != nil }
    public var usesPracticeRenderer: Bool { ["pictureChoice", "choice", "matching", "textMatching", "wordBank", "exposure"].contains(format) }
}

public struct CourseRevealModel: Codable, Hashable { public var spanish: String; public var meaning: String }
public struct CourseExerciseContext: Codable, Hashable {
    public var cashierText: String? = nil
    public var goalText: String? = nil
    public var goalFeedback: String? = nil
    public var goalMismatchChoiceIDs: [String]? = nil
    public var goalMismatchOrders: [[String]]? = nil
    public var dialogueID: String? = nil
    public var dialogueStepID: String? = nil
    public var audioReference: String? = nil
}
public struct CourseDialogueDefinition: Codable, Hashable {
    public var id: String
    public var revision: String
    public var lessonID: String
    public var title: String
    public var goal: String
    public var briefing: String
    public var steps: [CourseDialogueStep]
    func isSupported(cards: [CourseLessonCard]) -> Bool {
        let updates = [["product":"coffee", "quantity":"1"],["milk":"with_milk"],["service":"here"],["extras":"none"],["amount":"2"],["payment":"handed_over"],["farewell":"done"]]
        guard !id.isEmpty, !revision.isEmpty, !goal.isEmpty, !briefing.isEmpty, steps.count == 7,
              Set(steps.map(\.id)).count == 7, Array(cards.prefix(7).map(\.id)) == steps.map(\.cardID) else { return false }
        return steps.enumerated().allSatisfy { index, step in
            let context = cards[index].activity?.exercise?.context
            return !step.id.isEmpty && step.turn == [1,2,3,4,5,5,6][index] && step.substep == ["reply","reply","reply","reply","amount","handover","reply"][index] && step.updates == updates[index] && context?.dialogueID == id && context?.dialogueStepID == step.id && context?.cashierText?.isEmpty == false && ["choice", "wordBank"].contains(cards[index].activity?.exercise?.format ?? "")
        }
    }
}
public struct CourseDialogueStep: Codable, Hashable, Identifiable {
    public var id: String
    public var cardID: String
    public var turn: Int
    public var substep: String
    public var updates: [String: String]
}
public struct CourseExercisePair: Codable, Hashable, Identifiable {
    public var id: String
    public var label: String
    public var image: String
    public var description: String
    public var vocabularyIDs: [String]
    public var conceptIDs: [String]
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
/// Shared by app, extension and delivery validation. Capabilities are behavior,
/// not a user-agent guess. Unsupported notifications can only hand off.
enum CourseDeliveryContracts {
    static let profile = "practice-v2"
    static let v1: Set<String> = ["exercise-v1", "matching-evidence-v1", "finite-bank-v1", "route-v1", "assessment-v1"]
    static let supported = v1.union(["text-matching-v1", "finite-dialogue-v1"])
    static let modernProfiles: Set<String> = ["practice-v1", "practice-v2"]
    static func required(for profile: String) -> Set<String> { profile == "practice-v1" ? v1 : profile == Self.profile ? supported : [] }
    static func supports(_ required: [String]) -> Bool { Set(required).isSubset(of: supported) }
    static func validatesV2(_ course: CourseDefinition) -> Bool {
        let lessons = course.units.flatMap(\.lessons), definitions = course.learning?.dialogues ?? [:]
        for (id, definition) in definitions {
            guard definition.id == id, let lesson = lessons.first(where: { $0.id == definition.lessonID }), definition.isSupported(cards: lesson.cards) else { return false }
        }
        if let assessment = course.learning?.starter?.assessment {
            for item in assessment.forms.values.flatMap({ $0 }) {
                guard let exercise = item.card.activity?.exercise, ["pictureChoice", "choice", "wordBank"].contains(exercise.format), exercise.context == nil, exercise.models == nil else { return false }
            }
        }
        for card in lessons.flatMap(\.cards) {
            guard let exercise = card.activity?.exercise else { continue }
            if exercise.format == "textMatching" {
                guard let pairs = exercise.pairs, pairs.count == 2, Set(pairs.map(\.id)).count == 2,
                      pairs.allSatisfy({ !$0.id.isEmpty && !$0.label.isEmpty && !$0.description.isEmpty && $0.image.isEmpty && !$0.vocabularyIDs.isEmpty && !$0.conceptIDs.isEmpty && Set($0.vocabularyIDs).isSubset(of: Set(exercise.vocabularyIDs)) && Set($0.conceptIDs).isSubset(of: Set(exercise.conceptIDs)) }) else { return false }
            }
            if exercise.models?.contains(where: { $0.spanish.isEmpty || $0.meaning.isEmpty }) == true { return false }
            guard let context = exercise.context else { continue }
            if (context.dialogueID == nil) != (context.dialogueStepID == nil) { return false }
            if let id = context.dialogueID {
                guard let definition = definitions[id], definition.steps.contains(where: { $0.id == context.dialogueStepID && $0.cardID == card.id }) else { return false }
            }
            if context.goalMismatchChoiceIDs?.contains(where: { id in id == exercise.correctChoiceID || exercise.choices?.contains(where: { $0.id == id }) != true }) == true { return false }
            for order in context.goalMismatchOrders ?? [] {
                var inventory = (exercise.tiles ?? []).map(\.text)
                guard !order.isEmpty, exercise.acceptedOrders?.contains(order) != true else { return false }
                for word in order { guard let index = inventory.firstIndex(of: word) else { return false }; inventory.remove(at: index) }
            }
        }
        return true
    }

    static func notificationCanRender(profile: String?, contracts: [String]?, course: CourseDefinition?) -> Bool {
        guard notificationIsCompatible(profile: profile, contracts: contracts), let course else { return false }
        return profile == nil || profile == "legacy-v1" || course.learning?.starter != nil
    }
    static func notificationIsCompatible(profile: String?, contracts: [String]?) -> Bool {
        guard let profile else { return contracts == nil || contracts?.isEmpty == true }
        if profile == "legacy-v1" { return contracts == nil || contracts?.isEmpty == true }
        return modernProfiles.contains(profile) && contracts.map { supports($0) && required(for: profile).isSubset(of: Set($0)) } == true
    }
}
