import Foundation
import SwiftData
import UserNotifications

@MainActor
enum DailyDeckAlertScheduler {
    private static let planKey = "dailyDeckAlertPlan"
    private static var inFlight: (id: UUID, data: Data, task: Task<[Date], Error>)?
    private static var defaults: UserDefaults? { UserDefaults(suiteName: "group.com.learnalert.shared") }
    private static var storedPlan: (plan: DailyDeckAlertPlan, data: Data)? {
        defaults?.synchronize()
        guard let data = defaults?.data(forKey: planKey),
              let plan = try? JSONDecoder().decode(DailyDeckAlertPlan.self, from: data) else { return nil }
        return (plan, data)
    }
    static var activePlan: DailyDeckAlertPlan? { storedPlan?.plan }
    static func clear() {
        NotificationLearningBudget.invalidateSchedule()
        inFlight?.task.cancel()
        inFlight = nil
        defaults?.removeObject(forKey: planKey)
        defaults?.synchronize()
    }
    static func activate(_ plan: DailyDeckAlertPlan) async throws -> [Date] {
        NotificationLearningBudget.invalidateSchedule()
        NotificationLearningBudget.setNotificationLimit(plan.requestedDailyCount)
        let data = try JSONEncoder().encode(plan)
        defaults?.set(data, forKey: planKey)
        defaults?.synchronize()
        do { return try await replenish() }
        catch {
            // A failed partial activation must not leave untracked deliveries behind.
            let center = UNUserNotificationCenter.current()
            let pending = await center.pendingNotificationRequests()
            let ids = pending.filter { $0.identifier.hasPrefix(plan.identifierPrefix + "-") }.map(\.identifier)
            center.removePendingNotificationRequests(withIdentifiers: ids)
            NotificationLearningBudget.cancelReservations(requestIDs: ids)
            // A superseded activation must not clear the replacement plan.
            if defaults?.data(forKey: planKey) == data { clear() }
            throw error
        }
    }
    @discardableResult
    static func replenish() async throws -> [Date] {
        guard let stored = storedPlan, isCurrent(planData: stored.data, defaults: defaults) else { return [] }
        if let current = inFlight, current.data == stored.data { return try await current.task.value }
        inFlight?.task.cancel()
        let token = UUID()
        let task = Task { try await replenishPlan(stored) }
        inFlight = (token, stored.data, task)
        do {
            let result = try await task.value
            if inFlight?.id == token { inFlight = nil }
            return result
        } catch {
            if inFlight?.id == token { inFlight = nil }
            throw error
        }
    }
    private static func replenishPlan(_ stored: (plan: DailyDeckAlertPlan, data: Data)) async throws -> [Date] {
        guard isCurrent(planData: stored.data, defaults: defaults) else { return [] }
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
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        guard isCurrent(planData: stored.data, defaults: defaults) else { return [] }
        let ankiCandidates = try AnkiNotificationSelection.candidates(deckID: deckId, sectionID: sectionId, in: context)
        let onlyAnki: Bool
        if ankiCandidates.isEmpty { onlyAnki = false }
        else { onlyAnki = try AnkiNotificationSelection.isAnkiOnly(deckID: deckId, sectionID: sectionId, in: context) }
        // An all-Anki deck can be caught up for weeks. Keep its existing time
        // window, but search around its next due date instead of giving up after
        // the first 60 empty appointments.
        let earliest = ankiCandidates.map { $0.isNew ? Date.distantPast : $0.due }.min()
        let searchDate = onlyAnki ? max(Date(), (earliest ?? Date()).addingTimeInterval(-2)) : Date()
        let candidateSlots = plan.slots(now: searchDate)
        var cards = try scheduledCards(cardIDs: candidateSlots.map(\.cardId), deckID: deckId,
            sectionID: sectionId, in: context)
        let originalLookup = Dictionary(uniqueKeysWithValues: cards.map { ($0.id, $0) })
        let ankiLookup = Dictionary(uniqueKeysWithValues: ankiCandidates.map { ($0.id, $0) })
        let eligibleSlots = candidateSlots.compactMap { slot -> (date: Date, cardId: UUID)? in
            let id = AnkiNotificationSelection.next(in: ankiCandidates, at: slot.date)
            if let id, ankiLookup[id]?.isNew == false { return (slot.date, id) }
            if onlyAnki || originalLookup[slot.cardId]?.cardType == .anki {
                guard let id else { return nil }
                return (slot.date, id)
            }
            return originalLookup[slot.cardId] == nil ? nil : slot
        }
        let extraIDs = Array(Set(eligibleSlots.map(\.cardId)).subtracting(originalLookup.keys))
        cards += try scheduledCards(cardIDs: extraIDs, deckID: deckId, sectionID: sectionId, in: context)
        let lookup = Dictionary(uniqueKeysWithValues: cards.map { ($0.id, $0) })
        var shouldStop = false
        if plan.stopWhenMastered {
            shouldStop = try allCardsMastered(deckID: deckId, sectionID: sectionId, in: context)
        }
        if shouldStop {
            guard isCurrent(planData: stored.data, defaults: defaults) else { return [] }
            clear()
            let ids = pending.filter { $0.identifier.hasPrefix(plan.identifierPrefix + "-") }.map(\.identifier)
            center.removePendingNotificationRequests(withIdentifiers: ids)
            NotificationLearningBudget.cancelReservations(requestIDs: ids)
            defaults?.set(true, forKey: "extensionDidStopAlerts")
            return []
        }
        func identifier(_ slot: (date: Date, cardId: UUID)) -> String {
            plan.identifierPrefix + "-" + String(Int(slot.date.timeIntervalSince1970))
        }
        let preliminary = Set(eligibleSlots.map(identifier))
        guard isCurrent(planData: stored.data, defaults: defaults) else { return [] }
        let obsolete = pending.filter {
            $0.identifier.hasPrefix(plan.identifierPrefix + "-") && !preliminary.contains($0.identifier)
        }.map(\.identifier)
        center.removePendingNotificationRequests(withIdentifiers: obsolete)
        NotificationLearningBudget.cancelReservations(requestIDs: obsolete)
        // Existing requests outside this plan participate in the same spacing and
        // daily cap. Test previews are deliberately outside the learning budget.
        let otherDates = pending.filter {
            $0.content.categoryIdentifier == "FLASHCARD_REVEAL" && !$0.identifier.hasPrefix(plan.identifierPrefix + "-")
        }.compactMap { request in
            (request.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate()
                ?? (request.trigger as? UNTimeIntervalNotificationTrigger)?.nextTriggerDate()
        }
        let existing = Dictionary(pending.map { ($0.identifier, $0) }, uniquingKeysWith: { first, _ in first })
        var slots: [(date: Date, cardId: UUID)] = []
        for slot in eligibleSlots {
            let id = identifier(slot)
            guard isCurrent(planData: stored.data, defaults: defaults) else { return [] }
            guard let card = lookup[slot.cardId], NotificationLearningBudget.remainingQuestions(on: slot.date) > 0,
                  NotificationLearningBudget.reserveNotification(requestID: id, at: slot.date, pendingDates: otherDates + slots.map(\.date), minimumSpacingMinutes: plan.minimumSpacingMinutes,
                      dailyNotificationLimit: plan.requestedDailyCount) else { continue }
            slots.append(slot)
            // Current policy metadata replaces dense/legacy payloads in place.
            if let request = existing[id], request.content.userInfo["questionsPerAlert"] as? Int == plan.questionsPerAlert,
               request.content.userInfo["dailyQuestionGoal"] as? Int == 20,
               request.content.userInfo["cardId"] as? String == card.id.uuidString,
               request.content.userInfo["ankiDueSelection"] as? Bool == (card.cardType == .anki),
               request.content.userInfo["sectionId"] as? String == (sectionId?.uuidString ?? "") { continue }
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
                "optionImageNames": card.optionImageNames, "isRandom": false,
                "questionsPerAlert": plan.questionsPerAlert, "dailyQuestionGoal": 20,
                "minimumSpacingMinutes": plan.minimumSpacingMinutes,
                "sectionId": sectionId?.uuidString ?? "",
                "ankiDueSelection": card.cardType == .anki,
                "progress": "1/\(plan.questionsPerAlert)"]
            let trigger = UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second], from: slot.date), repeats: false)
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            do { try await center.add(request) }
            catch {
                NotificationLearningBudget.cancelReservations(requestIDs: [id])
                throw error
            }
            if NotificationLearningBudget.remainingQuestions(on: slot.date) == 0 {
                center.removePendingNotificationRequests(withIdentifiers: [id])
                NotificationLearningBudget.cancelReservations(requestIDs: [id])
                slots.removeAll { identifier($0) == id }
                continue
            }
            AlertTimelineStore.shared.scheduled(request, date: slot.date)
            if !isCurrent(planData: stored.data, defaults: defaults) {
                center.removePendingNotificationRequests(withIdentifiers: [id])
                NotificationLearningBudget.cancelReservations(requestIDs: [id])
                return []
            }
        }
        guard isCurrent(planData: stored.data, defaults: defaults) else { return [] }
        let accepted = Set(slots.map(identifier))
        let rejected = pending.filter {
            $0.identifier.hasPrefix(plan.identifierPrefix + "-") && !accepted.contains($0.identifier)
        }.map(\.identifier)
        center.removePendingNotificationRequests(withIdentifiers: rejected)
        NotificationLearningBudget.cancelReservations(requestIDs: rejected)
        return slots.map(\.date)
    }

    /// Check cancellation after each suspension without decoding a potentially
    /// huge card-ID plan and forcing a preferences flush for every alert.
    static func isCurrent(planData: Data, defaults: UserDefaults?) -> Bool {
        !Task.isCancelled && defaults?.bool(forKey: "extensionDidStopAlerts") != true && defaults?.data(forKey: planKey) == planData
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
