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
    @Published var recentSamples: [AnkiImportRateSample] = []
    @Published var archiveBytes: Int?
    @Published private(set) var completedFiles: Int?
    @Published private(set) var totalFiles: Int?
    @Published var package: AnkiImportPackage?
    @Published var selectedDecks = Set<String>()
    @Published var updateExisting = false
    @Published var deckNames: [String: String] = [:]
    @Published private(set) var hasConfirmedDeckNames = false
    @Published var error: String?
    @Published var result: AnkiImportResult?
    private struct SaveRequest: Sendable {
        let package: AnkiImportPackage
        let container: ModelContainer
        let selection: Set<String>
        let update: Bool
        let filename: String
        let deckNames: [String: String]
        let renamedDecks: Set<String>
    }
    private var pendingSave: SaveRequest?
    private var workspace: URL?
    private var worker: Task<AnkiImportPackage, Error>?
    private var savingWorker: Task<AnkiImportResult, Error>?
    private var operation: Task<Void, Never>?
    private var runID = UUID()
    private var renamedDecks = Set<String>()
    var filename = ""

    var isBusy: Bool { phase == .converting || phase == .saving }
    var selectedCardCount: Int { package?.decks.filter { selectedDecks.contains($0.id) }.reduce(0) { $0 + $1.cardCount } ?? 0 }
    var canConfirmDeckNames: Bool {
        !selectedDecks.isEmpty && selectedDecks.allSatisfy {
            !(deckNames[$0] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
    var waitingForCommit: Bool { phase == .saving && progress.completedItems == nil && progress.fraction >= 0.96 }
    var filePercentage: Int? {
        guard let completedFiles, let totalFiles, totalFiles > 0 else { return nil }
        let percentage = Int(Double(min(totalFiles, max(0, completedFiles))) / Double(totalFiles) * 100)
        return min(phase == .complete ? 100 : 99, percentage)
    }

    func open(_ url: URL) {
        cancel()
        let id = UUID(); runID = id
        let workspace = FileManager.default.temporaryDirectory.appendingPathComponent("LearnAlert-Anki-\(id.uuidString)", isDirectory: true)
        self.workspace = workspace; filename = url.lastPathComponent
        package = nil; error = nil; result = nil; phase = .converting
        deckNames = [:]; renamedDecks = []; hasConfirmedDeckNames = false; updateExisting = false
        startedAt = Date(); stageStartedAt = startedAt; archiveBytes = nil; recentSamples = []
        completedFiles = nil; totalFiles = nil
        progress = .init(0, "Opening your deck", filename)
        let scoped = url.startAccessingSecurityScopedResource()
        let relay = AnkiImportProgressRelay { [weak self] value in
            guard let self, self.runID == id, self.phase == .converting else { return }
            self.recordProgress(value)
        }
        let worker = Task.detached(priority: .userInitiated) {
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            return try AnkiPackageReader.read(url: url, workspace: workspace) { relay.send($0) }
        }
        self.worker = worker
        operation = Task { [weak self] in
            do {
                let package = try await worker.value
                guard let self, self.runID == id, !Task.isCancelled else { Self.removeWorkspace(workspace); return }
                self.package = package
                self.completedFiles = package.mediaCount
                self.totalFiles = package.mediaCount + 1
                self.worker = nil
                self.selectedDecks = Set(package.decks.map(\.id))
                self.deckNames = Dictionary(uniqueKeysWithValues: package.decks.map {
                    ($0.id, Self.suggestedDeckName($0.name, fallback: url.deletingPathExtension().lastPathComponent))
                })
                self.phase = .review
            } catch {
                Self.removeWorkspace(workspace)
                guard let self, self.runID == id, !Task.isCancelled else { return }
                self.error = error.localizedDescription; self.phase = .failed
            }
        }
    }

    /// Anki's hierarchy is useful inside Anki, but its leaf is the useful library title here.
    nonisolated static func suggestedDeckName(_ name: String, fallback: String = "Imported deck") -> String {
        let leaf = name.components(separatedBy: "::")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .last(where: { !$0.isEmpty }) ?? fallback
        let spaced = leaf.replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "(?<=[0-9])(?=[A-Za-z])", with: " ", options: .regularExpression)
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return spaced.isEmpty ? "Imported deck" : spaced
    }

    func setDeckName(_ name: String, for deckID: String) {
        guard deckNames[deckID] != name else { return }
        deckNames[deckID] = name
        renamedDecks.insert(deckID)
        hasConfirmedDeckNames = false
    }

    func confirmDeckNames() {
        guard canConfirmDeckNames else { return }
        for id in selectedDecks { deckNames[id] = deckNames[id]?.trimmingCharacters(in: .whitespacesAndNewlines) }
        hasConfirmedDeckNames = true
    }

    func save(container: ModelContainer) {
        guard let package, !selectedDecks.isEmpty, phase == .review,
              hasConfirmedDeckNames, canConfirmDeckNames else { return }
        pendingSave = SaveRequest(package: package, container: container, selection: selectedDecks,
                                  update: updateExisting, filename: filename, deckNames: deckNames, renamedDecks: renamedDecks)
        phase = .saving; startedAt = Date(); stageStartedAt = startedAt; recentSamples = []
        // Each extracted media file is prepared once. Keep the collection file
        // outstanding throughout card conversion and the atomic library commit.
        completedFiles = package.mediaCount; totalFiles = package.mediaCount + 1
        progress = .init(0.01, "Making room for your cards", "Preparing your library")
        // The view acknowledges appearance before any large SwiftData work starts.
    }

    func savingViewDidAppear() {
        guard phase == .saving, let request = pendingSave else { return }
        pendingSave = nil
        let id = runID, workspace = workspace, container = request.container
        let relay = AnkiImportProgressRelay { [weak self] value in
            guard let self, self.runID == id, self.phase == .saving else { return }
            self.recordProgress(value)
        }
        // Starting from a detached task also constructs the model actor's context
        // off the UI actor. One atomic commit retains rollback and re-import safety.
        let savingWorker = Task.detached(priority: .userInitiated) {
            try await Task.sleep(for: .milliseconds(40)) // Let the saving surface draw its first frame.
            try Task.checkCancellation()
            let committer = AnkiLibraryImporter(modelContainer: request.container)
            return try await committer.save(request.package, selectedDecks: request.selection,
                updateExisting: request.update, filename: request.filename, deckNames: request.deckNames,
                renamedDecks: request.renamedDecks, consumeMedia: true) { relay.send($0) }
        }
        self.savingWorker = savingWorker
        operation = Task { [weak self] in
            do {
                let result = try await savingWorker.value
                guard let self, self.runID == id, !Task.isCancelled else { Self.removeWorkspace(workspace); return }
                self.recordProgress(.init(0.995, "Updating your library", "Your cards are saved. Refreshing the library…"))
                await Task.yield()
                // Keep the saving surface up while SwiftData delivers its changes.
                container.mainContext.processPendingChanges()
                try await Task.sleep(for: .milliseconds(40)) // Allow the library's query update to draw under the saving surface.
                guard self.runID == id, !Task.isCancelled else { Self.removeWorkspace(workspace); return }
                self.workspace = nil; self.savingWorker = nil; self.result = result
                self.releasePackage()
                Self.removeWorkspace(workspace)
                let total = request.package.mediaCount + 1
                self.recordProgress(.init(1, "Your deck is ready", completedFiles: total, totalFiles: total))
                self.phase = .complete
            } catch {
                guard let self, self.runID == id, !Task.isCancelled else { return }
                self.savingWorker = nil
                self.error = error.localizedDescription; self.phase = .review
            }
        }
    }

    private func recordProgress(_ value: AnkiImportProgress) {
        guard value.fraction >= progress.fraction else { return }
        let now = Date()
        if value.title != progress.title {
            stageStartedAt = now
            recentSamples = [.init(date: now, items: 0, bytes: 0)]
        }
        if let bytes = value.archiveBytes { archiveBytes = bytes }
        if let total = value.totalFiles, total > 0 {
            totalFiles = total
            if let completed = value.completedFiles { completedFiles = min(total, max(0, completed)) }
        }
        if value.completedItems != nil || value.processedBytes != nil {
            recentSamples.append(.init(date: now, items: value.completedItems, bytes: value.processedBytes))
            recentSamples = Array(recentSamples.filter { now.timeIntervalSince($0.date) <= 4 }.suffix(40))
        }
        progress = value
    }

    private func releasePackage() {
        let disposal = AnkiImportPackageDisposal(package)
        package = nil
        // Releasing a very large array of HTML cards can itself be expensive.
        Task.detached(priority: .utility) { disposal.release() }
    }

    private nonisolated static func removeWorkspace(_ workspace: URL?) {
        guard let workspace else { return }
        Task.detached(priority: .utility) { try? FileManager.default.removeItem(at: workspace) }
    }

    func cancel() {
        runID = UUID()
        worker?.cancel(); savingWorker?.cancel(); operation?.cancel()
        pendingSave = nil
        if let workspace {
            let worker = worker, savingWorker = savingWorker
            Task.detached(priority: .utility) {
                _ = try? await worker?.value
                _ = try? await savingWorker?.value
                try? FileManager.default.removeItem(at: workspace)
            }
        }
        worker = nil; savingWorker = nil; operation = nil; workspace = nil
        releasePackage()
    }
}

/// Coalescing avoids thousands of queued UI tasks during large conversions/inserts.
private nonisolated final class AnkiImportProgressRelay: @unchecked Sendable {
    private let lock = NSLock()
    private var latest: AnkiImportProgress?
    private var scheduled = false
    private let receive: @MainActor @Sendable (AnkiImportProgress) -> Void
    init(_ receive: @escaping @MainActor @Sendable (AnkiImportProgress) -> Void) { self.receive = receive }
    func send(_ progress: AnkiImportProgress) {
        lock.lock(); latest = progress
        guard !scheduled else { lock.unlock(); return }
        scheduled = true; lock.unlock()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            if let progress = self.take() { self.receive(progress) }
        }
    }
    private func take() -> AnkiImportProgress? {
        lock.lock(); defer { lock.unlock() }
        scheduled = false; defer { latest = nil }; return latest
    }
}

private nonisolated final class AnkiImportPackageDisposal: @unchecked Sendable {
    private var package: AnkiImportPackage?
    init(_ package: AnkiImportPackage?) { self.package = package }
    func release() { package = nil }
}

struct AnkiImportResult: Sendable { let added: Int; let updated: Int; let unchanged: Int; let decks: Int }

@ModelActor
actor AnkiLibraryImporter {
    private nonisolated struct StoredMedia: Decodable { let mediaFolder: String }

    func save(_ package: AnkiImportPackage, selectedDecks: Set<String>, updateExisting: Bool, filename: String,
              deckNames: [String: String] = [:], renamedDecks: Set<String> = [],
              consumeMedia: Bool = false, progress: @Sendable (AnkiImportProgress) -> Void) throws -> AnkiImportResult {
        modelContext.autosaveEnabled = false
        try Task.checkCancellation()
        progress(.init(0.02, "Checking your library", "Matching previously imported cards"))
        let library = try modelContext.fetch(FetchDescriptor<Deck>())
        let candidates = Dictionary(grouping: library.filter { $0.sourceAnkiDeckID != nil }, by: { $0.sourceAnkiDeckID! })
        let cardIndices = package.cards.indices.filter { selectedDecks.contains(package.cards[$0].deckID) }
        var incomingIDs: [String: Set<String>] = [:]
        for index in cardIndices { incomingIDs[package.cards[index].deckID, default: []].insert(package.cards[index].id) }
        var decks: [String: Deck] = [:], existing: [String: [String: Flashcard]] = [:], deckCards: [String: [Flashcard]] = [:]
        var snapshots: [UUID: [Flashcard]] = [:]
        var changes: [Int] = [], unchanged = 0, renamedExistingDeck = false
        let mediaFolder = UUID().uuidString
        let destination = AnkiCardContent.mediaRoot.appendingPathComponent(mediaFolder, isDirectory: true)
        var saved = false, movedMedia = false, stagedMedia = false
        defer {
            if !saved {
                modelContext.rollback()
                if movedMedia { try? FileManager.default.moveItem(at: destination, to: package.mediaDirectory) }
                else if stagedMedia { try? FileManager.default.removeItem(at: destination) }
            }
        }
        for source in package.decks where selectedDecks.contains(source.id) {
            try Task.checkCancellation()
            let ids = incomingIDs[source.id] ?? []
            // The default Anki deck ID is reused across unrelated collections.
            // Card GUID/template overlap establishes that this is a re-import.
            var matched: Deck?, bestOverlap = 0
            for candidate in candidates[source.id] ?? [] {
                let cards = snapshots[candidate.id] ?? candidate.cards
                snapshots[candidate.id] = cards
                let overlap = cards.reduce(0) { $0 + ($1.sourceAnkiCardID.map { ids.contains($0) } == true ? 1 : 0) }
                if overlap > bestOverlap { matched = candidate; bestOverlap = overlap }
            }
            let deck: Deck
            let requestedName = deckNames[source.id]?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let matched {
                deck = matched
                // Suggested source names must not overwrite a learner's saved title on re-import.
                if renamedDecks.contains(source.id), let requestedName, !requestedName.isEmpty,
                   deck.name != requestedName {
                    deck.name = requestedName
                    renamedExistingDeck = true
                }
            }
            else {
                let name = requestedName.flatMap { $0.isEmpty ? nil : $0 }
                    ?? AnkiImportSession.suggestedDeckName(source.name)
                deck = Deck(name: name, colorHex: "#A9D7F5", deckType: "Anki", orderIndex: library.count + decks.count)
                deck.sourceAnkiDeckID = source.id; deck.sourceKind = "anki"; deck.sourceName = filename
                modelContext.insert(deck)
            }
            decks[source.id] = deck
            let cards = snapshots[deck.id] ?? []
            existing[source.id] = Dictionary(cards.compactMap { card in card.sourceAnkiCardID.map { ($0, card) } }, uniquingKeysWith: { first, _ in first })
            deckCards[source.id] = cards
        }
        for index in cardIndices {
            let source = package.cards[index]
            if existing[source.deckID]?[source.id] != nil && !updateExisting { unchanged += 1 }
            else { changes.append(index) }
        }
        // A duplicate import does not enumerate, copy or move any media at all.
        guard !changes.isEmpty else {
            if renamedExistingDeck { try modelContext.save(); saved = true }
            else { modelContext.rollback() }
            progress(.init(0.99, "Already in your library", "\(unchanged.formatted()) cards kept as they are"))
            return AnkiImportResult(added: 0, updated: 0, unchanged: unchanged, decks: decks.count)
        }
        try Task.checkCancellation()
        progress(.init(0.06, "Saving images & audio", completedItems: 0, totalItems: package.mediaCount, unit: "files", processedBytes: 0))
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        if consumeMedia {
            do {
                // Session workspaces are owned exclusively by this import. A same-volume
                // directory move adopts every image/audio file without another full copy.
                try FileManager.default.moveItem(at: package.mediaDirectory, to: destination)
                movedMedia = true; stagedMedia = true
            } catch {
                try Task.checkCancellation()
                // Cross-volume/file-provider storage retains the safe, measured copy path.
            }
        }
        if !stagedMedia {
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            stagedMedia = true
            let files = try FileManager.default.contentsOfDirectory(at: package.mediaDirectory, includingPropertiesForKeys: [.fileSizeKey])
            var copiedBytes = 0, lastReport = Date.distantPast
            for (index, file) in files.enumerated() {
                try Task.checkCancellation()
                try FileManager.default.copyItem(at: file, to: destination.appendingPathComponent(file.lastPathComponent))
                copiedBytes += (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                let now = Date()
                if now.timeIntervalSince(lastReport) >= 0.1 || index + 1 == files.count {
                    lastReport = now
                    progress(.init(0.06 + 0.3 * Double(index + 1) / Double(max(1, files.count)), "Saving images & audio", "\(index + 1) of \(files.count)", completedItems: index + 1, totalItems: files.count, unit: "files", processedBytes: copiedBytes))
                }
            }
        }
        if movedMedia {
            // A directory rename did not transfer these bytes; do not invent a B/s rate.
            progress(.init(0.37, "Images & audio ready", "\(package.mediaCount.formatted()) media files ready"))
        } else {
            progress(.init(0.37, "Saving images & audio", "\(package.mediaCount.formatted()) media files ready"))
        }
        progress(.init(0.4, "Adding your cards", completedItems: 0, totalItems: changes.count, unit: "cards"))
        var added = 0, updated = 0, replacedMediaFolders = Set<String>(), lastReport = Date.distantPast
        let encoder = JSONEncoder(), decoder = JSONDecoder()
        for (position, index) in changes.enumerated() {
            try Task.checkCancellation()
            let source = package.cards[index]
            guard decks[source.deckID] != nil else { continue }
            let question = String((source.plainFront.isEmpty ? "Image / audio card" : source.plainFront).prefix(8_000))
            let answer = String(source.plainBack.prefix(8_000))
            let content = AnkiCardContent(frontHTML: source.front, backHTML: source.back, css: source.css,
                mediaFolder: mediaFolder, templateOrdinal: source.templateOrdinal, noteType: source.noteType, tags: source.tags)
            let contentData = try encoder.encode(content)
            if let found = existing[source.deckID]?[source.id] {
                if let data = found.ankiContentData, let folder = try? decoder.decode(StoredMedia.self, from: data).mediaFolder { replacedMediaFolders.insert(folder) }
                found.question = question; found.correctAnswer = answer
                found.ankiContentData = contentData; found.cardType = .anki
                updated += 1
            } else {
                // Configure before insertion, avoiding managed-change tracking for
                // every property while thousands of new cards are assembled.
                let card = Flashcard(question: question, correctAnswer: answer, cardType: .anki)
                card.orderIndex = deckCards[source.deckID]?.count ?? 0
                card.sourceAnkiCardID = source.id; card.ankiContentData = contentData
                modelContext.insert(card)
                deckCards[source.deckID, default: []].append(card)
                existing[source.deckID, default: [:]][source.id] = card
                added += 1
            }
            let now = Date()
            if now.timeIntervalSince(lastReport) >= 0.1 || position + 1 == changes.count {
                lastReport = now
                progress(.init(0.4 + 0.53 * Double(position + 1) / Double(changes.count), "Adding your cards", "\(position + 1) of \(changes.count)", completedItems: position + 1, totalItems: changes.count, unit: "cards"))
            }
        }
        progress(.init(0.945, "Organizing your decks", "Linking \(changes.count.formatted()) cards"))
        for (id, cards) in deckCards { decks[id]?.cards = cards }
        try Task.checkCancellation()
        progress(.init(0.97, "Saving your library", "Writing cards safely. Larger decks may take a moment."))
        try modelContext.save()
        saved = true
        if !replacedMediaFolders.isEmpty {
            let container = modelContainer, folders = replacedMediaFolders
            Task.detached(priority: .utility) {
                let cleanup = AnkiLibraryImporter(modelContainer: container)
                await cleanup.removeUnreferencedMedia(folders)
            }
        }
        progress(.init(0.99, "Cards saved", "Refreshing your library"))
        return AnkiImportResult(added: added, updated: updated, unchanged: unchanged, decks: decks.count)
    }

    private func removeUnreferencedMedia(_ candidates: Set<String>) {
        guard let cards = try? modelContext.fetch(FetchDescriptor<Flashcard>()) else { return }
        let decoder = JSONDecoder()
        var unused = candidates
        for card in cards {
            if let data = card.ankiContentData,
               let folder = try? decoder.decode(StoredMedia.self, from: data).mediaFolder {
                unused.remove(folder)
                if unused.isEmpty { return }
            }
        }
        for folder in unused where UUID(uuidString: folder) != nil {
            try? FileManager.default.removeItem(at: AnkiCardContent.mediaRoot.appendingPathComponent(folder))
        }
    }
}

struct AnkiImportRateSample: Sendable {
    let date: Date
    let items: Int?
    let bytes: Int?
}

/// Stage averages and a recent measured window are distinct; local work is not network transfer.
struct AnkiImportTelemetry {
    let progress: AnkiImportProgress
    let elapsed: TimeInterval
    let stageElapsed: TimeInterval
    private let now: Date
    private let samples: [AnkiImportRateSample]
    init(progress: AnkiImportProgress, startedAt: Date, stageStartedAt: Date, now: Date,
         samples: [AnkiImportRateSample] = []) {
        self.progress = progress; self.now = now; self.samples = samples
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
    private func currentRate(_ value: (AnkiImportRateSample) -> Int?) -> Double? {
        guard let last = samples.last, now.timeIntervalSince(last.date) <= 1.5,
              let lastValue = value(last),
              let first = samples.first(where: { last.date.timeIntervalSince($0.date) >= 0.25 && value($0) != nil }),
              let firstValue = value(first) else { return nil }
        let duration = last.date.timeIntervalSince(first.date)
        guard duration > 0, lastValue >= firstValue else { return nil }
        return Double(lastValue - firstValue) / duration
    }
    var currentUnitsPerSecond: Double? { currentRate(\.items) }
    var currentBytesPerSecond: Double? { currentRate(\.bytes) }
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
