# Explicit notification handoff and a shared daily allowance

The extension saves UI state on appearance and answer changes. Ordinary app startup currently consumes that cache as navigation intent, reopening an old answered card. In-app study also queues full decks without the notification journal's20-answer cap.

The user confirmed20 answered questions total per day across notifications and in-app study, with their review histories remaining separate. Preserve full deck queues, card identities, in-app bookmarks, Anki ratings and pending short reviews.

- Only a default/Continue response can authorize opening the stored card, and only for its exact notification request. Ordinary launch/foreground must never consume passive UI state. Explicit Open app to practice carries a separate request-scoped selected-deck intent, without replaying a notification card or rating.
- Add an explicit Done action after grading/batch completion. Clear only that notification's cached state and delivered listing, then dismiss its extension UI. Preserve tutorial flow and future alerts.
- Extend the existing file-locked daily journal with backward-compatible practice events. Count each actual graded answer, including repeats, toward one shared20. Reserve before Anki persistence, roll back failures, and recover interrupted practice reservations against practice review state.
- Display today's progress out of20 in-app, gate every answer path, and pause at the cap without marking the full saved deck session complete. Resume remaining queues on another day. Refresh on activation/day/time changes and before answering. Reconcile today's pending alerts at the cap while preserving future schedules.
- Keep all interface languages covered; preserve unrelated catalog edits. Build/install/launch the simulator for the user to check; do not run app UI tests.

Apple's installed iOS27.1 UserNotificationsUI header declares performNotificationDefaultAction (opens the host with a default notification response) and dismissNotificationContentExtension. removeDeliveredNotifications(withIdentifiers:) removes only the requested delivered alert; it does not remove future scheduled requests.

Verification: app and extension Debug simulator build passed with Xcode27.1; only the existing no-AppIntents metadata warning remained. Compiler extraction has no missing keys; the new daily-limit explanation is bundled in all six translations. Source reviews covered exact-request handoff authorization, independent practice intent, all solve entry points, reserve/save/rollback, orphan retries, next-day bookmarks and settlement before resets. No app UI tests were run. Changed source was byte-identical in the local build copy used to avoid the Desktop coordination stall; original project configuration and unrelated catalog edits were preserved.
