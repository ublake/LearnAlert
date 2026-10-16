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
