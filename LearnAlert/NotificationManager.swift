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

struct CourseHandoff: Identifiable, Hashable {
    let id: String
    var sectionId: String? = nil
}

class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    
    @Published var isAuthorized = false
    @Published var pendingCourseHandoff: CourseHandoff?
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
        let continueAction = UNNotificationAction(
            identifier: "CONTINUE_IN_APP",
            title: "Continue in App",
            options: [.foreground]
        )
        let revealCategory = UNNotificationCategory(
            identifier: "FLASHCARD_REVEAL",
            actions: [continueAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        let testCategory = UNNotificationCategory(
            identifier: "FLASHCARD_TEST",
            actions: [],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        UNUserNotificationCenter.current().setNotificationCategories([revealCategory, testCategory])
    }
    
    func scheduleRealCard(_ card: Flashcard, at date: Date, progress: String) {
        let content = UNMutableNotificationContent()
        let deckName = card.deck?.name ?? "Daily Review"
        let deckType = card.cardType.title
        
        content.title = "LearnAlert: \(deckName)"
        content.body = card.cardType == .vocabulary ? "Press and hold to review" : "Press and hold to answer"
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
            "matchingRightItems": card.matchingRightItems,
            "promptImageName": card.promptImageName ?? "",
            "optionImageNames": card.optionImageNames
        ]
        
        let triggerDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: "\(card.id.uuidString)_\(UUID().uuidString)", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error { print("Error scheduling: \(error)") }
        }
    }

    func scheduleRealCardAsync(_ card: Flashcard, at date: Date, progress: String) async throws {
        let content = UNMutableNotificationContent()
        let deckName = card.deck?.name ?? "Daily Review"
        let deckType = card.cardType.title

        content.title = "LearnAlert: \(deckName)"
        content.body = card.cardType == .vocabulary ? "Press and hold to review" : "Press and hold to answer"
        content.categoryIdentifier = "FLASHCARD_REVEAL"

        let savedSound = UserDefaults.standard.string(forKey: "alertSound") ?? "Default"
        if savedSound == "Default" {
            content.sound = .default
        } else {
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
            "matchingRightItems": card.matchingRightItems,
            "promptImageName": card.promptImageName ?? "",
            "optionImageNames": card.optionImageNames
        ]

        let triggerDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: "\(card.id.uuidString)_\(UUID().uuidString)", content: content, trigger: trigger)

        try await UNUserNotificationCenter.current().add(request)
    }
    
    func scheduleTutorialAlert(
        deckTitle: String,
        question: String,
        options: [String],
        correctAnswer: String,
        hint: String,
        cardId: UUID = UUID(),
        deckId: UUID = UUID(),
        delay: TimeInterval = 0.8
    ) {
        setupCategories()
        let content = UNMutableNotificationContent()
        content.title = "LearnAlert: \(deckTitle)"
        content.body = "Press and hold to answer"
        content.categoryIdentifier = "FLASHCARD_TEST"

        let savedSound = UserDefaults.standard.string(forKey: "alertSound") ?? "Default"
        if savedSound == "Default" {
            content.sound = .default
        } else {
            content.sound = UNNotificationSound(named: UNNotificationSoundName(savedSound))
        }

        content.userInfo = [
            "cardId": cardId.uuidString,
            "deckId": deckId.uuidString,
            "deckName": deckTitle,
            "deckType": "Quiz",
            "isRandom": false,
            "isTutorial": true,
            "progress": "Tutorial \u{2022} Card 1",
            "question": question,
            "cardType": "multiple_choice",
            "options": options,
            "correctAnswer": correctAnswer,
            "hint": hint,
            "matchingLeftItems": [String](),
            "matchingRightItems": [String]()
        ]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(delay, 0.5), repeats: false)
        let request = UNNotificationRequest(
            identifier: "tutorial_\(cardId.uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling tutorial alert: \(error)")
            }
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .sound, .list, .badge])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
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
            if let courseId = userInfo["courseId"] as? String,
               response.actionIdentifier != UNNotificationDismissActionIdentifier {
                CourseProgressManager.shared.reloadFromSharedDefaults()
                let course = CourseCurriculumCatalog.course(for: courseId)
                let sectionId = course.flatMap { CourseLearningStore.shared.snapshot().pendingCheckpoint(course: $0)?.id }
                self.pendingCourseHandoff = CourseHandoff(id: courseId, sectionId: sectionId)
                UserDefaults(suiteName: "group.com.learnalert.shared")?.removeObject(forKey: "handoffCourseId")
                completionHandler()
                return
            }
            let defaults = UserDefaults(suiteName: "group.com.learnalert.shared")
            let fromNotificationUI = defaults?.bool(forKey: "handoffFromNotificationUI") ?? false
            let hasHandoffDeck = defaults?.string(forKey: "handoffDeckId") != nil

            if response.actionIdentifier == "CONTINUE_IN_APP" {
                self.shouldShowNotificationOpeningTip = false
                if hasHandoffDeck {
                    defaults?.removeObject(forKey: "handoffFromNotificationUI")
                    self.consumePendingStudyHandoff()
                } else if let deckString = userInfo["deckId"] as? String,
                          let cardString = userInfo["cardId"] as? String,
                          let deckId = UUID(uuidString: deckString),
                          let cardId = UUID(uuidString: cardString) {
                    self.pendingStudyHandoff = StudyHandoff(
                        deckId: deckId,
                        cardId: cardId,
                        selectedAnswer: nil,
                        wasCorrect: nil,
                        wasGraded: false,
                        wasHintVisible: false
                    )
                } else {
                    self.consumePendingStudyHandoff()
                }
            } else if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
                if fromNotificationUI || hasHandoffDeck {
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
        CourseProgressManager.shared.reloadFromSharedDefaults()
        if let defaults = UserDefaults(suiteName: "group.com.learnalert.shared"), let id = defaults.string(forKey: "handoffCourseId") {
            let course = CourseCurriculumCatalog.course(for: id)
            pendingCourseHandoff = CourseHandoff(id: id, sectionId: course.flatMap { CourseLearningStore.shared.snapshot().pendingCheckpoint(course: $0)?.id })
            defaults.removeObject(forKey: "handoffCourseId")
        }
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
