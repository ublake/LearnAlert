//
//  CourseModels.swift
//  LearnAlert
//
//  Created by Blake Miller on 2/20/26.
//

import Foundation
import SwiftUI

// MARK: - Study Modes & Goals

public enum CourseStudyMode: String, Codable, CaseIterable, Identifiable, Hashable {
    case inAppAndNotifications = "in_app_and_notifications"
    case notificationsOnly = "notifications_only"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .inAppAndNotifications:
            return "In-App + Lock Screen Alerts"
        case .notificationsOnly:
            return "Lock Screen Learning"
        }
    }

    public var subtitle: String {
        switch self {
        case .inAppAndNotifications:
            return "Complete interactive lessons in-app and reinforce mastery via scheduled notification alerts."
        case .notificationsOnly:
            return "Learn through lock screen alerts. Section checkpoints are completed in the app."
        }
    }

    public var icon: String {
        switch self {
        case .inAppAndNotifications:
            return "iphone.and.arrow.forward"
        case .notificationsOnly:
            return "bell.badge.fill"
        }
    }
}

public enum CourseGoal: String, Codable, CaseIterable, Identifiable, Hashable {
    case travel = "travel"
    case conversation = "conversation"
    case school = "school"
    case personalGrowth = "personal_growth"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .travel: return "Travel & Culture"
        case .conversation: return "Daily Conversation"
        case .school: return "School & Academic"
        case .personalGrowth: return "Brain Training & Growth"
        }
    }

    public var icon: String {
        switch self {
        case .travel: return "airplane"
        case .conversation: return "bubble.left.and.bubble.right.fill"
        case .school: return "graduationcap.fill"
        case .personalGrowth: return "sparkles"
        }
    }
}

public enum CourseExperienceLevel: String, Codable, CaseIterable, Identifiable, Hashable {
    case absoluteBeginner = "beginner"
    case someKnowledge = "some_knowledge"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .absoluteBeginner: return "Absolute Beginner"
        case .someKnowledge: return "Some Prior Knowledge"
        }
    }

    public var subtitle: String {
        switch self {
        case .absoluteBeginner: return "New to the alphabet, sounds, and greetings."
        case .someKnowledge: return "Know some basic words and phrases already."
        }
    }

    public var icon: String {
        switch self {
        case .absoluteBeginner: return "seedling.fill"
        case .someKnowledge: return "leaf.fill"
        }
    }
}

// MARK: - Lesson Node Types & Status

public enum LessonNodeType: String, Codable, Hashable {
    case lesson = "lesson"
    case practice = "practice"
    case checkpoint = "checkpoint"
    case culturalTip = "cultural_tip"

    public var icon: String {
        switch self {
        case .lesson: return "book.fill"
        case .practice: return "bolt.fill"
        case .checkpoint: return "trophy.fill"
        case .culturalTip: return "lightbulb.fill"
        }
    }
}

public enum LessonStatus: String, Codable, Hashable {
    case locked = "locked"
    case available = "available"
    case current = "current"
    case completed = "completed"
    case reviewDue = "review_due"
}

// MARK: - Korean Vocabulary & Definition Item

public struct KoreanVocabularyItem: Identifiable, Codable, Hashable {
    public var id: String { surface }
    public let surface: String // Surface form (e.g. "안녕하세요", "먹어요")
    public let dictionaryForm: String // Dictionary base form (e.g. "안녕하다", "먹다")
    public let romanization: String
    public let partOfSpeech: String // e.g. "Polite Greeting", "Verb (해요체)"
    public let contextualMeaning: String
    public let breakdownNote: String? // Conjugation or particle breakdown note
    public let exampleKorean: String?
    public let exampleEnglish: String?
    public let audioText: String?

    public init(
        surface: String,
        dictionaryForm: String,
        romanization: String,
        partOfSpeech: String,
        contextualMeaning: String,
        breakdownNote: String? = nil,
        exampleKorean: String? = nil,
        exampleEnglish: String? = nil,
        audioText: String? = nil
    ) {
        self.surface = surface
        self.dictionaryForm = dictionaryForm
        self.romanization = romanization
        self.partOfSpeech = partOfSpeech
        self.contextualMeaning = contextualMeaning
        self.breakdownNote = breakdownNote
        self.exampleKorean = exampleKorean
        self.exampleEnglish = exampleEnglish
        self.audioText = audioText ?? surface
    }
}

// MARK: - Course Hierarchy Definitions

public struct CourseDefinition: Identifiable, Codable, Hashable {
    public let id: String
    public let title: String
    public let language: String
    public let flagEmoji: String
    public let levelTag: String
    public let colorHex: String
    public let summary: String
    public let estimatedHours: Int
    public let outcomes: [String]
    public let units: [CourseUnit]

    public var totalLessonsCount: Int {
        units.reduce(0) { $0 + $1.lessons.count }
    }

    public var totalCardsCount: Int {
        units.reduce(0) { unitSum, unit in
            unitSum + unit.lessons.reduce(0) { $0 + $1.cards.count } + (unit.checkpointQuiz?.questions.count ?? 0)
        }
    }

    public init(
        id: String,
        title: String,
        language: String,
        flagEmoji: String,
        levelTag: String,
        colorHex: String,
        summary: String,
        estimatedHours: Int,
        outcomes: [String],
        units: [CourseUnit]
    ) {
        self.id = id
        self.title = title
        self.language = language
        self.flagEmoji = flagEmoji
        self.levelTag = levelTag
        self.colorHex = colorHex
        self.summary = summary
        self.estimatedHours = estimatedHours
        self.outcomes = outcomes
        self.units = units
    }
}

public struct CourseCheckpointQuiz: Identifiable, Codable, Hashable {
    public let id: String
    public let title: String
    public let summary: String
    public let passingScoreThreshold: Double // Default 0.80 (80%)
    public let questions: [CourseLessonCard]
    public let keyConcepts: [String]

    public init(
        id: String,
        title: String,
        summary: String,
        passingScoreThreshold: Double = 0.80,
        questions: [CourseLessonCard],
        keyConcepts: [String] = []
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.passingScoreThreshold = passingScoreThreshold
        self.questions = questions
        self.keyConcepts = keyConcepts
    }
}

public struct CourseCheckpointResult: Codable, Hashable {
    public let checkpointId: String
    public let sectionId: String
    public let date: Date
    public let score: Int
    public let totalQuestions: Int
    public let passed: Bool
    public let missedQuestionIds: [String]
    public let missedConcepts: [String]

    public var percentage: Double {
        guard totalQuestions > 0 else { return 0.0 }
        return Double(score) / Double(totalQuestions)
    }

    public init(
        checkpointId: String,
        sectionId: String,
        date: Date = Date(),
        score: Int,
        totalQuestions: Int,
        passed: Bool,
        missedQuestionIds: [String] = [],
        missedConcepts: [String] = []
    ) {
        self.checkpointId = checkpointId
        self.sectionId = sectionId
        self.date = date
        self.score = score
        self.totalQuestions = totalQuestions
        self.passed = passed
        self.missedQuestionIds = missedQuestionIds
        self.missedConcepts = missedConcepts
    }
}

public struct CourseUnit: Identifiable, Codable, Hashable {
    public let id: String
    public let unitNumber: Int
    public let title: String
    public let subtitle: String
    public let colorHex: String
    public let badgeIcon: String
    public let lessons: [CourseLesson]
    public let checkpointQuiz: CourseCheckpointQuiz?

    public init(
        id: String,
        unitNumber: Int,
        title: String,
        subtitle: String,
        colorHex: String,
        badgeIcon: String,
        lessons: [CourseLesson],
        checkpointQuiz: CourseCheckpointQuiz? = nil
    ) {
        self.id = id
        self.unitNumber = unitNumber
        self.title = title
        self.subtitle = subtitle
        self.colorHex = colorHex
        self.badgeIcon = badgeIcon
        self.lessons = lessons
        self.checkpointQuiz = checkpointQuiz
    }
}

public struct CourseLesson: Identifiable, Codable, Hashable {
    public let id: String
    public let lessonNumber: Int
    public let title: String
    public let subtitle: String
    public let nodeType: LessonNodeType
    public let estimatedMinutes: Int
    public let tipNote: String?
    public let cards: [CourseLessonCard]

    public init(
        id: String,
        lessonNumber: Int,
        title: String,
        subtitle: String,
        nodeType: LessonNodeType = .lesson,
        estimatedMinutes: Int = 5,
        tipNote: String? = nil,
        cards: [CourseLessonCard]
    ) {
        self.id = id
        self.lessonNumber = lessonNumber
        self.title = title
        self.subtitle = subtitle
        self.nodeType = nodeType
        self.estimatedMinutes = estimatedMinutes
        self.tipNote = tipNote
        self.cards = cards
    }
}

public struct CourseLessonCard: Identifiable, Codable, Hashable {
    public let id: String
    public let question: String
    public let options: [String]
    public let correctAnswer: String
    public let hint: String
    public let cardType: String // "multipleChoice", "fillBlank", "vocabulary", "tapReveal", "matching"
    public let matchingLeftItems: [String]
    public let matchingRightItems: [String]
    public let promptImageName: String?
    public let optionImageNames: [String]
    public let vocabularyItem: KoreanVocabularyItem?
    public let grammarNote: String?
    public let speechText: String?
    public let conceptTag: String?
    public let explanation: String?
    public let acceptedAnswers: [String]?

    public init(
        id: String,
        question: String,
        options: [String] = [],
        correctAnswer: String,
        hint: String = "",
        cardType: String = "multipleChoice",
        matchingLeftItems: [String] = [],
        matchingRightItems: [String] = [],
        promptImageName: String? = nil,
        optionImageNames: [String] = [],
        vocabularyItem: KoreanVocabularyItem? = nil,
        grammarNote: String? = nil,
        speechText: String? = nil,
        conceptTag: String? = nil,
        explanation: String? = nil,
        acceptedAnswers: [String]? = nil
    ) {
        self.id = id
        self.question = question
        self.options = options
        self.correctAnswer = correctAnswer
        self.hint = hint
        self.cardType = cardType
        self.matchingLeftItems = matchingLeftItems
        self.matchingRightItems = matchingRightItems
        self.promptImageName = promptImageName
        self.optionImageNames = optionImageNames
        self.vocabularyItem = vocabularyItem
        self.grammarNote = grammarNote
        self.speechText = speechText
        self.conceptTag = conceptTag
        self.explanation = explanation
        self.acceptedAnswers = acceptedAnswers
    }

    public var primaryKoreanText: String? {
        if let vocab = vocabularyItem?.surface, !vocab.isEmpty {
            return vocab
        }
        if let speech = speechText, !speech.isEmpty {
            return speech
        }
        let pattern = "[가-힣ㄱ-ㅎㅏ-ㅣ]+(?:\\s+[가-힣ㄱ-ㅎㅏ-ㅣ]+)*"
        if let expression = try? NSRegularExpression(pattern: pattern) {
            let matches = expression.matches(in: question, range: NSRange(question.startIndex..., in: question))
            let phrases = matches.compactMap { Range($0.range, in: question).map { String(question[$0]) } }
            return phrases.max(by: { $0.count < $1.count })
        }
        return nil
    }
}

// MARK: - User Course Enrollment & Live Progress

public struct CourseEnrollment: Identifiable, Codable, Hashable {
    public let courseId: String
    public var enrolledDate: Date
    public var goal: CourseGoal
    public var experienceLevel: CourseExperienceLevel
    public var studyMode: CourseStudyMode
    public var selectedDays: [Int] // 1 = Sunday, 2 = Monday, ... 7 = Saturday
    public var startHour: Int
    public var startMinute: Int
    public var endHour: Int
    public var endMinute: Int
    public var dailyCardsTarget: Int
    public var linkedDeckId: String?
    public var checkpointPassingThreshold: Double
    public var autoPronounceInStudy: Bool

    public var id: String { courseId }

    public init(
        courseId: String,
        enrolledDate: Date = Date(),
        goal: CourseGoal = .conversation,
        experienceLevel: CourseExperienceLevel = .absoluteBeginner,
        studyMode: CourseStudyMode = .inAppAndNotifications,
        selectedDays: [Int] = [1, 2, 3, 4, 5, 6, 7],
        startHour: Int = 9,
        startMinute: Int = 0,
        endHour: Int = 18,
        endMinute: Int = 0,
        dailyCardsTarget: Int = 5,
        linkedDeckId: String? = nil,
        checkpointPassingThreshold: Double = 0.80,
        autoPronounceInStudy: Bool = false
    ) {
        self.courseId = courseId
        self.enrolledDate = enrolledDate
        self.goal = goal
        self.experienceLevel = experienceLevel
        self.studyMode = studyMode
        self.selectedDays = selectedDays
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
        self.dailyCardsTarget = dailyCardsTarget
        self.linkedDeckId = linkedDeckId
        self.checkpointPassingThreshold = checkpointPassingThreshold
        self.autoPronounceInStudy = autoPronounceInStudy
    }
    private enum CodingKeys: String, CodingKey { case courseId, enrolledDate, goal, experienceLevel, studyMode, selectedDays, startHour, startMinute, endHour, endMinute, dailyCardsTarget, linkedDeckId, checkpointPassingThreshold, autoPronounceInStudy }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.courseId = try values.decode(String.self, forKey: .courseId)
        self.enrolledDate = try values.decode(Date.self, forKey: .enrolledDate)
        self.goal = try values.decode(CourseGoal.self, forKey: .goal)
        self.experienceLevel = try values.decode(CourseExperienceLevel.self, forKey: .experienceLevel)
        self.studyMode = try values.decode(CourseStudyMode.self, forKey: .studyMode)
        self.selectedDays = try values.decode([Int].self, forKey: .selectedDays)
        self.startHour = try values.decode(Int.self, forKey: .startHour)
        self.startMinute = try values.decode(Int.self, forKey: .startMinute)
        self.endHour = try values.decode(Int.self, forKey: .endHour)
        self.endMinute = try values.decode(Int.self, forKey: .endMinute)
        self.dailyCardsTarget = try values.decode(Int.self, forKey: .dailyCardsTarget)
        self.linkedDeckId = try values.decodeIfPresent(String.self, forKey: .linkedDeckId)
        self.checkpointPassingThreshold = try values.decodeIfPresent(Double.self, forKey: .checkpointPassingThreshold) ?? 0.80
        self.autoPronounceInStudy = try values.decodeIfPresent(Bool.self, forKey: .autoPronounceInStudy) ?? false
    }

}

public struct CourseLessonProgressRecord: Codable, Hashable {
    public var status: LessonStatus
    public var completedDate: Date?
    public var correctAnswersCount: Int
    public var totalAttemptsCount: Int
    public var masteredCardIds: [String]

    public init(
        status: LessonStatus = .locked,
        completedDate: Date? = nil,
        correctAnswersCount: Int = 0,
        totalAttemptsCount: Int = 0,
        masteredCardIds: [String] = []
    ) {
        self.status = status
        self.completedDate = completedDate
        self.correctAnswersCount = correctAnswersCount
        self.totalAttemptsCount = totalAttemptsCount
        self.masteredCardIds = masteredCardIds
    }
    private enum CodingKeys: String, CodingKey { case status, completedDate, correctAnswersCount, totalAttemptsCount, masteredCardIds }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.status = try values.decode(LessonStatus.self, forKey: .status)
        self.completedDate = try values.decodeIfPresent(Date.self, forKey: .completedDate)
        self.correctAnswersCount = try values.decode(Int.self, forKey: .correctAnswersCount)
        self.totalAttemptsCount = try values.decode(Int.self, forKey: .totalAttemptsCount)
        self.masteredCardIds = try values.decodeIfPresent([String].self, forKey: .masteredCardIds) ?? []
    }

}

// MARK: - Spaced Repetition Card Record

public struct CourseCardSRSRecord: Codable, Hashable {
    public let cardId: String
    public var masteryScore: Int // 0 to 3
    public var streak: Int
    public var reviewCount: Int
    public var correctCount: Int
    public var lastReviewedDate: Date?
    public var nextReviewDate: Date?
    public var intervalHours: Double

    public var isDue: Bool {
        guard let next = nextReviewDate else { return true }
        return Date() >= next
    }

    public init(
        cardId: String,
        masteryScore: Int = 0,
        streak: Int = 0,
        reviewCount: Int = 0,
        correctCount: Int = 0,
        lastReviewedDate: Date? = nil,
        nextReviewDate: Date? = nil,
        intervalHours: Double = 0
    ) {
        self.cardId = cardId
        self.masteryScore = masteryScore
        self.streak = streak
        self.reviewCount = reviewCount
        self.correctCount = correctCount
        self.lastReviewedDate = lastReviewedDate
        self.nextReviewDate = nextReviewDate
        self.intervalHours = intervalHours
    }

    public mutating func processAnswer(isCorrect: Bool) {
        reviewCount += 1
        let now = Date()
        lastReviewedDate = now

        if isCorrect {
            correctCount += 1
            streak += 1
            masteryScore = min(masteryScore + 1, 3)
            switch masteryScore {
            case 1: intervalHours = 4.0
            case 2: intervalHours = 24.0
            case 3: intervalHours = 72.0
            default: intervalHours = 168.0
            }
            nextReviewDate = now.addingTimeInterval(intervalHours * 3600)
        } else {
            streak = 0
            masteryScore = max(masteryScore - 1, 0)
            // Delay re-presentation by 5 minutes rather than immediate endless repeating
            intervalHours = 0.0833 // ~5 minutes
            nextReviewDate = now.addingTimeInterval(300)
        }
    }
}

// MARK: - Course Schedule Pointer

public struct CourseSchedulePointer: Codable, Hashable {
    public var courseId: String
    public var sectionId: String
    public var lessonId: String
    public var cardIndex: Int
    public var isCheckpointPending: Bool

    public init(
        courseId: String,
        sectionId: String,
        lessonId: String,
        cardIndex: Int = 0,
        isCheckpointPending: Bool = false
    ) {
        self.courseId = courseId
        self.sectionId = sectionId
        self.lessonId = lessonId
        self.cardIndex = cardIndex
        self.isCheckpointPending = isCheckpointPending
    }
}

// MARK: - Course Answer Event (App & Notification Extension Queue)

public struct CourseAnswerEvent: Codable, Hashable {
    public let courseId: String
    public let sectionId: String
    public let lessonId: String
    public let cardId: String
    public let isCorrect: Bool
    public let eventToken: String
    public let timestamp: TimeInterval

    public init(
        courseId: String,
        sectionId: String,
        lessonId: String,
        cardId: String,
        isCorrect: Bool,
        eventToken: String = UUID().uuidString,
        timestamp: TimeInterval = Date().timeIntervalSince1970
    ) {
        self.courseId = courseId
        self.sectionId = sectionId
        self.lessonId = lessonId
        self.cardId = cardId
        self.isCorrect = isCorrect
        self.eventToken = eventToken
        self.timestamp = timestamp
    }
}
