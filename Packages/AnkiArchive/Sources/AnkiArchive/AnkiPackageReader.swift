import Foundation
import SQLite3
import ZIPFoundation
import CZstd

public enum AnkiPackageReader {
    public static let maximumCards = 100_000
    public static let maximumArchiveBytes = 1_024 * 1_024 * 1_024
    private static let maximumDatabaseBytes = 256 * 1_024 * 1_024
    private static let maximumMediaBytes = 64 * 1_024 * 1_024
    private static let maximumTotalBytes = 2_048 * 1_024 * 1_024

    /// Synchronous, cancellable work; call from a background task, never the UI actor.
    /// The caller owns `workspace` and removes it on cancel, failure or after committing.
    public static func read(url: URL, workspace: URL,
                            progress: @escaping @Sendable (AnkiImportProgress) -> Void = { _ in }) throws -> AnkiImportPackage {
        try Task.checkCancellation()
        let reporter = AnkiImportProgressReporter(emit: progress)
        let progress: @Sendable (AnkiImportProgress) -> Void = { reporter.report($0) }
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size > 0, size <= maximumArchiveBytes else { throw AnkiImportError.invalid("Choose an Anki package smaller than 1 GB.") }
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
        progress(.init(0.02, "Opening your deck", url.lastPathComponent, archiveBytes: size))
        let archive: Archive
        do { archive = try Archive(url: url, accessMode: .read) }
        catch { throw AnkiImportError.invalid("This file isn't a readable Anki package. Export the deck as an .apkg file and try again.") }
        // Archive[path] scans the ZIP directory from the beginning. Looking up every
        // numbered media file that way becomes quadratic on large exports.
        var entries = try AnkiArchiveEntryIndex(archive)
        let version: Int
        if let entry = entries["meta"] {
            version = Int(try AnkiProto(extract(entry, archive: archive, limit: 4_096)).integer(1))
            guard (1...3).contains(version) else { throw AnkiImportError.invalid("This Anki package uses a newer format. Re-export it with ‘Support older Anki versions’ enabled.") }
        } else { version = entries["collection.anki21"] == nil ? 1 : 2 }
        let modern = version == 3
        let filename = modern ? "collection.anki21b" : version == 2 ? "collection.anki21" : "collection.anki2"
        guard let collection = entries[filename] else { throw AnkiImportError.invalid("The package is missing its Anki collection database.") }
        let mediaMap = try readMediaMap(entries: entries, archive: archive, modern: modern)
        guard mediaMap.count <= 100_000 else { throw AnkiImportError.invalid("This package contains too many media files.") }
        // Resolve noncanonical ZIP names once, then count real source files.
        // The collection remains unfinished until the app's atomic library save.
        try entries.include(Set(mediaMap.map { $0.0 }), from: archive)
        let totalFiles = 1 + mediaMap.reduce(0) { $0 + (entries[$1.0] == nil ? 0 : 1) }
        progress(.init(0.07, "Reading cards", "Unpacking the collection", completedFiles: 0, totalFiles: totalFiles))
        let databaseURL = workspace.appendingPathComponent("collection.sqlite")
        let databaseBytes = try extractToFile(collection, archive: archive, to: databaseURL, compressed: modern, limit: maximumDatabaseBytes) { bytes in
            progress(.init(0.07, "Reading cards", "Unpacking the collection", processedBytes: bytes))
        }
        let header = try FileHandle(forReadingFrom: databaseURL)
        defer { try? header.close() }
        guard try header.read(upToCount: 16) == Data("SQLite format 3\0".utf8) else { throw AnkiImportError.invalid("The Anki collection database is damaged.") }
        let (cards, deckNames, cardWarnings, skipped) = try readDatabase(databaseURL, progress: progress)
        guard !cards.isEmpty else { throw AnkiImportError.invalid("No compatible cards were found in this package. It may be empty or use unsupported note types.") }

        progress(.init(0.48, "Gathering images & audio"))
        let mediaDirectory = workspace.appendingPathComponent("media", isDirectory: true)
        try FileManager.default.createDirectory(at: mediaDirectory, withIntermediateDirectories: true)
        var mediaBytes = 0, mediaCount = 0, missingMedia = 0
        var mediaFiles: [String: String] = [:]
        var names = Set<String>(), savedNames = Set<String>()
        progress(.init(0.48, "Gathering images & audio", completedItems: 0, totalItems: mediaMap.count, unit: "files", processedBytes: 0))
        for (index, item) in mediaMap.enumerated() {
            try Task.checkCancellation()
            let (key, name) = item
            guard isSafeMediaName(name), Int(key) != nil else { throw AnkiImportError.invalid("The Anki package contains an unsafe media filename.") }
            guard names.insert(name.precomposedStringWithCanonicalMapping).inserted else { throw AnkiImportError.invalid("The Anki package contains duplicate media filenames.") }
            guard let entry = entries[key] else { missingMedia += 1; continue }
            let available = min(maximumMediaBytes, maximumTotalBytes - mediaBytes - databaseBytes)
            let originalExtension = URL(fileURLWithPath: name).pathExtension.lowercased()
            let ext = originalExtension.count <= 16 && originalExtension.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.contains($0) && $0.isASCII }) ? originalExtension : "bin"
            let storedName = "media-\(index).\(ext.isEmpty ? "bin" : ext)"
            let bytesBeforeFile = mediaBytes
            let filesBeforeCurrent = mediaCount
            let extractedBytes = try extractToFile(entry, archive: archive, to: mediaDirectory.appendingPathComponent(storedName), compressed: modern, limit: available) { bytes in
                progress(.init(0.48 + 0.49 * Double(index) / Double(max(1, mediaMap.count)), "Gathering images & audio",
                    completedItems: index, totalItems: mediaMap.count, unit: "files", processedBytes: bytesBeforeFile + bytes,
                    completedFiles: filesBeforeCurrent, totalFiles: totalFiles))
            }
            mediaBytes += extractedBytes
            mediaFiles[name] = storedName
            mediaCount += 1
            savedNames.insert(name.precomposedStringWithCanonicalMapping)
            if index % 20 == 0 || index + 1 == mediaMap.count {
                progress(.init(0.48 + 0.49 * Double(index + 1) / Double(max(1, mediaMap.count)), "Gathering images & audio", "\(index + 1) of \(mediaMap.count) files", completedItems: index + 1, totalItems: mediaMap.count, unit: "files", processedBytes: mediaBytes,
                    completedFiles: mediaCount, totalFiles: totalFiles))
            }
        }
        // Always report the completed file stage, including missing/empty media maps.
        progress(.init(0.97, "Gathering images & audio", completedItems: mediaMap.count, totalItems: mediaMap.count,
            unit: "files", processedBytes: mediaBytes, completedFiles: mediaCount, totalFiles: totalFiles))
        try JSONEncoder().encode(mediaFiles).write(to: mediaDirectory.appendingPathComponent(".learnalert-media.json"))
        var warnings = cardWarnings
        let referenced = try referencedMedia(in: cards)
        let absent = referenced.subtracting(savedNames)
        if !absent.isEmpty { warnings.insert("\(absent.count) referenced media files weren't included in this export. Re-export with ‘Include Media’ to bring them along.") }
        if missingMedia > 0 { warnings.insert("\(missingMedia) media files listed by the deck were missing from the package.") }
        if skipped > 0 { warnings.insert("\(skipped) cards couldn't be converted. Their templates or note types were missing or invalid.") }
        var deckCounts: [String: Int] = [:]
        for card in cards { deckCounts[card.deckID, default: 0] += 1 }
        let decks = deckCounts.map { AnkiImportedDeck(id: $0.key, name: deckNames[$0.key] ?? "Imported deck", cardCount: $0.value) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        progress(.init(1, "Ready to import", "\(cards.count) cards · \(mediaCount) media files",
            completedFiles: mediaCount, totalFiles: totalFiles))
        return AnkiImportPackage(cards: cards, decks: decks, mediaDirectory: mediaDirectory,
                                 mediaCount: mediaCount, mediaBytes: mediaBytes, mediaFiles: mediaFiles, warnings: warnings.sorted(), skippedCards: skipped)
    }

    private static func readMediaMap(entries: AnkiArchiveEntryIndex, archive: Archive, modern: Bool) throws -> [(String, String)] {
        guard let entry = entries["media"] else { return [] }
        let packedMap = try extract(entry, archive: archive, limit: 24 * 1_024 * 1_024)
        let data = modern ? try decompress(packedMap, limit: 24 * 1_024 * 1_024) : packedMap
        if modern {
            return try AnkiProto(data).messages(1).enumerated().map { index, bytes in
                (String(index), try AnkiProto(bytes).string(1))
            }
        }
        guard let map = try JSONSerialization.jsonObject(with: data) as? [String: String] else {
            throw AnkiImportError.invalid("The Anki package has an unreadable media index.")
        }
        return map.sorted { $0.key.localizedStandardCompare($1.key) == .orderedAscending }.map { ($0.key, $0.value) }
    }

    public static func isSafeMediaName(_ name: String) -> Bool {
        !name.isEmpty && name != "." && name != ".." && name.count <= 255 && name.utf8.count <= 1_024 &&
        !name.contains("/") && !name.contains("\\") && !name.unicodeScalars.contains { $0.value < 32 || $0.value == 127 }
    }

    private static func referencedMedia(in cards: [AnkiImportedCard]) throws -> Set<String> {
        guard let regex = try? NSRegularExpression(pattern: #"(?i)(?:\b(?:src|poster|data-sound)\s*=\s*["']([^"']+)["']|url\(\s*["']?([^)'"\s]+))"#) else { return [] }
        var names = Set<String>(), scannedCSS = Set<String>()
        for card in cards {
            try Task.checkCancellation()
            let content = scannedCSS.insert(card.css).inserted ? [card.front, card.back, card.css] : [card.front, card.back]
            for html in content {
                let text = html as NSString
                for match in regex.matches(in: html, range: NSRange(location: 0, length: text.length)) {
                    let range = match.range(at: match.range(at: 1).location == NSNotFound ? 2 : 1)
                    var name = text.substring(with: range)
                    name = AnkiTemplateRenderer.plainText(name)
                    if name.contains("://") || name.hasPrefix("data:") || name.hasPrefix("//") || name.hasPrefix("#") { continue }
                    if name.hasPrefix("./") { name = String(name.dropFirst(2)) }
                    if !text.substring(with: match.range).lowercased().hasPrefix("data-sound") {
                        name = String(name.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false).first ?? "")
                        name = String(name.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false).first ?? "")
                    }
                    name = name.removingPercentEncoding ?? name
                    if !name.isEmpty, name.utf8.count <= 1_024 { names.insert(name.precomposedStringWithCanonicalMapping) }
                }
            }
        }
        return names
    }

    private static func extract(_ entry: Entry, archive: Archive, limit: Int) throws -> Data {
        guard entry.type == .file, entry.uncompressedSize <= UInt64(limit) else { throw AnkiImportError.invalid("An item in this deck exceeds the import size limit.") }
        var result = Data()
        let checksum = try archive.extract(entry, bufferSize: 65_536) { chunk in
            try Task.checkCancellation()
            guard result.count <= limit - chunk.count else { throw AnkiImportError.invalid("An item in this deck expands beyond the import size limit.") }
            result.append(chunk)
        }
        guard checksum == entry.checksum else { throw AnkiImportError.invalid("The Anki package contains a damaged file. Download or export it again.") }
        return result
    }

    /// Stream collection/media bytes to disk. Large decks never hold the database
    /// or entire audio/image archive in RAM alongside their converted cards.
    private static func extractToFile(_ entry: Entry, archive: Archive, to url: URL, compressed: Bool, limit: Int, onBytes: ((Int) -> Void)? = nil) throws -> Int {
        guard entry.type == .file, entry.uncompressedSize <= UInt64(max(0, limit)) else { throw AnkiImportError.invalid("An item in this deck exceeds the import size limit.") }
        FileManager.default.createFile(atPath: url.path, contents: nil)
        let file = try FileHandle(forWritingTo: url)
        defer { try? file.close() }
        var written = 0
        var lastReport = Date.distantPast
        func write(_ bytes: UnsafeRawBufferPointer, count: Int) throws {
            guard count <= limit - written else { throw AnkiImportError.invalid("An item in this deck expands beyond the import size limit.") }
            try file.write(contentsOf: Data(bytes: bytes.baseAddress!, count: count)); written += count
            if Date().timeIntervalSince(lastReport) >= 0.2 { lastReport = Date(); onBytes?(written) }
        }
        let stream = compressed ? ZSTD_createDStream() : nil
        if compressed && stream == nil { throw AnkiImportError.invalid("There isn't enough memory to open this deck.") }
        defer { if let stream { ZSTD_freeDStream(stream) } }
        if let stream { ZSTD_initDStream(stream); ZSTD_DCtx_setParameter(stream, ZSTD_d_windowLogMax, 27) }
        var remaining = 0, output = [UInt8](repeating: 0, count: 65_536)
        let checksum = try archive.extract(entry, bufferSize: 65_536) { chunk in
            try Task.checkCancellation()
            if let stream {
                try chunk.withUnsafeBytes { bytes in
                    var input = ZSTD_inBuffer(src: bytes.baseAddress, size: bytes.count, pos: 0)
                    var full = true
                    while input.pos < input.size || full {
                        try Task.checkCancellation()
                        full = try output.withUnsafeMutableBytes { buffer in
                            var target = ZSTD_outBuffer(dst: buffer.baseAddress, size: buffer.count, pos: 0)
                            let position = input.pos
                            let status = ZSTD_decompressStream(stream, &target, &input)
                            guard ZSTD_isError(status) == 0 else { throw AnkiImportError.invalid("A compressed file in this Anki package is damaged.") }
                            remaining = Int(status)
                            if target.pos > 0 { try write(UnsafeRawBufferPointer(buffer), count: target.pos) }
                            if target.pos == 0 && position == input.pos {
                                guard input.pos == input.size else { throw AnkiImportError.invalid("A compressed file in this Anki package is damaged.") }
                                return false
                            }
                            return target.pos == buffer.count
                        }
                    }
                }
            } else { try chunk.withUnsafeBytes { try write($0, count: $0.count) } }
        }
        guard checksum == entry.checksum else { throw AnkiImportError.invalid("The Anki package contains a damaged file.") }
        guard !compressed || remaining == 0 else { throw AnkiImportError.invalid("A compressed file in this Anki package is incomplete.") }
        return written
    }

    static func decompress(_ input: Data, limit: Int) throws -> Data {
        guard let stream = ZSTD_createDStream() else { throw AnkiImportError.invalid("There isn't enough memory to open this deck.") }
        defer { ZSTD_freeDStream(stream) }
        ZSTD_initDStream(stream)
        // Bound the decoder's window allocation as well as its output.
        ZSTD_DCtx_setParameter(stream, ZSTD_d_windowLogMax, 27)
        return try input.withUnsafeBytes { bytes in
            var source = ZSTD_inBuffer(src: bytes.baseAddress, size: bytes.count, pos: 0)
            var result = Data(), buffer = [UInt8](repeating: 0, count: 65_536)
            var remaining = 1
            repeat {
                try Task.checkCancellation()
                let previous = source.pos
                remaining = try buffer.withUnsafeMutableBytes { target -> Int in
                    var output = ZSTD_outBuffer(dst: target.baseAddress, size: target.count, pos: 0)
                    let status = ZSTD_decompressStream(stream, &output, &source)
                    guard ZSTD_isError(status) == 0 else { throw AnkiImportError.invalid("A compressed file in this Anki package is damaged.") }
                    guard output.pos <= limit - result.count else { throw AnkiImportError.invalid("An item in this deck expands beyond the import size limit.") }
                    result.append(target.bindMemory(to: UInt8.self).baseAddress!, count: output.pos)
                    if output.pos == 0 && source.pos == previous && status != 0 { throw AnkiImportError.invalid("A compressed file in this Anki package is incomplete.") }
                    return Int(status)
                }
            } while source.pos < source.size || remaining != 0
            return result
        }
    }

    private static func readDatabase(_ url: URL, progress: @Sendable (AnkiImportProgress) -> Void) throws -> ([AnkiImportedCard], [String: String], Set<String>, Int) {
        let db = try AnkiSQLite(url: url)
        let count = try db.rows("SELECT count(*) FROM cards").first?.int(0) ?? 0
        guard count <= maximumCards else { throw AnkiImportError.invalid("This package contains more than 100,000 cards. Export a smaller deck or subdeck.") }
        progress(.init(0.12, "Converting cards", completedItems: 0, totalItems: count, unit: "cards"))
        var types: [String: AnkiNoteType] = [:], decks: [String: String] = [:]
        if try db.hasTable("notetypes") {
            var fields: [String: [String]] = [:], templates: [String: [AnkiTemplate]] = [:]
            for row in try db.rows("SELECT ntid,name FROM fields ORDER BY ntid,ord") { fields[row.string(0), default: []].append(row.string(1)) }
            for row in try db.rows("SELECT ntid,name,config FROM templates ORDER BY ntid,ord") {
                let proto = try AnkiProto(row.data(2))
                templates[row.string(0), default: []].append(AnkiTemplate(name: row.string(1), front: proto.string(1), back: proto.string(2)))
            }
            for row in try db.rows("SELECT id,name,config FROM notetypes") {
                let proto = try AnkiProto(row.data(2)), id = row.string(0)
                types[id] = AnkiNoteType(id: id, name: row.string(1), fields: fields[id] ?? [], templates: templates[id] ?? [], css: proto.string(3), isCloze: proto.integer(1) == 1)
            }
            for row in try db.rows("SELECT id,name FROM decks") { decks[row.string(0)] = row.string(1).replacingOccurrences(of: "\u{1f}", with: "::") }
        } else {
            guard let row = try db.rows("SELECT models,decks FROM col LIMIT 1").first,
                  let models = try JSONSerialization.jsonObject(with: row.data(0)) as? [String: [String: Any]],
                  let deckMap = try JSONSerialization.jsonObject(with: row.data(1)) as? [String: [String: Any]] else { throw AnkiImportError.invalid("This package is missing its Anki note types.") }
            for (id, model) in models {
                let fieldList = (model["flds"] as? [[String: Any]] ?? []).sorted { ($0["ord"] as? Int ?? 0) < ($1["ord"] as? Int ?? 0) }
                let templateList = (model["tmpls"] as? [[String: Any]] ?? []).sorted { ($0["ord"] as? Int ?? 0) < ($1["ord"] as? Int ?? 0) }
                types[id] = AnkiNoteType(id: id, name: model["name"] as? String ?? "Anki", fields: fieldList.map { $0["name"] as? String ?? "" },
                    templates: templateList.map { AnkiTemplate(name: $0["name"] as? String ?? "Card", front: $0["qfmt"] as? String ?? "", back: $0["afmt"] as? String ?? "") }, css: model["css"] as? String ?? "", isCloze: model["type"] as? Int == 1)
            }
            for (id, deck) in deckMap { decks[id] = deck["name"] as? String ?? "Imported deck" }
        }
        var cards: [AnkiImportedCard] = [], warnings = Set<String>(), skipped = 0, totalHTML = 0
        cards.reserveCapacity(count)
        let renderer = AnkiTemplateRenderer.Session()
        // Read actual cards rather than notes: reverse templates and cloze groups remain separate cards.
        try db.forEach("SELECT c.id,c.ord,CASE WHEN c.odid != 0 THEN c.odid ELSE c.did END,n.guid,n.mid,n.flds,n.tags FROM cards c JOIN notes n ON n.id=c.nid ORDER BY c.id") { row in
            try Task.checkCancellation()
            guard let type = types[row.string(4)] else { skipped += 1; return }
            guard cards.count + skipped < maximumCards else { throw AnkiImportError.invalid("This package generates too many cards.") }
            let ordinal = row.int(1), deckID = row.string(2), guid = row.string(3)
            let name = decks[deckID] ?? "Imported deck"
            let tags = row.string(6).split(separator: " ").map(String.init)
            let result: AnkiTemplateRenderer.Result
            do { result = try renderer.render(type: type, values: row.string(5).components(separatedBy: "\u{1f}"), ordinal: ordinal, deck: name, tags: tags) }
            catch { skipped += 1; return }
            totalHTML += result.front.utf8.count + result.back.utf8.count + type.css.utf8.count
            guard totalHTML <= 192 * 1_024 * 1_024 else { throw AnkiImportError.invalid("This deck contains too much card content to import at once. Export a smaller subdeck.") }
            warnings.formUnion(result.warnings)
            cards.append(AnkiImportedCard(id: "\(guid):\(ordinal)", noteGUID: guid, deckID: deckID, deckName: name, templateOrdinal: ordinal, noteType: type.name,
                front: result.front, back: result.back, css: type.css, plainFront: AnkiTemplateRenderer.plainText(result.front), plainBack: AnkiTemplateRenderer.plainText(result.back), tags: tags, warnings: result.warnings, frontSideRanges: result.frontSideRanges))
            if cards.count % 100 == 0 { progress(.init(0.12 + 0.34 * Double(cards.count + skipped) / Double(max(1, count)), "Converting cards", "\(cards.count) of \(count)", completedItems: cards.count + skipped, totalItems: count, unit: "cards")) }
        }
        progress(.init(0.46, "Converting cards", completedItems: cards.count + skipped, totalItems: count, unit: "cards"))
        return (cards, decks, warnings, skipped)
    }
}

private final class AnkiSQLite {
    private var handle: OpaquePointer?
    struct Row {
        let values: [Data]
        func data(_ column: Int) -> Data { values[column] }
        func string(_ column: Int) -> String { String(data: values[column], encoding: .utf8) ?? "" }
        func int(_ column: Int) -> Int { Int(string(column)) ?? 0 }
    }
    init(url: URL) throws {
        // APKG contains a standalone snapshot. Immutable mode also opens exports
        // whose SQLite header retains WAL mode without creating journal sidecars.
        guard sqlite3_open_v2(url.absoluteString + "?immutable=1", &handle, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX | SQLITE_OPEN_URI, nil) == SQLITE_OK else { throw AnkiImportError.invalid("The Anki database couldn't be opened.") }
        // Modern Anki declares its Unicode name collation in table/index schemas.
        // We never query names for identity or write the source database.
        sqlite3_create_collation(handle, "unicase", SQLITE_UTF8, nil) { _, leftCount, left, rightCount, right in
            let lhs = left.map { String(decoding: UnsafeBufferPointer(start: $0.assumingMemoryBound(to: UInt8.self), count: Int(leftCount)), as: UTF8.self) } ?? ""
            let rhs = right.map { String(decoding: UnsafeBufferPointer(start: $0.assumingMemoryBound(to: UInt8.self), count: Int(rightCount)), as: UTF8.self) } ?? ""
            return Int32(lhs.caseInsensitiveCompare(rhs).rawValue)
        }
        sqlite3_limit(handle, SQLITE_LIMIT_LENGTH, 2 * 1_024 * 1_024)
        sqlite3_limit(handle, SQLITE_LIMIT_SQL_LENGTH, 4_096)
        sqlite3_progress_handler(handle, 10_000, { _ in Task<Never, Never>.isCancelled ? 1 : 0 }, nil)
        sqlite3_exec(handle, "PRAGMA query_only=ON; PRAGMA trusted_schema=OFF;", nil, nil, nil)
        // Reject virtual tables/views in all tables used by the converter.
        let names = ["col", "cards", "notes", "notetypes", "fields", "templates", "decks"]
        for row in try rows("SELECT name,type,sql FROM sqlite_master") where names.contains(row.string(0)) {
            guard row.string(1) == "table", !row.string(2).uppercased().contains("VIRTUAL TABLE") else { throw AnkiImportError.invalid("The package uses an unsupported database structure.") }
        }
    }
    deinit { sqlite3_close(handle) }
    func hasTable(_ name: String) throws -> Bool { try rows("SELECT name FROM sqlite_master WHERE type='table'").contains { $0.string(0) == name } }
    func rows(_ sql: String) throws -> [Row] {
        var result: [Row] = [], bytes = 0
        try forEach(sql) { row in
            bytes += row.values.reduce(0) { $0 + $1.count }
            guard bytes < 32 * 1_024 * 1_024, result.count < 100_000 else { throw AnkiImportError.invalid("This package contains too much note-type metadata.") }
            result.append(row)
        }
        return result
    }
    func forEach(_ sql: String, body: (Row) throws -> Void) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK else { throw AnkiImportError.invalid("This Anki database schema isn't supported.") }
        defer { sqlite3_finalize(statement) }
        while true {
            try Task.checkCancellation()
            let status = sqlite3_step(statement)
            if status == SQLITE_DONE { return }
            if status == SQLITE_INTERRUPT { try Task.checkCancellation() }
            guard status == SQLITE_ROW else { throw AnkiImportError.invalid("The Anki database contains damaged or oversized card data.") }
            let values = (0..<sqlite3_column_count(statement)).map { column -> Data in
                if sqlite3_column_type(statement, column) == SQLITE_BLOB {
                    let count = Int(sqlite3_column_bytes(statement, column))
                    guard count > 0, let pointer = sqlite3_column_blob(statement, column) else { return Data() }
                    return Data(bytes: pointer, count: count)
                }
                guard let pointer = sqlite3_column_text(statement, column) else { return Data() }
                return Data(bytes: pointer, count: Int(sqlite3_column_bytes(statement, column)))
            }
            try body(Row(values: values))
        }
    }
}


/// Index only paths the APKG reader may use. Arbitrarily long unrelated ZIP names
/// never become retained dictionary keys; duplicate paths retain ZIPFoundation's first match.
struct AnkiArchiveEntryIndex {
    private var entries: [String: Entry] = [:]
    let scannedEntryCount: Int
    var indexedEntryCount: Int { entries.count }
    init<S: Sequence>(_ archive: S) throws where S.Element == Entry {
        let metadata: Set<String> = ["meta", "media", "collection.anki2", "collection.anki21", "collection.anki21b"]
        var count = 0
        for entry in archive {
            try Task.checkCancellation()
            count += 1
            guard count <= 150_000 else { throw AnkiImportError.invalid("This package contains too many files.") }
            let path = entry.path
            guard metadata.contains(path) || (path.utf8.count <= 20 && Int(path) != nil) else { continue }
            if entries[path] == nil { entries[path] = entry }
        }
        scannedEntryCount = count
    }
    mutating func include<S: Sequence>(_ paths: Set<String>, from archive: S) throws where S.Element == Entry {
        var missing = Set(paths.filter { entries[$0] == nil })
        guard !missing.isEmpty else { return }
        for entry in archive {
            try Task.checkCancellation()
            let path = entry.path
            if missing.remove(path) != nil { entries[path] = entry }
            if missing.isEmpty { return }
        }
    }
    subscript(_ path: String) -> Entry? { entries[path] }
}

/// A small file can finish before its per-file byte timer elapses. Coalesce across
/// the entire import so thousands of tiny files don't enqueue thousands of UI tasks.
final class AnkiImportProgressReporter: @unchecked Sendable {
    static let minimumInterval: TimeInterval = 0.1
    private let lock = NSLock()
    private let emit: @Sendable (AnkiImportProgress) -> Void
    private let clock: @Sendable () -> TimeInterval
    private var lastEmission: TimeInterval?
    private var lastStage: String?
    init(emit: @escaping @Sendable (AnkiImportProgress) -> Void,
         clock: @escaping @Sendable () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.emit = emit; self.clock = clock
    }
    func report(_ value: AnkiImportProgress) {
        let now = clock(), stage = value.title + "\u{0}" + value.unit
        let finished = value.fraction >= 1 || (value.completedItems != nil && value.completedItems == value.totalItems)
        lock.lock()
        let shouldEmit = lastStage != stage || finished || lastEmission.map { now - $0 >= Self.minimumInterval } ?? true
        if shouldEmit { lastEmission = now; lastStage = stage }
        lock.unlock()
        if shouldEmit { emit(value) }
    }
}
