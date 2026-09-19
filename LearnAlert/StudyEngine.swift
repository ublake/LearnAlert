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
    
    // New Volume State
    @AppStorage("volumeSelectionIndex") var volumeSelectionIndex: Int = 3 // Defaults to 10 cards
    @AppStorage("customVolume") var customVolume: Int = 20
    
    let volumeOptions = [3, 5, 7, 10, 15]
    
    var activeVolume: Int {
        if volumeSelectionIndex == 5 { return customVolume }
        return volumeOptions[volumeSelectionIndex]
    }
    
    // Persistent Storage for Active Sessions
    @AppStorage("savedIsActive") private var savedIsActive: Bool = false
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
            savedDeckName = ""
            savedDatesData = Data()
            sharedDefaults?.set(false, forKey: "extensionDidStopAlerts")
        }

        // 1. Load saved dates from hard drive
        if let decodedDates = try? JSONDecoder().decode([Date].self, from: savedDatesData) {
            // Filter out notifications that already fired in the past
            let futureDates = decodedDates.filter { $0 > Date() }
            self.scheduledDates = futureDates
            self.activeDeckName = savedDeckName
            self.activeSectionId = UUID(uuidString: savedSectionId)
            self.activeSectionName = savedSectionName
            self.isActive = savedIsActive
            
            if futureDates.isEmpty && savedIsActive {
                rescheduleNextCycle()
            } else if futureDates.isEmpty && !savedIsActive {
                stopAlerts()
            }
        }
        
        // 2. Double-check with iOS Notification Center to ensure perfect accuracy
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            DispatchQueue.main.async {
                let flashcardRequests = requests.filter { $0.content.categoryIdentifier == "FLASHCARD_REVEAL" }
                if flashcardRequests.isEmpty {
                    if self.savedIsActive {
                        self.rescheduleNextCycle()
                    } else {
                        self.stopAlerts()
                    }
                }
            }
        }
    }
    
    func startAlerts(for deck: Deck, section: DeckSection? = nil) {
        let cards = fetchCardsToStudy(from: deck, section: section)
        guard !cards.isEmpty else { return }
        
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        let now = Date()
        let calendar = Calendar.current
        guard var startTime = calendar.date(bySettingHour: startHour, minute: startMinute, second: 0, of: now),
              var endTime = calendar.date(bySettingHour: endHour, minute: endMinute, second: 0, of: now) else {
            return
        }

        // Treat an end time at or before the start time as an overnight window.
        let startTotalMinutes = startHour * 60 + startMinute
        let endTotalMinutes = endHour * 60 + endMinute
        if endTotalMinutes <= startTotalMinutes,
           let followingDay = calendar.date(byAdding: .day, value: 1, to: endTime) {
            endTime = followingDay
        }

        if now > endTime,
           let nextStart = calendar.date(byAdding: .day, value: 1, to: startTime),
           let nextEnd = calendar.date(byAdding: .day, value: 1, to: endTime) {
            startTime = nextStart
            endTime = nextEnd
        } else if now > startTime {
            startTime = now.addingTimeInterval(60)
        }
        
        let totalDuration = endTime.timeIntervalSince(startTime)
        let interval = totalDuration / Double(cards.count)
        
        var newScheduledDates: [Date] = []
        
        for (index, card) in cards.enumerated() {
            let triggerDate = startTime.addingTimeInterval(interval * Double(index))
            newScheduledDates.append(triggerDate)
            NotificationManager.shared.scheduleRealCard(card, at: triggerDate, progress: "\(index + 1)/\(cards.count)")
        }
        
        // Update Live UI
        self.activeDeckName = deck.name
        self.activeSectionId = section?.id
        self.activeSectionName = section?.name ?? "All Categories"
        self.scheduledDates = newScheduledDates
        withAnimation(.spring) { self.isActive = true }
        
        // Save to Hard Drive
        self.savedIsActive = true
        self.savedDeckName = deck.name
        self.savedSectionId = section?.id.uuidString ?? ""
        self.savedSectionName = section?.name ?? "All Categories"
        if let encodedData = try? JSONEncoder().encode(newScheduledDates) {
            self.savedDatesData = encodedData
        }
    }
    
    func stopAlerts() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        withAnimation(.spring) {
            self.isActive = false
            self.scheduledDates = []
            self.activeDeckName = ""
            self.activeSectionId = nil
            self.activeSectionName = "All Categories"
        }
        
        // Clear Hard Drive
        self.savedIsActive = false
        self.savedDeckName = ""
        self.savedSectionId = ""
        self.savedSectionName = "All Categories"
        self.savedDatesData = Data()
        UserDefaults(suiteName: "group.com.learnalert.shared")?.set(false, forKey: "extensionDidStopAlerts")
    }
    
    func rescheduleNextCycle() {
        guard savedIsActive, !savedDeckName.isEmpty else {
            stopAlerts()
            return
        }
        let descriptor = FetchDescriptor<Deck>()
        guard let allDecks = try? context.fetch(descriptor),
              let deck = allDecks.first(where: { $0.name == savedDeckName }) else {
            stopAlerts()
            return
        }
        
        var section: DeckSection? = nil
        if !savedSectionId.isEmpty, let sectionUUID = UUID(uuidString: savedSectionId) {
            section = deck.sections.first(where: { $0.id == sectionUUID })
        }
        
        startAlerts(for: deck, section: section)
    }

    private func fetchCardsToStudy(from deck: Deck, section: DeckSection?) -> [Flashcard] {
        let baseCards = section?.cards ?? deck.cards
        guard !baseCards.isEmpty else { return [] }
        
        // 1. Smart arrange: prioritize cards based on studyPriority and error pressure
        var sortedCards = baseCards
        if smartSRS {
            sortedCards.sort {
                if $0.studyPriority != $1.studyPriority {
                    return $0.studyPriority > $1.studyPriority
                }
                if $0.accuracy != $1.accuracy {
                    return $0.accuracy < $1.accuracy
                }
                return $0.nextReviewDate < $1.nextReviewDate
            }
        } else {
            sortedCards.sort { $0.id.uuidString < $1.id.uuidString }
        }
        
        // 2. Smart repeat and cycle: ensure deck fills activeVolume and cycles for mastery
        let targetCount = activeVolume
        var cycledCards: [Flashcard] = []
        var index = 0
        while cycledCards.count < targetCount {
            cycledCards.append(sortedCards[index % sortedCards.count])
            index += 1
        }
        return cycledCards
    }
}
