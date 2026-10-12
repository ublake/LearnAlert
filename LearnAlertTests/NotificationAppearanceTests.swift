import Foundation
import Testing
import UserNotifications
@testable import LearnAlert

@MainActor
@Suite("Notification appearance")
struct NotificationAppearanceTests {
    @Test("Test alerts carry all themes, layouts and appearance modes without a shared container")
    func testAlertAppearancePayload() throws {
        let cardId = UUID(), deckId = UUID()
        let stale = NotificationAppearance(theme: .defaultTheme, layout: .automatic, mode: "system")
        for theme in NotificationTheme.allCases {
            for layout in NotificationLayoutMode.allCases {
                for mode in ["system", "light", "dark"] {
                    let selected = NotificationAppearance(theme: theme, layout: layout, mode: mode)
                    let content = NotificationManager.tutorialAlertContent(
                        deckTitle: "Example", question: "Which planet?", options: ["Saturn", "Mars"],
                        correctAnswer: "Saturn", hint: "Rings", cardId: cardId, deckId: deckId, appearance: selected)
                    #expect(NotificationAppearance.resolve(userInfo: content.userInfo, fallback: stale) == selected)
                    #expect(content.categoryIdentifier == "FLASHCARD_TEST")
                    #expect(content.userInfo["cardId"] as? String == cardId.uuidString)
                    #expect(content.userInfo["deckId"] as? String == deckId.uuidString)
                    #expect(content.userInfo["options"] as? [String] == ["Saturn", "Mars"])
                    #expect(content.userInfo["isTutorial"] as? Bool == true)
                    // Local notification payloads must remain valid property lists.
                    _ = try PropertyListSerialization.data(fromPropertyList: content.userInfo, format: .binary, options: 0)
                }
            }
        }
    }

    @Test("Existing notifications keep their saved appearance fallback")
    func legacyPayloadFallback() {
        let saved = NotificationAppearance(theme: .aurora, layout: .compact, mode: "light")
        #expect(NotificationAppearance.resolve(userInfo: ["question": "Existing card"], fallback: saved) == saved)
        #expect(NotificationAppearance.resolve(userInfo: ["notificationCustomTheme": "unknown",
            "notificationCustomLayout": 42, "appearanceMode": "unknown"], fallback: saved) == saved)
        let partial = NotificationAppearance.resolve(userInfo: ["notificationCustomTheme": "sunset"], fallback: saved)
        #expect(partial == NotificationAppearance(theme: .sunset, layout: .compact, mode: "light"))
    }

    @Test("Selected appearance stays attached to the test that was sent")
    func sentAppearanceIsStable() throws {
        let suite = "test-notification-appearance-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("sunset", forKey: "notificationCustomTheme")
        defaults.set("compact", forKey: "notificationCustomLayout")
        defaults.set("dark", forKey: "appearanceMode")
        let sent = NotificationAppearance.saved(in: defaults).userInfo
        defaults.set("midnight", forKey: "notificationCustomTheme")
        #expect(NotificationAppearance.resolve(userInfo: sent, fallback: .saved(in: defaults)) ==
            NotificationAppearance(theme: .sunset, layout: .compact, mode: "dark"))
    }

    @Test("Missing and invalid settings safely use defaults")
    func invalidSettings() throws {
        let suite = "test-notification-defaults-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let expected = NotificationAppearance(theme: .defaultTheme, layout: .automatic, mode: "system")
        #expect(NotificationAppearance.saved(in: defaults) == expected)
        defaults.set("bad", forKey: "notificationCustomTheme")
        defaults.set("bad", forKey: "notificationCustomLayout")
        defaults.set("bad", forKey: "appearanceMode")
        #expect(NotificationAppearance.saved(in: defaults) == expected)
    }
}
