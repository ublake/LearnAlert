import Foundation
import CoreGraphics
import CryptoKit
import Testing
#if canImport(UIKit)
import SwiftUI
import UIKit
#endif
@testable import LearnAlert

@MainActor
@Suite("Korean foundation workshop")
struct CourseActivityTests {
    private var course: CourseDefinition { CourseCurriculumCatalog.koreanCourse }
    private var unit: CourseUnit { course.units[0] }
    private var practice: [CourseLessonCard] { unit.lessons.flatMap(\.cards) }

    @Test("Read-through acknowledgments have neutral feedback while scored activities stay scored")
    func readingFeedback() {
        let teaching = practice.filter { $0.activity?.kind == .teach }
        #expect(!teaching.isEmpty)
        for card in teaching {
            #expect(card.isReadThrough)
            #expect(card.feedbackTitle(isCorrect: true) == "Reviewed")
            #expect(card.feedbackTitle(isCorrect: false) == "Review later")
        }
        for card in practice where card.activity?.kind != .teach {
            #expect(!card.isReadThrough)
            #expect(card.feedbackTitle(isCorrect: true) == "Correct")
        }
        for type in ["vocabulary", "tapReveal"] {
            let card = CourseLessonCard(id: type, question: "Read this", correctAnswer: "A lesson note", cardType: type)
            #expect(card.isReadThrough)
            #expect(card.feedbackTitle(isCorrect: true) == "Reviewed")
        }
    }

    @Test("Korean emphasis preserves every character, repeated letters, links and surrounding formatting")
    func koreanEmphasis() throws {
        let plain = "Start with ㄱ + ㅏ = 가. Repeat ㄱ. 한 👩‍🎓."
        var source = AttributedString(plain)
        let english = try #require(source.range(of: "Start"))
        source[english].inlinePresentationIntent = .emphasized
        let linked = try #require(source.range(of: "가"))
        let url = try #require(URL(string: "learnalert-word://lookup?word=가"))
        source[linked].link = url
        let emphasized = CourseKoreanText.attributed(source)
        #expect(String(emphasized.characters) == plain)
        #expect(emphasized[english].inlinePresentationIntent == .emphasized)
        #expect(emphasized[english].foregroundColor == nil)
        #expect(emphasized[linked].link == url)
        for run in emphasized.runs {
            let text = String(emphasized[run.range].characters)
            if text.contains("ㄱ") || text.contains("ㅏ") || text.contains("가") || text.contains("한") {
                #expect(run.foregroundColor == CourseKoreanText.emphasisColor)
                #expect(run.inlinePresentationIntent?.contains(.stronglyEmphasized) == true)
            }
        }
    }

    @Test("Bundled workshop activities are limited to the first Korean unit")
    func activityScope() {
        #expect(unit.lessons.count == 5)
        #expect(practice.allSatisfy { $0.activity != nil })
        #expect(Set(practice.compactMap { $0.activity?.kind.rawValue }) == Set([
            "teach", "trace", "buildBlock", "placeTokens", "listenChoose", "situation", "matchPairs"
        ]))
        #expect(course.units.dropFirst().flatMap(\.lessons).flatMap(\.cards).allSatisfy { $0.activity == nil })
        for other in CourseCurriculumCatalog.bundledCourses where other.language != "Korean" {
            #expect(other.units.flatMap(\.lessons).flatMap(\.cards).allSatisfy { $0.activity == nil })
        }
    }

    @Test("Authored activities keep their teaching sequence across randomized sessions")
    func lessonSequence() throws {
        for lesson in unit.lessons {
            #expect(lesson.cards.first?.activity?.kind == .teach)
            #expect(lesson.cards.compactMap { $0.activity?.sequence } == Array(lesson.cards.indices))
            for _ in 0..<5 {
                let ordered = CourseLearningSnapshot.orderedLearningCards(lesson.cards.shuffled())
                #expect(ordered.map(\.id) == lesson.cards.map(\.id))
            }
        }
        var state = CourseLearningSnapshot()
        for lesson in unit.lessons {
            let sessionValue = state.resumePractice(course: course, lessonId: lesson.id, checkpointUnitId: nil)
            let session = try #require(sessionValue)
            #expect(session.cardIds == lesson.cards.map(\.id))
            for id in session.cardIds {
                let saved = state.answerPractice(course: course, lessonId: lesson.id, checkpointUnitId: nil,
                    sessionId: session.id, cardId: id, correct: true)
                #expect(saved)
            }
            #expect(state.status(course: course, lessonId: lesson.id) == .completed)
        }
        #expect(state.pendingCheckpoint(course: course)?.id == unit.id)
        #expect(state.currentLesson(course: course) == nil)
        #expect(state.status(course: course, lessonId: course.units[1].lessons[0].id) == .locked)
    }

    @Test("Practice choices are Korean and each listening or situation option has its own hint")
    func koreanChoicesAndHints() throws {
        let checkpoint = try #require(unit.checkpointQuiz)
        for card in practice + checkpoint.questions {
            let activity = try #require(card.activity)
            guard activity.kind != .teach && activity.kind != .matchPairs else { continue }
            #expect(card.options.count == 4 && Set(card.options).count == 4)
            #expect(card.options.filter { card.accepts($0) }.count == 1)
            #expect(card.options.allSatisfy { $0.range(of: "[가-힣ㄱ-ㅎㅏ-ㅣ]", options: .regularExpression) != nil })
            #expect(card.options.allSatisfy { $0.range(of: "[A-Za-z]", options: .regularExpression) == nil })
            if !card.id.hasPrefix("kr-cp-1-"), activity.kind == .listenChoose || activity.kind == .situation {
                #expect(card.options.allSatisfy { activity.optionHints[$0]?.isEmpty == false })
            }
            if activity.kind == .listenChoose {
                #expect(card.speechText?.isEmpty == false && activity.readingCue?.isEmpty == false)
                #expect(card.questionText(audioEnabled: false) != card.questionText(audioEnabled: true))
            }
        }
    }

    @Test("Placement distinguishes left, right, below and final slots and remembers a corrected mistake")
    func placement() throws {
        let builds = practice.filter { $0.activity?.kind == .buildBlock }
        let layouts = Set(builds.compactMap { $0.activity?.layout.rawValue })
        #expect(layouts.isSuperset(of: [
            "beside", "below", "besideWithFinal", "belowWithFinal"
        ]))
        for card in builds + practice.filter({ $0.activity?.kind == .placeTokens }) {
            let activity = try #require(card.activity)
            #expect(activity.slotLabels.count == activity.slots.count)
            #expect(activity.slots.allSatisfy { activity.tokens.contains($0) })
            var state = CoursePlacementState(count: activity.slots.count)
            #expect(!state.filled)
            let invalidSlot = state.place(activity.slots[0], in: activity.slots.count, available: activity.tokens)
            let invalidToken = state.place("unknown", in: 0, available: activity.tokens)
            #expect(!invalidSlot && !invalidToken && state.values.allSatisfy { $0 == nil })
            for (index, token) in activity.slots.enumerated() {
                state.selectedToken = token
                let placed = state.place(token, in: index, available: activity.tokens)
                #expect(placed && state.selectedToken == nil)
            }
            #expect(state.filled)
            let correct = state.check(expected: activity.slots)
            #expect(correct && !state.hadMistake)
        }
        var state = CoursePlacementState(count: 3)
        for (index, token) in ["ㅁ", "ㄴ", "ㅜ"].enumerated() {
            _ = state.place(token, in: index, available: ["ㅁ", "ㅜ", "ㄴ"])
        }
        let incorrect = state.check(expected: ["ㅁ", "ㅜ", "ㄴ"])
        #expect(!incorrect && state.hadMistake)
        _ = state.place("ㅜ", in: 1, available: ["ㅁ", "ㅜ", "ㄴ"])
        _ = state.place("ㄴ", in: 2, available: ["ㅁ", "ㅜ", "ㄴ"])
        let corrected = state.check(expected: ["ㅁ", "ㅜ", "ㄴ"])
        #expect(corrected && state.hadMistake)
    }

    @Test("Every taught tracing guide accepts a complete stroke and rejects incomplete or incorrect gestures")
    func tracingGeometry() throws {
        let symbols = Set(practice.compactMap { $0.activity?.kind == .trace ? $0.activity?.symbol : nil })
        #expect(symbols == Set(["ㅏ", "ㅓ", "ㅗ", "ㅜ", "ㅡ", "ㅣ", "ㄱ", "ㄴ", "ㅁ", "ㅇ", "ㄷ", "ㄹ", "ㅂ", "ㅅ", "ㅈ", "ㅎ"]))
        for symbol in symbols {
            let strokes = HangulStrokeGuide.strokes(for: symbol)
            #expect(!strokes.isEmpty)
            for stroke in strokes {
                let input = sampled(stroke)
                #expect(HangulStrokeGuide.accepts(input, target: stroke))
                #expect(!HangulStrokeGuide.accepts(Array(input.reversed()), target: stroke))
                #expect(!HangulStrokeGuide.accepts(Array(input.prefix(max(5, input.count / 3))), target: stroke))
                #expect(!HangulStrokeGuide.accepts(input.map { CGPoint(x: $0.x + 0.4, y: $0.y + 0.4) }, target: stroke))
                #expect(!HangulStrokeGuide.accepts(Array(input.prefix(4)), target: stroke))
            }
        }
        #expect(HangulStrokeGuide.strokes(for: "unknown").isEmpty)
        let fastLine = try #require(HangulStrokeGuide.strokes(for: "ㅣ").first)
        #expect(HangulStrokeGuide.accepts(fastLine, target: fastLine))
        #expect(!HangulStrokeGuide.accepts([fastLine[0], fastLine[0]], target: fastLine))
    }

    @Test("The checkpoint only assesses skills and answers introduced in this unit")
    func checkpointUsesTaughtContent() throws {
        let checkpoint = try #require(unit.checkpointQuiz)
        #expect(checkpoint.questions.count == 10)
        #expect(Set(checkpoint.questions.map(\.id)).isDisjoint(with: practice.map(\.id)))
        let taughtAnswers = Set(practice.map(\.correctAnswer))
        for card in checkpoint.questions {
            let activity = try #require(card.activity)
            #expect(activity.kind != .teach && activity.kind != .trace)
            #expect(activity.optionHints.isEmpty)
            #expect(taughtAnswers.contains(card.correctAnswer))
            if activity.kind == .buildBlock || activity.kind == .placeTokens {
                #expect(practice.contains { candidate in
                    candidate.activity?.kind == activity.kind && candidate.activity?.slots == activity.slots
                        && candidate.activity?.layout == activity.layout && candidate.correctAnswer == card.correctAnswer
                })
            }
        }
        for lesson in unit.lessons {
            for (index, card) in lesson.cards.enumerated() where card.promptImageName != nil && card.activity?.kind == .situation {
                #expect(lesson.cards.prefix(index).contains { $0.activity?.kind == .teach && $0.vocabularyItem?.surface == card.correctAnswer })
            }
        }
    }

    @Test("Course activities round-trip while older lesson cards decode without activity metadata")
    func activityCoding() throws {
        for card in practice + (unit.checkpointQuiz?.questions ?? []) {
            #expect(try JSONDecoder().decode(CourseLessonCard.self, from: JSONEncoder().encode(card)) == card)
        }
        let legacy = CourseLessonCard(id: "legacy-card", question: "Choose the Korean for water", options: ["물", "문"], correctAnswer: "물")
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(legacy)) as? [String: Any])
        json.removeValue(forKey: "activity")
        let decoded = try JSONDecoder().decode(CourseLessonCard.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(decoded.activity == nil && decoded == legacy)
    }

    #if canImport(UIKit)
    @Test("Reserved Korean artwork files are bundled and one-pixel files resolve to placeholders")
    func bundledPlaceholders() throws {
        let stems = ["child", "tree", "sea", "milk", "water", "door", "mountain", "house", "person", "hat", "flower"]
        for stem in stems {
            let url = try #require(Bundle.main.url(forResource: stem, withExtension: "png", subdirectory: "koreanimages")
                ?? Bundle.main.url(forResource: stem, withExtension: "png"))
            #expect(FileManager.default.fileExists(atPath: url.path))
            let pixels = try #require(UIImage(contentsOfFile: url.path)?.cgImage)
            if pixels.width == 1 && pixels.height == 1 {
                #expect(CourseVocabularyImages.image(named: "koreanimages/\(stem).png") == nil)
                #expect(CourseVocabularyImages.image(named: "\(stem).png") == nil)
                #expect(CourseVocabularyImages.image(named: stem) == nil)
            } else {
                #expect(CourseVocabularyImages.image(named: "koreanimages/\(stem).png") != nil)
            }
        }
        for invalid in ["../tree.png", "koreanimages/../tree.png", "/tree.png", "tree.gif", "tree\\.png"] {
            #expect(CourseVocabularyImages.image(named: invalid) == nil)
        }
        let pictureCards = practice.filter { $0.promptImageName != nil }
        #expect(Set(pictureCards.compactMap(\.promptImageName)).count == 8)
        #expect(pictureCards.allSatisfy { $0.promptImageName?.hasPrefix("koreanimages/") == true })
    }

    @Test("Custom activities render in app and compact notification sizes across appearances")
    func activityAppearance() throws {
        let fixtures: [(String, CourseLessonCard)] = try [
            ("teach", #require(practice.first { $0.activity?.kind == .teach && $0.promptImageName == nil })),
            ("trace", #require(practice.first { $0.activity?.kind == .trace })),
            ("listen", #require(practice.first { $0.activity?.kind == .listenChoose })),
            ("build-beside", #require(practice.first { $0.activity?.layout == .beside })),
            ("build-below", #require(practice.first { $0.activity?.layout == .below })),
            ("build-final", #require(practice.first { $0.activity?.layout == .besideWithFinal })),
            ("arrange", #require(practice.first { $0.activity?.kind == .placeTokens })),
            ("matching", #require(practice.first { $0.activity?.kind == .matchPairs })),
            ("situation", #require(practice.last { $0.activity?.kind == .situation && $0.promptImageName == nil })),
            ("picture-placeholder", #require(practice.first { $0.activity?.kind == .situation && $0.promptImageName != nil })),
            ("word-introduction", #require(practice.first { $0.activity?.kind == .teach && $0.promptImageName != nil }))
        ]
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("korean-workshop-previews", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for scheme in [ColorScheme.light, .dark] {
            for immersive in [true, false] {
                let width: CGFloat = immersive ? 402 : 360
                for (label, card) in fixtures {
                    let renderer = ImageRenderer(content: CourseQuestionPanel(card: card, immersive: immersive,
                        allowRecordedAudio: label == "listen", allowKoreanSpeech: label == "listen") { _ in }
                        .environment(\.courseNotificationCompact, !immersive && label != "trace")
                        .padding(immersive ? 24 : 16).frame(width: width)
                        .background(Color(.systemGroupedBackground)).environment(\.colorScheme, scheme))
                    renderer.scale = 2
                    let image = try #require(renderer.uiImage)
                    #expect(image.size.width == width && image.size.height > 100)
                    let name = "workshop-\(label)-\(immersive ? "app" : "notification")-\(scheme == .dark ? "dark" : "light").png"
                    try #require(image.pngData()).write(to: directory.appendingPathComponent(name))
                    Attachment.record(image, named: name, as: .png)
                }
            }
        }
    }
    #endif

    private func sampled(_ stroke: [CGPoint]) -> [CGPoint] {
        zip(stroke, stroke.dropFirst()).flatMap { start, end in
            (0...24).map { step in
                let position = CGFloat(step) / 24
                return CGPoint(x: start.x + (end.x - start.x) * position, y: start.y + (end.y - start.y) * position)
            }
        }
    }
}


@MainActor
@Suite("Practice-first exercises")
struct CoursePracticeExerciseTests {
    private var bank: CourseExercise {
        .init(format: "wordBank", vocabularyIDs: ["es.libro.object"], conceptIDs: ["request.object"],
              tiles: [.init(id: "a", text: "un"), .init(id: "b", text: "libro"), .init(id: "c", text: "y"), .init(id: "d", text: "un")],
              acceptedOrders: [["un", "libro", "y", "un"]])
    }
    @Test("Finite token instances, move/remove and first answer remain immutable")
    func finiteBank() throws {
        var state = CourseExerciseState()
        state.append("a", exercise: bank); state.append("a", exercise: bank); state.append("missing", exercise: bank)
        #expect(state.selectedIDs == ["a"])
        for id in ["b", "d", "c"] { state.append(id, exercise: bank) }
        state.move("c", before: "d", exercise: bank)
        #expect(state.selectedIDs == ["a", "b", "c", "d"])
        #expect(state.submit(bank) == true)
        let graded = state
        state.remove("a"); state.append("a", exercise: bank)
        #expect(state.submit(bank) == nil)
        #expect(state == graded)
        let restored = try JSONDecoder().decode(CourseExerciseState.self, from: JSONEncoder().encode(state))
        #expect(restored == state)
        #expect(restored.orderedIDs(["a", "b", "c", "d"]) == state.orderedIDs(["a", "b", "c", "d"]))
        #expect(Set(state.orderedIDs(["a", "b", "c", "d"])) == ["a", "b", "c", "d"])
        var wrong = CourseExerciseState(); wrong.append("b", exercise: bank)
        #expect(wrong.submit(bank) == false)
    }
    @Test("Alternatives are explicit, accents retained and incomplete answers never pass")
    func acceptedOrders() {
        var exercise = bank
        exercise.acceptedOrders = [["un", "libro"], ["libro", "un"]]
        var state = CourseExerciseState(); state.append("b", exercise: exercise); state.append("a", exercise: exercise)
        #expect(state.submit(exercise) == true)
        exercise.acceptedOrders = [["café"]]; exercise.tiles = [.init(id: "coffee", text: "cafe")]
        state = CourseExerciseState(); state.append("coffee", exercise: exercise)
        #expect(state.submit(exercise) == false)
    }
    @Test("Shared reducers reject stale writers and deduplicate Check")
    func staleWriter() {
        var snapshot = CourseLearningSnapshot(), first = CourseExerciseState()
        first.append("a", exercise: bank)
        #expect(snapshot.saveExercise(courseID: "es", cardID: "bank", exercise: bank, state: first) == true)
        var stale = first
        first.append("b", exercise: bank)
        #expect(snapshot.saveExercise(courseID: "es", cardID: "bank", exercise: bank, state: first) == true)
        stale.append("c", exercise: bank)
        #expect(snapshot.saveExercise(courseID: "es", cardID: "bank", exercise: bank, state: stale) == false)
        _ = first.submit(bank)
        #expect(snapshot.saveExercise(courseID: "es", cardID: "bank", exercise: bank, state: first) == true)
        #expect(snapshot.saveExercise(courseID: "es", cardID: "bank", exercise: bank, state: first) == true)
    }
    @Test("v1 migration is recoverable and old writers cannot overwrite v2")
    func migration() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let original = Data(#"{"progress":{"es":{"one":{"status":"completed","correctAnswersCount":1,"totalAttemptsCount":1,"masteredCardIds":["old"]}}},"practiceSessions":{"es:lesson:two":{"id":"unfinished","cardIds":["x","y"],"answers":{"x":true}}}}"#.utf8)
        let v1 = directory.appendingPathComponent("course-learning-v1.json")
        try original.write(to: v1)
        let store = CourseLearningStore(directory: directory, defaults: nil)
        #expect(store.transaction { $0.traceAttempts["retained"] = 2; return true } == true)
        #expect(try Data(contentsOf: directory.appendingPathComponent("course-learning-v1.pre-practice.json")) == original)
        try Data("{\"progress\":{}}".utf8).write(to: v1) // old binary, after migration
        let migrated = store.snapshot()
        #expect(migrated.retainedCompletion["es"] == ["one"])
        #expect(migrated.progress["es"]?["one"]?.masteredCardIds == ["old"])
        #expect(migrated.practiceSessions["es:lesson:two"]?.nextIndex == 1)
        #expect(store.transaction { _ in true } == true)
        #expect(store.snapshot().traceAttempts["retained"] == 2)
        let v2 = directory.appendingPathComponent("course-learning-v2.json")
        try Data("broken".utf8).write(to: v2)
        #expect(store.transaction { $0.traceAttempts.removeAll() } == nil)
        #expect(try String(contentsOf: v2, encoding: .utf8) == "broken")
    }
    @Test("New exercise checkpoints retain first response and wait for durable Continue")
    func checkpointExercise() throws {
        var activity = CourseActivity(kind: .placeTokens, sequence: 0)
        activity.exercise = bank
        let question = CourseLessonCard(id: "checkpoint-bank", question: "Arrange", correctAnswer: "un libro y un", cardType: "tokenPlacement", activity: activity)
        let course = CourseDefinition(id: "checkpoint-fixture", title: "Fixture", language: "Spanish", flagEmoji: "🇪🇸", levelTag: "", colorHex: "#42685A", summary: "", estimatedHours: 1, outcomes: [], units: [
            .init(id: "unit", unitNumber: 1, title: "Unit", subtitle: "", colorHex: "#42685A", badgeIcon: "book", lessons: [
                .init(id: "lesson", lessonNumber: 1, title: "Lesson", subtitle: "", cards: [.init(id: "old", question: "Old", correctAnswer: "Old", cardType: "vocabulary")])
            ], checkpointQuiz: .init(id: "checkpoint", title: "Checkpoint", summary: "", questions: [question], keyConcepts: []))
        ])
        var snapshot = CourseLearningSnapshot()
        snapshot.progress[course.id] = ["lesson": .init(status: .completed)]
        let resumed = snapshot.resumePractice(course: course, lessonId: nil, checkpointUnitId: "unit")
        let session = try #require(resumed)
        var state = CourseExerciseState()
        for id in ["a", "b", "c", "d"] {
            state.append(id, exercise: bank)
            #expect(snapshot.saveExercise(courseID: course.id, cardID: question.id, exercise: bank, state: state) == true)
        }
        #expect(state.submit(bank) == true)
        #expect(snapshot.saveExercise(courseID: course.id, cardID: question.id, exercise: bank, state: state) == true)
        #expect(snapshot.answerPractice(course: course, lessonId: nil, checkpointUnitId: "unit", sessionId: session.id, cardId: question.id, correct: true) == true)
        #expect(snapshot.exerciseEvidence.count == 1)
        #expect(snapshot.finishPractice(course: course, lessonId: nil, checkpointUnitId: "unit", sessionId: session.id) == nil)
        #expect(snapshot.continueExercise(courseID: course.id, lessonID: nil, checkpointID: "unit", sessionID: session.id, cardID: question.id) == true)
        #expect(snapshot.finishPractice(course: course, lessonId: nil, checkpointUnitId: "unit", sessionId: session.id)?.checkpointResult?.passed == true)
    }
    /// Real local media cache entries, never fabricated remote catalog asset IDs.
    private func pictures() throws -> [CoursePictureChoice] {
        try ["libro", "mochila", "silla", "reloj"].enumerated().map { index, noun in
            let id = UUID().uuidString, reference = "catalog:" + id
            let bundle = Bundle(for: CoursePilotTestBundleMarker.self)
            let url = try #require(bundle.url(forResource: "sp-" + noun + "-transparent", withExtension: "png"))
            let png = try Data(contentsOf: url)
            try ManagedCatalogMedia.save(png, asset: .init(id: id, reference: reference, contentType: "image/png", url: "https://api.learnalertapp.com/v1/catalog/media/" + id))
            #expect(try Data(contentsOf: #require(ManagedCatalogMedia.url(reference: reference))) == png)
            let decoded = try #require(CourseVocabularyImages.image(named: reference)?.cgImage)
            #expect([CGImageAlphaInfo.premultipliedLast, .premultipliedFirst, .last, .first].contains(decoded.alphaInfo))
            let context = try #require(CGContext(data: nil, width: 160, height: 160, bitsPerComponent: 8, bytesPerRow: 640, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(decoded, in: CGRect(x: 0, y: 0, width: 160, height: 160))
            #expect(context.data?.assumingMemoryBound(to: UInt8.self)[3] == 0)
            return .init(id: "picture-\(index)", image: reference, description: ["A closed book", "A backpack", "A chair", "A clock"][index])
        }
    }
    private func cleanup(_ pictures: [CoursePictureChoice]) {
        for picture in pictures { if let url = ManagedCatalogMedia.url(reference: picture.image) { try? FileManager.default.removeItem(at: url); try? FileManager.default.removeItem(at: url.appendingPathExtension("mime")) } }
    }
    private func pilot(_ pictures: [CoursePictureChoice]) -> CourseDefinition {
        func pictureCard(_ count: Int) -> CourseLessonCard {
            var activity = CourseActivity(kind: .situation, sequence: count)
            activity.exercise = .init(format: "pictureChoice", vocabularyIDs: ["es.libro.object"], conceptIDs: ["recognize.book"], pictures: Array(pictures.prefix(count)), correctChoiceID: pictures[0].id)
            return .init(id: "pictures-\(count)", question: "Find el libro", options: Array(pictures.prefix(count)).map(\.description), correctAnswer: pictures[0].description,
                         fieldMedia: Dictionary(uniqueKeysWithValues: Array(pictures.prefix(count)).enumerated().map { ("option:\($0.offset)", CardFieldMedia(image: $0.element.image)) }), correctOptionIndex: 0, activity: activity)
        }
        var introduction = CourseActivity(kind: .teach, sequence: 0, example: "el libro · a book")
        introduction.exercise = .init(format: "exposure", vocabularyIDs: ["es.libro.object"], conceptIDs: ["recognize.book"])
        var sentence = CourseActivity(kind: .placeTokens, sequence: 5, tokens: ["Veo", "un", "libro"], slots: ["Veo", "un", "libro"])
        sentence.exercise = .init(format: "wordBank", vocabularyIDs: ["es.libro.object"], conceptIDs: ["build.book"], tiles: [.init(id: "see", text: "Veo"), .init(id: "a", text: "un"), .init(id: "book", text: "libro")], acceptedOrders: [["Veo", "un", "libro"]])
        let cards = [CourseLessonCard(id: "intro", question: "A useful word", correctAnswer: "el libro", hint: "a book", cardType: "vocabulary", promptImageName: pictures[0].image, activity: introduction), pictureCard(2), pictureCard(4),
                     .init(id: "sentence", question: "Build: I see a book.", correctAnswer: "Veo un libro", cardType: "tokenPlacement", activity: sentence)]
        return .init(id: "local-practice-pilot", title: "Spanish (SP) · Local test fixture", language: "Spanish", flagEmoji: "🇪🇸", levelTag: "Beginner", colorHex: "#42685A", summary: "Local pipeline fixture; not reviewed course content", estimatedHours: 1, outcomes: [], units: [
            .init(id: "unit", unitNumber: 1, title: "First words", subtitle: "", colorHex: "#42685A", badgeIcon: "book", lessons: [.init(id: "lesson", lessonNumber: 1, title: "Look and build", subtitle: "", cards: cards)])], learning: .init(vocabulary: ["es.libro.object": .init(lemma: "libro", meaning: "book", locale: "es-ES", article: "el", image: pictures[0].image)], concepts: ["recognize.book": .init(title: "Recognize a book", prerequisiteIDs: [], vocabularyIDs: ["es.libro.object"]), "build.book": .init(title: "Use book in a sentence", prerequisiteIDs: ["recognize.book"], vocabularyIDs: ["es.libro.object"])]))
    }
    @Test("Managed document, alpha media, exposure-to-retrieval and durable Continue work end to end")
    func managedPilot() throws {
        let pictures = try pictures(); defer { cleanup(pictures) }
        let source = pilot(pictures)
        struct Document: Encodable { var id: String; var kind = "course"; var revision = 1; var document: CourseDefinition }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let catalog = ManagedCatalogStore(directory: directory, defaults: nil)
        try catalog.install(.init(schemaVersion: 1, revision: "local", initialized: true, items: [.init(id: source.id, kind: "course", title: source.title, revision: 1, updatedAt: 0, contentURL: "https://api.learnalertapp.com/v1/catalog/" + source.id)]), documents: [source.id: JSONEncoder().encode(Document(id: source.id, document: source))])
        let offline = ManagedCatalogStore(directory: directory, defaults: nil)
        let course = try #require(offline.course(for: source.id))
        #expect(course == source)
        let lesson = course.units[0].lessons[0]
        let store = CourseLearningStore(directory: directory.appendingPathComponent("progress"), defaults: nil)
        let session = try #require(store.transaction { $0.resumePractice(course: course, lessonId: lesson.id, checkpointUnitId: nil) } ?? nil)
        #expect(session.cardIds == lesson.cards.map(\.id))
        for card in lesson.cards {
            let exercise = try #require(card.activity?.exercise)
            var state = CourseExerciseState()
            func save() { #expect(store.transaction { $0.saveExercise(courseID: course.id, cardID: card.id, exercise: exercise, state: state) } == true) }
            if exercise.format == "pictureChoice" { state.select(pictures[0].id, exercise: exercise); save() }
            if exercise.format == "wordBank" { for id in ["see", "a", "book"] { state.append(id, exercise: exercise); save() } }
            #expect(state.submit(exercise) == true); save()
            #expect(store.transaction { $0.answerPractice(course: course, lessonId: lesson.id, checkpointUnitId: nil, sessionId: session.id, cardId: card.id, correct: true) } == true)
            let attempts = store.snapshot().progress[course.id]?[lesson.id]?.totalAttemptsCount
            #expect(store.transaction { $0.answer(course: course, lessonId: lesson.id, cardId: card.id, correct: true, token: "other-host-" + card.id) } == true)
            #expect(store.snapshot().progress[course.id]?[lesson.id]?.totalAttemptsCount == attempts)
            #expect(store.snapshot().practiceSessions[course.id + ":lesson:" + lesson.id]?.pendingContinueCardID == card.id)
            let reopened = CourseLearningStore(directory: directory.appendingPathComponent("progress"), defaults: nil)
            #expect(reopened.snapshot().exerciseDrafts[CourseLearningSnapshot.exerciseKey(courseID: course.id, cardID: card.id)]?.state == state)
            #expect(store.transaction { $0.continueExercise(courseID: course.id, lessonID: lesson.id, checkpointID: nil, sessionID: session.id, cardID: card.id) } == true)
        }
        #expect(store.snapshot().status(course: course, lessonId: lesson.id) == .completed)
        #expect(store.snapshot().exerciseEvidence.count == 4)
        var credited = store.snapshot()
        credited.progress[course.id]?[lesson.id]?.masteredCardIds = ["retired-original-card"]
        #expect(credited.status(course: course, lessonId: lesson.id) == .completed)
        #expect(credited.completionFraction(course: course) == 1)
        #expect(credited.exerciseEvidence.count == 4)
        #expect(store.snapshot().srsRecord(courseId: course.id, cardId: "intro") == nil)
        #expect(store.snapshot().exerciseEvidence.values.filter { $0.mode == "recognition" }.count == 2)
        #expect(store.transaction { $0.finishPractice(course: course, lessonId: lesson.id, checkpointUnitId: nil, sessionId: session.id) } != nil)
    }
    @Test("Picture and finite-bank panels render light/dark, large text and notification layout")
    func practiceAppearance() throws {
        let pictures = try pictures(); defer { cleanup(pictures) }
        let cards = pilot(pictures).units[0].lessons[0].cards
        for scheme in [ColorScheme.light, .dark] {
            for size in [DynamicTypeSize.large, .accessibility3] {
                for compact in [false, true] {
                    for card in cards {
                        let view = CourseQuestionPanel(card: card, immersive: !compact, onAnswer: { _ in })
                            .environment(\.colorScheme, scheme).environment(\.dynamicTypeSize, size)
                            .environment(\.courseNotificationCompact, compact).padding(20).frame(width: compact ? 320 : 390)
                            .background(scheme == .dark ? Color.black : Color.white)
                        let renderer = ImageRenderer(content: view)
                        let image = try #require(renderer.uiImage)
                        #expect(image.size.height > 0)
                        if size == .accessibility3 && card.id == "sentence" { #expect(image.size.height > 150) }
                        Attachment.record(image, named: "practice-\(card.id)-\(scheme)-\(size)-\(compact ? "notification" : "app")", as: .png)
                    }
                }
            }
        }
    }
}

private final class CoursePilotTestBundleMarker: NSObject {}


@MainActor
@Suite("Independent review repairs")
struct CourseReviewRepairTests {
    private func card(_ id: String, exposure: Bool = false, changed: Bool = false) -> CourseLessonCard {
        var activity = CourseActivity(kind: exposure ? .teach : .placeTokens, sequence: exposure ? 0 : 1, example: exposure ? "el libro · a book" : nil,
            tokens: [changed ? "el" : "un", "libro"], slots: [changed ? "el" : "un", "libro"])
        activity.exercise = .init(format: exposure ? "exposure" : "wordBank", vocabularyIDs: ["book"], conceptIDs: ["book"],
            tiles: exposure ? nil : [.init(id: "article", text: changed ? "el" : "un"), .init(id: "noun", text: "libro")],
            acceptedOrders: exposure ? nil : [[changed ? "el" : "un", "libro"]])
        return .init(id: id, question: "Book", correctAnswer: exposure ? "el libro" : "un libro", cardType: exposure ? "vocabulary" : "tokenPlacement", activity: activity)
    }
    private func course(_ cards: [CourseLessonCard], checkpoint: Bool = false) -> CourseDefinition {
        .init(id: "repair-fixture", title: "Repair", language: "Spanish", flagEmoji: "🇪🇸", levelTag: "", colorHex: "#123456", summary: "", estimatedHours: 1, outcomes: [], units: [
            .init(id: "unit", unitNumber: 1, title: "Unit", subtitle: "", colorHex: "#123456", badgeIcon: "book", lessons: [
                .init(id: "lesson", lessonNumber: 1, title: "Lesson", subtitle: "", cards: checkpoint ? [.init(id: "study", question: "Study", correctAnswer: "Study", cardType: "vocabulary")] : cards)
            ], checkpointQuiz: checkpoint ? .init(id: "checkpoint", title: "Check", summary: "", questions: cards, keyConcepts: []) : nil)
        ])
    }
    private func prepared(_ card: CourseLessonCard, snapshot: inout CourseLearningSnapshot, courseID: String, correct: Bool = true) throws -> CourseExerciseState {
        let exercise = try #require(card.activity?.exercise)
        var state = CourseExerciseState()
        for tile in correct ? (exercise.tiles ?? []) : Array((exercise.tiles ?? []).reversed()) {
            state.append(tile.id, exercise: exercise)
            #expect(snapshot.saveExercise(courseID: courseID, cardID: card.id, exercise: exercise, state: state) == true)
        }
        _ = state.submit(exercise)
        #expect(snapshot.saveExercise(courseID: courseID, cardID: card.id, exercise: exercise, state: state) == true)
        return state
    }
    @Test("App Continue acknowledges the matching notification without leaving phantom feedback")
    func sharedContinueIdentity() throws {
        let card = card("a"), course = course([card]); var snapshot = CourseLearningSnapshot()
        let opened = snapshot.resumePractice(course: course, lessonId: "lesson", checkpointUnitId: nil)
        let session = try #require(opened)
        _ = try prepared(card, snapshot: &snapshot, courseID: course.id)
        #expect(snapshot.answerPractice(course: course, lessonId: "lesson", checkpointUnitId: nil, sessionId: session.id, cardId: card.id, correct: true) == true)
        snapshot.notificationExerciseCardIDs[course.id] = card.id
        #expect(snapshot.continueExercise(courseID: course.id, lessonID: "lesson", checkpointID: nil, sessionID: session.id, cardID: card.id) == true)
        #expect(snapshot.notificationExerciseCardIDs[course.id] == nil)
    }
    @Test("Completed exposures do not become due retrieval or prevent automatic stopping")
    func exposureReviewEligibility() throws {
        let intro = card("intro", exposure: true), retrieval = card("retrieve"), course = course([intro, retrieval])
        var snapshot = CourseLearningSnapshot()
        for card in [intro, retrieval] {
            _ = try prepared(card, snapshot: &snapshot, courseID: course.id)
            #expect(snapshot.answer(course: course, lessonId: "lesson", cardId: card.id, correct: true, token: card.id) == true)
        }
        var srs = CourseCardSRSRecord(cardId: retrieval.id)
        for _ in 0..<3 { srs.processAnswer(isCorrect: true) }
        srs.nextReviewDate = .distantFuture
        snapshot.courseSRS[course.id]?[retrieval.id] = srs
        #expect(snapshot.batch(course: course, count: 60, reviewOnly: true).isEmpty)
        #expect(!CourseNotificationProgress.practiceCards(course: course, snapshot: snapshot).contains { $0.id == intro.id })
        #expect(snapshot.isFullyMastered(course: course))
        #expect(snapshot.srsRecord(courseId: course.id, cardId: intro.id) == nil)
        #expect(snapshot.progress[course.id]?["lesson"]?.masteredCardIds.contains(intro.id) == true)
    }
    @Test("Removing pending feedback allows lesson and checkpoint sessions to finish")
    func removedPendingCard() throws {
        for checkpoint in [false, true] {
            let first = card("a"), original = course([first], checkpoint: checkpoint)
            var snapshot = CourseLearningSnapshot()
            if checkpoint { snapshot.progress[original.id] = ["lesson": .init(status: .completed)] }
            let opened = snapshot.resumePractice(course: original, lessonId: checkpoint ? nil : "lesson", checkpointUnitId: checkpoint ? "unit" : nil)
            let session = try #require(opened)
            _ = try prepared(first, snapshot: &snapshot, courseID: original.id)
            #expect(snapshot.answerPractice(course: original, lessonId: checkpoint ? nil : "lesson", checkpointUnitId: checkpoint ? "unit" : nil, sessionId: session.id, cardId: first.id, correct: true) == true)
            let replacement = CourseLessonCard(id: "b", question: "B", options: ["Yes", "No"], correctAnswer: "Yes")
            let updated = course([replacement], checkpoint: checkpoint)
            let resumed = snapshot.resumePractice(course: updated, lessonId: checkpoint ? nil : "lesson", checkpointUnitId: checkpoint ? "unit" : nil)
            #expect(resumed?.pendingContinueCardID == nil)
            #expect(snapshot.exerciseDrafts[CourseLearningSnapshot.exerciseKey(courseID: original.id, cardID: first.id)] == nil)
            #expect(snapshot.answerPractice(course: updated, lessonId: checkpoint ? nil : "lesson", checkpointUnitId: checkpoint ? "unit" : nil, sessionId: session.id, cardId: "b", correct: true) == true)
            let completion = snapshot.finishPractice(course: updated, lessonId: checkpoint ? nil : "lesson", checkpointUnitId: checkpoint ? "unit" : nil, sessionId: session.id)
            #expect(completion != nil)
            #expect(snapshot.exerciseEvidence.count == 1)
        }
    }
    @Test("Upgrade commits imported legacy identity and detects later rollback writes")
    func legacyDivergence() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let legacy = directory.appendingPathComponent("course-learning-v1.json")
        var old = CourseLearningSnapshot(); old.traceAttempts["before"] = 1
        try JSONEncoder().encode(old).write(to: legacy)
        let store = CourseLearningStore(directory: directory, defaults: nil)
        #expect(store.transaction { $0.traceAttempts["new-client"] = 2; return true } == true)
        old.traceAttempts["rollback"] = 3; try JSONEncoder().encode(old).write(to: legacy)
        _ = store.snapshot()
        let active = try JSONSerialization.jsonObject(with: Data(contentsOf: directory.appendingPathComponent("course-learning-v2.json"))) as? [String: Any]
        #expect(active?["migration"] != nil)
        #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent("CourseProgressRecovery").path))
        #expect(store.snapshot().traceAttempts["new-client"] == 2)
        #expect(store.snapshot().traceAttempts["rollback"] == nil)
    }
    @Test("Both Continue orders and a stale alert preserve a newer partial attempt across relaunch")
    func bothHostContinueOrders() throws {
        for notificationFirst in [false, true] {
            let card = card("a"), course = course([card]); var snapshot = CourseLearningSnapshot()
            let opened = snapshot.resumePractice(course: course, lessonId: "lesson", checkpointUnitId: nil)
            let session = try #require(opened)
            let first = try prepared(card, snapshot: &snapshot, courseID: course.id)
            #expect(snapshot.answerPractice(course: course, lessonId: "lesson", checkpointUnitId: nil, sessionId: session.id, cardId: card.id, correct: true, exerciseAttemptID: first.attemptID) == true)
            #expect(snapshot.answerNotificationExercise(course: course, lessonID: "lesson", cardID: card.id, correct: true, token: "alert", attemptID: first.attemptID) == true)
            #expect(snapshot.progress[course.id]?["lesson"]?.totalAttemptsCount == 1)
            if notificationFirst { #expect(snapshot.acknowledgeExercise(courseID: course.id, cardID: card.id, attemptID: first.attemptID) == true) }
            else { #expect(snapshot.continueExercise(courseID: course.id, lessonID: "lesson", checkpointID: nil, sessionID: session.id, cardID: card.id, attemptID: first.attemptID) == true) }
            snapshot = try JSONDecoder().decode(CourseLearningSnapshot.self, from: JSONEncoder().encode(snapshot))
            let resumed = snapshot.resumePractice(course: course, lessonId: "lesson", checkpointUnitId: nil)
            #expect(resumed?.pendingContinueCardID == nil)
            #expect(resumed?.nextIndex == nil)
            #expect(snapshot.resumeNotificationExercise(course: course) == nil)
            var next = CourseExerciseState()
            let exercise = try #require(card.activity?.exercise)
            next.append("article", exercise: exercise)
            #expect(snapshot.saveExercise(courseID: course.id, cardID: card.id, exercise: exercise, state: next) == true)
            if notificationFirst { #expect(snapshot.continueExercise(courseID: course.id, lessonID: "lesson", checkpointID: nil, sessionID: session.id, cardID: card.id, attemptID: first.attemptID) == true) }
            else { #expect(snapshot.acknowledgeExercise(courseID: course.id, cardID: card.id, attemptID: first.attemptID) == true) }
            #expect(snapshot.exerciseDrafts[CourseLearningSnapshot.exerciseKey(courseID: course.id, cardID: card.id)]?.state == next)
            #expect(snapshot.progress[course.id]?["lesson"]?.totalAttemptsCount == 1)
            #expect(snapshot.exerciseEvidence.count == 1)
        }
    }
    @Test("Changed pending exercises retire feedback while additions preserve valid Continue and answers")
    func pendingRevisionReconciliation() throws {
        for change in [false, true] {
            let originalCard = card("a")
            let b = CourseLessonCard(id: "b", question: "B", options: ["Yes", "No"], correctAnswer: "Yes")
            let original = course([originalCard, b]); var snapshot = CourseLearningSnapshot()
            let opened = snapshot.resumePractice(course: original, lessonId: "lesson", checkpointUnitId: nil)
            let session = try #require(opened)
            let first = try prepared(originalCard, snapshot: &snapshot, courseID: original.id)
            #expect(snapshot.answerPractice(course: original, lessonId: "lesson", checkpointUnitId: nil, sessionId: session.id, cardId: "a", correct: true) == true)
            let key = try #require(CourseLearningSnapshot.practiceKey(courseId: original.id, lessonId: "lesson", checkpointUnitId: nil))
            // A surviving wrong answer from an earlier partial session must stay intact.
            snapshot.practiceSessions[key]?.answers["b"] = false
            let updated = course([card("a", changed: change), b, .init(id: "c", question: "C", options: ["Yes", "No"], correctAnswer: "Yes")])
            let resumed = snapshot.resumePractice(course: updated, lessonId: "lesson", checkpointUnitId: nil)
            #expect(resumed?.answers["b"] == false)
            if change {
                #expect(resumed?.pendingContinueCardID == nil)
                #expect(resumed?.answers["a"] == nil)
                #expect(snapshot.exerciseDrafts[CourseLearningSnapshot.exerciseKey(courseID: original.id, cardID: "a")] == nil)
                let again = snapshot.resumePractice(course: updated, lessonId: "lesson", checkpointUnitId: nil)
                #expect(again?.answers["a"] == nil)
            } else {
                #expect(resumed?.pendingContinueAttemptID == first.attemptID)
                #expect(resumed?.answers["a"] == true)
                #expect(snapshot.exerciseDrafts[CourseLearningSnapshot.exerciseKey(courseID: original.id, cardID: "a")]?.state == first)
            }
            #expect(snapshot.exerciseEvidence[first.attemptID] != nil)
            #expect(snapshot.progress[original.id]?["lesson"]?.masteredCardIds.contains("a") == true)
        }
    }
    private func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    @Test("Rollback branches export exact histories without combining counters, events or SRS")
    func recoveryBranchesAndExport() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let v1 = directory.appendingPathComponent("course-learning-v1.json")
        var old = CourseLearningSnapshot(); old.traceAttempts["old"] = 1; old.eventTokens = ["original"]
        old.courseSRS["course"] = ["card": CourseCardSRSRecord(cardId: "card")]
        let imported = try JSONEncoder().encode(old); try imported.write(to: v1)
        let first = CourseLearningStore(directory: directory, defaults: nil)
        #expect(first.transaction { $0.traceAttempts["new"] = 2; $0.eventTokens.append("new"); return true } == true)
        #expect(first.snapshot().migration?.imported?.v1SHA256 == hash(imported))
        let second = CourseLearningStore(directory: directory, defaults: nil)
        var branches: [Data] = []
        for value in [3, 4] {
            old.traceAttempts["rollback"] = value; old.eventTokens.append("old-\(value)")
            old.courseSRS["course"]?["card"]?.processAnswer(isCorrect: true)
            let bytes = try JSONEncoder().encode(old); branches.append(bytes); try bytes.write(to: v1, options: .atomic)
            let active = second.snapshot()
            #expect(active.traceAttempts["new"] == 2)
            #expect(active.traceAttempts["rollback"] == nil)
            #expect(active.eventTokens == ["original", "new"])
            #expect(active.courseSRS["course"]?["card"]?.masteryScore == 0)
            #expect(active.progressRecoveryNotice != nil)
            #expect(second.transaction { $0.traceAttempts["interleaved-new"] = value; return true } == true)
        }
        #expect(first.snapshot().migration?.divergences.count == 2)
        #expect(first.snapshot().schemaVersion == 5)
        let export = try JSONDecoder().decode(CourseProgressRecoveryExport.self, from: second.recoveryExportData())
        #expect(export.olderHistory == branches.last)
        #expect(export.archives.values.contains(imported))
        for branch in branches { #expect(export.archives.values.contains(branch)) }
        let active = try JSONDecoder().decode(CourseLearningSnapshot.self, from: #require(export.activeHistory))
        #expect(active.eventTokens == ["original", "new"])
        #expect(active.traceAttempts["rollback"] == nil)
        #expect(try Data(contentsOf: directory.appendingPathComponent("course-learning-v1.pre-practice.json")) == imported)
    }
    @Test("Defaults-only imports detect older writes and omit unrelated secrets from recovery")
    func defaultsRecovery() throws {
        let id = "recovery-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: id))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(id)
        defer { defaults.removePersistentDomain(forName: id); try? FileManager.default.removeItem(at: directory) }
        let key = "course_progress_retired-course"
        defaults.set(try JSONEncoder().encode(["lesson": CourseLessonProgressRecord(status: .completed, correctAnswersCount: 1, totalAttemptsCount: 1, masteredCardIds: ["old"])]), forKey: key)
        defaults.set("must-not-export", forKey: "account_secret")
        let store = CourseLearningStore(directory: directory, defaults: defaults)
        #expect(store.transaction { $0.traceAttempts["new"] = 2; return true } == true)
        #expect(store.snapshot().migration?.imported?.v1SHA256 == nil)
        defaults.set(try JSONEncoder().encode(["lesson": CourseLessonProgressRecord(status: .completed, correctAnswersCount: 9, totalAttemptsCount: 9, masteredCardIds: ["old", "rollback"])]), forKey: key)
        let changed = store.snapshot()
        #expect(changed.migration?.divergences.count == 1)
        #expect(changed.progress["retired-course"]?["lesson"]?.correctAnswersCount == 1)
        var legacy = CourseLearningSnapshot(); legacy.traceAttempts["rollback"] = 3
        let legacyData = try JSONEncoder().encode(legacy)
        try legacyData.write(to: directory.appendingPathComponent("course-learning-v1.json"), options: .atomic)
        #expect(store.snapshot().migration?.divergences.count == 2)
        let manager = CourseProgressManager(defaults: defaults, learningStore: store)
        #expect(manager.progressRecoveryNotice != nil)
        let url = try manager.exportProgressRecovery(); defer { try? FileManager.default.removeItem(at: url) }
        let exported = try JSONDecoder().decode(CourseProgressRecoveryExport.self, from: Data(contentsOf: url))
        #expect(exported.olderHistory == legacyData)
        let keys = try JSONDecoder().decode([String: Data].self, from: exported.olderDefaults).keys
        #expect(Set(keys) == [key])
        #expect(store.snapshot().traceAttempts["new"] == 2)
        #expect(store.snapshot().traceAttempts["rollback"] == nil)
    }
    @Test("Interrupted installs commit source identity with history or retry current legacy bytes")
    func interruptedMigration() throws {
        for before in [true, false] {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: directory) }
            let v1 = directory.appendingPathComponent("course-learning-v1.json")
            var old = CourseLearningSnapshot(); old.traceAttempts["before"] = 1
            try JSONEncoder().encode(old).write(to: v1)
            let interrupted = CourseLearningStore(directory: directory, defaults: nil, commitObserver: { stage in
                switch stage {
                case .beforeInstall: if before { throw CocoaError(.fileWriteUnknown) }
                case .afterInstall: if !before { throw CocoaError(.fileWriteUnknown) }
                }
            })
            #expect(interrupted.transaction { $0.traceAttempts["new"] = 2; return true } == nil)
            #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent("course-learning-v2.json").path) == !before)
            old.traceAttempts["rollback"] = 3
            let latest = try JSONEncoder().encode(old); try latest.write(to: v1, options: .atomic)
            let reopened = CourseLearningStore(directory: directory, defaults: nil).snapshot()
            if before {
                #expect(reopened.traceAttempts["rollback"] == 3)
                #expect(reopened.traceAttempts["new"] == nil)
                #expect(reopened.migration?.imported?.v1SHA256 == hash(latest))
                #expect(reopened.migration?.divergences.isEmpty == true)
            } else {
                #expect(reopened.traceAttempts["new"] == 2)
                #expect(reopened.traceAttempts["rollback"] == nil)
                #expect(reopened.migration?.divergences.count == 1)
            }
        }
    }
    @Test("Corrupt older branches remain exportable and future active schemas are never overwritten")
    func corruptAndFutureRecovery() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CourseLearningStore(directory: directory, defaults: nil)
        #expect(store.transaction { $0.traceAttempts["active"] = 1; return true } == true)
        let corrupt = Data("corrupt older history".utf8), v1 = directory.appendingPathComponent("course-learning-v1.json")
        try corrupt.write(to: v1)
        let state = store.snapshot()
        #expect(store.lastError == nil)
        #expect(state.traceAttempts["active"] == 1)
        #expect(state.migration?.divergences.last?.reason == "unreadableOlderVersionFile")
        let export = try JSONDecoder().decode(CourseProgressRecoveryExport.self, from: store.recoveryExportData())
        #expect(export.olderHistory == corrupt)
        #expect(export.archives.values.contains(corrupt))
        let future = Data("{\"schemaVersion\":6}".utf8), v2 = directory.appendingPathComponent("course-learning-v2.json")
        try future.write(to: v2)
        #expect(store.transaction { $0.traceAttempts.removeAll(); return true } == nil)
        #expect(try Data(contentsOf: v2) == future)
        let protected = try JSONDecoder().decode(CourseProgressRecoveryExport.self, from: store.recoveryExportData())
        #expect(protected.activeHistory == future)
        #expect(protected.olderHistory == corrupt)
        #expect(protected.readError != nil)
    }

    @Test("API accepted exercise fixture round-trips through native Codable including inactive optional fields")
    func sharedAPIFixtureDecoding() throws {
        let bundle = Bundle(for: CoursePilotTestBundleMarker.self)
        let url = try #require(bundle.url(forResource: "practice-contract-valid", withExtension: "json"))
        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode(CourseDefinition.self, from: data)
        #expect(try JSONDecoder().decode(CourseDefinition.self, from: JSONEncoder().encode(decoded)) == decoded)
        #expect(decoded.units[0].lessons[0].cards[0].activity?.exercise?.tiles == [])
        #expect(decoded.units[0].lessons[0].cards[1].activity?.exercise?.pictures == nil)
        var root = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        for malformedPicture in [true, false] {
            var units = try #require(root["units"] as? [[String: Any]])
            var lessons = try #require(units[0]["lessons"] as? [[String: Any]])
            var cards = try #require(lessons[0]["cards"] as? [[String: Any]])
            let index = malformedPicture ? 1 : 0
            var activity = try #require(cards[index]["activity"] as? [String: Any])
            var exercise = try #require(activity["exercise"] as? [String: Any])
            if malformedPicture { exercise["pictures"] = "invalid" }
            else { exercise["tiles"] = [["id": 1, "text": false]] }
            activity["exercise"] = exercise; cards[index]["activity"] = activity
            lessons[0]["cards"] = cards; units[0]["lessons"] = lessons; root["units"] = units
            let bad = try JSONSerialization.data(withJSONObject: root)
            #expect(throws: (any Error).self) { try JSONDecoder().decode(CourseDefinition.self, from: bad) }
            root = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        }
    }

    @Test("Detected rollback warning renders readable recovery actions in light dark and large text")
    func recoveryBannerAppearance() throws {
        let id = "recovery-ui-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: id))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(id)
        defer { defaults.removePersistentDomain(forName: id); try? FileManager.default.removeItem(at: directory) }
        let store = CourseLearningStore(directory: directory, defaults: defaults)
        #expect(store.transaction { $0.traceAttempts["active"] = 1; return true } == true)
        var old = CourseLearningSnapshot(); old.traceAttempts["rollback"] = 2
        try JSONEncoder().encode(old).write(to: directory.appendingPathComponent("course-learning-v1.json"))
        let manager = CourseProgressManager(defaults: defaults, learningStore: store)
        #expect(manager.progressRecoveryNotice?.contains("has not been added") == true)
        for scheme in [ColorScheme.light, .dark] {
            var regularHeight: CGFloat = 0
            for size in [DynamicTypeSize.large, .accessibility3] {
                let view = CourseProgressRecoveryBanner(manager: manager)
                    .environment(\.colorScheme, scheme).environment(\.dynamicTypeSize, size).frame(width: 390)
                let image = try #require(ImageRenderer(content: view).uiImage)
                #expect(image.size.height >= 44)
                if size == .large { regularHeight = image.size.height }
                else { #expect(image.size.height > regularHeight) }
                Attachment.record(image, named: "recovery-warning-\(scheme)-\(size)", as: .png)
            }
        }
    }

    @Test("An unqualified old notification marker cannot claim a newer graded app attempt")
    func unqualifiedNotificationMarker() throws {
        let card = card("a"), course = course([card]); var snapshot = CourseLearningSnapshot()
        let opened = snapshot.resumePractice(course: course, lessonId: "lesson", checkpointUnitId: nil)
        let session = try #require(opened)
        let first = try prepared(card, snapshot: &snapshot, courseID: course.id)
        #expect(snapshot.answerPractice(course: course, lessonId: "lesson", checkpointUnitId: nil, sessionId: session.id, cardId: card.id, correct: true) == true)
        #expect(snapshot.continueExercise(courseID: course.id, lessonID: "lesson", checkpointID: nil, sessionID: session.id, cardID: card.id, attemptID: first.attemptID) == true)
        snapshot.notificationExerciseCardIDs[course.id] = card.id // pre-repair leftover: no attempt identity
        let newer = try prepared(card, snapshot: &snapshot, courseID: course.id)
        #expect(snapshot.answer(course: course, lessonId: "lesson", cardId: card.id, correct: true, token: "new-app-attempt", exerciseAttemptID: newer.attemptID) == true)
        let pending = snapshot.resumeNotificationExercise(course: course)
        #expect(pending == nil)
        #expect(snapshot.notificationExerciseCardIDs[course.id] == nil)
        #expect(snapshot.exerciseDrafts[CourseLearningSnapshot.exerciseKey(courseID: course.id, cardID: card.id)]?.state == newer)
        #expect(snapshot.exerciseEvidence.count == 2)
    }

    @Test("Interrupted app grading survives notification Continue without replaying credit")
    func interruptedCrossHostGrade() throws {
        for (delayed, correct) in [(false, true), (true, true), (false, false), (true, false)] {
            let card = card("interrupted"), course = course([card])
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: directory) }
            let app = CourseLearningStore(directory: directory, defaults: nil)
            let notification = CourseLearningStore(directory: directory, defaults: nil)
            let opened = app.transaction { $0.resumePractice(course: course, lessonId: "lesson", checkpointUnitId: nil) }
            let session = try #require(opened ?? nil)
            let persisted = app.transaction { state in try? prepared(card, snapshot: &state, courseID: course.id, correct: correct) }
            let check = try #require(persisted ?? nil)
            // App persisted Check, then died before its parent recorded the session answer.
            let graded = notification.transaction { $0.answerNotificationExercise(course: course, lessonID: "lesson", cardID: card.id, correct: correct, token: "notification", attemptID: check.attemptID) }
            #expect(graded == true)
            let acknowledged = notification.transaction { $0.acknowledgeExercise(courseID: course.id, cardID: card.id, attemptID: check.attemptID) }
            #expect(acknowledged == true)
            let relaunched = CourseLearningStore(directory: directory, defaults: nil)
            if delayed {
                let callback = relaunched.transaction { $0.answerPractice(course: course, lessonId: "lesson", checkpointUnitId: nil, sessionId: session.id, cardId: card.id, correct: correct, exerciseAttemptID: check.attemptID) }
                #expect(callback == true)
                let contradictory = relaunched.transaction { $0.answerPractice(course: course, lessonId: "lesson", checkpointUnitId: nil, sessionId: session.id, cardId: card.id, correct: !correct, exerciseAttemptID: check.attemptID) }
                #expect(contradictory == false)
            }
            let restored = relaunched.transaction { $0.resumePractice(course: course, lessonId: "lesson", checkpointUnitId: nil) }
            let resumed = try #require(restored ?? nil)
            #expect(resumed.nextIndex == nil)
            #expect(resumed.answers[card.id] == correct)
            #expect(resumed.pendingContinueCardID == nil)
            let snapshot = relaunched.snapshot()
            #expect(snapshot.exerciseEvidence.count == 1)
            #expect(snapshot.srsRecord(courseId: course.id, cardId: card.id)?.reviewCount == 1)
            #expect(snapshot.progress[course.id]?["lesson"]?.totalAttemptsCount == 1)
            let finished = relaunched.transaction { $0.finishPractice(course: course, lessonId: "lesson", checkpointUnitId: nil, sessionId: session.id) != nil }
            #expect(finished == true)
        }
    }

    @Test("Unknown exercise fallback advances consecutive review and notification cards without modern credit")
    func unsupportedFallbackContinue() throws {
        var future = try #require(card("future").activity)
        future.exercise?.format = "futureExercise"
        let first = CourseLessonCard(id: "future-a", question: "Book", correctAnswer: "un libro", cardType: "tokenPlacement", activity: future)
        let second = CourseLessonCard(id: "future-b", question: "Book", correctAnswer: "un libro", cardType: "tokenPlacement", activity: future)
        let course = course([first, second]); var snapshot = CourseLearningSnapshot()
        for (index, card) in [first, second].enumerated() {
            #expect(card.activity?.exercise?.usesPracticeRenderer == false)
            let result6 = snapshot.answerNotificationExercise(course: course, lessonID: "lesson", cardID: card.id, correct: true, token: "alert-\(index)", attemptID: nil); #expect(result6)
            let result7 = snapshot.acknowledgeRenderedExercise(courseID: course.id, card: card, attemptID: nil); #expect(result7)
            let result8 = snapshot.answer(course: course, lessonId: "lesson", cardId: card.id, correct: true, token: "review-\(index)"); #expect(result8)
            let result9 = snapshot.acknowledgeRenderedExercise(courseID: course.id, card: card, attemptID: nil); #expect(result9)
        }
        #expect(snapshot.exerciseEvidence.isEmpty && snapshot.exerciseDrafts.isEmpty)
        let result10 = !snapshot.acknowledgeRenderedExercise(courseID: course.id, card: card("known"), attemptID: nil); #expect(result10)
    }

    @Test("Interrupted Check receipts cannot cross definitions, replacement sessions or newer drafts")
    func interruptedReceiptIsolation() throws {
        for mutation in ["definition", "session", "newDraft"] {
            let card = card("isolation"), course = course([card]); var snapshot = CourseLearningSnapshot()
            let opened = snapshot.resumePractice(course: course, lessonId: "lesson", checkpointUnitId: nil)
            let session = try #require(opened)
            let check = try prepared(card, snapshot: &snapshot, courseID: course.id)
            let graded = snapshot.answerNotificationExercise(course: course, lessonID: "lesson", cardID: card.id, correct: true, token: "notification", attemptID: check.attemptID)
            #expect(graded)
            let key = course.id + ":lesson:lesson"
            if mutation == "definition" {
                snapshot.practiceSessions[key]?.exerciseDefinitionsByCard?[card.id] = self.card(card.id, changed: true).activity?.exercise
            } else if mutation == "session" {
                snapshot.practiceSessions[key]?.id = UUID().uuidString
            } else {
                // First host clears Check and starts another attempt; the old
                // callback must neither acknowledge nor credit the newer one.
                let acknowledged = snapshot.acknowledgeExercise(courseID: course.id, cardID: card.id, attemptID: check.attemptID)
                #expect(acknowledged)
                var next = CourseExerciseState()
                let exercise = try #require(card.activity?.exercise)
                next.append("article", exercise: exercise)
                let saved = snapshot.saveExercise(courseID: course.id, cardID: card.id, exercise: exercise, state: next)
                #expect(saved)
                let delayed = snapshot.answerPractice(course: course, lessonId: "lesson", checkpointUnitId: nil, sessionId: session.id, cardId: card.id, correct: true, exerciseAttemptID: check.attemptID)
                #expect(!delayed)
                let stale = snapshot.acknowledgeExercise(courseID: course.id, cardID: card.id, attemptID: check.attemptID)
                #expect(stale)
                #expect(snapshot.exerciseDrafts[CourseLearningSnapshot.exerciseKey(courseID: course.id, cardID: card.id)]?.state == next)
                continue
            }
            let acknowledged = snapshot.acknowledgeExercise(courseID: course.id, cardID: card.id, attemptID: check.attemptID)
            #expect(acknowledged)
            #expect(snapshot.practiceSessions[key]?.answers[card.id] == nil)
            #expect(snapshot.srsRecord(courseId: course.id, cardId: card.id)?.reviewCount == 1)
        }
    }

    @Test("Current Check ownership survives old-answer invalidation across interleavings")
    func currentDefinitionOwnershipMatrix() throws {
        let cases = ["unchanged", "changed", "changedAfterAnswer", "removed", "session", "newDraft", "lateSession", "oldDefinition", "oldReceipt"]
        for scenario in cases { for correct in [true, false] { for delayed in [true, false] {
            let original = card("matrix"), originalCourse = course([original])
            var current = original, currentCourse = originalCourse
            var snapshot = CourseLearningSnapshot()
            var opened = snapshot.resumePractice(course: currentCourse, lessonId: "lesson", checkpointUnitId: nil)
            if scenario == "changedAfterAnswer" {
                let old = try prepared(original, snapshot: &snapshot, courseID: currentCourse.id)
                let recorded = snapshot.answerPractice(course: currentCourse, lessonId: "lesson", checkpointUnitId: nil, sessionId: opened!.id, cardId: original.id, correct: true, exerciseAttemptID: old.attemptID)
                #expect(recorded)
            }
            if scenario == "changed" || scenario == "changedAfterAnswer" {
                current = card("matrix", changed: true); currentCourse = course([current])
                opened = snapshot.resumePractice(course: currentCourse, lessonId: "lesson", checkpointUnitId: nil)
                #expect(snapshot.practiceSessions[currentCourse.id + ":lesson:lesson"]?.invalidatedExerciseCardIDs?.contains(current.id) == true)
            }
            let session = try #require(opened)
            if scenario == "lateSession" { snapshot.practiceSessions.removeAll() }
            let check = try prepared(current, snapshot: &snapshot, courseID: currentCourse.id, correct: correct)
            let graded = snapshot.answerNotificationExercise(course: currentCourse, lessonID: "lesson", cardID: current.id, correct: correct, token: "notification", attemptID: check.attemptID)
            #expect(graded)
            if scenario == "oldReceipt" {
                let earlier = snapshot.acknowledgeExercise(courseID: currentCourse.id, cardID: current.id, attemptID: check.attemptID)
                #expect(earlier)
            }
            if scenario == "removed" {
                currentCourse = course([card("replacement")])
                _ = snapshot.resumePractice(course: currentCourse, lessonId: "lesson", checkpointUnitId: nil)
            } else if scenario == "session" {
                snapshot.practiceSessions[currentCourse.id + ":lesson:lesson"]?.id = UUID().uuidString
            } else if scenario == "lateSession" {
                _ = snapshot.resumePractice(course: currentCourse, lessonId: "lesson", checkpointUnitId: nil)
            } else if scenario == "oldDefinition" || scenario == "oldReceipt" {
                currentCourse = course([card("matrix", changed: true)])
                _ = snapshot.resumePractice(course: currentCourse, lessonId: "lesson", checkpointUnitId: nil)
                // Reverting metadata does not resurrect the former Check owner.
                currentCourse = originalCourse
                _ = snapshot.resumePractice(course: currentCourse, lessonId: "lesson", checkpointUnitId: nil)
            }
            let acknowledged = snapshot.acknowledgeExercise(courseID: currentCourse.id, cardID: current.id, attemptID: check.attemptID)
            #expect(acknowledged)
            var newer: CourseExerciseState?
            if scenario == "newDraft" {
                let exercise = try #require(current.activity?.exercise)
                var state = CourseExerciseState(); state.append("article", exercise: exercise)
                let saved = snapshot.saveExercise(courseID: currentCourse.id, cardID: current.id, exercise: exercise, state: state)
                #expect(saved); newer = state
            }
            let shouldReconcile = ["unchanged", "changed", "changedAfterAnswer", "newDraft"].contains(scenario)
            let shouldAcceptCallback = ["unchanged", "changed", "changedAfterAnswer"].contains(scenario)
            if delayed {
                let callback = snapshot.answerPractice(course: currentCourse, lessonId: "lesson", checkpointUnitId: nil, sessionId: session.id, cardId: current.id, correct: correct, exerciseAttemptID: check.attemptID)
                #expect(callback == shouldAcceptCallback)
                let contradictory = snapshot.answerPractice(course: currentCourse, lessonId: "lesson", checkpointUnitId: nil, sessionId: session.id, cardId: current.id, correct: !correct, exerciseAttemptID: check.attemptID)
                #expect(!contradictory)
            }
            snapshot = try JSONDecoder().decode(CourseLearningSnapshot.self, from: JSONEncoder().encode(snapshot))
            let resumed = snapshot.resumePractice(course: currentCourse, lessonId: "lesson", checkpointUnitId: nil)
            let stored = try #require(resumed)
            if shouldReconcile {
                #expect(stored.answers[current.id] == correct)
                #expect(stored.attemptCounts?[current.id] == (scenario == "changedAfterAnswer" ? 2 : 1))
                #expect(stored.invalidatedExerciseCardIDs?.contains(current.id) != true)
                #expect(stored.nextIndex == nil)
            } else {
                #expect(stored.answers[current.id] == nil)
                #expect(stored.attemptCounts?[current.id] == (scenario == "oldReceipt" ? 1 : nil))
            }
            if let newer { #expect(snapshot.exerciseDrafts[CourseLearningSnapshot.exerciseKey(courseID: currentCourse.id, cardID: current.id)]?.state == newer) }
            #expect(snapshot.exerciseEvidence.count == (scenario == "changedAfterAnswer" ? 2 : 1))
            #expect(snapshot.exerciseEvidence[check.attemptID]?.correct == correct)
            #expect(snapshot.progress[currentCourse.id]?["lesson"]?.totalAttemptsCount == (scenario == "changedAfterAnswer" ? 2 : 1))
            #expect(snapshot.srsRecord(courseId: currentCourse.id, cardId: current.id)?.reviewCount == (scenario == "changedAfterAnswer" ? 2 : 1))
        } } }
    }

    @Test("A retired one-step Check cannot reacquire ownership when a definition reverts")
    func retiredCheckCannotReacquireOwnership() throws {
        for credited in [true, false] {
            let original = card("one-step", exposure: true), originalCourse = course([original])
            var revisedActivity = try #require(original.activity)
            revisedActivity.exercise?.conceptIDs = ["revised-concept"]
            let revised = CourseLessonCard(id: original.id, question: "Book", correctAnswer: "el libro", cardType: "vocabulary", activity: revisedActivity)
            var snapshot = CourseLearningSnapshot()
            _ = snapshot.resumePractice(course: originalCourse, lessonId: "lesson", checkpointUnitId: nil)
            let exercise = try #require(original.activity?.exercise)
            var oldCheck = CourseExerciseState(); _ = oldCheck.submit(exercise)
            let saved = snapshot.saveExercise(courseID: originalCourse.id, cardID: original.id, exercise: exercise, state: oldCheck)
            #expect(saved && oldCheck.revision == 1)
            if credited {
                let graded = snapshot.answerNotificationExercise(course: originalCourse, lessonID: "lesson", cardID: original.id, correct: true, token: "old", attemptID: oldCheck.attemptID)
                #expect(graded)
            }
            _ = snapshot.resumePractice(course: course([revised]), lessonId: "lesson", checkpointUnitId: nil)
            let revisedExercise = try #require(revised.activity?.exercise)
            var replacement = CourseExerciseState(); _ = replacement.submit(revisedExercise)
            let replaced = snapshot.saveExercise(courseID: originalCourse.id, cardID: original.id, exercise: revisedExercise, state: replacement)
            #expect(replaced)
            _ = snapshot.resumePractice(course: originalCourse, lessonId: "lesson", checkpointUnitId: nil)
            let resurrected = snapshot.saveExercise(courseID: originalCourse.id, cardID: original.id, exercise: exercise, state: oldCheck)
            #expect(!resurrected)
            #expect(snapshot.exerciseDrafts[CourseLearningSnapshot.exerciseKey(courseID: originalCourse.id, cardID: original.id)]?.state == replacement)
            #expect(snapshot.exerciseEvidence.count == (credited ? 1 : 0))
            // A genuinely new Check for the current definition remains eligible.
            var fresh = CourseExerciseState(); _ = fresh.submit(exercise)
            let freshSaved = snapshot.saveExercise(courseID: originalCourse.id, cardID: original.id, exercise: exercise, state: fresh)
            #expect(freshSaved)
            let freshGraded = snapshot.answerNotificationExercise(course: originalCourse, lessonID: "lesson", cardID: original.id, correct: true, token: "fresh", attemptID: fresh.attemptID)
            #expect(freshGraded)
            let continued = snapshot.acknowledgeExercise(courseID: originalCourse.id, cardID: original.id, attemptID: fresh.attemptID)
            #expect(continued)
            #expect(snapshot.practiceSessions[originalCourse.id + ":lesson:lesson"]?.answers[original.id] == true)
            #expect(snapshot.exerciseEvidence.count == (credited ? 2 : 1))
            #expect(snapshot.courseSRS[originalCourse.id]?[original.id] == nil)
        }
    }

}
