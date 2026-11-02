import Foundation
import SwiftData
import Testing
import SwiftUI
import WebKit
import AVFoundation
import AnkiArchive
@testable import LearnAlert

private class AnkiFixtureBundle: NSObject { }

@MainActor
private final class AnkiAudioMessageRecorder: NSObject, WKScriptMessageHandler {
    var messages: [[String: String]] = []
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if let body = message.body as? [String: String] { messages.append(body) }
    }
}

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

    /// A real hosted WebKit surface also exercises SwiftUI's color-scheme input.
    private func withRenderedCard<Result>(content: AnkiCardContent, directory: URL? = nil,
                                         dark: Bool, _ inspect: @MainActor (WKWebView) async throws -> Result) async throws -> Result {
        let renderer = AnkiCardRenderer()
        let host = UIHostingController(rootView: AnkiCardView(content: content, showingBack: false,
            mediaDirectory: directory, renderer: renderer).environment(\.colorScheme, dark ? .dark : .light))
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 600)
        window.rootViewController = host; window.makeKeyAndVisible()
        defer {
            renderer.discard()
            window.isHidden = true; window.rootViewController = nil
        }
        host.view.layoutIfNeeded()
        var ready = false
        let deadline = ContinuousClock.now.advanced(by: .seconds(15))
        while ContinuousClock.now < deadline {
            if !renderer.isLoading, renderer.error == nil,
               let complete = try? await renderer.webView.evaluateJavaScript("document.readyState==='complete' && !!document.getElementById('learnalert-anki-content')"),
               complete as? Bool == true { ready = true; break }
            try await Task.sleep(for: .milliseconds(30))
        }
        if !ready {
            let page = (try? await renderer.webView.evaluateJavaScript("JSON.stringify({readyState:document.readyState,hasRoot:!!document.getElementById('learnalert-anki-content'),url:location.href,colorScheme:getComputedStyle(document.documentElement).colorScheme})")) as? String ?? "JavaScript unavailable"
            try #require(ready, "Imported HTML readiness timed out: isLoading=\(renderer.isLoading), error=\(renderer.error ?? "none"), documentQueued=\(!renderer.coordinator.document.isEmpty), webViewAttached=\(renderer.webView.window != nil), page=\(page)")
        }
        return try await inspect(renderer.webView)
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
        let reviewStateData = try #require(original.ankiReviewStateData)
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
        #expect(updated.ankiReviewStateData == reviewStateData)
        #expect(updated.ankiReviewState.ratingCounts.good == 1)
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
        let host = UIHostingController(rootView: AnkiCardView(content: content, showingBack: false, mediaDirectory: package.mediaDirectory, centered: true, animatedReveal: true).environment(\.colorScheme, .light))
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

    @Test("Authored white and black templates follow both host appearances with readable text", arguments: [false, true], [false, true])
    func adaptiveTemplateTheme(dark: Bool, authoredDark: Bool) async throws {
        let background = authoredDark ? "#000" : "#fff"
        let foreground = authoredDark ? "#fff" : "#000"
        let content = AnkiCardContent(frontHTML: """
            <div id="panel" style="background:\(background)!important;border:2px solid \(foreground)!important;padding:16px">
              <span id="inherited">Inherited Korean 한국어</span>
              <span id="explicit" style="color:\(foreground)!important">Explicit text</span>
              <span id="accent" style="color:#ffff00!important">Colored emphasis</span>
              <span id="blue" style="color:#1764b4!important">Blue emphasis</span>
              <span id="cloze" class="cloze">[...]</span>
            </div>
            <div id="gradient" style="background:linear-gradient(#fff,#000);padding:12px">Template box</div>
            <script>
              for (const element of [document.documentElement,document.body,document.getElementById('learnalert-anki-content')]) {
                element.style.setProperty('background','\(background)','important');
                element.style.setProperty('color','\(foreground)','important');
              }
            </script>
            """, backHTML: "Answer", css: "", mediaFolder: "", templateOrdinal: 0, noteType: "Custom", tags: [])
        try await withRenderedCard(content: content, dark: dark) { web in
            let checks = try #require(try await web.evaluateJavaScript("""
                (() => {
                  const rgb=value=>value.match(/[\\d.]+/g).map(Number);
                  const alpha=value=>{ const c=rgb(value);return c.length===4?c[3]:1; };
                  const luminance=c=>c.slice(0,3).reduce((sum,v,i)=>{
                    v/=255;return sum+(v<=.04045?v/12.92:Math.pow((v+.055)/1.055,2.4))*[.2126,.7152,.0722][i];
                  },0);
                  const contrast=(a,b)=>(Math.max(luminance(a),luminance(b))+.05)/(Math.min(luminance(a),luminance(b))+.05);
                  const style=id=>getComputedStyle(document.getElementById(id));
                  const host=\(dark ? "[25,29,40]" : "[238,241,248]");
                  const surface=rgb(style('panel').backgroundColor);
                  const blended=surface.slice(0,3).map((v,i)=>v*(surface[3]??1)+host[i]*(1-(surface[3]??1)));
                  const ink=rgb(getComputedStyle(document.body).color);
                  return {
                    appearance:getComputedStyle(document.documentElement).colorScheme==='\(dark ? "dark" : "light")',
                    transparentRoots:[document.documentElement,document.body,document.getElementById('learnalert-anki-content')].every(el=>alpha(getComputedStyle(el).backgroundColor)<.01),
                    translucentPanel:surface[3]>0 && surface[3]<.7,
                    subtleBorder:alpha(style('panel').borderTopColor)>0 && alpha(style('panel').borderTopColor)<.7,
                    inheritedReadable:contrast(rgb(style('inherited').color),blended)>=4.5,
                    explicitReadable:contrast(rgb(style('explicit').color),blended)>=4.5,
                    emphasisReadable:contrast(rgb(style('accent').color),blended)>=4.5,
                    blueReadable:contrast(rgb(style('blue').color),blended)>=4.5,
                    clozeReadable:contrast(rgb(style('cloze').color),blended)>=4.5,
                    inkFollowsHost:\(dark ? "luminance(ink)>.6" : "luminance(ink)<.1"),
                    gradientAdapted:style('gradient').backgroundImage==='none' && alpha(style('gradient').backgroundColor)<.7,
                    contentPreserved:document.getElementById('inherited').textContent==='Inherited Korean 한국어' && document.getElementById('cloze').textContent==='[...]'
                  };
                })()
                """) as? [String: Bool])
            #expect(checks["appearance"] == true)
            #expect(checks["transparentRoots"] == true)
            #expect(checks["translucentPanel"] == true)
            #expect(checks["subtleBorder"] == true)
            #expect(checks["inheritedReadable"] == true)
            #expect(checks["explicitReadable"] == true)
            #expect(checks["emphasisReadable"] == true)
            #expect(checks["blueReadable"] == true)
            #expect(checks["clozeReadable"] == true)
            #expect(checks["inkFollowsHost"] == true)
            #expect(checks["gradientAdapted"] == true)
            #expect(checks["contentPreserved"] == true)
        }
    }

    @Test("Theme adaptation preserves local image backgrounds, audio actions, and interactive template content", arguments: [false, true])
    func adaptiveThemeKeepsTemplateBehavior(dark: Bool) async throws {
        let (package, workspace) = try package()
        defer { try? FileManager.default.removeItem(at: workspace) }
        let content = AnkiCardContent(frontHTML: """
            <div id="image-panel" style="background:#fff url('cat.png') center/contain no-repeat;padding:12px">
              <img id="picture" src="cat.png">
            </div>
            <button id="listen" class="anki-sound" data-sound="tone.wav">Listen</button>
            <button id="speech" data-speech="한국어" data-language="ko-KR">Speak</button>
            <button id="toggle" onclick="document.getElementById('cloze').textContent='한국어';document.getElementById('concealed').style.removeProperty('color');document.getElementById('visible').style.color='transparent';const panel=document.createElement('div');panel.id='added';panel.style.cssText='background:white;color:black;border:1px solid black';panel.textContent='Added by the template';document.getElementById('learnalert-anki-content').append(panel)">Reveal custom answer</button>
            <span id="cloze" class="cloze" data-original="한국어">[...]</span>
            <span id="concealed" style="color:transparent!important">Hidden answer</span>
            <span id="visible">Initially visible answer</span>
            <script>document.documentElement.style.setProperty('background-image',"url('cat.png')",'important');</script>
            """, backHTML: "Answer", css: "", mediaFolder: "", templateOrdinal: 0, noteType: "Custom", tags: [])
        try await withRenderedCard(content: content, directory: package.mediaDirectory, dark: dark) { web in
            #expect(try await web.evaluateJavaScript("getComputedStyle(document.documentElement).backgroundImage.includes('cat.png') && getComputedStyle(document.getElementById('image-panel')).backgroundImage.includes('cat.png')") as? Bool == true)
            #expect(try await web.evaluateJavaScript("document.getElementById('picture').complete && document.getElementById('picture').naturalWidth>0") as? Bool == true)
            #expect(try await web.evaluateJavaScript("getComputedStyle(document.getElementById('concealed')).color==='rgba(0, 0, 0, 0)'") as? Bool == true)
            #expect(try await web.evaluateJavaScript("getComputedStyle(document.getElementById('visible')).color===getComputedStyle(document.body).color") as? Bool == true)
            let recorder = AnkiAudioMessageRecorder()
            web.configuration.userContentController.removeScriptMessageHandler(forName: "ankiAudio")
            web.configuration.userContentController.add(recorder, name: "ankiAudio")
            _ = try await web.evaluateJavaScript("document.getElementById('listen').click();document.getElementById('speech').click();document.getElementById('toggle').click();true")
            var insertedAndAdapted = false
            for _ in 0..<100 {
                if let adapted = try? await web.evaluateJavaScript("(() => { const panel=document.getElementById('added');return panel && getComputedStyle(panel).backgroundColor.startsWith('rgba(') && getComputedStyle(panel).color===getComputedStyle(document.body).color; })()"),
                   adapted as? Bool == true, recorder.messages.count == 2 { insertedAndAdapted = true; break }
                try await Task.sleep(for: .milliseconds(30))
            }
            #expect(insertedAndAdapted)
            #expect(try await web.evaluateJavaScript("getComputedStyle(document.getElementById('visible')).color==='rgba(0, 0, 0, 0)'") as? Bool == true)
            #expect(recorder.messages.first?["sound"] == "tone.wav")
            #expect(recorder.messages.last?["speech"] == "한국어")
            #expect(recorder.messages.last?["language"] == "ko-KR")
            #expect(try await web.evaluateJavaScript("document.getElementById('cloze').textContent==='한국어' && document.getElementById('cloze').dataset.original==='한국어' && document.getElementById('added').textContent==='Added by the template' && getComputedStyle(document.getElementById('concealed')).color===getComputedStyle(document.body).color") as? Bool == true)
            let network = try await web.callAsyncJavaScript("try { await fetch('https://example.com/blocked'); return 'allowed'; } catch (_) { return 'blocked'; }", arguments: [:], in: nil, contentWorld: .page)
            #expect(network as? String == "blocked")
        }
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
        session.confirmDeckNames()
        session.save(container: container)
        #expect(session.phase == .saving)
        #expect(session.progress.title == "Making room for your cards")
        await Task.yield()
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<Flashcard>()) == 0)
        // Starting is gated by the visible saving surface, never by a hidden worker.
        session.savingViewDidAppear()
        session.savingViewDidAppear() // Reappearing cannot start a second commit.
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
    @Test("A session-owned media folder is adopted without retaining a second extracted copy")
    func consumesOwnedMedia() async throws {
        let (package, workspace) = try package()
        defer { try? FileManager.default.removeItem(at: workspace) }
        let container = try container()
        let importer = AnkiLibraryImporter(modelContainer: container)
        let result = try await importer.save(package, selectedDecks: Set(package.decks.map(\.id)),
            updateExisting: false, filename: "sample.apkg", consumeMedia: true) { _ in }
        #expect(result.added == 9)
        #expect(!FileManager.default.fileExists(atPath: package.mediaDirectory.path))
        let context = ModelContext(container)
        let cards = try context.fetch(FetchDescriptor<Flashcard>())
        let folders = Set(cards.compactMap { $0.ankiContent?.mediaFolder })
        defer { for folder in folders { try? FileManager.default.removeItem(at: AnkiCardContent.mediaRoot.appendingPathComponent(folder)) } }
        #expect(folders.count == 1)
        let directory = try #require(cards.first?.ankiContent?.mediaURL)
        let audio = try #require(AnkiCardContent.safeMediaURL(name: "tone.wav", directory: directory))
        #expect(try AVAudioPlayer(contentsOf: audio).duration > 0)
    }

    @Test("Cancelling after media adoption rolls back every model and restores the package for retry")
    func cancelledSaveRestoresMedia() async throws {
        let (package, workspace) = try package()
        defer { try? FileManager.default.removeItem(at: workspace) }
        let container = try container(), importer = AnkiLibraryImporter(modelContainer: container)
        let selection = Set(package.decks.map(\.id))
        let task = Task {
            try await importer.save(package, selectedDecks: selection, updateExisting: false,
                filename: "sample.apkg", consumeMedia: true) { progress in
                if progress.title == "Adding your cards" && progress.completedItems == 0 {
                    withUnsafeCurrentTask { $0?.cancel() }
                }
            }
        }
        do { _ = try await task.value; Issue.record("Cancelled save unexpectedly committed") }
        catch { #expect(error is CancellationError) }
        let context = ModelContext(container)
        #expect(try context.fetchCount(FetchDescriptor<Deck>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Flashcard>()) == 0)
        #expect(FileManager.default.fileExists(atPath: package.mediaDirectory.path))
        let retry = AnkiLibraryImporter(modelContainer: container)
        let result = try await retry.save(package, selectedDecks: selection, updateExisting: false,
            filename: "sample.apkg", consumeMedia: true) { _ in }
        #expect(result.added == 9)
        let refreshed = ModelContext(container)
        let cards = try refreshed.fetch(FetchDescriptor<Flashcard>())
        for folder in Set(cards.compactMap { $0.ankiContent?.mediaFolder }) {
            try? FileManager.default.removeItem(at: AnkiCardContent.mediaRoot.appendingPathComponent(folder))
        }
    }

    @Test("No-op re-imports do not access the extracted media directory")
    func duplicateImportSkipsMedia() async throws {
        let (package, workspace) = try package()
        defer { try? FileManager.default.removeItem(at: workspace) }
        let container = try container(), importer = AnkiLibraryImporter(modelContainer: container)
        let selection = Set(package.decks.map(\.id))
        _ = try await importer.save(package, selectedDecks: selection, updateExisting: false, filename: "sample.apkg") { _ in }
        try FileManager.default.removeItem(at: package.mediaDirectory)
        let duplicate = try await importer.save(package, selectedDecks: selection, updateExisting: false, filename: "sample.apkg") { _ in }
        #expect(duplicate.added == 0 && duplicate.updated == 0 && duplicate.unchanged == 9)
        let context = ModelContext(container)
        let cards = try context.fetch(FetchDescriptor<Flashcard>())
        #expect(cards.count == 9)
        for folder in Set(cards.compactMap { $0.ankiContent?.mediaFolder }) {
            try? FileManager.default.removeItem(at: AnkiCardContent.mediaRoot.appendingPathComponent(folder))
        }
    }

    @Test("Study preloading reuses the next renderer and retains only two cards")
    func prefetchesNextCard() async throws {
        let cache = AnkiStudyRenderCache()
        defer { cache.clear() }
        let ids = (0..<3).map { _ in UUID() }
        func content(_ number: Int) -> AnkiCardContent {
            .init(frontHTML: "Card \(number)", backHTML: "Answer \(number)", css: "", mediaFolder: "", templateOrdinal: 0, noteType: "Basic", tags: [])
        }
        cache.prepare(current: (ids[0], content(0), false), next: (ids[1], content(1)), configuration: .init())
        let next = cache.renderer(for: ids[1])
        #expect(!next.coordinator.permitsPlayback)
        for _ in 0..<150 {
            if !next.isLoading { break }
            try await Task.sleep(for: .milliseconds(30))
        }
        #expect(!next.isLoading && next.error == nil)
        #expect(try await next.webView.evaluateJavaScript("document.body.textContent.includes('Card 1')") as? Bool == true)
        cache.prepare(current: (ids[1], content(1), false), next: (ids[2], content(2)), configuration: .init())
        #expect(cache.renderer(for: ids[1]) === next)
        #expect(!next.isLoading)
        #expect(cache.retainedRendererCount == 2)
    }

    @Test("Import telemetry measures stage rates and does not invent an ETA before progress")
    func importTelemetry() {
        let start = Date(timeIntervalSince1970: 100)
        let now = Date(timeIntervalSince1970: 110)
        let progress = AnkiImportProgress(0.6, "Media", completedItems: 20, totalItems: 100, unit: "files", processedBytes: 2000000)
        let metrics = AnkiImportTelemetry(progress: progress, startedAt: start, stageStartedAt: start, now: now)
        #expect(metrics.unitsPerSecond == 2)
        #expect(metrics.bytesPerSecond == 200000)
        #expect(metrics.remainingSeconds == 40)
        let waiting = AnkiImportTelemetry(progress: .init(0,"Opening"), startedAt: start, stageStartedAt: start, now: now)
        #expect(waiting.bytesPerSecond == nil && waiting.remainingSeconds == nil)
        let complete = AnkiImportTelemetry(progress: .init(1,"Done",completedItems:100,totalItems:100,unit:"cards"), startedAt:start,stageStartedAt:start,now:now)
        #expect(complete.remainingSeconds == nil)
    }

    @Test("Current import rates use recent measurements and expire rather than showing stale speed")
    func currentImportTelemetry() {
        let start = Date(timeIntervalSince1970: 100), now = Date(timeIntervalSince1970: 110)
        let progress = AnkiImportProgress(0.6, "Cards", completedItems: 100, totalItems: 200, unit: "cards", processedBytes: 2500)
        let samples: [AnkiImportRateSample] = [
            .init(date: Date(timeIntervalSince1970: 108), items: 90, bytes: 500),
            .init(date: now, items: 100, bytes: 2500)
        ]
        let metrics = AnkiImportTelemetry(progress: progress, startedAt: start, stageStartedAt: start, now: now, samples: samples)
        #expect(metrics.unitsPerSecond == 10)
        #expect(metrics.currentUnitsPerSecond == 5)
        #expect(metrics.bytesPerSecond == 250)
        #expect(metrics.currentBytesPerSecond == 1000)
        #expect(metrics.remainingSeconds == 10)
        let stale = AnkiImportTelemetry(progress: progress, startedAt: start, stageStartedAt: start,
            now: now.addingTimeInterval(2), samples: samples)
        #expect(stale.currentUnitsPerSecond == nil && stale.currentBytesPerSecond == nil)
    }

}
