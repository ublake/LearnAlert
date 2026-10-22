import Foundation
import SwiftData
import UserNotifications

@MainActor
enum DailyDeckAlertScheduler {
    private static let planKey = "dailyDeckAlertPlan"
    private static var defaults: UserDefaults? { UserDefaults(suiteName: "group.com.learnalert.shared") }
    private static var storedPlan: (plan: DailyDeckAlertPlan, data: Data)? {
        defaults?.synchronize()
        guard let data = defaults?.data(forKey: planKey),
              let plan = try? JSONDecoder().decode(DailyDeckAlertPlan.self, from: data) else { return nil }
        return (plan, data)
    }
    static var activePlan: DailyDeckAlertPlan? { storedPlan?.plan }
    static func clear() {
        defaults?.removeObject(forKey: planKey)
        defaults?.synchronize()
    }
    static func activate(_ plan: DailyDeckAlertPlan) async throws -> [Date] {
        defaults?.set(try JSONEncoder().encode(plan), forKey: planKey)
        defaults?.synchronize()
        do { return try await replenish() }
        catch { clear(); throw error }
    }
    @discardableResult
    static func replenish() async throws -> [Date] {
        guard let stored = storedPlan, isCurrent(planData: stored.data, defaults: defaults) else { return [] }
        let plan = stored.plan
        let context = ModelContext(SharedDatabase.shared.container)
        let deckId = plan.deckId
        guard let deck = try context.fetch(FetchDescriptor<Deck>(predicate: #Predicate { $0.id == deckId })).first else {
            clear()
            return []
        }
        // A daily plan only needs the next 60 slots. Faulting deck.cards also
        // sorts the entire imported deck and used to block startup for large decks.
        let sectionId = plan.sectionId.flatMap { id in deck.sections.first { $0.id == id }?.id }
        let candidateSlots = plan.slots()
        let cards = try scheduledCards(cardIDs: candidateSlots.map(\.cardId), deckID: deckId,
            sectionID: sectionId, in: context)
        let lookup = Dictionary(uniqueKeysWithValues: cards.map { ($0.id, $0) })
        let center = UNUserNotificationCenter.current()
        var shouldStop = false
        if plan.stopWhenMastered {
            shouldStop = try allCardsMastered(deckID: deckId, sectionID: sectionId, in: context)
        }
        if shouldStop {
            let pending = await center.pendingNotificationRequests()
            guard isCurrent(planData: stored.data, defaults: defaults) else { return [] }
            clear()
            center.removePendingNotificationRequests(withIdentifiers: pending.filter { $0.identifier.hasPrefix("daily-deck-") }.map(\.identifier))
            defaults?.set(true, forKey: "extensionDidStopAlerts")
            return []
        }
        let slots = candidateSlots.filter { slot in
            guard let card = lookup[slot.cardId] else { return false }
            return card.cardType != .anki || card.isNew || card.nextReviewDate <= slot.date
        }
        let desired = Set(slots.map { "daily-deck-\(plan.id)-\(Int($0.date.timeIntervalSince1970))" })
        let pending = await center.pendingNotificationRequests()
        guard isCurrent(planData: stored.data, defaults: defaults) else { return [] }
        center.removePendingNotificationRequests(withIdentifiers: pending.filter {
            $0.identifier.hasPrefix("daily-deck-") && !desired.contains($0.identifier)
        }.map(\.identifier))
        let existing = Set(pending.map(\.identifier))
        for slot in slots {
            let id = "daily-deck-\(plan.id)-\(Int(slot.date.timeIntervalSince1970))"
            guard isCurrent(planData: stored.data, defaults: defaults) else { return [] }
            guard !existing.contains(id), let card = lookup[slot.cardId] else { continue }
            let content = UNMutableNotificationContent()
            content.title = "LearnAlert: \(deck.name)"
            content.body = card.cardType.isReviewOnly ? "Press and hold to review" : "Press and hold to answer"
            content.categoryIdentifier = "FLASHCARD_REVEAL"
            let sound = plan.sound
            content.sound = sound == "Default" ? .default : UNNotificationSound(named: UNNotificationSoundName(sound))
            content.userInfo = ["deckId": deck.id.uuidString, "cardId": card.id.uuidString,
                "deckName": deck.name, "deckType": card.cardType.title, "cardType": card.cardType.rawValue,
                "question": card.studyQuestion, "options": card.options, "correctAnswer": card.correctAnswer,
                "hint": card.hint, "matchingLeftItems": card.matchingLeftItems,
                "matchingRightItems": card.matchingRightItems, "promptImageName": card.promptImageName ?? "",
                "answerImageName": card.answerImageName ?? "",
                "optionImageNames": card.optionImageNames, "isRandom": false, "progress": "Daily card"]
            let trigger = UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second], from: slot.date), repeats: false)
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            try await center.add(request)
            AlertTimelineStore.shared.scheduled(request, date: slot.date)
            if !isCurrent(planData: stored.data, defaults: defaults) {
                center.removePendingNotificationRequests(withIdentifiers: [id])
                return []
            }
        }
        return slots.map(\.date)
    }

    /// Check cancellation after each suspension without decoding a potentially
    /// huge card-ID plan and forcing a preferences flush for every alert.
    static func isCurrent(planData: Data, defaults: UserDefaults?) -> Bool {
        defaults?.bool(forKey: "extensionDidStopAlerts") != true && defaults?.data(forKey: planKey) == planData
    }

    static func scheduledCards(cardIDs: [UUID], deckID: UUID, sectionID: UUID?, in context: ModelContext) throws -> [Flashcard] {
        let ids = Array(Set(cardIDs))
        guard !ids.isEmpty else { return [] }
        let predicate: Predicate<Flashcard>
        if let sectionID {
            predicate = #Predicate { ids.contains($0.id) && $0.deck?.id == deckID && $0.section?.id == sectionID }
        } else {
            predicate = #Predicate { ids.contains($0.id) && $0.deck?.id == deckID }
        }
        return try context.fetch(FetchDescriptor<Flashcard>(predicate: predicate))
    }

    static func allCardsMastered(deckID: UUID, sectionID: UUID?, in context: ModelContext, now: Date = Date()) throws -> Bool {
        let unmastered: Predicate<Flashcard>
        let scope: Predicate<Flashcard>
        if let sectionID {
            unmastered = #Predicate { $0.deck?.id == deckID && $0.section?.id == sectionID && $0.masteryScore < 3 }
            scope = #Predicate { $0.deck?.id == deckID && $0.section?.id == sectionID }
        } else {
            unmastered = #Predicate { $0.deck?.id == deckID && $0.masteryScore < 3 }
            scope = #Predicate { $0.deck?.id == deckID }
        }
        guard try context.fetchCount(FetchDescriptor<Flashcard>(predicate: unmastered)) == 0 else { return false }
        // Anki due dates live in its review-state JSON, so check the already
        // mastered cards in bounded batches only for this explicit stop condition.
        var descriptor = FetchDescriptor<Flashcard>(predicate: scope)
        descriptor.fetchLimit = 200
        while true {
            let batch = try context.fetch(descriptor)
            guard batch.allSatisfy({ $0.nextReviewDate > now }) else { return false }
            if batch.count < 200 { return true }
            descriptor.fetchOffset = (descriptor.fetchOffset ?? 0) + batch.count
        }
    }
}
