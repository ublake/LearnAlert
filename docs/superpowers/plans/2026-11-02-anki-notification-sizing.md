# Content-sized Anki notifications

The notification currently requests the maximum Anki window height, stretches its card to the granted viewport, and centers HTML inside that full frame. A short word therefore occupies a tall card. Feeding that capped frame back into the preferred size would reintroduce the earlier resize loop.

- Report the active HTML wrapper's intrinsic content height, including body padding, independently of its centered position and the native viewport. Observe reflow, fonts, media and content changes; reject stale document reports.
- Notification-only content sizing uses a stable media cap, rather than viewport-relative image heights. Keep normal in-app study and deck previews unchanged.
- Request intrinsic HTML plus measured header/footer/status/padding/spacing, capped by the existing screen-derived ceiling. Separately cap the visible card to the actual viewport so long HTML can scroll without pushing controls below it.
- Remove the forced full-height Anki stack. Choose its compact chrome by width, so a shrinking window cannot change its own layout threshold.
- Preserve imported content, styling, tap-to-flip, audio, grading, schedules and progress. No stored data migrations.

Verification: inspect the integrated diff, build the app and extension, and install/launch on the existing iPhone 18 Pro simulator. The user requested simulator builds and will perform the visual notification checks; do not run automated or manual app UI tests.

App and extension Debug simulator builds passed with Xcode 27.1. JavaScript syntax and git whitespace checks passed. Independent source reviews covered renderer message lifecycle, geometry feedback, and reserved controls; no automated or manual app UI tests were run. The build used byte-identical changed source in a temporary local workspace to avoid the Desktop File Provider coordination stall, without changing the authoritative project setup. Existing catalog edits were preserved and excluded from staging.
