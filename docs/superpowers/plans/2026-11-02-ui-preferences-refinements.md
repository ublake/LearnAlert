# Library, Sharing and Preferences Refinements

> **For agentic workers:** Use the user-directed requirements below as the scope. Independent UI areas may be implemented in parallel; integration and verification stay sequential.

**Goal:** Reduce visual clutter in library, sharing and customization, and add a functional native-name language picker.
**Architecture:** Reuse existing SwiftUI views, background deck preview summaries, SafariView sheets and localization catalogs. Persist language choice in the existing shared app-group preferences, then apply that locale to SwiftUI and computed localized strings without changing view identity.
**Tech Stack:** SwiftUI, Foundation localization resources, SwiftData, UserDefaults, UserNotificationsUI.
**Spec:** The user's explicit bullet list in the current request; routine dimensions are recorded below.

## Global constraints

- Preserve deck contents, card IDs, separate practice/notification progress and schedule settings.
- Keep description and explicit consent required for sharing; retain all publish/auth/media guards.
- Terms and Privacy taps open existing SFSafariViewController sheets, never an external browser.
- Remove appearance/layout controls only from Customize; existing preferences and rendering support stay intact.
- Initial ringtone becomes Comet when no preference exists; keep the System default option, Comet's name, saved choices and the five legacy filename mappings unchanged.
- Preserve the two preexisting modified translation catalogs; stage only translations added by this task.
- Build/install/launch the iPhone 18 Pro simulator for the user to check. No automated app UI testing.

## Tasks

- [x] Remove Home due/last-studied captions and their sole background work; reduce row top/bottom padding from 14 to 12 points.
- [x] Put a noninteractive last-studied line directly below Reset Progress in the deck menu. Reuse the existing background card-preview pass and actual review/practice history; refresh after background use.
- [x] Replace sharing rules with one checkbox sentence; make both policy links blue and present SafariView sheets. Use a 44-point submit button with 12-point corners and cleaner category/description fields; remove the required suffix.
- [x] Unmount Customize appearance/layout selectors and select Comet for unconfigured sound preferences without renaming options or remapping old alert3.wav.
- [x] Add a compact language picker first in Preferences: System default, English, Español, Português (Brasil), Français, Deutsch, 日本語, 한국어.
- [x] Apply the selected locale consistently to literal SwiftUI text, computed labels, resources and new notification views; retain navigation/session identities. Make cached translated option arrays refreshable.
- [x] Preserve compiler extraction by using typed LocalizedStringResource helpers. Make Anki import diagnostics use the selected locale within that import's task context only.
- [x] Add only the new interface translations, preserve the existing catalog edits, and validate formatting and link destinations.
- [x] Build, review the final changes, and install/launch the simulator. Deliver with the user-authorized commit/push.

## Review focus

- Menu statistics must use real study dates, not saved checkpoint timestamps, and must not slow large-deck opening.
- Policy link taps must not toggle consent or bypass disabled submit conditions.
- Native language names must remain verbatim; language changes must not translate authored learning content or restart the app.
- Notification and import text must follow the same shared choice while concurrent tasks retain their own locale context.
- Comet's new initial selection must preserve explicit System default/saved choices and old bundled sound aliases.

## Verification

- Debug simulator build passed for the app and notification extension with Xcode 27.1; no compiler errors. App Intents metadata emits its existing no-framework warning.
- Strict Swift 5 MainActor-default concurrency typecheck passed for both shared locale helpers. Language-change notifications deliver on the main queue before publishing UI updates.
- Standalone isolated locale fixtures passed selection/interpolation, observation invalidation, persistence/native names, dates and independent Anki task-local scopes. No app preferences were changed by those fixtures.
- Compiler extraction has no missing interface keys. Eleven new keys have all six translations, valid format arguments and unchanged policy URLs; compiled resources contain them in both app and extension.
- Every preexisting translation entry was preserved. Only the eleven task additions are staged from the catalog; unrelated catalog changes remain local.
- Independent reviews covered library performance/statistics, consent/publishing guards, ringtone compatibility and locale integration. No automated app UI tests were run.
- Installed and launched on the existing iPhone 18 Pro simulator for the user’s visual checks.
