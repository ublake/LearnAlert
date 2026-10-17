import Foundation
import Testing
import UserNotifications
@testable import LearnAlert

@Suite("Alert trail")
struct AlertTimelineTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private func store() throws -> (AlertTimelineStore, URL) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (AlertTimelineStore(directory: directory), directory)
    }
    @Test("A past scheduled time is not delivery evidence; only confirmed delivery becomes unanswered")
    func evidenceAndStatus() throws {
        let (journal, directory) = try store(); defer { try? FileManager.default.removeItem(at: directory) }
        let date = now.addingTimeInterval(-1800)
        journal.scheduled(id: "a", deckID: "deck", date: date, now: now)
        #expect(journal.entries(deckID: "deck", now: now).first?.status(at: now) == .elapsed)
        journal.delivered(id: "a", deckID: "deck", date: now, now: now)
        let row = try #require(journal.entries(deckID: "deck", now: now).first)
        #expect(row.status(at: now) == .delivered)
        #expect(row.status(at: now.addingTimeInterval(901)) == .unanswered)
        journal.opened("a", now: now)
        #expect(journal.entries(deckID: "deck", now: now).first?.status(at: now.addingTimeInterval(901)) == .opened)
        journal.answered("a", now: now)
        journal.dismissed("a", now: now)
        journal.delivered(id: "a", deckID: "deck", date: now, now: now)
        #expect(journal.entries(deckID: "deck", now: now).first?.status(at: now) == .answered)
    }
    @Test("Responses survive new store instances and future scheduling reconciliation")
    func persistenceAndCancellation() throws {
        let (journal, directory) = try store(); defer { try? FileManager.default.removeItem(at: directory) }
        journal.scheduled(id: "past", deckID: "deck", date: now.addingTimeInterval(-10), now: now)
        journal.answered("past", now: now)
        journal.scheduled(id: "future", deckID: "deck", date: now.addingTimeInterval(60), now: now)
        journal.scheduled(id: "other", deckID: "other", date: now.addingTimeInterval(-10), now: now)
        journal.cancelFuture(now: now)
        let reopened = AlertTimelineStore(directory: directory)
        let rows = reopened.entries(deckID: "deck", now: now)
        #expect(rows.count == 1 && rows[0].id == "past" && rows[0].status(at: now) == .answered)
        #expect(reopened.entries(deckID: "other", now: now).count == 1)
        journal.answered("missing", now: now)
        #expect(reopened.entries(deckID: "deck", now: now).count == 1)
    }
    @Test("Concurrent app/extension-style updates never erase an answered alert")
    func concurrentUpdates() async throws {
        let (journal, directory) = try store(); defer { try? FileManager.default.removeItem(at: directory) }
        let other = AlertTimelineStore(directory: directory)
        journal.scheduled(id: "first", deckID: "deck", date: now, now: now)
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<20 {
                let date = now
                group.addTask {
                    if i.isMultiple(of: 2) { journal.answered("first", now: date) }
                    else { other.delivered(id: "first", deckID: "deck", date: date, now: date) }
                    other.scheduled(id: "event-\(i)", deckID: "deck", date: date.addingTimeInterval(Double(i)), now: date)
                }
            }
        }
        let rows = journal.entries(deckID: "deck", now: now)
        #expect(rows.count == 21)
        #expect(rows.first { $0.id == "first" }?.status(at: now) == .answered)
    }
    @Test("The track keeps the next alert, recent history, and a bounded number of dots")
    func samplesAndRetention() throws {
        let entries = (-20...30).map { i in AlertTimelineEntry(id: "\(i)", deckID: "deck", date: now.addingTimeInterval(Double(i) * 60)) }
        let samples = AlertTimelineEntry.samples(entries, now: now)
        #expect(samples.count == 14)
        #expect(samples.contains { $0.id == "1" })
        #expect(samples.filter { $0.date <= now }.count == 6)
        #expect(AlertTimelineEntry.samples(entries, now: now, limit: 0).isEmpty)
        let (journal, directory) = try store(); defer { try? FileManager.default.removeItem(at: directory) }
        journal.scheduled(id: "old", deckID: "deck", date: now.addingTimeInterval(-8 * 86_400), now: now)
        #expect(journal.entries(deckID: "deck", now: now).isEmpty)
    }
    @Test("Synthetic tutorials and customization previews do not become real alert history")
    func excludesPreviews() {
        let content = UNMutableNotificationContent()
        content.categoryIdentifier = "FLASHCARD_TEST"
        #expect(!AlertTimelineStore.isStudy(content))
        content.categoryIdentifier = "FLASHCARD_REVEAL"
        content.userInfo = ["isTutorial": true]
        #expect(!AlertTimelineStore.isStudy(content))
        content.userInfo = ["isCustomizationTest": true]
        #expect(!AlertTimelineStore.isStudy(content))
        content.userInfo = ["deckId": "deck"]
        #expect(AlertTimelineStore.isStudy(content))
    }
}
