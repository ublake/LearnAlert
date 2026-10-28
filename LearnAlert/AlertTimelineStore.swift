import Foundation
import UserNotifications
import Darwin

nonisolated enum AlertTimelineStatus: String, CaseIterable, Sendable {
    case upcoming, elapsed, delivered, unanswered, opened, answered
    var title: String {
        switch self {
        case .upcoming: "Upcoming"
        case .elapsed: "Scheduled time passed"
        case .delivered: "Delivered"
        case .unanswered: "No answer yet"
        case .opened: "Opened in app"
        case .answered: "Answered"
        }
    }
}

nonisolated struct AlertTimelineEntry: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let deckID: String
    var date: Date
    var deliveredAt: Date?
    var openedAt: Date?
    var answeredAt: Date?
    var dismissedAt: Date?

    func status(at now: Date) -> AlertTimelineStatus {
        if answeredAt != nil { return .answered }
        if openedAt != nil { return .opened }
        if dismissedAt != nil { return .unanswered }
        if let deliveredAt { return now.timeIntervalSince(deliveredAt) >= 15 * 60 ? .unanswered : .delivered }
        return date > now ? .upcoming : .elapsed
    }

    static func samples(_ entries: [Self], now: Date, limit: Int = 14) -> [Self] {
        let sorted = entries.sorted { $0.date < $1.date }
        let past = sorted.filter { $0.date <= now }
        let future = sorted.filter { $0.date > now }
        let pastCount = min(past.count, max(0, limit - min(future.count, 8)))
        return Array(past.suffix(pastCount)) + Array(future.prefix(max(0, limit - pastCount)))
    }
}

/// A bounded local journal. File locking protects app/extension writes, including
/// repeated delivery reconciliation racing an answer. No delivery is inferred from time alone.
nonisolated final class AlertTimelineStore: @unchecked Sendable {
    static let shared = AlertTimelineStore(directory: (
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.learnalert.shared")
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    ).appendingPathComponent("AlertTimeline", isDirectory: true))
    private let directory: URL
    init(directory: URL) { self.directory = directory }

    func entries(deckID: String, now: Date = Date()) -> [AlertTimelineEntry] {
        (try? locked { try read().filter { $0.deckID == deckID && $0.date >= now.addingTimeInterval(-86_400) }.sorted { $0.date < $1.date } }) ?? []
    }
    func recentStudyEntries(now: Date = Date()) -> [AlertTimelineEntry] {
        (try? locked { try read().filter { $0.date >= now.addingTimeInterval(-14 * 86_400) } }) ?? []
    }
    func scheduled(id: String, deckID: String, date: Date, now: Date = Date()) {
        guard !deckID.isEmpty else { return }
        update(now: now) { rows in
            guard !rows.contains(where: { $0.id == id }) else { return }
            rows.append(.init(id: id, deckID: deckID, date: date))
        }
    }
    func scheduled(_ request: UNNotificationRequest, date: Date) {
        guard Self.isStudy(request.content), let deckID = request.content.userInfo["deckId"] as? String else { return }
        scheduled(id: request.identifier, deckID: deckID, date: date)
    }
    func delivered(_ notification: UNNotification, now: Date = Date()) {
        guard Self.isStudy(notification.request.content), let deckID = notification.request.content.userInfo["deckId"] as? String else { return }
        delivered(id: notification.request.identifier, deckID: deckID, date: notification.date, now: now)
    }
    func delivered(id: String, deckID: String, date: Date, now: Date = Date()) {
        update(now: now) { rows in
            if let index = rows.firstIndex(where: { $0.id == id }) { rows[index].deliveredAt = rows[index].deliveredAt ?? date }
            else { rows.append(.init(id: id, deckID: deckID, date: date, deliveredAt: date)) }
        }
    }
    func answered(_ id: String?, now: Date = Date()) { mark(id, now: now) { $0.answeredAt = $0.answeredAt ?? now } }
    func opened(_ id: String?, now: Date = Date()) { mark(id, now: now) { $0.openedAt = $0.openedAt ?? now } }
    func dismissed(_ id: String?, now: Date = Date()) { mark(id, now: now) { $0.dismissedAt = $0.dismissedAt ?? now } }
    private func mark(_ id: String?, now: Date, change: (inout AlertTimelineEntry) -> Void) {
        guard let id else { return }
        update(now: now) { rows in if let index = rows.firstIndex(where: { $0.id == id }) { change(&rows[index]) } }
    }
    func cancelFuture(now: Date = Date()) { reconcile(pending: [], now: now) }
    func reconcile(pending: [UNNotificationRequest], now: Date = Date()) {
        let ids = Set(pending.map(\.identifier))
        update(now: now) { rows in
            rows.removeAll { $0.date > now && $0.deliveredAt == nil && $0.answeredAt == nil && $0.openedAt == nil && !ids.contains($0.id) }
            for request in pending where Self.isStudy(request.content) {
                guard let deckID = request.content.userInfo["deckId"] as? String,
                      let date = Self.triggerDate(request.trigger), !rows.contains(where: { $0.id == request.identifier }) else { continue }
                rows.append(.init(id: request.identifier, deckID: deckID, date: date))
            }
        }
    }
    private static func triggerDate(_ trigger: UNNotificationTrigger?) -> Date? {
        if let trigger = trigger as? UNCalendarNotificationTrigger { return trigger.nextTriggerDate() }
        if let trigger = trigger as? UNTimeIntervalNotificationTrigger { return trigger.nextTriggerDate() }
        return nil
    }
    static func isStudy(_ content: UNNotificationContent) -> Bool {
        content.categoryIdentifier == "FLASHCARD_REVEAL" && content.userInfo["isTutorial"] as? Bool != true && content.userInfo["isCustomizationTest"] as? Bool != true
    }
    private func read() throws -> [AlertTimelineEntry] {
        let file = directory.appendingPathComponent("events.json")
        guard FileManager.default.fileExists(atPath: file.path) else { return [] }
        return try JSONDecoder().decode([AlertTimelineEntry].self, from: Data(contentsOf: file))
    }
    private func update(now: Date, change: (inout [AlertTimelineEntry]) -> Void) {
        try? locked {
            let before = try read()
            var rows = before
            change(&rows)
            rows = Array(rows.filter { $0.date >= now.addingTimeInterval(-7 * 86_400) }.sorted { $0.date < $1.date }.suffix(500))
            guard rows != before else { return }
            try JSONEncoder().encode(rows).write(to: directory.appendingPathComponent("events.json"), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        }
    }
    private func locked<T>(_ action: () throws -> T) throws -> T {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
        let descriptor = open(directory.appendingPathComponent("events.lock").path, O_CREAT | O_RDWR, 0o600)
        guard descriptor >= 0 else { throw CocoaError(.fileWriteUnknown) }
        defer { close(descriptor) }
        guard flock(descriptor, LOCK_EX) == 0 else { throw CocoaError(.fileWriteUnknown) }
        defer { flock(descriptor, LOCK_UN) }
        return try action()
    }
}
