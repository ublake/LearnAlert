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
    var presentation: AnkiStudyPresentation = .revealBelow
    var loadingChanged: ((Bool) -> Void)? = nil
    var onCardTap: (() -> Void)? = nil
    private let preparedDocument: String?
    private let preparedMediaIndex: [String: String]?
    @StateObject private var localRenderer: AnkiCardRenderer
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    init(content: AnkiCardContent, showingBack: Bool, mediaDirectory: URL? = nil,
         compact: Bool = false, centered: Bool = false, animatedReveal: Bool = false,
         renderer: AnkiCardRenderer? = nil, loadingChanged: ((Bool) -> Void)? = nil,
         preparedDocument: String? = nil, preparedMediaIndex: [String: String]? = nil,
         presentation: AnkiStudyPresentation = .revealBelow, onCardTap: (() -> Void)? = nil) {
        self.content = content; self.showingBack = showingBack; self.mediaDirectory = mediaDirectory
        self.compact = compact; self.centered = centered; self.animatedReveal = animatedReveal
        self.loadingChanged = loadingChanged
        self.presentation = presentation; self.onCardTap = onCardTap
        self.preparedDocument = preparedDocument; self.preparedMediaIndex = preparedMediaIndex
        _localRenderer = StateObject(wrappedValue: renderer ?? AnkiCardRenderer())
    }

    var body: some View {
        AnkiRenderedSurface(renderer: localRenderer,
            document: preparedDocument ?? Self.document(content: content, showingBack: showingBack,
                configuration: .init(dark: colorScheme == .dark, compact: compact, centered: centered,
                    animatedReveal: animatedReveal, reduceMotion: reduceMotion, presentation: presentation)),
            directory: mediaDirectory ?? content.mediaURL, compact: compact, loadingChanged: loadingChanged,
            mediaIndex: preparedMediaIndex, onCardTap: onCardTap)
    }

    nonisolated static func document(content: AnkiCardContent, showingBack: Bool, configuration: AnkiRenderConfiguration) -> String {
        let dark = configuration.dark, compact = configuration.compact, centered = configuration.centered
        let animatedReveal = configuration.animatedReveal, reduceMotion = configuration.reduceMotion
        let html = showingBack ? (configuration.presentation == .tapToFlip ? content.flipBackHTML : content.backHTML) : content.frontHTML
        let cardHTML = "<main id=\"learnalert-anki-content\">\(html)</main>"
        let revealStyle = configuration.presentation == .revealBelow && animatedReveal && showingBack && !reduceMotion
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
        <style>\(nativeThemeCSS(dark: dark))</style>
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
        </script><script>\(nativeThemeScript(dark: dark))</script>\(configuration.presentation == .tapToFlip ? "<script>" + cardTapScript + "</script>" : "")</body></html>
        """
    }

    /// Listen in the document, rather than covering WebKit with a native button.
    /// Template controls, media, text selection and scrolling keep their own input.
    nonisolated private static var cardTapScript: String {
        """
        (() => {
          const interactive='a,button,input,textarea,select,option,label,summary,details,audio,video,[contenteditable]:not([contenteditable="false"]),[role="button"],[role="link"],[onclick],[data-sound],[data-speech],.anki-sound';
          let start=null, moved=false, lastScroll=-1000;
          document.addEventListener('pointerdown',event=>{
            if(!event.isPrimary){moved=true;return;}
            if(event.button!==0){start=null;return;}
            start={x:event.clientX,y:event.clientY,time:performance.now()};moved=false;
          },{passive:true});
          document.addEventListener('pointermove',event=>{
            if(start && Math.hypot(event.clientX-start.x,event.clientY-start.y)>10)moved=true;
          },{passive:true});
          document.addEventListener('pointercancel',()=>{start=null;moved=true;},{passive:true});
          document.addEventListener('scroll',()=>{lastScroll=performance.now();moved=true;},{capture:true,passive:true});
          document.addEventListener('click',event=>{
            const target=event.target instanceof Element?event.target:event.target.parentElement;
            const selection=window.getSelection();
            const blocked=!event.isTrusted || event.defaultPrevented || !target || target.closest(interactive) ||
              (selection && !selection.isCollapsed) || moved || performance.now()-lastScroll<220 ||
              (start && performance.now()-start.time>700);
            start=null;
            if(blocked)return;
            window.webkit.messageHandlers.ankiCardTap.postMessage({kind:'tap'});
          });
        })();
        """
    }

    /// Keep imported structure and behavior, but let the host surface show through.
    /// Only presentation is adapted; the saved HTML/CSS and media are untouched.
    nonisolated private static func nativeThemeCSS(dark: Bool) -> String {
        """
        :root {
          --la-ink: \(dark ? "#f2f5fa" : "#19213d");
          --la-panel: \(dark ? "rgba(255,255,255,.075)" : "rgba(255,255,255,.56)");
          --la-line: \(dark ? "rgba(220,232,255,.18)" : "rgba(38,63,99,.25)");
          --la-accent: \(dark ? "#86c9ff" : "#206db0");
        }
        html:root, html:root body.card, #learnalert-anki-content {
          background-color:transparent !important; color:var(--la-ink) !important;
        }
        body.card { font-family:-apple-system,BlinkMacSystemFont,sans-serif !important; }
        #learnalert-anki-content { max-width:100%; }
        #learnalert-anki-content :is(div,section,article,table) { max-width:100%; }
        .anki-sound, button[data-sound], button[data-speech] {
          color:var(--la-ink) !important; background:rgba(119,186,255,.14) !important;
          border:1px solid var(--la-line) !important; border-radius:14px !important;
          font-family:-apple-system,BlinkMacSystemFont,sans-serif !important;
        }
        hr { border:0; border-top:1px solid var(--la-line) !important; }
        a, .cloze { color:var(--la-accent); }
        ::selection { background:rgba(119,186,255,.32); }
        """
    }

    nonisolated private static func nativeThemeScript(dark: Bool) -> String {
        """
        (() => {
          const dark=\(dark ? "true" : "false"), ink=dark?[242,245,250]:[25,33,61];
          const backdrop=dark?[25,29,40]:[238,241,248];
          const originals=new WeakMap();
          const colors=new Map(), sample=document.createElement('canvas'); sample.width=sample.height=1;
          const context=sample.getContext('2d');
          const color=value => {
            if(colors.has(value))return colors.get(value);
            let result=null;
            if(value.startsWith('rgb')) {
              const parts=value.match(/[\\d.]+/g);
              if(parts && parts.length>=3)result=parts.map(Number);
            } else if(context) {
              // Modern templates can use display-p3, lab, or color() values too.
              context.clearRect(0,0,1,1); context.fillStyle=value; context.fillRect(0,0,1,1);
              const pixel=context.getImageData(0,0,1,1).data;
              result=[pixel[0],pixel[1],pixel[2],pixel[3]/255];
            }
            colors.set(value,result); return result;
          };
          const neutral=c => Math.max(...c.slice(0,3))-Math.min(...c.slice(0,3))<36;
          const luminance=c => c.slice(0,3).reduce((sum,v,i)=>{
            v/=255; return sum+(v<=.04045?v/12.92:Math.pow((v+.055)/1.055,2.4))*[.2126,.7152,.0722][i];
          },0);
          const contrast=(a,b)=>(Math.max(luminance(a),luminance(b))+.05)/(Math.min(luminance(a),luminance(b))+.05);
          const readable=(c,background) => {
            if(neutral(c)) return `rgb(${ink.join(',')})`;
            let result=c.slice(0,3), target=luminance(background)<.18?255:0;
            for(let i=0;i<20 && contrast(result,background)<4.5;i++) result=result.map(v=>v+(target-v)*.12);
            return `rgb(${result.map(Math.round).join(',')})`;
          };
          const set=(element,key,value)=>element.style.setProperty(key,value,'important');
          const adapt=()=>{
            // Snapshot authored colors before changing ancestors, so inherited colors
            // and template-specific night-mode rules can be handled consistently.
            const elements=[document.documentElement,document.body,...document.body.querySelectorAll('*')]
              .filter(el=>!el.closest('svg,canvas,img,video,picture,script,style,link'));
            const added=elements.filter(el=>!originals.has(el));
            for(const el of added) {
              const s=getComputedStyle(el);
              originals.set(el,{ink:color(s.color),bg:color(s.backgroundColor),image:s.backgroundImage,
                border:s.borderTopWidth!=='0px'||s.borderRightWidth!=='0px'||s.borderBottomWidth!=='0px'||s.borderLeftWidth!=='0px',
                radius:s.borderRadius,shadow:s.boxShadow});
            }
            for(const el of added) {
              const s=originals.get(el);
              if(el===document.documentElement||el===document.body||el.id==='learnalert-anki-content') {
                set(el,'background-color','transparent'); set(el,'color','var(--la-ink)');
                if(!s.image.includes('url(')) set(el,'background-image','none');
                set(el,'box-shadow','none');
                continue;
              }
              const gradient=s.image.includes('gradient(')&&!s.image.includes('url(');
              if(gradient) { set(el,'background-image','none'); set(el,'background-color','var(--la-panel)'); }
              if(s.bg && (s.bg[3]===undefined||s.bg[3]>.03)) {
                // Preserve image backgrounds and meaningful colored highlights.
                // Neutral HTML boxes become softly separated app-like surfaces.
                if(neutral(s.bg)) set(el,'background-color','var(--la-panel)');
                else set(el,'background-color',`rgba(${s.bg.slice(0,3).map(Math.round).join(',')},${dark ? .18 : .12})`);
                if(s.image==='none' && !['SPAN','MARK','TD','TH','TR'].includes(el.tagName)) {
                  set(el,'border-radius',s.radius==='0px'?'14px':s.radius);
                }
              }
              if(s.border) set(el,'border-color','var(--la-line)');
              if(s.shadow!=='none') set(el,'box-shadow',dark?'0 3px 12px rgba(0,0,0,.12)':'0 3px 12px rgba(25,40,65,.07)');
            }
            const backgrounds=new WeakMap();
            const background=el=>{
              if(!el)return backdrop;
              if(backgrounds.has(el))return backgrounds.get(el);
              const base=background(el.parentElement), c=color(getComputedStyle(el).backgroundColor);
              const alpha=c?(c[3]===undefined?1:c[3]):0;
              const result=c?base.map((v,i)=>c[i]*alpha+v*(1-alpha)):base;
              backgrounds.set(el,result); return result;
            };
            // Do not replay old colors over a template's later reveal/hide actions.
            for(const el of added) {
              const c=originals.get(el).ink;
              // Transparent text is often a deliberate template answer/reveal mask.
              if(c && (c[3]===undefined||c[3]>.03) && el!==document.documentElement && el!==document.body && el.id!=='learnalert-anki-content') {
                set(el,'color',readable(c,background(el)));
              }
            }
          };
          adapt();
          let pending=false;
          new MutationObserver(()=>{
            if(pending)return; pending=true;
            requestAnimationFrame(()=>{pending=false;adapt();});
          }).observe(document.body,{childList:true,subtree:true});
          window.addEventListener('load',adapt,{once:true});
        })();
        """
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var document = ""
        var directory: URL?
        var media: AnkiMediaSchemeHandler?
        var permitsPlayback = false
        var documentReady = false
        private(set) var surfaceID: UUID?
        private var onCardTap: (() -> Void)?
        var loadCompleted: ((Error?) -> Void)?

        func attach(surfaceID: UUID, onCardTap: (() -> Void)?) {
            self.surfaceID = surfaceID
            self.onCardTap = onCardTap
            permitsPlayback = true
        }

        func detach(surfaceID: UUID) {
            guard self.surfaceID == surfaceID else { return }
            self.surfaceID = nil; onCardTap = nil; permitsPlayback = false
            stop()
        }

        func detachAll() {
            surfaceID = nil; onCardTap = nil; permitsPlayback = false
            stop()
        }
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
            if message.name == "ankiCardTap" {
                guard message.frameInfo.isMainFrame, permitsPlayback, documentReady, surfaceID != nil,
                      let body = message.body as? [String: String], body["kind"] == "tap" else { return }
                onCardTap?()
                return
            }
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

/// Study-only presentation. Import previews and editors keep their separate,
/// explicit front/back controls and never inherit a global flipping gesture.
struct AnkiStudyCardView: View {
    let content: AnkiCardContent
    @Binding var showingBack: Bool
    var mediaDirectory: URL? = nil
    var compact = false
    var centered = true
    var renderer: AnkiCardRenderer? = nil
    var isEnabled = true
    var loadingChanged: ((Bool) -> Void)? = nil

    @AppStorage(AnkiStudyPresentation.storageKey, store: UserDefaults(suiteName: "group.com.learnalert.shared"))
    private var presentationRaw = AnkiStudyPresentation.revealBelow.rawValue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.notificationDesignTheme) private var notificationDesign
    @State private var displayedBack = false
    @State private var angle: Double = 0
    @State private var isTurning = false
    @State private var isLoading = true
    @State private var turnID = UUID()

    init(content: AnkiCardContent, showingBack: Binding<Bool>, mediaDirectory: URL? = nil,
         compact: Bool = false, centered: Bool = true, renderer: AnkiCardRenderer? = nil,
         isEnabled: Bool = true, loadingChanged: ((Bool) -> Void)? = nil) {
        self.content = content; _showingBack = showingBack; self.mediaDirectory = mediaDirectory
        self.compact = compact; self.centered = centered; self.renderer = renderer
        self.isEnabled = isEnabled; self.loadingChanged = loadingChanged
        _displayedBack = State(initialValue: showingBack.wrappedValue)
    }

    private var presentation: AnkiStudyPresentation { AnkiStudyPresentation(rawValue: presentationRaw) ?? .revealBelow }
    private var busy: Bool { isTurning || isLoading }
    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: notificationDesign?.cornerRadius(20) ?? 20, style: .continuous)
    }

    var body: some View {
        Group {
            if presentation == .tapToFlip {
                AnkiCardView(content: content, showingBack: displayedBack, mediaDirectory: mediaDirectory,
                    compact: compact, centered: centered, animatedReveal: false, renderer: renderer,
                    loadingChanged: { isLoading = $0 }, presentation: .tapToFlip, onCardTap: flip)
                    .background(Color.primary.opacity(colorScheme == .dark ? 0.045 : 0.025), in: shape)
                    .overlay(shape.strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.28 : 0.23), lineWidth: 1.2).allowsHitTesting(false))
                    .clipShape(shape)
                    .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.55)
                    .accessibilityElement(children: .contain)
                    .accessibilityHint(showingBack ? "Tap the card background to return to the front." : "Tap the card background to show the answer.")
                    .accessibilityAction(named: showingBack ? "Flip to front" : "Flip to answer") { flip() }
            } else {
                AnkiCardView(content: content, showingBack: showingBack, mediaDirectory: mediaDirectory,
                    compact: compact, centered: centered, animatedReveal: true, renderer: renderer,
                    loadingChanged: loadingChanged)
            }
        }
        .onAppear {
            displayedBack = showingBack
            angle = 0
            if presentation == .tapToFlip { loadingChanged?(busy) }
        }
        .onChange(of: showingBack) { _, back in
            if presentation == .tapToFlip { turn(to: back) }
            else { displayedBack = back }
        }
        .onChange(of: busy) { _, value in
            if presentation == .tapToFlip { loadingChanged?(value) }
        }
        .onChange(of: presentation) { _, _ in
            turnID = UUID(); isTurning = false; angle = 0; displayedBack = showingBack
        }
        .onChange(of: reduceMotion) { _, _ in
            turnID = UUID(); isTurning = false; angle = 0; displayedBack = showingBack
        }
        .onDisappear { turnID = UUID(); isTurning = false }
    }

    private func flip() {
        guard isEnabled, !busy else { return }
        // Revealing is deliberately separate from grading or changing review dates.
        showingBack.toggle()
    }

    private func turn(to back: Bool) {
        let id = UUID()
        turnID = id
        isTurning = true
        loadingChanged?(true)
        guard !reduceMotion else {
            displayedBack = back; angle = 0
            Task { @MainActor in
                await Task.yield()
                guard turnID == id else { return }
                isTurning = false
                loadingChanged?(isLoading)
            }
            return
        }
        withAnimation(.easeIn(duration: 0.18), completionCriteria: .logicallyComplete) {
            angle = 90
        } completion: {
            guard turnID == id else { return }
            // Swap exactly at the edge: the reader never sees the other side mirrored.
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { displayedBack = back; angle = -90 }
            Task { @MainActor in
                await Task.yield()
                guard turnID == id else { return }
                withAnimation(.easeOut(duration: 0.22), completionCriteria: .logicallyComplete) {
                    angle = 0
                } completion: {
                    guard turnID == id else { return }
                    isTurning = false
                }
            }
        }
    }
}

nonisolated struct AnkiRenderConfiguration: Equatable, Sendable {
    var dark = false
    var compact = false
    var centered = true
    var animatedReveal = true
    var reduceMotion = false
    var presentation: AnkiStudyPresentation = .revealBelow
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
        configuration.userContentController.add(coordinator, name: "ankiCardTap")
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = coordinator
        webView.isOpaque = false; webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.alwaysBounceVertical = false
        webView.allowsBackForwardNavigationGestures = false
        coordinator.loadCompleted = { [weak self] error in
            self?.coordinator.documentReady = error == nil
            self?.error = error == nil ? nil : "This card couldn’t load. Try again."
            self?.isLoading = false
        }
    }
    func load(_ document: String, directory: URL?, mediaIndex: [String: String]? = nil) {
        guard coordinator.document != document || coordinator.directory != directory else { return }
        coordinator.stop(); coordinator.documentReady = false; error = nil; isLoading = true
        coordinator.document = document; coordinator.directory = directory
        coordinator.media?.setDirectory(directory, preparedIndex: mediaIndex)
        webView.loadHTMLString(document, baseURL: URL(string: "anki-media://deck/"))
    }
    func retry() {
        let document = coordinator.document, directory = coordinator.directory
        coordinator.document = ""; load(document, directory: directory)
    }
    func discard() { webView.stopLoading(); coordinator.documentReady = false; coordinator.detachAll() }
}

private struct AnkiNativeWebView: UIViewRepresentable {
    let renderer: AnkiCardRenderer
    let surfaceID: UUID
    let onCardTap: (() -> Void)?
    let isActive: Bool
    final class Attachment {
        let renderer: AnkiCardRenderer
        let surfaceID: UUID
        init(renderer: AnkiCardRenderer, surfaceID: UUID) { self.renderer = renderer; self.surfaceID = surfaceID }
    }
    func makeUIView(context: Context) -> WKWebView {
        if isActive { renderer.coordinator.attach(surfaceID: surfaceID, onCardTap: onCardTap) }
        return renderer.webView
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {
        if isActive { renderer.coordinator.attach(surfaceID: surfaceID, onCardTap: onCardTap) }
        else { renderer.coordinator.detach(surfaceID: surfaceID) }
    }
    func makeCoordinator() -> Attachment { Attachment(renderer: renderer, surfaceID: surfaceID) }
    static func dismantleUIView(_ uiView: WKWebView, coordinator: Attachment) {
        coordinator.renderer.coordinator.detach(surfaceID: coordinator.surfaceID)
    }
}

private struct AnkiRenderedSurface: View {
    @ObservedObject var renderer: AnkiCardRenderer
    let document: String
    let directory: URL?
    let compact: Bool
    let loadingChanged: ((Bool) -> Void)?
    var mediaIndex: [String: String]? = nil
    var onCardTap: (() -> Void)? = nil
    @State private var surfaceID = UUID()
    @State private var isVisible = false
    var body: some View {
        ZStack {
            AnkiNativeWebView(renderer: renderer, surfaceID: surfaceID, onCardTap: onCardTap, isActive: isVisible)
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
        .onAppear { isVisible = true; renderer.coordinator.attach(surfaceID: surfaceID, onCardTap: onCardTap) }
        .onDisappear { isVisible = false; renderer.coordinator.detach(surfaceID: surfaceID) }
        .onChange(of: document, initial: true) { _, value in renderer.load(value, directory: directory, mediaIndex: mediaIndex) }
        .onChange(of: directory) { _, value in renderer.load(document, directory: value, mediaIndex: mediaIndex) }
        .onChange(of: renderer.isLoading, initial: true) { _, value in loadingChanged?(value || renderer.error != nil) }
        .onChange(of: renderer.error) { _, value in loadingChanged?(renderer.isLoading || value != nil) }
    }
}

final class AnkiMediaSchemeHandler: NSObject, WKURLSchemeHandler {
    var index: [String: String] = [:]
    private var mediaDirectory: URL?
    var directory: URL? {
        get { mediaDirectory }
        set { setDirectory(newValue) }
    }
    func setDirectory(_ directory: URL?, preparedIndex: [String: String]? = nil) {
        guard mediaDirectory != directory || preparedIndex != nil else { return }
        mediaDirectory = directory
        index = preparedIndex ?? directory.map { AnkiCardContent.mediaIndex(in: $0) } ?? [:]
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
    var options: [AnkiReviewOption] = []
    var tapToFlip = false
    let onReveal: () -> Void
    let onGrade: (AnkiReviewRating) -> Void
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.notificationDesignTheme) private var notificationDesign

    var body: some View {
        if !isGraded {
            if isRevealed {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: notificationDesign?.spacing(8) ?? 8), count: typeSize.isAccessibilitySize ? 2 : 4), spacing: notificationDesign?.spacing(8) ?? 8) {
                    ForEach(options, id: \.rating) { option in
                        Button { onGrade(option.rating) } label: {
                            VStack(spacing: 4) {
                                Text(option.intervalLabel)
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                Text(option.rating.title)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1).minimumScaleFactor(0.8)
                                    .foregroundStyle(option.rating.reviewTint)
                            }
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .padding(.vertical, notificationDesign?.verticalPadding(6) ?? 6)
                            .modifier(AnkiNotificationRatingSurface(tint: option.rating.reviewTint))
                            .contentShape(RoundedRectangle(cornerRadius: notificationDesign?.cornerRadius(14) ?? 14))
                        }
                        .buttonStyle(AnkiRatingButtonStyle())
                        .accessibilityLabel("\(option.rating.title), next review in \(option.intervalLabel)")
                    }
                }
            } else if tapToFlip {
                Label("Tap card to flip", systemImage: "hand.tap")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 24)
                    .accessibilityHidden(true)
            } else {
                Button(action: onReveal) {
                    Label("Flip/reveal", systemImage: "rectangle.on.rectangle").frame(maxWidth: .infinity, minHeight: 42)
                }.notificationPrimaryActionStyle().font(.subheadline.weight(.semibold))
            }
        }
    }
}

private struct AnkiNotificationRatingSurface: ViewModifier {
    let tint: Color
    @Environment(\.notificationDesignTheme) private var design
    @Environment(\.colorScheme) private var colorScheme

    @ViewBuilder
    func body(content: Content) -> some View {
        if let design, design != .liquidGlass {
            content.notificationControlSurface(cornerRadius: 14, tint: tint.opacity(0.12),
                isLight: colorScheme == .light, customBorderColor: tint.opacity(0.6))
        } else {
            content.background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(tint.opacity(0.28), lineWidth: 1).allowsHitTesting(false))
        }
    }
}

extension AnkiReviewRating {
    var reviewTint: Color {
        switch self {
        case .again: .red
        case .hard: .orange
        case .good: .blue
        case .easy: .teal
        }
    }
}

private struct AnkiRatingButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.76 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
