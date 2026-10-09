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
        if volumeSelectionIndex == 5 { return min(60, max(1, customVolume)) }
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
    
    private var restoringCourse = false

    func restoreSession() {
        if let plan = CourseNotificationScheduler.activePlan, savedIsActive {
            guard !restoringCourse else { return }
            restoringCourse = true
            activeDeckId = UUID(uuidString: plan.deckId)
            activeDeckName = savedDeckName
            isActive = true
            Task {
                defer { restoringCourse = false }
                do {
                    scheduledDates = try await CourseNotificationScheduler.replenish()
                    savedDatesData = try JSONEncoder().encode(scheduledDates)
                    if scheduledDates.isEmpty, plan.expiresAt != nil || plan.stopWhenMastered == true { stopAlerts() }
                } catch { print("Course alerts could not be restored: \(error.localizedDescription)") }
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
    func startAlerts(for deck: Deck, section: DeckSection? = nil, courseReviewOnly: Bool = false) async throws -> Int {
        let manager = CourseProgressManager.shared
        if let course = manager.allEnrolledCourses.first(where: { manager.enrollment(for: $0.id)?.linkedDeckId == deck.id.uuidString }),
           let enrollment = manager.enrollment(for: course.id) {
            guard !enrollment.selectedDays.isEmpty else {
                throw NSError(domain: "LearnAlert.Course", code: 400, userInfo: [NSLocalizedDescriptionKey: "Choose at least one study day."])
            }
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            let expiry = stopCondition == "Until Day Ends" ? Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())) : nil
            let plan = CourseAlertPlan(courseId: course.id, deckId: deck.id.uuidString,
                startHour: startHour, startMinute: startMinute, endHour: endHour, endMinute: endMinute,
                weekdays: enrollment.selectedDays, dailyCount: activeVolume, expiresAt: expiry, reviewOnly: courseReviewOnly, stopWhenMastered: stopCondition == "Until Deck Learnt")
            let dates = try await CourseNotificationScheduler.activate(plan)
            guard !dates.isEmpty else {
                CourseNotificationScheduler.clear()
                throw NSError(domain: "LearnAlert.Course", code: 204, userInfo: [NSLocalizedDescriptionKey: "No alerts fit the selected days and study window."])
            }
            activeDeckId = deck.id; activeDeckName = deck.name
            activeSectionId = nil; activeSectionName = "Learning Path"
            scheduledDates = dates; isActive = true
            savedIsActive = true; savedDeckId = deck.id.uuidString; savedDeckName = deck.name
            savedSectionId = ""; savedSectionName = "Learning Path"
            savedDatesData = try JSONEncoder().encode(dates)
            let defaults = UserDefaults(suiteName: "group.com.learnalert.shared")
            defaults?.set(deck.id.uuidString, forKey: "extensionActiveDeckId")
            defaults?.set(deck.name, forKey: "extensionActiveDeckName")
            defaults?.set(false, forKey: "extensionDidStopAlerts")
            return dates.count
        }
        CourseNotificationScheduler.clear()
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
        
        for (index, card) in cards.enumerated() {
            let triggerDate = startTime.addingTimeInterval(interval * Double(index))
            newScheduledDates.append(triggerDate)
            try await NotificationManager.shared.scheduleRealCardAsync(
                card,
                at: triggerDate,
                progress: "\(index + 1)/\(cards.count)"
            )
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
        CourseNotificationScheduler.clear()
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
            let ordered = orderedCards(deck: deck, section: section)
            let nextID = UserDefaults.standard.string(forKey: sequentialCursorKey(deck: deck, section: section)).flatMap(UUID.init(uuidString:))
            return StudyScheduling.sequentialBatch(ordered, nextID: nextID, count: activeVolume)
        }
    }
}
