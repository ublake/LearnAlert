# Duo workspace, Discover expansion and iPad library

## Current page behavior

The combined Home/Discover workspace is exclusive to phone scenes that expose a fold division, including an inactive division while flat. The idiom check gates this product feature; actual size class, container bounds and active reserved geometry continue to choose its layout. iPad and ordinary iPhone scenes use independent full-page Home and Discover tabs.

On an expanded Duo, selecting Discover animates its existing pane across the workspace to fill the page. Selecting Home restores the library and Discover together. The custom Layout interpolates the pane positions and sizes, keeping both child trees mounted. Searches, feed state and open navigation are retained. Hidden Home content stops accepting interaction and leaves the accessibility tree. Reduce Motion disables the pane animation. Continuous full-page Discover content can span a fold, while the dock keeps its existing fold-safe placement.

In folded portrait, Home and Discover remain separate tabs: only the selected page appears in the largest usable region, with the dock in that same region. They never stack above and below the fold. Fully open portrait retains the combined workspace. Landscape book mode can still separate the two columns around a vertical fold and keep the dock in the Home pane. Narrow scenes show the selected page, with both tabs available. The navigation stack remains outside the layout. This avoids ArrangementView's automatic vertical splitting in a tall, flat display and its secondary-view hiding under a horizontal-only axis restriction.

On iPad, Home fills its page. The library uses a single scroll view with a row-major two-column lazy grid when there is at least 700 points of local width: first card left, second right, third on the next row left, fourth right. Existing pinned-first ordering, courses, search, card actions and reorder controls are preserved. Narrow windows and accessibility text sizes use one column to keep cards readable. Duo Home panes remain single-column.

## Notification behavior retained

Native-deck and course notification content request bounded heights using the active scene's effective coordinate space, rather than the physical screen. The hosted content responds to local width/height and active fold/camera regions; the system retains control of notification width, final height, position and chrome. No notification behavior changed in the Discover/grid refinement.

## Validation on 19 October 2026

- Signed Debug app and notification-extension build passed using Xcode 27.1 (27A9269), iPhoneSimulator27.1 SDK. Deployment targets remain unchanged.
- Eight AdaptiveWorkspaceTests passed with zero failures/skips on iPhone Duo, iOS 27.1 after the folded-portrait change. Coverage includes separate portrait tabs for both fold axes, Duo eligibility, landscape fold geometry, RTL, intermediate/full Discover frames, local iPad grid limits, occlusions and notification height budgets. Result: /tmp/LearnAlert-DuoBuild/Logs/Test/Test-LearnAlert-2026.10.19_12-13-58--0400.xcresult.
- Duo simulator: half-folded portrait showed only Home in the lower usable region; selecting Discover replaced it with the community feed. Opening the display and selecting Home restored both panes. The previous refinement also verified Discover's full-page expansion.
- iPad Air 13-inch (M4), iPadOS 27.0: Home occupied the full page. Four local sample decks visibly appeared as Layout 1 / Layout 2, then Layout 3 / Layout 4 in the next row. No alerts were scheduled for these samples.
- The previous implementation's 20 notification/layout regression tests passed before this refinement. Live notification presentation on physical Duo hardware, device ergonomics, camera occlusion and multitasking remain unverified.
- The Desktop checkout has blocked local file reads. Builds and commits use /tmp/LearnAlert-DuoClean. This task's source files are mirrored atomically to /Users/blake/Desktop/LearnAlert; its original Git revision and unrelated project-formatting/Korean-artwork edits are preserved.

## References

- https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo
- https://developer.apple.com/documentation/swiftui/geometryproxy/reservedregions(kind:options:layoutdirectionbehavior:)
- https://developer.apple.com/documentation/usernotificationsui/customizing-the-appearance-of-notifications
- /Users/blake/.codex/skills/iphone-duo/references/iPhone-Duo-Developer-Guide.md
