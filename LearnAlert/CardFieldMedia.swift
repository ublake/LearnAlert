import SwiftUI

/// Positions identify tiles, so repeated words remain separate draggable items.
nonisolated enum CardDragAnswerEvaluation {
    static func selection(in response: String, count: Int) -> [Int] {
        guard let data = response.data(using: .utf8),
              let values = try? JSONDecoder().decode([Int].self, from: data) else { return [] }
        var seen = Set<Int>()
        return values.filter { (0..<count).contains($0) && seen.insert($0).inserted }
    }

    static func response(for selection: [Int]) -> String {
        (try? JSONEncoder().encode(selection)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
    }

    static func isCorrect(response: String, options: [String], fields: [String: CardFieldMedia]) -> Bool {
        guard let data = response.data(using: .utf8),
              let selected = try? JSONDecoder().decode([Int].self, from: data),
              (2...30).contains(options.count), selected.count == options.count,
              Set(selected).count == options.count, selected.allSatisfy(options.indices.contains) else { return false }
        func identity(_ index: Int) -> String {
            let word = options[index].trimmingCharacters(in: .whitespacesAndNewlines)
            // Identical visible words can trade places. Empty media tiles must
            // retain their actual media identity instead of comparing as "".
            if !word.isEmpty { return "text:\(word)" }
            let media = fields["option:\(index)"] ?? .init()
            return "image:\(media.image ?? "")|audio:\(media.audio ?? "")"
        }
        guard options.indices.allSatisfy({ (fields["option:\($0)"] ?? .init()).hasContent(options[$0]) }) else { return false }
        return selected.map(identity) == options.indices.map(identity)
    }
}

/// One submission per presentation. Tapping is always available alongside the
/// system drag interaction, including inside an expanded notification.
struct CardDragAnswerPanel: View {
    let options: [String]
    let fields: [String: CardFieldMedia]
    let isGraded: Bool
    @Binding var response: String
    let onGrade: (Bool) -> Void
    @State private var bankOrder: [Int]
    @State private var submittedResponse: String?
    @State private var dragScope = UUID().uuidString
    @State private var targetID: Int?
    @State private var bankTargeted = false
    @State private var answerTargeted = false
    @State private var tileWidths: [Int: CGFloat] = [:]

    init(options: [String], fields: [String: CardFieldMedia], isGraded: Bool,
         response: Binding<String>, onGrade: @escaping (Bool) -> Void) {
        self.options = options; self.fields = fields; self.isGraded = isGraded
        _response = response; self.onGrade = onGrade
        var order = Array(options.indices).shuffled()
        if order.count > 1 && order == Array(options.indices) { order.append(order.removeFirst()) }
        _bankOrder = State(initialValue: order)
    }

    private var selected: [Int] { CardDragAnswerEvaluation.selection(in: response, count: options.count) }
    private var remaining: [Int] { bankOrder.filter { !selected.contains($0) } }
    private var locked: Bool { isGraded || submittedResponse != nil }
    private var validCard: Bool {
        (2...30).contains(options.count) && options.indices.allSatisfy {
            (fields["option:\($0)"] ?? .init()).hasContent(options[$0])
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Your answer").font(.caption.weight(.semibold))
                Spacer()
                Text("\(selected.count)/\(options.count)").font(.caption.monospacedDigit())
            }.foregroundStyle(.secondary)

            answerArea

            if !isGraded {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tiles").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    CardSentenceLayout(spacing: 6) {
                        ForEach(remaining, id: \.self) { id in tile(id, inAnswer: false) }
                        if remaining.isEmpty {
                            Text("Drag a tile here to return it")
                                .font(.caption).foregroundStyle(.secondary).frame(minHeight: 36)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .padding(8)
                    .modifier(NotificationMediaSurface(cornerRadius: 12,
                        fill: Color.primary.opacity(bankTargeted ? 0.08 : 0.025),
                        border: Color.primary.opacity(bankTargeted ? 0.45 : 0.12)))
                    .dropDestination(for: String.self) { items, _ in
                        guard let id = droppedID(items), selected.contains(id) else { return false }
                        update(selected.filter { $0 != id }); return true
                    } isTargeted: { bankTargeted = $0 && !locked }
                }
            }

            if isGraded {
                let correct = CardDragAnswerEvaluation.isCorrect(response: response, options: options, fields: fields)
                Label(correct ? "Correct" : "Correct order", systemImage: correct ? "checkmark.circle.fill" : "arrow.right")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(correct ? Color.green : Color.secondary)
                if !correct {
                    CardSentenceLayout(spacing: 6) {
                        ForEach(Array(options.indices), id: \.self) { id in tileContent(id, inAnswer: false, isSolution: true) }
                    }
                }
            } else {
                Button(submittedResponse == nil ? "Submit answer" : "Submitting…") {
                    guard !locked, validCard, selected.count == options.count else { return }
                    submittedResponse = response
                    onGrade(CardDragAnswerEvaluation.isCorrect(response: response, options: options, fields: fields))
                }
                .notificationPrimaryActionStyle()
                .disabled(locked || !validCard || selected.count != options.count)
            }
        }
        .onChange(of: options) { _, _ in
            bankOrder = Array(options.indices).shuffled()
            submittedResponse = nil; response = ""; dragScope = UUID().uuidString
        }
        .onChange(of: isGraded) { wasGraded, graded in
            if wasGraded && !graded {
                // A preview or synthetic alert can advance without changing its
                // sample card ID. This is a new presentation, not a second submit.
                bankOrder = Array(options.indices).shuffled()
                submittedResponse = nil; dragScope = UUID().uuidString
            }
        }
    }

    private var answerArea: some View {
        CardSentenceLayout(spacing: 6) {
            if selected.isEmpty {
                Text("Tap or drag tiles here")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .dropDestination(for: String.self) { items, _ in insert(items, at: 0) }
                        isTargeted: { answerTargeted = $0 && !locked }
            } else {
                ForEach(Array(selected.enumerated()), id: \.element) { position, id in
                    tile(id, inAnswer: true)
                        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { tileWidths[id] = $0 }
                        .dropDestination(for: String.self) { items, point in
                            let after = point.x > tileWidths[id, default: 80] / 2
                            return insert(items, at: position + (after ? 1 : 0))
                        } isTargeted: { targeted in
                            if targeted && !locked { targetID = id }
                            else if targetID == id { targetID = nil }
                        }
                }
                if !locked {
                    Image(systemName: "plus").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                        .frame(width: 36, height: 44)
                        .contentShape(Rectangle())
                        .dropDestination(for: String.self) { items, _ in insert(items, at: selected.count) }
                            isTargeted: { answerTargeted = $0 && !locked }
                        .accessibilityHidden(true)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .padding(10)
        .modifier(NotificationMediaSurface(cornerRadius: 14,
            fill: Color.accentColor.opacity(answerTargeted ? 0.12 : 0.045),
            border: Color.accentColor.opacity(answerTargeted ? 0.6 : 0.22)))
    }

    @ViewBuilder private func tile(_ id: Int, inAnswer: Bool) -> some View {
        if locked { tileContent(id, inAnswer: inAnswer) }
        else { tileContent(id, inAnswer: inAnswer).draggable(payload(id)) }
    }

    @ViewBuilder private func tileContent(_ id: Int, inAnswer: Bool, isSolution: Bool = false) -> some View {
        let media = fields["option:\(id)"] ?? .init()
        let content = HStack(spacing: 6) {
            if isSolution {
                tileLabel(id, media: media, showsRemove: false)
                    .accessibilityLabel(options[id].isEmpty ? "Tile \(id + 1)" : options[id])
            } else {
                Button {
                    guard !locked else { return }
                    if inAnswer { update(selected.filter { $0 != id }) }
                    else { update(selected + [id]) }
                } label: {
                    tileLabel(id, media: media, showsRemove: inAnswer && !locked)
                }
                .buttonStyle(.plain).disabled(locked)
                .accessibilityLabel(options[id].isEmpty ? "Tile \(id + 1)" : options[id])
                .accessibilityHint(locked ? "" : inAnswer ? "Tap to return this tile. Drag to change its position." : "Tap or drag to add this tile to your answer.")
            }
            if let audio = media.audio { CardAudioPlaybackButton(name: audio, compact: true).padding(.trailing, 6) }
        }
        .modifier(NotificationMediaSurface(cornerRadius: 10,
            fill: inAnswer ? Color.accentColor.opacity(0.1) : Color.primary.opacity(0.04),
            border: targetID == id ? Color.accentColor : Color.primary.opacity(0.18),
            emphasized: targetID == id))
        if inAnswer && !locked {
            content.accessibilityAction(named: "Move earlier") { move(id, by: -1) }
                .accessibilityAction(named: "Move later") { move(id, by: 1) }
        } else { content }
    }

    private func tileLabel(_ id: Int, media: CardFieldMedia, showsRemove: Bool) -> some View {
        HStack(spacing: 5) {
            if options[id].isEmpty && media.image == nil { Label("Audio", systemImage: "waveform") }
            else { CardFieldContent(text: options[id], media: .init(image: media.image), imageHeight: 64) }
            if showsRemove { Image(systemName: "xmark").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary) }
        }
        .font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
        .padding(.horizontal, 10).frame(minHeight: 44)
        .frame(maxWidth: 190)
        .contentShape(Rectangle())
    }

    private func payload(_ id: Int) -> String { "learnalert-order:\(dragScope):\(id)" }
    private func droppedID(_ items: [String]) -> Int? {
        guard !locked, items.count == 1 else { return nil }
        let prefix = "learnalert-order:\(dragScope):"
        guard items[0].hasPrefix(prefix), let id = Int(items[0].dropFirst(prefix.count)), options.indices.contains(id) else { return nil }
        return id
    }
    private func insert(_ items: [String], at destination: Int) -> Bool {
        guard let id = droppedID(items) else { return false }
        var answer = selected
        var target = min(max(0, destination), answer.count)
        if let old = answer.firstIndex(of: id) {
            answer.remove(at: old)
            if old < target { target -= 1 }
        }
        answer.insert(id, at: min(target, answer.count)); update(answer); return true
    }
    private func move(_ id: Int, by amount: Int) {
        guard !locked, let position = selected.firstIndex(of: id) else { return }
        var answer = selected
        let target = min(max(0, position + amount), answer.count - 1)
        guard target != position else { return }
        answer.swapAt(position, target); update(answer)
    }
    private func update(_ selection: [Int]) {
        guard !locked else { return }
        let encoded = CardDragAnswerEvaluation.response(for: selection)
        guard response != encoded else { return }
        withAnimation(.snappy(duration: 0.22)) { response = encoded }
    }
}

/// Stable field keys keep attachments aligned even when their text is empty or duplicated.
public nonisolated struct CardFieldMedia: Codable, Hashable, Sendable {
    var image: String? = nil
    var audio: String? = nil
    var isEmpty: Bool { image?.isEmpty != false && audio?.isEmpty != false }
    func hasContent(_ text: String) -> Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !isEmpty }
}

extension CardFieldMedia {
    private nonisolated enum CodingKeys: String, CodingKey { case image, audio, imageID, audioID }
    public nonisolated init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(image: try values.decodeIfPresent(String.self, forKey: .image) ?? values.decodeIfPresent(String.self, forKey: .imageID),
            audio: try values.decodeIfPresent(String.self, forKey: .audio) ?? values.decodeIfPresent(String.self, forKey: .audioID))
    }
    public nonisolated func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encodeIfPresent(image, forKey: .image)
        try values.encodeIfPresent(audio, forKey: .audio)
    }
}

enum CardChoiceIdentity {
    static func value(_ index: Int) -> String { "learnalert-choice:\(index)" }
    static func index(_ value: String?, options: [String]) -> Int? {
        guard let value else { return nil }
        if value.hasPrefix("learnalert-choice:"), let index = Int(value.dropFirst("learnalert-choice:".count)), options.indices.contains(index) { return index }
        return options.firstIndex(of: value) // Older notification handoffs stored the answer text.
    }
}

/// Audio controls are separate from answer-selection controls: listening never submits an answer.
struct CardFieldContent: View {
    var text = ""
    var media = CardFieldMedia()
    var imageHeight: CGFloat = 150
    @Environment(\.notificationDesignTheme) private var notificationDesign
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let image = CardImageStore.loadImage(named: media.image) {
                Image(uiImage: image).resizable().scaledToFit().frame(maxWidth: .infinity, maxHeight: imageHeight)
                    .clipShape(RoundedRectangle(cornerRadius: notificationDesign?.cornerRadius(10) ?? 10))
            }
            if !text.isEmpty { Text(text).fixedSize(horizontal: false, vertical: true) }
            if let audio = media.audio, !audio.isEmpty { CardAudioPlaybackButton(name: audio) }
        }
    }
}

/// Recorded listening and its complete reading alternative share one question.
/// Playback is always explicit; changing mode removes only this clip's player.
struct CardQuestionContent: View {
    let question: String
    var readingPrompt: String? = nil
    var media = CardFieldMedia()
    var imageHeight: CGFloat = 150
    @State private var reading = false
    private var recordingAvailable: Bool { media.audio.map { CardAudioStore.isAvailable(named: $0) } ?? false }
    private var isListeningCard: Bool { readingPrompt?.isEmpty == false }
    private var listening: Bool { isListeningCard && recordingAvailable && !reading }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if isListeningCard {
                Text(listening ? "LISTENING" : "READING").font(.caption2.weight(.bold)).foregroundStyle(.secondary)
            }
            CardFieldContent(text: isListeningCard && !listening ? readingPrompt ?? question : question,
                             media: .init(image: media.image), imageHeight: imageHeight)
            if !isListeningCard || listening, let audio = media.audio { CardAudioPlaybackButton(name: audio) }
            if isListeningCard && recordingAvailable {
                Button {
                    withAnimation(.snappy) { reading.toggle() }
                } label: {
                    Text(listening ? "I can’t listen right now" : "Back to listening")
                        .font(.caption.weight(.semibold))
                        .modifier(NotificationReadingToggleSurface())
                }.buttonStyle(.plain)
            }
        }.onChange(of: question) { _, _ in reading = false }
    }
}

struct CardMediaChoiceList: View {
    let options: [String]
    let fields: [String: CardFieldMedia]
    let correctIndex: Int?
    let selection: String?
    let isGraded: Bool
    let onSelect: (String) -> Void
    @State private var order: [Int] = []
    @Environment(\.notificationDesignTheme) private var notificationDesign
    private var choiceOrder: [Int] { order.count == options.count ? order : Array(options.indices) }
    private var picturesOnly: Bool { options.count >= 2 && options.indices.allSatisfy { options[$0].isEmpty && fields["option:\($0)"]?.image != nil } }
    var body: some View {
        Group {
            if picturesOnly {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: notificationDesign?.spacing(10) ?? 10) {
                    ForEach(choiceOrder, id: \.self) { choice($0) }
                }
            } else { VStack(spacing: notificationDesign?.spacing(10) ?? 10) { ForEach(choiceOrder, id: \.self) { choice($0) } } }
        }.onAppear { order = Array(options.indices).shuffled() }
            .onChange(of: options) { _, _ in order = Array(options.indices).shuffled() }
    }
    private func choice(_ index: Int) -> some View {
        let media = fields["option:\(index)"] ?? .init()
        let selected = CardChoiceIdentity.index(selection, options: options) == index
        let color: Color = isGraded && correctIndex == index ? .green : isGraded && selected ? .red : .accentColor
        return HStack(spacing: 8) {
            Button { onSelect(CardChoiceIdentity.value(index)) } label: {
                HStack(spacing: 8) {
                    Image(systemName: isGraded && correctIndex == index ? "checkmark.circle.fill" : selected ? "checkmark.circle.fill" : "circle").font(.subheadline).foregroundStyle(color)
                    CardFieldContent(text: options[index], media: .init(image: media.image), imageHeight: picturesOnly ? 80 : 100)
                        .font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                    if !picturesOnly { Spacer(minLength: 0) }
                }.padding(.horizontal, 12).padding(.vertical, notificationDesign?.verticalPadding(12) ?? 12)
                    .frame(maxWidth: media.audio != nil && options[index].isEmpty && media.image == nil ? 48 : .infinity, minHeight: picturesOnly ? 104 : 48, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain).disabled(isGraded || selection != nil)
                .accessibilityLabel(options[index].isEmpty ? "Select choice \(index + 1)" : "Select \(options[index])")
            if let audio = media.audio { CardAudioPlaybackButton(name: audio, compact: picturesOnly).padding(.trailing, 8) }
        }.modifier(NotificationMediaSurface(cornerRadius: 14,
            fill: color.opacity(selected || (isGraded && correctIndex == index) ? 0.16 : 0.05),
            border: selected || (isGraded && correctIndex == index) ? color : Color.primary.opacity(0.18),
            borderWidth: selected ? 2 : 1, emphasized: selected || (isGraded && correctIndex == index)))
    }
}

/// Pair validation is independent of presentation order. A mistake can be corrected
/// immediately, but is still remembered when the exercise is graded.
struct MatchingCardState {
    let pairCount: Int
    var selectedLeft: Int?
    var selectedRight: Int?
    var matched: Set<Int> = []
    var mistakeLeft: Int?
    var mistakeRight: Int?
    var hadMistake = false
    var complete: Bool { pairCount > 0 && matched.count == pairCount }

    init(pairCount: Int) {
        self.pairCount = max(0, pairCount)
    }

    /// Only shuffle pairs that exist on both sides. Shuffling all right-hand
    /// items before taking a prefix can hide a required match in malformed data.
    static func rightOrder(pairCount: Int) -> [Int] {
        let indices = Array(0..<max(0, pairCount))
        let shuffled = indices.shuffled()
        guard shuffled.count > 1, shuffled == indices else { return shuffled }
        return Array(shuffled.dropFirst()) + [shuffled[0]]
    }

    mutating func select(_ index: Int, left: Bool) {
        guard (0..<pairCount).contains(index), !matched.contains(index), !complete else { return }
        mistakeLeft = nil; mistakeRight = nil
        if left { selectedLeft = selectedLeft == index ? nil : index }
        else { selectedRight = selectedRight == index ? nil : index }
        guard let lhs = selectedLeft, let rhs = selectedRight else { return }
        if lhs == rhs { matched.insert(lhs) }
        else { hadMistake = true; mistakeLeft = lhs; mistakeRight = rhs }
        selectedLeft = nil; selectedRight = nil
    }
}

/// Matching uses position-independent identity and one neutral selection style.
struct CardMediaMatchingBoard: View {
    let left: [String]
    let right: [String]
    let fields: [String: CardFieldMedia]
    let isGraded: Bool
    let onGrade: (Bool) -> Void
    @State private var state: MatchingCardState
    @State private var order: [Int]
    @State private var submitted = false
    @Environment(\.notificationDesignTheme) private var notificationDesign

    init(left: [String], right: [String], fields: [String: CardFieldMedia], isGraded: Bool, onGrade: @escaping (Bool) -> Void) {
        self.left = left; self.right = right; self.fields = fields; self.isGraded = isGraded; self.onGrade = onGrade
        let count = min(left.count, right.count)
        _state = State(initialValue: MatchingCardState(pairCount: count))
        _order = State(initialValue: MatchingCardState.rightOrder(pairCount: count))
    }
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(state.mistakeLeft == nil ? "Tap two that belong together" : "Try another pair")
                Spacer()
                Text("\(state.matched.count)/\(state.pairCount)").monospacedDigit()
            }.font(.caption).foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 10) {
                VStack(spacing: notificationDesign?.spacing(8) ?? 8) { ForEach(0..<state.pairCount, id: \.self) { tile($0, leftSide: true) } }
                VStack(spacing: notificationDesign?.spacing(8) ?? 8) { ForEach(order, id: \.self) { tile($0, leftSide: false) } }
            }
        }
    }
    private func tile(_ index: Int, leftSide: Bool) -> some View {
        let matched = state.matched.contains(index)
        let selected = leftSide ? state.selectedLeft == index : state.selectedRight == index
        let media = fields["\(leftSide ? "left" : "right"):\(index)"] ?? .init()
        return VStack(spacing: 4) {
            Button {
                guard !submitted else { return }
                withAnimation(.snappy(duration: 0.2)) { state.select(index, left: leftSide) }
                if state.complete { submitted = true; onGrade(!state.hadMistake) }
            } label: {
                HStack(spacing: 6) {
                    CardFieldContent(text: (leftSide ? left : right)[index], media: .init(image: media.image), imageHeight: 80)
                        .font(.subheadline.weight(.medium)).frame(maxWidth: .infinity, minHeight: 44)
                    if matched { Image(systemName: "checkmark").font(.caption.bold()) }
                }.padding(.horizontal, 10).padding(.vertical, notificationDesign?.verticalPadding(10) ?? 10).contentShape(Rectangle())
                    .modifier(NotificationMediaSurface(cornerRadius: 12, fill: Color.primary.opacity(selected ? 0.12 : 0.04),
                        border: Color.primary.opacity(selected ? 0.7 : 0.18), borderWidth: selected ? 2 : 1,
                        emphasized: selected, insetBorder: true))
            }.buttonStyle(.plain).disabled(isGraded || matched).opacity(matched ? 0.4 : 1)
                .accessibilityLabel((leftSide ? left : right)[index].isEmpty ? "\(leftSide ? "Left" : "Right") item \(index + 1)" : (leftSide ? left : right)[index])
                .accessibilityValue(matched ? "Matched" : selected ? "Selected" : "")
            if let audio = media.audio { CardAudioPlaybackButton(name: audio, compact: true) }
        }
    }
}

struct BlankChoiceState: Equatable {
    var selected: Int?
    mutating func select(_ index: Int) { selected = selected == index ? nil : index }
    mutating func clear() { selected = nil }
    func isCorrect(answerIndex: Int?) -> Bool { selected != nil && selected == answerIndex }
}

/// Shared by regular decks, language decks and expanded notifications.
struct CardBlankChoicePanel: View {
    let prompt: String
    let options: [String]
    let answerIndex: Int?
    var fields: [String: CardFieldMedia] = [:]
    let isGraded: Bool
    let onGrade: (Bool) -> Void
    @State private var state = BlankChoiceState()
    @State private var order: [Int] = []
    @State private var correct: Bool?
    @Environment(\.notificationDesignTheme) private var notificationDesign

    private var words: [String] {
        let range = prompt.range(of: #"_{2,}|\{blank\}|\[blank\]"#, options: .regularExpression)
        let before = range.map { String(prompt[..<$0.lowerBound]) } ?? prompt
        let after = range.map { String(prompt[$0.upperBound...]) } ?? ""
        return before.split(whereSeparator: \.isWhitespace).map(String.init) + ["\u{FFFC}"] + after.split(whereSeparator: \.isWhitespace).map(String.init)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            CardSentenceLayout(spacing: 6) {
                ForEach(Array(words.enumerated()), id: \.offset) { _, word in
                    if word == "\u{FFFC}" {
                        Button { withAnimation(.snappy) { state.clear() } } label: {
                            HStack(spacing: 6) {
                                if let selected = state.selected {
                                    let media = fields["option:\(selected)"] ?? .init()
                                    if let image = CardImageStore.loadImage(named: media.image) {
                                        Image(uiImage: image).resizable().scaledToFit().frame(width: 60, height: 44)
                                    } else { Text(options[selected].isEmpty ? "Audio" : options[selected]) }
                                    if !isGraded { Image(systemName: "xmark").font(.caption2) }
                                } else { Text("        ") }
                            }.padding(.horizontal, 10).frame(minWidth: 72, minHeight: 44)
                                .modifier(NotificationMediaSurface(cornerRadius: 9, fill: Color.primary.opacity(0.08),
                                    border: Color.primary.opacity(0.35), emphasized: state.selected != nil, insetBorder: true))
                        }.buttonStyle(.plain).disabled(isGraded || state.selected == nil)
                            .accessibilityLabel(state.selected.map { "Remove \(options[$0]) from blank" } ?? "Empty blank")
                    } else { Text(word).font(.title3.weight(.semibold)) }
                }
            }
            ForEach(order.count == options.count ? order : Array(options.indices), id: \.self) { index in
                HStack {
                    Button { withAnimation(.snappy) { state.select(index) } } label: {
                        CardFieldContent(text: options[index], media: .init(image: fields["option:\(index)"]?.image), imageHeight: 100)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .padding(.horizontal, 10).padding(.vertical, notificationDesign?.verticalPadding(10) ?? 10).contentShape(Rectangle())
                    }.buttonStyle(.plain).disabled(isGraded)
                    if let audio = fields["option:\(index)"]?.audio { CardAudioPlaybackButton(name: audio).padding(.trailing, 8) }
                }.modifier(NotificationMediaSurface(cornerRadius: 12, fill: Color.primary.opacity(state.selected == index ? 0.12 : 0.04),
                    border: Color.primary.opacity(state.selected == index ? 0.7 : 0.18), borderWidth: state.selected == index ? 2 : 1,
                    emphasized: state.selected == index, insetBorder: true))
                    .accessibilityAddTraits(state.selected == index ? .isSelected : [])
            }
            if isGraded {
                Label(correct == true ? "Correct" : "Answer: \(answerIndex.flatMap { options.indices.contains($0) ? options[$0] : nil } ?? "")", systemImage: correct == true ? "checkmark.circle" : "arrow.counterclockwise")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                Button("Check answer") { let result = state.isCorrect(answerIndex: answerIndex); correct = result; onGrade(result) }
                    .notificationPrimaryActionStyle().disabled(state.selected == nil)
            }
        }.onAppear { order = Array(options.indices).shuffled() }
    }
}

/// The same card views also serve in-app study; only notification descendants opt in.
private struct NotificationReadingToggleSurface: ViewModifier {
    @Environment(\.notificationDesignTheme) private var design
    @Environment(\.colorScheme) private var colorScheme

    @ViewBuilder
    func body(content: Content) -> some View {
        if let design, design != .liquidGlass {
            content.padding(.horizontal, 10).frame(minHeight: 44)
                .notificationControlSurface(cornerRadius: 10, isLight: colorScheme == .light)
        } else { content }
    }
}

private struct NotificationMediaSurface: ViewModifier {
    let cornerRadius: CGFloat
    let fill: Color
    let border: Color
    var borderWidth: CGFloat = 1
    var emphasized = false
    var insetBorder = false
    @Environment(\.notificationDesignTheme) private var design
    @Environment(\.colorScheme) private var colorScheme

    @ViewBuilder
    func body(content: Content) -> some View {
        if let design, design != .liquidGlass {
            content.notificationControlSurface(cornerRadius: cornerRadius, tint: fill,
                isLight: colorScheme == .light, customBorderColor: emphasized ? border : nil)
        } else {
            let shape = RoundedRectangle(cornerRadius: cornerRadius)
            content.background(fill, in: shape)
                .overlay {
                    if insetBorder { shape.strokeBorder(border, lineWidth: borderWidth).allowsHitTesting(false) }
                    else { shape.stroke(border, lineWidth: borderWidth).allowsHitTesting(false) }
                }
        }
    }
}

private struct CardSentenceLayout: Layout {
    var spacing: CGFloat
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(subviews, width: proposal.width ?? 320).size
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let arrangement = arrange(subviews, width: bounds.width)
        for (index, origin) in arrangement.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y), proposal: .unspecified)
        }
    }
    private func arrange(_ subviews: Subviews, width: CGFloat) -> (size: CGSize, positions: [CGPoint]) {
        var x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0, rowStart = 0
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        var positions: [CGPoint] = []
        func alignRow(_ end: Int) {
            for index in rowStart..<end { positions[index].y += (row - sizes[index].height) / 2 }
        }
        for (index, size) in sizes.enumerated() {
            if x > 0 && x + size.width > width {
                alignRow(index); x = 0; y += row + spacing; row = 0; rowStart = index
            }
            positions.append(CGPoint(x: x, y: y)); x += size.width + spacing; row = max(row, size.height)
        }
        alignRow(sizes.count)
        return (CGSize(width: width, height: y + row), positions)
    }
}
