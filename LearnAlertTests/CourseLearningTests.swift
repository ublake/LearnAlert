import Foundation
import AVFoundation
import Testing
#if canImport(UIKit)
import UIKit
import SwiftUI
import SwiftData
#endif
@testable import LearnAlert

@MainActor
@Suite("Course learning path")
struct CourseLearningTests {
    private var course: CourseDefinition { CourseCurriculumCatalog.koreanCourse }

    @Test("Curriculum IDs, answers and checkpoints are consistent")
    func curriculum() {
        let lessons = course.units.flatMap(\.lessons)
        let cards = lessons.flatMap(\.cards)
        let quizzes = course.units.compactMap(\.checkpointQuiz)
        let all = cards + quizzes.flatMap(\.questions)
        #expect(course.units.count == 10)
        #expect(lessons.count == 41)
        #expect(cards.count == 1410)
        #expect(quizzes.count == 10)
        #expect(Set(all.map(\.id)).count == all.count)
        #expect(Set(lessons.map(\.id)).count == lessons.count)
        for card in all {
            #expect(!card.question.isEmpty && !card.correctAnswer.isEmpty)
            if card.cardType == "multipleChoice" || card.cardType == "listening" { #expect(card.options.contains(card.correctAnswer)); #expect(Set(card.options).count == card.options.count) }
            if card.cardType == "matching" { #expect(card.matchingLeftItems.count == card.matchingRightItems.count && !card.matchingLeftItems.isEmpty) }
        }
    }

    @Test("Expanded lessons cover reading, listening, production, and matching")
    func variedPractice() {
        for lesson in course.units.flatMap(\.lessons) {
            #expect(lesson.cards.count >= 33)
            let types = Set(lesson.cards.map(\.cardType))
            #expect(types.isSuperset(of: ["vocabulary", "multipleChoice", "fillBlank", "matching", "listening", "listeningWrite"]))
            #expect(!types.contains("tapReveal"))
        }
    }

    @Test("Listening alternatives keep the learning task and accept the same answer")
    func listeningAlternatives() throws {
        let audioCards = course.units.flatMap(\.lessons).flatMap(\.cards).filter(\.isListeningQuestion)
        #expect(audioCards.count == 492)
        for card in audioCards {
            #expect(card.speechText?.isEmpty == false)
            #expect(card.readingPrompt?.isEmpty == false)
            #expect(card.questionText(audioEnabled: true) == card.question)
            #expect(card.questionText(audioEnabled: false) != card.question)
            #expect(card.accepts(card.correctAnswer))
            #expect(try JSONDecoder().decode(CourseLessonCard.self, from: JSONEncoder().encode(card)) == card)
            if card.cardType == "listeningWrite" { #expect(card.usesTypedAnswer) }
        }
        let legacy = course.units[0].lessons[0].cards[0]
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(legacy)) as? [String: Any])
        json.removeValue(forKey: "readingPrompt")
        #expect(try JSONDecoder().decode(CourseLessonCard.self, from: JSONSerialization.data(withJSONObject: json)).readingPrompt == nil)
    }

    @Test("Playback starts and stops without a stale cancellation clearing a new utterance")
    func speechPlayback() async {
        let speech = KoreanSpeechManager.shared
        guard speech.hasVoice else { return }
        let phrase = "한국어를 공부하고 있어요. 오늘은 새로운 문장을 읽고 연습하고 있어요."
        speech.speak(phrase)
        #expect(speech.isSpeaking && speech.currentSpeakingText == phrase)
        speech.speechSynthesizer(AVSpeechSynthesizer(), didCancel: AVSpeechUtterance(string: "old playback"))
        await Task.yield()
        #expect(speech.isSpeaking && speech.currentSpeakingText == phrase)
        speech.stop()
        #expect(!speech.isSpeaking && speech.currentSpeakingText == nil)
    }

    @Test("Matching accepts selection from either side and remembers corrected mistakes")
    func matchingInteraction() {
        var state = CourseMatchingState(pairCount: 3)
        state.select(2, left: false)
        #expect(state.selectedRight == 2)
        state.select(1, left: true)
        #expect(state.hadMistake && state.matched.isEmpty && !state.complete)
        state.select(2, left: false); state.select(2, left: true)
        #expect(state.matched == [2] && state.mistakeLeft == nil)
        state.select(2, left: true)
        #expect(state.selectedLeft == nil)
        state.select(0, left: true); state.select(0, left: true)
        #expect(state.selectedLeft == nil)
        state.select(0, left: true); state.select(0, left: false)
        state.select(1, left: false); state.select(1, left: true)
        #expect(state.complete && state.hadMistake)
        var perfect = CourseMatchingState(pairCount: 1)
        perfect.select(0, left: false); perfect.select(0, left: true)
        #expect(perfect.complete && !perfect.hadMistake)
    }

    @Test("Every section bundles detailed guides and worked examples offline")
    func sectionGuides() {
        for course in CourseCurriculumCatalog.courses {
            for unit in course.units {
                let topics = CourseSectionGuides.topics(course: course, unit: unit)
                #expect(topics.count >= 7)
                #expect(Set(topics.map(\.id)).count == topics.count)
                #expect(topics.allSatisfy { !$0.rule.isEmpty })
                #expect(topics.filter { !$0.examples.isEmpty }.count >= 3)
            }
        }
        let hangul = CourseSectionGuides.topics(course: course, unit: course.units[0])
        #expect(hangul.contains { $0.rule.contains("Compound vowels") && $0.examples.contains { $0.contains("관") } })
    }

    @Test("Picture vocabulary resolves bundled art and keeps image choices aligned")
    func pictureVocabulary() throws {
        for course in CourseCurriculumCatalog.courses {
            let cards = course.units.flatMap(\.lessons).flatMap(\.cards)
            let prompts = cards.filter { $0.promptImageName != nil }
            let choices = cards.filter { !$0.optionImageNames.isEmpty }
            #expect(prompts.count == 16 && choices.count == 16)
            #expect(Set(prompts.compactMap { $0.options.firstIndex(of: $0.correctAnswer) }).count == 4)
            for card in prompts + choices {
                if let name = card.promptImageName { #expect(CardImageStore.loadImage(named: name) != nil) }
                #expect(card.optionImageNames.isEmpty || card.optionImageNames.count == card.options.count)
                for name in card.optionImageNames { #expect(CardImageStore.loadImage(named: name) != nil) }
                let encoded = try JSONEncoder().encode(card)
                #expect(try JSONDecoder().decode(CourseLessonCard.self, from: encoded) == card)
            }
        }
    }

    @Test("Editing built-in vocabulary art creates a private image copy")
    func editCoursePicture() throws {
        let name = "course-vocab-apple"
        let image = try #require(CardImageStore.loadImage(named: name))
        let copy = try #require(CardImageStore.saveImage(image, name: name))
        defer { CardImageStore.deleteImage(named: copy) }
        #expect(copy != name && copy.hasSuffix(".jpg"))
        #expect(CardImageStore.loadImage(named: copy) != nil)
        #expect(CardImageStore.loadImage(named: name) != nil)
    }

    @Test("Vocabulary definitions resolve authored particles and irregular verb forms")
    func vocabularyDefinitions() {
        #expect(KoreanLexicon.lookup("한국어를")?.dictionaryForm == "한국어")
        #expect(KoreanLexicon.lookup("추워요.")?.dictionaryForm == "춥다")
        #expect(KoreanLexicon.lookup("제가")?.dictionaryForm == "저")
        #expect(KoreanLexicon.lookup("도서관에서")?.dictionaryForm == "도서관")
        #expect(KoreanLexicon.lookup("unknown") == nil)
    }

    @Test("Expanded checkpoints use new questions instead of copying lesson practice")
    func transferQuestions() {
        for unit in course.units.dropFirst() {
            let questions = Set(unit.lessons.flatMap(\.cards).map(\.question))
            #expect(unit.checkpointQuiz!.questions.allSatisfy { !questions.contains($0.question) })
            #expect(unit.checkpointQuiz!.questions.contains { $0.cardType == "fillBlank" })
        }
    }

    @Test("Fresh enrollment opens exactly the first lesson")
    func orderedPath() {
        let state = CourseLearningSnapshot()
        let lessons = course.units.flatMap(\.lessons)
        #expect(state.status(course: course, lessonId: lessons[0].id) == .current)
        for lesson in lessons.dropFirst() { #expect(state.status(course: course, lessonId: lesson.id) == .locked) }
        #expect(state.currentLesson(course: course)?.id == lessons[0].id)
        #expect(state.pendingCheckpoint(course: course) == nil)
    }

    @Test("Wrong answers wait before returning; all cards must be correct to advance")
    func masteryAndRetry() {
        var state = CourseLearningSnapshot()
        let lesson = course.units[0].lessons[0]
        let first = lesson.cards[0]
        let outcome1 = state.answer(course: course, lessonId: lesson.id, cardId: first.id, correct: false, token: "wrong"); #expect(outcome1)
        #expect(!state.batch(course: course, count: 10).contains(where: { $0.id == first.id }))
        #expect(state.batch(course: course, count: 10, now: Date().addingTimeInterval(301)).contains(where: { $0.id == first.id }))
        for card in lesson.cards.dropFirst() { state.answer(course: course, lessonId: lesson.id, cardId: card.id, correct: true, token: card.id) }
        #expect(state.status(course: course, lessonId: lesson.id) == .current)
        state.answer(course: course, lessonId: lesson.id, cardId: first.id, correct: true, token: "retry")
        #expect(state.status(course: course, lessonId: lesson.id) == .completed)
        #expect(state.currentLesson(course: course)?.id == course.units[0].lessons[1].id)
    }

    @Test("Duplicate, unknown and locked answers cannot alter progress")
    func validation() {
        var state = CourseLearningSnapshot()
        let lesson = course.units[0].lessons[0], card = lesson.cards[0]
        let outcome2 = !state.answer(course: course, lessonId: course.units[1].lessons[0].id, cardId: course.units[1].lessons[0].cards[0].id, correct: true, token: "locked"); #expect(outcome2)
        let outcome3 = !state.answer(course: course, lessonId: lesson.id, cardId: "unknown", correct: true, token: "unknown"); #expect(outcome3)
        #expect(state.srs.isEmpty && state.eventTokens.isEmpty)
        let outcome4 = state.answer(course: course, lessonId: lesson.id, cardId: card.id, correct: true, token: "once"); #expect(outcome4)
        let outcome5 = !state.answer(course: course, lessonId: lesson.id, cardId: card.id, correct: false, token: "once"); #expect(outcome5)
        #expect(state.srs[card.id]?.reviewCount == 1)
    }

    @Test("Old answer tokens cannot be replayed after many later answers")
    func durableAnswerTokens() {
        var state = CourseLearningSnapshot()
        let lesson = course.units[0].lessons[0], card = lesson.cards[0]
        let first = state.answer(course: course, lessonId: lesson.id, cardId: card.id, correct: true, token: "original")
        #expect(first)
        state.eventTokens.append(contentsOf: (0..<4001).map { "later-\($0)" })
        let replayed = state.answer(course: course, lessonId: lesson.id, cardId: card.id, correct: true, token: "original")
        #expect(!replayed && state.srs[card.id]?.reviewCount == 1)
    }

    @Test("Checkpoint gates the next section and preserves a previous pass")
    func checkpointGate() {
        var state = CourseLearningSnapshot()
        let unit = course.units[0], next = course.units[1].lessons[0]
        let outcome6 = state.checkpoint(course: course, unit: unit, missed: []) == nil; #expect(outcome6)
        for lesson in unit.lessons {
            for card in lesson.cards { state.answer(course: course, lessonId: lesson.id, cardId: card.id, correct: true, token: card.id) }
        }
        #expect(state.currentLesson(course: course) == nil)
        #expect(state.pendingCheckpoint(course: course)?.id == unit.id)
        #expect(state.status(course: course, lessonId: next.id) == .locked)
        let outcome7 = state.checkpoint(course: course, unit: unit, missed: ["invalid"]) == nil; #expect(outcome7)
        let quiz = unit.checkpointQuiz!
        let outcome8 = state.checkpoint(course: course, unit: unit, missed: Array(quiz.questions.prefix(3).map(\.id)))?.passed == false; #expect(outcome8)
        #expect(state.status(course: course, lessonId: next.id) == .locked)
        let outcome9 = state.checkpoint(course: course, unit: unit, missed: Array(quiz.questions.prefix(2).map(\.id)))?.passed == true; #expect(outcome9)
        #expect(state.status(course: course, lessonId: next.id) == .current)
        let outcome10 = state.checkpoint(course: course, unit: unit, missed: quiz.questions.map(\.id))?.passed == false; #expect(outcome10)
        #expect(state.status(course: course, lessonId: next.id) == .current)
    }

    @Test("All lessons and quizzes finish without restarting the course")
    func completeCourse() {
        var state = CourseLearningSnapshot()
        for unit in course.units {
            for lesson in unit.lessons {
                for card in lesson.cards { let outcome11 = state.answer(course: course, lessonId: lesson.id, cardId: card.id, correct: true, token: card.id); #expect(outcome11) }
            }
            let outcome12 = state.checkpoint(course: course, unit: unit, missed: [])?.passed == true; #expect(outcome12)
        }
        #expect(state.currentLesson(course: course) == nil)
        #expect(state.pendingCheckpoint(course: course) == nil)
        #expect(!state.isFullyMastered(course: course))
        #expect(state.batch(course: course, count: 10).isEmpty)
        #expect(!state.batch(course: course, count: 10, now: Date().addingTimeInterval(14500)).isEmpty)
        for unit in course.units {
            for lesson in unit.lessons {
                for card in lesson.cards {
                    state.answer(course: course, lessonId: lesson.id, cardId: card.id, correct: true, token: "second-\(card.id)")
                    state.answer(course: course, lessonId: lesson.id, cardId: card.id, correct: true, token: "third-\(card.id)")
                }
            }
        }
        #expect(state.isFullyMastered(course: course))
    }

    @Test("Old saved progress and enrollments decode without new fields")
    func migration() throws {
        let enrollment = CourseEnrollment(courseId: course.id)
        let data = try JSONEncoder().encode(enrollment)
        var json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "autoPronounceInStudy"); json.removeValue(forKey: "checkpointPassingThreshold")
        let restored = try JSONDecoder().decode(CourseEnrollment.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(restored.autoPronounceInStudy == false && restored.checkpointPassingThreshold == 0.8)
        let legacy = Data(#"{"status":"completed","correctAnswersCount":4,"totalAttemptsCount":5}"#.utf8)
        let progress = try JSONDecoder().decode(CourseLessonProgressRecord.self, from: legacy)
        #expect(progress.status == .completed && progress.masteredCardIds.isEmpty)
    }

    @Test("Shared disk transactions preserve updates from independent clients")
    func sharedStore() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = CourseLearningStore(directory: directory, defaults: nil)
        let second = CourseLearningStore(directory: directory, defaults: nil)
        let lesson = course.units[0].lessons[0]
        let outcome13 = first.transaction { $0.answer(course: course, lessonId: lesson.id, cardId: lesson.cards[0].id, correct: true, token: "first") } == true; #expect(outcome13)
        let outcome14 = second.transaction { $0.answer(course: course, lessonId: lesson.id, cardId: lesson.cards[1].id, correct: false, token: "second") } == true; #expect(outcome14)
        #expect(first.snapshot().progress[course.id]?[lesson.id]?.totalAttemptsCount == 2)
        let outcome15 = second.transaction { $0.answer(course: course, lessonId: lesson.id, cardId: lesson.cards[0].id, correct: true, token: "first") } == false; #expect(outcome15)
        #expect(first.snapshot().progress[course.id]?[lesson.id]?.totalAttemptsCount == 2)
    }

    @Test("Partial practice survives a relaunch before Continue and keeps wrong answers")
    func resumePartialPractice() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CourseLearningStore(directory: directory, defaults: nil)
        let lesson = course.units[0].lessons[0]
        let session = try #require(store.transaction { $0.resumePractice(course: course, lessonId: lesson.id, checkpointUnitId: nil) } ?? nil)
        for (index, correct) in [true, false].enumerated() {
            let saved = store.transaction { $0.answerPractice(course: course, lessonId: lesson.id, checkpointUnitId: nil,
                sessionId: session.id, cardId: session.cardIds[index], correct: correct) }
            #expect(saved == true)
        }
        let reopened = CourseLearningStore(directory: directory, defaults: nil)
        let restored = try #require(reopened.transaction { $0.resumePractice(course: course, lessonId: lesson.id, checkpointUnitId: nil) } ?? nil)
        #expect(restored.id == session.id && restored.nextIndex == 2)
        #expect(restored.cardIds == session.cardIds)
        #expect(restored.missedCardIds == [session.cardIds[1]])
        #expect(reopened.snapshot().progress[course.id]?[lesson.id]?.totalAttemptsCount == 2)
        let duplicate = reopened.transaction { $0.answerPractice(course: course, lessonId: lesson.id, checkpointUnitId: nil,
            sessionId: session.id, cardId: session.cardIds[0], correct: true) }
        #expect(duplicate == false)
        #expect(reopened.snapshot().srs[session.cardIds[0]]?.reviewCount == 1)
        for cardId in session.cardIds.dropFirst(2) {
            #expect(reopened.transaction { $0.answerPractice(course: course, lessonId: lesson.id, checkpointUnitId: nil,
                sessionId: session.id, cardId: cardId, correct: true) } == true)
        }
        // All answers can survive exiting on the last question without tapping Finish.
        let finalStore = CourseLearningStore(directory: directory, defaults: nil)
        let allAnswered = try #require(finalStore.transaction { $0.resumePractice(course: course, lessonId: lesson.id, checkpointUnitId: nil) } ?? nil)
        #expect(allAnswered.nextIndex == nil && allAnswered.missedCardIds == [session.cardIds[1]])
        #expect(finalStore.transaction { $0.finishPractice(course: course, lessonId: lesson.id, checkpointUnitId: nil, sessionId: session.id) } != nil)
        let retry = try #require(finalStore.transaction { $0.resumePractice(course: course, lessonId: lesson.id, checkpointUnitId: nil) } ?? nil)
        #expect(retry.id != session.id)
        #expect(retry.cardIds[try #require(retry.nextIndex)] == session.cardIds[1])
        #expect(retry.answers.count == lesson.cards.count - 1)
    }

    @Test("A curriculum upgrade preserves the old shuffled order and surviving answers")
    func practiceUpgrade() throws {
        var state = CourseLearningSnapshot()
        let lesson = course.units[0].lessons[0]
        let ids = [lesson.cards[2].id, lesson.cards[0].id]
        let key = try #require(CourseLearningSnapshot.practiceKey(courseId: course.id, lessonId: lesson.id, checkpointUnitId: nil))
        var old = CoursePracticeSession(cardIds: [ids[0], "removed-card", ids[1]])
        old.answers = [ids[0]: false, "removed-card": true]
        state.practiceSessions[key] = old
        let resumedValue = state.resumePractice(course: course, lessonId: lesson.id, checkpointUnitId: nil)
        let resumed = try #require(resumedValue)
        #expect(resumed.id == old.id && Array(resumed.cardIds.prefix(2)) == ids)
        #expect(resumed.answers == [ids[0]: false])
        #expect(resumed.nextIndex == 1)
        #expect(Set(resumed.cardIds) == Set(lesson.cards.map(\.id)))
        var reopened = try JSONDecoder().decode(CourseLearningSnapshot.self, from: JSONEncoder().encode(state))
        let againValue = reopened.resumePractice(course: course, lessonId: lesson.id, checkpointUnitId: nil)
        let again = try #require(againValue)
        #expect(again.cardIds == resumed.cardIds && again.answers == resumed.answers)
    }

    @Test("Saved notification answers and legacy snapshots resume without losing mastery")
    func resumeLegacyPractice() throws {
        var state = CourseLearningSnapshot()
        let lesson = course.units[0].lessons[0]
        state.answer(course: course, lessonId: lesson.id, cardId: lesson.cards[0].id, correct: true, token: "notification")
        let fraction = state.completionFraction(course: course)
        #expect(fraction > 0 && fraction < 1 / Double(course.totalLessonsCount))
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
        json.removeValue(forKey: "practiceSessions")
        var legacy = try JSONDecoder().decode(CourseLearningSnapshot.self, from: JSONSerialization.data(withJSONObject: json))
        let resumedValue = legacy.resumePractice(course: course, lessonId: lesson.id, checkpointUnitId: nil)
        let resumed = try #require(resumedValue)
        #expect(resumed.answers[lesson.cards[0].id] == true)
        #expect(resumed.answers[resumed.cardIds[try #require(resumed.nextIndex)]] == nil)
        #expect(legacy.eventTokens == ["notification"] && legacy.srs[lesson.cards[0].id]?.reviewCount == 1)
        #expect(legacy.completionFraction(course: course) == fraction)
        #expect(legacy.resumePractice(course: course, lessonId: course.units[1].lessons[0].id, checkpointUnitId: nil) == nil)
    }

    @Test("Checkpoint attempts resume their scores and finalize only after every question")
    func resumeCheckpoint() throws {
        var state = CourseLearningSnapshot()
        let unit = course.units[0], quiz = try #require(unit.checkpointQuiz)
        #expect(state.resumePractice(course: course, lessonId: nil, checkpointUnitId: unit.id) == nil)
        for lesson in unit.lessons {
            for card in lesson.cards { state.answer(course: course, lessonId: lesson.id, cardId: card.id, correct: true, token: card.id) }
        }
        let sessionValue = state.resumePractice(course: course, lessonId: nil, checkpointUnitId: unit.id)
        let session = try #require(sessionValue)
        let firstSaved = state.answerPractice(course: course, lessonId: nil, checkpointUnitId: unit.id, sessionId: session.id,
            cardId: session.cardIds[0], correct: false)
        #expect(firstSaved)
        #expect(state.finishPractice(course: course, lessonId: nil, checkpointUnitId: unit.id, sessionId: session.id) == nil)
        var reopened = try JSONDecoder().decode(CourseLearningSnapshot.self, from: JSONEncoder().encode(state))
        let resumedValue = reopened.resumePractice(course: course, lessonId: nil, checkpointUnitId: unit.id)
        let resumed = try #require(resumedValue)
        #expect(resumed.id == session.id && resumed.nextIndex == 1)
        for cardId in session.cardIds.dropFirst() {
            let saved = reopened.answerPractice(course: course, lessonId: nil, checkpointUnitId: unit.id, sessionId: session.id, cardId: cardId, correct: true)
            #expect(saved)
        }
        let completionValue = reopened.finishPractice(course: course, lessonId: nil, checkpointUnitId: unit.id, sessionId: session.id)
        let completion = try #require(completionValue)
        #expect(completion.checkpointResult?.score == quiz.questions.count - 1)
        #expect(completion.checkpointResult?.missedQuestionIds == [session.cardIds[0]])
        #expect(completion.checkpointResult?.passed == true)
        #expect(reopened.status(course: course, lessonId: course.units[1].lessons[0].id) == .current)
        #expect(reopened.practiceSessions.isEmpty)
    }

    @Test("Corrupt shared data is reported and never overwritten")
    func corruptStore() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("course-learning-v1.json")
        let original = Data("not json".utf8); try original.write(to: url)
        let store = CourseLearningStore(directory: directory, defaults: nil)
        let outcome16 = store.transaction { $0.eventTokens.append("no") } == nil; #expect(outcome16)
        #expect(store.lastError != nil)
        #expect(try Data(contentsOf: url) == original)
    }

    @Test("Unicode, punctuation and spacing normalization accept equivalent answers")
    func answerNormalization() {
        let card = CourseLessonCard(id: "test", question: "", correctAnswer: "한국어를 공부해요.", acceptedAnswers: ["한국어 공부해요"])
        #expect(card.accepts("  한국어를 공부해요!  "))
        #expect(card.accepts("한국어 공부해요"))
        #expect(card.accepts("한국어를 공부해요".decomposedStringWithCanonicalMapping))
        #expect(!card.accepts("")); #expect(!card.accepts("한국어를 안 공부해요"))
    }

    @Test("Schedule respects weekdays, overnight windows and request limits")
    func scheduling() throws {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 9, hour: 1)))
        let plan = CourseAlertPlan(courseId: course.id, deckId: "test", startHour: 22, startMinute: 0,
            endHour: 6, endMinute: 0, weekdays: [5], dailyCount: 8) // Thursday night includes Friday morning.
        let dates = plan.dates(now: now, calendar: calendar)
        #expect(dates.first == calendar.date(from: DateComponents(year: 2026, month: 10, day: 9, hour: 2)))
        #expect(dates.allSatisfy { $0 > now })
        let busy = CourseAlertPlan(courseId: course.id, deckId: "test", startHour: 9, startMinute: 0,
            endHour: 18, endMinute: 0, weekdays: [1,2,3,4,5,6,7], dailyCount: 50)
        #expect(busy.dates(now: now, calendar: calendar).count == 60)
        let empty = CourseAlertPlan(courseId: course.id, deckId: "test", startHour: 9, startMinute: 0,
            endHour: 18, endMinute: 0, weekdays: [], dailyCount: 5)
        #expect(empty.dates(now: now, calendar: calendar).isEmpty)
    }
    @Test("Ordinary overnight schedules retain the remaining morning window")
    func ordinaryOvernight() throws {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 9, hour: 1)))
        let window = try #require(StudyScheduling.window(now: now, startHour: 22, startMinute: 0,
            endHour: 2, endMinute: 0, calendar: calendar))
        #expect(window.start == now.addingTimeInterval(90))
        #expect(window.end == calendar.date(from: DateComponents(year: 2026, month: 10, day: 9, hour: 2)))
        let next = try #require(StudyScheduling.window(now: window.end, startHour: 22, startMinute: 0,
            endHour: 2, endMinute: 0, calendar: calendar))
        #expect(next.start == calendar.date(from: DateComponents(year: 2026, month: 10, day: 9, hour: 22)))
    }

    @Test("Sequential batches advance, wrap, and survive deleting the next card")
    func sequentialBatches() {
        struct Item: Identifiable { let id: Int }
        let ordered = (0..<7).map { Item(id: $0) }
        #expect(StudyScheduling.sequentialBatch(ordered, nextID: nil, count: 3).map(\.id) == [0, 1, 2])
        #expect(StudyScheduling.sequentialBatch(ordered, nextID: 3, count: 3).map(\.id) == [3, 4, 5])
        #expect(StudyScheduling.sequentialBatch(ordered, nextID: 6, count: 3).map(\.id) == [6, 0, 1])
        #expect(StudyScheduling.sequentialBatch(ordered, nextID: 100, count: 3).map(\.id) == [0, 1, 2])
        #expect(StudyScheduling.sequentialBatch(ordered, nextID: nil, count: 100).count == 7)
    }

    @Test("Checkpoint keeps learned review available and honors the configured pass score")
    func checkpointReview() {
        var state = CourseLearningSnapshot()
        let unit = course.units[0]
        for lesson in unit.lessons {
            for card in lesson.cards { state.answer(course: course, lessonId: lesson.id, cardId: card.id,
                correct: true, token: card.id) }
        }
        let review = state.batch(course: course, count: 50, now: Date().addingTimeInterval(14500), reviewOnly: true)
        #expect(!review.isEmpty)
        #expect(review.allSatisfy { card in unit.lessons.contains { $0.cards.contains { $0.id == card.id } } })
        #expect(state.currentLesson(course: course) == nil)
        let missed = Array(unit.checkpointQuiz!.questions.prefix(2).map(\.id))
        let strict = state.checkpoint(course: course, unit: unit, missed: missed, passingThreshold: 0.9)
        #expect(strict?.passed == false)
        #expect(state.currentLesson(course: course) == nil)
    }

    #if canImport(UIKit)
    @Test("Existing course deck is expanded without duplication or review resets")
    func deckUpgrade() throws {
        let container = try ModelContainer(for: Deck.self, DeckSection.self, Flashcard.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let context = ModelContext(container)
        let original = CourseDefinition(id: course.id, title: "Korean Foundations", language: "Korean",
            flagEmoji: course.flagEmoji, levelTag: "Hangul", colorHex: course.colorHex, summary: "", estimatedHours: 14,
            outcomes: [], units: [course.units[0]])
        let manager = CourseProgressManager.shared
        let old = manager.createOrSyncCourseDeck(for: original, in: context)
        let first = try #require(old.cards.first)
        first.reviewCount = 7
        let upgraded = manager.createOrSyncCourseDeck(for: course, in: context)
        #expect(upgraded.id == old.id)
        #expect(upgraded.cards.count == 1410 && upgraded.sections.count == 10)
        #expect(upgraded.cards.first?.id == first.id && first.reviewCount == 7)
        let repeated = manager.createOrSyncCourseDeck(for: course, in: context)
        #expect(repeated.cards.count == 1410)
        #expect(try context.fetch(FetchDescriptor<Deck>()).count == 1)
    }

    @Test("Spacious picture questions render across appearances")
    func redesignedAppearance() throws {
        let cards = course.units.flatMap(\.lessons).flatMap(\.cards)
        let prompt = try #require(cards.first { $0.promptImageName != nil })
        let choices = try #require(cards.first { !$0.optionImageNames.isEmpty })
        let longMatch = try #require(course.units.last?.lessons.last?.cards.first { $0.cardType == "matching" })
        for scheme in [ColorScheme.light, .dark] {
            for (label, view) in [
                ("picture-prompt", AnyView(CourseQuestionPanel(card: prompt, immersive: true) { _ in })),
                ("picture-choices", AnyView(CourseQuestionPanel(card: choices, immersive: true) { _ in })),
                ("long-matching", AnyView(CourseQuestionPanel(card: longMatch, immersive: true) { _ in })),
                ("accessible-matching", AnyView(CourseQuestionPanel(card: longMatch, immersive: true) { _ in }.environment(\.dynamicTypeSize, .accessibility2))),
                ("matching", AnyView(CourseQuestionPanel(card: course.units[0].lessons[0].cards[2], immersive: true) { _ in })),
                ("reading-alternative", AnyView(CourseQuestionPanel(card: course.units[0].lessons[0].cards.first { $0.cardType == "listening" }!, immersive: true, prefersReading: true) { _ in })),
                ("vocabulary", AnyView(CourseQuestionPanel(card: course.units[0].lessons[0].cards[1], immersive: true) { _ in })),
                ("listening", AnyView(CourseQuestionPanel(card: course.units[0].lessons[0].cards.first { $0.cardType == "listening" }!, immersive: true) { _ in })),
                ("guide", AnyView(CourseGuideContent(course: course, unit: course.units[0]))),
                ("large-type", AnyView(CourseQuestionPanel(card: prompt, immersive: true) { _ in }.environment(\.dynamicTypeSize, .accessibility2)))
            ] {
                let renderer = ImageRenderer(content: view.padding(24).frame(width: 402)
                    .background(Color(.systemGroupedBackground)).environment(\.colorScheme, scheme))
                renderer.scale = 2
                let image = try #require(renderer.uiImage)
                #expect(image.size.width == 402)
                Attachment.record(image, named: "redesign-\(label)-\(scheme == .dark ? "dark" : "light")", as: .png)
            }
        }
    }

    @Test("Course question renders in light and dark mode")
    func questionAppearance() throws {
        let card = course.units[1].lessons[0].cards[0]
        for scheme in [ColorScheme.light, .dark] {
            let renderer = ImageRenderer(content: CourseQuestionPanel(card: card) { _ in }
                .padding(16).frame(width: 360).background(.background).environment(\.colorScheme, scheme))
            renderer.scale = 2
            let image = try #require(renderer.uiImage)
            #expect(image.size.width == 360 && image.size.height > 200)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("course-question-\(scheme == .dark ? "dark" : "light").png")
            try #require(image.pngData()).write(to: url)
            Attachment.record(image, named: url.lastPathComponent, as: .png)
        }
    }
    #endif

}
