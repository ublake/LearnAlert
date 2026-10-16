import XCTest
import ZIPFoundation
@testable import AnkiArchive

final class AnkiArchiveTests: XCTestCase {
    private func fixture(_ name: String) throws -> URL { try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "apkg", subdirectory: "Fixtures")) }
    private func temporary() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true) }

    func testOfficialLegacyAndModernExportsPreserveActualCardsAndMedia() throws {
        var identities: Set<String>?
        for format in ["legacy", "modern"] {
            let workspace = temporary(); defer { try? FileManager.default.removeItem(at: workspace) }
            let package = try AnkiPackageReader.read(url: fixture(format), workspace: workspace)
            XCTAssertEqual(package.cards.count, 9)
            XCTAssertEqual(package.decks.count, 3)
            XCTAssertEqual(package.mediaCount, 2)
            XCTAssertEqual(package.skippedCards, 0)
            XCTAssertTrue(package.warnings.isEmpty, package.warnings.joined(separator: "; "))
            let sound = try XCTUnwrap(package.mediaFiles["tone.wav"])
            XCTAssertTrue(FileManager.default.fileExists(atPath: package.mediaDirectory.appendingPathComponent(sound).path))
            let forward = try XCTUnwrap(package.cards.first { $0.noteGUID == "fixture-cat" && $0.templateOrdinal == 0 })
            let reverse = try XCTUnwrap(package.cards.first { $0.noteGUID == "fixture-cat" && $0.templateOrdinal == 1 })
            XCTAssertTrue(forward.front.contains("<b>고양이</b>"))
            XCTAssertTrue(forward.front.contains("data-sound=\"tone.wav\""))
            XCTAssertTrue(reverse.front.contains("A cat"))
            XCTAssertEqual(forward.tags, ["fixture", "한국어"])
            let clozes = package.cards.filter { $0.noteGUID == "fixture-cloze" }
            XCTAssertEqual(clozes.count, 2)
            XCTAssertTrue(clozes.first { $0.templateOrdinal == 0 }!.front.contains("[sounds]"))
            XCTAssertTrue(clozes.first { $0.templateOrdinal == 1 }!.back.contains("consonants</span>"))
            let occlusions = package.cards.filter { $0.noteGUID == "fixture-occlusion" }
            XCTAssertEqual(occlusions.count, 2)
            XCTAssertTrue(occlusions[0].front.contains("learnalert-io"))
            XCTAssertFalse(occlusions[0].front.contains("anki.imageOcclusion.setup"))
            XCTAssertTrue(occlusions[0].back.contains("A diagram explanation"))
            let custom = try XCTUnwrap(package.cards.first { $0.noteGUID == "fixture-styled" })
            XCTAssertTrue(custom.front.contains("<aside>An extra note</aside>"))
            XCTAssertTrue(custom.front.contains("<script>"))
            XCTAssertTrue(custom.css.contains("#4488cc"))
            let keys = Set(package.cards.map(\.id))
            if let identities { XCTAssertEqual(keys, identities) } else { identities = keys }
        }
    }

    func testNestedClozeAndIndependentGroups() {
        let text = "{{c1::outer {{c2::inner}}::hint}} plus {{c2::second}}"
        XCTAssertEqual(AnkiTemplateRenderer.cloze(text, target: 1, answer: false), "<span class=\"cloze\">[hint]</span> plus second")
        XCTAssertTrue(AnkiTemplateRenderer.cloze(text, target: 2, answer: false).contains("outer <span class=\"cloze\">[…]</span>"))
        XCTAssertTrue(AnkiTemplateRenderer.cloze(text, target: 2, answer: true).contains("inner</span>"))
    }

    func testConditionalsFrontSideFiltersAndLiteralBracesInFields() throws {
        let type = AnkiNoteType(id: "1", name: "Custom", fields: ["Front", "Extra"], templates: [
            AnkiTemplate(name: "Card", front: "{{#Extra}}{{Front}}{{/Extra}}{{^Missing}}ok{{/Missing}}", back: "{{FrontSide}} {{text:Front}}")
        ], css: "", isCloze: false)
        let output = try AnkiTemplateRenderer.render(type: type, values: ["<b>{{literal}}</b>", "yes"], ordinal: 0, deck: "Parent::Child", tags: [])
        XCTAssertEqual(output.front, "<b>{{literal}}</b>ok")
        XCTAssertEqual(output.back, "<b>{{literal}}</b>ok {{literal}}")
        XCTAssertTrue(output.warnings.isEmpty)
    }

    func testUnknownFilterAndExternalResourcesAreReported() throws {
        let type = AnkiNoteType(id: "1", name: "Custom", fields: ["Front"], templates: [
            AnkiTemplate(name: "Card", front: "{{addon:Front}}<img src=\"https://example.com/a.png\">", back: "{{Front}}")
        ], css: "", isCloze: false)
        let output = try AnkiTemplateRenderer.render(type: type, values: ["Hello"], ordinal: 0, deck: "D", tags: [])
        XCTAssertEqual(output.warnings.count, 2)
        XCTAssertTrue(output.front.contains("Hello"))
    }

    func testMalformedArchiveAndUnsupportedVersionFailClearly() throws {
        let base = temporary(); try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }
        let broken = base.appendingPathComponent("bad.apkg")
        try Data("not a ZIP".utf8).write(to: broken)
        XCTAssertThrowsError(try AnkiPackageReader.read(url: broken, workspace: base.appendingPathComponent("bad")))
        let newer = base.appendingPathComponent("new.apkg")
        try zip(["meta": Data([8, 99])], to: newer)
        XCTAssertThrowsError(try AnkiPackageReader.read(url: newer, workspace: base.appendingPathComponent("new"))) { error in
            XCTAssertTrue(error.localizedDescription.contains("newer format"))
        }
    }

    func testMediaPathTraversalCannotEscapeWorkspace() throws {
        let base = temporary(); try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }
        let original = try Archive(url: fixture("legacy"), accessMode: .read)
        var items: [String: Data] = [:]
        for entry in original {
            var data = Data(); _ = try original.extract(entry) { data.append($0) }; items[entry.path] = data
        }
        items["media"] = Data("{\"0\":\"../escaped.png\"}".utf8)
        let attack = base.appendingPathComponent("attack.apkg"); try zip(items, to: attack)
        XCTAssertThrowsError(try AnkiPackageReader.read(url: attack, workspace: base.appendingPathComponent("workspace"))) { error in
            XCTAssertTrue(error.localizedDescription.contains("unsafe media filename"))
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: base.appendingPathComponent("escaped.png").path))
        for name in ["../a", "a/b", "a\\b", ".", "..", "a\0b"] { XCTAssertFalse(AnkiPackageReader.isSafeMediaName(name)) }
        XCTAssertTrue(AnkiPackageReader.isSafeMediaName("한글 picture.png"))
    }

    func testZstandardOutputIsBounded() throws {
        let archive = try Archive(url: fixture("modern"), accessMode: .read)
        let entry = try XCTUnwrap(archive["collection.anki21b"])
        var data = Data(); _ = try archive.extract(entry) { data.append($0) }
        XCTAssertThrowsError(try AnkiPackageReader.decompress(data, limit: 8))
        XCTAssertThrowsError(try AnkiPackageReader.decompress(Data([1, 2, 3]), limit: 1_024))
    }

    func testMissingMediaIsReportedEvenWhenTheExportMediaIndexIsEmpty() throws {
        let base = temporary(); try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }
        var items = try legacyItems()
        items["media"] = Data("{}".utf8)
        let source = base.appendingPathComponent("no-media.apkg"); try zip(items, to: source)
        let package = try AnkiPackageReader.read(url: source, workspace: base.appendingPathComponent("workspace"))
        XCTAssertEqual(package.cards.count, 9)
        XCTAssertEqual(package.mediaCount, 0)
        XCTAssertTrue(package.warnings.contains { $0.contains("2 referenced media files") })
    }

    func testOldCollectionAnki2PackagesUseTheRealDatabaseWithoutAPlaceholder() throws {
        let base = temporary(); try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }
        var items = try legacyItems()
        items["collection.anki2"] = try XCTUnwrap(items.removeValue(forKey: "collection.anki21"))
        items.removeValue(forKey: "meta")
        let source = base.appendingPathComponent("old.apkg"); try zip(items, to: source)
        let package = try AnkiPackageReader.read(url: source, workspace: base.appendingPathComponent("workspace"))
        XCTAssertEqual(package.cards.count, 9)
        XCTAssertEqual(package.mediaCount, 2)
        XCTAssertTrue(package.warnings.isEmpty)
    }

    func testLongUnicodeAndCaseDistinctFilenamesUseIndependentSafeStorageNames() throws {
        let base = temporary(); try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }
        var items = try legacyItems()
        let longName = String(repeating: "한", count: 200) + ".png"
        items["2"] = items["0"]
        items["media"] = try JSONSerialization.data(withJSONObject: ["0": "Picture.png", "1": "picture.png", "2": longName])
        let source = base.appendingPathComponent("unicode.apkg"); try zip(items, to: source)
        let package = try AnkiPackageReader.read(url: source, workspace: base.appendingPathComponent("workspace"))
        XCTAssertEqual(package.mediaCount, 3)
        XCTAssertNotEqual(package.mediaFiles["Picture.png"], package.mediaFiles["picture.png"])
        let stored = try XCTUnwrap(package.mediaFiles[longName])
        XCTAssertTrue(stored.utf8.count < 30)
        XCTAssertTrue(FileManager.default.fileExists(atPath: package.mediaDirectory.appendingPathComponent(stored).path))
    }

    func testCancelledImportStopsBeforeExtraction() async throws {
        let source = try fixture("modern"), workspace = temporary()
        defer { try? FileManager.default.removeItem(at: workspace) }
        let task = Task {
            try await Task.sleep(nanoseconds: 50_000_000)
            return try AnkiPackageReader.read(url: source, workspace: workspace)
        }
        task.cancel()
        do { _ = try await task.value; XCTFail("Expected cancellation") } catch is CancellationError { }
    }

    private func zip(_ items: [String: Data], to url: URL) throws {
        let archive = try Archive(url: url, accessMode: .create)
        for (name, data) in items {
            try archive.addEntry(with: name, type: .file, uncompressedSize: Int64(data.count)) { position, size in
                data.subdata(in: Int(position)..<Int(position) + size)
            }
        }
    }

    private func legacyItems() throws -> [String: Data] {
        let archive = try Archive(url: fixture("legacy"), accessMode: .read)
        var items: [String: Data] = [:]
        for entry in archive {
            var data = Data(); _ = try archive.extract(entry) { data.append($0) }; items[entry.path] = data
        }
        return items
    }
}
