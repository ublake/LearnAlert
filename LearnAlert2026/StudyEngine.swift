import Foundation
import SwiftData
import UserNotifications

@MainActor
class StudyEngine {
    static let shared = StudyEngine()
    
    // Connect to the shared App Group database
    private let context = ModelContext(SharedDatabase.shared.container)
    
    // 1. Find cards that are due
    func fetchDueCards(limit: Int = 10) -> [Flashcard] {
        let now = Date()
        
        // Query SwiftData for cards where nextReviewDate is in the past
        let descriptor = FetchDescriptor<Flashcard>(
            predicate: #Predicate { $0.nextReviewDate <= now },
            sortBy: [SortDescriptor(\.nextReviewDate)]
        )
        
        do {
            let dueCards = try context.fetch(descriptor)
            return Array(dueCards.prefix(limit))
        } catch {
            print("Failed to fetch due cards: \(error)")
            return []
        }
    }
    
    // 2. Schedule them as notifications
    func scheduleTodaysCards() {
        let dueCards = fetchDueCards(limit: 5) // Grab top 5 due cards
        
        guard !dueCards.isEmpty else {
            print("No cards due right now! You're all caught up.")
            return
        }
        
        // Clear old pending notifications so we don't spam the user
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        let now = Date()
        
        // Schedule each card 10 seconds apart (FOR TESTING!)
        // In production, change `(index + 1) * 10` to `(index + 1) * 3600` (1 hour apart)
        for (index, card) in dueCards.enumerated() {
            let delay = TimeInterval((index + 1) * 10) 
            let triggerDate = now.addingTimeInterval(delay)
            
            NotificationManager.shared.scheduleRealCard(card, at: triggerDate, progress: "\(index + 1)/\(dueCards.count)")
        }
        
        print("Successfully scheduled \(dueCards.count) cards for review.")
    }
}