import Foundation
import SwiftData
import Combine
import AnkiArchive

@MainActor
final class AnkiImportSession: ObservableObject {
    enum Phase { case chooseFile, converting, review, saving, complete, failed }
    @Published var phase = Phase.chooseFile
    @Published var progress = AnkiImportProgress(0, "Opening your deck")
    @Published var startedAt = Date()
    @Published var stageStartedAt = Date()
    @Published var archiveBytes: Int?
    @Published var package: AnkiImportPackage?
    @Published var selectedDecks = Set<String>()
    @Published var updateExisting = false
    @Published var error: String?
    @Published var result: AnkiImportResult?
    private var workspace: URL?
    private var worker: Task<AnkiImportPackage, Error>?
    private var operation: Task<Void, Never>?
    private var runID = UUID()
    var filename = ""

    var isBusy: Bool { phase == .converting || phase == .saving }
    var selectedCardCount: Int { package?.decks.filter { selectedDecks.contains($0.id) }.reduce(0) { $0 + $1.cardCount } ?? 0 }

    func open(_ url: URL) {
        cancel()
        let id = UUID(); runID = id
        let workspace = FileManager.default.temporaryDirectory.appendingPathComponent("LearnAlert-Anki-\(id.uuidString)", isDirectory: true)
        self.workspace = workspace; filename = url.lastPathComponent
        package = nil; error = nil; result = nil; phase = .converting
        startedAt = Date(); stageStartedAt = startedAt; archiveBytes = nil
        progress = .init(0, "Opening your deck", filename)
        let scoped = url.startAccessingSecurityScopedResource()
        let progressOwner = self
        let worker = Task.detached(priority: .userInitiated) {
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            return try AnkiPackageReader.read(url: url, workspace: workspace) { value in
                Task { @MainActor in
                    guard progressOwner.runID == id, progressOwner.phase == .converting else { return }
                    progressOwner.recordProgress(value)
                }
            }
        }
        self.worker = worker
        operation = Task { [weak self] in
            do {
                let package = try await worker.value
                guard let self, self.runID == id, !Task.isCancelled else { try? FileManager.default.removeItem(at: workspace); return }
                self.package = package
                self.worker = nil
                self.selectedDecks = Set(package.decks.map(\.id))
                self.phase = .review
            } catch {
                try? FileManager.default.removeItem(at: workspace)
                guard let self, self.runID == id, !Task.isCancelled else { return }
                self.error = error.localizedDescription; self.phase = .failed
            }
        }
    }

    func save(container: ModelContainer) {
        guard let package, !selectedDecks.isEmpty, phase == .review else { return }
        let selection = selectedDecks, update = updateExisting, filename = filename
        let id = runID, workspace = workspace
        phase = .saving; startedAt = Date(); stageStartedAt = startedAt
        progress = .init(0.02, "Adding to your library")
        let progressOwner = self
        operation = Task { [weak self] in
            do {
                // ModelContext chooses its queue at initialization. Create the
                // model actor off the UI actor so file copies and inserts stay off it.
                let committer = await Task.detached(priority: .userInitiated) {
                    AnkiLibraryImporter(modelContainer: container)
                }.value
                let result = try await committer.save(package, selectedDecks: selection, updateExisting: update, filename: filename) { value in
                    Task { @MainActor in
                        guard progressOwner.runID == id, progressOwner.phase == .saving else { return }
                        progressOwner.recordProgress(value)
                    }
                }
                if let workspace { try? FileManager.default.removeItem(at: workspace) }
                guard let self, self.runID == id else { return }
                self.workspace = nil; self.result = result; self.package = nil; self.phase = .complete
            } catch {
                guard let self, self.runID == id else { return }
                self.error = error.localizedDescription; self.phase = .review
            }
        }
    }

    private func recordProgress(_ value: AnkiImportProgress) {
        guard value.fraction >= progress.fraction else { return }
        if value.title != progress.title { stageStartedAt = Date() }
        if let bytes = value.archiveBytes { archiveBytes = bytes }
        progress = value
    }

    func cancel() {
        runID = UUID()
        worker?.cancel(); operation?.cancel()
        if let workspace {
            let worker = worker
            Task.detached {
                _ = try? await worker?.value
                try? FileManager.default.removeItem(at: workspace)
            }
        }
        worker = nil; operation = nil; workspace = nil
    }
}

struct AnkiImportResult: Sendable { let added: Int; let updated: Int; let unchanged: Int; let decks: Int }

@ModelActor
actor AnkiLibraryImporter {
    func save(_ package: AnkiImportPackage, selectedDecks: Set<String>, updateExisting: Bool, filename: String,
              progress: @Sendable (AnkiImportProgress) -> Void) throws -> AnkiImportResult {
        modelContext.autosaveEnabled = false
        let mediaFolder = UUID().uuidString
        let destination = AnkiCardContent.mediaRoot.appendingPathComponent(mediaFolder, isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        var saved = false
        defer {
            if !saved { modelContext.rollback(); try? FileManager.default.removeItem(at: destination) }
        }
        let files = try FileManager.default.contentsOfDirectory(at: package.mediaDirectory, includingPropertiesForKeys: nil)
        var copiedBytes = 0
        progress(.init(0.05, "Saving images & audio", completedItems: 0, totalItems: files.count, unit: "files", processedBytes: 0))
        for (index, file) in files.enumerated() {
            try Task.checkCancellation()
            try FileManager.default.copyItem(at: file, to: destination.appendingPathComponent(file.lastPathComponent))
            copiedBytes += (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            if index % 20 == 0 || index + 1 == files.count { progress(.init(0.05 + 0.35 * Double(index + 1) / Double(max(1, files.count)), "Saving images & audio", "\(index + 1) of \(files.count)", completedItems: index + 1, totalItems: files.count, unit: "files", processedBytes: copiedBytes)) }
        }
        let library = try modelContext.fetch(FetchDescriptor<Deck>())
        var decks: [String: Deck] = [:]
        var added = 0, updated = 0, unchanged = 0
        var replacedMediaFolders = Set<String>()
        let cards = package.cards.filter { selectedDecks.contains($0.deckID) }
        let incomingCards = Dictionary(grouping: cards, by: \.deckID)
        var existing: [String: [String: Flashcard]] = [:]
        var deckCards: [String: [Flashcard]] = [:]
        for source in package.decks where selectedDecks.contains(source.id) {
            // Deck 1 (the default deck) is reused across unrelated Anki collections.
            // Card GUID/template identities establish that this is actually a re-import.
            let incomingIDs = Set((incomingCards[source.id] ?? []).map(\.id))
            let matches = library.filter { $0.sourceAnkiDeckID == source.id }.map { candidate in
                (deck: candidate, overlap: candidate.cards.reduce(0) { count, card in
                    count + (card.sourceAnkiCardID.map { incomingIDs.contains($0) } == true ? 1 : 0)
                })
            }
            let matched = matches.filter { $0.overlap > 0 }.max { $0.overlap < $1.overlap }?.deck
            let deck: Deck
            if let matched { deck = matched }
            else {
                deck = Deck(name: source.name, colorHex: "#A9D7F5", deckType: "Anki", orderIndex: library.count + decks.count)
                deck.sourceAnkiDeckID = source.id; deck.sourceKind = "anki"; deck.sourceName = filename
                modelContext.insert(deck); decks[source.id] = deck
            }
            decks[source.id] = deck
            var map: [String: Flashcard] = [:]
            for card in deck.cards { if let id = card.sourceAnkiCardID { map[id] = card } }
            existing[source.id] = map
            deckCards[source.id] = deck.cards
        }
        for (index, source) in cards.enumerated() {
            try Task.checkCancellation()
            guard decks[source.deckID] != nil else { continue }
            let card: Flashcard
            if let found = existing[source.deckID]?[source.id] {
                guard updateExisting else { unchanged += 1; continue }
                if let folder = found.ankiContent?.mediaFolder { replacedMediaFolders.insert(folder) }
                card = found; updated += 1
            } else {
                card = Flashcard(question: "", cardType: .anki)
                card.orderIndex = deckCards[source.deckID]?.count ?? 0
                card.sourceAnkiCardID = source.id
                modelContext.insert(card)
                deckCards[source.deckID, default: []].append(card)
                existing[source.deckID, default: [:]][source.id] = card
                added += 1
            }
            card.question = String((source.plainFront.isEmpty ? "Image / audio card" : source.plainFront).prefix(8_000))
            card.correctAnswer = String(source.plainBack.prefix(8_000))
            card.ankiContent = AnkiCardContent(frontHTML: source.front, backHTML: source.back, css: source.css,
                mediaFolder: mediaFolder, templateOrdinal: source.templateOrdinal, noteType: source.noteType, tags: source.tags)
            card.cardType = .anki
            if index % 100 == 0 || index + 1 == cards.count { progress(.init(0.42 + 0.53 * Double(index + 1) / Double(max(1, cards.count)), "Adding your cards", "\(index + 1) of \(cards.count)", completedItems: index + 1, totalItems: cards.count, unit: "cards")) }
        }
        for (id, cards) in deckCards { decks[id]?.cards = cards }
        try Task.checkCancellation()
        progress(.init(0.97, "Finishing up"))
        try modelContext.save()
        saved = true
        AnkiMediaCleanup.removeUnreferenced(replacedMediaFolders, context: modelContext)
        if added + updated == 0 { try? FileManager.default.removeItem(at: destination) }
        progress(.init(1, "Your deck is ready"))
        return AnkiImportResult(added: added, updated: updated, unchanged: unchanged, decks: selectedDecks.count)
    }
}

/// Rates are phase-local measurements; local archive work is never labeled as network transfer.
struct AnkiImportTelemetry {
    let progress: AnkiImportProgress
    let elapsed: TimeInterval
    let stageElapsed: TimeInterval
    init(progress: AnkiImportProgress, startedAt: Date, stageStartedAt: Date, now: Date) {
        self.progress = progress
        elapsed = max(0, now.timeIntervalSince(startedAt))
        stageElapsed = max(0, now.timeIntervalSince(stageStartedAt))
    }
    var unitsPerSecond: Double? {
        guard stageElapsed >= 0.25, let count = progress.completedItems, count > 0 else { return nil }
        return Double(count) / stageElapsed
    }
    var bytesPerSecond: Double? {
        guard stageElapsed >= 0.25, let bytes = progress.processedBytes, bytes > 0 else { return nil }
        return Double(bytes) / stageElapsed
    }
    var remainingSeconds: TimeInterval? {
        guard stageElapsed >= 1, let completed = progress.completedItems, let total = progress.totalItems,
              completed > 0, total > completed, let rate = unitsPerSecond else { return nil }
        return Double(total - completed) / rate
    }
    static func duration(_ seconds: TimeInterval) -> String {
        let seconds = Int(max(0, seconds).rounded(.up))
        return seconds >= 60 ? "\(seconds / 60)m \(seconds % 60)s" : "\(seconds)s"
    }
    static func bytes(_ count: Int) -> String { ByteCountFormatter.string(fromByteCount: Int64(count), countStyle: .file) }
}
