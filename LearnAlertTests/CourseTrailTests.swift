import Foundation
import AVFoundation
import Testing
import SwiftUI
import UIKit
@testable import LearnAlert

@MainActor
@Suite("Connected course trail and letter practice")
struct CourseTrailTests {
    private var course: CourseDefinition { CourseCurriculumCatalog.koreanCourse }
    private var reviewCourse: CourseDefinition {
        let cards = (1...3).map { CourseLessonCard(id: "review-\($0)", question: "Letter \($0)", correctAnswer: "a") }
        let lesson = CourseLesson(id: "review-lesson", lessonNumber: 1, title: "Read your first words", subtitle: "", cards: cards)
        let quiz = CourseCheckpointQuiz(id: "review-quiz", title: "Checkpoint", summary: "", questions: cards)
        let unit = CourseUnit(id: "review-unit", unitNumber: 1, title: "First words", subtitle: "", colorHex: "007AFF",
            badgeIcon: "book.fill", lessons: [lesson], checkpointQuiz: quiz)
        return CourseDefinition(id: "review-course", title: "Korean", language: "Korean", flagEmoji: "🇰🇷",
            levelTag: "Beginner", colorHex: "007AFF", summary: "", estimatedHours: 1, outcomes: [], units: [unit])
    }

    @Test("Review requires every activity to be attempted and clears when the missing answers are mastered")
    func reviewState() throws {
        let course = reviewCourse
        let unit = course.units[0]
        let lesson = unit.lessons[0]
        var state = CourseLearningSnapshot()
        for attempt in 1...3 {
            state.answer(course: course, lessonId: lesson.id, cardId: lesson.cards[0].id, correct: false, token: "repeat-\(attempt)")
        }
        #expect(CourseTrailProjection(course: course, snapshot: state).focus?.status == .current)
        state.answer(course: course, lessonId: lesson.id, cardId: lesson.cards[1].id, correct: true, token: "second")
        let partial = try #require(CourseTrailProjection(course: course, snapshot: state).focus)
        #expect(partial.status == .current && partial.showsProgress && partial.percentage == "33%")
        state.answer(course: course, lessonId: lesson.id, cardId: lesson.cards[2].id, correct: true, token: "third")
        let persisted = try JSONDecoder().decode(CourseLearningSnapshot.self, from: JSONEncoder().encode(state))
        let review = try #require(CourseTrailProjection(course: course, snapshot: persisted).focus)
        #expect(review.id == lesson.id && review.needsReview && review.isCurrent)
        #expect(review.percentage == "66%" && review.detail == "Needs review")
        #expect(state.status(course: course, lessonId: lesson.id) == .current)
        #expect(CourseTrailProjection(course: course, snapshot: state).milestones.last?.status == .locked)
        state.answer(course: course, lessonId: lesson.id, cardId: lesson.cards[0].id, correct: true, token: "corrected")
        let ready = CourseTrailProjection(course: course, snapshot: state)
        #expect(ready.milestones.first?.status == .completed)
        #expect(ready.focus?.isCheckpoint == true && ready.focus?.status == .available)
        let failed = state.checkpoint(course: course, unit: unit, missed: lesson.cards.map(\.id))
        #expect(failed?.passed == false)
        #expect(CourseTrailProjection(course: course, snapshot: state).focus?.needsReview == true)
        let passed = state.checkpoint(course: course, unit: unit, missed: [])
        #expect(passed?.passed == true)
        #expect(CourseTrailProjection(course: course, snapshot: state).milestones.allSatisfy { $0.status == .completed })
    }

    @Test("A fully attempted lesson can need review at zero percent mastery")
    func zeroMasteryReview() {
        let course = reviewCourse
        let lesson = course.units[0].lessons[0]
        var state = CourseLearningSnapshot()
        for card in lesson.cards {
            state.answer(course: course, lessonId: lesson.id, cardId: card.id, correct: false, token: card.id)
        }
        let focus = CourseTrailProjection(course: course, snapshot: state).focus
        #expect(focus?.needsReview == true && focus?.showsProgress == true && focus?.percentage == "0%")
    }

    @Test("The trail follows live practice, the pending quiz, and the next section")
    func trailProgress() throws {
        var state = CourseLearningSnapshot()
        let first = course.units[0].lessons[0]
        let initial = CourseTrailProjection(course: course, snapshot: state)
        #expect(initial.focus?.id == first.id)
        #expect(initial.currentUnit.count == course.units[0].lessons.count + 1)
        let saved = state.answer(course: course, lessonId: first.id, cardId: first.cards[0].id, correct: true, token: "trail-first")
        #expect(saved)
        let partial = CourseTrailProjection(course: course, snapshot: state)
        #expect(partial.focus?.fraction == 1 / Double(first.cards.count))
        for lesson in course.units[0].lessons {
            for card in lesson.cards {
                state.answer(course: course, lessonId: lesson.id, cardId: card.id, correct: true, token: "trail-\(card.id)")
            }
        }
        let ready = CourseTrailProjection(course: course, snapshot: state)
        #expect(ready.focus?.isCheckpoint == true && ready.focus?.status == .available)
        #expect(ready.currentUnit.dropLast().allSatisfy { $0.fraction == 1 })
        let result = state.checkpoint(course: course, unit: course.units[0], missed: [])
        #expect(result?.passed == true)
        let advanced = CourseTrailProjection(course: course, snapshot: state)
        #expect(advanced.focus?.id == course.units[1].lessons[0].id)
        #expect(advanced.currentUnit.allSatisfy { $0.unitId == course.units[1].id })
    }

    @Test("An unfinished letter holds both alert and in-app practice until corrected")
    func letterMasteryGate() throws {
        var state = CourseLearningSnapshot()
        let lesson = course.units[0].lessons[0]
        let sessionValue = state.resumePractice(course: course, lessonId: lesson.id, checkpointUnitId: nil)
        let session = try #require(sessionValue)
        let intro = lesson.cards[0]
        let introSaved = state.answerPractice(course: course, lessonId: lesson.id, checkpointUnitId: nil,
            sessionId: session.id, cardId: intro.id, correct: true)
        #expect(introSaved)
        let group = try #require(lesson.cards[1].activity?.practiceGroup)
        let cards = lesson.cards.filter { $0.activity?.practiceGroup == group }
        let nextGroup = try #require(lesson.cards.first { $0.activity?.practiceGroup != nil && $0.activity?.practiceGroup != group })
        #expect(cards.count == 4)
        #expect(Set(cards.compactMap { $0.activity?.kind.rawValue }) == Set(["teach", "listenChoose", "trace", "situation"]))
        let skipped = state.answer(course: course, lessonId: lesson.id, cardId: nextGroup.id, correct: true, token: "cannot-skip")
        #expect(!skipped)
        let failed = cards[1]
        for card in cards {
            let saved = state.answerPractice(course: course, lessonId: lesson.id, checkpointUnitId: nil,
                sessionId: session.id, cardId: card.id, correct: card.id != failed.id)
            #expect(saved)
        }
        let key = try #require(CourseLearningSnapshot.practiceKey(courseId: course.id, lessonId: lesson.id, checkpointUnitId: nil))
        let pending = try #require(state.practiceSessions[key])
        #expect(pending.cardIds[pending.nextIndex ?? 0] == failed.id)
        #expect(state.batch(course: course, count: 10).map(\.id) == [failed.id])
        #expect(CourseNotificationProgress.nextLearningCard(course: course, snapshot: state, excluding: Set(cards.map(\.id)))?.id == failed.id)
        let retry = state.answerPractice(course: course, lessonId: lesson.id, checkpointUnitId: nil,
            sessionId: session.id, cardId: failed.id, correct: true)
        #expect(retry)
        #expect(state.practiceSessions[key]?.answers[failed.id] == true)
        #expect(state.batch(course: course, count: 10).allSatisfy { $0.activity?.practiceGroup == nextGroup.activity?.practiceGroup })
        #expect(state.srsRecord(courseId: course.id, cardId: failed.id)?.reviewCount == 2)
    }

    @Test("Tracing guides fade after two attempts and return for errors or a minute of hesitation")
    func tracingHelpPolicy() throws {
        #expect(CourseTraceGuidance(attempt: 1).showsGuide)
        #expect(CourseTraceGuidance(attempt: 2).showsGuide)
        #expect(!CourseTraceGuidance(attempt: 3).showsGuide)
        #expect(CourseTraceGuidance(attempt: 3, needsHelp: true).highlightsDirection)
        #expect(!CourseTraceGuidance(attempt: 3, elapsed: 59).showsGuide)
        #expect(CourseTraceGuidance(attempt: 3, elapsed: 60).highlightsDirection)
        var state = CourseLearningSnapshot()
        state.traceAttempts["ㅏ"] = 3
        let decoded = try JSONDecoder().decode(CourseLearningSnapshot.self, from: JSONEncoder().encode(state))
        #expect(decoded.traceAttempts["ㅏ"] == 3)
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
        json.removeValue(forKey: "traceAttempts")
        #expect(try JSONDecoder().decode(CourseLearningSnapshot.self, from: JSONSerialization.data(withJSONObject: json)).traceAttempts.isEmpty)
    }

    @Test("All 40 bundled letter recordings are playable and map to their actual letters")
    func recordings() throws {
        let letters = HangulAudio.vowels + HangulAudio.consonants
        #expect(letters.count == 40 && Set(letters).count == 40)
        #expect(HangulAudio.filename(for: "ㅏ") == "vowel_01")
        #expect(HangulAudio.filename(for: "ㅓ") == "vowel_03")
        #expect(HangulAudio.filename(for: "오") == "vowel_05")
        #expect(HangulAudio.filename(for: "ㅇ") == "consonant_08")
        #expect(HangulAudio.filename(for: "ㅉ") == "consonant_19")
        #expect(HangulAudio.filename(for: "나무") == nil)
        for letter in letters {
            let url = try #require(HangulAudio.url(for: letter))
            let player = try AVAudioPlayer(contentsOf: url)
            #expect(player.duration > 0 && player.duration < 10)
            #expect(KoreanSpeechManager.shared.canPlay(letter))
        }
        for lesson in course.units[0].lessons.prefix(2) {
            for card in lesson.cards where card.isListeningQuestion {
                #expect(HangulAudio.url(for: card.speechText ?? "") != nil)
            }
        }
    }

    @Test("Trail and mini trail render at phone and accessibility sizes")
    func trailAppearance() throws {
        var state = CourseLearningSnapshot()
        let first = course.units[0].lessons[0]
        for card in first.cards.prefix(3) { state.answer(course: course, lessonId: first.id, cardId: card.id, correct: true, token: card.id) }
        let trail = CourseTrailProjection(course: course, snapshot: state)
        var reviewState = CourseLearningSnapshot()
        let reviewCourse = reviewCourse
        let reviewLesson = reviewCourse.units[0].lessons[0]
        for (index, card) in reviewLesson.cards.enumerated() {
            reviewState.answer(course: reviewCourse, lessonId: reviewLesson.id, cardId: card.id, correct: index != 0, token: card.id)
        }
        let reviewTrail = CourseTrailProjection(course: reviewCourse, snapshot: reviewState)
        for scheme in [ColorScheme.light, .dark] {
            for size in [DynamicTypeSize.large, .accessibility2] {
                let view = VStack(spacing: 24) {
                    CourseMiniTrail(milestones: trail.currentUnit, color: .blue)
                    CourseConnectedTrail(milestones: trail.currentUnit, color: .blue) { _ in }
                    CourseMiniTrail(milestones: reviewTrail.currentUnit, color: .blue)
                    CourseConnectedTrail(milestones: reviewTrail.currentUnit, color: .blue) { _ in }
                }.padding(20).frame(width: 402).background(Color(.systemGroupedBackground))
                    .environment(\.colorScheme, scheme).environment(\.dynamicTypeSize, size)
                let renderer = ImageRenderer(content: view)
                renderer.scale = 2
                let image = try #require(renderer.uiImage)
                #expect(image.size.width == 402 && image.size.height > 300)
                Attachment.record(image, named: "course-trail-\(scheme)-\(size)", as: .png)
            }
        }
    }
}
