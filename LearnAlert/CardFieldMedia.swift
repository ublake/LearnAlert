import SwiftUI

/// Stable field keys keep attachments aligned even when their text is empty or duplicated.
public struct CardFieldMedia: Codable, Hashable, Sendable {
    var image: String? = nil
    var audio: String? = nil
    var isEmpty: Bool { image?.isEmpty != false && audio?.isEmpty != false }
    func hasContent(_ text: String) -> Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !isEmpty }
}

extension CardFieldMedia {
    private enum CodingKeys: String, CodingKey { case image, audio, imageID, audioID }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(image: try values.decodeIfPresent(String.self, forKey: .image) ?? values.decodeIfPresent(String.self, forKey: .imageID),
            audio: try values.decodeIfPresent(String.self, forKey: .audio) ?? values.decodeIfPresent(String.self, forKey: .audioID))
    }
    public func encode(to encoder: Encoder) throws {
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
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let image = CardImageStore.loadImage(named: media.image) {
                Image(uiImage: image).resizable().scaledToFit().frame(maxWidth: .infinity, maxHeight: imageHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
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
                Button(listening ? "I can’t listen right now" : "Back to listening") {
                    withAnimation(.snappy) { reading.toggle() }
                }.font(.caption.weight(.semibold)).buttonStyle(.plain)
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
    private var choiceOrder: [Int] { order.count == options.count ? order : Array(options.indices) }
    private var picturesOnly: Bool { options.count >= 2 && options.indices.allSatisfy { options[$0].isEmpty && fields["option:\($0)"]?.image != nil } }
    var body: some View {
        Group {
            if picturesOnly {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(choiceOrder, id: \.self) { choice($0) }
                }
            } else { VStack(spacing: 10) { ForEach(choiceOrder, id: \.self) { choice($0) } } }
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
                }.padding(12).frame(maxWidth: media.audio != nil && options[index].isEmpty && media.image == nil ? 48 : .infinity, minHeight: picturesOnly ? 104 : 48, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain).disabled(isGraded || selection != nil)
                .accessibilityLabel(options[index].isEmpty ? "Select choice \(index + 1)" : "Select \(options[index])")
            if let audio = media.audio { CardAudioPlaybackButton(name: audio, compact: picturesOnly).padding(.trailing, 8) }
        }.background(color.opacity(selected || (isGraded && correctIndex == index) ? 0.16 : 0.05), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(selected || (isGraded && correctIndex == index) ? color : Color.primary.opacity(0.18), lineWidth: selected ? 2 : 1))
    }
}

/// Matching uses position-independent identity and one neutral selection style.
struct CardMediaMatchingBoard: View {
    let left: [String]
    let right: [String]
    let fields: [String: CardFieldMedia]
    let isGraded: Bool
    let onGrade: (Bool) -> Void
    @State private var state: CourseMatchingState
    @State private var order: [Int]
    @State private var submitted = false

    init(left: [String], right: [String], fields: [String: CardFieldMedia], isGraded: Bool, onGrade: @escaping (Bool) -> Void) {
        self.left = left; self.right = right; self.fields = fields; self.isGraded = isGraded; self.onGrade = onGrade
        let count = min(left.count, right.count)
        _state = State(initialValue: CourseMatchingState(pairCount: count))
        _order = State(initialValue: CourseMatchingState.rightOrder(pairCount: count))
    }
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(state.mistakeLeft == nil ? "Tap two that belong together" : "Try another pair")
                Spacer()
                Text("\(state.matched.count)/\(state.pairCount)").monospacedDigit()
            }.font(.caption).foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 10) {
                VStack(spacing: 8) { ForEach(0..<state.pairCount, id: \.self) { tile($0, leftSide: true) } }
                VStack(spacing: 8) { ForEach(order, id: \.self) { tile($0, leftSide: false) } }
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
                }.padding(10).contentShape(Rectangle())
                    .background(Color.primary.opacity(selected ? 0.12 : 0.04), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(selected ? 0.7 : 0.18), lineWidth: selected ? 2 : 1))
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
                                .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
                                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Color.primary.opacity(0.35), lineWidth: 1))
                        }.buttonStyle(.plain).disabled(isGraded || state.selected == nil)
                            .accessibilityLabel(state.selected.map { "Remove \(options[$0]) from blank" } ?? "Empty blank")
                    } else { Text(word).font(.title3.weight(.semibold)) }
                }
            }
            ForEach(order.count == options.count ? order : Array(options.indices), id: \.self) { index in
                HStack {
                    Button { withAnimation(.snappy) { state.select(index) } } label: {
                        CardFieldContent(text: options[index], media: .init(image: fields["option:\(index)"]?.image), imageHeight: 100)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).padding(10).contentShape(Rectangle())
                    }.buttonStyle(.plain).disabled(isGraded)
                    if let audio = fields["option:\(index)"]?.audio { CardAudioPlaybackButton(name: audio).padding(.trailing, 8) }
                }.background(Color.primary.opacity(state.selected == index ? 0.12 : 0.04), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(state.selected == index ? 0.7 : 0.18), lineWidth: state.selected == index ? 2 : 1))
                    .accessibilityAddTraits(state.selected == index ? .isSelected : [])
            }
            if isGraded {
                Label(correct == true ? "Correct" : "Answer: \(answerIndex.flatMap { options.indices.contains($0) ? options[$0] : nil } ?? "")", systemImage: correct == true ? "checkmark.circle" : "arrow.counterclockwise")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                Button("Check answer") { let result = state.isCorrect(answerIndex: answerIndex); correct = result; onGrade(result) }
                    .buttonStyle(.borderedProminent).disabled(state.selected == nil)
            }
        }.onAppear { order = Array(options.indices).shuffled() }
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
