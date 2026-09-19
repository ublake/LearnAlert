import Foundation
import UserNotifications

class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    
    @Published var isAuthorized = false
    
    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        checkPermission()
    }
    
    func checkPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                self.isAuthorized = granted
                if granted {
                    self.setupCategories()
                }
            }
        }
    }
    
    // Registers the category so iOS knows this notification gets a custom UI
    private func setupCategories() {
        // The "Reveal" action button
        let gotItAction = UNNotificationAction(identifier: "GOT_IT_ACTION", title: "I knew it!", options: [])
        let missedItAction = UNNotificationAction(identifier: "MISSED_IT_ACTION", title: "Missed it", options: [.destructive])
        
        let revealCategory = UNNotificationCategory(
            identifier: "FLASHCARD_REVEAL",
            actions: [gotItAction, missedItAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([revealCategory])
    }
    
    // The Test Button Function
    func scheduleTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "LearnAlert Pop Quiz"
        content.body = "Hold down to reveal the answer..."
        content.sound = .default
        
        // This MUST match the identifier in the category above, and in the Extension's Info.plist
        content.categoryIdentifier = "FLASHCARD_REVEAL" 
        
        // Passing data to our custom UI extension
        content.userInfo = [
            "question": "What is the powerhouse of the cell?",
            "answer": "The Mitochondria",
            "theme": "dark"
        ]
        
        // Schedule for 3 seconds from now so you can go to the home screen and see it
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error { print("Error scheduling: \(error)") }
            else { print("Scheduled! Go to home screen.") }
        }
    }
    
    // Required to show notifications while the app is actively open
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}