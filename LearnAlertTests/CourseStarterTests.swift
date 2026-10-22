import Foundation
import SwiftUI
import Testing
@testable import LearnAlert

@MainActor
@Suite("Playable visual starter and narrow assessment")
struct CourseStarterTests {
    private func baseCourse() -> CourseDefinition {
        .init(id: "spanish-course", title: "Spanish (SP)", language: "Spanish", flagEmoji: "🇪🇸", levelTag: "Beginner", colorHex: "#E05A47", summary: "Test legacy path", estimatedHours: 1, outcomes: [], units: [
            .init(id: "legacy-unit", unitNumber: 1, title: "Legacy pronunciation", subtitle: "", colorHex: "#E05A47", badgeIcon: "book", lessons: [
                .init(id: "legacy-one", lessonNumber: 1, title: "Legacy one", subtitle: "", cards: [.init(id: "old-one", question: "Old", correctAnswer: "Old", cardType: "vocabulary")]),
                .init(id: "legacy-two", lessonNumber: 2, title: "Legacy two", subtitle: "", cards: [.init(id: "old-two", question: "Old two", correctAnswer: "Old two", cardType: "vocabulary")])
            ])
        ])
    }
    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
    private func installed(_ directory: URL) throws -> (ManagedCatalogStore, CourseDefinition) {
        let catalog = ManagedCatalogStore(directory: directory, defaults: nil, developmentPreview: true)
        let url = try #require(Bundle.main.url(forResource: "visual-starter-pilot", withExtension: "json"))
        try catalog.installStarterPreview(baseCourse: baseCourse(), componentData: Data(contentsOf: url))
        let course = try #require(catalog.course(for: "spanish-course"))
        return (catalog, course)
    }
    private func correctSteps(_ exercise: CourseExercise, initial: CourseExerciseState = .init()) -> [CourseExerciseState] {
        var state = initial; var steps: [CourseExerciseState] = []
        if exercise.format == "pictureChoice" || exercise.format == "choice" {
            state.select(exercise.correctChoiceID!, exercise: exercise); steps.append(state)
        } else if exercise.format == "wordBank" {
            for word in exercise.acceptedOrders!.first! {
                let tile = exercise.tiles!.first { $0.text == word && !state.selectedIDs.contains($0.id) }!
                state.append(tile.id, exercise: exercise); steps.append(state)
            }
        } else if exercise.format == "matching" {
            for pair in exercise.pairs!.reversed() {
                state.selectPair(pair.id, exercise: exercise); steps.append(state)
                state.matchPair(pair.id, exercise: exercise); steps.append(state)
            }
        }
        _ = state.submit(exercise); steps.append(state); return steps
    }
    @Test("Managed preview keeps the entire legacy course, stable IDs, real alpha assets and taught order")
    func managedPreviewAndOrder() throws {
        let directory = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
        let (_, course) = try installed(directory)
        #expect(course.id == baseCourse().id)
        #expect(course.units.first == baseCourse().units.first)
        let lessons = course.units.last!.lessons
        #expect(lessons.map(\.id) == ["pf-sp-l01", "pf-sp-l02"])
        let cards = lessons.flatMap(\.cards)
        #expect(cards.count == 30 && cards.filter(\.isExposure).count == 8)
        #expect(cards.filter { !$0.isExposure }.count == 22)
        var seen = Set<String>()
        for lesson in lessons {
            #expect(CourseLearningSnapshot.orderedLearningCards(lesson.cards).map(\.id) == lesson.cards.map(\.id))
            for card in lesson.cards {
                #expect(card.id.hasPrefix("pf-sp-l"))
                #expect(Set(card.activity!.exercise!.prerequisiteIDs!).isSubset(of: seen))
                if let cue = card.activity?.exercise?.stimulusText { #expect(card.question.localizedCaseInsensitiveContains(cue)) }
                seen.insert(card.id)
            }
        }
        for name in ["libro", "mochila", "silla", "reloj"] {
            let image = try #require(CourseVocabularyImages.image(named: "sp-\(name)-transparent.png")?.cgImage)
            #expect(image.width == 1254 && image.height == 1254)
            #expect(image.alphaInfo != .none && image.alphaInfo != .noneSkipFirst && image.alphaInfo != .noneSkipLast)
        }
        let normal = ManagedCatalogStore(directory: try temporaryDirectory(), defaults: nil)
        let url = Bundle.main.url(forResource: "visual-starter-pilot", withExtension: "json")!
        #expect(throws: (any Error).self) { try normal.installStarterPreview(baseCourse: baseCourse(), componentData: Data(contentsOf: url)) }
        let reopened = ManagedCatalogStore(directory: directory, defaults: nil, developmentPreview: true)
        #expect(reopened.course(for: course.id) == course)
    }
    @Test("New and returning routes preserve Continue, old completion fraction and optional starter choice")
    func routesPreserveHistory() throws {
        let directory = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
        let (_, course) = try installed(directory)
        var old = CourseLearningSnapshot()
        let first = old.answer(course: baseCourse(), lessonId: "legacy-one", cardId: "old-one", correct: true, token: "old")
        #expect(first)
        let existing = old.resumePractice(course: baseCourse(), lessonId: "legacy-two", checkpointUnitId: nil)
        let session = try #require(existing)
        let fraction = old.completionFraction(course: baseCourse())
        old.assignRoute(course: course, returningLearner: true)
        #expect(old.currentLesson(course: course)?.id == "legacy-two")
        #expect(old.completionFraction(course: course) == fraction)
        old.selectStarter(course: course, selected: true)
        #expect(old.currentLesson(course: course)?.id == "pf-sp-l01")
        old.selectStarter(course: course, selected: false)
        #expect(old.currentLesson(course: course)?.id == "legacy-two")
        #expect(old.practiceSessions["spanish-course:lesson:legacy-two"]?.id == session.id)
        #expect(old.exerciseEvidence.isEmpty)
        var fresh = CourseLearningSnapshot(); fresh.assignRoute(course: course, returningLearner: false)
        #expect(fresh.currentLesson(course: course)?.id == "pf-sp-l01")
        #expect(CourseTrailProjection(course: course, snapshot: fresh).focus?.id == "pf-sp-l01")
        #expect(fresh.status(course: course, lessonId: "pf-sp-l02") == .locked)
        #expect(CourseNotificationProgress.nextLearningCard(course: course, snapshot: fresh, excluding: []) == nil)
        var completed = CourseLearningSnapshot()
        for lesson in baseCourse().units[0].lessons {
            let saved = completed.answer(course: baseCourse(), lessonId: lesson.id, cardId: lesson.cards[0].id, correct: true, token: lesson.id); #expect(saved)
        }
        completed.assignRoute(course: course, returningLearner: true)
        #expect(completed.currentLesson(course: course) == nil)
        let trail = CourseTrailProjection(course: course, snapshot: completed)
        #expect(trail.focus?.status == .completed && trail.progressMilestones.count == 2)
        #expect(trail.progressMilestones.allSatisfy { $0.status == .completed })
        #expect(completed.completionFraction(course: course) == 1)
    }
    @Test("Both lessons run through shared finite reducers and file-backed practice without forced-pair or exposure mastery")
    func completePlayableLessons() throws {
        let directory = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
        let (_, course) = try installed(directory)
        let store = CourseLearningStore(directory: directory, defaults: nil)
        _ = store.transaction { $0.assignRoute(course: course, returningLearner: false); return true }
        for lesson in course.units.last!.lessons {
            let opened = store.transaction { $0.resumePractice(course: course, lessonId: lesson.id, checkpointUnitId: nil) }
            let session = try #require(opened ?? nil)
            #expect(session.cardIds == lesson.cards.map(\.id))
            for card in lesson.cards {
                let exercise = try #require(card.activity?.exercise)
                var initial = CourseExerciseState()
                if card.id == "pf-sp-l01-e01" { initial.usedHelp = true; initial.revision += 1
                    let helpSaved = store.transaction { $0.saveExercise(courseID: course.id, cardID: card.id, exercise: exercise, state: initial) }; #expect(helpSaved == true)
                }
                let steps = correctSteps(exercise, initial: initial)
                for state in steps {
                    let saved = store.transaction { $0.saveExercise(courseID: course.id, cardID: card.id, exercise: exercise, state: state) }; #expect(saved == true)
                }
                let state = try #require(steps.last)
                // Cover interrupted parent grading using the same store contracts.
                if card.id == "pf-sp-l01-e02" {
                    let grade = store.transaction { $0.answerNotificationExercise(course: course, lessonID: lesson.id, cardID: card.id, correct: true, token: "alert", attemptID: state.attemptID) }; #expect(grade == true)
                }
                let grade = store.transaction { $0.answerPractice(course: course, lessonId: lesson.id, checkpointUnitId: nil, sessionId: session.id, cardId: card.id, correct: true, exerciseAttemptID: state.attemptID) }; #expect(grade == true)
                if card.id == lesson.cards.last?.id { #expect(store.snapshot().currentLesson(course: course)?.id == lesson.id) }
                let continued = store.transaction { $0.continueExercise(courseID: course.id, lessonID: lesson.id, checkpointID: nil, sessionID: session.id, cardID: card.id, attemptID: state.attemptID) }; #expect(continued == true)
                let evidence = try #require(store.snapshot().exerciseEvidence[state.attemptID])
                #expect(evidence.assisted == (card.id == "pf-sp-l01-e01"))
                if card.isExposure { #expect(store.snapshot().srsRecord(courseId: course.id, cardId: card.id) == nil) }
                else { #expect(store.snapshot().srsRecord(courseId: course.id, cardId: card.id)?.reviewCount == 1) }
                if exercise.format == "matching" {
                    #expect(evidence.pairEvidence?.count == 1)
                    #expect(evidence.vocabularyIDs == exercise.pairs!.last!.vocabularyIDs && evidence.conceptIDs == exercise.pairs!.last!.conceptIDs)
                }
            }
            let done = store.transaction { $0.finishPractice(course: course, lessonId: lesson.id, checkpointUnitId: nil, sessionId: session.id) != nil }; #expect(done == true)
            #expect(store.snapshot().status(course: course, lessonId: lesson.id) == .completed)
        }
        #expect(store.snapshot().exerciseEvidence.count == 30)
        let relaunched = CourseLearningStore(directory: directory, defaults: nil)
        #expect(relaunched.snapshot().currentLesson(course: course)?.id == "legacy-one")
    }
    @Test("Assessment scoring is frozen, resumable, unhinted, idempotent and separate from studied/SRS history")
    func assessmentScoringAndResume() throws {
        let directory = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
        let (_, course) = try installed(directory)
        for skips in [[], [0, 1], [0, 3]] as [[Int]] {
            var snapshot = CourseLearningSnapshot(); snapshot.assignRoute(course: course, returningLearner: false)
            let opened = snapshot.startAssessment(course: course)
            let attempt = try #require(opened)
            #expect(attempt.formID == "a" && attempt.items.count == 12)
            for (index, item) in attempt.items.enumerated() {
                if !skips.contains(index) {
                    let initial = try #require(snapshot.assessmentAttempts[attempt.id]?.states[item.id])
                    let exercise = try #require(item.card.activity?.exercise)
                    var hinted = initial; hinted.usedHelp = true; hinted.revision += 1
                    let acceptedHint = snapshot.saveAssessmentState(courseID: course.id, assessmentID: attempt.id, itemID: item.id, state: hinted); #expect(!acceptedHint)
                    for state in correctSteps(exercise, initial: initial) {
                        let saved = snapshot.saveAssessmentState(courseID: course.id, assessmentID: attempt.id, itemID: item.id, state: state); #expect(saved)
                        let repeated = snapshot.saveAssessmentState(courseID: course.id, assessmentID: attempt.id, itemID: item.id, state: state); #expect(repeated)
                    }
                }
                let advanced = snapshot.advanceAssessment(courseID: course.id, assessmentID: attempt.id, itemID: item.id, skip: skips.contains(index)); #expect(advanced)
                let repeated = snapshot.advanceAssessment(courseID: course.id, assessmentID: attempt.id, itemID: item.id, skip: skips.contains(index)); #expect(!repeated)
                snapshot = try JSONDecoder().decode(CourseLearningSnapshot.self, from: JSONEncoder().encode(snapshot))
                let resumed = snapshot.startAssessment(course: course)
                #expect(resumed?.id == attempt.id && resumed?.items == attempt.items)
            }
            let final = try #require(snapshot.assessmentAttempts[attempt.id])
            #expect(final.score == 12 - skips.count)
            #expect(final.passed == (skips != [0, 1]))
            if final.passed == true {
                let trail = CourseTrailProjection(course: course, snapshot: snapshot)
                #expect(trail.milestones.filter(\.assessmentAccess).count == 2)
                #expect(trail.milestones.filter(\.assessmentAccess).allSatisfy { !$0.isCurrent && $0.status != .completed })
            }
            #expect(snapshot.progress[course.id] == nil && snapshot.courseSRS[course.id] == nil && snapshot.exerciseEvidence.isEmpty)
            #expect(Set(snapshot.assessmentAccess[course.id] ?? []) == (final.passed == true ? Set(["pf-sp-l01", "pf-sp-l02"]) : Set<String>()))
            #expect(final.remediationLessonIDs.allSatisfy { ["pf-sp-l01", "pf-sp-l02"].contains($0) })
            let retry = snapshot.startAssessment(course: course, retake: true)
            #expect(retry?.formID == "b" && retry?.id != attempt.id)
            #expect(snapshot.assessmentAttempts[attempt.id]?.score == final.score)
            #expect(snapshot.assessmentAttempts.count == 2)
        }
    }
    @Test("Active assessment ignores catalog revision changes, stale writers and notification scoring")
    func frozenAssessmentAndHandoff() throws {
        let directory = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
        let (_, course) = try installed(directory)
        var snapshot = CourseLearningSnapshot()
        let opened = snapshot.startAssessment(course: course)
        let attempt = try #require(opened), item = try #require(attempt.activeItem)
        let original = try #require(attempt.states[item.id]), exercise = try #require(item.card.activity?.exercise)
        var next = original; next.select(exercise.correctChoiceID!, exercise: exercise)
        let first = snapshot.saveAssessmentState(courseID: course.id, assessmentID: attempt.id, itemID: item.id, state: next); #expect(first)
        var stale = original; stale.select(exercise.pictures!.first { $0.id != exercise.correctChoiceID }!.id, exercise: exercise)
        let rejected = snapshot.saveAssessmentState(courseID: course.id, assessmentID: attempt.id, itemID: item.id, state: stale); #expect(!rejected)
        var changed = try JSONSerialization.jsonObject(with: JSONEncoder().encode(course)) as! [String: Any]
        var graph = changed["learning"] as! [String: Any]; var starter = graph["starter"] as! [String: Any]
        starter["revision"] = "pilot-2"; var assessment = starter["assessment"] as! [String: Any]; assessment["revision"] = "pilot-2"; assessment["forms"] = [:]; starter["assessment"] = assessment; graph["starter"] = starter; changed["learning"] = graph
        let updated = try JSONDecoder().decode(CourseDefinition.self, from: JSONSerialization.data(withJSONObject: changed))
        let resumed = snapshot.startAssessment(course: updated, retake: true)
        #expect(resumed?.id == attempt.id && resumed?.blueprint.revision == "pilot-1" && resumed?.items == attempt.items)
        #expect(snapshot.assessmentAttempts[attempt.id]?.states[item.id]?.orderedIDs(exercise.pictures!.map(\.id)) == next.orderedIDs(exercise.pictures!.map(\.id)))
        #expect(CourseHandoff.destination(course: course, snapshot: snapshot).assessmentID == attempt.id)
        #expect(CourseHandoff.destination(course: course, snapshot: snapshot, openPath: true).assessmentID == nil)
        let encoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot)) as! [String: Any]
        #expect(encoded["schemaVersion"] as? Int == 7)
    }
    @Test("New choice, matching and assessment layouts support dark/light and accessibility text")
    func starterLayouts() throws {
        let directory = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
        let (_, course) = try installed(directory)
        let cards = course.units.last!.lessons.flatMap(\.cards).filter { ["pf-sp-l01-e07", "pf-sp-l01-e09", "pf-sp-l02-e03"].contains($0.id) }
        for card in cards { for scheme in [ColorScheme.light, .dark] { for size in [DynamicTypeSize.large, .accessibility3] { for compact in [false, true] {
            let panel = CoursePracticeExercisePanel(card: card, exercise: card.activity!.exercise!, immersive: !compact, checkpoint: false) { _ in }
                .padding(24).frame(width: 390).background(LearnAlertStyle.courseCanvas).environment(\.colorScheme, scheme).environment(\.dynamicTypeSize, size).environment(\.courseNotificationCompact, compact)
            let renderer = ImageRenderer(content: panel); renderer.scale = 1
            let image = try #require(renderer.uiImage)
            #expect(image.size.width == 390 && image.size.height > 200)
            Attachment.record(image, named: "starter-\(card.id)-\(scheme)-\(size)-\(compact ? "notification" : "app")", as: .png)
        } } } }
    }
    @Test("Assessment partial choice and saved Check survive real file-store relaunch without a live catalog")
    func fileBackedAssessmentInterruption() throws {
        let directory = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
        let (_, course) = try installed(directory)
        let app = CourseLearningStore(directory: directory, defaults: nil)
        let opened = app.transaction { $0.startAssessment(course: course) }
        let attempt = try #require(opened ?? nil), item = try #require(attempt.activeItem)
        let exercise = try #require(item.card.activity?.exercise)
        var state = try #require(attempt.states[item.id]); state.select(exercise.correctChoiceID!, exercise: exercise)
        let saved = app.transaction { $0.saveAssessmentState(courseID: course.id, assessmentID: attempt.id, itemID: item.id, state: state) }; #expect(saved == true)
        let relaunched = CourseLearningStore(directory: directory, defaults: nil)
        let resumed = relaunched.transaction { $0.startAssessment(course: baseCourse()) }
        #expect((resumed ?? nil)?.states[item.id] == state)
        #expect((resumed ?? nil)?.blueprint == attempt.blueprint)
        _ = state.submit(exercise)
        let checked = relaunched.transaction { $0.saveAssessmentState(courseID: course.id, assessmentID: attempt.id, itemID: item.id, state: state) }; #expect(checked == true)
        let afterCheck = CourseLearningStore(directory: directory, defaults: nil)
        #expect(afterCheck.snapshot().activeAssessment(courseID: course.id)?.activeItem?.id == item.id)
        #expect(afterCheck.snapshot().activeAssessment(courseID: course.id)?.states[item.id]?.result == true)
        let continued = afterCheck.transaction { $0.advanceAssessment(courseID: course.id, assessmentID: attempt.id, itemID: item.id) }; #expect(continued == true)
        let repeated = afterCheck.transaction { $0.advanceAssessment(courseID: course.id, assessmentID: attempt.id, itemID: item.id) }; #expect(repeated == false)
        #expect(afterCheck.snapshot().activeAssessment(courseID: course.id)?.index == 1)
        #expect(afterCheck.snapshot().exerciseEvidence.isEmpty && afterCheck.snapshot().courseSRS.isEmpty && afterCheck.snapshot().progress.isEmpty)
    }
    @Test("Both reviewed forms grade all 24 items and a failed retake retains earlier access/history")
    func bothFormsAndFailedRetake() throws {
        let directory = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
        let (_, course) = try installed(directory)
        var snapshot = CourseLearningSnapshot(); var completed: [String] = []
        for round in 0..<3 {
            let opened = snapshot.startAssessment(course: course, retake: round > 0)
            let attempt = try #require(opened); completed.append(attempt.id)
            #expect(attempt.formID == (round == 1 ? "b" : "a"))
            for item in attempt.items {
                if round < 2 {
                    for state in correctSteps(item.card.activity!.exercise!, initial: attempt.states[item.id]!) {
                        let saved = snapshot.saveAssessmentState(courseID: course.id, assessmentID: attempt.id, itemID: item.id, state: state); #expect(saved)
                    }
                }
                let advanced = snapshot.advanceAssessment(courseID: course.id, assessmentID: attempt.id, itemID: item.id, skip: round == 2); #expect(advanced)
            }
            #expect(snapshot.assessmentAttempts[attempt.id]?.passed == (round < 2))
            #expect(Set(snapshot.assessmentAccess[course.id] ?? []) == Set(["pf-sp-l01", "pf-sp-l02"]))
        }
        #expect(snapshot.assessmentAttempts.count == 3)
        #expect(snapshot.assessmentAttempts[completed[0]]?.score == 12 && snapshot.assessmentAttempts[completed[1]]?.score == 12 && snapshot.assessmentAttempts[completed[2]]?.score == 0)
        #expect(snapshot.progress.isEmpty && snapshot.courseSRS.isEmpty && snapshot.exerciseEvidence.isEmpty)
    }

    @Test("Manager publishes the full authoritative route, assessment, access and exercise snapshot")
    func managerKeepsVersionedSnapshot() throws {
        let directory = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
        let (_, course) = try installed(directory)
        let store = CourseLearningStore(directory: directory, defaults: nil)
        _ = store.transaction { $0.assignRoute(course: course, returningLearner: false); return true }
        let opened = store.transaction { $0.startAssessment(course: course) }
        let attempt = try #require(opened ?? nil)
        let manager = CourseProgressManager(defaults: nil, learningStore: store, isPreview: true, courseProvider: { id in id == course.id ? course : nil })
        #expect(manager.learningSnapshot.activeAssessment(courseID: course.id)?.id == attempt.id)
        #expect(manager.currentLesson(for: course)?.id == "pf-sp-l01")
        for item in attempt.items {
            for state in correctSteps(item.card.activity!.exercise!, initial: attempt.states[item.id]!) {
                let saved = store.transaction { $0.saveAssessmentState(courseID: course.id, assessmentID: attempt.id, itemID: item.id, state: state) }; #expect(saved == true)
            }
            let advanced = store.transaction { $0.advanceAssessment(courseID: course.id, assessmentID: attempt.id, itemID: item.id) }; #expect(advanced == true)
        }
        manager.reloadFromSharedDefaults()
        #expect(Set(manager.learningSnapshot.assessmentAccess[course.id] ?? []) == Set(["pf-sp-l01", "pf-sp-l02"]))
        #expect(manager.currentLesson(for: course)?.id == "legacy-one")
        let lesson = course.units.last!.lessons[0], card = lesson.cards[0]
        let session = try #require(manager.resumePractice(course: course, lessonId: lesson.id, checkpointUnitId: nil))
        let state = correctSteps(card.activity!.exercise!).last!
        let saved = store.transaction { $0.saveExercise(courseID: course.id, cardID: card.id, exercise: card.activity!.exercise!, state: state) }; #expect(saved == true)
        let recorded = manager.recordPracticeAnswer(course: course, lessonId: lesson.id, checkpointUnitId: nil, sessionId: session.id, cardId: card.id, correct: true, exerciseAttemptID: state.attemptID); #expect(recorded)
        #expect(manager.learningSnapshot.exerciseEvidence[state.attemptID]?.mode == "exposure")
        #expect(manager.learningSnapshot.exerciseDrafts[CourseLearningSnapshot.exerciseKey(courseID: course.id, cardID: card.id)]?.state == state)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        #expect(try encoder.encode(manager.learningSnapshot) == encoder.encode(store.snapshot()))
    }

    private func studyMatchingPrerequisites(_ card: CourseLessonCard, course: CourseDefinition, snapshot: inout CourseLearningSnapshot) throws {
        for id in card.activity?.exercise?.prerequisiteIDs ?? [] {
            let lesson = try #require(course.units.flatMap(\.lessons).first { $0.cards.contains { $0.id == id } })
            let reveal = try #require(lesson.cards.first { $0.id == id })
            #expect(reveal.isExposure)
            let exercise = try #require(reveal.activity?.exercise)
            for state in correctSteps(exercise) {
                let saved = snapshot.saveExercise(courseID: course.id, cardID: id, exercise: exercise, state: state); #expect(saved)
            }
            let recorded = snapshot.answer(course: course, lessonId: lesson.id, cardId: id, correct: true, token: "matching-prerequisite-" + id); #expect(recorded)
            #expect(snapshot.srsRecord(courseId: course.id, cardId: id) == nil)
        }
    }

    @Test("Pair edits cannot promote elimination or replace the first decision")
    func monotonicPairEvidence() throws {
        let directory = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
        let (_, course) = try installed(directory)
        let card = try #require(course.units.last?.lessons.first?.cards.first { $0.id == "pf-sp-l01-e09" })
        let exercise = try #require(card.activity?.exercise)
        let pairs = try #require(exercise.pairs)
        for reversed in [false, true] { for edit in ["none", "first", "second", "both", "clear-before-second", "wrong-then-correct"] { for help in [false, true] {
            let first = pairs[reversed ? 1 : 0], second = pairs[reversed ? 0 : 1]
            var snapshot = CourseLearningSnapshot(), state = CourseExerciseState()
            try studyMatchingPrerequisites(card, course: course, snapshot: &snapshot)
            func write(_ action: (inout CourseExerciseState) -> Void) {
                action(&state)
                let saved = snapshot.saveExercise(courseID: course.id, cardID: card.id, exercise: exercise, state: state); #expect(saved)
            }
            func match(_ left: String, _ right: String) { write { $0.selectPair(left, exercise: exercise) }; write { $0.matchPair(right, exercise: exercise) } }
            if help { write { $0.usedHelp = true; $0.revision += 1 } }
            match(first.id, edit == "wrong-then-correct" ? second.id : first.id)
            if edit == "clear-before-second" { write { $0.clearPair(first.id) } }
            match(second.id, edit == "wrong-then-correct" ? first.id : second.id)
            if edit == "first" { write { $0.clearPair(first.id) }; match(first.id, first.id) }
            if edit == "second" { write { $0.clearPair(second.id) }; match(second.id, second.id) }
            if edit == "both" || edit == "wrong-then-correct" {
                write { $0.clearPair(first.id) }; write { $0.clearPair(second.id) }
                match(second.id, second.id); match(first.id, first.id)
            }
            if edit == "clear-before-second" { match(first.id, first.id) }
            snapshot = try JSONDecoder().decode(CourseLearningSnapshot.self, from: JSONEncoder().encode(snapshot))
            state = try #require(snapshot.exerciseDrafts[CourseLearningSnapshot.exerciseKey(courseID: course.id, cardID: card.id)]?.state)
            write { _ = $0.submit(exercise) }
            let graded = snapshot.answer(course: course, lessonId: "pf-sp-l01", cardId: card.id, correct: true, token: "board", exerciseAttemptID: state.attemptID); #expect(graded)
            let evidence = try #require(snapshot.exerciseEvidence[state.attemptID])
            #expect(evidence.pairEvidence?.map(\.pairID) == [first.id])
            #expect(evidence.pairEvidence?.first?.correct == (edit != "wrong-then-correct"))
            #expect(evidence.vocabularyIDs == (edit == "wrong-then-correct" ? [] : first.vocabularyIDs))
            #expect(evidence.assisted == help)
        } } }
    }
    @Test("Mastery stopping honors the assigned route and deliberate optional starter selection")
    func masteryUsesAssignedRoute() throws {
        let directory = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
        let (_, course) = try installed(directory)
        var snapshot = CourseLearningSnapshot()
        for lesson in baseCourse().units[0].lessons { for index in 0..<3 {
            let saved = snapshot.answer(course: baseCourse(), lessonId: lesson.id, cardId: lesson.cards[0].id, correct: true, token: lesson.id + String(index)); #expect(saved)
        } }
        #expect(snapshot.isFullyMastered(course: baseCourse()))
        snapshot.assignRoute(course: course, returningLearner: true)
        #expect(snapshot.currentLesson(course: course) == nil)
        #expect(snapshot.batch(course: course, count: 10).isEmpty)
        #expect(snapshot.isFullyMastered(course: course))
        #expect(CourseNotificationScheduler.shouldStopWhenMastered(course: course, snapshot: snapshot, enabled: true))
        #expect(!CourseNotificationScheduler.shouldStopWhenMastered(course: course, snapshot: snapshot, enabled: false))
        snapshot.selectStarter(course: course, selected: true)
        #expect(!snapshot.isFullyMastered(course: course))
        #expect(!CourseNotificationScheduler.shouldStopWhenMastered(course: course, snapshot: snapshot, enabled: true))
        snapshot.selectStarter(course: course, selected: false)
        #expect(snapshot.isFullyMastered(course: course))
        #expect(CourseNotificationScheduler.shouldStopWhenMastered(course: course, snapshot: snapshot, enabled: true))
        #expect(!CourseNotificationScheduler.shouldStopWhenMastered(course: course, snapshot: snapshot, enabled: false))
        #expect(snapshot.progress[course.id]?["pf-sp-l01"] == nil && snapshot.courseSRS[course.id]?["pf-sp-l01-e01"] == nil)
        var fresh = snapshot; fresh.routes.removeAll(); fresh.assignRoute(course: course, returningLearner: false)
        fresh.assessmentAccess[course.id] = ["pf-sp-l01", "pf-sp-l02"]
        #expect(!fresh.isFullyMastered(course: course))
    }

    @Test("Matching first-response history survives stale hosts, help, retirement and legacy decode")
    func matchingHostHistory() throws {
        let directory = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
        let (_, course) = try installed(directory)
        let card = try #require(course.units.last?.lessons.first?.cards.first { $0.id == "pf-sp-l01-e09" })
        let exercise = try #require(card.activity?.exercise), pairs = try #require(exercise.pairs)
        var snapshot = CourseLearningSnapshot(), state = CourseExerciseState()
        try studyMatchingPrerequisites(card, course: course, snapshot: &snapshot)
        func write(_ action: (inout CourseExerciseState) -> Void) { action(&state); let ok = snapshot.saveExercise(courseID: course.id, cardID: card.id, exercise: exercise, state: state); #expect(ok) }
        write { $0.selectPair(pairs[0].id, exercise: exercise) }; write { $0.matchPair(pairs[0].id, exercise: exercise) }
        var stale = state
        write { $0.usedHelp = true; $0.revision += 1 }
        stale.selectPair(pairs[1].id, exercise: exercise)
        let staleRejected = snapshot.saveExercise(courseID: course.id, cardID: card.id, exercise: exercise, state: stale); #expect(!staleRejected)
        for attack in 0..<3 {
            var altered = state; altered.revision += 1
            if attack == 0 { altered.usedHelp = false }
            if attack == 1 { altered.pairDecisions = [:] }
            if attack == 2 { altered.pairDecisions?[pairs[0].id]?.firstRightID = pairs[1].id }
            let rejected = snapshot.saveExercise(courseID: course.id, cardID: card.id, exercise: exercise, state: altered); #expect(!rejected)
        }
        snapshot = try JSONDecoder().decode(CourseLearningSnapshot.self, from: JSONEncoder().encode(snapshot))
        state = try #require(snapshot.exerciseDrafts[CourseLearningSnapshot.exerciseKey(courseID: course.id, cardID: card.id)]?.state)
        write { $0.selectPair(pairs[1].id, exercise: exercise) }; write { $0.matchPair(pairs[1].id, exercise: exercise) }
        var promoted = state; promoted.pairDecisions?[pairs[1].id]?.independent = true; promoted.revision += 1
        let rejected = snapshot.saveExercise(courseID: course.id, cardID: card.id, exercise: exercise, state: promoted); #expect(!rejected)
        write { _ = $0.submit(exercise) }
        let graded = snapshot.answer(course: course, lessonId: "pf-sp-l01", cardId: card.id, correct: true, token: "original", exerciseAttemptID: state.attemptID); #expect(graded)
        let original = try #require(snapshot.exerciseEvidence[state.attemptID]); #expect(original.assisted && original.pairEvidence?.first?.assisted == true)
        let cleared = snapshot.acknowledgeExercise(courseID: course.id, cardID: card.id, attemptID: state.attemptID); #expect(cleared)
        var replay = CourseExerciseState(); replay.attemptID = state.attemptID; replay.selectPair(pairs[0].id, exercise: exercise)
        let replayRejected = snapshot.saveExercise(courseID: course.id, cardID: card.id, exercise: exercise, state: replay); #expect(!replayRejected)
        var retry = CourseExerciseState(); retry.selectPair(pairs[1].id, exercise: exercise)
        let newAttempt = snapshot.saveExercise(courseID: course.id, cardID: card.id, exercise: exercise, state: retry); #expect(newAttempt)
        #expect(snapshot.exerciseEvidence[state.attemptID]?.pairEvidence?.first?.pairID == pairs[0].id)
        // An old draft has no trustworthy choice-time history. It remains playable
        // but can never retroactively claim independent matching evidence.
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as! [String: Any]
        json.removeValue(forKey: "pairDecisions"); json.removeValue(forKey: "result")
        var legacy = try JSONDecoder().decode(CourseExerciseState.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(legacy.pairDecisions == nil)
        legacy.clearPair(pairs[0].id); legacy.selectPair(pairs[0].id, exercise: exercise); legacy.matchPair(pairs[0].id, exercise: exercise)
        #expect(legacy.pairDecisions == nil)
        let encoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot)) as! [String: Any]
        #expect(encoded["schemaVersion"] as? Int == 7)
    }

    private func expandedTestRoute(_ course: CourseDefinition) throws -> CourseDefinition {
        var root = try JSONSerialization.jsonObject(with: JSONEncoder().encode(course)) as! [String: Any]
        var units = root["units"] as! [[String: Any]], unit = units.removeLast(), lessons = unit["lessons"] as! [[String: Any]]
        let reveal = (lessons[0]["cards"] as! [[String: Any]]).first { (($0["activity"] as? [String: Any])?["exercise"] as? [String: Any])?["format"] as? String == "exposure" }!
        var card = (lessons[0]["cards"] as! [[String: Any]]).first { (($0["activity"] as? [String: Any])?["exercise"] as? [String: Any])?["format"] as? String == "pictureChoice" }!
        card["id"] = "test-only-l03-practice"
        var activity = card["activity"] as! [String: Any], exercise = activity["exercise"] as! [String: Any]
        let quantityReveal = (lessons[1]["cards"] as! [[String: Any]]).first { (($0["activity"] as? [String: Any])?["exercise"] as? [String: Any])?["format"] as? String == "exposure" }!
        exercise["prerequisiteIDs"] = [reveal["id"] as! String, quantityReveal["id"] as! String]; activity["exercise"] = exercise; card["activity"] = activity
        var next = lessons[0]; next["id"] = "pf-sp-l03"; next["title"] = "Synthetic next-lesson contract fixture"; next["lessonNumber"] = 3; next["cards"] = [card]; lessons.append(next)
        unit["lessons"] = lessons; units.append(unit); root["units"] = units
        var graph = root["learning"] as! [String: Any], starter = graph["starter"] as! [String: Any]
        starter["revision"] = "test-route-2"; starter["lessonIDs"] = ["pf-sp-l01", "pf-sp-l02", "pf-sp-l03"]; graph["starter"] = starter; root["learning"] = graph
        return try JSONDecoder().decode(CourseDefinition.self, from: JSONSerialization.data(withJSONObject: root))
    }
    @Test("Pinned route expansion preserves pending Continue, access and original accounting")
    func deliberateRouteRevision() throws {
        let directory = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
        let (_, oldCourse) = try installed(directory), expanded = try expandedTestRoute(oldCourse)
        var snapshot = CourseLearningSnapshot(); snapshot.assignRoute(course: oldCourse, returningLearner: true)
        let opened = snapshot.resumePractice(course: oldCourse, lessonId: "legacy-one", checkpointUnitId: nil)
        let session = try #require(opened)
        let fraction = snapshot.completionFraction(course: oldCourse), ids = snapshot.routes[oldCourse.id]?.lessonIDs
        #expect(snapshot.assignedStarterLessonIDs(course: expanded) == ["pf-sp-l01", "pf-sp-l02"])
        #expect(snapshot.currentLesson(course: expanded)?.id == "legacy-one")
        #expect(snapshot.status(course: expanded, lessonId: "pf-sp-l03") == .locked)
        let adopted = snapshot.adoptStarterRevision(course: expanded); #expect(adopted)
        #expect(snapshot.currentLesson(course: expanded)?.id == "legacy-one")
        #expect(snapshot.routes[oldCourse.id]?.lessonIDs == ids && snapshot.completionFraction(course: expanded) == fraction)
        #expect(snapshot.practiceSessions["spanish-course:lesson:legacy-one"]?.id == session.id)
        snapshot = try JSONDecoder().decode(CourseLearningSnapshot.self, from: JSONEncoder().encode(snapshot))
        #expect(snapshot.assignedStarterLessonIDs(course: expanded).count == 3)
        let repeated = snapshot.adoptStarterRevision(course: expanded); #expect(!repeated)
    }
    @Test("L01-L02 test-out unlocks eligible L03 without inventing study/SRS or bypassing unrelated prerequisites")
    func scopedAssessmentPrerequisites() throws {
        let directory = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
        let (_, oldCourse) = try installed(directory), course = try expandedTestRoute(oldCourse)
        var snapshot = CourseLearningSnapshot(); snapshot.assignRoute(course: course, returningLearner: false)
        let opened = snapshot.startAssessment(course: course)
        let attempt = try #require(opened)
        for item in attempt.items {
            let initial = try #require(snapshot.assessmentAttempts[attempt.id]?.states[item.id])
            for state in correctSteps(try #require(item.card.activity?.exercise), initial: initial) {
                let saved = snapshot.saveAssessmentState(courseID: course.id, assessmentID: attempt.id, itemID: item.id, state: state); #expect(saved)
            }
            let advanced = snapshot.advanceAssessment(courseID: course.id, assessmentID: attempt.id, itemID: item.id); #expect(advanced)
        }
        snapshot = try JSONDecoder().decode(CourseLearningSnapshot.self, from: JSONEncoder().encode(snapshot))
        #expect(snapshot.assessmentAttempts[attempt.id]?.passed == true)
        #expect(Set(snapshot.assessmentAccess[course.id] ?? []) == Set(["pf-sp-l01", "pf-sp-l02"]))
        #expect(snapshot.progress.isEmpty && snapshot.courseSRS.isEmpty && snapshot.exerciseEvidence.isEmpty)
        #expect(!snapshot.isFullyMastered(course: course))
        #expect(snapshot.currentLesson(course: course)?.id == "pf-sp-l03")
        let card = try #require(course.units.last?.lessons.last?.cards.first)
        #expect(snapshot.satisfiesPrerequisites(card: card, course: course))
        #expect(snapshot.batch(course: course, count: 20).contains { $0.id == card.id })
        #expect(CourseNotificationProgress.nextLearningCard(course: course, snapshot: snapshot, excluding: [])?.id == card.id)
        let exercise = try #require(card.activity?.exercise)
        let operationResult1 = snapshot.resumePractice(course: course, lessonId: "pf-sp-l03", checkpointUnitId: nil)
        let appSession = try #require(operationResult1)
        #expect(snapshot.canPresentPracticeCard(course: course, lessonId: "pf-sp-l03", checkpointUnitId: nil, sessionId: appSession.id, cardId: card.id))
        for state in correctSteps(exercise) { let saved = snapshot.saveExercise(courseID: course.id, cardID: card.id, exercise: exercise, state: state); #expect(saved) }
        let identity = try #require(snapshot.exerciseDrafts[CourseLearningSnapshot.exerciseKey(courseID: course.id, cardID: card.id)]?.state.attemptID)
        let graded = snapshot.answerPractice(course: course, lessonId: "pf-sp-l03", checkpointUnitId: nil, sessionId: appSession.id, cardId: card.id, correct: true, exerciseAttemptID: identity); #expect(graded)
        #expect(CourseNotificationProgress.practiceCards(course: course, snapshot: snapshot).contains { $0.id == card.id })
        #expect(snapshot.progress[course.id]?["pf-sp-l01"] == nil && snapshot.courseSRS[course.id]?["pf-sp-l01-e01"] == nil)
        var changed = try JSONSerialization.jsonObject(with: JSONEncoder().encode(course)) as! [String: Any]
        var units = changed["units"] as! [[String: Any]], unit = units.removeLast(), lessons = unit["lessons"] as! [[String: Any]], first = lessons[0], cards = first["cards"] as! [[String: Any]]
        let reference = exercise.prerequisiteIDs!.first!, index = cards.firstIndex { $0["id"] as? String == reference }!
        cards[index]["question"] = "Changed teaching definition"; first["cards"] = cards; lessons[0] = first; unit["lessons"] = lessons; units.append(unit); changed["units"] = units
        let cosmeticCourse = try JSONDecoder().decode(CourseDefinition.self, from: JSONSerialization.data(withJSONObject: changed))
        #expect(snapshot.satisfiesPrerequisites(card: card, course: cosmeticCourse))
        var changedActivity = cards[index]["activity"] as! [String: Any], changedExercise = changedActivity["exercise"] as! [String: Any]
        changedExercise["conceptIDs"] = ["test-only-new-objective"]; changedActivity["exercise"] = changedExercise; cards[index]["activity"] = changedActivity
        first["cards"] = cards; lessons[0] = first; unit["lessons"] = lessons; units[units.count - 1] = unit; changed["units"] = units
        let changedCourse = try JSONDecoder().decode(CourseDefinition.self, from: JSONSerialization.data(withJSONObject: changed))
        #expect(!snapshot.satisfiesPrerequisites(card: card, course: changedCourse))
        var outsideJSON = try JSONSerialization.jsonObject(with: JSONEncoder().encode(card)) as! [String: Any]
        var outsideActivity = outsideJSON["activity"] as! [String: Any], outsideExercise = outsideActivity["exercise"] as! [String: Any]
        outsideExercise["prerequisiteIDs"] = [baseCourse().units[0].lessons[0].cards[0].id]; outsideActivity["exercise"] = outsideExercise; outsideJSON["activity"] = outsideActivity
        let outside = try JSONDecoder().decode(CourseLessonCard.self, from: JSONSerialization.data(withJSONObject: outsideJSON))
        #expect(!snapshot.satisfiesPrerequisites(card: outside, course: course))
        #expect(CourseDeliveryContracts.notificationIsCompatible(profile: "practice-v1", contracts: Array(CourseDeliveryContracts.supported)))
        #expect(!CourseDeliveryContracts.notificationIsCompatible(profile: "practice-v1", contracts: ["exercise-v1"]))
        #expect(!CourseDeliveryContracts.notificationIsCompatible(profile: "future", contracts: []))
    }

    @Test("App sessions retain blocked work without presenting or crediting it, then resume after the real prerequisite")
    func appPrerequisiteParity() throws {
        let directory = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
        let (_, oldCourse) = try installed(directory), expanded = try expandedTestRoute(oldCourse)
        var root = try JSONSerialization.jsonObject(with: JSONEncoder().encode(expanded)) as! [String: Any]
        var units = root["units"] as! [[String: Any]], unit = units.removeLast(), lessons = unit["lessons"] as! [[String: Any]], lesson = lessons.removeLast(), cards = lesson["cards"] as! [[String: Any]]
        var cardJSON = cards[0], activity = cardJSON["activity"] as! [String: Any], exerciseJSON = activity["exercise"] as! [String: Any]
        exerciseJSON["prerequisiteIDs"] = ["old-one"]; activity["exercise"] = exerciseJSON; cardJSON["activity"] = activity; cards[0] = cardJSON
        lesson["cards"] = cards; lessons.append(lesson); unit["lessons"] = lessons; units.append(unit); root["units"] = units
        let course = try JSONDecoder().decode(CourseDefinition.self, from: JSONSerialization.data(withJSONObject: root))
        var snapshot = CourseLearningSnapshot(); snapshot.assignRoute(course: course, returningLearner: false)
        let operationResult2 = snapshot.startAssessment(course: course)
        let attempt = try #require(operationResult2)
        for item in attempt.items {
            let initial = try #require(snapshot.assessmentAttempts[attempt.id]?.states[item.id])
            for state in correctSteps(try #require(item.card.activity?.exercise), initial: initial) { let operationResult3 = snapshot.saveAssessmentState(courseID: course.id, assessmentID: attempt.id, itemID: item.id, state: state); #expect(operationResult3) }
            let operationResult4 = snapshot.advanceAssessment(courseID: course.id, assessmentID: attempt.id, itemID: item.id); #expect(operationResult4)
        }
        let card = try #require(course.units.last?.lessons.last?.cards.first), exercise = try #require(card.activity?.exercise)
        let operationResult5 = snapshot.resumePractice(course: course, lessonId: "pf-sp-l03", checkpointUnitId: nil)
        let session = try #require(operationResult5)
        #expect(session.cardIds.contains(card.id)) // keep the full plan; blocked is never completed
        #expect(!snapshot.canPresentPracticeCard(course: course, lessonId: "pf-sp-l03", checkpointUnitId: nil, sessionId: session.id, cardId: card.id))
        #expect(!snapshot.batch(course: course, count: 20).contains { $0.id == card.id })
        for state in correctSteps(exercise) { let operationResult6 = snapshot.saveExercise(courseID: course.id, cardID: card.id, exercise: exercise, state: state); #expect(operationResult6) }
        let identity = try #require(snapshot.exerciseDrafts[CourseLearningSnapshot.exerciseKey(courseID: course.id, cardID: card.id)]?.state.attemptID)
        let operationResult7 = !snapshot.answerPractice(course: course, lessonId: "pf-sp-l03", checkpointUnitId: nil, sessionId: session.id, cardId: card.id, correct: true, exerciseAttemptID: identity); #expect(operationResult7)
        let operationResult8 = !snapshot.answer(course: course, lessonId: "pf-sp-l03", cardId: card.id, correct: true, token: "stale", exerciseAttemptID: identity); #expect(operationResult8)
        #expect(snapshot.courseSRS[course.id]?[card.id] == nil && snapshot.exerciseEvidence[identity] == nil)
        let operationResult9 = snapshot.finishPractice(course: course, lessonId: "pf-sp-l03", checkpointUnitId: nil, sessionId: session.id) == nil; #expect(operationResult9)
        snapshot = try JSONDecoder().decode(CourseLearningSnapshot.self, from: JSONEncoder().encode(snapshot))
        let operationResult10 = snapshot.resumePractice(course: course, lessonId: "pf-sp-l03", checkpointUnitId: nil)
        let resumed = try #require(operationResult10); #expect(resumed.id == session.id && resumed.answers.isEmpty)
        // The unrelated earlier lesson is genuinely studied, not assessment-fabricated.
        let operationResult11 = snapshot.answer(course: course, lessonId: "legacy-one", cardId: "old-one", correct: true, token: "actual-earlier-study"); #expect(operationResult11)
        #expect(snapshot.canPresentPracticeCard(course: course, lessonId: "pf-sp-l03", checkpointUnitId: nil, sessionId: session.id, cardId: card.id))
        let operationResult12 = snapshot.answerPractice(course: course, lessonId: "pf-sp-l03", checkpointUnitId: nil, sessionId: session.id, cardId: card.id, correct: true, exerciseAttemptID: identity); #expect(operationResult12)
        #expect(snapshot.courseSRS[course.id]?[card.id] != nil)
    }

}
