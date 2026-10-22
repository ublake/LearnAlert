import Foundation
import SwiftUI
import CryptoKit
import Testing
@testable import LearnAlert

@MainActor
@Suite("Six-lesson managed starter and finite café")
struct CourseCafeTests {
    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("cafe-test-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true); return url
    }
    private func course(_ directory: URL, resourceName: String = "visual-cafe-pilot") throws -> CourseDefinition {
        let base = CourseDefinition(id: "spanish-course", title: "Spanish (SP)", language: "Spanish", flagEmoji: "🇪🇸", levelTag: "Beginner", colorHex: "#E05A47", summary: "Test", estimatedHours: 1, outcomes: [], units: [
            .init(id: "legacy", unitNumber: 1, title: "Legacy", subtitle: "", colorHex: "#123456", badgeIcon: "book", lessons: [
                .init(id: "legacy-one", lessonNumber: 1, title: "Legacy", subtitle: "", cards: [.init(id: "legacy-card", question: "Legacy", correctAnswer: "Legacy", cardType: "vocabulary")])
            ])
        ])
        let store = ManagedCatalogStore(directory: directory, defaults: nil, developmentPreview: true, profile: resourceName == "visual-cafe-pilot" ? "practice-v2" : "legacy-v1")
        let resource = try #require(Bundle.main.url(forResource: resourceName, withExtension: "json"))
        try store.installStarterPreview(baseCourse: base, componentData: Data(contentsOf: resource))
        return try #require(store.course(for: base.id))
    }
    private func correctSteps(_ exercise: CourseExercise, initial: CourseExerciseState? = nil) throws -> [CourseExerciseState] {
        var state = initial ?? CourseExerciseState(), states: [CourseExerciseState] = []
        switch exercise.format {
        case "choice", "pictureChoice": state.select(try #require(exercise.correctChoiceID), exercise: exercise); states.append(state)
        case "wordBank":
            for text in try #require(exercise.acceptedOrders?.first) {
                let tile = try #require(exercise.tiles?.first { $0.text == text && !state.selectedIDs.contains($0.id) })
                state.append(tile.id, exercise: exercise); states.append(state)
            }
        case "matching", "textMatching":
            for pair in try #require(exercise.pairs) {
                state.selectPair(pair.id, exercise: exercise); states.append(state)
                state.matchPair(pair.id, exercise: exercise); states.append(state)
            }
        default: break
        }
        _ = state.submit(exercise); states.append(state); return states
    }
    @discardableResult private func check(_ card: CourseLessonCard, course: CourseDefinition, snapshot: inout CourseLearningSnapshot) throws -> String {
        let exercise = try #require(card.activity?.exercise)
        let saved = snapshot.exerciseDrafts[CourseLearningSnapshot.exerciseKey(courseID: course.id, cardID: card.id)]?.state ?? CourseExerciseState()
        for state in try correctSteps(exercise, initial: saved) {
            let accepted = snapshot.saveExercise(courseID: course.id, cardID: card.id, exercise: exercise, state: state); #expect(accepted)
        }
        return try #require(snapshot.exerciseDrafts[CourseLearningSnapshot.exerciseKey(courseID: course.id, cardID: card.id)]?.state.attemptID)
    }
    private func study(_ id: String, course: CourseDefinition, snapshot: inout CourseLearningSnapshot) throws {
        let opened = snapshot.resumePractice(course: course, lessonId: id, checkpointUnitId: nil)
        let session = try #require(opened)
        for _ in 0..<100 {
            let resumed = snapshot.resumePractice(course: course, lessonId: id, checkpointUnitId: nil)
            let current = try #require(resumed)
            if let pending = current.pendingContinueCardID {
                let acknowledged = snapshot.continueExercise(courseID: course.id, lessonID: id, checkpointID: nil, sessionID: session.id, cardID: pending, attemptID: current.pendingContinueAttemptID); #expect(acknowledged); continue
            }
            guard let next = current.nextIndex else {
                let finished = snapshot.finishPractice(course: course, lessonId: id, checkpointUnitId: nil, sessionId: session.id); #expect(finished != nil); return
            }
            let card = try #require(course.units.flatMap(\.lessons).first { $0.id == id }?.cards.first { $0.id == current.cardIds[next] })
            #expect(snapshot.canPresentPracticeCard(course: course, lessonId: id, checkpointUnitId: nil, sessionId: session.id, cardId: card.id))
            let identity = try check(card, course: course, snapshot: &snapshot)
            let recorded = snapshot.answerPractice(course: course, lessonId: id, checkpointUnitId: nil, sessionId: session.id, cardId: card.id, correct: true, exerciseAttemptID: identity); #expect(recorded)
        }
        Issue.record("Practice did not reach its existing completion boundary")
    }
    private func prepared(_ course: CourseDefinition) throws -> CourseLearningSnapshot {
        var snapshot = CourseLearningSnapshot(); snapshot.assignRoute(course: course, returningLearner: false)
        for id in course.learning!.starter!.lessonIDs.prefix(5) { try study(id, course: course, snapshot: &snapshot) }
        return snapshot
    }
    @Test("Exactly59 additions retain old IDs, no audio activation and a readable89-record route")
    func mappedContent() throws {
        let dir = try directory(); defer { try? FileManager.default.removeItem(at: dir) }; let course = try course(dir)
        let lessons = try #require(course.units.last?.lessons)
        #expect(lessons.count == 6 && lessons.flatMap(\.cards).count == 89)
        #expect(lessons.suffix(4).flatMap(\.cards).filter { $0.isExposure }.count == 21)
        #expect(lessons.suffix(4).flatMap(\.cards).filter { !$0.isExposure }.count == 38)
        #expect(course.learning?.starter?.assessment.lessonIDs == ["pf-sp-l01", "pf-sp-l02"])
        var seen = Set<String>()
        for lesson in lessons { for card in lesson.cards {
            let ex = try #require(card.activity?.exercise)
            #expect(Set(ex.prerequisiteIDs ?? []).isSubset(of: seen)); seen.insert(card.id)
            #expect(ex.context?.audioReference == nil)
            #expect(Set(ex.vocabularyIDs).isSubset(of: Set(course.learning!.vocabulary.keys)))
            #expect(Set(ex.conceptIDs).isSubset(of: Set(course.learning!.concepts.keys)))
        } }
        for name in ["cafe", "leche", "bocadillo"] {
            let image = try #require(CourseVocabularyImages.image(named: "sp-\(name)-transparent.png")?.cgImage)
            #expect(image.width == 1254 && image.height == 1254 && image.alphaInfo != .none && image.alphaInfo != .noneSkipFirst && image.alphaInfo != .noneSkipLast)
        }
        #expect(CoursePrivatePreviewAudio.files.count == 6)
        for file in CoursePrivatePreviewAudio.files.values { #expect(Bundle.main.url(forResource: URL(fileURLWithPath: file).deletingPathExtension().lastPathComponent, withExtension: "mp3") == nil) }
    }
    @Test("All five preparation lessons run through actual managed sessions without keyboard or deadlocks")
    func completePreparation() throws {
        let dir = try directory(); defer { try? FileManager.default.removeItem(at: dir) }; let course = try course(dir), snapshot = try prepared(course)
        #expect(snapshot.currentLesson(course: course)?.id == "pf-sp-l06")
        for id in course.learning!.starter!.lessonIDs.prefix(5) { #expect(snapshot.status(course: course, lessonId: id) == .completed) }
        for card in course.units.last!.lessons.flatMap(\.cards).filter(\.isExposure) { #expect(snapshot.srsRecord(courseId: course.id, cardId: card.id) == nil) }
    }
    @Test("Text matching preserves first pair, help and forced-pair provenance through edits and reload")
    func textMatchingProvenance() throws {
        let dir = try directory(); defer { try? FileManager.default.removeItem(at: dir) }; let course = try course(dir)
        let exercise = try #require(course.units.last!.lessons[3].cards.first { $0.id == "pf-sp-l04-e03" }?.activity?.exercise), pairs = try #require(exercise.pairs)
        var state = CourseExerciseState(); state.selectPair(pairs[0].id, exercise: exercise); state.matchPair(pairs[0].id, exercise: exercise)
        state.selectPair(pairs[1].id, exercise: exercise); state.matchPair(pairs[1].id, exercise: exercise)
        state.clearPair(pairs[1].id); state.selectPair(pairs[1].id, exercise: exercise); state.matchPair(pairs[1].id, exercise: exercise)
        state = try JSONDecoder().decode(CourseExerciseState.self, from: JSONEncoder().encode(state))
        #expect(state.pairDecisions?[pairs[0].id]?.independent == true && state.pairDecisions?[pairs[1].id]?.independent == false)
        var forged = state; forged.pairDecisions?[pairs[1].id]?.independent = true; #expect(!forged.preservesEvidence(from: state, exercise: exercise))
        _ = state.submit(exercise); #expect(state.result == true)
    }
    @Test("Valid goal alternatives stay open, retain the first response and do not count as language errors")
    func goalMismatchEvidence() throws {
        let dir = try directory(); defer { try? FileManager.default.removeItem(at: dir) }; let course = try course(dir)
        let card = try #require(course.units.last!.lessons[3].cards.first { $0.id == "pf-sp-l04-e06" }), ex = try #require(card.activity?.exercise), alternate = try #require(ex.context?.goalMismatchChoiceIDs?.first)
        var snapshot = CourseLearningSnapshot(), state = CourseExerciseState()
        state.select(alternate, exercise: ex); let selected = snapshot.saveExercise(courseID: course.id, cardID: card.id, exercise: ex, state: state); #expect(selected)
        _ = state.submit(ex); let mismatch = snapshot.saveExercise(courseID: course.id, cardID: card.id, exercise: ex, state: state); #expect(mismatch)
        #expect(state.result == nil && state.outcome == "goalMismatch" && state.firstResponse?.choiceID == alternate && state.usedHelp)
        #expect(snapshot.progress.isEmpty && snapshot.exerciseEvidence.isEmpty && snapshot.courseSRS.isEmpty)
        let first = state.firstResponse
        state = try JSONDecoder().decode(CourseExerciseState.self, from: JSONEncoder().encode(state))
        for next in try correctSteps(ex, initial: state) { let saved = snapshot.saveExercise(courseID: course.id, cardID: card.id, exercise: ex, state: next); #expect(saved); state = next }
        #expect(state.result == true && state.firstResponse == first)
        var forgottenHelp = state; forgottenHelp.assistanceKinds = []; #expect(!forgottenHelp.preservesEvidence(from: state, exercise: ex))

        var forged = state; forged.firstResponse = .init(outcome: "correct", choiceID: ex.correctChoiceID, selectedIDs: []); #expect(!forged.preservesEvidence(from: state, exercise: ex))
    }
    @Test("Finite café saves every amount/handover boundary and duplicate delivery is single-credit")
    func interruptedVisit() throws {
        let dir = try directory(); defer { try? FileManager.default.removeItem(at: dir) }; let course = try course(dir)
        var snapshot = try prepared(course)
        let opened = snapshot.resumePractice(course: course, lessonId: "pf-sp-l06", checkpointUnitId: nil), session = try #require(opened)
        for (index, card) in course.units.last!.lessons.last!.cards.prefix(7).enumerated() {
            let identity = try check(card, course: course, snapshot: &snapshot)
            let rejectedNotification = snapshot.answerNotificationExercise(course: course, lessonID: "pf-sp-l06", cardID: card.id, correct: true, token: "notification", attemptID: identity); #expect(!rejectedNotification)
            let rejectedDirect = snapshot.answer(course: course, lessonId: "pf-sp-l06", cardId: card.id, correct: true, token: "outside-visit", exerciseAttemptID: identity); #expect(!rejectedDirect)
            let recorded = snapshot.answerPractice(course: course, lessonId: "pf-sp-l06", checkpointUnitId: nil, sessionId: session.id, cardId: card.id, correct: true, exerciseAttemptID: identity); #expect(recorded)
            let evidenceCount = snapshot.exerciseEvidence.count, counters = snapshot.progress[course.id]?["pf-sp-l06"]?.totalAttemptsCount
            let repeated = snapshot.answerPractice(course: course, lessonId: "pf-sp-l06", checkpointUnitId: nil, sessionId: session.id, cardId: card.id, correct: true, exerciseAttemptID: identity); #expect(repeated)
            #expect(snapshot.exerciseEvidence.count == evidenceCount && snapshot.progress[course.id]?["pf-sp-l06"]?.totalAttemptsCount == counters)
            snapshot = try JSONDecoder().decode(CourseLearningSnapshot.self, from: JSONEncoder().encode(snapshot))
            let reopened = snapshot.resumePractice(course: course, lessonId: "pf-sp-l06", checkpointUnitId: nil); #expect(reopened?.pendingContinueAttemptID == identity)
            let visit = try #require(snapshot.dialogueAttempt(courseID: course.id, lessonID: "pf-sp-l06", sessionID: session.id))
            #expect(visit.stepIndex == index + 1)
            #expect(snapshot.srsRecord(courseId: course.id, cardId: card.id) == nil)
            if index == 4 { #expect(visit.order["amount"] == "2" && visit.order["payment"] == nil && visit.currentStep?.substep == "handover") }
            if index == 5 { #expect(visit.order["payment"] == "handed_over" && visit.completedAt == nil) }
            let continued = snapshot.continueExercise(courseID: course.id, lessonID: "pf-sp-l06", checkpointID: nil, sessionID: session.id, cardID: card.id, attemptID: identity); #expect(continued)
            let duplicate = snapshot.continueExercise(courseID: course.id, lessonID: "pf-sp-l06", checkpointID: nil, sessionID: session.id, cardID: card.id, attemptID: identity); #expect(duplicate)
        }
        let visit = try #require(snapshot.dialogueAttempt(courseID: course.id, lessonID: "pf-sp-l06", sessionID: session.id)); #expect(visit.completedAt != nil && visit.order["milk"] == "with_milk" && visit.order["service"] == "here")
        let frozenOrder = visit.order, completedAt = visit.completedAt
        try study("pf-sp-l06", course: course, snapshot: &snapshot)
        #expect(snapshot.dialogueAttempts[visit.id]?.order == frozenOrder && snapshot.dialogueAttempts[visit.id]?.completedAt == completedAt)
        #expect(snapshot.status(course: course, lessonId: "pf-sp-l06") == .completed)
        var reviewed = snapshot
        let legacyStudied = reviewed.answer(course: course, lessonId: "legacy-one", cardId: "legacy-card", correct: true, token: "mastery-fixture-legacy"); #expect(legacyStudied)
        for lesson in course.units.flatMap(\.lessons) { for card in lesson.cards where !card.isExposure && card.activity?.exercise?.isAppOnlyDialogue != true {
            var record = reviewed.srsRecord(courseId: course.id, cardId: card.id) ?? CourseCardSRSRecord(cardId: card.id)
            record.masteryScore = 3; record.nextReviewDate = .distantFuture
            reviewed.courseSRS[course.id, default: [:]][card.id] = record
        } }
        #expect(reviewed.isFullyMastered(course: course))
        #expect(reviewed.batch(course: course, count: 200, reviewOnly: true).isEmpty)

    }
    @Test("A visit freezes its definition and cards across presentation revisions without resetting Continue")
    func frozenContentAndSchema() throws {
        let dir = try directory(); defer { try? FileManager.default.removeItem(at: dir) }; let original = try course(dir)
        var snapshot = try prepared(original); let opened = snapshot.resumePractice(course: original, lessonId: "pf-sp-l06", checkpointUnitId: nil), session = try #require(opened)
        let before = try #require(snapshot.dialogueAttempt(courseID: original.id, lessonID: "pf-sp-l06", sessionID: session.id))
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as! [String: Any], graph = json["learning"] as! [String: Any], definitions = graph["dialogues"] as! [String: Any], definition = definitions[before.definition.id] as! [String: Any]
        definition["title"] = "Updated title"; definition["revision"] = "presentation-2"; definitions[before.definition.id] = definition; graph["dialogues"] = definitions; json["learning"] = graph
        let changed = try JSONDecoder().decode(CourseDefinition.self, from: JSONSerialization.data(withJSONObject: json)), resumed = snapshot.resumePractice(course: changed, lessonId: "pf-sp-l06", checkpointUnitId: nil)
        #expect(resumed?.id == session.id && snapshot.dialogueAttempt(courseID: original.id, lessonID: "pf-sp-l06", sessionID: session.id)?.definition == before.definition)
        let data = try JSONEncoder().encode(snapshot), reloaded = try JSONDecoder().decode(CourseLearningSnapshot.self, from: data); #expect(reloaded.schemaVersion == 7 && reloaded.dialogueAttempts[before.id]?.cards == before.cards)
        #expect(throws: (any Error).self) { try JSONDecoder().decode(CourseLearningSnapshot.self, from: Data("{\"schemaVersion\":8}".utf8)) }
        var old = try JSONSerialization.jsonObject(with: data) as! [String: Any]; old["schemaVersion"] = 6; old.removeValue(forKey: "dialogueAttempts"); old["practiceSessions"] = [:]
        let migrated = try JSONDecoder().decode(CourseLearningSnapshot.self, from: JSONSerialization.data(withJSONObject: old)); #expect(migrated.schemaVersion == 7 && migrated.progress.count == snapshot.progress.count && migrated.dialogueAttempts.isEmpty)
    }
    @Test("Notifications review taught independent items and never grade or truncate a visit")
    func notificationBoundary() throws {
        let dir = try directory(); defer { try? FileManager.default.removeItem(at: dir) }; let course = try course(dir), snapshot = try prepared(course)
        let cards = CourseNotificationProgress.practiceCards(course: course, snapshot: snapshot)
        #expect(cards.allSatisfy { $0.activity?.exercise?.isAppOnlyDialogue != true })
        #expect(CourseNotificationProgress.nextLearningCard(course: course, snapshot: snapshot, excluding: [])?.activity?.exercise?.isAppOnlyDialogue != true)
        #expect(CourseDeliveryContracts.notificationIsCompatible(profile: "practice-v2", contracts: CourseDeliveryContracts.supported.sorted()))
        #expect(!CourseDeliveryContracts.notificationIsCompatible(profile: "practice-v2", contracts: CourseDeliveryContracts.v1.sorted()))
    }
    @Test("Text matching, short reveals and contextual choices render in light/dark and large text")
    func readableLayouts() throws {
        let dir = try directory(); defer { try? FileManager.default.removeItem(at: dir) }; let course = try course(dir)
        let ids = Set(["pf-sp-l03-e03", "pf-sp-l04-x07", "pf-sp-l04-e03", "pf-sp-l06-e01"])
        for card in course.units.last!.lessons.flatMap(\.cards).filter({ ids.contains($0.id) }) {
            for scheme in [ColorScheme.light, .dark] { for size in [DynamicTypeSize.large, .accessibility3] {
                let panel = CoursePracticeExercisePanel(card: card, exercise: card.activity!.exercise!, immersive: true, checkpoint: false) { _ in }.padding(24).frame(width: 390).background(LearnAlertStyle.courseCanvas).environment(\.colorScheme, scheme).environment(\.dynamicTypeSize, size)
                let renderer = ImageRenderer(content: panel); renderer.scale = 1; let image = try #require(renderer.uiImage); #expect(image.size.width == 390 && image.size.height > 150)
                Attachment.record(image, named: "cafe-\(card.id)-\(scheme)-\(size)", as: .png)
            } }
        }
    }
    @Test("Real six-lesson adoption preserves the two-lesson Continue anchor and accounting")
    func realRouteExpansion() throws {
        let dir = try directory(); defer { try? FileManager.default.removeItem(at: dir) }
        let old = try course(dir, resourceName: "visual-starter-pilot")
        var snapshot = CourseLearningSnapshot(); snapshot.assignRoute(course: old, returningLearner: false)
        let opened = snapshot.resumePractice(course: old, lessonId: "pf-sp-l01", checkpointUnitId: nil), session = try #require(opened)
        let card = old.units.last!.lessons[0].cards[0], identity = try check(card, course: old, snapshot: &snapshot)
        let recorded = snapshot.answerPractice(course: old, lessonId: "pf-sp-l01", checkpointUnitId: nil, sessionId: session.id, cardId: card.id, correct: true, exerciseAttemptID: identity); #expect(recorded)
        let fraction = snapshot.completionFraction(course: old), denominator = snapshot.routes[old.id]?.lessonIDs
        let expanded = try course(dir)
        #expect(snapshot.assignedStarterLessonIDs(course: expanded).count == 2)
        let adopted = snapshot.adoptStarterRevision(course: expanded); #expect(adopted)
        #expect(snapshot.assignedStarterLessonIDs(course: expanded).count == 6 && snapshot.routes[old.id]?.lessonIDs == denominator)
        #expect(snapshot.completionFraction(course: expanded) == fraction && snapshot.currentLesson(course: expanded)?.id == "pf-sp-l01")
        let resumed = snapshot.resumePractice(course: expanded, lessonId: "pf-sp-l01", checkpointUnitId: nil)
        #expect(resumed?.id == session.id && resumed?.pendingContinueAttemptID == identity)
    }
    @Test("Passing the unchanged two-lesson assessment permits actual L03 without fabricated old study")
    func actualLessonAfterTestOut() throws {
        let dir = try directory(); defer { try? FileManager.default.removeItem(at: dir) }; let course = try course(dir)
        var snapshot = CourseLearningSnapshot(); snapshot.assignRoute(course: course, returningLearner: false)
        let opened = snapshot.startAssessment(course: course), attempt = try #require(opened)
        for item in attempt.items {
            let initial = try #require(snapshot.assessmentAttempts[attempt.id]?.states[item.id])
            for state in try correctSteps(try #require(item.card.activity?.exercise), initial: initial) {
                let accepted = snapshot.saveAssessmentState(courseID: course.id, assessmentID: attempt.id, itemID: item.id, state: state); #expect(accepted)
            }
            let advanced = snapshot.advanceAssessment(courseID: course.id, assessmentID: attempt.id, itemID: item.id); #expect(advanced)
        }
        #expect(snapshot.assessmentAttempts[attempt.id]?.passed == true && snapshot.currentLesson(course: course)?.id == "pf-sp-l03")
        #expect(snapshot.progress.isEmpty && snapshot.courseSRS.isEmpty)
        try study("pf-sp-l03", course: course, snapshot: &snapshot)
        #expect(snapshot.status(course: course, lessonId: "pf-sp-l03") == .completed)
        #expect(snapshot.progress[course.id]?["pf-sp-l01"] == nil && snapshot.progress[course.id]?["pf-sp-l02"] == nil)
        #expect(Set(snapshot.assessmentAccess[course.id] ?? []) == Set(["pf-sp-l01", "pf-sp-l02"]))
        #expect(!(snapshot.courseSRS[course.id]?.keys.contains { $0.hasPrefix("pf-sp-l01") || $0.hasPrefix("pf-sp-l02") } ?? false))
    }
    @Test("A file-backed interrupted Check reconciles into the same visit and stale hosts cannot duplicate it")
    func durableVisitHosts() throws {
        let dir = try directory(); defer { try? FileManager.default.removeItem(at: dir) }; let course = try course(dir)
        var preparedState = try prepared(course)
        let app = CourseLearningStore(directory: dir, defaults: nil)
        let seeded = app.transaction { current in preparedState.migration = current.migration; current = preparedState; return true }; #expect(seeded == true)
        let opened = app.transaction { $0.resumePractice(course: course, lessonId: "pf-sp-l06", checkpointUnitId: nil) }, session = try #require(opened ?? nil)
        let card = course.units.last!.lessons.last!.cards[0], ex = try #require(card.activity?.exercise)
        var states = try correctSteps(ex)
        let checked = states.removeLast()
        for state in states { let saved = app.transaction { $0.saveExercise(courseID: course.id, cardID: card.id, exercise: ex, state: state) }; #expect(saved == true) }
        let notification = CourseLearningStore(directory: dir, defaults: nil)
        #expect(notification.snapshot().exerciseDrafts[CourseLearningSnapshot.exerciseKey(courseID: course.id, cardID: card.id)]?.state.selectedIDs == states.last?.selectedIDs)
        let checkedSave = app.transaction { $0.saveExercise(courseID: course.id, cardID: card.id, exercise: ex, state: checked) }; #expect(checkedSave == true)
        let cannotAcknowledge = notification.transaction { $0.acknowledgeExercise(courseID: course.id, cardID: card.id, attemptID: checked.attemptID) }; #expect(cannotAcknowledge == false)
        let relaunch = CourseLearningStore(directory: dir, defaults: nil)
        let restored = relaunch.transaction { $0.resumePractice(course: course, lessonId: "pf-sp-l06", checkpointUnitId: nil) }; #expect((restored ?? nil)?.id == session.id)
        let graded = relaunch.transaction { $0.answerPractice(course: course, lessonId: "pf-sp-l06", checkpointUnitId: nil, sessionId: session.id, cardId: card.id, correct: true, exerciseAttemptID: checked.attemptID) }; #expect(graded == true)
        let continuedElsewhere = notification.transaction { $0.acknowledgeExercise(courseID: course.id, cardID: card.id, attemptID: checked.attemptID) }; #expect(continuedElsewhere == true)
        let lateCallback = app.transaction { $0.answerPractice(course: course, lessonId: "pf-sp-l06", checkpointUnitId: nil, sessionId: session.id, cardId: card.id, correct: true, exerciseAttemptID: checked.attemptID) }; #expect(lateCallback == true)
        let final = app.snapshot(), visit = try #require(final.dialogueAttempt(courseID: course.id, lessonID: "pf-sp-l06", sessionID: session.id))
        #expect(visit.stepIndex == 1 && visit.committed.count == 1 && final.progress[course.id]?["pf-sp-l06"]?.totalAttemptsCount == 1)
        #expect(final.srsRecord(courseId: course.id, cardId: card.id) == nil)
    }

    private func envelope(_ course: CourseDefinition, profile: String, revision: Int) throws -> (ManagedCatalogManifest, Data) {
        let payload = try JSONEncoder().encode(course), digest = SHA256.hash(data: payload).map { String(format: "%02x", $0) }.joined(), required = CourseDeliveryContracts.required(for: profile).sorted()
        let data = try JSONSerialization.data(withJSONObject: ["schemaVersion":2,"id":course.id,"kind":"course","revision":revision,"deliveryProfile":profile,"requiredContracts":required,"contentDigest":digest,"payload":payload.base64EncodedString()])
        var item = ManagedCatalogItem(id: course.id, kind: "course", title: course.title, revision: revision, updatedAt: 0, contentURL: "https://api.learnalertapp.com/v1/catalog/" + course.id + "?profile=" + profile + "&revision=" + String(revision))
        item.deliveryProfile = profile; item.requiredContracts = required; item.contentDigest = digest
        return (.init(schemaVersion: 2, revision: profile + String(revision), initialized: true, items: [item], deliveryProfile: profile), data)
    }
    @Test("v2 cache is isolated from v1, rejects a route-losing fallback and restores compatible last-good offline")
    func compatibleCaches() throws {
        let oldDir = try directory(), modernDir = try directory(), cacheDir = try directory()
        defer { for dir in [oldDir, modernDir, cacheDir] { try? FileManager.default.removeItem(at: dir) } }
        let old = try course(oldDir, resourceName: "visual-starter-pilot"), modern = try course(modernDir)
        let v1 = ManagedCatalogStore(directory: cacheDir, defaults: nil, profile: "practice-v1"), oldRelease = try envelope(old, profile: "practice-v1", revision: 11)
        try v1.install(oldRelease.0, documents: [old.id: oldRelease.1])
        let oldBytes = try Data(contentsOf: cacheDir.appendingPathComponent("managed-catalog-v2-practice-v1.json"))
        let v2 = ManagedCatalogStore(directory: cacheDir, defaults: nil, profile: "practice-v2")
        #expect(v2.course(for: old.id)?.units.last?.lessons.count == 2)
        let release = try envelope(modern, profile: "practice-v2", revision: 12)
        try v2.install(release.0, documents: [modern.id: release.1])
        #expect(try Data(contentsOf: cacheDir.appendingPathComponent("managed-catalog-v2-practice-v1.json")) == oldBytes)
        #expect(throws: (any Error).self) { try v1.install(release.0, documents: [modern.id: release.1]) }
        var fallback = oldRelease.0
        fallback = .init(schemaVersion: 2, revision: "withdrawn-v2", initialized: true, items: fallback.items, deliveryProfile: "practice-v2")
        #expect(throws: (any Error).self) { try v2.install(fallback, documents: [old.id: oldRelease.1]) }
        var malformed = release.0, items = malformed.items; items[0].requiredContracts = CourseDeliveryContracts.v1.sorted()
        malformed = .init(schemaVersion: 2, revision: "partial-contract", initialized: true, items: items, deliveryProfile: "practice-v2")
        #expect(throws: (any Error).self) { try v2.install(malformed, documents: [modern.id: release.1]) }
        let correction = try envelope(modern, profile: "practice-v2", revision: 13); try v2.install(correction.0, documents: [modern.id: correction.1])
        try Data("corrupt".utf8).write(to: cacheDir.appendingPathComponent("managed-catalog-v2-practice-v2.json"))
        let offline = ManagedCatalogStore(directory: cacheDir, defaults: nil, profile: "practice-v2")
        #expect(offline.course(for: modern.id)?.units.last?.lessons.count == 6)
        #expect(ManagedCatalogStore(directory: cacheDir, defaults: nil, profile: "practice-v1").course(for: old.id)?.units.last?.lessons.count == 2)
    }

    @Test("v2 offline upgrade validates v1 primary and backup before legacy, preserving assigned routes")
    func compatibleBackupRecoveryMatrix() throws {
        let oldDir = try directory(), modernDir = try directory()
        defer { for dir in [oldDir, modernDir] { try? FileManager.default.removeItem(at: dir) } }
        let old = try course(oldDir, resourceName: "visual-starter-pilot"), modern = try course(modernDir)
        // v1 primary, v1 backup, legacy, v2 primary, v2 backup, six-lesson assignment, expected lessons.
        let cases: [(String, String, Bool, String, String, Bool, Int?)] = [
            ("corrupt","valid",false,"missing","missing",false,2),
            ("missing","valid",false,"missing","missing",false,2),
            ("corrupt","valid",true,"missing","missing",false,2),
            ("missing","valid",true,"missing","missing",false,2),
            ("valid","valid",true,"missing","missing",false,2),
            ("corrupt","corrupt",true,"missing","missing",false,nil),
            ("missing","digest",true,"missing","missing",false,nil),
            ("missing","contracts",true,"missing","missing",false,nil),
            ("corrupt","valid",true,"missing","missing",true,nil),
            ("corrupt","valid",true,"valid","valid",false,6),
            ("corrupt","valid",true,"corrupt","valid",false,6),
            ("corrupt","valid",true,"missing","valid",true,6),
            ("corrupt","valid",true,"corrupt","corrupt",false,nil)
        ]
        for (index, c) in cases.enumerated() {
            let dir = try directory(), suite = "CafeBackupMatrix." + UUID().uuidString
            let defaults = try #require(UserDefaults(suiteName: suite))
            defer { try? FileManager.default.removeItem(at: dir); defaults.removePersistentDomain(forName: suite) }
            let v1 = ManagedCatalogStore(directory: dir, defaults: defaults, profile: "practice-v1"), release = try envelope(old, profile: "practice-v1", revision: 11)
            try v1.install(release.0, documents: [old.id: release.1])
            let v1URL = dir.appendingPathComponent("managed-catalog-v2-practice-v1.json"), v2URL = dir.appendingPathComponent("managed-catalog-v2-practice-v2.json")
            let v1Bytes = try Data(contentsOf: v1URL)
            if c.3 != "missing" || c.4 != "missing" {
                let v2 = ManagedCatalogStore(directory: dir, defaults: defaults, profile: "practice-v2"), newer = try envelope(modern, profile: "practice-v2", revision: 12)
                try v2.install(newer.0, documents: [modern.id: newer.1])
            }
            if c.2 {
                let base = CourseDefinition(id: old.id, title: old.title, language: old.language, flagEmoji: old.flagEmoji, levelTag: old.levelTag, colorHex: old.colorHex, summary: old.summary, estimatedHours: 1, outcomes: [], units: Array(old.units.dropLast()))
                let document = try JSONSerialization.jsonObject(with: JSONEncoder().encode(base)), bytes = try JSONSerialization.data(withJSONObject: ["id":base.id,"kind":"course","revision":9,"document":document])
                let item = ManagedCatalogItem(id: base.id, kind: "course", title: base.title, revision: 9, updatedAt: 0, contentURL: "https://api.learnalertapp.com/v1/catalog/" + base.id + "?revision=9")
                try ManagedCatalogStore(directory: dir, defaults: defaults).install(.init(schemaVersion: 1, revision: "legacy9", initialized: true, items: [item]), documents: [base.id: bytes])
            }
            func alter(_ path: URL, _ state: String, backup: Bool = false) throws {
                if state == "missing" { if FileManager.default.fileExists(atPath: path.path) { try FileManager.default.removeItem(at: path) }; return }
                if state == "corrupt" { try Data("broken".utf8).write(to: path); return }
                if backup && state == "valid" {
                    var cache = try #require(JSONSerialization.jsonObject(with: v1Bytes) as? [String: Any]), manifest = try #require(cache["manifest"] as? [String: Any]); manifest["revision"] = "backup-v1"; cache["manifest"] = manifest
                    try JSONSerialization.data(withJSONObject: cache).write(to: path); return
                }
                if state == "digest" || state == "contracts" {
                    var cache = try #require(JSONSerialization.jsonObject(with: v1Bytes) as? [String: Any]), manifest = try #require(cache["manifest"] as? [String: Any]), items = try #require(manifest["items"] as? [[String: Any]])
                    if state == "digest" { items[0]["contentDigest"] = String(repeating: "0", count: 64) } else { items[0]["requiredContracts"] = ["exercise-v1"] }
                    manifest["items"] = items; cache["manifest"] = manifest; try JSONSerialization.data(withJSONObject: cache).write(to: path)
                }
            }
            try alter(v1URL, c.0); try alter(v1URL.appendingPathExtension("backup"), c.1, backup: true)
            try alter(v2URL, c.3); try alter(v2URL.appendingPathExtension("backup"), c.4)
            let preservedPrimary = try? Data(contentsOf: v1URL), preservedBackup = try? Data(contentsOf: v1URL.appendingPathExtension("backup"))
            var progress = CourseLearningSnapshot(); progress.assignRoute(course: c.5 ? modern : old, returningLearner: false)
            let admission: (CourseDefinition, CourseDefinition) -> Bool = { progress.permitsCourseReplacement(previous: $0, candidate: $1) }
            let reader = ManagedCatalogStore(directory: dir, defaults: defaults, profile: "practice-v2", replacementAllowed: admission)
            #expect(reader.courses.first?.units.last?.lessons.count == c.6, "backup matrix case \(index)")
            if c.6 == 2 { #expect(reader.revision == (c.0 == "valid" ? "practice-v111" : "backup-v1")) }
            if c.6 == nil && c.2 && c.3 == "missing" && c.4 == "missing" { #expect(reader.lastError != nil) }
            if c.6 != nil { #expect(reader.lastError == nil) }
            reader.reloadFromDisk(); #expect(reader.courses.first?.units.last?.lessons.count == c.6)
            #expect((try? Data(contentsOf: v1URL)) == preservedPrimary)
            #expect((try? Data(contentsOf: v1URL.appendingPathExtension("backup"))) == preservedBackup)
            #expect(progress.routes[old.id]?.revision == (c.5 ? modern : old).learning?.starter?.revision)
        }
    }

}
