import Foundation
import SwiftData
import UserNotifications

@MainActor
enum AnkiReviewAlerts {
    private static var reconciling = false
    private static var needsAnotherPass = false
    /// Already queued alerts must not bring a known card back before its new due date.
    static func reconcile(cardID: UUID) async {
        needsAnotherPass = true
        guard !reconciling else { return }
        reconciling = true
        defer { reconciling = false }
        while needsAnotherPass {
            needsAnotherPass = false
            _ = try? await DailyDeckAlertScheduler.replenish()
            let center = UNUserNotificationCenter.current()
            let pending = await center.pendingNotificationRequests()
            let context = ModelContext(SharedDatabase.shared.container)
            // Recheck every pending Anki card: another review may have happened while
            // replenishing, and an older pass must not resurrect its premature alerts.
            let ids = Set(pending.compactMap { UUID(uuidString: $0.content.userInfo["cardId"] as? String ?? "") })
            let obsolete = ids.flatMap { id -> [String] in
                guard let card = try? context.fetch(FetchDescriptor<Flashcard>(predicate: #Predicate { $0.id == id })).first,
                      card.cardType == .anki else { return [] }
                return prematureRequests(pending, cardID: id, due: card.nextReviewDate)
            }
            guard !obsolete.isEmpty else { continue }
            center.removePendingNotificationRequests(withIdentifiers: obsolete)
            AlertTimelineStore.shared.reconcile(pending: await center.pendingNotificationRequests())
        }
    }

    static func prematureRequests(_ requests: [UNNotificationRequest], cardID: UUID, due: Date) -> [String] {
        requests.compactMap { request in
            guard UUID(uuidString: request.content.userInfo["cardId"] as? String ?? "") == cardID,
                  let date = (request.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate()
                    ?? (request.trigger as? UNTimeIntervalNotificationTrigger)?.nextTriggerDate(), date < due else { return nil }
            return request.identifier
        }
    }
}
