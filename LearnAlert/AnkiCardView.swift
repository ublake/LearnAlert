import SwiftUI
import Combine
import WebKit
import AVFoundation
import UniformTypeIdentifiers

/// Imported cards have their own isolated renderer. Native LearnAlert cards never load HTML.
struct AnkiCardView: View {
    let content: AnkiCardContent
    let showingBack: Bool
    var mediaDirectory: URL? = nil
    var compact = false
    var centered = false
    var animatedReveal = false
    var loadingChanged: ((Bool) -> Void)? = nil
    @StateObject private var localRenderer: AnkiCardRenderer
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    init(content: AnkiCardContent, showingBack: Bool, mediaDirectory: URL? = nil,
         compact: Bool = false, centered: Bool = false, animatedReveal: Bool = false,
         renderer: AnkiCardRenderer? = nil, loadingChanged: ((Bool) -> Void)? = nil) {
        self.content = content; self.showingBack = showingBack; self.mediaDirectory = mediaDirectory
        self.compact = compact; self.centered = centered; self.animatedReveal = animatedReveal
        self.loadingChanged = loadingChanged
        _localRenderer = StateObject(wrappedValue: renderer ?? AnkiCardRenderer())
    }

    var body: some View {
        AnkiRenderedSurface(renderer: localRenderer,
            document: Self.document(content: content, showingBack: showingBack,
                configuration: .init(dark: colorScheme == .dark, compact: compact, centered: centered,
                    animatedReveal: animatedReveal, reduceMotion: reduceMotion)),
            directory: mediaDirectory ?? content.mediaURL, compact: compact, loadingChanged: loadingChanged)
    }

    static func document(content: AnkiCardContent, showingBack: Bool, configuration: AnkiRenderConfiguration) -> String {
        let dark = configuration.dark, compact = configuration.compact, centered = configuration.centered
        let animatedReveal = configuration.animatedReveal, reduceMotion = configuration.reduceMotion
        let html = showingBack ? content.backHTML : content.frontHTML
        let cardHTML = centered ? "<main id=\"learnalert-anki-content\">\(html)</main>" : html
        let revealStyle = animatedReveal && showingBack && !reduceMotion
            ? "@keyframes learnalertReveal { from { opacity:0; transform:translateY(12px) scale(.98); } to { opacity:1; transform:none; } } #learnalert-anki-content { animation:learnalertReveal 280ms cubic-bezier(.2,.8,.2,1) both; }"
            : ""
        let hasMath = ["\\(", "\\[", "[latex]", "[$]", "[$$]"].contains { html.contains($0) }
        let mathAssets = hasMath ? """
        <link rel="stylesheet" href="anki-media://assets/katex.min.css">
        <script src="anki-media://assets/katex.min.js"></script>
        <script src="anki-media://assets/contrib/auto-render.min.js"></script>
        """ : ""
        // Templates may use inline scripts and bundled libraries, but have no network,
        // account/session access, frame navigation, or native bridge beyond local audio.
        return """
        <!doctype html><html><head><meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=5">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'unsafe-inline' anki-media:; style-src 'unsafe-inline' anki-media:; img-src anki-media: data:; media-src anki-media: data:; font-src anki-media: data:; connect-src 'none'; frame-src 'none'; base-uri 'none'; form-action 'none'">
        <style>
        :root { color-scheme: \(dark ? "dark" : "light"); } * { box-sizing: border-box; }
        body { margin:0; padding:\(compact ? 12 : 20)px; background:transparent; color:\(dark ? "#f0f1f4" : "#202631"); font: \(compact ? 17 : 22)px -apple-system, sans-serif; overflow-wrap:anywhere; }
        img,video,svg,canvas { max-width:100%; height:auto; } audio { max-width:100%; }
        .cloze { color:\(dark ? "#86c9ff" : "#1474c4"); font-weight:700; }
        .anki-sound { border:1px solid #739abb66; border-radius:14px; padding:12px 16px; margin:6px; color:inherit; background:#77baff22; font:600 15px -apple-system; }
        details { margin:12px 0; } summary { cursor:pointer; } table { max-width:100%; }
        </style><style>\(content.css.replacingOccurrences(of: "</style", with: "<\\/style", options: .caseInsensitive))</style>
        <style>\(centered ? "body { min-height:100vh; display:flex; flex-direction:column; } #learnalert-anki-content { width:100%; flex-shrink:0; margin-block:auto; } img,video { max-height:65vh; object-fit:contain; }" : "")</style>
        <style>\(revealStyle)</style>
        \(mathAssets)
        </head><body class="card card\(content.templateOrdinal + 1) iphone mobile \(dark ? "nightMode night_mode" : "")">\(cardHTML)
        <script>
        document.addEventListener('click',function(event){
          const button=event.target.closest('[data-sound],[data-speech]');
          if(!button)return;event.preventDefault();
          window.webkit.messageHandlers.ankiAudio.postMessage({sound:button.dataset.sound||'',speech:button.dataset.speech||'',language:button.dataset.language||''});
        });
        if(window.renderMathInElement){renderMathInElement(document.body,{delimiters:[
          {left:'\\\\[',right:'\\\\]',display:true},{left:'\\\\(',right:'\\\\)',display:false},
          {left:'[$$]',right:'[/$$]',display:true},{left:'[$]',right:'[/$]',display:false},
          {left:'[latex]',right:'[/latex]',display:true}
        ],throwOnError:false,trust:false,maxExpand:1000});}
        </script></body></html>
        """
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var document = ""
        var directory: URL?
        var media: AnkiMediaSchemeHandler?
        var permitsPlayback = false
        var loadCompleted: ((Error?) -> Void)?
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard !webView.isLoading else { return }
            let expectedDocument = document
            webView.evaluateJavaScript("document.readyState") { [weak self, weak webView] _, error in
                guard let self, self.document == expectedDocument, webView?.isLoading == false else { return }
                self.loadCompleted?(error)
            }
        }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            if (error as NSError).code != NSURLErrorCancelled { loadCompleted?(error) }
        }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            if (error as NSError).code != NSURLErrorCancelled { loadCompleted?(error) }
        }
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            loadCompleted?(URLError(.cannotLoadFromNetwork))
        }
        private var audio: AVAudioPlayer?
        private let speech = AVSpeechSynthesizer()

        func stop() { audio?.stop(); audio = nil; speech.stopSpeaking(at: .immediate) }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard permitsPlayback, let body = message.body as? [String: String] else { return }
            stop()
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try? AVAudioSession.sharedInstance().setActive(true)
            if let name = body["sound"], !name.isEmpty, let directory,
               let url = AnkiCardContent.safeMediaURL(name: name, directory: directory, index: media?.index) {
                audio = try? AVAudioPlayer(contentsOf: url)
                audio?.play()
            } else if let text = body["speech"], !text.isEmpty {
                let utterance = AVSpeechUtterance(string: String(text.prefix(4_000)))
                utterance.voice = AVSpeechSynthesisVoice(language: body["language"]?.replacingOccurrences(of: "_", with: "-"))
                speech.speak(utterance)
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            let scheme = action.request.url?.scheme?.lowercased()
            decisionHandler(action.navigationType == .other && (scheme == "about" || scheme == "anki-media") ? .allow : .cancel)
        }
    }
}

struct AnkiRenderConfiguration: Equatable {
    var dark = false
    var compact = false
    var centered = true
    var animatedReveal = true
    var reduceMotion = false
}

/// One renderer for the current card and one for the next; never preload a whole deck.
@MainActor final class AnkiStudyRenderCache: ObservableObject {
    private var renderers: [UUID: AnkiCardRenderer] = [:]
    var retainedRendererCount: Int { renderers.count }
    func renderer(for id: UUID) -> AnkiCardRenderer {
        if let renderer = renderers[id] { return renderer }
        let renderer = AnkiCardRenderer(); renderers[id] = renderer
        return renderer
    }
    func prepare(current: (UUID, AnkiCardContent, Bool), next: (UUID, AnkiCardContent)?, configuration: AnkiRenderConfiguration) {
        let keep = Set([current.0, next?.0].compactMap { $0 })
        for id in Array(renderers.keys) where !keep.contains(id) { renderers.removeValue(forKey: id)?.discard() }
        renderer(for: current.0).load(AnkiCardView.document(content: current.1, showingBack: current.2, configuration: configuration), directory: current.1.mediaURL)
        if let next, next.0 != current.0 {
            renderer(for: next.0).load(AnkiCardView.document(content: next.1, showingBack: false, configuration: configuration), directory: next.1.mediaURL)
        }
    }
    func clear() { renderers.values.forEach { $0.discard() }; renderers.removeAll() }
}

@MainActor final class AnkiCardRenderer: ObservableObject {
    @Published private(set) var isLoading = true
    @Published private(set) var error: String?
    let webView: WKWebView
    let coordinator = AnkiCardView.Coordinator()
    init() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.mediaTypesRequiringUserActionForPlayback = .all
        configuration.allowsInlineMediaPlayback = true
        let handler = AnkiMediaSchemeHandler()
        coordinator.media = handler
        configuration.setURLSchemeHandler(handler, forURLScheme: "anki-media")
        configuration.userContentController.add(coordinator, name: "ankiAudio")
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = coordinator
        webView.isOpaque = false; webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.alwaysBounceVertical = false
        webView.allowsBackForwardNavigationGestures = false
        coordinator.loadCompleted = { [weak self] error in
            self?.error = error == nil ? nil : "This card couldn’t load. Try again."
            self?.isLoading = false
        }
    }
    func load(_ document: String, directory: URL?) {
        guard coordinator.document != document || coordinator.directory != directory else { return }
        coordinator.stop(); error = nil; isLoading = true
        coordinator.document = document; coordinator.directory = directory
        coordinator.media?.directory = directory
        webView.loadHTMLString(document, baseURL: URL(string: "anki-media://deck/"))
    }
    func retry() {
        let document = coordinator.document, directory = coordinator.directory
        coordinator.document = ""; load(document, directory: directory)
    }
    func discard() { webView.stopLoading(); coordinator.permitsPlayback = false; coordinator.stop() }
}

private struct AnkiNativeWebView: UIViewRepresentable {
    let renderer: AnkiCardRenderer
    func makeUIView(context: Context) -> WKWebView { renderer.webView }
    func updateUIView(_ uiView: WKWebView, context: Context) { }
    func makeCoordinator() -> AnkiCardRenderer { renderer }
    static func dismantleUIView(_ uiView: WKWebView, coordinator: AnkiCardRenderer) { coordinator.coordinator.stop() }
}

private struct AnkiRenderedSurface: View {
    @ObservedObject var renderer: AnkiCardRenderer
    let document: String
    let directory: URL?
    let compact: Bool
    let loadingChanged: ((Bool) -> Void)?
    var body: some View {
        ZStack {
            AnkiNativeWebView(renderer: renderer)
                .opacity(renderer.isLoading || renderer.error != nil ? 0 : 1)
                .allowsHitTesting(!renderer.isLoading && renderer.error == nil)
                .accessibilityHidden(renderer.isLoading || renderer.error != nil)
            if renderer.isLoading {
                ProgressView("Loading card…").font(compact ? .caption : .subheadline)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = renderer.error {
                VStack(spacing: 12) {
                    Text(error).font(.subheadline).multilineTextAlignment(.center)
                    Button("Try again") { renderer.retry() }.buttonStyle(.bordered)
                }.padding()
            }
        }
        .onAppear { renderer.coordinator.permitsPlayback = true }
        .onDisappear { renderer.coordinator.permitsPlayback = false; renderer.coordinator.stop() }
        .onChange(of: document, initial: true) { _, value in renderer.load(value, directory: directory) }
        .onChange(of: directory) { _, value in renderer.load(document, directory: value) }
        .onChange(of: renderer.isLoading, initial: true) { _, value in loadingChanged?(value || renderer.error != nil) }
        .onChange(of: renderer.error) { _, value in loadingChanged?(renderer.isLoading || value != nil) }
    }
}

final class AnkiMediaSchemeHandler: NSObject, WKURLSchemeHandler {
    var index: [String: String] = [:]
    var directory: URL? {
        didSet { index = directory.map { AnkiCardContent.mediaIndex(in: $0) } ?? [:] }
    }
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let requestURL = urlSchemeTask.request.url else { urlSchemeTask.didFailWithError(URLError(.badURL)); return }
        let resolved: URL?
        if requestURL.host == "assets", let assets = Bundle.main.resourceURL?.appendingPathComponent("AnkiWebAssets") {
            let parts = requestURL.pathComponents.filter { $0 != "/" }
            let candidate = parts.reduce(assets) { $0.appendingPathComponent($1) }.standardizedFileURL
            resolved = candidate.path.hasPrefix(assets.standardizedFileURL.path + "/") ? candidate : nil
        } else if let directory, requestURL.host == "deck", requestURL.pathComponents.count == 2 {
            resolved = AnkiCardContent.safeMediaURL(name: requestURL.lastPathComponent, directory: directory, index: index)
        } else { resolved = nil }
        guard let url = resolved,
              let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= 64 * 1_024 * 1_024,
              let data = try? Data(contentsOf: url, options: .mappedIfSafe) else {
            urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist)); return
        }
        let mime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
        let response = URLResponse(url: requestURL, mimeType: mime, expectedContentLength: data.count, textEncodingName: mime.hasPrefix("text/") ? "utf-8" : nil)
        urlSchemeTask.didReceive(response); urlSchemeTask.didReceive(data); urlSchemeTask.didFinish()
    }
    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) { }
}

struct AnkiReviewControls: View {
    let isRevealed: Bool
    let isGraded: Bool
    let onReveal: () -> Void
    let onGrade: (Bool) -> Void

    var body: some View {
        if !isGraded {
            if isRevealed {
                HStack(spacing: 12) {
                    Button { onGrade(false) } label: {
                        Label("Again", systemImage: "arrow.counterclockwise").frame(maxWidth: .infinity, minHeight: 42)
                    }.buttonStyle(.bordered).tint(.orange)
                    Button { onGrade(true) } label: {
                        Label("Got it", systemImage: "checkmark").frame(maxWidth: .infinity, minHeight: 42)
                    }.buttonStyle(.borderedProminent)
                }.font(.subheadline.weight(.semibold))
            } else {
                Button(action: onReveal) {
                    Label("Show answer", systemImage: "rectangle.on.rectangle").frame(maxWidth: .infinity, minHeight: 42)
                }.buttonStyle(.borderedProminent).font(.subheadline.weight(.semibold))
            }
        }
    }
}
