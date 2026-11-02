import Foundation
import SwiftData

nonisolated struct AnkiCardContent: Codable, Equatable, Sendable {
    var frontHTML: String
    var backHTML: String
    var css: String
    var mediaFolder: String
    var templateOrdinal: Int
    var noteType: String
    var tags: [String]
    /// Optional for existing imports; the original front/back HTML is always retained.
    var frontSideRanges: [[Int]]? = nil

    var flipBackHTML: String {
        let answer: String
        if let frontSideRanges {
            var html = backHTML
            for bounds in frontSideRanges.reversed() {
                guard bounds.count == 2, bounds[0] >= 0, bounds[1] >= bounds[0],
                      bounds[1] <= html.utf16.count,
                      let range = Range(NSRange(location: bounds[0], length: bounds[1] - bounds[0]), in: html) else { return backHTML }
                html.removeSubrange(range)
            }
            answer = html
        } else {
            // Older imports have no field provenance. Remove only an exact leading
            // front or Anki's explicit answer divider, never repeated words in prose.
            let front = frontHTML.trimmingCharacters(in: .whitespacesAndNewlines)
            let back = backHTML.trimmingCharacters(in: .whitespacesAndNewlines)
            let remainder = !front.isEmpty && back.hasPrefix(front) ? String(back.dropFirst(front.count)) : nil
            let completeElement = front.hasPrefix("<") && front.hasSuffix(">")
            let separated = remainder?.range(of: #"(?is)^\s*<(?:hr|br)\b"#, options: .regularExpression) != nil
            if let remainder, completeElement || separated {
                answer = remainder
            } else if let divider = back.range(of: #"(?is)<hr\b[^>]*\bid\s*=\s*(?:["']answer["']|answer(?=\s|/?>))[^>]*>"#, options: .regularExpression) {
                answer = String(back[divider.upperBound...])
            } else { return backHTML }
        }
        let trimmed = answer.replacingOccurrences(of: #"(?is)^\s*(?:(?:<hr\b[^>]*>|<br\s*/?>)\s*)+"#,
            with: "", options: .regularExpression)
        // A FrontSide-only or script-driven template must still have a usable back.
        let text = trimmed.replacingOccurrences(of: #"(?s)<[^>]*>"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let hasMedia = trimmed.range(of: #"(?i)<(?:img|audio|video|svg|canvas|script)\b"#, options: .regularExpression) != nil
        return text.isEmpty && !hasMedia ? backHTML : trimmed
    }

    static var mediaRoot: URL {
        let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.learnalert.shared")
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("AnkiMedia", isDirectory: true)
    }

    var mediaURL: URL? {
        guard UUID(uuidString: mediaFolder) != nil else { return nil }
        return Self.mediaRoot.appendingPathComponent(mediaFolder, isDirectory: true)
    }

    static func mediaIndex(in directory: URL) -> [String: String] {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent(".learnalert-media.json")) else { return [:] }
        return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
    }

    static func safeMediaURL(name: String, directory: URL, index: [String: String]? = nil) -> URL? {
        let map = index ?? mediaIndex(in: directory)
        let decoded = map[name] ?? map[name.removingPercentEncoding ?? name] ?? (name.removingPercentEncoding ?? name)
        guard !decoded.isEmpty, decoded != ".", decoded != "..", !decoded.contains("/"), !decoded.contains("\\"),
              !decoded.unicodeScalars.contains(where: { $0.value < 32 }) else { return nil }
        let url = directory.appendingPathComponent(decoded).standardizedFileURL
        guard url.deletingLastPathComponent().path == directory.standardizedFileURL.path else { return nil }
        return url
    }
}

nonisolated enum AnkiMediaCleanup {
    /// A package can share media across several decks. Only remove old folders
    /// after a successful save and after the last referencing card has gone.
    static func removeUnreferenced(_ candidates: Set<String>, context: ModelContext) {
        guard !candidates.isEmpty, let cards = try? context.fetch(FetchDescriptor<Flashcard>()) else { return }
        let referenced = Set(cards.compactMap { $0.ankiContent?.mediaFolder })
        let unused = candidates.subtracting(referenced).filter { UUID(uuidString: $0) != nil }
            .map { AnkiCardContent.mediaRoot.appendingPathComponent($0, isDirectory: true) }
        Task.detached(priority: .utility) {
            for url in unused { try? FileManager.default.removeItem(at: url) }
        }
    }
}
