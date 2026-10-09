//
//  CourseProgressManager.swift
//  LearnAlert
//
//  Created by Blake Miller on 2/20/26.
//

import Foundation
import SwiftData
import SwiftUI
import Combine

@MainActor
final class CourseProgressManager: ObservableObject {
    static let shared = CourseProgressManager()

    private let appGroupSuite = "group.com.learnalert.shared"
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupSuite)
    }

    @Published private(set) var activeCourseId: String?
    @Published private(set) var activeEnrollment: CourseEnrollment?
    @Published private(set) var enrolledCourseIds: [String] = []
    @Published private(set) var progressMap: [String: [String: CourseLessonProgressRecord]] = [:] // courseId -> [lessonId: Record]
    @Published private(set) var checkpointResults: [String: [String: CourseCheckpointResult]] = [:] // courseId -> [sectionId: Result]
    @Published private(set) var srsRecords: [String: CourseCardSRSRecord] = [:] // cardId -> SRSRecord
    @Published private(set) var processedEventTokens: Set<String> = []
    @Published private(set) var pinnedItemIds: [String] = []
    @Published private(set) var unpinnedExplicitIds: Set<String> = []

    private init() {
        reloadFromSharedDefaults()
    }

    func reloadFromSharedDefaults() {
        guard let defaults = sharedDefaults else { return }

        let activeId = defaults.string(forKey: "course_active_enrollment_id")
        self.activeCourseId = activeId

        if let activeId, let enrollment = loadEnrollment(for: activeId) {
            self.activeEnrollment = enrollment
        } else {
            self.activeEnrollment = nil
        }

        // Load enrolled course IDs
        var enrolled = defaults.stringArray(forKey: "course_enrolled_ids") ?? []
        for course in CourseCurriculumCatalog.courses {
            if loadEnrollment(for: course.id) != nil && !enrolled.contains(course.id) {
                enrolled.append(course.id)
            }
        }
        self.enrolledCourseIds = enrolled

        // Load progress maps & checkpoint results
        for course in CourseCurriculumCatalog.courses {
            progressMap[course.id] = loadProgressMap(for: course.id)
            checkpointResults[course.id] = loadCheckpointResults(for: course.id)
        }

        // Load SRS records
        self.srsRecords = loadSRSRecords()

        // Load processed event tokens for deduplication
        let tokens = defaults.stringArray(forKey: "course_processed_event_tokens") ?? []
        self.processedEventTokens = Set(tokens)

        let snapshot = CourseLearningStore.shared.snapshot()
        progressMap = snapshot.progress
        checkpointResults = snapshot.checkpoints
        srsRecords = snapshot.srs
        processedEventTokens = Set(snapshot.eventTokens)

        // Load pinned state
        self.pinnedItemIds = defaults.stringArray(forKey: "home_pinned_item_ids") ?? []
        let unpinnedList = defaults.stringArray(forKey: "home_unpinned_explicit_ids") ?? []
        self.unpinnedExplicitIds = Set(unpinnedList)
    }

    // MARK: - Enrolled Courses

    var allEnrolledCourses: [CourseDefinition] {
        enrolledCourseIds.compactMap { id in
            CourseCurriculumCatalog.course(for: id)
        }
    }

    // MARK: - Pinning Management

    func isPinned(id: String) -> Bool {
        pinnedItemIds.contains(id)
    }

    func isCoursePinned(courseId: String) -> Bool {
        isPinned(id: "course:\(courseId)")
    }

    func isDeckPinned(deckId: UUID) -> Bool {
        isPinned(id: "deck:\(deckId.uuidString)")
    }

    func pin(id: String) {
        guard !pinnedItemIds.contains(id) else { return }
        pinnedItemIds.insert(id, at: 0)
        unpinnedExplicitIds.remove(id)
        savePinnedState()
    }

    func unpin(id: String) {
        pinnedItemIds.removeAll { $0 == id }
        unpinnedExplicitIds.insert(id)
        savePinnedState()
    }

    func togglePin(id: String) {
        if isPinned(id: id) {
            unpin(id: id)
        } else {
            pin(id: id)
        }
    }

    func movePinned(from source: IndexSet, to destination: Int) {
        pinnedItemIds.move(fromOffsets: source, toOffset: destination)
        savePinnedState()
    }

    private func savePinnedState() {
        guard let defaults = sharedDefaults else { return }
        defaults.set(pinnedItemIds, forKey: "home_pinned_item_ids")
        defaults.set(Array(unpinnedExplicitIds), forKey: "home_unpinned_explicit_ids")
        defaults.synchronize()
    }

    // MARK: - Enrollment Management

    func isEnrolled(in courseId: String) -> Bool {
        return loadEnrollment(for: courseId) != nil
    }

    func enrollment(for courseId: String) -> CourseEnrollment? {
        return loadEnrollment(for: courseId)
    }

    func enroll(
        course: CourseDefinition,
        goal: CourseGoal,
        experienceLevel: CourseExperienceLevel,
        studyMode: CourseStudyMode,
        selectedDays: [Int],
        startHour: Int,
        startMinute: Int,
        endHour: Int,
        endMinute: Int,
        dailyCardsTarget: Int,
        context: ModelContext
    ) -> Deck {
        let deck = createOrSyncCourseDeck(for: course, in: context)

        let enrollment = CourseEnrollment(
            courseId: course.id,
            enrolledDate: Date(),
            goal: goal,
            experienceLevel: experienceLevel,
            studyMode: studyMode,
            selectedDays: selectedDays,
            startHour: startHour,
            startMinute: startMinute,
            endHour: endHour,
            endMinute: endMinute,
            dailyCardsTarget: dailyCardsTarget,
            linkedDeckId: deck.id.uuidString,
            checkpointPassingThreshold: 0.80,
            autoPronounceInStudy: loadEnrollment(for: course.id)?.autoPronounceInStudy ?? false
        )

        saveEnrollment(enrollment)

        if !enrolledCourseIds.contains(course.id) {
            enrolledCourseIds.append(course.id)
            sharedDefaults?.set(enrolledCourseIds, forKey: "course_enrolled_ids")
        }

        // Initialize progress for this course if not exists
        var currentMap = loadProgressMap(for: course.id)
        if currentMap.isEmpty {
            for (uIndex, unit) in course.units.enumerated() {
                for (lIndex, lesson) in unit.lessons.enumerated() {
                    let isFirst = (uIndex == 0 && lIndex == 0)
                    let initialStatus: LessonStatus = isFirst ? .current : .locked
                    currentMap[lesson.id] = CourseLessonProgressRecord(
                        status: initialStatus,
                        completedDate: nil,
                        correctAnswersCount: 0,
                        totalAttemptsCount: 0,
                        masteredCardIds: []
                    )
                }
            }
            saveProgressMap(currentMap, for: course.id)
        }

        // Set as active course
        sharedDefaults?.set(course.id, forKey: "course_active_enrollment_id")
        self.activeCourseId = course.id
        self.activeEnrollment = enrollment
        self.progressMap[course.id] = currentMap

        // Sync schedule preferences with StudyEngine without starting automatically
        StudyEngine.shared.startHour = startHour
        StudyEngine.shared.startMinute = startMinute
        StudyEngine.shared.endHour = endHour
        StudyEngine.shared.endMinute = endMinute
        StudyEngine.shared.customVolume = dailyCardsTarget
        StudyEngine.shared.volumeSelectionIndex = 5

        // Automatically pin when first started unless user explicitly unpinned it
        let coursePinKey = "course:\(course.id)"
        if !unpinnedExplicitIds.contains(coursePinKey) && !pinnedItemIds.contains(coursePinKey) {
            pin(id: coursePinKey)
        }

        updateSchedulePointer(course: course)
        return deck
    }

    func setAutoPronounce(_ enabled: Bool, courseId: String) {
        guard var enrollment = loadEnrollment(for: courseId) else { return }
        enrollment.autoPronounceInStudy = enabled
        saveEnrollment(enrollment)
        reloadFromSharedDefaults()
    }

    func unenroll(courseId: String) {
        if CourseNotificationScheduler.activePlan?.courseId == courseId { StudyEngine.shared.stopAlerts() }
        sharedDefaults?.removeObject(forKey: "course_enrollment_\(courseId)")
        enrolledCourseIds.removeAll { $0 == courseId }
        sharedDefaults?.set(enrolledCourseIds, forKey: "course_enrolled_ids")
        unpin(id: "course:\(courseId)")

        if activeCourseId == courseId {
            sharedDefaults?.removeObject(forKey: "course_active_enrollment_id")
            sharedDefaults?.removeObject(forKey: "course_active_schedule_pointer")
            activeCourseId = nil
            activeEnrollment = nil
        }
        reloadFromSharedDefaults()
    }

    // MARK: - Course Deck Creation & Sync

    func createOrSyncCourseDeck(for course: CourseDefinition, in context: ModelContext) -> Deck {
        let deckName = "\(course.flagEmoji) \(course.title)"
        let allDecks = (try? context.fetch(FetchDescriptor<Deck>())) ?? []
        let linkedId = loadEnrollment(for: course.id)?.linkedDeckId
        let existing = allDecks.first(where: { $0.id.uuidString == linkedId }) ?? allDecks.first(where: {
            $0.deckType == "Course" && ($0.name == deckName || (course.id == "korean-course" && $0.name == "🇰🇷 Korean Foundations"))
        })
        let deck = existing ?? Deck(name: deckName, colorHex: course.colorHex, deckType: "Course", orderIndex: allDecks.count)
        if existing == nil { context.insert(deck) }
        deck.name = deckName
        if var enrollment = loadEnrollment(for: course.id), enrollment.linkedDeckId != deck.id.uuidString {
            enrollment.linkedDeckId = deck.id.uuidString
            saveEnrollment(enrollment)
            if activeCourseId == course.id { activeEnrollment = enrollment }
        }
        let originalCards = deck.cards
        var usedIds: Set<UUID> = []
        var order = 0
        for unit in course.units {
            let section = deck.sections.first(where: { $0.name == unit.title }) ?? DeckSection(name: unit.title, orderIndex: unit.unitNumber)
            if !deck.sections.contains(where: { $0.id == section.id }) { deck.sections.append(section) }
            section.deck = deck
            for definition in unit.lessons.flatMap(\.cards) {
                let type: FlashcardType
                switch definition.cardType {
                case "fillBlank", "listeningWrite": type = .fillBlank
                case "vocabulary": type = .vocabulary
                case "tapReveal": type = .tapReveal
                case "matching": type = .matching
                default: type = .multipleChoice
                }
                let deckQuestion = definition.questionText(audioEnabled: false)
                let card = originalCards.first(where: {
                    !usedIds.contains($0.id) && $0.question == deckQuestion && $0.section?.id == section.id
                }) ?? Flashcard(question: deckQuestion, options: definition.options, correctAnswer: definition.correctAnswer)
                card.options = definition.options
                card.correctAnswer = definition.correctAnswer
                card.hint = definition.hint
                card.cardType = type
                card.matchingLeftItems = definition.matchingLeftItems
                card.matchingRightItems = definition.matchingRightItems
                card.promptImageName = definition.promptImageName
                card.optionImageNames = definition.optionImageNames
                card.orderIndex = order; order += 1
                card.deck = deck; card.section = section
                if !deck.cards.contains(where: { $0.id == card.id }) { deck.cards.append(card) }
                if !section.cards.contains(where: { $0.id == card.id }) { section.cards.append(card) }
                usedIds.insert(card.id)
            }
        }
        // Keep any extra saved cards and their review history.
        for card in originalCards where !usedIds.contains(card.id) { card.orderIndex = order; order += 1 }
        do { try context.save() } catch { print("Course deck could not be saved: \(error.localizedDescription)") }
        return deck
    }

    // MARK: - Lesson Progression & Gating Logic

    func getLessonRecord(courseId: String, lessonId: String) -> CourseLessonProgressRecord {
        let map = progressMap[courseId] ?? loadProgressMap(for: courseId)
        return map[lessonId] ?? CourseLessonProgressRecord(status: .locked)
    }

    func getLessonStatus(courseId: String, lessonId: String) -> LessonStatus {
        guard let course = CourseCurriculumCatalog.course(for: courseId) else { return .locked }
        return CourseLearningStore.shared.snapshot().status(course: course, lessonId: lessonId)
    }

    /// Check if all regular lessons in a section are completed
    func isSectionLessonsCompleted(courseId: String, sectionId: String) -> Bool {
        guard let course = CourseCurriculumCatalog.course(for: courseId),
              let unit = course.units.first(where: { $0.id == sectionId }) else {
            return false
        }
        let map = progressMap[courseId] ?? loadProgressMap(for: courseId)
        let snapshot = CourseLearningStore.shared.snapshot()
        return unit.lessons.allSatisfy { snapshot.status(course: course, lessonId: $0.id) == .completed }
    }

    /// Check if a section checkpoint has been passed
    func isCheckpointPassed(courseId: String, sectionId: String) -> Bool {
        let results = checkpointResults[courseId] ?? loadCheckpointResults(for: courseId)
        guard let result = results[sectionId] else { return false }
        return result.passed
    }

    /// Checkpoint status: .locked (lessons incomplete), .available (ready to take), .completed (passed >= 80%)
    func getCheckpointStatus(courseId: String, sectionId: String) -> LessonStatus {
        if isCheckpointPassed(courseId: courseId, sectionId: sectionId) {
            return .completed
        }
        if isSectionLessonsCompleted(courseId: courseId, sectionId: sectionId) {
            return .available
        }
        return .locked
    }

    /// Record a completed checkpoint attempt
    func recordCheckpointResult(courseId: String, sectionId: String, checkpointId: String, score: Int,
        totalQuestions: Int, missedQuestionIds: [String], missedConcepts: [String]) -> CourseCheckpointResult {
        if let course = CourseCurriculumCatalog.course(for: courseId),
           let unit = course.units.first(where: { $0.id == sectionId }), let quiz = unit.checkpointQuiz,
           quiz.id == checkpointId, totalQuestions == quiz.questions.count,
           score == totalQuestions - Set(missedQuestionIds).count,
           let result = CourseLearningStore.shared.transaction({ $0.checkpoint(course: course, unit: unit, missed: missedQuestionIds,
                passingThreshold: enrollment(for: courseId)?.checkpointPassingThreshold) }) ?? nil {
            reloadFromSharedDefaults()
            reconcilePendingNotifications(for: course)
            return result
        }
        return CourseCheckpointResult(checkpointId: checkpointId, sectionId: sectionId, score: 0,
            totalQuestions: totalQuestions, passed: false, missedQuestionIds: missedQuestionIds, missedConcepts: missedConcepts)
    }

    /// Mark a lesson completed in-app
    func completeLesson(courseId: String, lessonId: String, correctAnswers: Int, totalCards: Int) {
        // Completion is derived exclusively from individually graded cards.
        reloadFromSharedDefaults()
    }

    // MARK: - Deduplicated Answer Recording (App & Notification Extension)

    /// Records an answer event with deduplication token. Updates SRS record and checks lesson advancement.
    @discardableResult
    func recordCardAnswer(courseId: String, sectionId: String, lessonId: String, cardId: String,
        isCorrect: Bool, eventToken: String? = nil) -> Bool {
        guard let course = CourseCurriculumCatalog.course(for: courseId),
              course.units.contains(where: { $0.id == sectionId && $0.lessons.contains(where: { $0.id == lessonId }) }) else { return false }
        let applied = CourseLearningStore.shared.transaction {
            $0.answer(course: course, lessonId: lessonId, cardId: cardId, correct: isCorrect, token: eventToken ?? UUID().uuidString)
        } ?? false
        reloadFromSharedDefaults()
        reconcilePendingNotifications(for: course)
        return applied
    }

    /// Backwards compatible hook for notification answer sync
    func recordCardAnswer(cardQuestion: String, isCorrect: Bool) {
        for course in CourseCurriculumCatalog.courses {
            for unit in course.units {
                for lesson in unit.lessons {
                    if let card = lesson.cards.first(where: { $0.question == cardQuestion || cardQuestion.contains($0.question) }) {
                        recordCardAnswer(
                            courseId: course.id,
                            sectionId: unit.id,
                            lessonId: lesson.id,
                            cardId: card.id,
                            isCorrect: isCorrect,
                            eventToken: "\(card.id)_\(Date().timeIntervalSince1970)"
                        )
                        return
                    }
                }
            }
        }
    }

    // MARK: - Resumable In-App Practice

    func resumePractice(course: CourseDefinition, lessonId: String?, checkpointUnitId: String?) -> CoursePracticeSession? {
        let session = CourseLearningStore.shared.transaction {
            $0.resumePractice(course: course, lessonId: lessonId, checkpointUnitId: checkpointUnitId)
        } ?? nil
        reloadFromSharedDefaults()
        return session
    }

    @discardableResult
    func recordPracticeAnswer(course: CourseDefinition, lessonId: String?, checkpointUnitId: String?, sessionId: String, cardId: String, correct: Bool) -> Bool {
        let saved = CourseLearningStore.shared.transaction {
            $0.answerPractice(course: course, lessonId: lessonId, checkpointUnitId: checkpointUnitId, sessionId: sessionId, cardId: cardId, correct: correct)
        } ?? false
        reloadFromSharedDefaults()
        if saved { reconcilePendingNotifications(for: course) }
        return saved
    }

    func finishPractice(course: CourseDefinition, lessonId: String?, checkpointUnitId: String?, sessionId: String) -> CoursePracticeCompletion? {
        let completion = CourseLearningStore.shared.transaction {
            $0.finishPractice(course: course, lessonId: lessonId, checkpointUnitId: checkpointUnitId, sessionId: sessionId,
                passingThreshold: enrollment(for: course.id)?.checkpointPassingThreshold)
        } ?? nil
        reloadFromSharedDefaults()
        if completion != nil { reconcilePendingNotifications(for: course) }
        return completion
    }

    func answeredCardsCount(course: CourseDefinition, lesson: CourseLesson) -> Int {
        let state = CourseLearningStore.shared.snapshot()
        let key = CourseLearningSnapshot.practiceKey(courseId: course.id, lessonId: lesson.id, checkpointUnitId: nil)!
        let answered = Set(state.practiceSessions[key]?.answers.keys.map { $0 } ?? [])
        let mastered = Set(state.progress[course.id]?[lesson.id]?.masteredCardIds ?? [])
        return answered.union(mastered).intersection(Set(lesson.cards.map(\.id))).count
    }

    // MARK: - Spaced Repetition + Ordered Path Card Selection (Requirement 7)

    /// Generates the next batch of cards to study: combines new cards from current lesson and due SRS cards from completed lessons.
    func nextStudyBatch(for course: CourseDefinition, maxCount: Int = 10) -> [CourseLessonCard] {
        CourseLearningStore.shared.snapshot().batch(course: course, count: maxCount)
    }

    // MARK: - Current State Queries

    func currentLesson(for course: CourseDefinition) -> CourseLesson? {
        CourseLearningStore.shared.snapshot().currentLesson(course: course)
    }

    func completedLessonsCount(for course: CourseDefinition) -> Int {
        let map = progressMap[course.id] ?? loadProgressMap(for: course.id)
        return course.units.flatMap(\.lessons).filter { map[$0.id]?.status == .completed }.count
    }

    func completionPercentage(for course: CourseDefinition) -> Double {
        CourseLearningStore.shared.snapshot().completionFraction(course: course)
    }

    func completedCards(for course: CourseDefinition) -> [CourseLessonCard] {
        let map = progressMap[course.id] ?? loadProgressMap(for: course.id)
        var result: [CourseLessonCard] = []
        for unit in course.units {
            for lesson in unit.lessons {
                if map[lesson.id]?.status == .completed {
                    result.append(contentsOf: lesson.cards)
                }
            }
        }
        return result
    }

    // MARK: - Scheduling Pointer & Notification Reconciliation (Requirements 6 & 14)

    func updateSchedulePointer(course: CourseDefinition) {
        let snapshot = CourseLearningStore.shared.snapshot()
        let current = snapshot.currentLesson(course: course)
        guard let unit = snapshot.pendingCheckpoint(course: course) ?? course.units.first(where: { $0.lessons.contains(where: { $0.id == current?.id }) }) ?? course.units.last else { return }
        let card = snapshot.batch(course: course, count: 1).first
        let pointer = CourseSchedulePointer(courseId: course.id, sectionId: unit.id, lessonId: current?.id ?? "",
            cardIndex: current?.cards.firstIndex(where: { $0.id == card?.id }) ?? 0,
            isCheckpointPending: snapshot.pendingCheckpoint(course: course) != nil)
        if let data = try? JSONEncoder().encode(pointer) { sharedDefaults?.set(data, forKey: "course_active_schedule_pointer") }
    }

    func activeSchedulePointer() -> CourseSchedulePointer? {
        if let id = CourseNotificationScheduler.activePlan?.courseId ?? activeCourseId,
           let course = CourseCurriculumCatalog.course(for: id) { updateSchedulePointer(course: course) }
        guard let data = sharedDefaults?.data(forKey: "course_active_schedule_pointer"),
              let pointer = try? JSONDecoder().decode(CourseSchedulePointer.self, from: data) else {
            return nil
        }
        return pointer
    }

    /// Reconcile queued course alerts safely using iOS background scheduling rules
    func reconcilePendingNotifications(for course: CourseDefinition) {
        // Course notifications resolve live shared progress when expanded. No unrelated deck is rescheduled.
        updateSchedulePointer(course: course)
        guard CourseNotificationScheduler.activePlan?.courseId == course.id else { return }
        Task {
            do { try await CourseNotificationScheduler.replenish() }
            catch { print("Course notification refresh failed: \(error.localizedDescription)") }
        }
    }

    // MARK: - Internal Persistence

    private func saveEnrollment(_ enrollment: CourseEnrollment) {
        guard let defaults = sharedDefaults,
              let data = try? JSONEncoder().encode(enrollment) else { return }
        defaults.set(data, forKey: "course_enrollment_\(enrollment.courseId)")
        defaults.synchronize()
    }

    private func loadEnrollment(for courseId: String) -> CourseEnrollment? {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: "course_enrollment_\(courseId)"),
              let decoded = try? JSONDecoder().decode(CourseEnrollment.self, from: data) else {
            return nil
        }
        return decoded
    }

    private func saveProgressMap(_ map: [String: CourseLessonProgressRecord], for courseId: String) {
        CourseLearningStore.shared.transaction { state in
            // Enrollment only initializes absent records, preserving extension progress.
            for (id, record) in map where state.progress[courseId]?[id] == nil {
                state.progress[courseId, default: [:]][id] = record
            }
        }
    }

    private func loadProgressMap(for courseId: String) -> [String: CourseLessonProgressRecord] {
        CourseLearningStore.shared.snapshot().progress[courseId] ?? [:]
    }

    private func saveCheckpointResults(_ results: [String: CourseCheckpointResult], for courseId: String) {
        guard let defaults = sharedDefaults,
              let data = try? JSONEncoder().encode(results) else { return }
        defaults.set(data, forKey: "course_checkpoints_\(courseId)")
        defaults.synchronize()
    }

    private func loadCheckpointResults(for courseId: String) -> [String: CourseCheckpointResult] {
        CourseLearningStore.shared.snapshot().checkpoints[courseId] ?? [:]
    }

    private func saveSRSRecords(_ records: [String: CourseCardSRSRecord]) {
        guard let defaults = sharedDefaults,
              let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: "course_srs_records")
        defaults.synchronize()
    }

    private func loadSRSRecords() -> [String: CourseCardSRSRecord] {
        CourseLearningStore.shared.snapshot().srs
    }
}
