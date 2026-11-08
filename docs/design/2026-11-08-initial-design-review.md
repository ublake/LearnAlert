# LearnAlert: initial Impeccable-informed review

Method: native iOS source review, with an independent read-only reviewer. App baseline `3e6d8f7`, inspected 2026-11-08. No simulator, physical-device, screenshot, or performance measurements were taken; the browser detector is not applicable to SwiftUI. This is a focused first pass, not a full accessibility certification or a numerically scored visual critique.

## Recommendation

Keep the current design. The adaptive cool-neutral palette, translucent baby-blue actions, deck artwork, compact library, and existing navigation are coherent. Start with four small usability refinements below; consider the two visual experiments only after looking at real screens. No recommendation has been implemented in this setup.

## What is working

- Home places Alert Schedule and the actual library in the main flow. Active scheduling already exposes the selected deck, Edit/Stop, and a timeline.
- The active Settings preferences use grouped rows, semantic text, native menus/toggles, 64pt minimum row heights, and vertical values at accessibility sizes. Older unused Settings structs are not evidence of the current screen.
- Shared decks already has loading, retry, empty/filter states, incremental pagination, accessible counts, and a detailed preview.
- The dock already has Reduce Motion/Transparency handling and large-content viewers. Library swipe actions have named accessibility alternatives.

## First four improvements

### P2 — Search pinned and unpinned decks consistently

`LearnAlert/App/ContentView.swift:313–323`: `pinnedItems` does not apply `searchText`, while `unpinnedDecks` does. The combined count/empty state therefore includes unrelated pinned decks. This is confirmed source behavior.

Apply the same matching rule to both groups while searching, preserving normal pin ordering when the query is empty. This improves predictability without altering the appearance.

### P2 — Keep small controls visually compact but easier to hit

`LearnAlert/App/ContentView.swift:929,939` uses fixed 40pt empty-library actions; the quick-tip dismiss button at line 2899 has a 26pt frame. The creator link in `LearnAlert/Features/Community/CommunityViews.swift:550` has a 32pt minimum height. Explicit frame sizes are confirmed; actual hit testing has not been measured.

Increase the interactive area to at least 44pt without enlarging the visible icon. Let text-bearing controls grow at larger text sizes instead of enforcing a fixed height.

### P2 — Make the storage warning readable in light mode

`LearnAlert/App/ContentView.swift:352–360` uses white/80%-white warning text on 15%-orange fill over a very light canvas. This is a source-confirmed contrast risk; no rendered-pixel ratio is claimed. The message matters because it warns that flashcards may not persist.

Keep the orange warning icon/border and use adaptive readable ink or an appropriate opaque warning surface. No new decoration is needed.

### P2 — Respect Reduce Motion in the Home tutorial pulse

`HomeAlertSetupCard` in `LearnAlert/App/ContentView.swift:1155–1277` starts a repeating pulse and uses scale/move transitions without consulting Reduce Motion locally. Other components already have the right pattern.

Reuse that pattern: a static highlight or restrained opacity change when Reduce Motion is enabled. Preserve the existing tutorial steps and completion detection.

## Optional visual experiments, not confirmed defects

1. **Navigation recognition.** `LearnAlert/App/BottomNavigation.swift:183–218,292–296` shows only the selected title and uses small fixed title sizes. Compare compact persistent labels inside the existing dock on real screenshots if needed. Do not replace the dock, plus action, or blue identity based on source review alone.
2. **Long shared-deck names.** `LearnAlert/Features/Community/CommunityViews.swift:422–477` places up to five intrinsic count groups beside a two-line title. Test a narrow screen with long names and media-rich decks. A second metadata line at constrained widths may help if crowding is observed; keep the counts and compact presentation.

## Suggested next request

```text
Use Impeccable to fix the four source-backed Home/accessibility findings in the initial review. Preserve the current appearance, card mechanics, and scheduling policy. Build/install to the simulator; I will test interactions.
```

For visual experimentation later, review one named screen at a time using current simulator captures. Screenshots and real-device behavior may change these recommendations; the owner does not need to accept generic aesthetic preferences.

## Implementation follow-up — 2026-11-08

The owner authorized the four concrete fixes while preserving the design. They are now implemented: shared search matching for pinned/unpinned decks, content-driven 44pt minimum control targets, adaptive storage-warning ink, and Reduce Motion-aware tutorial transitions/pulse lifecycle. The optional navigation-label and shared-row layout experiments remain proposals.

Validation: the Debug app and notification extension built successfully with Xcode 27.1 for the iPhone 18 Pro simulator, and the new app was installed and launched without resetting its data. Independent source review found no actionable regressions. The existing project/localization working-tree changes were preserved. Unit and interaction tests were not run; the owner will test the installed build.
