import Foundation
import AVFoundation
import Combine
import SwiftUI
import UIKit
import Testing
@testable import LearnAlert

@MainActor
@Suite("Course recorded audio and reading alternatives", .serialized)
struct CourseAudioTests {
    private func card(promptAudio: String? = nil, fieldAudio: String? = nil,
                      speech: String? = "hola", readingPrompt: String? = "Read ‘hola’. Which English greeting matches?",
                      activity: CourseActivity? = nil, cardType: String = "listening") -> CourseLessonCard {
        .init(id: "audio-fixture", question: "Listen and choose", options: ["Hello", "Good night"],
              correctAnswer: "Hello", cardType: cardType, promptAudioName: promptAudio,
              fieldMedia: fieldAudio.map { ["prompt": CardFieldMedia(audio: $0)] }, speechText: speech,
              readingPrompt: readingPrompt, activity: activity)
    }

    private func importedSpanishClip() throws -> String {
        let data = try #require(Data(base64Encoded: Self.spanishMP3, options: .ignoreUnknownCharacters))
        return try CardAudioStore.saveDownloaded(data)
    }

    @Test("Spanish recordings work independently of the Korean speech permission")
    func spanishRecordingPermission() throws {
        let name = try importedSpanishClip()
        defer { CardAudioStore.delete(named: name) }
        #expect(name.hasSuffix(".mp3"))
        #expect(CardAudioStore.isAvailable(named: name))
        let spanish = card(promptAudio: name)
        let source = CourseAudioPolicy.source(for: spanish, allowRecordedAudio: true, allowKoreanSpeech: false)
        #expect(source == .recording(name))
        #expect(CourseAudioPolicy.isListening(card: spanish, source: source, prefersReading: false))
        #expect(CourseAudioPolicy.source(for: spanish, allowRecordedAudio: false, allowKoreanSpeech: false) == nil)
    }

    @Test("Both recording fields are supported and a missing legacy attachment cannot hide field audio")
    func recordingSourcePreference() {
        let both = card(promptAudio: "legacy.mp3", fieldAudio: "field.mp3", speech: "안녕하세요")
        func source(available: Set<String>) -> CourseAudioSource? {
            CourseAudioPolicy.source(for: both, allowRecordedAudio: true, allowKoreanSpeech: true,
                recordingAvailable: { available.contains($0) }, canSpeak: { _ in true })
        }
        #expect(source(available: ["legacy.mp3", "field.mp3"]) == .recording("legacy.mp3"))
        #expect(source(available: ["field.mp3"]) == .recording("field.mp3"))
        #expect(source(available: []) == .koreanSpeech("안녕하세요"))
        let fieldOnly = card(fieldAudio: "field.mp3")
        #expect(CourseAudioPolicy.source(for: fieldOnly, allowRecordedAudio: true, allowKoreanSpeech: false,
            recordingAvailable: { $0 == "field.mp3" }, canSpeak: { _ in false }) == .recording("field.mp3"))
    }

    @Test("Korean synthesis requires an allowed language, nonempty text and a usable speech source")
    func koreanSpeechPermission() {
        for language in ["Korean", " korean ", "ko", "KO-KR"] {
            #expect(CourseAudioPolicy.allowsKoreanSpeech(for: language))
        }
        for language in ["Spanish", "es", "es-ES", "English", "Japanese", ""] {
            #expect(!CourseAudioPolicy.allowsKoreanSpeech(for: language))
        }
        let korean = card(speech: " 안녕하세요 \n")
        #expect(CourseAudioPolicy.source(for: korean, allowRecordedAudio: false, allowKoreanSpeech: true,
            recordingAvailable: { _ in false }, canSpeak: { $0 == "안녕하세요" }) == .koreanSpeech("안녕하세요"))
        #expect(CourseAudioPolicy.source(for: korean, allowRecordedAudio: false, allowKoreanSpeech: false,
            recordingAvailable: { _ in false }, canSpeak: { _ in true }) == nil)
        #expect(CourseAudioPolicy.source(for: korean, allowRecordedAudio: false, allowKoreanSpeech: true,
            recordingAvailable: { _ in false }, canSpeak: { _ in false }) == nil)
        for text: String? in [nil, "", " \n\t"] {
            var speechWasAsked = false
            #expect(CourseAudioPolicy.source(for: card(speech: text), allowRecordedAudio: true, allowKoreanSpeech: true,
                recordingAvailable: { _ in false }, canSpeak: { _ in speechWasAsked = true; return true }) == nil)
            #expect(!speechWasAsked)
        }
    }

    @Test("Missing or empty recordings fall back to reading without invoking Spanish text as Korean speech")
    func unavailableRecordings() {
        let missing = "missing-\(UUID().uuidString).mp3"
        #expect(!CardAudioStore.isAvailable(named: missing))
        #expect(!CardAudioStore.isAvailable(named: " \n"))
        let spanish = card(promptAudio: missing, fieldAudio: "")
        let source = CourseAudioPolicy.source(for: spanish, allowRecordedAudio: true, allowKoreanSpeech: false)
        #expect(source == nil)
        #expect(!CourseAudioPolicy.isListening(card: spanish, source: source, prefersReading: false))
        #expect(CourseAudioPolicy.readingQuestion(for: spanish) == spanish.readingPrompt)
    }

    @Test("Complete reading questions take precedence over short activity cues in both layouts")
    func completeReadingQuestion() {
        let fullPrompt = "Read ‘hola’. Which English greeting matches this Spanish word?"
        let activity = CourseActivity(kind: .listenChoose, sequence: 0, readingCue: "hola")
        for layout in [nil, activity] {
            let question = card(readingPrompt: fullPrompt, activity: layout)
            #expect(CourseAudioPolicy.readingQuestion(for: question) == fullPrompt)
            #expect(CourseAudioPolicy.readingQuestion(for: question) != activity.readingCue)
        }
        for emptyPrompt: String? in [nil, "", " \n"] {
            let legacyCue = card(readingPrompt: emptyPrompt, activity: activity)
            #expect(CourseAudioPolicy.readingQuestion(for: legacyCue) == "hola")
        }
        let legacy = card(speech: "hola", readingPrompt: nil)
        #expect(CourseAudioPolicy.readingQuestion(for: legacy) == legacy.practiceQuestionText(audioEnabled: false))
        for emptyPrompt in ["", " \n"] {
            let legacyBlank = card(speech: "hola", readingPrompt: emptyPrompt)
            #expect(!CourseAudioPolicy.readingQuestion(for: legacyBlank).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            #expect(CourseAudioPolicy.readingQuestion(for: legacyBlank).contains("hola"))
        }
        let unavailable = card(speech: nil, readingPrompt: nil)
        #expect(CourseAudioPolicy.readingQuestion(for: unavailable) == unavailable.question)
    }

    @Test("Reading preferences can return to the same listening question without changing its source")
    func reversibleReadingPreference() {
        let question = card(fieldAudio: "spanish.mp3")
        let source = CourseAudioPolicy.source(for: question, allowRecordedAudio: true, allowKoreanSpeech: false,
            recordingAvailable: { _ in true }, canSpeak: { _ in false })
        for reading in [false, true, false] {
            #expect(CourseAudioPolicy.isListening(card: question, source: source, prefersReading: reading) == !reading)
        }
        #expect(!CourseAudioPolicy.isListening(card: card(cardType: "vocabulary"), source: source, prefersReading: false))
        #expect(!CourseAudioPolicy.isListening(card: question, source: nil, prefersReading: false))
    }

    @Test("The Spanish MP3 decodes and starts playback, and global stopping ends the active player")
    func recordedPlaybackAndStop() throws {
        CardAudioPlayer.stopActive()
        let name = try importedSpanishClip()
        let first = CardAudioPlayer()
        let second = CardAudioPlayer()
        defer { first.stop(); second.stop(); CardAudioStore.delete(named: name) }
        let decoder = try AVAudioPlayer(contentsOf: CardAudioStore.url(named: name))
        #expect(decoder.duration > 1)
        var changes: [Bool] = []
        let observer = CardAudioPlayer.playbackChanges.sink { changes.append($0) }
        defer { observer.cancel() }
        first.toggle(name: name)
        #expect(first.isPlaying && CardAudioPlayer.isAnyPlaying)
        #expect(first.errorMessage == nil)
        second.toggle(name: name)
        #expect(!first.isPlaying && second.isPlaying && CardAudioPlayer.isAnyPlaying)
        CardAudioPlayer.stopActive()
        #expect(!second.isPlaying && !CardAudioPlayer.isAnyPlaying)
        #expect(changes.contains(true) && changes.last == false)
    }

    @Test("A recorded clip naturally finishes and publishes its stopped state")
    func recordedPlaybackCompletion() async throws {
        CardAudioPlayer.stopActive()
        let name = try importedSpanishClip()
        let player = CardAudioPlayer()
        defer { player.stop(); CardAudioStore.delete(named: name) }
        let duration = try AVAudioPlayer(contentsOf: CardAudioStore.url(named: name)).duration
        var changes: [Bool] = []
        let observer = CardAudioPlayer.playbackChanges.sink { changes.append($0) }
        defer { observer.cancel() }

        let start = ContinuousClock.now
        player.toggle(name: name)
        try #require(player.isPlaying && CardAudioPlayer.isAnyPlaying)
        while player.isPlaying && ContinuousClock.now - start < .seconds(5) {
            try await Task.sleep(for: .milliseconds(25))
        }

        // No stop() call precedes these assertions: the real AVAudioPlayer
        // delegate must clear both local and global playback after the MP3 ends.
        #expect(!player.isPlaying && !CardAudioPlayer.isAnyPlaying)
        #expect(player.errorMessage == nil)
        #expect(changes == [true, false])
        #expect(ContinuousClock.now - start >= .seconds(duration * 0.5))
    }

    @Test("A stale completion from an earlier clip cannot stop the replacement recording")
    func staleRecordedPlaybackCompletion() async throws {
        CardAudioPlayer.stopActive()
        let name = try importedSpanishClip()
        let player = CardAudioPlayer()
        defer { player.stop(); CardAudioStore.delete(named: name) }
        var changes: [Bool] = []
        let observer = CardAudioPlayer.playbackChanges.sink { changes.append($0) }
        defer { observer.cancel() }

        player.toggle(name: name)
        try #require(player.isPlaying)
        // Keep the actual previous AVAudioPlayer alive to reproduce a delayed
        // delegate callback without exposing the player's private storage API.
        let stored = try #require(Mirror(reflecting: player).children.first { $0.label == "player" }?.value)
        let previous = try #require(Mirror(reflecting: stored).children.first?.value as? AVAudioPlayer)
        player.stop()
        player.toggle(name: name)
        try #require(player.isPlaying && CardAudioPlayer.isAnyPlaying)
        let changesBeforeStaleCompletion = changes

        player.audioPlayerDidFinishPlaying(previous, successfully: true)
        // Yield to the delegate's MainActor task while the replacement clip is
        // still playing. The stale callback must neither stop it nor emit false.
        try await Task.sleep(for: .milliseconds(75))
        #expect(player.isPlaying && CardAudioPlayer.isAnyPlaying)
        #expect(player.errorMessage == nil)
        #expect(changes == changesBeforeStaleCompletion)
    }

    @Test("Playback failure leaves no active audio state")
    func failedPlaybackStopsActiveState() {
        CardAudioPlayer.stopActive()
        let player = CardAudioPlayer()
        defer { player.stop() }
        player.toggle(name: "missing-\(UUID().uuidString).mp3")
        #expect(!player.isPlaying && !CardAudioPlayer.isAnyPlaying)
        #expect(player.errorMessage != nil)
    }

    @Test("Korean pronunciation plays its bundled sound and completes playback")
    func koreanPronunciationPlayback() async throws {
        let speech = KoreanSpeechManager.shared
        speech.stop()
        defer { speech.stop() }
        let url = try #require(HangulAudio.url(for: "ㅏ"))
        let duration = try AVAudioPlayer(contentsOf: url).duration
        #expect(duration > 0)
        let start = Date()
        speech.speak("ㅏ")
        #expect(speech.isSpeaking && speech.currentSpeakingText == "ㅏ")
        while speech.isSpeaking && Date().timeIntervalSince(start) < max(10, duration + 5) {
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(!speech.isSpeaking && speech.currentSpeakingText == nil)
        #expect(Date().timeIntervalSince(start) >= duration * 0.5)
    }

    @Test("Recorded listening and complete reading alternatives render in app and notification layouts")
    func audioReadingAppearance() throws {
        let name = try importedSpanishClip()
        defer { CardAudioPlayer.stopActive(); CardAudioStore.delete(named: name) }
        let activity = CourseActivity(kind: .listenChoose, sequence: 0, readingCue: "hola")
        var modeCallbacks = 0
        for scheme in [ColorScheme.light, .dark] {
            for immersive in [false, true] {
                let width: CGFloat = immersive ? 402 : 360
                for layout in [nil, activity] {
                    for reading in [false, true] {
                        let question = card(fieldAudio: name, activity: layout)
                        let content = CourseQuestionPanel(card: question, immersive: immersive,
                            allowRecordedAudio: true, allowKoreanSpeech: false, prefersReading: reading,
                            onReadingRequested: { modeCallbacks += 1 }, onListeningRequested: { modeCallbacks += 1 }) { _ in }
                            .environment(\.courseNotificationCompact, !immersive)
                            .environment(\.dynamicTypeSize, .large)
                            .padding(12).frame(width: width).background(Color(.systemBackground))
                            .environment(\.colorScheme, scheme)
                        let renderer = ImageRenderer(content: content)
                        let image = try #require(renderer.uiImage)
                        #expect(image.size.width == width && image.size.height > 100)
                        if !immersive { #expect(image.size.height + 120 <= CourseNotificationSizing.maximumHeight(screenHeight: 844)) }
                        if !immersive && scheme == .dark {
                            Attachment.record(image, named: "spanish-\(layout == nil ? "legacy" : "activity")-\(reading ? "reading" : "listening").png", as: .png)
                        }
                    }
                }
            }
        }
        // Rendering is passive. These snapshots do not simulate taps or prove audibility.
        #expect(modeCallbacks == 0)
        #expect(!CardAudioPlayer.isAnyPlaying)
    }

    @Test("Missing Spanish audio renders the reading question in both lesson and notification layouts")
    func missingAudioAppearance() throws {
        let activity = CourseActivity(kind: .listenChoose, sequence: 0, readingCue: "hola")
        for immersive in [false, true] {
            for layout in [nil, activity] {
                let question = card(fieldAudio: "missing-\(UUID().uuidString).mp3", activity: layout)
                let source = CourseAudioPolicy.source(for: question, allowRecordedAudio: true, allowKoreanSpeech: false)
                #expect(source == nil)
                #expect(!CourseAudioPolicy.isListening(card: question, source: source, prefersReading: false))
                #expect(CourseAudioPolicy.readingQuestion(for: question) == question.readingPrompt)
                let width: CGFloat = immersive ? 402 : 360
                let renderer = ImageRenderer(content: CourseQuestionPanel(card: question, immersive: immersive,
                    allowRecordedAudio: true, allowKoreanSpeech: false) { _ in }
                    .environment(\.courseNotificationCompact, !immersive)
                    .padding(12).frame(width: width).background(Color(.systemBackground))
                    .environment(\.colorScheme, .dark))
                let image = try #require(renderer.uiImage)
                #expect(image.size.width == width && image.size.height > 100)
                if !immersive {
                    #expect(image.size.height + 120 <= CourseNotificationSizing.maximumHeight(screenHeight: 844))
                    Attachment.record(image, named: "spanish-\(layout == nil ? "legacy" : "activity")-missing-audio.png", as: .png)
                }
            }
        }
        #expect(!CardAudioPlayer.isAnyPlaying)
    }

    // Offline fixture: macOS Mónica voice saying "Hola, buenos días", encoded as
    // a 1.41-second mono MP3. Embedded bytes avoid test-bundle resource assumptions.
    private static let spanishMP3 = """
    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
    qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqo=
    """
}
