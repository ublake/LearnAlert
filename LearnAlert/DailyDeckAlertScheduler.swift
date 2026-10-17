import Foundation
import SwiftData
import UserNotifications

@MainActor
enum DailyDeckAlertScheduler {
    private static var defaults: UserDefaults? { UserDefaults(suiteName: "group.com.learnalert.shared") }
    static var activePlan: DailyDeckAlertPlan? {
        defaults?.synchronize()
        return defaults?.data(forKey: "dailyDeckAlertPlan").flatMap { try? JSONDecoder().decode(DailyDeckAlertPlan.self, from: $0) }
    }
    static func clear() {
        defaults?.removeObject(forKey: "dailyDeckAlertPlan")
        defaults?.synchronize()
    }
    static func activate(_ plan: DailyDeckAlertPlan) async throws -> [Date] {
        defaults?.set(try JSONEncoder().encode(plan), forKey: "dailyDeckAlertPlan")
        defaults?.synchronize()
        do { return try await replenish() }
        catch { clear(); throw error }
    }
    @discardableResult
    static func replenish() async throws -> [Date] {
        guard let plan = activePlan, defaults?.bool(forKey: "extensionDidStopAlerts") != true else { return [] }
        let context = ModelContext(SharedDatabase.shared.container)
        let deckId = plan.deckId
        guard let deck = try context.fetch(FetchDescriptor<Deck>(predicate: #Predicate { $0.id == deckId })).first else {
            clear()
            return []
        }
        let cards = plan.sectionId.flatMap { id in deck.sections.first { $0.id == id }?.cards } ?? deck.cards
        let lookup = Dictionary(uniqueKeysWithValues: cards.map { ($0.id, $0) })
        let center = UNUserNotificationCenter.current()
        if plan.stopWhenMastered && cards.allSatisfy({ $0.isLearned && $0.nextReviewDate > Date() }) {
            let pending = await center.pendingNotificationRequests()
            guard activePlan == plan else { return [] }
            clear()
            center.removePendingNotificationRequests(withIdentifiers: pending.filter { $0.identifier.hasPrefix("daily-deck-") }.map(\.identifier))
            defaults?.set(true, forKey: "extensionDidStopAlerts")
            return []
        }
        let slots = plan.slots().filter { lookup[$0.cardId] != nil }
        let desired = Set(slots.map { "daily-deck-\(plan.id)-\(Int($0.date.timeIntervalSince1970))" })
        let pending = await center.pendingNotificationRequests()
        guard activePlan == plan else { return [] }
        center.removePendingNotificationRequests(withIdentifiers: pending.filter {
            $0.identifier.hasPrefix("daily-deck-") && !desired.contains($0.identifier)
        }.map(\.identifier))
        let existing = Set(pending.map(\.identifier))
        for slot in slots {
            let id = "daily-deck-\(plan.id)-\(Int(slot.date.timeIntervalSince1970))"
            guard activePlan == plan else { return [] }
            guard !existing.contains(id), let card = lookup[slot.cardId] else { continue }
            let content = UNMutableNotificationContent()
            content.title = "LearnAlert: \(deck.name)"
            content.body = card.cardType.isReviewOnly ? "Press and hold to review" : "Press and hold to answer"
            content.categoryIdentifier = "FLASHCARD_REVEAL"
            let sound = plan.sound
            content.sound = sound == "Default" ? .default : UNNotificationSound(named: UNNotificationSoundName(sound))
            content.userInfo = ["deckId": deck.id.uuidString, "cardId": card.id.uuidString,
                "deckName": deck.name, "deckType": card.cardType.title, "cardType": card.cardType.rawValue,
                "question": card.question, "options": card.options, "correctAnswer": card.correctAnswer,
                "hint": card.hint, "matchingLeftItems": card.matchingLeftItems,
                "matchingRightItems": card.matchingRightItems, "promptImageName": card.promptImageName ?? "",
                "answerImageName": card.answerImageName ?? "",
                "optionImageNames": card.optionImageNames, "isRandom": false, "progress": "Daily card"]
            let trigger = UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second], from: slot.date), repeats: false)
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            try await center.add(request)
            AlertTimelineStore.shared.scheduled(request, date: slot.date)
            if activePlan != plan {
                center.removePendingNotificationRequests(withIdentifiers: [id])
                return []
            }
        }
        return slots.map(\.date)
    }
}
