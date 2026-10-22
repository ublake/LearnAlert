import SwiftUI
import ImageIO

/// Read-only library previews use the same persisted fields as study and alerts.
struct DeckCardPreviewRow: View {
    let card: Flashcard
    let edit: () -> Void
    @State private var expandedAnki = false
    @State private var preparedAnki: PreparedAnkiLibraryPreview?
    private var fields: [String: CardFieldMedia] { card.fieldMedia }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 5) {
                Image(systemName: card.cardType.icon)
                Text(card.cardType.title)
                if card.interval >= 7 {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(LearnAlertStyle.aqua)
                        .accessibilityLabel("Mastered")
                }
                Spacer(minLength: 0)
                Button(action: edit) { Image(systemName: "pencil").frame(width: 32, height: 32) }
                    .buttonStyle(.plain).accessibilityLabel("Edit card")
            }.font(.caption2.weight(.medium)).foregroundStyle(LearnAlertStyle.textSecondary)

            if card.cardType == .anki {
                ankiPreview(preparedAnki?.content)
            } else if card.cardType == .images {
                HStack(alignment: .top, spacing: 14) {
                    field("prompt", title: fields["answer"] == nil ? "Image" : "Front", text: "")
                    if fields["answer"] != nil { field("answer", title: "Back", text: "") }
                }
            } else {
                field("prompt", title: nil, text: card.question, emphasized: true)
                switch card.cardType {
                case .multipleChoice:
                    VStack(spacing: 5) {
                        ForEach(card.options.indices, id: \.self) { index in
                            let correct = card.resolvedCorrectOptionIndex == index
                            HStack(alignment: .center, spacing: 8) {
                                Text(String(UnicodeScalar(65 + index) ?? "A"))
                                    .font(.caption2.weight(.semibold)).frame(width: 18)
                                    .foregroundStyle(correct ? .green : LearnAlertStyle.textSecondary)
                                field("option:\(index)", title: nil, text: card.options[index])
                                if correct {
                                    Image(systemName: "checkmark.circle.fill").font(.caption).foregroundStyle(.green)
                                        .accessibilityLabel("Correct answer")
                                }
                            }.padding(.horizontal, 8).padding(.vertical, 3)
                                .background(correct ? Color.green.opacity(0.08) : LearnAlertStyle.insetSurface.opacity(0.55), in: RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(correct ? Color.green.opacity(0.35) : Color.clear, lineWidth: 0.8))
                        }
                    }
                case .matching:
                    VStack(spacing: 6) {
                        ForEach(card.matchingLeftItems.indices, id: \.self) { index in
                            HStack(alignment: .center, spacing: 8) {
                                field("left:\(index)", title: nil, text: card.matchingLeftItems[index])
                                Image(systemName: "arrow.right").font(.caption2).foregroundStyle(LearnAlertStyle.textSecondary)
                                field("right:\(index)", title: nil, text: card.matchingRightItems.indices.contains(index) ? card.matchingRightItems[index] : "")
                            }
                        }
                    }
                default:
                    field("answer", title: card.cardType == .vocabulary ? "Definition" : "Answer", text: card.correctAnswer)
                }
                if (fields["hint"] ?? .init()).hasContent(card.hint) {
                    DisclosureGroup { field("hint", title: nil, text: card.hint) } label: {
                        Label("Hint", systemImage: "lightbulb").font(.caption2)
                    }.tint(LearnAlertStyle.textSecondary)
                }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(LearnAlertStyle.surface, in: RoundedRectangle(cornerRadius: 15))
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(LearnAlertStyle.cardBorder, lineWidth: 0.8))
        .task(id: card.cardType == .anki ? card.ankiContentData : nil) {
            guard card.cardType == .anki else { return }
            let data = card.ankiContentData, id = card.id
            let worker = Task.detached(priority: .userInitiated) { AnkiLibraryPreview.prepare(cardID: id, data: data) }
            let result = await withTaskCancellationHandler { await worker.value } onCancel: { worker.cancel() }
            if !Task.isCancelled { preparedAnki = result }
        }
    }

    private func field(_ key: String, title: String?, text: String, emphasized: Bool = false) -> some View {
        let media = fields[key] ?? .init()
        return VStack(alignment: .leading, spacing: 3) {
            if let title { Text(title).font(.system(size: 10, weight: .medium)).foregroundStyle(LearnAlertStyle.textSecondary) }
            HStack(alignment: .center, spacing: 8) {
                if let name = media.image {
                    if let image = CardImageStore.loadImage(named: name) {
                        Image(uiImage: image).resizable().scaledToFit().frame(width: 68, height: 52)
                            .background(LearnAlertStyle.insetSurface, in: RoundedRectangle(cornerRadius: 7))
                            .clipShape(RoundedRectangle(cornerRadius: 7)).accessibilityLabel("\(title ?? "Card") image")
                    } else { Image(systemName: "photo.badge.exclamationmark").accessibilityLabel("Image unavailable") }
                }
                if !text.isEmpty {
                    Text(text).font(emphasized ? .subheadline.weight(.semibold) : .subheadline)
                        .foregroundStyle(LearnAlertStyle.textPrimary).fixedSize(horizontal: false, vertical: true)
                }
                if let audio = media.audio { CardAudioPlaybackButton(name: audio, compact: true) }
                Spacer(minLength: 0)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func ankiPreview(_ content: AnkiCardContent?) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .top, spacing: 9) {
                if let image = preparedAnki?.thumbnail {
                    Image(uiImage: image).resizable().scaledToFit().frame(width: 68, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                VStack(alignment: .leading, spacing: 4) {
                    if !card.question.isEmpty { Text(card.question).font(.subheadline.weight(.semibold)).lineLimit(3) }
                    if !card.correctAnswer.isEmpty { Text(card.correctAnswer).font(.caption).foregroundStyle(LearnAlertStyle.textSecondary).lineLimit(3) }
                }
            }
            DisclosureGroup(isExpanded: $expandedAnki) {
                // DisclosureGroup may evaluate its content while collapsed. Keep
                // WebKit creation behind an explicit condition as well.
                if expandedAnki, let content {
                    AnkiExpandedPreview(content: content)
                } else if expandedAnki { ProgressView("Loading card…") }
            } label: { Text("Formatted card").font(.caption2) }.tint(LearnAlertStyle.appAccentForeground)
        }
    }

}

nonisolated struct PreparedAnkiLibraryPreview: @unchecked Sendable {
    let content: AnkiCardContent?
    let thumbnail: UIImage?
}

nonisolated enum AnkiLibraryPreview {
    private final class Cached: @unchecked Sendable {
        let data: Data
        let value: PreparedAnkiLibraryPreview
        init(_ data: Data, _ value: PreparedAnkiLibraryPreview) { self.data = data; self.value = value }
    }
    private final class Index: @unchecked Sendable {
        let values: [String: String]
        init(_ values: [String: String]) { self.values = values }
    }
    private static let previews: NSCache<NSUUID, Cached> = {
        let cache = NSCache<NSUUID, Cached>(); cache.totalCostLimit = 12 * 1_024 * 1_024; return cache
    }()
    private static let indexes: NSCache<NSURL, Index> = {
        let cache = NSCache<NSURL, Index>(); cache.countLimit = 4; return cache
    }()
    private static let imagePattern = try? NSRegularExpression(pattern: #"<img\b[^>]*\bsrc\s*=\s*["']([^"']+)["']"#, options: .caseInsensitive)

    static func prepare(cardID: UUID, data: Data?) -> PreparedAnkiLibraryPreview {
        guard let data else { return .init(content: nil, thumbnail: nil) }
        if let saved = previews.object(forKey: cardID as NSUUID), saved.data == data { return saved.value }
        let content = try? JSONDecoder().decode(AnkiCardContent.self, from: data)
        let value = PreparedAnkiLibraryPreview(content: content, thumbnail: content.flatMap(thumbnail))
        if !Task.isCancelled { previews.setObject(Cached(data, value), forKey: cardID as NSUUID, cost: data.count + 192 * 192 * 4) }
        return value
    }

    static func mediaIndex(in directory: URL) -> [String: String] {
        let key = directory as NSURL
        if let saved = indexes.object(forKey: key) { return saved.values }
        let index = Index(AnkiCardContent.mediaIndex(in: directory))
        indexes.setObject(index, forKey: key)
        return index.values
    }

    private static func thumbnail(_ content: AnkiCardContent) -> UIImage? {
        let html = String(content.frontHTML.prefix(32_768)) + String(content.backHTML.prefix(32_768))
        guard !Task.isCancelled, let regex = imagePattern,
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html) else { return nil }
        let name = String(html[range]).replacingOccurrences(of: "&amp;", with: "&").removingPercentEncoding ?? String(html[range])
        guard let directory = content.mediaURL else { return nil }
        guard let url = AnkiCardContent.safeMediaURL(name: name, directory: directory, index: mediaIndex(in: directory)),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 192] as CFDictionary) else { return nil }
        return UIImage(cgImage: thumbnail)
    }
}
