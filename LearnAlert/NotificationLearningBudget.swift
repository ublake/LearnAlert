import Foundation
import UserNotifications
import Darwin
import SwiftData

nonisolated struct NotificationLearningDaySnapshot: Equatable, Sendable {
    let completedCount: Int
    var remainingQuestions: Int { max(0, 20 - completedCount) }
    var isComplete: Bool { remainingQuestions == 0 }
}

/// A device-wide journal shared by the app and notification extension. Reservations
/// survive rescheduling, including alerts delivered while neither process is running.
@MainActor
enum NotificationLearningBudget {
    static let goal = 20
    static let hardNotificationLimit = 30
    static let minimumSpacingMinutes = 60

    private struct Reservation: Codable, Equatable {
        let id: String
        var date: Date
        var deliveredAt: Date?
        var spacingMinutes = 60
        var reservedAt = Date()
    }
    private struct Event: Codable, Equatable {
        var ordinal: Int
        let cardID: String
        let date: Date
        let answered: Bool
        var committed = false
        var previousReviewCount: Int? = nil
    }
    private struct Batch: Codable, Equatable {
        let id: String
        let createdAt: Date
        let limit: Int
        var events: [Event] = []
    }
    private struct Journal: Codable, Equatable {
        var reservations: [Reservation] = []
        var batches: [Batch] = []
        var dailyNotificationLimit = 20
        var revision = 0
        mutating func prune(now: Date) {
            let cutoff = Calendar.current.date(byAdding: .day, value: -14, to: now) ?? now.addingTimeInterval(-14 * 86_400)
            reservations.removeAll { $0.date < cutoff }
            batches.removeAll { ($0.events.last?.date ?? $0.createdAt) < cutoff }
        }
    }
    private static var directory: URL {
        (FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.learnalert.shared")
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0])
            .appendingPathComponent("NotificationLearning", isDirectory: true)
    }

    private static func sameDay(_ lhs: Date, _ rhs: Date) -> Bool { Calendar.current.isDate(lhs, inSameDayAs: rhs) }
    private static func completed(in journal: Journal, on day: Date) -> Int {
        journal.batches.reduce(0) { count, batch in
            count + batch.events.filter { $0.answered && sameDay($0.date, day) }.count
        }
    }

    static func today(now: Date = Date()) -> NotificationLearningDaySnapshot {
        recoverInterruptedAnswers(now: now)
        // A corrupt/unavailable journal pauses learning rather than resetting its budget.
        return .init(completedCount: (try? transaction { completed(in: $0, on: now) }) ?? goal)
    }
    static func remainingQuestions(on date: Date) -> Int {
        max(0, goal - ((try? transaction { completed(in: $0, on: date) }) ?? goal))
    }

    static func batchLimit(for requestID: String?, requested: Int = 3, now: Date = Date()) -> Int {
        guard let id = requestID, !id.isEmpty else { return 0 }
        return (try? transaction(write: true, now: now) { journal in
            if let batch = journal.batches.first(where: { $0.id == id }) { return batch.limit }
            let limit = min(3, max(1, requested), max(0, goal - completed(in: journal, on: now)))
            journal.batches.append(.init(id: id, createdAt: now, limit: limit))
            return limit
        }) ?? 0
    }
    static func batchCompleted(for requestID: String?, now: Date = Date()) -> Int {
        (try? transaction { journal in journal.batches.first { $0.id == requestID }?.events.filter(\.answered).count ?? 0 }) ?? 0
    }
    static func batchConsumed(for requestID: String?, now: Date = Date()) -> Int {
        (try? transaction { $0.batches.first { $0.id == requestID }?.events.count ?? 0 }) ?? 3
    }
    static func answeredCardIDs(for requestID: String?, now: Date = Date()) -> Set<String> {
        (try? transaction { journal in Set(journal.batches.first { $0.id == requestID }?.events.filter(\.answered).map(\.cardID) ?? []) }) ?? []
    }
    static func handledCardIDs(for requestID: String?, now: Date = Date()) -> Set<String> {
        (try? transaction { journal in Set(journal.batches.first { $0.id == requestID }?.events.map(\.cardID) ?? []) }) ?? []
    }
    static func canAnswer(requestID: String?, batchLimit: Int, now: Date = Date()) -> Bool {
        guard let id = requestID, !id.isEmpty else { return false }
        return (try? transaction { journal in
            guard completed(in: journal, on: now) < goal,
                  let batch = journal.batches.first(where: { $0.id == id }) else { return false }
            return batch.events.count < min(batch.limit, batchLimit)
        }) ?? false
    }

    /// Reserve before the card transaction; roll back this event if its save fails.
    @discardableResult
    static func recordAnswer(requestID: String?, cardID: UUID, batchOrdinal: Int, batchLimit: Int, previousReviewCount: Int? = nil, now: Date = Date()) -> Bool {
        recordEvent(requestID: requestID, cardID: cardID, ordinal: batchOrdinal, limit: batchLimit, answered: true, previousReviewCount: previousReviewCount, now: now)
    }
    @discardableResult
    static func recordSkip(requestID: String?, cardID: UUID, batchOrdinal: Int, batchLimit: Int, now: Date = Date()) -> Bool {
        recordEvent(requestID: requestID, cardID: cardID, ordinal: batchOrdinal, limit: batchLimit, answered: false, previousReviewCount: nil, now: now)
    }
    private static func recordEvent(requestID: String?, cardID: UUID, ordinal: Int, limit: Int, answered: Bool, previousReviewCount: Int?, now: Date) -> Bool {
        guard let id = requestID, !id.isEmpty, ordinal >= 0 else { return false }
        return (try? transaction(write: true, now: now) { journal in
            guard completed(in: journal, on: now) < goal,
                  let index = journal.batches.firstIndex(where: { $0.id == id }),
                  ordinal == journal.batches[index].events.count,
                  ordinal < min(journal.batches[index].limit, limit) else { return false }
            journal.batches[index].events.append(.init(ordinal: ordinal, cardID: cardID.uuidString, date: now,
                answered: answered, committed: !answered, previousReviewCount: previousReviewCount))
            return true
        }) ?? false
    }
    @discardableResult
    static func commitAnswer(requestID: String?, batchOrdinal: Int) -> Bool {
        (try? transaction(write: true) { journal in
            guard let batch = journal.batches.firstIndex(where: { $0.id == requestID }),
                  let event = journal.batches[batch].events.firstIndex(where: { $0.ordinal == batchOrdinal && $0.answered }) else { return false }
            journal.batches[batch].events[event].committed = true
            return true
        }) ?? false
    }
    static func rollbackAnswer(requestID: String?, batchOrdinal: Int, now: Date = Date()) {
        try? transaction(write: true, now: now) { journal in
            guard let index = journal.batches.firstIndex(where: { $0.id == requestID }),
                  let event = journal.batches[index].events.firstIndex(where: { $0.ordinal == batchOrdinal && $0.answered && !$0.committed }) else { return }
            journal.batches[index].events.remove(at: event)
            for position in journal.batches[index].events.indices { journal.batches[index].events[position].ordinal = position }
        }
    }

    static func recordDelivered(requestID: String?, at date: Date = Date()) {
        guard let id = requestID, !id.isEmpty else { return }
        try? transaction(write: true) { journal in
            if let index = journal.reservations.firstIndex(where: { $0.id == id }) {
                if journal.reservations[index].deliveredAt == nil {
                    journal.reservations[index].deliveredAt = date
                    journal.reservations[index].date = date
                }
            } else { journal.reservations.append(.init(id: id, date: date, deliveredAt: date)) }
        }
    }
    static func canSchedule(at date: Date, pendingDates: [Date] = [], minimumSpacingMinutes: Int = 60) -> Bool {
        (try? transaction { permitted(date: date, id: nil, pendingDates: pendingDates, spacingMinutes: minimumSpacingMinutes, journal: $0) }) ?? false
    }
    @discardableResult
    static func reserveNotification(requestID: String, at date: Date, pendingDates: [Date] = [], minimumSpacingMinutes: Int = 60, dailyNotificationLimit: Int? = nil) -> Bool {
        (try? transaction(write: true) { journal in
            if let limit = dailyNotificationLimit { journal.dailyNotificationLimit = min(hardNotificationLimit, max(1, limit)) }
            guard permitted(date: date, id: requestID, pendingDates: pendingDates, spacingMinutes: minimumSpacingMinutes, journal: journal) else { return false }
            // Replenishment of the exact same slot does not consume a second reservation.
            if let index = journal.reservations.firstIndex(where: { $0.id == requestID }), abs(journal.reservations[index].date.timeIntervalSince(date)) < 1 {
                journal.reservations[index].spacingMinutes = max(journal.reservations[index].spacingMinutes, minimumSpacingMinutes)
                return true
            }
            journal.reservations.removeAll { $0.id == requestID }
            journal.reservations.append(.init(id: requestID, date: date, spacingMinutes: max(Self.minimumSpacingMinutes, minimumSpacingMinutes)))
            return true
        }) ?? false
    }
    static func setNotificationLimit(_ limit: Int) {
        try? transaction(write: true) { $0.dailyNotificationLimit = min(hardNotificationLimit, max(1, limit)) }
    }
    static func invalidateSchedule() {
        try? transaction(write: true) { $0.revision &+= 1 }
    }
    static func recordScheduled(requestID: String, at date: Date) { _ = reserveNotification(requestID: requestID, at: date) }
    private static func permitted(date: Date, id: String?, pendingDates: [Date], spacingMinutes: Int, journal: Journal) -> Bool {
        guard date > Date(), completed(in: journal, on: date) < goal else { return false }
        let others = journal.reservations.filter { $0.id != id }
        let dayCount = others.filter { sameDay($0.date, date) }.count
        guard dayCount < min(hardNotificationLimit, max(1, journal.dailyNotificationLimit)) else { return false }
        let minutes = max(Self.minimumSpacingMinutes, spacingMinutes)
        let spacing = TimeInterval(minutes * 60)
        guard others.allSatisfy({ abs($0.date.timeIntervalSince(date)) >= TimeInterval(max(minutes, $0.spacingMinutes) * 60) - 1 }) else { return false }
        return pendingDates.allSatisfy { abs($0.timeIntervalSince(date)) < 1 || abs($0.timeIntervalSince(date)) >= spacing - 1 }
    }
    static func cancelReservations(requestIDs: [String], now: Date = Date()) {
        let ids = Set(requestIDs)
        try? transaction(write: true, now: now) { journal in
            journal.reservations.removeAll { ids.contains($0.id) && $0.date > now && $0.deliveredAt == nil }
        }
    }

    /// Cancels today's remaining alerts on completion and repairs pre-upgrade queues.
    /// Already elapsed reservations remain, preventing a deck switch from restarting a quota.
    private static var reconciling = false
    private static var needsReconciliation = false
    static func reconcilePending() async {
        needsReconciliation = true
        guard !reconciling else { return }
        reconciling = true
        defer { reconciling = false }
        while needsReconciliation {
            needsReconciliation = false
            await reconcilePass()
        }
    }
    private static func reconcilePass() async {
        let center = UNUserNotificationCenter.current()
        let now = Date()
        recoverInterruptedAnswers(now: now)
        guard let initialRevision = try? transaction({ $0.revision }) else { return }
        let delivered = await center.deliveredNotifications()
        guard (try? transaction({ $0.revision })) == initialRevision else { needsReconciliation = true; return }
        for notification in delivered where AlertTimelineStore.isStudy(notification.request.content) {
            recordDelivered(requestID: notification.request.identifier, at: notification.date)
        }
        guard let snapshotRevision = try? transaction({ $0.revision }) else { return }
        let pending = await center.pendingNotificationRequests()
        let study = pending.filter { AlertTimelineStore.isStudy($0.content) }
        let pendingIDs = Set(study.map(\.identifier))
        let ordered = study.sorted { (triggerDate($0) ?? .distantFuture) < (triggerDate($1) ?? .distantFuture) }
        // Pre-upgrade elapsed slots also count conservatively toward today's cap.
        let elapsed = AlertTimelineStore.shared.recentStudyEntries(now: now).filter { $0.date <= now }
        let result: (remove: [String], revision: Int)?
        do { result = try transaction(write: true, now: now) { journal -> (remove: [String], revision: Int)? in
            guard journal.revision == snapshotRevision else { return nil }
            let before = journal
            let known = Set(journal.reservations.map(\.id))
            for entry in elapsed where !known.contains(entry.id) {
                journal.reservations.append(.init(id: entry.id, date: entry.deliveredAt ?? entry.date, deliveredAt: entry.deliveredAt))
            }
            journal.reservations.removeAll {
                $0.date > now && $0.deliveredAt == nil && !pendingIDs.contains($0.id) && now.timeIntervalSince($0.reservedAt) > 120
            }
            // Rebuild one snapshot while holding the file lock, so app/extension
            // rescheduling cannot leave ghost reservations from an older queue.
            journal.reservations.removeAll { pendingIDs.contains($0.id) && $0.date > now && $0.deliveredAt == nil }
            var remove: [String] = []
            for request in ordered {
                let minutes = request.content.userInfo["minimumSpacingMinutes"] as? Int ?? 60
                guard let date = triggerDate(request), request.trigger?.repeats != true,
                      permitted(date: date, id: request.identifier, pendingDates: [], spacingMinutes: minutes, journal: journal) else {
                    remove.append(request.identifier); continue
                }
                journal.reservations.append(.init(id: request.identifier, date: date, spacingMinutes: max(60, minutes)))
            }
            return (remove, before == journal ? journal.revision : journal.revision &+ 1)
        } } catch { return }
        guard let result else { needsReconciliation = true; return }
        guard (try? transaction({ $0.revision })) == result.revision else { needsReconciliation = true; return }
        if !result.remove.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: result.remove)
        }
        AlertTimelineStore.shared.reconcile(pending: await center.pendingNotificationRequests())
    }

    /// A process can be terminated between reserving its answer and saving its
    /// review. After a grace period, verify SwiftData before keeping that claim.
    private static func recoverInterruptedAnswers(now: Date) {
        let pending = (try? transaction { journal in
            journal.batches.flatMap { batch in
                batch.events.filter { $0.answered && !$0.committed && now.timeIntervalSince($0.date) >= 120 }
                    .map { (batch.id, $0) }
            }
        }) ?? []
        guard !pending.isEmpty else { return }
        let context = ModelContext(SharedDatabase.shared.container)
        for (id, event) in pending {
            guard let cardID = UUID(uuidString: event.cardID) else { continue }
            let cards: [Flashcard]
            do { cards = try context.fetch(FetchDescriptor<Flashcard>(predicate: #Predicate { $0.id == cardID })) }
            catch { continue }
            let saved = cards.first.map { card in
                guard let previous = event.previousReviewCount else { return true }
                return card.reviewCount > previous && (card.lastReviewedDate ?? .distantPast) >= event.date.addingTimeInterval(-1)
            } ?? true
            try? transaction(write: true, now: now) { journal in
                guard let batch = journal.batches.firstIndex(where: { $0.id == id }),
                      let position = journal.batches[batch].events.firstIndex(where: { $0.date == event.date && $0.cardID == event.cardID && !$0.committed }) else { return }
                if saved { journal.batches[batch].events[position].committed = true }
                else {
                    journal.batches[batch].events.remove(at: position)
                    for index in journal.batches[batch].events.indices { journal.batches[batch].events[index].ordinal = index }
                }
            }
        }
    }
    private static func triggerDate(_ request: UNNotificationRequest) -> Date? {
        (request.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate()
            ?? (request.trigger as? UNTimeIntervalNotificationTrigger)?.nextTriggerDate()
    }

    private static func transaction<T>(write: Bool = false, now: Date = Date(), _ action: (inout Journal) throws -> T) throws -> T {
        let folder = directory
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
        let descriptor = open(folder.appendingPathComponent("budget.lock").path, O_CREAT | O_RDWR, 0o600)
        guard descriptor >= 0 else { throw CocoaError(.fileWriteUnknown) }
        defer { close(descriptor) }
        guard flock(descriptor, LOCK_EX) == 0 else { throw CocoaError(.fileWriteUnknown) }
        defer { flock(descriptor, LOCK_UN) }
        let file = folder.appendingPathComponent("budget.json")
        var journal = FileManager.default.fileExists(atPath: file.path)
            ? try JSONDecoder().decode(Journal.self, from: Data(contentsOf: file)) : Journal()
        let before = journal
        journal.prune(now: now)
        let result = try action(&journal)
        if write && journal != before {
            journal.revision = before.revision &+ 1
            try JSONEncoder().encode(journal).write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        }
        return result
    }
}
