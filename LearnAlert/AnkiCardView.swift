import SwiftUI
import WebKit
import AVFoundation
import UniformTypeIdentifiers

/// Imported cards have their own isolated renderer. Native LearnAlert cards never load HTML.
struct AnkiCardView: UIViewRepresentable {
    let content: AnkiCardContent
    let showingBack: Bool
    var mediaDirectory: URL? = nil
    var compact = false
    var centered = false
    var animatedReveal = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.mediaTypesRequiringUserActionForPlayback = .all
        configuration.allowsInlineMediaPlayback = true
        let handler = AnkiMediaSchemeHandler()
        context.coordinator.media = handler
        configuration.setURLSchemeHandler(handler, forURLScheme: "anki-media")
        configuration.userContentController.add(context.coordinator, name: "ankiAudio")
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.alwaysBounceVertical = false
        webView.allowsBackForwardNavigationGestures = false
        return webView
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        let html = document
        let directory = mediaDirectory ?? content.mediaURL
        guard context.coordinator.document != html || context.coordinator.directory != directory else { return }
        context.coordinator.stop()
        context.coordinator.document = html
        context.coordinator.directory = directory
        context.coordinator.media?.directory = directory
        view.loadHTMLString(html, baseURL: URL(string: "anki-media://deck/"))
    }

    static func dismantleUIView(_ view: WKWebView, coordinator: Coordinator) {
        view.stopLoading(); coordinator.stop()
        view.configuration.userContentController.removeScriptMessageHandler(forName: "ankiAudio")
        view.navigationDelegate = nil
    }

    private var document: String {
        let dark = colorScheme == .dark
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
        private var audio: AVAudioPlayer?
        private let speech = AVSpeechSynthesizer()

        func stop() { audio?.stop(); audio = nil; speech.stopSpeaking(at: .immediate) }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: String] else { return }
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
