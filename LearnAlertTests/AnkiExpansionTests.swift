import Foundation
import Testing
import WebKit
@testable import LearnAlert

@MainActor
@Suite("Anki dropdown expansion", .serialized)
struct AnkiExpansionTests {
    private func waitForBoth(_ controller: AnkiPreviewRenderController) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(15))
        while ContinuousClock.now < deadline {
            if controller.front?.isLoading == false, controller.back?.isLoading == false { return }
            try await Task.sleep(for: .milliseconds(20))
        }
        Issue.record("Both preview sides did not finish loading")
    }

    @Test("Expansion starts one browser at a time and reuses a large media map prepared off the UI thread")
    func stagedExpansion() async throws {
        let folder = UUID().uuidString
        let directory = AnkiCardContent.mediaRoot.appendingPathComponent(folder, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let map = Dictionary(uniqueKeysWithValues: (0..<20_000).map { ("audio-\($0).mp3", "stored-\($0).mp3") })
        let mapURL = directory.appendingPathComponent(".learnalert-media.json")
        try JSONEncoder().encode(map).write(to: mapURL)
        let content = AnkiCardContent(frontHTML: "<b>Front marker</b>", backHTML: "<i>Back marker</i>", css: "b {color:red}", mediaFolder: folder, templateOrdinal: 0, noteType: "Basic", tags: [])
        let start = ContinuousClock.now
        let documents = try await Task.detached {
            try AnkiPreviewDocuments.prepare(content, configuration: .init(dark: true, compact: true, centered: false))
        }.value
        let preparation = start.duration(to: .now)
        #expect(documents.mediaIndex == map)
        #expect(documents.front.contains("Front marker") && documents.back.contains("Back marker"))
        // Neither browser can read the map again. Both must use the prepared value.
        try FileManager.default.removeItem(at: mapURL)
        let controller = AnkiPreviewRenderController()
        defer { controller.clear() }
        #expect(controller.front == nil && controller.back == nil)
        let creationStart = ContinuousClock.now
        controller.start(documents, directory: directory)
        let creation = creationStart.duration(to: .now)
        #expect(controller.front != nil && controller.back == nil)
        #expect(controller.front?.coordinator.media?.index == map)
        try await waitForBoth(controller)
        let front = try #require(controller.front), back = try #require(controller.back)
        #expect(front.error == nil && back.error == nil)
        #expect(back.coordinator.media?.index == map)
        #expect(try await front.webView.evaluateJavaScript("document.body.textContent.includes('Front marker')") as? Bool == true)
        #expect(try await back.webView.evaluateJavaScript("document.body.textContent.includes('Back marker')") as? Bool == true)
        #expect(!front.coordinator.permitsPlayback && !back.coordinator.permitsPlayback)
        Attachment.record("20000 media aliases: background preparation \(preparation); first browser startup \(creation). Second browser starts only after the front settles.", named: "dropdown-expansion-timing.txt")
    }

    @Test("Collapsing cancels pending back creation and reopening displays the new content")
    func collapseAndReopen() async throws {
        let controller = AnkiPreviewRenderController()
        defer { controller.clear() }
        let first = AnkiPreviewDocuments(front: "<html><body>Old front</body></html>", back: "<html><body>Old back</body></html>", mediaIndex: [:])
        controller.start(first, directory: nil)
        let old = try #require(controller.front)
        controller.clear()
        try await Task.sleep(for: .milliseconds(100))
        #expect(controller.front == nil && controller.back == nil && !old.coordinator.permitsPlayback)
        let next = AnkiPreviewDocuments(front: "<html><body>New front</body></html>", back: "<html><body>New back</body></html>", mediaIndex: [:])
        controller.start(next, directory: nil)
        try await waitForBoth(controller)
        #expect(controller.front !== old)
        let back = try #require(controller.back)
        #expect(try await back.webView.evaluateJavaScript("document.body.textContent==='New back'") as? Bool == true)
    }
}
