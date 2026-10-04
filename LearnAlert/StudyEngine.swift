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
    
    // Engine Settings
    @AppStorage("smartSRS") var smartSRS: Bool = true
    @AppStorage("stopCondition") var stopCondition: String = "Until Deck Learnt"
    @AppStorage("startHour") var startHour: Int = 10 // 10 AM
    @AppStorage("startMinute") var startMinute: Int = 0
    @AppStorage("endHour") var endHour: Int = 19     // 7 PM
    @AppStorage("endMinute") var endMinute: Int = 0
    
    // Volume State
    @AppStorage("volumeSelectionIndex") var volumeSelectionIndex: Int = 3 // Defaults to 10 cards
    @AppStorage("customVolume") var customVolume: Int = 20
    
    let volumeOptions = [3, 5, 7, 10, 15]
    
    var activeVolume: Int {
        if volumeSelectionIndex == 5 { return customVolume }
        return volumeOptions[min(max(0, volumeSelectionIndex), volumeOptions.count - 1)]
    }
    
    // Persistent Storage for Active Sessions
    @AppStorage("savedIsActive") private var savedIsActive: Bool = false
    @AppStorage("savedDeckId") private var savedDeckId: String = ""
    @AppStorage("savedDeckName") private var savedDeckName: String = ""
    @AppStorage("savedSectionId") private var savedSectionId: String = ""
    @AppStorage("savedSectionName") private var savedSectionName: String = "All Categories"
    @AppStorage("savedDatesData") private var savedDatesData: Data = Data()
    
    init() {
        restoreSession()
    }
    
    func restoreSession() {
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
        guard var startTime = calendar.date(bySettingHour: startHour, minute: startMinute, second: 0, of: now),
              var endTime = calendar.date(bySettingHour: endHour, minute: endMinute, second: 0, of: now) else {
            throw NSError(
                domain: "LearnAlert.StudyEngine",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Invalid study window configuration."]
            )
        }

        // Overnight window support
        let startTotalMinutes = startHour * 60 + startMinute
        let endTotalMinutes = endHour * 60 + endMinute
        if endTotalMinutes <= startTotalMinutes,
           let followingDay = calendar.date(byAdding: .day, value: 1, to: endTime) {
            endTime = followingDay
        }

        // Shift window if now is past today's window or within 5 minutes of closing
        if now.addingTimeInterval(300) > endTime {
            if let nextStart = calendar.date(byAdding: .day, value: 1, to: startTime),
               let nextEnd = calendar.date(byAdding: .day, value: 1, to: endTime) {
                startTime = nextStart
                endTime = nextEnd
            }
        } else if now > startTime {
            startTime = max(now.addingTimeInterval(90), startTime)
            if startTime >= endTime.addingTimeInterval(-180) {
                if let nextStart = calendar.date(byAdding: .day, value: 1, to: startTime),
                   let nextEnd = calendar.date(byAdding: .day, value: 1, to: endTime) {
                    startTime = nextStart
                    endTime = nextEnd
                }
            }
        }
        
        let totalDuration = max(120.0, endTime.timeIntervalSince(startTime))
        let interval = max(60.0, totalDuration / Double(max(1, cards.count)))
        
        var newScheduledDates: [Date] = []
        
        for (index, card) in cards.enumerated() {
            let triggerDate = startTime.addingTimeInterval(interval * Double(index))
            newScheduledDates.append(triggerDate)
            try await NotificationManager.shared.scheduleRealCardAsync(
                card,
                at: triggerDate,
                progress: "\(index + 1)/\(cards.count)"
            )
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
        if stopCondition == "Until Day Ends" {
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
                let futureCards = baseCards.filter { !$0.isNew && $0.nextReviewDate > now }.sorted {
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
            // Sequential order without SRS filtering
            let sortedCards = baseCards.sorted { $0.id.uuidString < $1.id.uuidString }
            let targetCount = min(activeVolume, sortedCards.count)
            return Array(sortedCards.prefix(targetCount))
        }
    }
}
