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

struct CardMediaChoiceList: View {
    let options: [String]
    let fields: [String: CardFieldMedia]
    let correctIndex: Int?
    let selection: String?
    let isGraded: Bool
    let onSelect: (String) -> Void
    var body: some View {
        VStack(spacing: 10) {
            ForEach(options.indices, id: \.self) { index in
                let media = fields["option:\(index)"] ?? .init()
                let selected = CardChoiceIdentity.index(selection, options: options) == index
                let color: Color = isGraded && correctIndex == index ? .green : isGraded && selected ? .red : .accentColor
                HStack(spacing: 8) {
                    Button { onSelect(CardChoiceIdentity.value(index)) } label: {
                        HStack(spacing: 10) {
                            Image(systemName: isGraded && correctIndex == index ? "checkmark.circle.fill" : selected ? "checkmark.circle.fill" : "circle")
                                .font(.title3).foregroundStyle(color)
                            CardFieldContent(text: options[index], media: .init(image: media.image), imageHeight: 100)
                                .font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                            if media.audio == nil || !options[index].isEmpty || media.image != nil { Spacer(minLength: 0) }
                        }.padding(12).frame(maxWidth: media.audio != nil && options[index].isEmpty && media.image == nil ? 48 : .infinity, minHeight: 48, alignment: .leading).contentShape(Rectangle())
                    }.buttonStyle(.plain).disabled(isGraded || selection != nil)
                        .accessibilityLabel(options[index].isEmpty ? "Select choice \(index + 1)" : "Select \(options[index])")
                    if let audio = media.audio { CardAudioPlaybackButton(name: audio).padding(.trailing, 12).frame(maxWidth: .infinity) }
                }
                .background(color.opacity(selected || (isGraded && correctIndex == index) ? 0.16 : 0.05), in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(selected || (isGraded && correctIndex == index) ? color : Color.primary.opacity(0.18), lineWidth: selected ? 2 : 1))
            }
        }
    }
}

struct CardMediaMatchingBoard: View {
    let left: [String]
    let right: [String]
    let fields: [String: CardFieldMedia]
    let isGraded: Bool
    let onGrade: (Bool) -> Void
    @State private var selected: Int?
    @State private var assignments: [Int: Int] = [:]
    @State private var order: [Int] = []
    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                VStack(spacing: 8) {
                    ForEach(left.indices, id: \.self) { index in
                        tile(left[index], media: fields["left:\(index)"] ?? .init(), label: "Left item \(index + 1)", active: selected == index, matched: assignments.values.contains(index)) {
                            selected = selected == index ? nil : index
                        }
                    }
                }
                VStack(spacing: 8) {
                    ForEach(order, id: \.self) { index in
                        tile(right[index], media: fields["right:\(index)"] ?? .init(), label: "Right item \(index + 1)", active: false, matched: assignments[index] != nil) {
                            if let selected {
                                assignments = assignments.filter { $0.value != selected }
                                assignments[index] = selected; self.selected = nil
                            } else { assignments.removeValue(forKey: index) }
                        }
                        if let source = assignments[index] {
                            Text(isGraded ? (source == index ? "✓" : "✕") : "\(source + 1) → \(index + 1)")
                                .font(.caption.weight(.semibold)).foregroundStyle(isGraded && source != index ? .red : .secondary)
                        }
                    }
                }
            }
            if !isGraded {
                Button("Check matches") { onGrade(left.count == right.count && right.indices.allSatisfy { assignments[$0] == $0 }) }
                    .buttonStyle(.borderedProminent).disabled(assignments.count != right.count)
            }
        }.onAppear { if order.isEmpty { order = Array(right.indices).shuffled() } }
    }
    private func tile(_ text: String, media: CardFieldMedia, label: String, active: Bool, matched: Bool, action: @escaping () -> Void) -> some View {
        VStack(spacing: 4) {
            Button { withAnimation(.snappy) { action() } } label: {
                CardFieldContent(text: text.isEmpty && media.image == nil ? "Select" : text, media: .init(image: media.image), imageHeight: 85)
                    .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())
            }.buttonStyle(.plain).disabled(isGraded).accessibilityLabel(label)
            if let audio = media.audio { CardAudioPlaybackButton(name: audio).font(.caption) }
        }.padding(8).frame(maxWidth: .infinity)
            .background(Color.accentColor.opacity(active ? 0.2 : matched ? 0.1 : 0.04), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(active ? Color.accentColor : Color.primary.opacity(0.18), lineWidth: active ? 2 : 1))
    }
}
