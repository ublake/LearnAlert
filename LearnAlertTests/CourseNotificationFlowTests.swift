import Foundation
import Testing
@testable import LearnAlert

@MainActor
@Suite("Course notification continuity")
struct CourseNotificationFlowTests {
    private var course: CourseDefinition { CourseCurriculumCatalog.koreanCourse }

    private func completeFirstUnit() -> CourseLearningSnapshot {
        var state = CourseLearningSnapshot()
        for lesson in course.units[0].lessons {
            for card in lesson.cards {
                state.answer(course: course, lessonId: lesson.id, cardId: card.id, correct: true, token: "ready-\(card.id)")
            }
        }
        return state
    }

    @Test("The last saved practice answer immediately makes section progress quiz ready")
    func finalAnswerRevealsQuiz() throws {
        var state = CourseLearningSnapshot()
        let unit = course.units[0]
        let finalLesson = try #require(unit.lessons.last)
        let finalCard = try #require(finalLesson.cards.last)
        for lesson in unit.lessons {
            for card in lesson.cards where card.id != finalCard.id {
                state.answer(course: course, lessonId: lesson.id, cardId: card.id, correct: true, token: card.id)
            }
        }
        let before = CourseNotificationProgress(course: course, snapshot: state)
        #expect(before.checkpointUnitId == nil)
        #expect(before.learnedCount == before.totalCount - 1)
        let lastAnswerSaved = state.answer(course: course, lessonId: finalLesson.id, cardId: finalCard.id, correct: true, token: "last-alert")
        #expect(lastAnswerSaved)
        let after = CourseNotificationProgress(course: course, snapshot: state)
        #expect(after.checkpointUnitId == unit.id)
        #expect(after.learnedCount == after.totalCount && after.fraction == 1)
        #expect(after.completedLessons == unit.lessons.count)
        #expect(!after.isCourseComplete)
        #expect(state.status(course: course, lessonId: course.units[1].lessons[0].id) == .locked)
    }

    @Test("A wrong answer and a duplicate delivery cannot falsely complete practice")
    func incompletePractice() throws {
        var state = CourseLearningSnapshot()
        let lesson = course.units[0].lessons[0]
        let card = try #require(lesson.cards.first)
        let wrongAnswerSaved = state.answer(course: course, lessonId: lesson.id, cardId: card.id, correct: false, token: "wrong")
        let duplicateAnswerSaved = state.answer(course: course, lessonId: lesson.id, cardId: card.id, correct: true, token: "wrong")
        #expect(wrongAnswerSaved)
        #expect(!duplicateAnswerSaved)
        let progress = CourseNotificationProgress(course: course, snapshot: state)
        #expect(progress.learnedCount == 0 && progress.checkpointUnitId == nil)
    }

    @Test("Optional alert practice remains available while the quiz waits without unlocking future material")
    func practiceAfterCheckpointReady() {
        let state = completeFirstUnit()
        #expect(state.batch(course: course, count: 60, reviewOnly: true).isEmpty)
        let practice = CourseNotificationProgress.practiceCards(course: course, snapshot: state)
        let allowedIds = Set(course.units[0].lessons.flatMap(\.cards).map(\.id))
        #expect(!practice.isEmpty)
        #expect(Set(practice.map(\.id)) == allowedIds)
        #expect(Set(practice.map(\.id)).count == practice.count)
        let excluded = Set(practice.prefix(3).map(\.id))
        let remaining = CourseNotificationProgress.practiceCards(course: course, snapshot: state, excluding: excluded)
        #expect(Set(remaining.map(\.id)).isDisjoint(with: excluded))
        #expect(state.pendingCheckpoint(course: course)?.id == course.units[0].id)
    }

    @Test("Notification quiz handoffs validate readiness and respect opening the path")
    func quizHandoff() {
        let ready = completeFirstUnit()
        let firstUnit = course.units[0]
        #expect(CourseHandoff.destination(course: course, snapshot: ready).sectionId == firstUnit.id)
        #expect(CourseHandoff.destination(course: course, snapshot: ready, requestedSectionId: firstUnit.id).sectionId == firstUnit.id)
        #expect(CourseHandoff.destination(course: course, snapshot: ready, openPath: true).sectionId == nil)
        #expect(CourseHandoff.destination(course: course, snapshot: ready, requestedSectionId: "stale-unit").sectionId == nil)
        #expect(CourseHandoff.destination(course: course, snapshot: CourseLearningSnapshot(), requestedSectionId: firstUnit.id).sectionId == nil)
        var passed = ready
        let result = passed.checkpoint(course: course, unit: firstUnit, missed: [])
        #expect(result?.passed == true)
        #expect(CourseHandoff.destination(course: course, snapshot: passed, requestedSectionId: firstUnit.id).sectionId == nil)
        #expect(CourseNotificationProgress(course: course, snapshot: passed).checkpointUnitId == nil)
    }

    private func legacyFirstUnit(passed: Bool) -> CourseLearningSnapshot {
        var state = CourseLearningSnapshot()
        let unit = course.units[0]
        for lesson in unit.lessons {
            // These original IDs never overlap the replacement workshop activity IDs.
            state.progress[course.id, default: [:]][lesson.id] = CourseLessonProgressRecord(
                status: .completed, masteredCardIds: ["\(lesson.id)-1", "\(lesson.id)-2"])
        }
        if passed {
            state.checkpoints[course.id, default: [:]][unit.id] = CourseCheckpointResult(
                checkpointId: unit.checkpointQuiz?.id ?? "kr-cp-1", sectionId: unit.id,
                score: 8, totalQuestions: 10, passed: true)
        }
        return state
    }

    @Test("A passed legacy checkpoint preserves the next unit and completed workshop status")
    func passedWorkshopMigration() {
        let state = legacyFirstUnit(passed: true)
        let firstUnit = course.units[0]
        let nextLesson = course.units[1].lessons[0]
        for lesson in firstUnit.lessons {
            #expect(state.status(course: course, lessonId: lesson.id) == .completed)
            let oldIds = Set(state.progress[course.id]?[lesson.id]?.masteredCardIds ?? [])
            #expect(oldIds.isDisjoint(with: Set(lesson.cards.map(\.id))))
        }
        #expect(state.currentLesson(course: course)?.id == nextLesson.id)
        #expect(state.status(course: course, lessonId: nextLesson.id) == .current)
        #expect(state.pendingCheckpoint(course: course) == nil)
        #expect(CourseNotificationProgress(course: course, snapshot: state).unitId == course.units[1].id)
    }

    @Test("Unfinished legacy completion requires replacement activities without deleting history")
    func unfinishedWorkshopMigration() {
        var state = legacyFirstUnit(passed: false)
        let firstLesson = course.units[0].lessons[0]
        let secondLesson = course.units[0].lessons[1]
        let oldIds = Set(state.progress[course.id]?[firstLesson.id]?.masteredCardIds ?? [])
        #expect(state.status(course: course, lessonId: firstLesson.id) == .current)
        #expect(state.status(course: course, lessonId: secondLesson.id) == .locked)
        #expect(state.status(course: course, lessonId: course.units[1].lessons[0].id) == .locked)
        #expect(state.pendingCheckpoint(course: course) == nil)
        for card in firstLesson.cards {
            let saved = state.answer(course: course, lessonId: firstLesson.id, cardId: card.id,
                correct: true, token: "migrate-\(card.id)")
            #expect(saved)
        }
        #expect(state.status(course: course, lessonId: firstLesson.id) == .completed)
        #expect(state.status(course: course, lessonId: secondLesson.id) == .current)
        let retainedIds = Set(state.progress[course.id]?[firstLesson.id]?.masteredCardIds ?? [])
        #expect(retainedIds.isSuperset(of: oldIds))
        #expect(retainedIds.isSuperset(of: Set(firstLesson.cards.map(\.id))))
    }

    @Test("Unseen replacement activities stay out of due reviews while practiced ones remain eligible")
    func workshopDueReviewMigration() throws {
        var state = legacyFirstUnit(passed: true)
        #expect(state.batch(course: course, count: 200, reviewOnly: true).isEmpty)
        #expect(CourseNotificationProgress.practiceCards(course: course, snapshot: state).isEmpty)
        let lesson = course.units[0].lessons[0]
        let first = try #require(lesson.cards.first)
        let second = try #require(lesson.cards.dropFirst().first)
        state.progress[course.id]?[lesson.id]?.masteredCardIds.append(first.id)
        state.srs[second.id] = CourseCardSRSRecord(cardId: second.id, nextReviewDate: .distantPast)
        let due = state.batch(course: course, count: 200, reviewOnly: true)
        #expect(Set(due.map(\.id)) == [first.id, second.id])
        #expect(state.currentLesson(course: course)?.id == course.units[1].lessons[0].id)
    }
}
