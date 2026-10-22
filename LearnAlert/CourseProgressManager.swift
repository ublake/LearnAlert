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
import CryptoKit

@MainActor
final class CourseProgressManager: ObservableObject {
    static let shared = CourseProgressManager()

    private let sharedDefaults: UserDefaults?
    private let learningStore: CourseLearningStore
    private var practiceSessions: [String: CoursePracticeSession] = [:]

    @Published private(set) var progressRecoveryNotice: String?
    @Published private(set) var progressReadError: String?
    @Published private(set) var activeCourseId: String?
    @Published private(set) var activeEnrollment: CourseEnrollment?
    @Published private(set) var enrolledCourseIds: [String] = []
    @Published private(set) var progressMap: [String: [String: CourseLessonProgressRecord]] = [:] // courseId -> [lessonId: Record]
    @Published private(set) var checkpointResults: [String: [String: CourseCheckpointResult]] = [:] // courseId -> [sectionId: Result]
    @Published private(set) var srsRecords: [String: CourseCardSRSRecord] = [:] // cardId -> SRSRecord
    @Published private(set) var scopedSRSRecords: [String: [String: CourseCardSRSRecord]] = [:]
    @Published private(set) var processedEventTokens: Set<String> = []
    @Published private(set) var pinnedItemIds: [String] = []
    @Published private(set) var unpinnedExplicitIds: Set<String> = []

    init(defaults: UserDefaults? = UserDefaults(suiteName: "group.com.learnalert.shared"),
         learningStore: CourseLearningStore = .shared) {
        sharedDefaults = defaults
        self.learningStore = learningStore
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

        // The shared store already migrates legacy defaults. Read its complete
        // snapshot once rather than decoding the file separately for each field/course.
        let snapshot = learningStore.snapshot()
        if let error = learningStore.lastError { progressReadError = error; return }
        progressReadError = nil
        progressRecoveryNotice = snapshot.progressRecoveryNotice
        practiceSessions = snapshot.practiceSessions
        progressMap = snapshot.progress
        checkpointResults = snapshot.checkpoints
        srsRecords = snapshot.srs
        scopedSRSRecords = snapshot.courseSRS
        processedEventTokens = Set(snapshot.eventTokens)

        // Load pinned state
        self.pinnedItemIds = defaults.stringArray(forKey: "home_pinned_item_ids") ?? []
        let unpinnedList = defaults.stringArray(forKey: "home_unpinned_explicit_ids") ?? []
        self.unpinnedExplicitIds = Set(unpinnedList)
    }

    func exportProgressRecovery() throws -> URL {
        let data = try learningStore.recoveryExportData()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("LearnAlert-progress-recovery-" + UUID().uuidString + ".json")
        try data.write(to: url, options: .atomic)
        return url
    }

    // MARK: - Enrolled Courses

    var learningSnapshot: CourseLearningSnapshot {
        var snapshot = CourseLearningSnapshot()
        snapshot.progress = progressMap
        snapshot.checkpoints = checkpointResults
        snapshot.srs = srsRecords
        snapshot.courseSRS = scopedSRSRecords
        snapshot.practiceSessions = practiceSessions
        return snapshot
    }

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

    // Runtime-only marks never suppress a migration after installing a new build.
    // The actual deck must still exist in the current context before a mark is used.
    private var automaticCourseSyncDigests: [UUID: String] = [:]

    @discardableResult
    func syncManagedCourseDeckIfNeeded(for course: CourseDefinition, in context: ModelContext) -> Bool {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let digest = (try? encoder.encode(course)).map { SHA256.hash(data: $0).map { String(format: "%02x", $0) }.joined() }
        let linkedId = loadEnrollment(for: course.id)?.linkedDeckId
        let decks = (try? context.fetch(FetchDescriptor<Deck>())) ?? []
        let existing = decks.first { $0.id.uuidString == linkedId }
            ?? decks.first { $0.sourcePremadeID == "course:\(course.id)" }
        if let existing, let digest, automaticCourseSyncDigests[existing.id] == digest { return false }
        let deck = createOrSyncCourseDeck(for: course, in: context)
        // A failed save leaves changes pending and must be retried on the next refresh.
        if !context.hasChanges, let digest { automaticCourseSyncDigests[deck.id] = digest }
        return true
    }

    func createOrSyncCourseDeck(for course: CourseDefinition, in context: ModelContext) -> Deck {
        struct LegacyCardKey: Hashable { let sectionId: UUID; let question: String }
        let deckName = "\(course.flagEmoji) \(course.title)"
        let allDecks = (try? context.fetch(FetchDescriptor<Deck>())) ?? []
        let linkedId = loadEnrollment(for: course.id)?.linkedDeckId
        let existing = allDecks.first(where: { $0.id.uuidString == linkedId })
            ?? allDecks.first(where: { $0.sourcePremadeID == "course:\(course.id)" })
            ?? allDecks.first(where: {
                $0.deckType == "Course" && ($0.name == deckName || (course.id == "korean-course" && $0.name == "🇰🇷 Korean Foundations"))
            })
        let deck = existing ?? Deck(name: deckName, colorHex: course.colorHex, deckType: "Course", orderIndex: allDecks.count)
        automaticCourseSyncDigests.removeValue(forKey: deck.id)
        if deck.name != deckName { deck.name = deckName }
        if deck.colorHex != course.colorHex { deck.colorHex = course.colorHex }
        if deck.sourcePremadeID != "course:\(course.id)" { deck.sourcePremadeID = "course:\(course.id)" }
        if var enrollment = loadEnrollment(for: course.id), enrollment.linkedDeckId != deck.id.uuidString {
            enrollment.linkedDeckId = deck.id.uuidString
            saveEnrollment(enrollment)
            if activeCourseId == course.id { activeEnrollment = enrollment }
        }

        // These getters sort SwiftData relationships. Snapshot each relationship once,
        // work with local arrays/indexes, and update inverse relationships in bulk.
        let originalCards = deck.cards
        let originalSections = deck.sections
        let originalCardIds = Set(originalCards.map(\.id))
        let originalSectionIds = Set(originalSections.map(\.id))
        let originalSectionMembers = Dictionary(uniqueKeysWithValues: originalSections.map { ($0.id, Set($0.cards.map(\.id))) })
        let originalPositions = Dictionary(uniqueKeysWithValues: originalCards.enumerated().map { ($0.element.id, $0.offset) })
        var cardsBySource: [String: Flashcard] = [:]
        var legacyCards: [LegacyCardKey: [Flashcard]] = [:]
        for card in originalCards {
            if let source = card.sourceCourseCardID { if cardsBySource[source] == nil { cardsBySource[source] = card } }
            else if let sectionId = card.section?.id { legacyCards[LegacyCardKey(sectionId: sectionId, question: card.question), default: []].append(card) }
        }
        var sectionsBySource: [String: DeckSection] = [:]
        var legacySections: [String: DeckSection] = [:]
        for section in originalSections {
            if let source = section.sourceCourseUnitID { if sectionsBySource[source] == nil { sectionsBySource[source] = section } }
            else if legacySections[section.name] == nil { legacySections[section.name] = section }
        }
        var allSections = originalSections
        var authoredCards: [Flashcard] = []
        var destinationSections: [UUID: DeckSection] = [:]
        var usedIds: Set<UUID> = []
        var order = 0
        for unit in course.units {
            let section = sectionsBySource[unit.id] ?? legacySections.removeValue(forKey: unit.title)
                ?? DeckSection(name: unit.title, orderIndex: unit.unitNumber)
            sectionsBySource[unit.id] = section
            if section.sourceCourseUnitID != unit.id { section.sourceCourseUnitID = unit.id }
            if section.name != unit.title { section.name = unit.title }
            if section.summary != unit.subtitle { section.summary = unit.subtitle }
            if section.colorHex != unit.colorHex { section.colorHex = unit.colorHex }
            if section.orderIndex != unit.unitNumber { section.orderIndex = unit.unitNumber }
            if !originalSectionIds.contains(section.id) { allSections.append(section) }
            for definition in unit.lessons.flatMap(\.cards) {
                let type: FlashcardType
                switch definition.cardType {
                case "fillBlank", "listeningWrite": type = definition.options.isEmpty ? .fillBlank : .multipleChoice
                case "vocabulary": type = .vocabulary
                case "tapReveal": type = .tapReveal
                case "matching": type = .matching
                default: type = .multipleChoice
                }
                let deckQuestion = definition.practiceQuestionText(audioEnabled: false)
                let previousQuestions = [deckQuestion, definition.questionText(audioEnabled: false), definition.previousQuestion].compactMap { $0 }
                let legacyCandidates = Set(previousQuestions).compactMap { question in
                    legacyCards[LegacyCardKey(sectionId: section.id, question: question)]?.first { !usedIds.contains($0.id) }
                }
                let legacy = legacyCandidates.min { (originalPositions[$0.id] ?? 0) < (originalPositions[$1.id] ?? 0) }
                let card = cardsBySource[definition.id] ?? legacy ?? Flashcard(question: deckQuestion,
                    options: definition.options, correctAnswer: definition.correctAnswer, hint: definition.hint,
                    cardType: type, matchingLeftItems: definition.matchingLeftItems, matchingRightItems: definition.matchingRightItems,
                    promptImageName: definition.promptImageName, answerImageName: definition.answerImageName, optionImageNames: definition.optionImageNames)
                if card.sourceCourseCardID != definition.id { card.sourceCourseCardID = definition.id }
                if card.question != deckQuestion { card.question = deckQuestion }
                if card.options != definition.options { card.options = definition.options }
                if card.correctAnswer != definition.correctAnswer { card.correctAnswer = definition.correctAnswer }
                if card.hint != definition.hint { card.hint = definition.hint }
                if card.cardType != type { card.cardType = type }
                if card.matchingLeftItems != definition.matchingLeftItems { card.matchingLeftItems = definition.matchingLeftItems }
                if card.matchingRightItems != definition.matchingRightItems { card.matchingRightItems = definition.matchingRightItems }
                if card.fieldMedia != definition.resolvedFieldMedia { card.fieldMedia = definition.resolvedFieldMedia }
                if card.correctOptionIndex != definition.correctOptionIndex { card.correctOptionIndex = definition.correctOptionIndex }
                if card.orderIndex != order { card.orderIndex = order }
                order += 1
                authoredCards.append(card)
                destinationSections[card.id] = section
                usedIds.insert(card.id)
            }
        }
        // Preserve removed/authored extras and every saved review value.
        let extras = originalCards.filter { !usedIds.contains($0.id) }
        for card in extras {
            if card.orderIndex != order { card.orderIndex = order }
            order += 1
        }
        let allCards = authoredCards + extras
        var sectionMembers: [UUID: [Flashcard]] = [:]
        for card in allCards {
            if let section = destinationSections[card.id] ?? card.section { sectionMembers[section.id, default: []].append(card) }
        }
        for section in allSections {
            let members = sectionMembers[section.id] ?? []
            if originalSectionMembers[section.id] != Set(members.map(\.id)) { section.cards = members }
        }
        if originalSectionIds != Set(allSections.map(\.id)) { deck.sections = allSections }
        if originalCardIds != Set(allCards.map(\.id)) { deck.cards = allCards }
        if existing == nil { context.insert(deck) }
        do { if context.hasChanges { try context.save() } }
        catch { print("Course deck could not be saved: \(error.localizedDescription)") }
        return deck
    }

    // MARK: - Lesson Progression & Gating Logic

    func getLessonRecord(courseId: String, lessonId: String) -> CourseLessonProgressRecord {
        progressMap[courseId]?[lessonId] ?? CourseLessonProgressRecord(status: .locked)
    }

    func getLessonStatus(courseId: String, lessonId: String) -> LessonStatus {
        guard let course = CourseCurriculumCatalog.course(for: courseId) else { return .locked }
        return learningSnapshot.status(course: course, lessonId: lessonId)
    }

    /// Check if all regular lessons in a section are completed
    func isSectionLessonsCompleted(courseId: String, sectionId: String) -> Bool {
        guard let course = CourseCurriculumCatalog.course(for: courseId),
              let unit = course.units.first(where: { $0.id == sectionId }) else {
            return false
        }
        let snapshot = learningSnapshot
        return unit.lessons.allSatisfy { snapshot.status(course: course, lessonId: $0.id) == .completed }
    }

    /// Check if a section checkpoint has been passed
    func isCheckpointPassed(courseId: String, sectionId: String) -> Bool {
        guard let result = checkpointResults[courseId]?[sectionId] else { return false }
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
           let result = learningStore.transaction({ $0.checkpoint(course: course, unit: unit, missed: missedQuestionIds) }) ?? nil {
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
        isCorrect: Bool, eventToken: String? = nil, exerciseAttemptID: String? = nil) -> Bool {
        guard let course = CourseCurriculumCatalog.course(for: courseId),
              course.units.contains(where: { $0.id == sectionId && $0.lessons.contains(where: { $0.id == lessonId }) }) else { return false }
        let applied = learningStore.transaction {
            $0.answer(course: course, lessonId: lessonId, cardId: cardId, correct: isCorrect, token: eventToken ?? UUID().uuidString, exerciseAttemptID: exerciseAttemptID)
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
                    if let card = lesson.cards.first(where: {
                        let prompts = [$0.question, $0.practiceQuestionText(audioEnabled: false), $0.previousQuestion].compactMap { $0 }
                        return prompts.contains { $0 == cardQuestion || cardQuestion.contains($0) }
                    }) {
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
        let session = learningStore.transaction {
            $0.resumePractice(course: course, lessonId: lessonId, checkpointUnitId: checkpointUnitId)
        } ?? nil
        reloadFromSharedDefaults()
        return session
    }

    @discardableResult
    func recordPracticeAnswer(course: CourseDefinition, lessonId: String?, checkpointUnitId: String?, sessionId: String, cardId: String, correct: Bool, exerciseAttemptID: String? = nil) -> Bool {
        let saved = learningStore.transaction {
            $0.answerPractice(course: course, lessonId: lessonId, checkpointUnitId: checkpointUnitId, sessionId: sessionId, cardId: cardId, correct: correct, exerciseAttemptID: exerciseAttemptID)
        } ?? false
        reloadFromSharedDefaults()
        if saved { reconcilePendingNotifications(for: course) }
        return saved
    }

    func finishPractice(course: CourseDefinition, lessonId: String?, checkpointUnitId: String?, sessionId: String) -> CoursePracticeCompletion? {
        let completion = learningStore.transaction {
            $0.finishPractice(course: course, lessonId: lessonId, checkpointUnitId: checkpointUnitId, sessionId: sessionId)
        } ?? nil
        reloadFromSharedDefaults()
        if completion != nil { reconcilePendingNotifications(for: course) }
        return completion
    }

    func answeredCardsCount(course: CourseDefinition, lesson: CourseLesson) -> Int {
        let state = learningSnapshot
        let key = CourseLearningSnapshot.practiceKey(courseId: course.id, lessonId: lesson.id, checkpointUnitId: nil)!
        let answered = Set(state.practiceSessions[key]?.answers.keys.map { $0 } ?? [])
        let mastered = Set(state.progress[course.id]?[lesson.id]?.masteredCardIds ?? [])
        return answered.union(mastered).intersection(Set(lesson.cards.map(\.id))).count
    }

    // MARK: - Spaced Repetition + Ordered Path Card Selection (Requirement 7)

    /// Generates the next batch of cards to study: combines new cards from current lesson and due SRS cards from completed lessons.
    func nextStudyBatch(for course: CourseDefinition, maxCount: Int = 10) -> [CourseLessonCard] {
        learningStore.snapshot().batch(course: course, count: maxCount)
    }

    // MARK: - Current State Queries

    func currentLesson(for course: CourseDefinition) -> CourseLesson? {
        learningSnapshot.currentLesson(course: course)
    }

    func completedLessonsCount(for course: CourseDefinition) -> Int {
        let snapshot = learningSnapshot
        return course.units.flatMap(\.lessons).filter { snapshot.status(course: course, lessonId: $0.id) == .completed }.count
    }

    func completionPercentage(for course: CourseDefinition) -> Double {
        learningSnapshot.completionFraction(course: course)
    }

    func completedCards(for course: CourseDefinition) -> [CourseLessonCard] {
        let snapshot = learningSnapshot
        return course.units.flatMap(\.lessons)
            .filter { snapshot.status(course: course, lessonId: $0.id) == .completed }
            .flatMap { lesson in
                let learned = Set(snapshot.progress[course.id]?[lesson.id]?.masteredCardIds ?? [])
                return lesson.cards.filter { !$0.isExposure && ($0.activity == nil || learned.contains($0.id) || snapshot.srsRecord(courseId: course.id, cardId: $0.id) != nil) }
            }
    }

    // MARK: - Scheduling Pointer & Notification Reconciliation (Requirements 6 & 14)

    func updateSchedulePointer(course: CourseDefinition) {
        let snapshot = learningStore.snapshot()
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
        guard CourseNotificationScheduler.activePlan?.courseId == course.id else { return }
        updateSchedulePointer(course: course)
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
        learningStore.transaction { state in
            // Enrollment only initializes absent records, preserving extension progress.
            for (id, record) in map where state.progress[courseId]?[id] == nil {
                state.progress[courseId, default: [:]][id] = record
            }
        }
    }

    private func loadProgressMap(for courseId: String) -> [String: CourseLessonProgressRecord] {
        learningStore.snapshot().progress[courseId] ?? [:]
    }

    private func saveCheckpointResults(_ results: [String: CourseCheckpointResult], for courseId: String) {
        guard let defaults = sharedDefaults,
              let data = try? JSONEncoder().encode(results) else { return }
        defaults.set(data, forKey: "course_checkpoints_\(courseId)")
        defaults.synchronize()
    }

    private func loadCheckpointResults(for courseId: String) -> [String: CourseCheckpointResult] {
        learningStore.snapshot().checkpoints[courseId] ?? [:]
    }

    private func saveSRSRecords(_ records: [String: CourseCardSRSRecord]) {
        guard let defaults = sharedDefaults,
              let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: "course_srs_records")
        defaults.synchronize()
    }

    private func loadSRSRecords() -> [String: CourseCardSRSRecord] {
        learningStore.snapshot().srs
    }
}
