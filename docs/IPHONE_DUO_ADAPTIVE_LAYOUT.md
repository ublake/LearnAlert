# Duo workspace, Discover expansion and iPad library

## Current page behavior

The combined Home/Discover workspace is exclusive to phone scenes that expose a fold division, including an inactive division while flat. The idiom check gates this product feature; actual size class, container bounds and active reserved geometry continue to choose its layout. iPad and ordinary iPhone scenes use independent full-page Home and Discover tabs.

On an expanded Duo, selecting Discover animates its existing pane across the workspace to fill the page. Selecting Home restores the library and Discover together. The custom Layout interpolates the pane positions and sizes, keeping both child trees mounted. Searches, feed state and open navigation are retained. Hidden Home content stops accepting interaction and leaves the accessibility tree. Reduce Motion disables the pane animation. Continuous full-page Discover content can span a fold, while the dock keeps its existing fold-safe placement.

In folded portrait, Home and Discover remain separate destinations: only the selected page appears below the fold when that region has at least 240 points of height, including when a native horizontal bar shortens it. If the lower region is too small, the largest usable region is used. They never stack above and below the fold. Fully open portrait retains the combined workspace. Landscape book mode can still separate the two columns around a vertical fold. Narrow scenes show the selected page, with both destinations available. The navigation stack remains outside the layout. This avoids ArrangementView's automatic vertical splitting in a tall, flat display and its secondary-view hiding under a horizontal-only axis restriction.

On iPad, Home fills its page. The library uses a single scroll view with a row-major two-column lazy grid when there is at least 700 points of local width: first card left, second right, third on the next row left, fourth right. Existing pinned-first ordering, courses, search, card actions and reorder controls are preserved. Narrow windows and accessibility text sizes use one column to keep cards readable. Duo Home panes remain single-column.

## Adaptive navigation surface

Roomy iPad scenes keep the compact bottom capsule with native Liquid Glass, animated blue selection, multicolor icons and centered creation button. Ordinary iPhones keep the edge-to-edge Islands bar. The floating treatment requires at least 420 points of usable dock width; narrow iPad windows retain the bar. These custom dock surfaces retain their Reduce Transparency and Reduce Motion behavior.

Duo instead uses navigation-container-owned toolbar items. Home, Discover, Customize and Settings form one native group with filled blue symbols for the selected destination. The + creation menu is a separate toolbar item, divided from navigation using the system's fixed ToolbarSpacer so it receives its own circular glass background. Both opt into the vertical axis with axisBehavior(.verticalPreferred); Apple hosts them in the shared system strip beside the status icons on supported poses, and chooses horizontal placement on the inner portrait display. Spacing, glass, available width and overflow belong to the system. The previous content-owned right rail and its 84-point reservation have been removed.

Duo capability is recognized only for phone scenes exposing a fold division or a supported vertical toolbar edge, and retained across display transitions. The edge is a capability signal, not a claim that a vertical bar is currently visible. Root selection, page trees, sheets and notification handoffs retain their existing owners. The system navigation uses the same actions and page selection; no duplicate TabView page trees are introduced. Older systems keep the custom navigation path.

In Duo's vertical-bar context, the root geometry reader extends through the bottom container safe area, allowing the clipped Home and Discover panes to reach the display edge. Horizontal system-bar contexts retain bottom safe-area protection. Keyboard safe areas remain respected. A scoped environment value replaces the old custom-bar clearance in Home, Discover, Customize and Settings with a 24-point end margin only when Duo uses system navigation; iPad and ordinary iPhone spacing stays unchanged.

## Notification behavior retained

Native-deck and course notification content request bounded heights using the active scene's effective coordinate space, rather than the physical screen. The hosted content responds to local width/height and active fold/camera regions; the system retains control of notification width, final height, position and chrome. No notification behavior changed in the Discover/grid refinement.

## Validation on 19 October 2026

- Edge-fill/separate-action refinement: signed Debug app and extension build passed with Xcode 27.1. Installed on Duo iOS 27.1; simulator checks showed Home and Discover content reaching the lower rounded display edge, four navigation icons sharing one pill, and the separate circular + button below. Its menu still exposed Create Deck, Import with AI and Import Anki. This visual refinement used build/runtime checks; the ten-test result below belongs to the preceding native-navigation change.
- Native Duo navigation: signed Debug app and extension test-build passed using Xcode 27.1 (27A9269). Ten AdaptiveWorkspaceTests passed with zero failures, including Duo-only capability gating and a shortened tabletop content region. Result: /tmp/LearnAlert-DuoBuild/Logs/Test/Test-LearnAlert-2026.10.19_12-56-43--0400.xcresult.
- Native Duo simulator checks: landscape showed the navigation group inside the actual system strip beneath the status icons; selecting Discover expanded its page and updated the filled blue icon. The + menu exposed all three creation/import actions and Create Deck opened its existing sheet, dismissed without creating data. A fresh outer-display launch adopted native navigation and Settings worked. Returning to half-folded portrait kept Home alone below the fold with the native horizontal controls at the bottom. Physical hardware, system multitasking, overflow under severe space constraints and VoiceOver remain unverified.
- The custom right-rail prototype below is superseded by native navigation. iPad and ordinary iPhone retain the prior custom navigation paths; this refinement's runtime checks focused on Duo.
- Side-dock refinement: ten AdaptiveWorkspaceTests passed, including physical right-edge bounds, tabletop and camera avoidance, compact-display and short-region fallbacks. Signed app and extension test-build passed using Xcode 27.1. Result: /tmp/LearnAlert-DuoBuild/Logs/Test/Test-LearnAlert-2026.10.19_12-32-13--0400.xcresult. A subsequent build checked the conditional glass-menu cleanup.
- Duo simulator side-dock checks: landscape displayed both pages clear of the right rail; Discover selection still worked. The creation menu opened left and its Create Deck action opened the sheet, which was dismissed without creating a deck. Half-folded portrait kept only Home below the fold with the rail beside it. Opening/closing the menu after cleanup left no glass artifacts. iPad's bottom-dock design is retained in code; it was not rerun for this side-dock refinement because that simulator was shut down.
- Glass dock refinement: signed Debug app and extension build passed with Xcode 27.1. Nine AdaptiveWorkspaceTests passed, including floating-dock eligibility for iPad, inner/outer Duo, ordinary landscape iPhone and narrow windows. Result: /tmp/LearnAlert-DuoBuild/Logs/Test/Test-LearnAlert-2026.10.19_12-20-19--0400.xcresult. A subsequent build also passed after the Reduce Motion adjustment.
- Installed on Duo iOS 27.1 and iPad Air 13-inch (M4) iPadOS 27.0. Simulator checks showed the floating capsule on both, the glass creation actions above the Duo capsule, and working right-side tab selection. Duo was checked in dark appearance and iPad in light appearance. No physical-device glass or ergonomics check was performed.
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
- https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views
- https://developer.apple.com/videos/play/tech-talks/111462/
- https://developer.apple.com/documentation/swiftui/landmarks-refining-the-system-provided-glass-effect-in-toolbars
- /Users/blake/.codex/skills/iphone-duo/references/iPhone-Duo-Developer-Guide.md
