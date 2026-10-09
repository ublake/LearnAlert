import Foundation
import Darwin

/// An unfinished in-app attempt. Graded answers also persist before Continue is tapped.
struct CoursePracticeSession: Codable {
    var id = UUID().uuidString
    var cardIds: [String]
    var answers: [String: Bool] = [:]

    var nextIndex: Int? { cardIds.firstIndex { answers[$0] == nil } }
    var missedCardIds: [String] { cardIds.filter { answers[$0] == false } }
}

struct CoursePracticeCompletion {
    var checkpointResult: CourseCheckpointResult?
}

/// One atomic, cross-process course snapshot, shared by the app and notification extension.
struct CourseLearningSnapshot: Codable {
    var progress: [String: [String: CourseLessonProgressRecord]] = [:]
    var checkpoints: [String: [String: CourseCheckpointResult]] = [:]
    var srs: [String: CourseCardSRSRecord] = [:]
    var eventTokens: [String] = []
    var practiceSessions: [String: CoursePracticeSession] = [:]

    init() {}

    private enum CodingKeys: String, CodingKey { case progress, checkpoints, srs, eventTokens, practiceSessions }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        progress = try values.decodeIfPresent([String: [String: CourseLessonProgressRecord]].self, forKey: .progress) ?? [:]
        checkpoints = try values.decodeIfPresent([String: [String: CourseCheckpointResult]].self, forKey: .checkpoints) ?? [:]
        srs = try values.decodeIfPresent([String: CourseCardSRSRecord].self, forKey: .srs) ?? [:]
        eventTokens = try values.decodeIfPresent([String].self, forKey: .eventTokens) ?? []
        practiceSessions = try values.decodeIfPresent([String: CoursePracticeSession].self, forKey: .practiceSessions) ?? [:]
    }

    static func practiceKey(courseId: String, lessonId: String?, checkpointUnitId: String?) -> String? {
        if let lessonId { return "\(courseId):lesson:\(lessonId)" }
        if let checkpointUnitId { return "\(courseId):checkpoint:\(checkpointUnitId)" }
        return nil
    }

    private func practiceCards(course: CourseDefinition, lessonId: String?, checkpointUnitId: String?) -> [CourseLessonCard]? {
        if let lessonId, status(course: course, lessonId: lessonId) != .locked {
            return course.units.flatMap(\.lessons).first { $0.id == lessonId }?.cards
        }
        if let unit = course.units.first(where: { $0.id == checkpointUnitId }),
           unit.lessons.allSatisfy({ status(course: course, lessonId: $0.id) == .completed }) {
            return unit.checkpointQuiz?.questions
        }
        return nil
    }

    mutating func resumePractice(course: CourseDefinition, lessonId: String?, checkpointUnitId: String?) -> CoursePracticeSession? {
        guard let key = Self.practiceKey(courseId: course.id, lessonId: lessonId, checkpointUnitId: checkpointUnitId),
              let cards = practiceCards(course: course, lessonId: lessonId, checkpointUnitId: checkpointUnitId), !cards.isEmpty else { return nil }
        var session = practiceSessions[key] ?? CoursePracticeSession(cardIds: [])
        let validIds = Set(cards.map(\.id))
        let survivingIds = session.cardIds.filter { validIds.contains($0) }
        let added = cards.filter { !survivingIds.contains($0.id) }
        // Start with an orientation note; randomize exercises once, then save that order.
        session.cardIds = survivingIds + added.filter { $0.id.hasSuffix("-guide") }.map(\.id)
            + added.filter { !$0.id.hasSuffix("-guide") }.shuffled().map(\.id)
        session.answers = session.answers.filter { session.cardIds.contains($0.key) }
        if let lessonId, status(course: course, lessonId: lessonId) != .completed {
            // Existing saved answers, including notification answers, should not restart a lesson.
            for id in progress[course.id]?[lessonId]?.masteredCardIds ?? [] where session.cardIds.contains(id) && session.answers[id] == nil {
                session.answers[id] = true
            }
        }
        practiceSessions[key] = session
        return session
    }

    @discardableResult
    mutating func answerPractice(course: CourseDefinition, lessonId: String?, checkpointUnitId: String?, sessionId: String, cardId: String, correct: Bool) -> Bool {
        guard let key = Self.practiceKey(courseId: course.id, lessonId: lessonId, checkpointUnitId: checkpointUnitId),
              var session = practiceSessions[key], session.id == sessionId,
              let next = session.nextIndex, session.cardIds[next] == cardId,
              practiceCards(course: course, lessonId: lessonId, checkpointUnitId: checkpointUnitId)?.contains(where: { $0.id == cardId }) == true else { return false }
        if let lessonId, !answer(course: course, lessonId: lessonId, cardId: cardId, correct: correct, token: "\(session.id)-\(cardId)") { return false }
        session.answers[cardId] = correct
        practiceSessions[key] = session
        return true
    }

    mutating func finishPractice(course: CourseDefinition, lessonId: String?, checkpointUnitId: String?, sessionId: String, passingThreshold: Double? = nil) -> CoursePracticeCompletion? {
        guard let key = Self.practiceKey(courseId: course.id, lessonId: lessonId, checkpointUnitId: checkpointUnitId),
              let session = practiceSessions[key], session.id == sessionId, session.nextIndex == nil else { return nil }
        var result: CourseCheckpointResult?
        if let checkpointUnitId {
            guard let unit = course.units.first(where: { $0.id == checkpointUnitId }),
                  let checkpointResult = checkpoint(course: course, unit: unit, missed: session.missedCardIds, passingThreshold: passingThreshold) else { return nil }
            result = checkpointResult
        }
        practiceSessions.removeValue(forKey: key)
        return CoursePracticeCompletion(checkpointResult: result)
    }

    func completionFraction(course: CourseDefinition) -> Double {
        let lessonProgress = course.units.flatMap(\.lessons).reduce(0.0) { total, lesson in
            let record = progress[course.id]?[lesson.id]
            if record?.status == .completed { return total + 1 }
            let mastered = Set(record?.masteredCardIds ?? []).intersection(Set(lesson.cards.map(\.id))).count
            return total + Double(mastered) / Double(max(1, lesson.cards.count))
        }
        let quizzes = course.units.filter { $0.checkpointQuiz != nil }
        let passed = quizzes.filter { checkpoints[course.id]?[$0.id]?.passed == true }.count
        return min(1, (lessonProgress + Double(passed)) / Double(max(1, course.totalLessonsCount + quizzes.count)))
    }

    func status(course: CourseDefinition, lessonId: String) -> LessonStatus {
        for (index, unit) in course.units.enumerated() where unit.lessons.contains(where: { $0.id == lessonId }) {
            if course.units.prefix(index).contains(where: { previous in
                previous.checkpointQuiz != nil && checkpoints[course.id]?[previous.id]?.passed != true
            }) { return .locked }
            guard let lessonIndex = unit.lessons.firstIndex(where: { $0.id == lessonId }) else { return .locked }
            if unit.lessons.prefix(lessonIndex).contains(where: { progress[course.id]?[$0.id]?.status != .completed }) { return .locked }
            return progress[course.id]?[lessonId]?.status == .completed ? .completed : .current
        }
        return .locked
    }

    func pendingCheckpoint(course: CourseDefinition) -> CourseUnit? {
        course.units.first { unit in
            unit.checkpointQuiz != nil && checkpoints[course.id]?[unit.id]?.passed != true &&
            unit.lessons.allSatisfy { status(course: course, lessonId: $0.id) == .completed }
        }
    }

    func currentLesson(course: CourseDefinition) -> CourseLesson? {
        course.units.flatMap(\.lessons).first { status(course: course, lessonId: $0.id) == .current }
    }

    func batch(course: CourseDefinition, count: Int, now: Date = Date(), reviewOnly: Bool = false, randomized: Bool = false) -> [CourseLessonCard] {
        guard count > 0 else { return [] }
        let due = course.units.flatMap(\.lessons).filter { status(course: course, lessonId: $0.id) == .completed }
            .flatMap(\.cards).filter { srs[$0.id].map { ($0.nextReviewDate ?? .distantPast) <= now } ?? true }
            .sorted { (srs[$0.id]?.nextReviewDate ?? .distantPast) < (srs[$1.id]?.nextReviewDate ?? .distantPast) }
        let lesson = reviewOnly ? nil : currentLesson(course: course)
        let mastered = Set(progress[course.id]?[lesson?.id ?? ""]?.masteredCardIds ?? [])
        let fresh = lesson?.cards.filter { !mastered.contains($0.id) && (srs[$0.id].map { ($0.nextReviewDate ?? .distantPast) <= now } ?? true) } ?? []
        let reviews = fresh.isEmpty ? count : max(1, count / 2)
        return Array((Array(due.prefix(reviews)) + (randomized ? fresh.shuffled() : fresh)).prefix(count))
    }

    func isFullyMastered(course: CourseDefinition) -> Bool {
        course.units.allSatisfy { unit in
            (unit.checkpointQuiz == nil || checkpoints[course.id]?[unit.id]?.passed == true) &&
            unit.lessons.allSatisfy { lesson in
                status(course: course, lessonId: lesson.id) == .completed &&
                lesson.cards.allSatisfy { (srs[$0.id]?.masteryScore ?? 0) >= 3 }
            }
        }
    }

    @discardableResult
    mutating func answer(course: CourseDefinition, lessonId: String, cardId: String, correct: Bool, token: String) -> Bool {
        guard !eventTokens.contains(token), status(course: course, lessonId: lessonId) != .locked,
              let lesson = course.units.flatMap(\.lessons).first(where: { $0.id == lessonId }),
              lesson.cards.contains(where: { $0.id == cardId }) else { return false }
        eventTokens.append(token)
        var srsRecord = srs[cardId] ?? CourseCardSRSRecord(cardId: cardId)
        srsRecord.processAnswer(isCorrect: correct)
        srs[cardId] = srsRecord
        var record = progress[course.id]?[lessonId] ?? CourseLessonProgressRecord(status: .current)
        record.totalAttemptsCount += 1
        if correct {
            record.correctAnswersCount += 1
            if !record.masteredCardIds.contains(cardId) { record.masteredCardIds.append(cardId) }
        }
        if Set(record.masteredCardIds).isSuperset(of: Set(lesson.cards.map(\.id))) {
            record.status = .completed
            record.completedDate = record.completedDate ?? Date()
        }
        progress[course.id, default: [:]][lessonId] = record
        return true
    }

    mutating func checkpoint(course: CourseDefinition, unit: CourseUnit, missed: [String], passingThreshold: Double? = nil) -> CourseCheckpointResult? {
        guard let quiz = unit.checkpointQuiz,
              unit.lessons.allSatisfy({ status(course: course, lessonId: $0.id) == .completed }),
              Set(missed).isSubset(of: Set(quiz.questions.map(\.id))) else { return nil }
        let failures = Set(missed)
        let score = quiz.questions.count - failures.count
        let result = CourseCheckpointResult(checkpointId: quiz.id, sectionId: unit.id,
            score: score, totalQuestions: quiz.questions.count,
            passed: Double(score) / Double(max(1, quiz.questions.count)) >= min(1, max(0.5, passingThreshold ?? quiz.passingScoreThreshold)),
            missedQuestionIds: quiz.questions.filter { failures.contains($0.id) }.map(\.id),
            missedConcepts: Array(Set(quiz.questions.filter { failures.contains($0.id) }.compactMap(\.conceptTag))).sorted())
        // A failed practice retake never locks a previously passed section.
        if checkpoints[course.id]?[unit.id]?.passed != true { checkpoints[course.id, default: [:]][unit.id] = result }
        return result
    }
}

@MainActor
final class CourseLearningStore {
    static let shared = CourseLearningStore()
    private let directory: URL?
    private let defaults: UserDefaults?
    private(set) var lastError: String?

    init(directory: URL? = nil, defaults: UserDefaults? = UserDefaults(suiteName: "group.com.learnalert.shared")) {
        self.defaults = defaults
        let sharedDirectory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.learnalert.shared")
        #if targetEnvironment(simulator)
        // Unsigned simulator launches have no App Group entitlement. Keep their
        // practice data local; signed device builds require the shared container.
        self.directory = directory ?? sharedDirectory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("CourseLearning")
        #else
        self.directory = directory ?? sharedDirectory
        #endif
    }

    private func read() throws -> CourseLearningSnapshot {
        guard let directory else { throw CocoaError(.fileReadNoSuchFile) }
        let url = directory.appendingPathComponent("course-learning-v1.json")
        if FileManager.default.fileExists(atPath: url.path) {
            return try JSONDecoder().decode(CourseLearningSnapshot.self, from: Data(contentsOf: url))
        }
        var state = CourseLearningSnapshot()
        for course in CourseCurriculumCatalog.courses {
            if let data = defaults?.data(forKey: "course_progress_\(course.id)") {
                state.progress[course.id] = try JSONDecoder().decode([String: CourseLessonProgressRecord].self, from: data)
            }
            if let data = defaults?.data(forKey: "course_checkpoints_\(course.id)") {
                state.checkpoints[course.id] = try JSONDecoder().decode([String: CourseCheckpointResult].self, from: data)
            }
        }
        if let data = defaults?.data(forKey: "course_srs_records") { state.srs = try JSONDecoder().decode([String: CourseCardSRSRecord].self, from: data) }
        state.eventTokens = defaults?.stringArray(forKey: "course_processed_event_tokens") ?? []
        return state
    }

    func snapshot() -> CourseLearningSnapshot {
        do { let result = try read(); lastError = nil; return result }
        catch { lastError = error.localizedDescription; return CourseLearningSnapshot() }
    }

    @discardableResult
    func transaction<T>(_ edit: (inout CourseLearningSnapshot) -> T) -> T? {
        do {
            guard let directory else { throw CocoaError(.fileWriteNoPermission) }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let descriptor = open(directory.appendingPathComponent("course-learning.lock").path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
            guard descriptor >= 0 else { throw CocoaError(.fileWriteUnknown) }
            defer { flock(descriptor, LOCK_UN); close(descriptor) }
            guard flock(descriptor, LOCK_EX) == 0 else { throw CocoaError(.fileWriteUnknown) }
            var state = try read()
            let result = edit(&state)
            try JSONEncoder().encode(state).write(to: directory.appendingPathComponent("course-learning-v1.json"), options: .atomic)
            lastError = nil
            return result
        } catch { lastError = error.localizedDescription; return nil }
    }
}
