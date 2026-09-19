//
//  NotificationManager.swift
//  LearnAlert
//
//  Created by Blake Miller on 2/19/26.
//


import Foundation
import UserNotifications
import Combine
import SwiftUI

struct StudyHandoff: Identifiable, Hashable {
    let deckId: UUID
    let cardId: UUID
    let selectedAnswer: String?
    let wasCorrect: Bool?
    let wasGraded: Bool
    let wasHintVisible: Bool

    var id: String { "\(deckId.uuidString)-\(cardId.uuidString)-\(selectedAnswer ?? "reveal")" }
}

class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    
    @Published var isAuthorized = false
    @Published var pendingStudyHandoff: StudyHandoff?
    @Published var shouldShowNotificationOpeningTip = false
    
    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        setupCategories()
        checkPermission()
        Task { @MainActor [weak self] in
            self?.consumePendingStudyHandoff()
        }
    }
    
    func checkPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async { self.isAuthorized = settings.authorizationStatus == .authorized }
        }
    }
    
    @MainActor
    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted
            if granted { setupCategories() }
            return granted
        } catch {
            isAuthorized = false
            return false
        }
    }
    
    private func setupCategories() {
        let revealCategory = UNNotificationCategory(
            identifier: "FLASHCARD_REVEAL",
            actions: [],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        UNUserNotificationCenter.current().setNotificationCategories([revealCategory])
    }
    
    func scheduleRealCard(_ card: Flashcard, at date: Date, progress: String) {
        let content = UNMutableNotificationContent()
        let deckName = card.deck?.name ?? "Daily Review"
        let deckType = card.cardType.title
        
        content.title = "LearnAlert: \(deckName)"
        content.body = "Press and hold to answer"
        content.categoryIdentifier = "FLASHCARD_REVEAL"
        
        // NEW: Custom Sound Engine!
        let savedSound = UserDefaults.standard.string(forKey: "alertSound") ?? "Default"
        if savedSound == "Default" {
            content.sound = .default
        } else {
            // iOS requires .wav, .aiff, or .caf files bundled in your Xcode project
            content.sound = UNNotificationSound(named: UNNotificationSoundName(savedSound))
        }
        
        content.userInfo = [
            "cardId": card.id.uuidString,
            "deckId": card.deck?.id.uuidString ?? "",
            "deckName": deckName,
            "deckType": deckType,
            "isRandom": false,
            "progress": progress,
            "question": card.question,
            "cardType": card.cardType.rawValue,
            "options": card.options,
            "correctAnswer": card.correctAnswer,
            "hint": card.hint,
            "matchingLeftItems": card.matchingLeftItems,
            "matchingRightItems": card.matchingRightItems
        ]
        
        let triggerDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: "\(card.id.uuidString)_\(UUID().uuidString)", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error { print("Error scheduling: \(error)") }
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                completionHandler()
                return
            }
            let userInfo = response.notification.request.content.userInfo
            let defaults = UserDefaults(suiteName: "group.com.learnalert.shared")
            let fromNotificationUI = defaults?.bool(forKey: "handoffFromNotificationUI") ?? false
            let hasHandoffDeck = defaults?.string(forKey: "handoffDeckId") != nil

            if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
                if fromNotificationUI || hasHandoffDeck {
                    // Intentionally opened from inside the notification extension ("Continue in App" / "Open App")
                    defaults?.removeObject(forKey: "handoffFromNotificationUI")
                    self.shouldShowNotificationOpeningTip = false
                    self.consumePendingStudyHandoff()
                } else if let deckString = userInfo["deckId"] as? String,
                          let cardString = userInfo["cardId"] as? String,
                          let deckId = UUID(uuidString: deckString),
                          let cardId = UUID(uuidString: cardString) {
                    // Direct tap on the unexpanded banner
                    self.pendingStudyHandoff = StudyHandoff(
                        deckId: deckId,
                        cardId: cardId,
                        selectedAnswer: nil,
                        wasCorrect: nil,
                        wasGraded: false,
                        wasHintVisible: false
                    )
                    self.shouldShowNotificationOpeningTip = true
                } else {
                    self.consumePendingStudyHandoff()
                }
            } else {
                self.consumePendingStudyHandoff()
            }
            completionHandler()
        }
    }

    @MainActor
    func consumePendingStudyHandoff() {
        guard let defaults = UserDefaults(suiteName: "group.com.learnalert.shared"),
              let deckString = defaults.string(forKey: "handoffDeckId"),
              let cardString = defaults.string(forKey: "handoffCardId"),
              let deckId = UUID(uuidString: deckString),
              let cardId = UUID(uuidString: cardString) else { return }

        shouldShowNotificationOpeningTip = false
        pendingStudyHandoff = StudyHandoff(
            deckId: deckId,
            cardId: cardId,
            selectedAnswer: defaults.string(forKey: "handoffSelectedAnswer"),
            wasCorrect: defaults.object(forKey: "handoffWasCorrect") as? Bool,
            wasGraded: defaults.bool(forKey: "handoffWasGraded"),
            wasHintVisible: defaults.bool(forKey: "handoffHintVisible")
        )

        [
            "handoffDeckId", "handoffCardId", "handoffSelectedAnswer",
            "handoffWasCorrect", "handoffWasGraded", "handoffHintVisible",
            "handoffFromNotificationUI", "handoffTimestamp"
        ].forEach(defaults.removeObject(forKey:))
    }

    @MainActor
    func clearStudyHandoff() {
        pendingStudyHandoff = nil
    }
}
