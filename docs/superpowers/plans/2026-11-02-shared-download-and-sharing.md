# Shared deck transfer and sharing layout

The native downloader currently awaits each image/audio request serially and performs image rendering, audio validation and file writes on MainActor. Anki aliases can fetch the same media ID repeatedly. Optimize those bottlenecks without claiming a measured live speedup.

- Plan distinct media IDs across legacy fields, field media and Anki mappings. Keep four requests in flight, refilling as each completes. Use a storage actor for existing image/audio processing and atomic writes; reconstruct cards in source order.
- Preserve API/detail count behavior, request authorization/moderation, per-file limits and the existing aggregate Anki limit. Add no new download count or general size restrictions. Keep a cleanup ledger until all cancelled/failed child tasks have settled.
- Embed Add to Library and its download progress beneath the card/download counts, above previews, in normal scroll content. Remove its floating bottom inset.
- Raise only Discover's upload button10 points. Start its share sheet with no selected deck. A valid initialDeckID from a deck's settings still selects that deck once.
- Gate share presentation through the existing Apple sign-in/profile sheet. Successful completion opens sharing after authentication dismisses; cancellation and signout clear the request. Preserve consent, description and publish validation.

Build the app and extension and install/launch the simulator for the user to check. Do not run app UI tests or production download benchmarks. Preserve preexisting catalog edits.

Verification: Debug app and extension build passed with Xcode27.1; only the existing App Intents metadata warning remained. Source reviews covered transfer cancellation/cleanup/aliases and auth/cancel/signout presentation; final fixes removed unintended new download limits and cleared stale signout intents. Compiler extraction found no missing strings. No UI tests or live speed benchmarks were run. Changed files were byte-identical in the local build workspace used to avoid Desktop file coordination stalls. Preexisting localization changes were excluded from staging.
