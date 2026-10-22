import SwiftUI

/// Shared by the full-screen course and the expanded notification.
struct CourseActivityPanel: View {
    let card: CourseLessonCard
    let activity: CourseActivity
    let immersive: Bool
    let checkpoint: Bool
    let allowRecordedAudio: Bool
    let allowKoreanSpeech: Bool
    let prefersReading: Bool
    let onReadingRequested: () -> Void
    let onListeningRequested: () -> Void
    let onAnswer: (Bool) -> Void
    @StateObject private var speech = CourseSpeechHandle()
    @Environment(\.dynamicTypeSize) private var textSize
    @Environment(\.courseNotificationCompact) private var notificationCompact
    @State private var hints = false
    @State private var reading = false
    @State private var result: Bool?
    @State private var selected: String?
    @State private var choices: [String] = []
    @State private var placement: CoursePlacementState
    @State private var placementMessage: String?

    init(card: CourseLessonCard, activity: CourseActivity, immersive: Bool, checkpoint: Bool,
         allowRecordedAudio: Bool = true, allowKoreanSpeech: Bool = false, prefersReading: Bool,
         onReadingRequested: @escaping () -> Void, onListeningRequested: @escaping () -> Void = {},
         onAnswer: @escaping (Bool) -> Void) {
        self.card = card; self.activity = activity; self.immersive = immersive; self.checkpoint = checkpoint
        self.allowRecordedAudio = allowRecordedAudio; self.allowKoreanSpeech = allowKoreanSpeech; self.prefersReading = prefersReading
        self.onReadingRequested = onReadingRequested; self.onListeningRequested = onListeningRequested; self.onAnswer = onAnswer
        _placement = State(initialValue: CoursePlacementState(count: activity.slots.count))
        _choices = State(initialValue: (activity.kind == .buildBlock || activity.kind == .placeTokens ? activity.tokens : card.options).shuffled())
    }

    private var audioSource: CourseAudioSource? {
        CourseAudioPolicy.source(for: card, allowRecordedAudio: allowRecordedAudio, allowKoreanSpeech: allowKoreanSpeech)
    }
    private var audio: Bool { audioSource != nil && !prefersReading && !reading }
    private var isPlacement: Bool { activity.kind == .buildBlock || activity.kind == .placeTokens }
    private var compact: Bool { notificationCompact && !immersive && activity.kind != .trace }

    var body: some View {
        Group {
        if let exercise = activity.exercise, exercise.usesPracticeRenderer {
            CoursePracticeExercisePanel(card: card, exercise: exercise, immersive: immersive, checkpoint: checkpoint, onAnswer: onAnswer)
        } else {
        VStack(spacing: immersive ? 24 : compact ? 8 : 14) {
            HStack {
                Label(activityLabel, systemImage: activityIcon).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                if !checkpoint && (!activity.optionHints.isEmpty || (activity.rule != nil && activity.kind != .trace)) && activity.kind != .teach {
                    Button { hints.toggle() } label: {
                        Image(systemName: hints ? "lightbulb.fill" : "lightbulb").frame(width: 44, height: 44)
                    }.accessibilityLabel(hints ? "Hide hints" : activity.optionHints.isEmpty ? "Show rule" : "Show hints on each option")
                        .accessibilityValue(hints ? "On" : "Off")
                }
            }
            Text(CourseKoreanText.attributed(card.isListeningQuestion && !audio ? CourseAudioPolicy.readingQuestion(for: card) : card.question))
                .font(immersive ? .title2.bold() : .headline).multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            if let image = card.resolvedFieldMedia["prompt"]?.image {
                CourseVocabularyImage(name: image, label: card.vocabularyItem?.contextualMeaning ?? "Vocabulary picture", compact: !immersive)
            }
            if !card.isListeningQuestion && activity.kind != .teach, audio,
               case let .recording(name)? = audioSource {
                CardAudioPlaybackButton(name: name)
            }
            if card.isListeningQuestion { listeningControl }
            if activity.kind == .teach {
                teaching
            } else {
                if (hints || activity.kind == .trace), let rule = activity.rule {
                    Text(CourseKoreanText.attributed(rule)).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                if activity.kind == .trace, let symbol = activity.symbol {
                    CourseTracePanel(symbol: symbol, options: card.options, compact: !immersive,
                                     checkpoint: checkpoint, onAnswer: finish)
                } else if activity.kind == .matchPairs {
                    CourseMatchingPanel(card: card, immersive: immersive, onAnswer: finish)
                } else if isPlacement {
                    placementPanel
                } else {
                    optionGrid
                }
            }
            if activity.kind != .teach, result != nil, let media = card.resolvedFieldMedia["answer"] {
                CardFieldContent(media: media, imageHeight: immersive ? 224 : 120)
            }
            if let result, !immersive {
                Label(card.feedbackTitle(isCorrect: result), systemImage: result ? (card.isReadThrough ? "book.closed.fill" : "checkmark.circle.fill") : "arrow.counterclockwise")
                    .foregroundStyle(result ? (card.isReadThrough ? CourseKoreanText.emphasisColor : Color.green) : .orange).font(.subheadline.weight(.semibold))
                if !result { Text(card.correctAnswer).font(.headline) }
                if !checkpoint, let explanation = card.explanation { Text(CourseKoreanText.attributed(explanation)).font(.callout).foregroundStyle(.secondary) }
            }
        }
        .onAppear { if choices.isEmpty { choices = (isPlacement ? activity.tokens : card.options).shuffled() } }
        .onChange(of: prefersReading) { _, value in if !value { reading = false } }
        }
        }
    }

    private var teaching: some View {
        VStack(spacing: compact ? 10 : 20) {
            if let rule = activity.rule { Text(CourseKoreanText.attributed(rule)).font(immersive ? .title3 : .body).fixedSize(horizontal: false, vertical: true) }
            if let example = activity.example {
                Text(CourseKoreanText.attributed(example)).font(immersive ? .title2.weight(.semibold) : .title3.weight(.semibold))
                    .multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(compact ? 10 : 20)
                    .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
            }
            if !card.isListeningQuestion, audio, let source = audioSource {
                switch source {
                case .recording(let name):
                    CardAudioPlaybackButton(name: name)
                case .koreanSpeech(let text):
                    Button { speech.speak(text) } label: { Label("Hear the example", systemImage: "speaker.wave.2.fill").frame(minHeight: 44) }
                }
            }
            if let media = card.resolvedFieldMedia["answer"] { CardFieldContent(media: media, imageHeight: immersive ? 224 : 120) }
            if result == nil { Button("Got it") { finish(true) }.buttonStyle(.borderedProminent).controlSize(.large) }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var listeningControl: some View {
        if audio, let source = audioSource {
            VStack(spacing: compact ? 4 : 8) {
                switch source {
                case .recording(let name):
                    CardAudioPlaybackButton(name: name)
                case .koreanSpeech(let text):
                    spokenListeningControl(text)
                }
                if result == nil {
                    Button("I can’t listen right now", action: requestReading).font(.subheadline).frame(minHeight: 44)
                }
            }
        } else if audioSource != nil, result == nil {
            Button("Back to listening", action: requestListening).font(.subheadline).frame(minHeight: 44)
        } else if audioSource == nil && (allowRecordedAudio || allowKoreanSpeech) {
            Text("Audio is unavailable. Using text practice.").font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private func spokenListeningControl(_ text: String) -> some View {
        if compact {
            HStack(spacing: 8) {
                Button { speech.speak(text) } label: {
                    Label(speech.isSpeaking ? "Again" : "Play", systemImage: speech.isSpeaking ? "waveform" : "play.fill")
                        .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 44)
                }.buttonStyle(.borderedProminent).accessibilityLabel("Play Korean sound")
                Button { speech.speak(text, speed: .slow) } label: {
                    Image(systemName: "tortoise.fill").frame(width: 44, height: 44)
                }.buttonStyle(.plain).accessibilityLabel("Play slowly")
            }
        } else {
            VStack(spacing: 8) {
                Button { speech.speak(text) } label: {
                    VStack(spacing: 10) {
                        ZStack {
                            Circle().fill(Color.accentColor.opacity(0.12)).frame(width: immersive ? 104 : 72, height: immersive ? 104 : 72)
                            Image(systemName: speech.isSpeaking ? "waveform" : "play.fill").font(immersive ? .largeTitle : .title2)
                        }
                        Text(speech.isSpeaking ? "Play again" : "Play sound").font(.subheadline.weight(.semibold))
                    }.frame(maxWidth: .infinity)
                }.buttonStyle(.plain).accessibilityLabel("Play Korean sound")
                Button("Slower") { speech.speak(text, speed: .slow) }.font(.subheadline).frame(minHeight: 44)
            }
        }
    }

    private func requestReading() { speech.stop(); reading = true; onReadingRequested() }
    private func requestListening() { reading = false; onListeningRequested() }

    @ViewBuilder private var optionGrid: some View {
        if card.hasChoiceMedia {
            CardMediaChoiceList(options: card.options, fields: card.resolvedFieldMedia,
                correctIndex: card.resolvedCorrectOptionIndex, selection: selected, isGraded: result != nil) { value in
                    guard let index = CardChoiceIdentity.index(value, options: card.options) else { return }
                    selected = value
                    finish(index == card.resolvedCorrectOptionIndex)
                }
        } else {
            LazyVGrid(columns: optionColumns, spacing: compact ? 8 : 12) {
                ForEach(choices, id: \.self) { option in
                    Button { selected = option; finish(card.accepts(option)) } label: {
                        VStack(spacing: compact ? 4 : 8) {
                            Text(option).font(option.count <= 3 ? .system(size: immersive ? 40 : 30, weight: .medium) : .body.weight(.medium))
                                .fixedSize(horizontal: false, vertical: true)
                            if hints, !checkpoint, let hint = activity.optionHints[option] {
                                Text(CourseKoreanText.attributed(hint)).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                            }
                            if result != nil && (selected == option || card.accepts(option)) {
                                Image(systemName: card.accepts(option) ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(card.accepts(option) ? Color.green : .orange)
                            }
                        }.padding(compact ? 8 : 12).frame(maxWidth: .infinity, minHeight: immersive ? 120 : compact ? 56 : 92)
                            .background(optionBackground(option), in: RoundedRectangle(cornerRadius: 18))
                            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.primary.opacity(0.16), lineWidth: 1))
                    }.buttonStyle(.plain).disabled(result != nil)
                        .accessibilityLabel(option + (hints && !checkpoint ? ", " + (activity.optionHints[option] ?? "") : ""))
                }
            }
        }
    }

    private var optionColumns: [GridItem] {
        let shortOptions = card.options.allSatisfy { $0.count <= 12 }
        return shortOptions && !textSize.isAccessibilitySize
            ? [GridItem(.flexible()), GridItem(.flexible())] : [GridItem(.flexible())]
    }

    private var placementPanel: some View {
        VStack(spacing: compact ? 8 : 16) {
            if activity.kind == .buildBlock {
                VStack(spacing: compact ? 4 : 8) {
                    if activity.layout == .beside || activity.layout == .besideWithFinal {
                        HStack(spacing: 8) { slot(0); slot(1) }
                    } else { VStack(spacing: 8) { slot(0); slot(1) } }
                    if activity.slots.count > 2 { slot(2) }
                }.frame(maxWidth: immersive ? 240 : 190).padding(compact ? 6 : 12)
                    .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 24))
            } else {
                HStack(spacing: 8) { ForEach(activity.slots.indices, id: \.self) { slot($0) } }
            }
            Text(placementMessage ?? (placement.selectedToken == nil ? "Drag a tile, or tap a tile then its space." : "Tap a space for \(placement.selectedToken ?? "")."))
                .font(.caption).foregroundStyle(placementMessage == nil ? Color.secondary : .orange)
                .multilineTextAlignment(.center)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 10) {
                ForEach(choices, id: \.self) { token in
                    Button { placement.selectedToken = placement.selectedToken == token ? nil : token; placementMessage = nil } label: {
                        Text(token).font(token.count <= 2 ? .title2.weight(.semibold) : .body.weight(.medium))
                            .frame(maxWidth: .infinity, minHeight: compact ? 44 : 50)
                            .background(Color.accentColor.opacity(placement.selectedToken == token ? 0.22 : 0.07), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(placement.selectedToken == token ? Color.accentColor : Color.clear, lineWidth: 2))
                    }.buttonStyle(.plain).courseTileDrag(token, enabled: !notificationCompact).disabled(result != nil)
                        .accessibilityLabel("Tile \(token)").accessibilityAddTraits(placement.selectedToken == token ? .isSelected : [])
                }
            }
            if result == nil {
                Button("Check") {
                    let correct = placement.check(expected: activity.slots)
                    if checkpoint || correct { finish(correct && !placement.hadMistake) }
                    else { placementMessage = "Look at the positions and try again." }
                }.buttonStyle(.borderedProminent).disabled(!placement.filled).controlSize(.large)
            } else if let example = activity.example {
                Text(CourseKoreanText.attributed(example)).font(.title2.weight(.semibold))
            }
        }
    }

    private func slot(_ index: Int) -> some View {
        let label = activity.slotLabels.indices.contains(index) ? activity.slotLabels[index] : "Space \(index + 1)"
        return Button {
            guard result == nil else { return }
            if let token = placement.selectedToken { _ = placement.place(token, in: index, available: activity.tokens) }
            else { placement.values[index] = nil }
            placementMessage = nil
        } label: {
            VStack(spacing: 3) {
                Text(placement.values[index] ?? "+").font(.system(size: immersive ? 34 : 26, weight: .medium))
                Text(label).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
            }.padding(compact ? 4 : 6).frame(maxWidth: .infinity, minHeight: immersive ? 90 : compact ? 48 : 72)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.accentColor.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: placement.values[index] == nil ? [5] : [])))
        }.buttonStyle(.plain).disabled(result != nil)
            .accessibilityLabel("\(label), \(placement.values[index] ?? "empty")")
            .accessibilityHint(placement.selectedToken == nil ? "Select a tile first, or activate to clear this space." : "Place selected tile.")
            .courseTileDrop(enabled: !notificationCompact) { items in
                guard result == nil, items.count == 1, let item = items.first else { return false }
                placementMessage = nil
                return placement.place(item, in: index, available: activity.tokens)
            }
    }

    private func optionBackground(_ option: String) -> Color {
        if result != nil && card.accepts(option) { return Color.green.opacity(0.13) }
        if result != nil && selected == option { return Color.orange.opacity(0.13) }
        return Color(.secondarySystemGroupedBackground)
    }
    private var activityLabel: String {
        if card.isListeningQuestion { return audio ? "Listen" : "Read" }
        switch activity.kind {
        case .teach: return "Learn"
        case .trace: return "Trace"
        case .buildBlock: return "Build a block"
        case .placeTokens: return "Arrange"
        case .listenChoose: return audio ? "Listen" : "Read"
        case .situation: return card.promptImageName == nil ? "Use the language" : "Picture vocabulary"
        case .matchPairs: return "Match"
        }
    }
    private var activityIcon: String {
        if card.isListeningQuestion { return audio ? "waveform" : "textformat" }
        switch activity.kind {
        case .teach: return "sparkles"
        case .trace: return "hand.draw"
        case .buildBlock: return "square.grid.2x2"
        case .placeTokens: return "rectangle.3.group"
        case .listenChoose: return audio ? "waveform" : "textformat"
        case .situation: return "bubble.left"
        case .matchPairs: return "arrow.left.arrow.right"
        }
    }
    private func finish(_ correct: Bool) { guard result == nil else { return }; result = correct; speech.stop(); onAnswer(correct) }
}

private struct CourseTracePanel: View {
    let symbol: String
    let options: [String]
    let compact: Bool
    let checkpoint: Bool
    let onAnswer: (Bool) -> Void
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @State private var completed = 0
    @State private var completedStrokes: [[CGPoint]] = []
    @State private var input: [CGPoint] = []
    @State private var message: String?
    @State private var tapMode = false
    @State private var finished = false
    @State private var tapChoices: [String] = []
    @State private var guidance: CourseTraceGuidance
    @State private var attemptStarted = false
    @State private var attemptStamp = UUID()
    private var guides: [[CGPoint]] { HangulStrokeGuide.strokes(for: symbol) }

    init(symbol: String, options: [String], compact: Bool, checkpoint: Bool, onAnswer: @escaping (Bool) -> Void) {
        self.symbol = symbol; self.options = options; self.compact = compact; self.checkpoint = checkpoint; self.onAnswer = onAnswer
        _tapChoices = State(initialValue: (options.isEmpty ? [symbol] : options).shuffled())
        let attempts = CourseLearningStore.shared.snapshot().traceAttempts[symbol] ?? 0
        _guidance = State(initialValue: CourseTraceGuidance(attempt: attempts + 1))
    }

    var body: some View {
        VStack(spacing: 12) {
            if tapMode || voiceOver || guides.isEmpty {
                Text("Find \(symbol)").font(.title2).accessibilityLabel("Find the letter \(symbol)")
                HStack {
                    ForEach(tapChoices, id: \.self) { option in
                        Button(option) { guard !finished else { return }; finished = true; onAnswer(option == symbol) }
                            .font(.title).frame(maxWidth: .infinity, minHeight: 56).buttonStyle(.bordered).disabled(finished)
                    }
                }
            } else {
                GeometryReader { geometry in
                    TimelineView(.animation(minimumInterval: 1.0 / 24, paused: !guidance.highlightsDirection || finished)) { timeline in
                        Canvas { context, size in
                            if guidance.showsGuide {
                                for (index, stroke) in guides.enumerated() where index >= completed {
                                    let guide = path(stroke, size: size)
                                    context.stroke(guide, with: .color(.secondary.opacity(0.13)), style: StrokeStyle(lineWidth: 14, lineCap: .round, lineJoin: .round))
                                    if index == completed {
                                        if guidance.attempt <= 2 {
                                            context.stroke(guide, with: .color(.accentColor.opacity(0.45)), style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [5, 5]))
                                        }
                                        if guidance.highlightsDirection {
                                            let phase = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.8) / 1.8
                                            context.stroke(guide.trimmedPath(from: 0, to: phase), with: .color(.accentColor.opacity(0.65)), style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
                                        }
                                    }
                                }
                            }
                            for stroke in completedStrokes {
                                context.stroke(path(stroke, size: size), with: .color(.accentColor), style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round))
                            }
                            context.stroke(path(input, size: size), with: .color(.accentColor), style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round))
                        }
                    }
                    .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 24))
                    .contentShape(Rectangle())
                    .highPriorityGesture(DragGesture(minimumDistance: 0).onChanged { value in
                        guard !finished else { return }
                        if !attemptStarted {
                            let attempt = CourseLearningStore.shared.transaction { snapshot in
                                snapshot.traceAttempts[symbol, default: 0] += 1
                                return snapshot.traceAttempts[symbol] ?? 1
                            }
                            guidance = CourseTraceGuidance(attempt: attempt ?? guidance.attempt, needsHelp: guidance.needsHelp)
                            attemptStarted = true
                            attemptStamp = UUID()
                        }
                        input.append(CGPoint(x: min(1, max(0, value.location.x / geometry.size.width)), y: min(1, max(0, value.location.y / geometry.size.height))))
                    }.onEnded { _ in
                        guard !finished, guides.indices.contains(completed) else { return }
                        if HangulStrokeGuide.accepts(input, target: guides[completed]) {
                            completedStrokes.append(input)
                            completed += 1; message = nil
                            if completed == guides.count { finished = true; onAnswer(true) }
                        } else {
                            completed = 0; completedStrokes = []
                            attemptStarted = false
                            guidance.needsHelp = true
                            message = "Watch the highlighted stroke, then try again."
                        }
                        input = []
                    })
                }.frame(width: compact ? 200 : 260, height: compact ? 200 : 260)
                    .accessibilityHidden(true)
                Text(message ?? (finished ? "Letter complete" : guidance.showsGuide ? "Follow the stroke direction" : "Draw from memory"))
                    .font(.caption).foregroundStyle(message == nil ? Color.secondary : .orange).multilineTextAlignment(.center)
                if !finished {
                    HStack {
                        Button("Start over") {
                            completed = 0; completedStrokes = []; input = []; message = nil
                            attemptStarted = false
                            guidance = CourseTraceGuidance(attempt: (CourseLearningStore.shared.snapshot().traceAttempts[symbol] ?? 0) + 1)
                            attemptStamp = UUID()
                        }.frame(minHeight: 44)
                        Button("Use tap practice") { tapMode = true }.frame(minHeight: 44)
                    }.font(.subheadline)
                }
            }
        }
        .task(id: attemptStamp) {
            do { try await Task.sleep(for: .seconds(60)) } catch { return }
            guard !finished else { return }
            guidance.elapsed = 60
            message = "Here’s the stroke direction. Try it when you’re ready."
        }
    }
    private func path(_ points: [CGPoint], size: CGSize) -> Path {
        var path = Path()
        for (index, point) in points.enumerated() {
            let scaled = CGPoint(x: point.x * size.width, y: point.y * size.height)
            if index == 0 { path.move(to: scaled) } else { path.addLine(to: scaled) }
        }
        return path
    }
}


/// Natural-width rows shared by the answer strip and bank. Text grows vertically.
struct CourseWrappingLayout: Layout {
    var spacing: CGFloat = 8
    private func positions(_ proposal: ProposedViewSize, _ subviews: Subviews) -> ([CGPoint], CGSize) {
        let width = max(1, proposal.width ?? 320)
        var points: [CGPoint] = [], x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.init(width: width, height: nil))
            if x > 0 && x + size.width > width { x = 0; y += row + spacing; row = 0 }
            points.append(CGPoint(x: x, y: y)); x += min(size.width, width) + spacing; row = max(row, size.height)
        }
        return (points, CGSize(width: width, height: y + row))
    }
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize { positions(proposal, subviews).1 }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let (points, _) = positions(.init(width: bounds.width, height: nil), subviews)
        for (index, view) in subviews.enumerated() {
            let size = view.sizeThatFits(.init(width: bounds.width, height: nil))
            view.place(at: CGPoint(x: bounds.minX + points[index].x, y: bounds.minY + points[index].y), proposal: .init(width: min(size.width, bounds.width), height: size.height))
        }
    }
}
extension View {
    @ViewBuilder func courseTileDrag(_ id: String, enabled: Bool) -> some View {
        if enabled { draggable(id) } else { self }
    }
    @ViewBuilder func courseTileDrop(enabled: Bool, action: @escaping ([String]) -> Bool) -> some View {
        if enabled { dropDestination(for: String.self) { items, _ in action(items) } } else { self }
    }
}

struct CoursePracticeExercisePanel: View {
    let card: CourseLessonCard
    let exercise: CourseExercise
    let immersive: Bool
    let checkpoint: Bool
    let onAnswer: (Bool) -> Void
    @Environment(\.courseNotificationCompact) private var notification
    @Environment(\.courseAssessmentPresentation) private var assessment
    @Environment(\.dynamicTypeSize) private var textSize
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.courseExercisePersistence) private var persistence
    @Environment(\.courseExerciseAttemptReported) private var reportAttempt
    @State private var state = CourseExerciseState()
    @State private var error: String?
    @State private var reading = false
    @State private var help = false
    private var tiles: [CourseWordTile] { exercise.tiles ?? [] }
    private var pictures: [CoursePictureChoice] { exercise.pictures ?? [] }
    private var missingPicture: Bool { pictures.contains { CourseVocabularyImages.image(named: $0.image) == nil } }
    private var readingChoices: Bool { reading || voiceOver || missingPicture }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(exercise.format == "exposure" ? "Discover" : exercise.format == "pictureChoice" ? "Choose a picture" : exercise.format == "choice" ? "Choose an answer" : exercise.format == "matching" ? "Match" : "Build a phrase")
                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text(card.question).font(immersive ? .title2.bold() : .headline).fixedSize(horizontal: false, vertical: true)
            if exercise.format == "pictureChoice" { pictureGrid }
            else if exercise.format == "choice" { choiceList }
            else if exercise.format == "matching" { matchingBoard }
            else if exercise.format == "wordBank" { wordBank }
            else {
                if let image = card.resolvedFieldMedia["prompt"]?.image {
                    CourseVocabularyImage(name: image, label: card.hint, compact: !immersive)
                }
                Text(card.correctAnswer).font(.title2.weight(.semibold))
                if !card.hint.isEmpty { Text(card.hint).font(.body).foregroundStyle(.secondary) }
            }
            if state.result == nil {
                if !checkpoint, !assessment, let rule = card.activity?.rule, !rule.isEmpty, exercise.format != "exposure" {
                    DisclosureGroup("Why?", isExpanded: $help) { Text(rule).font(.callout).fixedSize(horizontal: false, vertical: true) }
                        .onChange(of: help) { _, expanded in
                            if expanded && !state.usedHelp { update { $0.usedHelp = true; $0.revision += 1 } }
                        }
                }
                Button(assessment ? "Save answer" : exercise.format == "exposure" ? "Ready to practice" : "Check") {
                    update { _ = $0.submit(exercise) }
                    if let result = state.result, error == nil { reportAttempt?(state.attemptID); onAnswer(result) }
                }.buttonStyle(.borderedProminent).controlSize(.large)
                    .frame(minHeight: 44).disabled(!state.canSubmit(exercise))
            } else if assessment {
                Label("Answer saved", systemImage: "checkmark.circle").font(.headline)
            } else if let correct = state.result {
                Label(exercise.format == "exposure" ? "Ready" : correct ? "Correct" : "Let’s remember this one",
                      systemImage: exercise.format == "exposure" ? "book.closed" : correct ? "checkmark.circle.fill" : "arrow.counterclockwise")
                    .font(.headline).foregroundStyle(correct ? Color.green : .orange)
                if !correct {
                    if exercise.format == "matching" { ForEach(exercise.pairs ?? []) { pair in Text("\(pair.label) → \(pair.description)").font(.body.weight(.semibold)) } }
                    else { Text(card.correctAnswer).font(.body.weight(.semibold)) }
                }
            }
            if let error {
                Text(error).font(.callout).foregroundStyle(.red)
                Button("Reload saved answer") { restore() }.frame(minHeight: 44)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { restore() }
    }
    private var pictureGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !voiceOver && !missingPicture {
                Button(reading ? "Use pictures" : "Use descriptions") { reading.toggle() }
                    .font(.subheadline).frame(minHeight: 44)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .top), count: textSize.isAccessibilitySize || readingChoices ? 1 : 2), spacing: 12) {
                ForEach(state.orderedIDs(pictures.map(\.id)).compactMap { id in pictures.first { $0.id == id } }) { picture in
                    Button { update { $0.select(picture.id, exercise: exercise) } } label: {
                        VStack(spacing: 8) {
                            if !readingChoices, let image = CourseVocabularyImages.image(named: picture.image) {
                                Image(uiImage: image).resizable().scaledToFit().frame(height: notification ? 84 : 124).accessibilityHidden(true)
                            } else { Text(picture.description).font(.body.weight(.medium)).fixedSize(horizontal: false, vertical: true) }
                            if state.choiceID == picture.id { Label("Selected", systemImage: "checkmark.circle.fill").font(.caption.weight(.semibold)) }
                        }
                        .padding(12).frame(maxWidth: .infinity, minHeight: 64)
                        .background(Color.accentColor.opacity(state.choiceID == picture.id ? 0.14 : 0.04), in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(state.choiceID == picture.id ? Color.accentColor : Color.primary.opacity(0.18), lineWidth: state.choiceID == picture.id ? 2 : 1))
                    }.buttonStyle(.plain).disabled(state.result != nil)
                        .accessibilityLabel(picture.description).accessibilityAddTraits(state.choiceID == picture.id ? .isSelected : [])
                }
            }
        }
    }
    @ViewBuilder private var stimulus: some View {
        if let image = card.resolvedFieldMedia["prompt"]?.image {
            let count = min(2, max(1, exercise.stimulusCount ?? 1))
            HStack(spacing: 16) {
                ForEach(0..<count, id: \.self) { _ in CourseVocabularyImage(name: image, label: exercise.stimulusText ?? card.hint, compact: true) }
            }.accessibilityElement(children: .ignore).accessibilityLabel(exercise.stimulusText ?? card.hint)
        }
        if let text = exercise.stimulusText, !text.isEmpty, !card.question.localizedCaseInsensitiveContains(text) { Text(text).font(.body).foregroundStyle(.secondary) }
    }
    private var choiceList: some View {
        VStack(alignment: .leading, spacing: 12) {
            stimulus
            ForEach(state.orderedIDs((exercise.choices ?? []).map(\.id)), id: \.self) { id in
                if let choice = exercise.choices?.first(where: { $0.id == id }) {
                    Button { update { $0.select(id, exercise: exercise) } } label: {
                        HStack(alignment: .top) {
                            Text(choice.text).font(.body.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 8)
                            if state.choiceID == id { Image(systemName: "checkmark.circle.fill") }
                        }.padding(16).frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                            .background(Color.primary.opacity(state.choiceID == id ? 0.12 : 0.04), in: RoundedRectangle(cornerRadius: 14))
                    }.buttonStyle(.plain).disabled(state.result != nil).accessibilityAddTraits(state.choiceID == id ? .isSelected : [])
                }
            }
        }
    }
    private var matchingBoard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tap a Spanish label, then its picture. Tap a placed match to change it.").font(.caption).foregroundStyle(.secondary)
            ForEach(exercise.pairs ?? []) { pair in
                Button {
                    update { if $0.pairChoices?[pair.id] != nil { $0.clearPair(pair.id) } else { $0.selectPair(pair.id, exercise: exercise) } }
                } label: {
                    HStack {
                        Text(pair.label).font(.body.weight(.semibold))
                        Spacer()
                        if let right = state.pairChoices?[pair.id], let match = exercise.pairs?.first(where: { $0.id == right }) { Text(match.description).font(.body) }
                        else if state.activePairID == pair.id { Image(systemName: "arrow.down") }
                    }.padding(16).frame(minHeight: 48).background(Color.primary.opacity(state.activePairID == pair.id ? 0.12 : 0.04), in: RoundedRectangle(cornerRadius: 14))
                }.buttonStyle(.plain).disabled(state.result != nil).accessibilityAddTraits(state.activePairID == pair.id ? .isSelected : [])
            }
            CourseWrappingLayout {
                ForEach(state.orderedIDs((exercise.pairs ?? []).map(\.id)), id: \.self) { id in
                    if let pair = exercise.pairs?.first(where: { $0.id == id }), state.pairChoices?.values.contains(id) != true {
                        Button { update { $0.matchPair(id, exercise: exercise) } } label: {
                            VStack(spacing: 8) {
                                if !voiceOver, let image = CourseVocabularyImages.image(named: pair.image) { Image(uiImage: image).resizable().scaledToFit().frame(width: 100, height: 100).accessibilityHidden(true) }
                                else { Text(pair.description).font(.body).fixedSize(horizontal: false, vertical: true) }
                            }.padding(12).frame(minWidth: 100, minHeight: 48).background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))
                        }.buttonStyle(.plain).disabled(state.result != nil || state.activePairID == nil).accessibilityLabel(pair.description)
                    }
                }
            }
        }
    }
    private var wordBank: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your sentence").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            CourseWrappingLayout {
                if state.selectedIDs.isEmpty { Text("Tap words to place them here").font(.body).foregroundStyle(.secondary).frame(minHeight: 44) }
                ForEach(state.selectedIDs, id: \.self) { id in
                    if let tile = tiles.first(where: { $0.id == id }) {
                        tileButton(tile, placed: true)
                            .courseTileDrop(enabled: !notification) { ids in
                                guard ids.count == 1, let dragged = ids.first else { return false }
                                return update { $0.move(dragged, before: id, exercise: exercise) }
                            }
                            .accessibilityAction(named: "Move earlier") {
                                if let index = state.selectedIDs.firstIndex(of: id), index > 0 {
                                    let before = state.selectedIDs[index - 1]; update { $0.move(id, before: before, exercise: exercise) }
                                }
                            }
                    }
                }
            }
            .padding(12).background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 16))
            .courseTileDrop(enabled: !notification) { ids in
                guard ids.count == 1, let id = ids.first else { return false }
                return update { $0.append(id, exercise: exercise) }
            }
            Text(notification ? "Tap a word to place it. Tap a placed word to return it." : "Tap or drag words. Tap a placed word to return it.")
                .font(.caption).foregroundStyle(.secondary)
            CourseWrappingLayout {
                ForEach(state.orderedIDs(tiles.map(\.id)).compactMap { id in tiles.first { $0.id == id && !state.selectedIDs.contains(id) } }) { tile in tileButton(tile, placed: false) }
            }
        }
    }
    private func tileButton(_ tile: CourseWordTile, placed: Bool) -> some View {
        Button { update { if placed { $0.remove(tile.id) } else { $0.append(tile.id, exercise: exercise) } } } label: {
            Text(tile.text).font(.body.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14).padding(.vertical, 8).frame(minHeight: 44)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.2)))
        }.buttonStyle(.plain).disabled(state.result != nil)
            .courseTileDrag(tile.id, enabled: !notification && state.result == nil)
            .accessibilityLabel(tile.text).accessibilityHint(placed ? "Return to word bank" : "Add to sentence")
    }
    @discardableResult private func update(_ edit: (inout CourseExerciseState) -> Void) -> Bool {
        var next = state; edit(&next)
        guard next != state else { return false }
        guard persistence?.save(next) ?? true else {
            error = "Your answer couldn’t be saved, or changed in another window. Reload to continue."; return false
        }
        state = next; error = nil; return true
    }
    private func restore() {
        state = persistence?.load() ?? CourseExerciseState()
        error = nil
        // A crash between durable Check and parent grading safely completes grading.
        if let result = state.result { reportAttempt?(state.attemptID); onAnswer(result) }
    }
}
