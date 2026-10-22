import Foundation
import Darwin
import CryptoKit

/// An unfinished in-app attempt. Graded answers also persist before Continue is tapped.
struct CoursePracticeSession: Codable {
    var id = UUID().uuidString
    var cardIds: [String]
    var answers: [String: Bool] = [:]
    var groupIdsByCard: [String: String]? = nil
    var attemptCounts: [String: Int]? = nil
    /// New exercises retain graded feedback until Continue is explicitly acknowledged.
    var pendingContinueCardID: String? = nil
    var pendingContinueAttemptID: String? = nil
    var exerciseDefinitionsByCard: [String: CourseExercise]? = nil
    var invalidatedExerciseCardIDs: [String]? = nil

    var nextIndex: Int? {
        for (index, id) in cardIds.enumerated() {
            if let group = groupIdsByCard?[id] {
                let indices = cardIds.indices.filter { groupIdsByCard?[cardIds[$0]] == group }
                if let next = indices.first(where: { answers[cardIds[$0]] == nil }) { return next }
                if let retry = indices.first(where: { answers[cardIds[$0]] == false }) { return retry }
            } else if answers[id] == nil { return index }
        }
        return nil
    }
    var missedCardIds: [String] { cardIds.filter { answers[$0] == false } }
}

struct CoursePracticeCompletion {
    var checkpointResult: CourseCheckpointResult?
}

/// One atomic, cross-process course snapshot, shared by the app and notification extension.
struct CourseLearningSnapshot: Codable {
    var progress: [String: [String: CourseLessonProgressRecord]] = [:]
    var checkpoints: [String: [String: CourseCheckpointResult]] = [:]
    /// Read-only legacy records from releases before managed courses existed.
    var srs: [String: CourseCardSRSRecord] = [:]
    /// IDs are local to a course. New records never share mastery across courses.
    var courseSRS: [String: [String: CourseCardSRSRecord]] = [:]
    var eventTokens: [String] = []
    var practiceSessions: [String: CoursePracticeSession] = [:]
    var traceAttempts: [String: Int] = [:]
    var notificationExerciseCardIDs: [String: String] = [:]
    var notificationExerciseAttempts: [String: CourseExerciseAcknowledgement] = [:]
    var schemaVersion = 6
    var routes: [String: CourseRouteAssignment] = [:]
    var assessmentAttempts: [String: CourseAssessmentAttempt] = [:]
    var activeAssessmentIDs: [String: String] = [:]
    var assessmentAccess: [String: [String]] = [:]
    var migration: CourseMigrationMetadata? = nil
    var exerciseDrafts: [String: CourseSavedExercise] = [:]
    var exerciseEvidence: [String: CourseExerciseEvidence] = [:]
    /// Completion is access credit; new variants never revoke it or invent skill evidence.
    var retainedCompletion: [String: [String]] = [:]

    init() {}

    private enum CodingKeys: String, CodingKey { case progress, checkpoints, srs, courseSRS, eventTokens, practiceSessions, traceAttempts, schemaVersion, exerciseDrafts, exerciseEvidence, retainedCompletion, notificationExerciseCardIDs, notificationExerciseAttempts, migration, routes, assessmentAttempts, activeAssessmentIDs, assessmentAccess }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        progress = try values.decodeIfPresent([String: [String: CourseLessonProgressRecord]].self, forKey: .progress) ?? [:]
        checkpoints = try values.decodeIfPresent([String: [String: CourseCheckpointResult]].self, forKey: .checkpoints) ?? [:]
        srs = try values.decodeIfPresent([String: CourseCardSRSRecord].self, forKey: .srs) ?? [:]
        courseSRS = try values.decodeIfPresent([String: [String: CourseCardSRSRecord]].self, forKey: .courseSRS) ?? [:]
        eventTokens = try values.decodeIfPresent([String].self, forKey: .eventTokens) ?? []
        practiceSessions = try values.decodeIfPresent([String: CoursePracticeSession].self, forKey: .practiceSessions) ?? [:]
        traceAttempts = try values.decodeIfPresent([String: Int].self, forKey: .traceAttempts) ?? [:]
        let version = try values.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        guard version <= 6 else { throw CocoaError(.coderReadCorrupt) }
        schemaVersion = 6
        routes = try values.decodeIfPresent([String: CourseRouteAssignment].self, forKey: .routes) ?? [:]
        assessmentAttempts = try values.decodeIfPresent([String: CourseAssessmentAttempt].self, forKey: .assessmentAttempts) ?? [:]
        activeAssessmentIDs = try values.decodeIfPresent([String: String].self, forKey: .activeAssessmentIDs) ?? [:]
        assessmentAccess = try values.decodeIfPresent([String: [String]].self, forKey: .assessmentAccess) ?? [:]
        migration = try values.decodeIfPresent(CourseMigrationMetadata.self, forKey: .migration)
        notificationExerciseCardIDs = try values.decodeIfPresent([String: String].self, forKey: .notificationExerciseCardIDs) ?? [:]
        notificationExerciseAttempts = try values.decodeIfPresent([String: CourseExerciseAcknowledgement].self, forKey: .notificationExerciseAttempts) ?? [:]
        exerciseDrafts = try values.decodeIfPresent([String: CourseSavedExercise].self, forKey: .exerciseDrafts) ?? [:]
        exerciseEvidence = try values.decodeIfPresent([String: CourseExerciseEvidence].self, forKey: .exerciseEvidence) ?? [:]
        retainedCompletion = try values.decodeIfPresent([String: [String]].self, forKey: .retainedCompletion) ?? [:]
        for (courseID, lessons) in progress {
            for (lessonID, record) in lessons where record.status == .completed {
                if retainedCompletion[courseID]?.contains(lessonID) != true { retainedCompletion[courseID, default: []].append(lessonID) }
            }
        }
        migrateLegacySRS()
    }

    // Only the original bundled author owns pre-managed unqualified history.
    // An AI course reusing a Korean/Spanish card ID must start with fresh SRS.
    private static let legacySRSOwners: [String: String] = {
        var owners: [String: String] = [:]
        for course in CourseCurriculumCatalog.bundledCourses {
            for card in course.units.flatMap(\.lessons).flatMap(\.cards) {
                if owners[card.id] == nil { owners[card.id] = course.id }
            }
        }
        return owners
    }()

    func srsRecord(courseId: String, cardId: String) -> CourseCardSRSRecord? {
        if let record = courseSRS[courseId]?[cardId] { return record }
        guard let legacy = srs[cardId], Self.legacySRSOwners[cardId] == courseId else { return nil }
        return legacy
    }

    mutating func migrateLegacySRS() {
        for (cardId, record) in srs {
            guard let courseId = Self.legacySRSOwners[cardId], courseSRS[courseId]?[cardId] == nil else { continue }
            courseSRS[courseId, default: [:]][cardId] = record
        }
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

    /// Keep the entire durable session, including temporarily blocked work.
    /// Presentation and new grading share the same prerequisite admission rule.
    /// Already-graded feedback may still be acknowledged without new credit.
    func canPresentPracticeCard(course: CourseDefinition, lessonId: String?, checkpointUnitId: String?, sessionId: String, cardId: String) -> Bool {
        guard let key = Self.practiceKey(courseId: course.id, lessonId: lessonId, checkpointUnitId: checkpointUnitId),
              let session = practiceSessions[key], session.id == sessionId,
              let card = practiceCards(course: course, lessonId: lessonId, checkpointUnitId: checkpointUnitId)?.first(where: { $0.id == cardId }) else { return false }
        if session.pendingContinueCardID == cardId, session.answers[cardId] != nil { return true }
        return session.nextIndex.map { session.cardIds[$0] == cardId } == true && satisfiesPrerequisites(card: card, course: course)
    }

    static func orderedLearningCards(_ cards: [CourseLessonCard], randomized: Bool = true) -> [CourseLessonCard] {
        if cards.contains(where: { $0.activity?.exercise?.prerequisiteIDs != nil }) {
            return cards.enumerated().sorted {
                let left = $0.element.activity?.sequence ?? 0, right = $1.element.activity?.sequence ?? 0
                return left == right ? $0.offset < $1.offset : left < right
            }.map(\.element)
        }
        let stages = Set(cards.map(\.learningStage)).sorted()
        return stages.flatMap { stage in
            let group = cards.filter { $0.learningStage == stage }
            return randomized && stage > 1 ? group.shuffled() : group
        }
    }

    mutating func resumePractice(course: CourseDefinition, lessonId: String?, checkpointUnitId: String?) -> CoursePracticeSession? {
        guard let key = Self.practiceKey(courseId: course.id, lessonId: lessonId, checkpointUnitId: checkpointUnitId),
              let cards = practiceCards(course: course, lessonId: lessonId, checkpointUnitId: checkpointUnitId), !cards.isEmpty else { return nil }
        var session = practiceSessions[key] ?? CoursePracticeSession(cardIds: [])
        let definitions = Dictionary(uniqueKeysWithValues: cards.compactMap { card in card.activity?.exercise.map { (card.id, $0) } })
        var invalidated = Set(session.invalidatedExerciseCardIDs ?? [])
        for id in session.cardIds {
            let removed = !cards.contains(where: { $0.id == id })
            let changed = session.exerciseDefinitionsByCard.map { $0[id] != definitions[id] } ?? false
            if removed || changed {
                // Invalidation applies to historical answers/ownership, not to a
                // fresh Check saved after this session adopts the new definition.
                retireSessionExerciseOwnership(courseID: course.id, sessionID: session.id, cardID: id)
                if !removed { invalidated.insert(id) }
            }
        }
        if let pending = session.pendingContinueCardID {
            let draft = exerciseDrafts[Self.exerciseKey(courseID: course.id, cardID: pending)]
            let attemptID = session.pendingContinueAttemptID
            let current = cards.first { $0.id == pending }
            let changed = current != nil && (current?.activity?.exercise == nil || draft.map { $0.exercise != current?.activity?.exercise } == true)
            let removed = current == nil
            if changed { invalidated.insert(pending) }
            if removed || changed { retireSessionExerciseOwnership(courseID: course.id, sessionID: session.id, cardID: pending) }
            if removed || changed || draft == nil || attemptID == nil || draft?.state.attemptID != attemptID || draft?.state.result == nil || invalidated.contains(pending) {
                if let attemptID { _ = acknowledgeExercise(courseID: course.id, cardID: pending, attemptID: attemptID) }
                session.pendingContinueCardID = nil; session.pendingContinueAttemptID = nil
            } else { session.pendingContinueAttemptID = attemptID }
        }
        session.exerciseDefinitionsByCard = definitions
        session.invalidatedExerciseCardIDs = Array(invalidated.intersection(Set(cards.map(\.id)))).sorted()
        let validIds = Set(cards.map(\.id))
        let survivingIds = session.cardIds.filter { validIds.contains($0) }
        let added = cards.filter { !survivingIds.contains($0.id) }
        // New sessions teach before testing; an existing session retains its saved order and answers.
        // Checkpoints remain shuffled assessments rather than following the lesson stages.
        let ordered = checkpointUnitId == nil && (course.language == "Korean" || cards.contains { $0.activity?.exercise != nil })
            ? Self.orderedLearningCards(added) : added.shuffled()
        session.cardIds = survivingIds + ordered.map(\.id)
        if cards.contains(where: { $0.activity?.exercise?.prerequisiteIDs != nil }) { session.cardIds = Self.orderedLearningCards(cards, randomized: false).map(\.id) }
        let groups = Dictionary(uniqueKeysWithValues: cards.compactMap { card in card.activity?.practiceGroup.map { (card.id, $0) } })
        session.groupIdsByCard = checkpointUnitId == nil ? groups : nil
        if !groups.isEmpty {
            // Keep saved answers, but align older sessions with the new letter groups.
            session.cardIds = Self.orderedLearningCards(cards, randomized: false).map(\.id)
        }
        session.answers = session.answers.filter { session.cardIds.contains($0.key) && !invalidated.contains($0.key) }
        if let lessonId, !groups.isEmpty {
            // Older sessions can contain saved correct answers without a matching
            // progress entry. Reconcile that evidence before applying letter gates.
            var record = progress[course.id]?[lessonId] ?? CourseLessonProgressRecord(status: .current)
            for (id, correct) in session.answers where correct && !record.masteredCardIds.contains(id) {
                record.masteredCardIds.append(id)
            }
            if Set(record.masteredCardIds).isSuperset(of: validIds) {
                record.status = .completed
                record.completedDate = record.completedDate ?? Date()
            }
            progress[course.id, default: [:]][lessonId] = record
        }
        if let lessonId, status(course: course, lessonId: lessonId) != .completed {
            // Existing saved answers, including notification answers, should not restart a lesson.
            for id in progress[course.id]?[lessonId]?.masteredCardIds ?? [] where session.cardIds.contains(id) && session.answers[id] == nil && !invalidated.contains(id) {
                session.answers[id] = true
            }
        }
        practiceSessions[key] = session
        return session
    }

    @discardableResult
    mutating func answerPractice(course: CourseDefinition, lessonId: String?, checkpointUnitId: String?, sessionId: String, cardId: String, correct: Bool, exerciseAttemptID: String? = nil) -> Bool {
        guard let key = Self.practiceKey(courseId: course.id, lessonId: lessonId, checkpointUnitId: checkpointUnitId),
              var session = practiceSessions[key], session.id == sessionId,
              let card = practiceCards(course: course, lessonId: lessonId, checkpointUnitId: checkpointUnitId)?.first(where: { $0.id == cardId }) else { return false }
        if let exerciseAttemptID, eventTokens.contains(Self.sessionExerciseReceipt(sessionID: session.id, attemptID: exerciseAttemptID)) {
            let currentDraft = exerciseDrafts[Self.exerciseKey(courseID: course.id, cardID: cardId)]
            return exerciseEvidence[exerciseAttemptID]?.courseID == course.id && exerciseEvidence[exerciseAttemptID]?.cardID == cardId &&
                exerciseEvidence[exerciseAttemptID]?.correct == correct && session.answers[cardId] == correct &&
                session.exerciseDefinitionsByCard?[cardId] == card.activity?.exercise &&
                session.invalidatedExerciseCardIDs?.contains(cardId) != true &&
                (currentDraft == nil || currentDraft?.state.attemptID == exerciseAttemptID)
        }
        guard let next = session.nextIndex, session.cardIds[next] == cardId,
              satisfiesPrerequisites(card: card, course: course) else { return false }
        if let exerciseAttemptID, exerciseDrafts[Self.exerciseKey(courseID: course.id, cardID: cardId)]?.state.attemptID != exerciseAttemptID { return false }
        let attempt = session.attemptCounts?[cardId] ?? 0
        if let lessonId, !answer(course: course, lessonId: lessonId, cardId: cardId, correct: correct, token: "\(session.id)-\(cardId)-attempt-\(attempt)", exerciseAttemptID: exerciseAttemptID) { return false }
        if session.attemptCounts == nil { session.attemptCounts = [:] }
        session.attemptCounts?[cardId] = attempt + 1
        session.answers[cardId] = correct
        session.invalidatedExerciseCardIDs?.removeAll { $0 == cardId }
        if card.activity?.exercise?.usesPracticeRenderer == true {
            session.pendingContinueCardID = cardId
            session.pendingContinueAttemptID = exerciseDrafts[Self.exerciseKey(courseID: course.id, cardID: cardId)]?.state.attemptID
            if checkpointUnitId != nil { captureExerciseEvidence(courseID: course.id, card: card) }
            if let identity = session.pendingContinueAttemptID {
                eventTokens.append(Self.sessionExerciseReceipt(sessionID: session.id, attemptID: identity))
            }
        }
        practiceSessions[key] = session
        return true
    }

    mutating func finishPractice(course: CourseDefinition, lessonId: String?, checkpointUnitId: String?, sessionId: String, passingThreshold: Double? = nil) -> CoursePracticeCompletion? {
        guard let key = Self.practiceKey(courseId: course.id, lessonId: lessonId, checkpointUnitId: checkpointUnitId),
              let session = practiceSessions[key], session.id == sessionId, session.nextIndex == nil,
              session.pendingContinueCardID == nil else { return nil }
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
        let scoped = course.units.flatMap(\.lessons).filter { routes[course.id]?.lessonIDs.contains($0.id) ?? true }
        let lessonProgress = scoped.reduce(0.0) { total, lesson in
            let record = progress[course.id]?[lesson.id]
            if status(course: course, lessonId: lesson.id) == .completed { return total + 1 }
            let mastered = Set(record?.masteredCardIds ?? []).intersection(Set(lesson.cards.map(\.id))).count
            return total + Double(mastered) / Double(max(1, lesson.cards.count))
        }
        let quizzes = course.units.filter { $0.checkpointQuiz != nil && $0.lessons.contains { lesson in routes[course.id]?.lessonIDs.contains(lesson.id) ?? true } }
        let passed = quizzes.filter { checkpoints[course.id]?[$0.id]?.passed == true }.count
        return min(1, (lessonProgress + Double(passed)) / Double(max(1, scoped.count + quizzes.count)))
    }

    func status(course: CourseDefinition, lessonId: String) -> LessonStatus {
        for (index, unit) in course.units.enumerated() where unit.lessons.contains(where: { $0.id == lessonId }) {
            let lesson = unit.lessons.first { $0.id == lessonId }!
            if hasCompleted(lesson, in: unit, course: course) { return .completed }
            if course.learning?.starter?.lessonIDs.contains(lessonId) == true {
                let assigned = assignedStarterLessonIDs(course: course)
                guard assigned.contains(lessonId) else { return .locked }
                if assessmentAccess[course.id]?.contains(lessonId) == true { return .available }
                return assigned.prefix(while: { $0 != lessonId }).allSatisfy { id in assessmentAccess[course.id]?.contains(id) == true || course.units.contains { unit in unit.lessons.contains { $0.id == id && hasCompleted($0, in: unit, course: course) } } } ? .current : .locked
            }
            // Existing learning/Continue position predates any newly authored gate.
            let key = Self.practiceKey(courseId: course.id, lessonId: lessonId, checkpointUnitId: nil)!
            if (progress[course.id]?[lessonId]?.totalAttemptsCount ?? 0) > 0 || practiceSessions[key]?.cardIds.isEmpty == false { return .current }
            if course.units.prefix(index).contains(where: { previous in
                previous.checkpointQuiz != nil && previous.lessons.contains { activeRouteLessonIDs(course: course).contains($0.id) } && checkpoints[course.id]?[previous.id]?.passed != true
            }) { return .locked }
            guard let lessonIndex = unit.lessons.firstIndex(where: { $0.id == lessonId }) else { return .locked }
            if unit.lessons.prefix(lessonIndex).contains(where: { !hasCompleted($0, in: unit, course: course) }) { return .locked }
            return hasCompleted(unit.lessons[lessonIndex], in: unit, course: course) ? .completed : .current
        }
        return .locked
    }

    /// Completion is retained access credit, independent of today's exercise count.
    private func hasCompleted(_ lesson: CourseLesson, in unit: CourseUnit, course: CourseDefinition) -> Bool {
        if checkpoints[course.id]?[unit.id]?.passed == true { return true }
        return progress[course.id]?[lesson.id]?.status == .completed || retainedCompletion[course.id]?.contains(lesson.id) == true
    }

    func pendingCheckpoint(course: CourseDefinition) -> CourseUnit? {
        if routes[course.id]?.starterSelected == true, let ids = Optional(assignedStarterLessonIDs(course: course)),
           ids.contains(where: { status(course: course, lessonId: $0) != .completed && assessmentAccess[course.id]?.contains($0) != true }) { return nil }
        return course.units.first { unit in
            unit.checkpointQuiz != nil && unit.lessons.contains { activeRouteLessonIDs(course: course).contains($0.id) } && checkpoints[course.id]?[unit.id]?.passed != true &&
            unit.lessons.allSatisfy { status(course: course, lessonId: $0.id) == .completed }
        }
    }

    func currentLesson(course: CourseDefinition) -> CourseLesson? {
        let lessons = course.units.flatMap(\.lessons)
        let starterIDs = assignedStarterLessonIDs(course: course)
        if let route = routes[course.id] {
            if let anchor = route.expansionContinueLessonID, let lesson = lessons.first(where: { $0.id == anchor }) {
                let key = Self.practiceKey(courseId: course.id, lessonId: anchor, checkpointUnitId: nil)!
                if practiceSessions[key]?.nextIndex != nil || status(course: course, lessonId: anchor) == .current { return lesson }
            }
            if route.starterSelected, let pending = starterIDs.compactMap({ id in lessons.first { $0.id == id } }).first(where: { lesson in
                let key = Self.practiceKey(courseId: course.id, lessonId: lesson.id, checkpointUnitId: nil)!
                return practiceSessions[key]?.pendingContinueCardID != nil
            }) { return pending }
            if let anchor = route.originalContinueLessonID, let lesson = lessons.first(where: { $0.id == anchor }) {
                let key = Self.practiceKey(courseId: course.id, lessonId: anchor, checkpointUnitId: nil)!
                if practiceSessions[key]?.pendingContinueCardID != nil { return lesson }
            }
            if route.starterSelected, let next = starterIDs.compactMap({ id in lessons.first { $0.id == id } }).first(where: {
                status(course: course, lessonId: $0.id) != .completed && assessmentAccess[course.id]?.contains($0.id) != true
            }) { return next }
            if let anchor = route.originalContinueLessonID, let lesson = lessons.first(where: { $0.id == anchor }), status(course: course, lessonId: anchor) == .current { return lesson }
            return route.lessonIDs.compactMap { id in lessons.first { $0.id == id } }.first { status(course: course, lessonId: $0.id) == .current && assessmentAccess[course.id]?.contains($0.id) != true }
        }
        // Metadata may arrive before migration/enrollment. Existing Continue stays
        // on its old path until a route is explicitly assigned.
        return lessons.first { !starterIDs.contains($0.id) && status(course: course, lessonId: $0.id) == .current }
    }

    func batch(course: CourseDefinition, count: Int, now: Date = Date(), reviewOnly: Bool = false, randomized: Bool = false) -> [CourseLessonCard] {
        guard count > 0 else { return [] }
        let due = course.units.flatMap(\.lessons).filter { status(course: course, lessonId: $0.id) == .completed }
            .flatMap { lesson in
                let learned = Set(progress[course.id]?[lesson.id]?.masteredCardIds ?? [])
                return lesson.cards.filter { card in
                    // Replacing a passed unit never turns unseen workshop material into due reviews.
                    !card.isExposure && satisfiesPrerequisites(card: card, course: course) && (card.activity == nil || srsRecord(courseId: course.id, cardId: card.id) != nil || learned.contains(card.id)) &&
                    (srsRecord(courseId: course.id, cardId: card.id).map { ($0.nextReviewDate ?? .distantPast) <= now } ?? true)
                }
            }
            .sorted { (srsRecord(courseId: course.id, cardId: $0.id)?.nextReviewDate ?? .distantPast) < (srsRecord(courseId: course.id, cardId: $1.id)?.nextReviewDate ?? .distantPast) }
        let lesson = reviewOnly ? nil : currentLesson(course: course)
        let mastered = Set(progress[course.id]?[lesson?.id ?? ""]?.masteredCardIds ?? [])
        var fresh = lesson?.cards.filter { satisfiesPrerequisites(card: $0, course: course) && !mastered.contains($0.id) && (srsRecord(courseId: course.id, cardId: $0.id).map { ($0.nextReviewDate ?? .distantPast) <= now } ?? true) } ?? []
        if let lesson, let focused = focusedLearningCards(lesson: lesson, mastered: mastered) {
            // Missed tasks return within this letter's group; future letters stay gated.
            fresh = focused.filter { satisfiesPrerequisites(card: $0, course: course) }.sorted {
                let lhs = srsRecord(courseId: course.id, cardId: $0.id)?.lastReviewedDate ?? .distantPast
                let rhs = srsRecord(courseId: course.id, cardId: $1.id)?.lastReviewedDate ?? .distantPast
                return lhs == rhs ? $0.learningStage < $1.learningStage : lhs < rhs
            }
            return Array(fresh.prefix(count))
        }
        let reviews = fresh.isEmpty ? count : max(1, count / 2)
        let learning = course.language == "Korean"
            ? Self.orderedLearningCards(fresh, randomized: randomized) : randomized ? fresh.shuffled() : fresh
        return Array((Array(due.prefix(reviews)) + learning).prefix(count))
    }

    private func focusedLearningCards(lesson: CourseLesson, mastered: Set<String>) -> [CourseLessonCard]? {
        guard lesson.cards.contains(where: { $0.activity?.practiceGroup != nil }) else { return nil }
        let ordered = Self.orderedLearningCards(lesson.cards, randomized: false)
        guard let first = ordered.first(where: { !mastered.contains($0.id) }) else { return [] }
        guard let group = first.activity?.practiceGroup else { return [first] }
        return ordered.filter { $0.activity?.practiceGroup == group && !mastered.contains($0.id) }
    }

    func isFullyMastered(course: CourseDefinition) -> Bool {
        let scope: Set<String>? = routes[course.id].map { route in
            Set(route.lessonIDs + (route.starterSelected ? assignedStarterLessonIDs(course: course) : []))
        }
        return course.units.allSatisfy { unit in
            let lessons = unit.lessons.filter { scope?.contains($0.id) ?? true }
            return (scope != nil && lessons.isEmpty) || ((unit.checkpointQuiz == nil || checkpoints[course.id]?[unit.id]?.passed == true) &&
            lessons.allSatisfy { lesson in
                status(course: course, lessonId: lesson.id) == .completed &&
                lesson.cards.filter { !$0.isExposure }.allSatisfy { (srsRecord(courseId: course.id, cardId: $0.id)?.masteryScore ?? 0) >= 3 }
            })
        }
    }

    @discardableResult
    mutating func answer(course: CourseDefinition, lessonId: String, cardId: String, correct: Bool, token: String, exerciseAttemptID: String? = nil) -> Bool {
        guard status(course: course, lessonId: lessonId) != .locked,
              let lesson = course.units.flatMap(\.lessons).first(where: { $0.id == lessonId }),
              let card = lesson.cards.first(where: { $0.id == cardId }) else { return false }
        var eventIdentity = token
        if let exercise = card.activity?.exercise, exercise.usesPracticeRenderer {
            guard let draft = exerciseDrafts[Self.exerciseKey(courseID: course.id, cardID: cardId)],
                  draft.exercise == exercise, draft.state.result == correct else { return false }
            if let exerciseAttemptID, draft.state.attemptID != exerciseAttemptID { return false }
            eventIdentity = "exercise:" + draft.state.attemptID
            if eventTokens.contains(eventIdentity) {
                // App and notification may acknowledge the same durable Check.
                // Accept its acknowledgement without counting a second review.
                return exerciseEvidence[draft.state.attemptID]?.courseID == course.id &&
                    exerciseEvidence[draft.state.attemptID]?.cardID == cardId &&
                    exerciseEvidence[draft.state.attemptID]?.correct == correct
            }
        } else if eventTokens.contains(token) { return false }
        if status(course: course, lessonId: lessonId) != .completed,
           progress[course.id]?[lessonId]?.masteredCardIds.contains(cardId) != true,
           let focused = focusedLearningCards(lesson: lesson, mastered: Set(progress[course.id]?[lessonId]?.masteredCardIds ?? [])),
           !focused.contains(where: { $0.id == cardId }) { return false }
        guard satisfiesPrerequisites(card: card, course: course) else { return false }
        eventTokens.append(eventIdentity)
        let exercise = card.activity?.exercise
        captureExerciseEvidence(courseID: course.id, card: card)
        // Viewing an introduction is exposure, not retrieval or spaced mastery.
        if exercise?.format != "exposure" {
            var recordForCard = srsRecord(courseId: course.id, cardId: cardId) ?? CourseCardSRSRecord(cardId: cardId)
            recordForCard.processAnswer(isCorrect: correct)
            courseSRS[course.id, default: [:]][cardId] = recordForCard
        }
        var record = progress[course.id]?[lessonId] ?? CourseLessonProgressRecord(status: .current)
        record.totalAttemptsCount += 1
        if correct {
            record.correctAnswersCount += 1
            if !record.masteredCardIds.contains(cardId) { record.masteredCardIds.append(cardId) }
        }
        if Set(record.masteredCardIds).isSuperset(of: Set(lesson.cards.map(\.id))) {
            if retainedCompletion[course.id]?.contains(lessonId) != true { retainedCompletion[course.id, default: []].append(lessonId) }
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
            passed: Double(score) / Double(max(1, quiz.questions.count)) >= min(1, max(0, passingThreshold ?? quiz.passingScoreThreshold)),
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
    private let commitObserver: ((CourseLearningCommitStage) throws -> Void)?

    init(directory: URL? = nil, defaults: UserDefaults? = UserDefaults(suiteName: "group.com.learnalert.shared"),
         commitObserver: ((CourseLearningCommitStage) throws -> Void)? = nil) {
        self.commitObserver = commitObserver
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

    private func sources() throws -> CourseLearningReadSources {
        .init(active: try optionalData("course-learning-v2.json"), legacy: try optionalData("course-learning-v1.json"), defaults: try legacyDefaultsData())
    }
    private func read(_ source: CourseLearningReadSources) throws -> CourseLearningSnapshot {
        if let active = source.active { return try JSONDecoder().decode(CourseLearningSnapshot.self, from: active) }
        if let legacy = source.legacy { return try JSONDecoder().decode(CourseLearningSnapshot.self, from: legacy) }
        let raw = try JSONDecoder().decode([String: Data].self, from: source.defaults)
        var state = CourseLearningSnapshot()
        for (key, bytes) in raw {
            let wrapped = try PropertyListSerialization.propertyList(from: bytes, format: nil) as? [String: Any]
            if key == "course_processed_event_tokens" {
                guard let tokens = wrapped?["value"] as? [String] else { throw CocoaError(.coderReadCorrupt) }
                state.eventTokens = tokens
            } else {
                guard let data = wrapped?["value"] as? Data else { throw CocoaError(.coderReadCorrupt) }
                if key.hasPrefix("course_progress_") {
                    state.progress[String(key.dropFirst("course_progress_".count))] = try JSONDecoder().decode([String: CourseLessonProgressRecord].self, from: data)
                } else if key.hasPrefix("course_checkpoints_") {
                    state.checkpoints[String(key.dropFirst("course_checkpoints_".count))] = try JSONDecoder().decode([String: CourseCheckpointResult].self, from: data)
                } else if key == "course_srs_records" { state.srs = try JSONDecoder().decode([String: CourseCardSRSRecord].self, from: data) }
            }
        }
        state.migrateLegacySRS()
        return state
    }

    private func locked<T>(_ operation: () throws -> T) throws -> T {
        guard let directory else { throw CocoaError(.fileWriteNoPermission) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let descriptor = open(directory.appendingPathComponent("course-learning.lock").path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw CocoaError(.fileWriteUnknown) }
        defer { flock(descriptor, LOCK_UN); close(descriptor) }
        guard flock(descriptor, LOCK_EX) == 0 else { throw CocoaError(.fileWriteUnknown) }
        return try operation()
    }

    private func commit(_ state: CourseLearningSnapshot) throws {
        guard let directory else { throw CocoaError(.fileWriteNoPermission) }
        let data = try JSONEncoder().encode(state)
        try commitObserver?(.beforeInstall)
        try data.write(to: directory.appendingPathComponent("course-learning-v2.json"), options: .atomic)
        try commitObserver?(.afterInstall)
    }

    func snapshot() -> CourseLearningSnapshot {
        do {
            let state = try locked {
                let source = try sources()
                var state = try read(source)
                if try preserveLegacyBranches(&state, source: source) { try commit(state) }
                return state
            }
            lastError = nil
            return state
        } catch { lastError = error.localizedDescription; return CourseLearningSnapshot() }
    }

    @discardableResult
    func transaction<T>(_ edit: (inout CourseLearningSnapshot) -> T) -> T? {
        do {
            let result = try locked {
                let source = try sources()
                var state = try read(source)
                _ = try preserveLegacyBranches(&state, source: source)
                let result = edit(&state)
                try commit(state)
                return result
            }
            lastError = nil
            return result
        } catch { lastError = error.localizedDescription; return nil }
    }

    private func legacyDefaultsData() throws -> Data {
        // Only course progress keys. Never export credentials, account tokens,
        // arbitrary defaults, enrollment preferences or unrelated app data.
        defaults?.synchronize()
        let values = defaults?.dictionaryRepresentation() ?? [:]
        var data: [String: Data] = [:]
        for (key, value) in values where key.hasPrefix("course_progress_") || key.hasPrefix("course_checkpoints_") ||
            key == "course_srs_records" || key == "course_processed_event_tokens" {
            data[key] = try PropertyListSerialization.data(fromPropertyList: ["value": value], format: .binary, options: 0)
        }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(data)
    }
    private func optionalData(_ name: String) throws -> Data? {
        guard let directory else { throw CocoaError(.fileReadNoSuchFile) }
        let url = directory.appendingPathComponent(name)
        return FileManager.default.fileExists(atPath: url.path) ? try Data(contentsOf: url) : nil
    }
    private func archive(_ bytes: Data, prefix: String) throws -> String {
        guard let directory else { throw CocoaError(.fileWriteNoPermission) }
        let folder = directory.appendingPathComponent("CourseProgressRecovery", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let filename = prefix + "-" + Self.digest(bytes) + ".json"
        let destination = folder.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: destination.path) {
            guard try Data(contentsOf: destination) == bytes else { throw CocoaError(.fileReadCorruptFile) }
        } else { try bytes.write(to: destination, options: .atomic) }
        return filename
    }
    private static func digest(_ bytes: Data) -> String { SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined() }

    /// Archive source bytes first, then commit their identity with v2 atomically.
    /// An interrupted pre-install migration is retried from the current source.
    private func preserveLegacyBranches(_ state: inout CourseLearningSnapshot, source captured: CourseLearningReadSources) throws -> Bool {
        let legacy = captured.legacy
        let defaults = captured.defaults
        let source = CourseLegacyFingerprint(v1SHA256: legacy.map(Self.digest), defaultsSHA256: Self.digest(defaults))
        let active = captured.active
        var changed = false
        if state.migration == nil {
            var metadata = CourseMigrationMetadata(imported: active == nil ? source : nil,
                origin: active == nil ? "legacyImport" : "preRecoverySnapshot")
            metadata.importedDefaultsArchive = try archive(defaults, prefix: "imported-defaults")
            if active == nil, let legacy {
                metadata.importedV1Archive = try archive(legacy, prefix: "imported-v1")
                if try optionalData("course-learning-v1.pre-practice.json") == nil, let directory {
                    try legacy.write(to: directory.appendingPathComponent("course-learning-v1.pre-practice.json"), options: .atomic)
                }
            } else if let active {
                metadata.priorActiveArchive = try archive(active, prefix: "prior-active")
            }
            state.migration = metadata
            changed = true
        }
        guard var metadata = state.migration else { return changed }
        // Pre-recovery v2 never recorded its source. Preserve it honestly rather
        // than claiming today's old notebook was the originally imported one.
        let uncertainPriorSource = metadata.imported == nil && (legacy != nil || defaults != Data("{}".utf8))
        if (metadata.imported != nil && source != metadata.imported || uncertainPriorSource) &&
            !metadata.divergences.contains(where: { $0.source == source }) {
            let legacyArchive = try legacy.map { try archive($0, prefix: "legacy-v1") }
            let defaultsArchive = try archive(defaults, prefix: "legacy-defaults")
            let decodable = legacy.map { (try? JSONDecoder().decode(CourseLearningSnapshot.self, from: $0)) != nil } ?? true
            metadata.divergences.append(.init(source: source, v1Archive: legacyArchive, defaultsArchive: defaultsArchive,
                reason: uncertainPriorSource ? "unverifiedPriorSource" : decodable ? "olderVersionProgress" : "unreadableOlderVersionFile", detectedAt: Date()))
            state.migration = metadata
            changed = true
        }
        return changed
    }

    /// Local recovery bundle only. Neither branch is merged, replayed or uploaded.
    func recoveryExportData() throws -> Data {
        try locked {
            var readError: String?
            do {
                let source = try sources()
                var state = try read(source)
                if try preserveLegacyBranches(&state, source: source) { try commit(state) }
            } catch { readError = error.localizedDescription }
            guard let directory else { throw CocoaError(.fileReadNoSuchFile) }
            let folder = directory.appendingPathComponent("CourseProgressRecovery", isDirectory: true)
            var archives: [String: Data] = [:]
            if FileManager.default.fileExists(atPath: folder.path) {
                for url in try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.isRegularFileKey])
                    where try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
                    archives[url.lastPathComponent] = try Data(contentsOf: url)
                }
            }
            let export = CourseProgressRecoveryExport(generatedAt: Date(), activeHistory: try optionalData("course-learning-v2.json"),
                olderHistory: try optionalData("course-learning-v1.json"), olderDefaults: try legacyDefaultsData(), archives: archives, readError: readError)
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            return try encoder.encode(export)
        }
    }

}


struct CourseSavedExercise: Codable {
    var exercise: CourseExercise
    var state: CourseExerciseState
}
extension CourseLearningSnapshot {
    static func exerciseKey(courseID: String, cardID: String) -> String { courseID + "\u{1F}" + cardID }
    /// Optimistic reducer revisions reject stale app/extension views and repeated checks.
    mutating func saveExercise(courseID: String, cardID: String, exercise: CourseExercise, state: CourseExerciseState) -> Bool {
        let key = Self.exerciseKey(courseID: courseID, cardID: cardID)
        if let old = exerciseDrafts[key], old.exercise == exercise {
            if old.state == state { return true }
            guard old.state.result == nil, old.state.attemptID == state.attemptID,
                  state.revision == old.state.revision + 1,
                  state.preservesEvidence(from: old.state, exercise: exercise) else { return false }
        } else {
            // A fresh draft needs a fresh identity. In particular, a one-step
            // exposure Check can have revision1 even after it was retired.
            guard state.revision == 1, exerciseEvidence[state.attemptID] == nil,
                  !eventTokens.contains("retired-exercise:" + state.attemptID) else { return false }
            if let replaced = exerciseDrafts[key] {
                guard replaced.state.attemptID != state.attemptID else { return false }
                eventTokens.append("retired-exercise:" + replaced.state.attemptID)
            }
        }
        exerciseDrafts[key] = CourseSavedExercise(exercise: exercise, state: state)
        if state.result != nil {
            // Bind a durable Check only to sessions already displaying this exact
            // definition. A later session must not consume an earlier review.
            for (sessionKey, session) in practiceSessions where sessionKey.hasPrefix(courseID + ":lesson:") || sessionKey.hasPrefix(courseID + ":checkpoint:") {
                if let next = session.nextIndex, session.cardIds[next] == cardID,
                   session.exerciseDefinitionsByCard?[cardID] == exercise {
                    let owner = Self.sessionCheckOwner(sessionID: session.id, attemptID: state.attemptID)
                    if !eventTokens.contains(owner) { eventTokens.append(owner) }
                }
            }
        }
        return true
    }
    mutating func continueExercise(courseID: String, lessonID: String?, checkpointID: String?, sessionID: String, cardID: String, attemptID: String? = nil) -> Bool {
        guard let key = Self.practiceKey(courseId: courseID, lessonId: lessonID, checkpointUnitId: checkpointID),
              let session = practiceSessions[key], session.id == sessionID,
              let identity = attemptID ?? session.pendingContinueAttemptID else { return false }
        return acknowledgeExercise(courseID: courseID, cardID: cardID, attemptID: identity)
    }

}

extension CourseLearningSnapshot {
    private mutating func captureExerciseEvidence(courseID: String, card: CourseLessonCard) {
        if let exercise = card.activity?.exercise, exercise.usesPracticeRenderer, let draft = exerciseDrafts[Self.exerciseKey(courseID: courseID, cardID: card.id)],
           draft.exercise == exercise, let firstResult = draft.state.result,
           exerciseEvidence[draft.state.attemptID] == nil {
            let independent = exercise.format == "matching" ? (exercise.pairs ?? []).filter { draft.state.pairDecisions?[$0.id]?.independent == true } : []
            let firstCorrect = independent.filter { draft.state.pairDecisions?[$0.id]?.firstRightID == $0.id }
            let targetVocabulary = exercise.format == "matching" ? Array(Set(firstCorrect.flatMap(\.vocabularyIDs))).sorted() : exercise.vocabularyIDs
            let targetConcepts = exercise.format == "matching" ? Array(Set(firstCorrect.flatMap(\.conceptIDs))).sorted() : exercise.conceptIDs
            exerciseEvidence[draft.state.attemptID] = CourseExerciseEvidence(attemptID: draft.state.attemptID,
                courseID: courseID, cardID: card.id, vocabularyIDs: targetVocabulary, conceptIDs: targetConcepts,
                mode: exercise.format == "exposure" ? "exposure" : exercise.format == "wordBank" ? "supportedConstruction" : exercise.format == "matching" ? "matching" : "recognition",
                correct: firstResult, assisted: draft.state.usedHelp, timestamp: Date(),
                pairEvidence: exercise.format == "matching" ? independent.map { CoursePairEvidence(pairID: $0.id, correct: draft.state.pairDecisions?[$0.id]?.firstRightID == $0.id, vocabularyIDs: $0.vocabularyIDs, conceptIDs: $0.conceptIDs, firstRightID: draft.state.pairDecisions?[$0.id]?.firstRightID, assisted: draft.state.usedHelp || draft.state.pairDecisions?[$0.id]?.assisted == true, usedElimination: draft.state.pairDecisions?[$0.id]?.usedElimination) } : nil)
        }
    }
}


struct CourseExerciseAcknowledgement: Codable, Equatable {
    var cardID: String
    var attemptID: String
}
extension CourseLessonCard { var isExposure: Bool { activity?.exercise?.format == "exposure" } }
extension CourseLearningSnapshot {
    mutating func acknowledgeRenderedExercise(courseID: String, card: CourseLessonCard, attemptID: String?) -> Bool {
        guard card.activity?.exercise?.usesPracticeRenderer == true else { return true }
        guard let attemptID else { return false }
        return acknowledgeExercise(courseID: courseID, cardID: card.id, attemptID: attemptID)
    }
    private static func sessionCheckOwner(sessionID: String, attemptID: String) -> String {
        "session-check:" + sessionID + ":exercise:" + attemptID
    }
    private static func sessionExerciseReceipt(sessionID: String, attemptID: String) -> String {
        "session:" + sessionID + ":exercise:" + attemptID
    }
    /// Retire session authorization only; immutable evidence and SRS event
    /// identities remain intact. A definition reverting later cannot revive it.
    private mutating func retireSessionExerciseOwnership(courseID: String, sessionID: String, cardID: String) {
        var attempts = Set(exerciseEvidence.values.filter { $0.courseID == courseID && $0.cardID == cardID }.map(\.attemptID))
        if let draft = exerciseDrafts[Self.exerciseKey(courseID: courseID, cardID: cardID)] { attempts.insert(draft.state.attemptID) }
        let retired = Set(attempts.flatMap { [Self.sessionCheckOwner(sessionID: sessionID, attemptID: $0), Self.sessionExerciseReceipt(sessionID: sessionID, attemptID: $0)] })
        eventTokens.removeAll { retired.contains($0) }
    }
    /// Both hosts acknowledge the same durable attempt. A stale acknowledgement
    /// is an idempotent no-op, never permission to erase another attempt.
    @discardableResult mutating func acknowledgeExercise(courseID: String, cardID: String, attemptID: String) -> Bool {
        guard let evidence = exerciseEvidence[attemptID], evidence.courseID == courseID, evidence.cardID == cardID else { return false }
        let draftKey = Self.exerciseKey(courseID: courseID, cardID: cardID)
        let matchesDraft = exerciseDrafts[draftKey]?.state.attemptID == attemptID
        for key in Array(practiceSessions.keys) where key.hasPrefix(courseID + ":lesson:") || key.hasPrefix(courseID + ":checkpoint:") {
            // Check can persist before the app parent records its answer. Reconcile
            // that exact graded draft before either host can retire it. Receipt
            // tokens bind it to this session without replaying progress/SRS.
            if matchesDraft, let draft = exerciseDrafts[draftKey], var session = practiceSessions[key],
               session.exerciseDefinitionsByCard?[cardID] == draft.exercise,
               eventTokens.contains(Self.sessionCheckOwner(sessionID: session.id, attemptID: attemptID)),
               session.pendingContinueCardID == nil,
               let next = session.nextIndex, session.cardIds[next] == cardID {
                let receipt = Self.sessionExerciseReceipt(sessionID: session.id, attemptID: attemptID)
                if !eventTokens.contains(receipt) {
                    session.answers[cardID] = evidence.correct
                    session.invalidatedExerciseCardIDs?.removeAll { $0 == cardID }
                    if session.attemptCounts == nil { session.attemptCounts = [:] }
                    session.attemptCounts?[cardID, default: 0] += 1
                    eventTokens.append(receipt)
                    practiceSessions[key] = session
                }
            }
            if practiceSessions[key]?.pendingContinueCardID == cardID && practiceSessions[key]?.pendingContinueAttemptID == attemptID {
                practiceSessions[key]?.pendingContinueCardID = nil
                practiceSessions[key]?.pendingContinueAttemptID = nil
            }
        }
        if matchesDraft { exerciseDrafts.removeValue(forKey: draftKey) }
        if notificationExerciseAttempts[courseID] == .init(cardID: cardID, attemptID: attemptID) {
            notificationExerciseAttempts.removeValue(forKey: courseID)
            notificationExerciseCardIDs.removeValue(forKey: courseID)
        } else if notificationExerciseAttempts[courseID] == nil && notificationExerciseCardIDs[courseID] == cardID && matchesDraft {
            // Retire only a verifiable pre-repair marker; never infer a newer ID.
            notificationExerciseCardIDs.removeValue(forKey: courseID)
        }
        return true
    }
    mutating func answerNotificationExercise(course: CourseDefinition, lessonID: String, cardID: String, correct: Bool, token: String, attemptID: String?) -> Bool {
        guard let card = course.units.flatMap(\.lessons).flatMap(\.cards).first(where: { $0.id == cardID }) else { return false }
        if card.activity?.exercise?.usesPracticeRenderer == true && attemptID == nil { return false }
        guard answer(course: course, lessonId: lessonID, cardId: cardID, correct: correct, token: token, exerciseAttemptID: attemptID) else { return false }
        if let attemptID {
            notificationExerciseAttempts[course.id] = .init(cardID: cardID, attemptID: attemptID)
            notificationExerciseCardIDs[course.id] = cardID
        }
        return true
    }
    mutating func resumeNotificationExercise(course: CourseDefinition) -> CourseExerciseAcknowledgement? {
        let pending = notificationExerciseAttempts[course.id]
        // A card-only pre-repair marker cannot identify which attempt it meant.
        // Do not bind it to a newer draft merely because the card ID matches.
        guard let pending else { notificationExerciseCardIDs.removeValue(forKey: course.id); return nil }
        let card = course.units.flatMap(\.lessons).flatMap(\.cards).first { $0.id == pending.cardID }
        let draft = exerciseDrafts[Self.exerciseKey(courseID: course.id, cardID: pending.cardID)]
        guard let card, let draft, draft.state.attemptID == pending.attemptID,
              draft.state.result != nil, draft.exercise == card.activity?.exercise else {
            _ = acknowledgeExercise(courseID: course.id, cardID: pending.cardID, attemptID: pending.attemptID)
            if notificationExerciseAttempts[course.id] == pending { notificationExerciseAttempts.removeValue(forKey: course.id); notificationExerciseCardIDs.removeValue(forKey: course.id) }
            return nil
        }
        return pending
    }
}


enum CourseLearningCommitStage { case beforeInstall, afterInstall }
struct CourseLegacyFingerprint: Codable, Equatable {
    var v1SHA256: String?
    var defaultsSHA256: String
}
struct CourseLegacyDivergence: Codable {
    var source: CourseLegacyFingerprint
    var v1Archive: String?
    var defaultsArchive: String
    var reason: String
    var detectedAt: Date
}
struct CourseMigrationMetadata: Codable {
    var imported: CourseLegacyFingerprint?
    var origin: String
    var importedV1Archive: String?
    var importedDefaultsArchive: String?
    var priorActiveArchive: String?
    var divergences: [CourseLegacyDivergence] = []
}
struct CourseProgressRecoveryExport: Codable {
    var format = "LearnAlert course progress recovery"
    var version = 1
    var explanation = "Current history remains active. Older-version work is preserved separately and has not been merged, credited or replayed. This export contains both histories and source archives for explicit recovery; it does not restore progress automatically."
    var generatedAt: Date
    var activeHistory: Data?
    var olderHistory: Data?
    var olderDefaults: Data
    var archives: [String: Data]
    var readError: String?
}

private struct CourseLearningReadSources {
    var active: Data?
    var legacy: Data?
    var defaults: Data
}


extension CourseLearningSnapshot {
    var progressRecoveryNotice: String? {
        guard migration?.divergences.isEmpty == false else { return nil }
        return "Progress from an older app version was found. Your current progress is unchanged. Older-version work has not been added automatically. Export both histories to keep them safe."
    }
}


extension CourseLearningSnapshot {
    mutating func assignRoute(course: CourseDefinition, returningLearner: Bool) {
        guard let starter = course.learning?.starter, routes[course.id] == nil else { return }
        let legacy = course.units.flatMap(\.lessons).filter { !starter.lessonIDs.contains($0.id) }
        let anchor = legacy.first { lesson in
            let key = Self.practiceKey(courseId: course.id, lessonId: lesson.id, checkpointUnitId: nil)!
            return practiceSessions[key] != nil
        } ?? legacy.first { status(course: course, lessonId: $0.id) == .current }
        routes[course.id] = .init(revision: starter.revision,
            lessonIDs: returningLearner ? legacy.map(\.id) : starter.lessonIDs + legacy.map(\.id),
            originalContinueLessonID: returningLearner ? anchor?.id : nil,
            starterSelected: !returningLearner, returningLearner: returningLearner, starterLessonIDs: starter.lessonIDs)
    }
    mutating func selectStarter(course: CourseDefinition, selected: Bool) {
        assignRoute(course: course, returningLearner: true)
        routes[course.id]?.starterSelected = selected
    }
    func activeAssessment(courseID: String) -> CourseAssessmentAttempt? {
        activeAssessmentIDs[courseID].flatMap { assessmentAttempts[$0] }
    }
    mutating func startAssessment(course: CourseDefinition, retake: Bool = false) -> CourseAssessmentAttempt? {
        if let active = activeAssessment(courseID: course.id), active.finalizedAt == nil || !retake { return active }
        guard let starter = course.learning?.starter else { return nil }
        let blueprint = starter.assessment
        guard blueprint.id == "pf-sp-a01", blueprint.lessonIDs == ["pf-sp-l01", "pf-sp-l02"], Set(blueprint.lessonIDs).isSubset(of: Set(starter.lessonIDs)),
              blueprint.forms.count == 2, blueprint.forms.values.allSatisfy({ $0.count == 12 }),
              blueprint.objectiveIDs.count == 4, blueprint.passingTotal == 10, blueprint.passingPerObjective == 2 else { return nil }
        let previous = activeAssessment(courseID: course.id)?.formID
        guard let form = blueprint.forms.keys.sorted().first(where: { $0 != previous }), let items = blueprint.forms[form],
              items.allSatisfy({ blueprint.objectiveIDs.contains($0.objectiveID) && $0.card.activity?.exercise?.usesPracticeRenderer == true && $0.card.activity?.exercise?.format != "exposure" }),
              blueprint.objectiveIDs.allSatisfy({ objective in items.filter { $0.objectiveID == objective }.count == 3 }) else { return nil }
        let attempt = CourseAssessmentAttempt(id: UUID().uuidString, courseID: course.id, blueprint: blueprint, formID: form,
            items: items, states: Dictionary(uniqueKeysWithValues: items.map { ($0.id, CourseExerciseState()) }))
        var prepared = attempt
        // Access/prerequisite credit is scoped to assessed concepts. Supporting
        // words are not converted into independent lexical evidence or SRS.
        let concepts = Set(items.flatMap { $0.card.activity?.exercise?.conceptIDs ?? [] })
        prepared.prerequisiteCards = course.units.flatMap(\.lessons).filter { blueprint.lessonIDs.contains($0.id) }.flatMap(\.cards).filter { card in
            guard let exercise = card.activity?.exercise, !exercise.conceptIDs.isEmpty else { return false }
            return Set(exercise.conceptIDs).isSubset(of: concepts)
        }
        assessmentAttempts[attempt.id] = prepared; activeAssessmentIDs[course.id] = attempt.id
        return prepared
    }
    mutating func saveAssessmentState(courseID: String, assessmentID: String, itemID: String, state: CourseExerciseState) -> Bool {
        guard activeAssessmentIDs[courseID] == assessmentID, var attempt = assessmentAttempts[assessmentID],
              attempt.finalizedAt == nil, let item = attempt.activeItem, item.id == itemID,
              let old = attempt.states[itemID], let exercise = item.card.activity?.exercise, !state.usedHelp else { return false }
        if old == state { return true }
        guard old.result == nil, old.attemptID == state.attemptID, state.revision == old.revision + 1,
              state.preservesEvidence(from: old, exercise: exercise) else { return false }
        if let result = state.result {
            var verification = state; verification.result = nil
            guard verification.submit(exercise) == result else { return false }
        }
        attempt.states[itemID] = state; assessmentAttempts[assessmentID] = attempt; return true
    }
    mutating func advanceAssessment(courseID: String, assessmentID: String, itemID: String, skip: Bool = false) -> Bool {
        guard activeAssessmentIDs[courseID] == assessmentID, var attempt = assessmentAttempts[assessmentID],
              attempt.finalizedAt == nil, attempt.activeItem?.id == itemID else { return false }
        if skip {
            guard attempt.states[itemID]?.result == nil else { return false }
            attempt.skippedIDs.append(itemID)
        } else if attempt.states[itemID]?.result == nil { return false }
        attempt.index += 1
        if attempt.index == attempt.items.count {
            attempt.finalizedAt = Date()
            attempt.passed = attempt.score >= attempt.blueprint.passingTotal && attempt.blueprint.objectiveIDs.allSatisfy { attempt.score(objectiveID: $0) >= attempt.blueprint.passingPerObjective }
            if attempt.passed == true {
                assessmentAccess[courseID] = Array(Set((assessmentAccess[courseID] ?? []) + attempt.blueprint.lessonIDs)).sorted()
            }
        }
        assessmentAttempts[assessmentID] = attempt; return true
    }
}

extension CourseLearningSnapshot {
    func assignedStarterLessonIDs(course: CourseDefinition) -> [String] {
        guard let route = routes[course.id] else { return course.learning?.starter?.lessonIDs ?? [] }
        if let ids = route.starterLessonIDs { return ids }
        // v5 only supported a two-lesson starter. Never infer newly added lessons.
        let available = Set(course.learning?.starter?.lessonIDs ?? [])
        let pinned = route.lessonIDs.filter { available.contains($0) }
        return pinned.isEmpty ? (course.learning?.starter?.assessment.lessonIDs ?? []).filter { available.contains($0) } : pinned
    }
    func activeRouteLessonIDs(course: CourseDefinition) -> Set<String> {
        guard let route = routes[course.id] else { return Set(course.units.flatMap(\.lessons).map(\.id)) }
        return Set(route.lessonIDs + (route.starterSelected ? assignedStarterLessonIDs(course: course) : []))
    }
    mutating func adoptStarterRevision(course: CourseDefinition) -> Bool {
        guard let starter = course.learning?.starter, var route = routes[course.id], route.revision != starter.revision,
              Set(assignedStarterLessonIDs(course: course)).isSubset(of: Set(starter.lessonIDs)) else { return false }
        let lessons = Set(course.units.flatMap(\.lessons).map(\.id))
        guard Set(starter.lessonIDs).isSubset(of: lessons) else { return false }
        route.expansionContinueLessonID = currentLesson(course: course)?.id
        route.starterLessonIDs = starter.lessonIDs; route.revision = starter.revision
        routes[course.id] = route; return true
    }
    func satisfiesPrerequisites(card: CourseLessonCard, course: CourseDefinition) -> Bool {
        let studied = Set((progress[course.id] ?? [:]).values.flatMap(\.masteredCardIds))
        let revealed = Set(exerciseEvidence.values.filter { $0.courseID == course.id && $0.mode == "exposure" }.map(\.cardID))
        return (card.activity?.exercise?.prerequisiteIDs ?? []).allSatisfy { id in
            if studied.contains(id) || revealed.contains(id) { return true }
            guard let lesson = course.units.flatMap(\.lessons).first(where: { $0.cards.contains { $0.id == id } }),
                  let current = lesson.cards.first(where: { $0.id == id }), assessmentAccess[course.id]?.contains(lesson.id) == true else { return false }
            return assessmentAttempts.values.contains { attempt in
                guard attempt.courseID == course.id, attempt.passed == true, attempt.blueprint.lessonIDs.contains(lesson.id),
                      let frozen = attempt.prerequisiteCards, let target = current.activity?.exercise, !target.conceptIDs.isEmpty, !target.vocabularyIDs.isEmpty else { return false }
                // This is scoped access, not a claim that a new variant was answered.
                // Cosmetic/presentation changes and new variants of known targets
                // do not revoke test-out; new meanings/objectives still need study.
                let concepts = Set(frozen.flatMap { $0.activity?.exercise?.conceptIDs ?? [] })
                let vocabulary = Set(frozen.flatMap { $0.activity?.exercise?.vocabularyIDs ?? [] })
                return Set(target.conceptIDs).isSubset(of: concepts) && Set(target.vocabularyIDs).isSubset(of: vocabulary)
            }
        }
    }
    func permitsCourseReplacement(previous: CourseDefinition, candidate: CourseDefinition) -> Bool {
        guard previous.id == candidate.id else { return false }
        let lessons = candidate.units.flatMap(\.lessons), ids = Set(lessons.map(\.id))
        if let route = routes[previous.id], !Set(route.lessonIDs + assignedStarterLessonIDs(course: previous)).isSubset(of: ids) { return false }
        for (key, session) in practiceSessions where key.hasPrefix(previous.id + ":") {
            guard let index = session.nextIndex else { continue }
            let id = session.cardIds[index]
            let old = previous.units.flatMap(\.lessons).flatMap(\.cards).first { $0.id == id }
            guard let new = lessons.flatMap(\.cards).first(where: { $0.id == id }) else { return false }
            if let definition = session.exerciseDefinitionsByCard?[id], definition != new.activity?.exercise { return false }
            if old != new { return false }
        }
        return true
    }
}
