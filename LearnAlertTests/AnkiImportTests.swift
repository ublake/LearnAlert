import Foundation
import SwiftData
import Testing
import SwiftUI
import WebKit
import AVFoundation
import AnkiArchive
@testable import LearnAlert

private class AnkiFixtureBundle: NSObject { }

@Suite("Anki imports", .serialized)
@MainActor
struct AnkiImportTests {
    private func package() throws -> (AnkiImportPackage, URL) {
        let source = try #require(Bundle(for: AnkiFixtureBundle.self).url(forResource: "anki-modern", withExtension: "apkg"))
        let workspace = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        return (try AnkiPackageReader.read(url: source, workspace: workspace), workspace)
    }

    private func container(url: URL? = nil) throws -> ModelContainer {
        let config = url.map { ModelConfiguration(url: $0, cloudKitDatabase: .none) }
            ?? ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: Deck.self, DeckSection.self, Flashcard.self, configurations: config)
    }

    @Test("Import, duplicate import, and updates retain card IDs and LearnAlert progress")
    func importAndUpdate() async throws {
        let (package, workspace) = try package()
        defer { try? FileManager.default.removeItem(at: workspace) }
        let container = try container()
        let importer = AnkiLibraryImporter(modelContainer: container)
        let selection = Set(package.decks.map(\.id))
        let first = try await importer.save(package, selectedDecks: selection, updateExisting: false, filename: "sample.apkg") { _ in }
        #expect(first.added == 9 && first.decks == 3)
        var context = ModelContext(container)
        var cards = try context.fetch(FetchDescriptor<Flashcard>())
        let original = try #require(cards.first { $0.sourceAnkiCardID == "fixture-cat:0" })
        let id = original.id
        original.processAnswer(isCorrect: true)
        var edited = try #require(original.ankiContent)
        edited.frontHTML = "A local edit"
        original.ankiContent = edited
        try context.save()
        defer {
            for folder in Set(cards.compactMap { $0.ankiContent?.mediaFolder }) {
                try? FileManager.default.removeItem(at: AnkiCardContent.mediaRoot.appendingPathComponent(folder))
            }
        }
        let second = try await importer.save(package, selectedDecks: selection, updateExisting: false, filename: "sample.apkg") { _ in }
        #expect(second.added == 0 && second.updated == 0 && second.unchanged == 9)
        let third = try await importer.save(package, selectedDecks: selection, updateExisting: true, filename: "sample.apkg") { _ in }
        #expect(third.added == 0 && third.updated == 9)
        context = ModelContext(container)
        cards = try context.fetch(FetchDescriptor<Flashcard>())
        #expect(cards.count == 9)
        let updated = try #require(cards.first { $0.id == id })
        #expect(updated.reviewCount == 1)
        #expect(updated.ankiContent?.frontHTML.contains("고양이") == true)
        #expect(updated.cardType == .anki)
        let decks = try context.fetch(FetchDescriptor<Deck>())
        #expect(decks.allSatisfy { $0.sourceAnkiDeckID != nil && !$0.canShareToCommunity && $0.alertSettings == nil })
        let directory = try #require(updated.ankiContent?.mediaURL)
        let audio = try #require(AnkiCardContent.safeMediaURL(name: "tone.wav", directory: directory))
        #expect(try AVAudioPlayer(contentsOf: audio).duration > 0)
    }

    @Test("Imported content and source identities survive reopening the store")
    func persistentImport() async throws {
        let (package, workspace) = try package()
        let path = workspace.appendingPathComponent("persistent.sqlite")
        defer { try? FileManager.default.removeItem(at: workspace) }
        let selection = Set(package.decks.map(\.id))
        do {
            let container = try container(url: path)
            let importer = AnkiLibraryImporter(modelContainer: container)
            _ = try await importer.save(package, selectedDecks: selection, updateExisting: false, filename: "sample.apkg") { _ in }
        }
        let reopened = try container(url: path)
        let context = ModelContext(reopened)
        let cards = try context.fetch(FetchDescriptor<Flashcard>())
        #expect(cards.count == 9)
        #expect(cards.allSatisfy { $0.ankiContent != nil && $0.sourceAnkiCardID != nil })
        for folder in Set(cards.compactMap { $0.ankiContent?.mediaFolder }) {
            try? FileManager.default.removeItem(at: AnkiCardContent.mediaRoot.appendingPathComponent(folder))
        }
    }

    @Test("Unrelated Anki packages that reuse a deck ID stay separate")
    func deckIdentityCollision() async throws {
        let (package, workspace) = try package()
        defer { try? FileManager.default.removeItem(at: workspace) }
        let source = try #require(package.decks.first)
        let container = try container(), context = ModelContext(container)
        let foreign = Deck(name: "A different imported deck")
        foreign.sourceAnkiDeckID = source.id
        let original = Flashcard(question: "Keep this separate", deck: foreign, cardType: .anki)
        original.sourceAnkiCardID = "another-collection:0"
        foreign.cards = [original]
        context.insert(foreign); try context.save()
        let foreignID = foreign.id
        let importer = AnkiLibraryImporter(modelContainer: container)
        _ = try await importer.save(package, selectedDecks: [source.id], updateExisting: true, filename: "other.apkg") { _ in }
        let refreshed = ModelContext(container)
        let decks = try refreshed.fetch(FetchDescriptor<Deck>())
        #expect(decks.count == 2)
        #expect(decks.first { $0.id == foreignID }?.cards.count == 1)
        #expect(decks.first { $0.id != foreignID }?.cards.count == source.cardCount)
        for folder in Set(decks.flatMap(\.cards).compactMap { $0.ankiContent?.mediaFolder }) {
            try? FileManager.default.removeItem(at: AnkiCardContent.mediaRoot.appendingPathComponent(folder))
        }
    }

    @Test("Rendering preserves custom scripts, styles, and bundled media while blocking network access")
    func renderer() async throws {
        let (package, workspace) = try package()
        defer { try? FileManager.default.removeItem(at: workspace) }
        let content = AnkiCardContent(frontHTML: "<div id='custom'>Korean \\(x^2\\)</div><img id='picture' src='cat.png'><script>document.getElementById('custom').dataset.ready='yes';</script>",
            backHTML: "Back", css: "#custom { color: rgb(23, 100, 180); }", mediaFolder: "", templateOrdinal: 0, noteType: "Custom", tags: [])
        let host = UIHostingController(rootView: AnkiCardView(content: content, showingBack: false, mediaDirectory: package.mediaDirectory, centered: true, animatedReveal: true))
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 600)
        window.rootViewController = host; window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        func findWeb(_ view: UIView) -> WKWebView? {
            if let web = view as? WKWebView { return web }
            return view.subviews.lazy.compactMap { findWeb($0) }.first
        }
        host.view.layoutIfNeeded()
        let web = try #require(findWeb(host.view))
        var ready = false
        for _ in 0..<100 {
            if let result = try? await web.evaluateJavaScript("document.readyState==='complete' && !!document.getElementById('custom')"), result as? Bool == true { ready = true; break }
            try await Task.sleep(for: .milliseconds(30))
        }
        #expect(ready)
        #expect(try await web.evaluateJavaScript("document.getElementById('custom').dataset.ready") as? String == "yes")
        #expect(try await web.evaluateJavaScript("getComputedStyle(document.getElementById('custom')).color") as? String == "rgb(23, 100, 180)")
        #expect(try await web.evaluateJavaScript("document.getElementById('picture').naturalWidth > 0") as? Bool == true)
        #expect(try await web.evaluateJavaScript("!!document.querySelector('.katex')") as? Bool == true)
        let network = try await web.callAsyncJavaScript("try { await fetch('https://example.com/blocked'); return 'allowed'; } catch (_) { return 'blocked'; }", arguments: [:], in: nil, contentWorld: .page)
        #expect(network as? String == "blocked")
        let centered = try await web.evaluateJavaScript("Math.abs(document.getElementById('learnalert-anki-content').getBoundingClientRect().top + document.getElementById('learnalert-anki-content').getBoundingClientRect().height / 2 - innerHeight / 2) < 3")
        #expect(centered as? Bool == true)
        let longContent = try await web.evaluateJavaScript("document.getElementById('learnalert-anki-content').style.height='1400px'; document.documentElement.scrollHeight > innerHeight && document.getElementById('learnalert-anki-content').getBoundingClientRect().top >= 0")
        #expect(longContent as? Bool == true)

    }

    @Test("Media lookup cannot escape its import folder")
    func mediaBoundary() {
        let directory = URL(fileURLWithPath: "/tmp/anki-media")
        for name in ["../secret", "%2e%2e%2fsecret", "folder/file", "folder\\file", ".", ".."] {
            #expect(AnkiCardContent.safeMediaURL(name: name, directory: directory) == nil)
        }
        #expect(AnkiCardContent.safeMediaURL(name: "한글.png", directory: directory)?.lastPathComponent == "한글.png")
    }

    @Test("The file-to-preview-to-save flow publishes completion without scheduling alerts")
    func sessionFlow() async throws {
        let source = try #require(Bundle(for: AnkiFixtureBundle.self).url(forResource: "anki-modern", withExtension: "apkg"))
        let session = AnkiImportSession()
        defer { session.cancel() }
        session.open(source)
        for _ in 0..<200 where session.phase == .converting { try await Task.sleep(for: .milliseconds(25)) }
        #expect(session.phase == .review)
        #expect(session.error == nil)
        #expect(session.selectedCardCount == 9)
        let container = try container()
        session.save(container: container)
        for _ in 0..<200 where session.phase == .saving { try await Task.sleep(for: .milliseconds(25)) }
        #expect(session.phase == .complete)
        #expect(session.result?.added == 9)
        let context = ModelContext(container)
        let cards = try context.fetch(FetchDescriptor<Flashcard>())
        #expect(cards.allSatisfy { $0.deck != nil })
        for folder in Set(cards.compactMap { $0.ankiContent?.mediaFolder }) {
            try? FileManager.default.removeItem(at: AnkiCardContent.mediaRoot.appendingPathComponent(folder))
        }
    }
}
