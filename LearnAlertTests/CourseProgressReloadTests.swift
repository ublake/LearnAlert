import Foundation
import Testing
@testable import LearnAlert

@MainActor
@Suite("Course progress reload")
struct CourseProgressReloadTests {
    private func course() -> CourseDefinition {
        .init(id: "reload-\(UUID().uuidString)", title: "Reload", language: "Spanish", flagEmoji: "🇪🇸",
              levelTag: "", colorHex: "#123456", summary: "", estimatedHours: 1, outcomes: [], units: [
                .init(id: "unit", unitNumber: 1, title: "Unit", subtitle: "", colorHex: "#123456", badgeIcon: "book", lessons: [
                    .init(id: "one", lessonNumber: 1, title: "One", subtitle: "", cards: [
                        .init(id: "one-a", question: "A", options: ["Yes", "No"], correctAnswer: "Yes"),
                        .init(id: "one-b", question: "B", options: ["Yes", "No"], correctAnswer: "Yes")
                    ]),
                    .init(id: "two", lessonNumber: 2, title: "Two", subtitle: "", cards: [
                        .init(id: "two-a", question: "C", options: ["Yes", "No"], correctAnswer: "Yes")
                    ])
                ])
              ])
    }

    @Test("Legacy defaults still migrate into the manager's shared progress snapshot")
    func legacyReload() throws {
        let suite = "CourseProgressReloadTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        defer {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: directory)
        }
        let course = try #require(CourseCurriculumCatalog.courses.first)
        let unit = try #require(course.units.first)
        let lesson = try #require(unit.lessons.first)
        let card = try #require(lesson.cards.first)
        let progress = [lesson.id: CourseLessonProgressRecord(status: .current, correctAnswersCount: 3,
            totalAttemptsCount: 4, masteredCardIds: [card.id])]
        let checkpoint = [unit.id: CourseCheckpointResult(checkpointId: "saved", sectionId: unit.id,
            score: 3, totalQuestions: 4, passed: false)]
        let reviews = [card.id: CourseCardSRSRecord(cardId: card.id, masteryScore: 2, reviewCount: 4, correctCount: 3)]
        defaults.set(try JSONEncoder().encode(progress), forKey: "course_progress_\(course.id)")
        defaults.set(try JSONEncoder().encode(checkpoint), forKey: "course_checkpoints_\(course.id)")
        defaults.set(try JSONEncoder().encode(reviews), forKey: "course_srs_records")
        defaults.set(["saved-answer"], forKey: "course_processed_event_tokens")
        let store = CourseLearningStore(directory: directory, defaults: defaults)
        let manager = CourseProgressManager(defaults: defaults, learningStore: store)
        let expected = store.snapshot()
        #expect(manager.progressMap == expected.progress)
        #expect(manager.checkpointResults == expected.checkpoints)
        #expect(manager.srsRecords == reviews)
        #expect(manager.scopedSRSRecords == expected.courseSRS)
        #expect(manager.processedEventTokens == ["saved-answer"])
        #expect(manager.getLessonRecord(courseId: course.id, lessonId: lesson.id) == progress[lesson.id])
    }

    @Test("Display queries stay in memory and foreground reload incorporates new shared answers")
    func cachedDisplayQueries() throws {
        let suite = "CourseProgressReloadTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        defer {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: directory)
        }
        let course = course()
        let lesson = course.units[0].lessons[0]
        let store = CourseLearningStore(directory: directory, defaults: defaults)
        let session = try #require(store.transaction {
            $0.resumePractice(course: course, lessonId: lesson.id, checkpointUnitId: nil)
        } ?? nil)
        let next = try #require(session.nextIndex)
        let answered = store.transaction {
            $0.answerPractice(course: course, lessonId: lesson.id, checkpointUnitId: nil,
                sessionId: session.id, cardId: session.cardIds[next], correct: true)
        }
        #expect(answered == true)
        let manager = CourseProgressManager(defaults: defaults, learningStore: store)
        let initialFraction = manager.completionPercentage(for: course)
        #expect(initialFraction > 0)
        #expect(manager.answeredCardsCount(course: course, lesson: lesson) == 1)

        let snapshotURL = directory.appendingPathComponent("course-learning-v1.json")
        let savedData = try Data(contentsOf: snapshotURL)
        try Data("not valid JSON".utf8).write(to: snapshotURL)
        #expect(manager.currentLesson(for: course)?.id == lesson.id)
        #expect(manager.completionPercentage(for: course) == initialFraction)
        #expect(manager.answeredCardsCount(course: course, lesson: lesson) == 1)
        #expect(store.lastError == nil)

        // Reconciling an unrelated course must neither read the invalid file nor
        // overwrite the one pointer belonging to the actively scheduled course.
        let pointer = Data("existing schedule pointer".utf8)
        defaults.set(pointer, forKey: "course_active_schedule_pointer")
        manager.reconcilePendingNotifications(for: course)
        #expect(defaults.data(forKey: "course_active_schedule_pointer") == pointer)
        #expect(store.lastError == nil)

        try savedData.write(to: snapshotURL)
        let updated = store.transaction { state in
            for card in lesson.cards {
                _ = state.answer(course: course, lessonId: lesson.id, cardId: card.id,
                    correct: true, token: "external-\(card.id)")
            }
        }
        #expect(updated != nil)
        // The app/extension explicitly reload on foreground or answer handoff.
        #expect(manager.currentLesson(for: course)?.id == lesson.id)
        manager.reloadFromSharedDefaults()
        #expect(manager.currentLesson(for: course)?.id == "two")
        #expect(manager.completionPercentage(for: course) > initialFraction)
        #expect(manager.answeredCardsCount(course: course, lesson: lesson) == lesson.cards.count)
    }
}
