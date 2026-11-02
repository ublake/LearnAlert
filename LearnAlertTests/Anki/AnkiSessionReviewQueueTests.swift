import Foundation
import Testing
import UserNotifications
@testable import LearnAlert

@Suite("Anki session learning steps")
struct AnkiSessionReviewQueueTests {
    @Test("Rating removes premature alerts only for that card")
    @MainActor
    func alertDueDates() {
        let id = UUID(), other = UUID()
        func request(_ name: String, cardID: UUID, delay: TimeInterval) -> UNNotificationRequest {
            let content = UNMutableNotificationContent()
            content.userInfo = ["cardId": cardID.uuidString]
            return .init(identifier: name, content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false))
        }
        let requests = [request("early", cardID: id, delay: 60),
            request("later", cardID: id, delay: 86_400), request("other", cardID: other, delay: 60)]
        #expect(AnkiReviewAlerts.prematureRequests(requests, cardID: id, due: Date().addingTimeInterval(3_600)) == ["early"])
    }

    @Test("Short steps wait until due and mature cards leave the session")
    func respectsDates() {
        let now = Date(timeIntervalSince1970: 1_000), missed = UUID(), known = UUID()
        var queue = AnkiSessionReviewQueue()
        queue.schedule(missed, due: now.addingTimeInterval(60), repeatsInSession: true)
        queue.schedule(known, due: now.addingTimeInterval(86_400), repeatsInSession: false)
        let early = queue.takeReady(at: now)
        #expect(early.isEmpty)
        #expect(queue.nextDate == now.addingTimeInterval(60))
        let due = queue.takeReady(at: now.addingTimeInterval(60))
        #expect(due == [missed])
        #expect(queue.nextDate == nil)
    }

    @Test("Rating a card again replaces its step without duplicate repeats")
    func replacesPendingStep() {
        let now = Date(), card = UUID()
        var queue = AnkiSessionReviewQueue()
        queue.schedule(card, due: now.addingTimeInterval(60), repeatsInSession: true)
        queue.schedule(card, due: now.addingTimeInterval(600), repeatsInSession: true)
        let due = queue.takeReady(at: now.addingTimeInterval(60))
        #expect(due.isEmpty)
        #expect(queue.pending.count == 1)
        queue.schedule(card, due: now.addingTimeInterval(86_400), repeatsInSession: false)
        #expect(queue.pending.isEmpty)
    }

    @Test("Explicit early review takes only the nearest pending card")
    func explicitEarlyReview() {
        let now = Date(), first = UUID(), second = UUID()
        var queue = AnkiSessionReviewQueue()
        queue.schedule(first, due: now.addingTimeInterval(60), repeatsInSession: true)
        queue.schedule(second, due: now.addingTimeInterval(600), repeatsInSession: true)
        let early = queue.takeReady(at: now, reviewEarly: true)
        #expect(early == [first])
        #expect(queue.pending[second] == now.addingTimeInterval(600))
    }
}
