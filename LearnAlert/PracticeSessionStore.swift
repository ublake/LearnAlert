import Foundation
import Combine

/// A practice checkpoint contains no notification learning mutations. Large HTML
/// and media remain on their cards; checkpoints retain only identities and answers.
nonisolated struct PracticeSessionSnapshot: Codable, Identifiable, Sendable {
    var id = UUID()
    let deckID: UUID
    let createdAt: Date
    var updatedAt: Date
    var originalCardIDs: [UUID]
    var queueIDs: [UUID]
    var cardIndex = 0
    var reviewedCardIDs: Set<UUID> = []
    var answerCount = 0
    var correctCount = 0
    var selectedAnswer: String?
    var typedAnswer = ""
    var isRevealed = false
    var hasViewedImageBack = false
    var isGraded = false
    var showingHint = false
    var hasRecordedHint = false
    var waitingForReview = false
    var isComplete = false
    var localAnkiStates: [UUID: Data] = [:]
    var pendingAnkiReviews: [UUID: Date] = [:]
    var ratingCounts: [Int: Int] = [:]
    var reviewedAnkiIDs: Set<UUID> = []

    var reviewedCount: Int { min(originalCardIDs.count, reviewedCardIDs.count) }
    var totalCount: Int { originalCardIDs.count }
}

private nonisolated struct PracticeSessionGeneration: Sendable {
    let all: Int
    let deck: Int
}

/// JSON preparation and atomic writes stay off the UI actor, even for large decks.
private actor PracticeSessionArchiveIO {
    static let shared = PracticeSessionArchiveIO()
    private let directory: URL
    private var cache: [UUID: [PracticeSessionSnapshot]] = [:]
    private var recentDecks: [UUID] = []
    private var allGeneration = 0
    private var deckGenerations: [UUID: Int] = [:]

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        directory = base.appendingPathComponent("LearnAlert/PracticeSessions", isDirectory: true)
    }

    private func url(_ id: UUID) -> URL { directory.appendingPathComponent(id.uuidString + ".json") }

    func load(deckID: UUID) throws -> [PracticeSessionSnapshot] {
        if let saved = cache[deckID] { return saved }
        let file = url(deckID)
        let values: [PracticeSessionSnapshot]
        if FileManager.default.fileExists(atPath: file.path) {
            values = try JSONDecoder().decode([PracticeSessionSnapshot].self, from: Data(contentsOf: file, options: .mappedIfSafe))
        } else { values = [] }
        let valid = Array(values.filter { $0.deckID == deckID }.sorted { $0.updatedAt > $1.updatedAt }.prefix(3))
        retain(valid, for: deckID)
        return valid
    }

    func save(_ snapshot: PracticeSessionSnapshot, generation: PracticeSessionGeneration) throws {
        guard generation.all == allGeneration, generation.deck == deckGenerations[snapshot.deckID, default: 0] else { return }
        var values = try load(deckID: snapshot.deckID)
        if let newer = values.first(where: { $0.id == snapshot.id }), newer.updatedAt > snapshot.updatedAt { return }
        values.removeAll { $0.id == snapshot.id }
        values.insert(snapshot, at: 0)
        values = Array(values.sorted { $0.updatedAt > $1.updatedAt }.prefix(3))
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(values).write(to: url(snapshot.deckID), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        retain(values, for: snapshot.deckID)
    }

    func removeAll(generation: Int) throws {
        allGeneration = generation
        cache.removeAll(); recentDecks.removeAll(); deckGenerations.removeAll()
        if FileManager.default.fileExists(atPath: directory.path) { try FileManager.default.removeItem(at: directory) }
    }

    func removeSessions(deckID: UUID, generation: Int) throws {
        deckGenerations[deckID] = generation
        cache.removeValue(forKey: deckID); recentDecks.removeAll { $0 == deckID }
        let file = url(deckID)
        if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
    }

    private func retain(_ values: [PracticeSessionSnapshot], for deckID: UUID) {
        cache[deckID] = values
        recentDecks.removeAll { $0 == deckID }; recentDecks.append(deckID)
        while recentDecks.count > 2 { cache.removeValue(forKey: recentDecks.removeFirst()) }
    }
}

@MainActor
final class PracticeSessionStore: ObservableObject {
    static let shared = PracticeSessionStore()
    @Published private(set) var sessions: [PracticeSessionSnapshot] = []
    @Published private(set) var errorMessage: String?
    private var pendingSave: Task<Void, Never>?
    private var loadedGeneration: PracticeSessionGeneration?
    private var loadedDeckID: UUID?
    private static var allGeneration = 0
    private static var deckGenerations: [UUID: Int] = [:]

    func load(deckID: UUID) async -> Bool {
        do {
            let generation = PracticeSessionGeneration(all: Self.allGeneration, deck: Self.deckGenerations[deckID, default: 0])
            let values = try await PracticeSessionArchiveIO.shared.load(deckID: deckID)
            guard generation.all == Self.allGeneration, generation.deck == Self.deckGenerations[deckID, default: 0] else {
                return await load(deckID: deckID)
            }
            sessions = values
            loadedDeckID = deckID
            loadedGeneration = generation
            errorMessage = nil
            return true
        } catch {
            errorMessage = "Saved practice sessions couldn’t be opened. Please try again."
            return false
        }
    }

    func save(_ snapshot: PracticeSessionSnapshot, immediately: Bool = false) {
        guard loadedDeckID == snapshot.deckID, let generation = loadedGeneration,
              generation.all == Self.allGeneration,
              generation.deck == Self.deckGenerations[snapshot.deckID, default: 0] else { return }
        errorMessage = nil
        sessions.removeAll { $0.id == snapshot.id }
        sessions.insert(snapshot, at: 0)
        sessions = Array(sessions.sorted { $0.updatedAt > $1.updatedAt }.prefix(3))
        pendingSave?.cancel()
        pendingSave = Task { [weak self] in
            do {
                if !immediately { try await Task.sleep(for: .milliseconds(120)) }
                try Task.checkCancellation()
                try await PracticeSessionArchiveIO.shared.save(snapshot, generation: generation)
            } catch is CancellationError { }
            catch { self?.errorMessage = "Practice progress couldn’t be saved. Keep this session open and try again." }
        }
    }

    /// Older app versions kept Anki state only in their three bookmarks. Prefer
    /// the most recently rated state, not whichever bookmark was opened last.
    func legacyAnkiStates() -> [UUID: Data] {
        var newest: [UUID: (data: Data, state: AnkiReviewState)] = [:]
        for session in sessions {
            for (id, data) in session.localAnkiStates {
                guard let state = try? JSONDecoder().decode(AnkiReviewState.self, from: data),
                      state.reviewCount > 0 else { continue }
                if let prior = newest[id] {
                    let date = state.lastReviewedDate ?? .distantPast
                    let priorDate = prior.state.lastReviewedDate ?? .distantPast
                    guard date > priorDate || (date == priorDate && state.reviewCount > prior.state.reviewCount) else { continue }
                }
                newest[id] = (data, state)
            }
        }
        return newest.mapValues(\.data)
    }

    func removeAll() async {
        Self.allGeneration += 1
        Self.deckGenerations.removeAll()
        loadedGeneration = nil; loadedDeckID = nil
        pendingSave?.cancel(); sessions.removeAll()
        do { try await PracticeSessionArchiveIO.shared.removeAll(generation: Self.allGeneration) }
        catch { errorMessage = "Saved practice sessions couldn’t be removed. Please try again." }
    }

    func removeSessions(deckID: UUID) async {
        Self.deckGenerations[deckID, default: 0] += 1
        pendingSave?.cancel(); sessions.removeAll { $0.deckID == deckID }
        do { try await PracticeSessionArchiveIO.shared.removeSessions(deckID: deckID, generation: Self.deckGenerations[deckID, default: 0]) }
        catch { errorMessage = "Saved practice sessions couldn’t be removed. Please try again." }
    }
}
