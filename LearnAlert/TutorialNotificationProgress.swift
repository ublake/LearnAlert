import Foundation

/// A matching attempt token lets only the current onboarding quiz finish the tour.
enum TutorialNotificationProgress {
    private static let attemptKey = "onboardingNotificationAttemptID"
    private static let answeredPrefix = "onboardingNotificationAnsweredAttempt."
    private static let cancelledPrefix = "onboardingNotificationCancelledAttempt."
    private static var defaults: UserDefaults? { UserDefaults(suiteName: "group.com.learnalert.shared") }

    static func beginAttempt() -> String {
        let attemptID = UUID().uuidString
        let store = defaults
        store?.set(attemptID, forKey: attemptKey)
        if let store { clearMarkers(in: store, except: attemptID) }
        store?.synchronize()
        return attemptID
    }

    static var hasAnswered: Bool {
        guard let store = defaults else { return false }
        store.synchronize()
        guard let attemptID = store.string(forKey: attemptKey), !attemptID.isEmpty else { return false }
        return store.bool(forKey: answeredPrefix + attemptID)
            && !store.bool(forKey: cancelledPrefix + attemptID)
    }

    static func recordAnswer(attemptID: String?) {
        guard let attemptID, !attemptID.isEmpty, let store = defaults else { return }
        store.synchronize()
        guard store.string(forKey: attemptKey) == attemptID,
              !store.bool(forKey: cancelledPrefix + attemptID) else { return }
        store.set(true, forKey: answeredPrefix + attemptID)
        store.synchronize()
    }

    /// Cancelling an older scheduling request cannot clear a newer attempt.
    static func cancelAttempt(_ attemptID: String) {
        let store = defaults
        store?.set(true, forKey: cancelledPrefix + attemptID)
        store?.synchronize()
    }

    static func reset() {
        let store = defaults
        store?.removeObject(forKey: attemptKey)
        if let store { clearMarkers(in: store) }
        store?.synchronize()
    }

    private static func clearMarkers(in store: UserDefaults, except attemptID: String? = nil) {
        let preserved = Set(attemptID.map { [answeredPrefix + $0, cancelledPrefix + $0] } ?? [])
        for key in store.dictionaryRepresentation().keys
        where (key.hasPrefix(answeredPrefix) || key.hasPrefix(cancelledPrefix)) && !preserved.contains(key) {
            store.removeObject(forKey: key)
        }
    }
}
