import Foundation
import SQLite3
import XCTest
import ZIPFoundation
@testable import AnkiArchive

private final class ImportTelemetry: @unchecked Sendable {
    private let lock = NSLock()
    private var samples: [(AnkiImportProgress, TimeInterval)] = []
    func record(_ progress: AnkiImportProgress) {
        lock.lock(); defer { lock.unlock() }
        samples.append((progress, ProcessInfo.processInfo.systemUptime))
    }
    func values() -> [(AnkiImportProgress, TimeInterval)] {
        lock.lock(); defer { lock.unlock() }; return samples
    }
}

private final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value: TimeInterval = 0
    func now() -> TimeInterval { lock.lock(); defer { lock.unlock() }; return value }
    func advance(_ amount: TimeInterval) { lock.lock(); defer { lock.unlock() }; value += amount }
}

private final class EntryCounter { var count = 0 }
private struct CountedEntries: Sequence {
    let archive: Archive
    let counter: EntryCounter
    func makeIterator() -> AnyIterator<Entry> {
        let iterator = archive.makeIterator()
        return AnyIterator {
            let value = iterator.next()
            if value != nil { counter.count += 1 }
            return value
        }
    }
}

final class AnkiArchivePerformanceTests: XCTestCase {
    /// This exercises actual ZIP/SQLite/template/media work rather than a mocked card loop.
    /// Override the two counts to profile a larger deck without committing a huge fixture.
    func testLargeArchivePreservesCardsMediaAndProgress() throws {
        let notes = Int(ProcessInfo.processInfo.environment["LEARNALERT_ANKI_BENCHMARK_NOTES"] ?? "2000") ?? 2000
        let files = Int(ProcessInfo.processInfo.environment["LEARNALERT_ANKI_BENCHMARK_FILES"] ?? "2000") ?? 2000
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let archive = try syntheticArchive(in: root, notes: notes, files: files)
        let telemetry = ImportTelemetry()
        let started = ProcessInfo.processInfo.systemUptime
        let package = try AnkiPackageReader.read(url: archive, workspace: root.appendingPathComponent("read"), progress: telemetry.record)
        let elapsed = ProcessInfo.processInfo.systemUptime - started
        let samples = telemetry.values()
        print("ANKI_BENCH notes=\(notes) cards=\(package.cards.count) files=\(files) read_seconds=\(String(format: "%.3f", elapsed)) callbacks=\(samples.count)")
        XCTAssertEqual(package.cards.count, notes * 2)
        XCTAssertEqual(package.mediaCount, files)
        XCTAssertEqual(package.skippedCards, 0)
        XCTAssertTrue(package.warnings.isEmpty, package.warnings.joined(separator: "; "))
        let forward = try XCTUnwrap(package.cards.first { $0.noteGUID == "synthetic-0" && $0.templateOrdinal == 0 })
        let reverse = try XCTUnwrap(package.cards.last { $0.noteGUID == "synthetic-\(notes - 1)" && $0.templateOrdinal == 1 })
        XCTAssertTrue(forward.front.contains("<b>한글 0 {{literal}}</b>"))
        XCTAssertTrue(forward.front.contains("data-sound=\"asset-1.wav\""))
        XCTAssertTrue(forward.back.contains("<hr id=answer><span>Meaning 0</span>"))
        XCTAssertTrue(reverse.front.contains("Meaning \(notes - 1)"))
        XCTAssertTrue(reverse.back.contains("{{literal}}"))
        XCTAssertTrue(forward.css.contains("background-image"))
        XCTAssertEqual(forward.tags, ["scale", "한국어"])
        for index in [0, files / 2, files - 1] {
            let name = mediaName(index)
            let stored = try XCTUnwrap(package.mediaFiles[name])
            XCTAssertEqual(try Data(contentsOf: package.mediaDirectory.appendingPathComponent(stored)), mediaBytes(index))
        }
        // This bound scales with elapsed time, not machine speed or archive size.
        // Initial/stage/final reports are the only events outside the 100ms budget.
        XCTAssertLessThanOrEqual(samples.count, Int(ceil(elapsed / AnkiImportProgressReporter.minimumInterval)) + 24)
        XCTAssertEqual(samples.last?.0.fraction, 1)
        XCTAssertEqual(samples.last(where: { $0.0.unit == "cards" })?.0.completedItems, notes * 2)
        XCTAssertEqual(samples.last(where: { $0.0.unit == "files" })?.0.completedItems, files)
        XCTAssertEqual(samples.last(where: { $0.0.unit == "files" })?.0.processedBytes, package.mediaBytes)
    }

    func testArchiveLookupTraversesDirectoryOnceForThousandsOfLookups() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = try syntheticArchive(in: root, notes: 1, files: 500)
        let archive = try Archive(url: url, accessMode: .read)
        let counter = EntryCounter()
        let sequence = CountedEntries(archive: archive, counter: counter)
        var index = try AnkiArchiveEntryIndex(sequence)
        XCTAssertEqual(index.scannedEntryCount, 502)
        XCTAssertEqual(counter.count, 502)
        for lookup in 0..<10_000 { XCTAssertNotNil(index[String(lookup % 500)]) }
        try index.include(Set((0..<500).map(String.init)), from: sequence)
        XCTAssertEqual(counter.count, 502, "Lookups and already-indexed include requests must not rescan ZIP headers")
        XCTAssertEqual(index.indexedEntryCount, 502)
    }

    func testLongZeroPaddedLegacyMediaKeysRemainReadable() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let fixture = try XCTUnwrap(Bundle.module.url(forResource: "legacy", withExtension: "apkg", subdirectory: "Fixtures"))
        let source = try Archive(url: fixture, accessMode: .read)
        var items: [String: Data] = [:]
        for entry in source { var data = Data(); _ = try source.extract(entry) { data.append($0) }; items[entry.path] = data }
        var media = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(items["media"])) as? [String: String])
        let padded = String(repeating: "0", count: 200)
        media[padded] = media.removeValue(forKey: "0")
        items[padded] = items.removeValue(forKey: "0")
        items["media"] = try JSONSerialization.data(withJSONObject: media)
        let url = root.appendingPathComponent("padded.apkg")
        let output = try Archive(url: url, accessMode: .create)
        for (path, data) in items {
            try output.addEntry(with: path, type: .file, uncompressedSize: Int64(data.count)) { position, count in data.subdata(in: Int(position)..<Int(position) + count) }
        }
        let result = try AnkiPackageReader.read(url: url, workspace: root.appendingPathComponent("read"))
        XCTAssertEqual(result.mediaCount, 2)
        XCTAssertTrue(result.warnings.isEmpty)
        let name = try XCTUnwrap(media[padded])
        let stored = try XCTUnwrap(result.mediaFiles[name])
        XCTAssertEqual(try Data(contentsOf: result.mediaDirectory.appendingPathComponent(stored)), items[padded])
    }

    func testProgressCoalescesTinyFilesButAlwaysReportsStageChangesAndCompletion() {
        let clock = TestClock(), telemetry = ImportTelemetry()
        let reporter = AnkiImportProgressReporter(emit: telemetry.record, clock: clock.now)
        for index in 0..<10_000 {
            reporter.report(.init(0.5, "Media", completedItems: index, totalItems: 10_000, unit: "files", processedBytes: index))
        }
        XCTAssertEqual(telemetry.values().count, 1)
        clock.advance(0.1)
        reporter.report(.init(0.6, "Media", completedItems: 9_999, totalItems: 10_000, unit: "files"))
        XCTAssertEqual(telemetry.values().count, 2)
        reporter.report(.init(0.97, "Media", completedItems: 10_000, totalItems: 10_000, unit: "files", processedBytes: 123_456))
        reporter.report(.init(0.98, "Preparing"))
        reporter.report(.init(1, "Ready"))
        XCTAssertEqual(telemetry.values().count, 5)
        XCTAssertEqual(telemetry.values().last(where: { $0.0.unit == "files" })?.0.processedBytes, 123_456)
    }

    func testSharedTemplatesAreParsedOnceWithoutCachingFieldHTMLOrDynamicWarnings() throws {
        let type = AnkiNoteType(id: "1", name: "Reusable", fields: ["Front", "Extra"], templates: [
            .init(name: "Card", front: "{{#Extra}}{{Front}}{{/Extra}}{{^Extra}}empty{{/Extra}} {{Tags}} {{Deck}}", back: "{{FrontSide}}<hr>{{text:Front}}")
        ], css: ".card{color:#112233}", isCloze: false)
        let session = AnkiTemplateRenderer.Session()
        for index in 0..<1_000 {
            let html = "<b>한글 \(index) {{literal}}</b><img src=\"https://example.com/\(index).png\">"
            let value = try session.render(type: type, values: [html, index.isMultiple(of: 2) ? "yes" : ""], ordinal: 0, deck: "Deck::\(index)", tags: ["tag-\(index)"])
            XCTAssertTrue(value.front.contains("tag-\(index) Deck::\(index)"))
            XCTAssertTrue(value.back.contains("한글 \(index) {{literal}}"))
            XCTAssertEqual(value.warnings.isEmpty, !index.isMultiple(of: 2))
            if index.isMultiple(of: 2) { XCTAssertTrue(value.front.contains(html)) }
            else { XCTAssertTrue(value.front.hasPrefix("empty")) }
        }
        XCTAssertEqual(session.parsedTemplateCount, 2)
        let invalid = AnkiNoteType(id: "bad", name: "Bad", fields: ["Front"], templates: [.init(name: "Card", front: "{{#Front}}", back: "")], css: "", isCloze: false)
        for _ in 0..<100 { XCTAssertThrowsError(try session.render(type: invalid, values: ["yes"], ordinal: 0, deck: "D", tags: [])) }
        XCTAssertEqual(session.parsedTemplateCount, 3, "An invalid shared template must not be reparsed for each card")
    }

    func testLargeSoundAndFuriganaFieldsPreserveEveryReplacementAndUnicode() throws {
        let type = AnkiNoteType(id: "1", name: "Audio", fields: ["Front"], templates: [.init(name: "Card", front: "{{Front}}", back: "{{FrontSide}}")], css: "", isCloze: false)
        let source = (0..<2_000).map { "🐱\($0) [sound:音-\($0)&.wav]" }.joined(separator: " · ")
        let sound = try AnkiTemplateRenderer.render(type: type, values: [source], ordinal: 0, deck: "D", tags: [])
        XCTAssertEqual(sound.front.components(separatedBy: "class=\"anki-sound\"").count - 1, 2_000)
        XCTAssertEqual(sound.front, sound.back)
        XCTAssertTrue(sound.front.contains("data-sound=\"音-1999&amp;.wav\""))
        XCTAssertTrue(sound.front.contains("🐱1999"))
        let rubyType = AnkiNoteType(id: "2", name: "Ruby", fields: ["Front"], templates: [.init(name: "Card", front: "{{furigana:Front}}", back: "{{FrontSide}}")], css: "", isCloze: false)
        let rubySource = (0..<1_000).map { "猫\($0)[ねこ\($0)]" }.joined(separator: " ")
        let ruby = try AnkiTemplateRenderer.render(type: rubyType, values: [rubySource], ordinal: 0, deck: "D", tags: [])
        let expected = (0..<1_000).map { "<ruby>猫\($0)<rt>ねこ\($0)</rt></ruby>" }.joined(separator: " ")
        XCTAssertEqual(ruby.front, expected)
        XCTAssertEqual(ruby.back, expected)
    }

    func testCancellationAfterConversionStopsBeforeMediaExtraction() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = try syntheticArchive(in: root, notes: 100, files: 100)
        let reachedMedia = expectation(description: "Reached media extraction")
        let gate = DispatchSemaphore(value: 0)
        let task = Task.detached {
            try AnkiPackageReader.read(url: url, workspace: root.appendingPathComponent("cancelled")) { progress in
                if progress.unit == "files", progress.completedItems == 0 {
                    reachedMedia.fulfill()
                    gate.wait()
                }
            }
        }
        await fulfillment(of: [reachedMedia], timeout: 10)
        task.cancel()
        gate.signal()
        do { _ = try await task.value; XCTFail("Expected cancellation during media phase") }
        catch is CancellationError { }
        let files = (try? FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("cancelled/media").path)) ?? []
        XCTAssertTrue(files.isEmpty)
    }

    private func mediaName(_ index: Int) -> String { "asset-\(index).\(index.isMultiple(of: 2) ? "png" : "wav")" }
    private func mediaBytes(_ index: Int) -> Data { Data("unchanged media bytes \(index) 🐱".utf8) }

    private func syntheticArchive(in root: URL, notes: Int, files: Int) throws -> URL {
        XCTAssertTrue((1...20_000).contains(notes) && files >= 2 && files.isMultiple(of: 2))
        let database = root.appendingPathComponent("source.sqlite")
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(database.path, &db), SQLITE_OK)
        defer { sqlite3_close(db) }
        func execute(_ sql: String) throws {
            guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else { throw AnkiImportError.invalid("Synthetic SQLite fixture failed: \(String(cString: sqlite3_errmsg(db)))") }
        }
        try execute("CREATE TABLE col(models TEXT,decks TEXT); CREATE TABLE notes(id INTEGER PRIMARY KEY,guid TEXT,mid INTEGER,flds TEXT,tags TEXT); CREATE TABLE cards(id INTEGER PRIMARY KEY,nid INTEGER,did INTEGER,ord INTEGER,odid INTEGER); BEGIN;")
        let models: [String: Any] = ["1": ["name": "Synthetic", "type": 0,
            "flds": [["name": "Front", "ord": 0], ["name": "Back", "ord": 1], ["name": "Extra", "ord": 2]],
            "tmpls": [["name": "Forward", "ord": 0, "qfmt": "<section>{{#Front}}{{Front}}{{/Front}}{{#Extra}}{{Extra}}{{/Extra}}</section>", "afmt": "{{FrontSide}}<hr id=answer>{{Back}}"],
                       ["name": "Reverse", "ord": 1, "qfmt": "{{Back}}", "afmt": "{{FrontSide}}<hr id=answer>{{Front}} {{Extra}}"]],
            "css": ".card { color: #112233; background-image: url('asset-0.png'); } <script>const literal = '{{not_a_template}}';</script>"]]
        let modelJSON = String(data: try JSONSerialization.data(withJSONObject: models), encoding: .utf8)!
        let deckJSON = #"{"1":{"name":"Large::Synthetic"}}"#
        try execute("INSERT INTO col VALUES ('\(modelJSON.replacingOccurrences(of: "'", with: "''"))','\(deckJSON)');")
        var noteStatement: OpaquePointer?, cardStatement: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(db, "INSERT INTO notes VALUES (?,?,?,?,?)", -1, &noteStatement, nil), SQLITE_OK)
        XCTAssertEqual(sqlite3_prepare_v2(db, "INSERT INTO cards VALUES (?,?,?,?,0)", -1, &cardStatement, nil), SQLITE_OK)
        defer { sqlite3_finalize(noteStatement); sqlite3_finalize(cardStatement) }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        for index in 0..<notes {
            let fields = ["<b>한글 \(index) {{literal}}</b><img src=\"\(mediaName((index * 2) % files))\">", "<span>Meaning \(index)</span>", "<aside>[sound:\(mediaName((index * 2 + 1) % files))]</aside>"].joined(separator: "\u{1f}")
            sqlite3_bind_int64(noteStatement, 1, Int64(index + 1))
            sqlite3_bind_text(noteStatement, 2, "synthetic-\(index)", -1, transient)
            sqlite3_bind_int64(noteStatement, 3, 1)
            sqlite3_bind_text(noteStatement, 4, fields, -1, transient)
            sqlite3_bind_text(noteStatement, 5, "scale 한국어", -1, transient)
            XCTAssertEqual(sqlite3_step(noteStatement), SQLITE_DONE); sqlite3_reset(noteStatement)
            for ordinal in 0..<2 {
                sqlite3_bind_int64(cardStatement, 1, Int64(index * 2 + ordinal + 1))
                sqlite3_bind_int64(cardStatement, 2, Int64(index + 1))
                sqlite3_bind_int64(cardStatement, 3, 1)
                sqlite3_bind_int64(cardStatement, 4, Int64(ordinal))
                XCTAssertEqual(sqlite3_step(cardStatement), SQLITE_DONE); sqlite3_reset(cardStatement)
            }
        }
        try execute("COMMIT;")
        let url = root.appendingPathComponent("large.apkg")
        let archive = try Archive(url: url, accessMode: .create)
        try archive.addEntry(with: "collection.anki2", fileURL: database, compressionMethod: .deflate)
        let media = Dictionary(uniqueKeysWithValues: (0..<files).map { (String($0), mediaName($0)) })
        func add(_ name: String, _ data: Data) throws {
            try archive.addEntry(with: name, type: .file, uncompressedSize: Int64(data.count)) { position, count in data.subdata(in: Int(position)..<Int(position) + count) }
        }
        try add("media", JSONSerialization.data(withJSONObject: media, options: .sortedKeys))
        for index in 0..<files { try add(String(index), mediaBytes(index)) }
        return url
    }
}
