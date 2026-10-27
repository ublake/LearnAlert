//
//  StudyEngine.swift
//  LearnAlert
//
//  Created by Blake Miller on 2/19/26.
//

import Foundation
import SwiftData
import SwiftUI
import UserNotifications
import Combine

@MainActor
class StudyEngine: ObservableObject {
    static let shared = StudyEngine()
    private let context = ModelContext(SharedDatabase.shared.container)
    
    // Live Dashboard State
    @Published var isActive: Bool = false
    @Published var scheduledDates: [Date] = []
    @Published var activeDeckId: UUID?
    @Published var activeDeckName: String = ""
    @Published var activeSectionId: UUID?
    @Published var activeSectionName: String = "All Categories"
    
    @Published private var defaultSettings = DeckAlertSettings.defaults()
    @Published private(set) var settingsDeck: Deck?
    @AppStorage("customVolume") private var storedCustomVolume: Int = 20
    let volumeOptions = [3, 5, 7, 10, 15]

    var settings: DeckAlertSettings {
        get { settingsDeck?.alertSettings ?? defaultSettings }
        set {
            objectWillChange.send()
            if let deck = settingsDeck, deck.alertSettings != nil {
                deck.alertSettings = newValue
                try? deck.modelContext?.save()
            } else {
                defaultSettings = newValue
                UserDefaults.standard.set(try? JSONEncoder().encode(newValue), forKey: "defaultDeckAlertSettings")
            }
        }
    }
    func selectSettings(for deck: Deck?) {
        settingsDeck = deck
    }
    var automaticDailyCount: Int {
        return DeckAlertSettings.automaticDailyCount(cardCount: settingsDeck?.cards.count)
    }
    var globalSettings: DeckAlertSettings { defaultSettings }

    /// Called only after an explicit save. Failed scheduling restores the preferences.
    func saveAlertSettings(_ preferences: DeckAlertSettings, sound: String, for deck: Deck?,
        reschedule: () async throws -> Void) async throws {
        let previousDeckSettings = deck?.alertSettings
        let previousDefaults = defaultSettings
        let previousDefaultsData = UserDefaults.standard.object(forKey: "defaultDeckAlertSettings")
        let previousSound = UserDefaults.standard.object(forKey: "alertSound")
        let previousSelection = settingsDeck
        do {
            selectSettings(for: deck)
            if let deck {
                deck.alertSettings = preferences
                try deck.modelContext?.save()
            } else {
                settings = preferences
            }
            UserDefaults.standard.set(sound, forKey: "alertSound")
            try await reschedule()
        } catch {
            deck?.alertSettings = previousDeckSettings
            try? deck?.modelContext?.save()
            defaultSettings = previousDefaults
            if let previousDefaultsData { UserDefaults.standard.set(previousDefaultsData, forKey: "defaultDeckAlertSettings") }
            else { UserDefaults.standard.removeObject(forKey: "defaultDeckAlertSettings") }
            if let previousSound { UserDefaults.standard.set(previousSound, forKey: "alertSound") }
            else { UserDefaults.standard.removeObject(forKey: "alertSound") }
            settingsDeck = previousSelection
            throw error
        }
    }
    var smartSRS: Bool { get { settings.smartSRS } set { settings.smartSRS = newValue } }
    var stopCondition: String { get { settings.stopCondition } set { settings.stopCondition = newValue } }
    var startHour: Int { get { settings.startHour } set { settings.startHour = newValue } }
    var startMinute: Int { get { settings.startMinute } set { settings.startMinute = newValue } }
    var endHour: Int { get { settings.endHour } set { settings.endHour = newValue } }
    var endMinute: Int { get { settings.endMinute } set { settings.endMinute = newValue } }
    var activeVolume: Int { settings.resolvedDailyCount(automaticCount: automaticDailyCount) }
    var volumeSelectionIndex: Int {
        get { volumeOptions.firstIndex(of: settings.dailyCount) ?? 5 }
        set { settings.dailyCount = newValue == 5 ? min(50, max(1, storedCustomVolume)) : volumeOptions[min(4, max(0, newValue))] }
    }
    var customVolume: Int {
        get { volumeSelectionIndex == 5 ? settings.dailyCount : storedCustomVolume }
        set { storedCustomVolume = min(50, max(1, newValue)); settings.dailyCount = storedCustomVolume }
    }

    // Persistent Storage for Active Sessions
    @AppStorage("savedIsActive") private var savedIsActive: Bool = false
    @AppStorage("savedDeckId") private var savedDeckId: String = ""
    @AppStorage("savedDeckName") private var savedDeckName: String = ""
    @AppStorage("savedSectionId") private var savedSectionId: String = ""
    @AppStorage("savedSectionName") private var savedSectionName: String = "All Categories"
    @AppStorage("savedDatesData") private var savedDatesData: Data = Data()
    
    init(restoreSavedSession: Bool = true) {
        if restoreSavedSession { restoreSession() }
    }
    
    private var restoringSchedule = false

    func restoreSession() {
        if let plan = DailyDeckAlertScheduler.activePlan, savedIsActive {
            guard !restoringSchedule else { return }
            restoringSchedule = true
            activeDeckId = plan.deckId
            activeDeckName = savedDeckName
            activeSectionId = plan.sectionId
            activeSectionName = savedSectionName
            isActive = true
            Task {
                defer { restoringSchedule = false }
                do {
                    scheduledDates = try await DailyDeckAlertScheduler.replenish()
                    savedDatesData = try JSONEncoder().encode(scheduledDates)
                    if scheduledDates.isEmpty { stopAlerts() }
                } catch { print("Daily alerts could not be restored: \(error.localizedDescription)") }
            }
            return
        }
        let sharedDefaults = UserDefaults(suiteName: "group.com.learnalert.shared")
        if sharedDefaults?.bool(forKey: "extensionDidStopAlerts") == true {
            savedIsActive = false
            savedDeckId = ""
            savedDeckName = ""
            savedDatesData = Data()
            sharedDefaults?.set(false, forKey: "extensionDidStopAlerts")
        }

        // 1. Load saved dates from hard drive
        if let decodedDates = try? JSONDecoder().decode([Date].self, from: savedDatesData) {
            let futureDates = decodedDates.filter { $0 > Date() }
            self.scheduledDates = futureDates
            self.activeDeckId = UUID(uuidString: savedDeckId)
            self.activeDeckName = savedDeckName
            self.activeSectionId = UUID(uuidString: savedSectionId)
            self.activeSectionName = savedSectionName
            self.isActive = savedIsActive
            
            if futureDates.isEmpty && savedIsActive {
                handleCycleFinished()
            } else if futureDates.isEmpty && !savedIsActive {
                stopAlerts()
            }
        }
        
        // 2. Cross-verify with iOS Notification Center
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            DispatchQueue.main.async {
                let flashcardRequests = requests.filter { $0.content.categoryIdentifier == "FLASHCARD_REVEAL" }
                if flashcardRequests.isEmpty {
                    if self.savedIsActive {
                        self.handleCycleFinished()
                    } else {
                        self.stopAlerts()
                    }
                }
            }
        }
    }
    
    @discardableResult
    func startAlerts(for deck: Deck, section: DeckSection? = nil) async throws -> Int {
        selectSettings(for: deck)
        DailyDeckAlertScheduler.clear()
        let cards = fetchCardsToStudy(from: deck, section: section)
        
        // If "Until Deck Learnt" is selected and all cards are mastered
        if stopCondition == "Until Deck Learnt" && cards.isEmpty {
            stopAlerts()
            throw NSError(
                domain: "LearnAlert.StudyEngine",
                code: 200,
                userInfo: [NSLocalizedDescriptionKey: "All cards in '\(deck.name)' are mastered! No review alerts are due today."]
            )
        }
        
        guard !cards.isEmpty else {
            throw NSError(
                domain: "LearnAlert.StudyEngine",
                code: 204,
                userInfo: [NSLocalizedDescriptionKey: "No studyable flashcards found in '\(deck.name)'."]
            )
        }
        
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        let now = Date()
        let calendar = Calendar.current
        guard let window = StudyScheduling.window(now: now, startHour: startHour, startMinute: startMinute,
            endHour: endHour, endMinute: endMinute, calendar: calendar) else {
            throw NSError(domain: "LearnAlert.StudyEngine", code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Invalid study window configuration."])
        }
        let startTime = window.start
        let endTime = window.end

        let totalDuration = max(120.0, endTime.timeIntervalSince(startTime))
        let interval = max(60.0, totalDuration / Double(max(1, cards.count)))
        
        var newScheduledDates: [Date] = []
        if activeVolume == 1 {
            let base = section?.cards ?? deck.cards
            let ordered = smartSRS ? base.sorted { $0.studyPriority > $1.studyPriority } : orderedCards(deck: deck, section: section)
            // Start with the next selected card, then rotate through the remaining material.
            let first = cards[0]
            let ids = [first.id] + ordered.filter { $0.id != first.id }.map(\.id)
            guard let anchor = calendar.nextDate(after: now, matching: DateComponents(hour: settings.dailyHour,
                minute: settings.dailyMinute, second: 0), matchingPolicy: .nextTime) else { return 0 }
            let expiresAt = stopCondition == "Until Day Ends" ? calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) : nil
            let plan = DailyDeckAlertPlan(deckId: deck.id, sectionId: section?.id, cardIds: ids,
                anchor: anchor, hour: settings.dailyHour, minute: settings.dailyMinute, expiresAt: expiresAt,
                stopWhenMastered: stopCondition == "Until Deck Learnt", sound: UserDefaults.standard.string(forKey: "alertSound") ?? "Default")
            UserDefaults(suiteName: "group.com.learnalert.shared")?.set(false, forKey: "extensionDidStopAlerts")
            newScheduledDates = try await DailyDeckAlertScheduler.activate(plan)
            guard !newScheduledDates.isEmpty else {
                DailyDeckAlertScheduler.clear()
                throw NSError(domain: "LearnAlert.StudyEngine", code: 204,
                    userInfo: [NSLocalizedDescriptionKey: "That time has passed today. Choose a later time or keep alerts running beyond today."])
            }
        } else {
            for (index, card) in cards.enumerated() {
                let triggerDate = startTime.addingTimeInterval(interval * Double(index))
                newScheduledDates.append(triggerDate)
                try await NotificationManager.shared.scheduleRealCardAsync(card, at: triggerDate, progress: "\(index + 1)/\(cards.count)")

            }
        }

        if !smartSRS {
            let ordered = orderedCards(deck: deck, section: section)
            if let last = cards.last, let index = ordered.firstIndex(where: { $0.id == last.id }) {
                UserDefaults.standard.set(ordered[(index + 1) % ordered.count].id.uuidString,
                    forKey: sequentialCursorKey(deck: deck, section: section))
            }
        }

        // Update Live UI
        self.activeDeckId = deck.id
        self.activeDeckName = deck.name
        self.activeSectionId = section?.id
        self.activeSectionName = section?.name ?? "All Categories"
        self.scheduledDates = newScheduledDates
        withAnimation(.spring) { self.isActive = true }
        
        // Save to Hard Drive & App Group Defaults
        self.savedIsActive = true
        self.savedDeckId = deck.id.uuidString
        self.savedDeckName = deck.name
        self.savedSectionId = section?.id.uuidString ?? ""
        self.savedSectionName = section?.name ?? "All Categories"
        if let encodedData = try? JSONEncoder().encode(newScheduledDates) {
            self.savedDatesData = encodedData
        }
        
        if let sharedDefaults = UserDefaults(suiteName: "group.com.learnalert.shared") {
            sharedDefaults.set(deck.id.uuidString, forKey: "extensionActiveDeckId")
            sharedDefaults.set(deck.name, forKey: "extensionActiveDeckName")
            sharedDefaults.set(stopCondition, forKey: "extensionStopCondition")
            sharedDefaults.set(false, forKey: "extensionDidStopAlerts")
        }
        
        return cards.count
    }
    
    func stopAlerts() {
        AlertTimelineStore.shared.cancelFuture()
        DailyDeckAlertScheduler.clear()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        withAnimation(.spring) {
            self.isActive = false
            self.scheduledDates = []
            self.activeDeckId = nil
            self.activeDeckName = ""
            self.activeSectionId = nil
            self.activeSectionName = "All Categories"
        }
        
        // Clear Hard Drive & Shared Defaults
        self.savedIsActive = false
        self.savedDeckId = ""
        self.savedDeckName = ""
        self.savedSectionId = ""
        self.savedSectionName = "All Categories"
        self.savedDatesData = Data()
        
        if let sharedDefaults = UserDefaults(suiteName: "group.com.learnalert.shared") {
            sharedDefaults.set(false, forKey: "extensionDidStopAlerts")
            sharedDefaults.set("", forKey: "extensionActiveDeckId")
            sharedDefaults.set("", forKey: "extensionActiveDeckName")
        }
    }
    
    /// Checks stopCondition when today's notification cycle finishes
    private func handleCycleFinished() {
        guard savedIsActive else {
            stopAlerts()
            return
        }
        
        // 1. "Until Day Ends" condition: stop scheduling automatically when the day finishes
        if (UserDefaults(suiteName: "group.com.learnalert.shared")?.string(forKey: "extensionStopCondition") ?? stopCondition) == "Until Day Ends" {
            stopAlerts()
            return
        }
        
        // 2. "Until Deck Learnt" or "Until I say so": attempt to reschedule
        rescheduleNextCycle()
    }
    
    func rescheduleNextCycle() {
        guard savedIsActive else {
            stopAlerts()
            return
        }
        
        let descriptor = FetchDescriptor<Deck>()
        guard let allDecks = try? context.fetch(descriptor) else {
            stopAlerts()
            return
        }
        
        // Permanent ID match, with name fallback
        let targetDeck: Deck?
        if let savedUUID = UUID(uuidString: savedDeckId) {
            targetDeck = allDecks.first(where: { $0.id == savedUUID }) ?? allDecks.first(where: { $0.name == savedDeckName })
        } else {
            targetDeck = allDecks.first(where: { $0.name == savedDeckName })
        }
        
        guard let deck = targetDeck else {
            stopAlerts()
            return
        }
        
        var section: DeckSection? = nil
        if !savedSectionId.isEmpty, let sectionUUID = UUID(uuidString: savedSectionId) {
            section = deck.sections.first(where: { $0.id == sectionUUID })
        }
        
        selectSettings(for: deck)
        // Check "Until Deck Learnt" condition
        if stopCondition == "Until Deck Learnt" {
            let baseCards = section?.cards ?? deck.cards
            let unlearnedCards = baseCards.filter { !$0.isLearned }
            let dueCards = baseCards.filter { $0.nextReviewDate <= Date() }
            if unlearnedCards.isEmpty && dueCards.isEmpty {
                stopAlerts()
                return
            }
        }
        
        Task {
            do {
                try await startAlerts(for: deck, section: section)
            } catch {
                stopAlerts()
            }
        }
    }

    private func sequentialCursorKey(deck: Deck, section: DeckSection?) -> String {
        "sequential-next-\(deck.id.uuidString)-\(section?.id.uuidString ?? "all")"
    }

    private func orderedCards(deck: Deck, section: DeckSection?) -> [Flashcard] {
        (section?.cards ?? deck.cards).sorted {
            if $0.orderIndex != $1.orderIndex { return $0.orderIndex < $1.orderIndex }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    /// Smart Spaced Repetition card selection prioritizing due & new cards
    private func fetchCardsToStudy(from deck: Deck, section: DeckSection?) -> [Flashcard] {
        let baseCards = section?.cards ?? deck.cards
        guard !baseCards.isEmpty else { return [] }
        
        let now = Date()
        
        if smartSRS {
            // 1. Due Cards: cards that have been studied before and have nextReviewDate <= now
            let dueCards = baseCards.filter { !$0.isNew && $0.nextReviewDate <= now }.sorted {
                if $0.studyPriority != $1.studyPriority {
                    return $0.studyPriority > $1.studyPriority
                }
                return $0.nextReviewDate < $1.nextReviewDate
            }
            
            // 2. New Cards: cards never studied before
            let newCards = baseCards.filter { $0.isNew }
            
            // Primary study batch: Due cards first, then new cards
            var selected: [Flashcard] = dueCards + newCards
            
            // 3. If stopCondition is "Until Deck Learnt", avoid over-scheduling cards that aren't due
            if stopCondition == "Until Deck Learnt" && selected.isEmpty {
                return []
            }
            
            let targetCount = activeVolume
            
            // 4. If we haven't reached activeVolume, pull upcoming cards that will be due soonest without duplicate repeats
            if selected.count < targetCount {
                let futureCards = baseCards.filter { $0.cardType != .anki && !$0.isNew && $0.nextReviewDate > now }.sorted {
                    $0.nextReviewDate < $1.nextReviewDate
                }
                
                for card in futureCards {
                    guard selected.count < targetCount else { break }
                    if !selected.contains(where: { $0.id == card.id }) {
                        selected.append(card)
                    }
                }
            }
            
            // 5. Cap to activeVolume
            if selected.count > targetCount {
                selected = Array(selected.prefix(targetCount))
            }
            
            return selected
        } else {
            let ordered = orderedCards(deck: deck, section: section).filter {
                $0.cardType != .anki || $0.isNew || $0.nextReviewDate <= now
            }
            let nextID = UserDefaults.standard.string(forKey: sequentialCursorKey(deck: deck, section: section)).flatMap(UUID.init(uuidString:))
            return StudyScheduling.sequentialBatch(ordered, nextID: nextID, count: activeVolume)
        }
    }
}
