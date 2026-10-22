import Foundation
import CoreGraphics
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
