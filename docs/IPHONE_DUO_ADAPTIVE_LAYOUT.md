# Adaptive Duo workspace and notification content

The Home and Discover tabs share a stable two-child layout. Regular-width containers with at least 640 points of width show the library and Discover together; compact windows keep the selected tab. Both children keep their identity during resizing and tab changes between Home and Discover, preserving local search, feed and scroll state. The existing navigation stack stays outside the layout, so an open deck/course remains open across a display transition. No display-name, device-idiom or hinge-angle thresholds choose the layout.

On iOS 27.1+, the layout explicitly queries active reserved divisions in physical local coordinates. A vertical fold leaves a gutter between columns and keeps the custom dock wholly in the Home pane. A horizontal fold uses Home above and Discover below when both have usable height; otherwise the selected page occupies the largest usable region, with both tabs still available. RTL reverses semantic column order once. The same width-driven layout works for iPad windows without requiring fold hardware. Settings, Customize, imports and study features retain their routes.

This uses a custom SwiftUI Layout to keep the requested side-by-side presentation even in a tall, flat inner display. Apple's ArrangementView normally chooses a vertical split in a tall container; restricting it to horizontal can hide its secondary view. The layout owns only geometry and preserves the child view trees. It is not nested inside a scrolling container or NavigationSplitView.

Both native-deck and course notification content now request bounded heights from the active window scene's effective coordinate space, rather than a physical screen's full height. Layout and safe-area changes recalculate that request. Content responds to actual local width/height; compact host regions use compact native-card spacing, large windows constrain text/media to 640 points, and active fold/camera regions constrain the hosted content to a usable local rectangle. Scrollable content remains the fallback when it cannot fit without losing readability. Drawing keeps its requested canvas height when space permits, and is capped in shorter containers rather than requesting an oversized window.

The system owns notification width, final height, position and chrome; preferredContentSize is a request. No public API is assumed to force a notification onto a particular Duo display or prevent the system's dismissal gestures. In-app notification handoff and grading paths are preserved.

## Sources and toolchain

- Apple: https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo
- Apple: https://developer.apple.com/documentation/swiftui/geometryproxy/reservedregions(kind:options:layoutdirectionbehavior:)
- Apple: https://developer.apple.com/documentation/usernotificationsui/customizing-the-appearance-of-notifications
- Local guide: /Users/blake/.codex/skills/iphone-duo/references/iPhone-Duo-Developer-Guide.md

Duo APIs were checked in Xcode 27.1 (27A9269), iPhoneSimulator27.1 SDK public interfaces. New reserved-region calls have iOS 27.1 availability guards; deployment targets are unchanged. The 27.1 beta's documented extension/debugging limitations and physical-device behavior remain separate from app build and simulated geometry evidence.

## Validation on 19 October 2026

- Signed Debug app and notification-extension build passed with Xcode 27.1 (27A9269), iPhoneSimulator27.1 SDK. The iOS 27.2 SDK also exposes the reserved-region declarations; no 27.2 build is claimed.
- All 20 focused simulator tests passed with zero failures/skips on iPhone Duo, iOS 27.1: AdaptiveWorkspaceTests, CourseNotificationFlowTests and NotificationAppearanceTests. Coverage includes both fold axes, RTL, multiple/partial/outside occlusions, small regions, scene height budgets and existing notification handoffs. Result: /tmp/LearnAlert-DuoBuild/Logs/Test/Test-LearnAlert-2026.10.19_10-54-20--0400.xcresult.
- The simulator visually confirmed closed single-page mode, flat-open Home/Discover columns, book-mode fold clearance and dock relocation, and rotated tabletop Home-above-Discover panes. A Discover search stayed expanded and retained its query across closing/reopening.
- iPad Air 13-inch (M4), iPadOS 27.0, visually confirmed the two-pane fallback and successful execution without 27.1-only calls.
- Live expanded notifications on both Duo displays, physical-device fold ergonomics, camera occlusion, VoiceOver and multitasking transitions remain unverified. Geometry tests and an extension build do not establish the system's final notification presentation.
- The Desktop checkout encountered blocking local file reads. Compilation/tests and commit preparation used a clean temporary checkout at /tmp/LearnAlert-DuoClean with the current implementation overlaid. Unrelated local project formatting and Korean artwork changes were excluded from the commit. The original checkout retains its edited source files and its previous Git revision.
