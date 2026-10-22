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
    var wasRevealed: Bool = false
    var wasImageBackViewed: Bool = false
    var notificationRequestID: String? = nil

    var id: String { "\(deckId.uuidString)-\(cardId.uuidString)-\(selectedAnswer ?? "reveal")-\(notificationRequestID ?? "session")" }
}

struct CourseHandoff: Identifiable, Hashable {
    let id: String
    var sectionId: String? = nil
    var assessmentID: String? = nil

    static func destination(course: CourseDefinition, snapshot: CourseLearningSnapshot, requestedSectionId: String? = nil, openPath: Bool = false) -> CourseHandoff {
        if !openPath, let active = snapshot.activeAssessment(courseID: course.id), active.finalizedAt == nil { return CourseHandoff(id: course.id, assessmentID: active.id) }
        guard !openPath, let pending = snapshot.pendingCheckpoint(course: course),
              requestedSectionId == nil || requestedSectionId == pending.id else { return CourseHandoff(id: course.id) }
        return CourseHandoff(id: course.id, sectionId: pending.id)
    }
}

class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    
    @Published var isAuthorized = false
    @Published var pendingCourseHandoff: CourseHandoff?
    @Published var pendingStudyHandoff: StudyHandoff?
    @Published var shouldShowCustomizationTestGuide = false
    
    override convenience init() {
        self.init(registerForNotifications: true)
    }

    init(registerForNotifications: Bool) {
        super.init()
        guard registerForNotifications else { return }
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
        content.body = card.cardType.isReviewOnly ? "Press and hold to review" : "Press and hold to answer"
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
            "answerImageName": card.answerImageName ?? "",
            "optionImageNames": card.optionImageNames,
            "correctOptionIndex": card.resolvedCorrectOptionIndex ?? -1
        ]
        
        let triggerDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: "\(card.id.uuidString)_\(UUID().uuidString)", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error { print("Error scheduling: \(error)") }
            else { AlertTimelineStore.shared.scheduled(request, date: date) }
        }
    }

    func scheduleRealCardAsync(_ card: Flashcard, at date: Date, progress: String) async throws {
        let content = UNMutableNotificationContent()
        let deckName = card.deck?.name ?? "Daily Review"
        let deckType = card.cardType.title

        content.title = "LearnAlert: \(deckName)"
        content.body = card.cardType.isReviewOnly ? "Press and hold to review" : "Press and hold to answer"
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
            "answerImageName": card.answerImageName ?? "",
            "optionImageNames": card.optionImageNames,
            "correctOptionIndex": card.resolvedCorrectOptionIndex ?? -1
        ]

        let triggerDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: "\(card.id.uuidString)_\(UUID().uuidString)", content: content, trigger: trigger)

        try await UNUserNotificationCenter.current().add(request)
        AlertTimelineStore.shared.scheduled(request, date: date)
    }
    
    func scheduleTutorialAlert(
        deckTitle: String,
        question: String,
        options: [String],
        correctAnswer: String,
        hint: String,
        cardId: UUID = UUID(),
        deckId: UUID = UUID(),
        delay: TimeInterval = 0.8,
        appearance: NotificationAppearance = .saved(),
        isCustomizationTest: Bool = false,
        completion: ((Error?) -> Void)? = nil
    ) {
        setupCategories()
        let content = Self.tutorialAlertContent(deckTitle: deckTitle, question: question, options: options,
            correctAnswer: correctAnswer, hint: hint, cardId: cardId, deckId: deckId, appearance: appearance,
            isCustomizationTest: isCustomizationTest)

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
            completion?(error)
        }
    }

    static func tutorialAlertContent(
        deckTitle: String, question: String, options: [String], correctAnswer: String, hint: String,
        cardId: UUID, deckId: UUID, appearance: NotificationAppearance, isCustomizationTest: Bool = false
    ) -> UNMutableNotificationContent {
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
            "isCustomizationTest": isCustomizationTest,
            "progress": "Tutorial \u{2022} Card 1",
            "question": question,
            "cardType": "multiple_choice",
            "options": options,
            "correctAnswer": correctAnswer,
            "hint": hint,
            "matchingLeftItems": [String](),
            "matchingRightItems": [String]()
        ]

        content.userInfo.merge(appearance.userInfo) { _, selected in selected }

        return content
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        AlertTimelineStore.shared.delivered(notification)
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
            if self.handleCustomizationTestResponse(content: response.notification.request.content,
                actionIdentifier: response.actionIdentifier,
                defaults: UserDefaults(suiteName: "group.com.learnalert.shared")) {
                completionHandler()
                return
            }
            let requestID = response.notification.request.identifier
            AlertTimelineStore.shared.delivered(response.notification)
            if response.actionIdentifier == UNNotificationDismissActionIdentifier {
                AlertTimelineStore.shared.dismissed(requestID)
                completionHandler()
                return
            }
            AlertTimelineStore.shared.opened(requestID)
            if let courseId = userInfo["courseId"] as? String,
               response.actionIdentifier != UNNotificationDismissActionIdentifier {
                CourseProgressManager.shared.reloadFromSharedDefaults()
                let defaults = UserDefaults(suiteName: "group.com.learnalert.shared")
                let hasExplicitHandoff = defaults?.string(forKey: "handoffCourseId") == courseId
                if let course = CourseCurriculumCatalog.course(for: courseId),
                   hasExplicitHandoff || self.pendingCourseHandoff?.id != courseId {
                    self.pendingCourseHandoff = CourseHandoff.destination(course: course, snapshot: CourseLearningStore.shared.snapshot(),
                        requestedSectionId: hasExplicitHandoff ? defaults?.string(forKey: "handoffCourseSectionId") : userInfo["courseCheckpointSectionId"] as? String,
                        openPath: hasExplicitHandoff && defaults?.bool(forKey: "handoffCourseOpenPath") == true)
                }
                ["handoffCourseId", "handoffCourseSectionId", "handoffCourseOpenPath"].forEach { defaults?.removeObject(forKey: $0) }
                completionHandler()
                return
            }
            let defaults = UserDefaults(suiteName: "group.com.learnalert.shared")
            let fromNotificationUI = defaults?.bool(forKey: "handoffFromNotificationUI") ?? false
            let hasHandoffDeck = defaults?.string(forKey: "handoffDeckId") != nil
            if defaults?.string(forKey: "handoffDeckId") == userInfo["deckId"] as? String {
                defaults?.set(requestID, forKey: "handoffNotificationRequestID")
            }

            if response.actionIdentifier == "CONTINUE_IN_APP" {
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
                        wasHintVisible: false, notificationRequestID: requestID
                    )
                } else {
                    self.consumePendingStudyHandoff()
                }
            } else if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
                if fromNotificationUI || hasHandoffDeck {
                    defaults?.removeObject(forKey: "handoffFromNotificationUI")
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
                        wasHintVisible: false, notificationRequestID: requestID
                    )
                } else {
                    self.consumePendingStudyHandoff()
                }
            } else {
                self.consumePendingStudyHandoff()
            }
            completionHandler()
        }
    }

    /// Preview IDs are deliberately synthetic and must never become study destinations.
    @MainActor
    @discardableResult
    func handleCustomizationTestResponse(content: UNNotificationContent, actionIdentifier: String,
        defaults: UserDefaults?) -> Bool {
        guard content.categoryIdentifier == "FLASHCARD_TEST",
              content.userInfo["isCustomizationTest"] as? Bool == true ||
                (content.userInfo["isCustomizationTest"] == nil &&
                 content.userInfo["deckName"] as? String == "Example") else { return false }
        guard actionIdentifier != UNNotificationDismissActionIdentifier else { return true }

        // Older extensions wrote preview handoffs on appearance. Remove only this alert's
        // synthetic IDs, leaving any unrelated real study handoff untouched.
        if defaults?.string(forKey: "handoffDeckId") == content.userInfo["deckId"] as? String,
           defaults?.string(forKey: "handoffCardId") == content.userInfo["cardId"] as? String {
            ["handoffDeckId", "handoffCardId", "handoffSelectedAnswer", "handoffWasCorrect",
             "handoffWasGraded", "handoffHintVisible", "handoffWasRevealed", "handoffFromNotificationUI", "handoffTimestamp"]
                .forEach { defaults?.removeObject(forKey: $0) }
        }
        if pendingStudyHandoff?.deckId.uuidString == content.userInfo["deckId"] as? String {
            pendingStudyHandoff = nil
        }
        shouldShowCustomizationTestGuide = true
        return true
    }

    @MainActor
    func consumePendingStudyHandoff(
        defaults: UserDefaults? = UserDefaults(suiteName: "group.com.learnalert.shared"),
        reloadCourseProgress: @MainActor () -> Void = { CourseProgressManager.shared.reloadFromSharedDefaults() }
    ) {
        guard let defaults else { return }
        // Most launches have no handoff. Loading every course's progress here
        // makes an ordinary launch pay for notification-only routing work.
        if let id = defaults.string(forKey: "handoffCourseId") {
            if let course = CourseCurriculumCatalog.course(for: id) {
                reloadCourseProgress()
                pendingCourseHandoff = CourseHandoff.destination(course: course, snapshot: CourseLearningStore.shared.snapshot(),
                    requestedSectionId: defaults.string(forKey: "handoffCourseSectionId"), openPath: defaults.bool(forKey: "handoffCourseOpenPath"))
            }
            ["handoffCourseId", "handoffCourseSectionId", "handoffCourseOpenPath"].forEach { defaults.removeObject(forKey: $0) }
        }
        guard let deckString = defaults.string(forKey: "handoffDeckId"),
              let cardString = defaults.string(forKey: "handoffCardId"),
              let deckId = UUID(uuidString: deckString),
              let cardId = UUID(uuidString: cardString) else { return }

        pendingStudyHandoff = StudyHandoff(
            deckId: deckId,
            cardId: cardId,
            selectedAnswer: defaults.string(forKey: "handoffSelectedAnswer"),
            wasCorrect: defaults.object(forKey: "handoffWasCorrect") as? Bool,
            wasGraded: defaults.bool(forKey: "handoffWasGraded"),
            wasHintVisible: defaults.bool(forKey: "handoffHintVisible"),
            wasRevealed: defaults.bool(forKey: "handoffWasRevealed"),
            wasImageBackViewed: defaults.bool(forKey: "handoffImageBackViewed"),
            notificationRequestID: defaults.string(forKey: "handoffNotificationRequestID")
        )

        [
            "handoffDeckId", "handoffCardId", "handoffSelectedAnswer",
            "handoffWasCorrect", "handoffWasGraded", "handoffHintVisible", "handoffWasRevealed", "handoffImageBackViewed",
            "handoffFromNotificationUI", "handoffTimestamp", "handoffNotificationRequestID"
        ].forEach(defaults.removeObject(forKey:))
    }

    @MainActor
    func clearStudyHandoff() {
        pendingStudyHandoff = nil
    }
}
