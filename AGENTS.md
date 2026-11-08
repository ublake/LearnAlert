# LearnAlert agent guidance

## Existing product and design

Read `PRODUCT.md` and `DESIGN.md` before UI work. They record the current product and the owner's approved design, not a proposed redesign. Current implementation wins if an extracted value has drifted; report the discrepancy instead of silently rewriting the identity.

The owner likes the existing app. Preserve the baby-blue accent, light/dark surfaces, compact layouts, deck artwork, and custom navigation unless the requested change concerns them. Generic design-skill preferences do not authorize replacing these choices. A polish request is a refinement, not a redesign.

For UI design work, use the project skill at `.agents/skills/impeccable/SKILL.md`. Start its context loader from this repository:

```sh
IMPECCABLE_NO_TELEMETRY=1 IMPECCABLE_NO_UPDATE_CHECK=1 IMPECCABLE_NO_STALENESS_CHECK=1 IMPECCABLE_HOOK_DISABLED=1 \
  sh .agents/skills/impeccable/scripts/impeccable context --target LearnAlert/App/ContentView.swift
```

Use the actual requested source file as `--target`. Apply native iOS guidance; the HTML/CSS detector does not validate SwiftUI. Review-only requests produce findings without editing product code. Explicit implementation requests already authorize the corresponding scoped changes.

The engine's web-oriented `hasVisualImplementation` heuristic may report false for this SwiftUI repository. The source, `PRODUCT.md`, and `DESIGN.md` establish that this is an existing native app; that flag is not permission to treat it as an empty project.

This is a skill-only installation: automatic hooks and browser live editing are not configured. Do not enable them as a side effect of a design task. Keep feedback and loading states honest; never present source review or a mockup as simulator/device evidence.

## Build and data boundaries

- Open `LearnAlert.xcworkspace`, not the standalone project. Preserve existing CocoaPods configuration.
- When app code changes, build/install to the requested simulator and let the owner do interaction testing unless they request otherwise. Do not execute tests merely because a skill recommends them.
- UI refinement must preserve card solving, scheduling and daily limits, separate study histories, notification handoff, persistence, and account/moderation permissions.
- Leave unrelated working-tree changes alone. Do not submit App Store review or deploy unrelated services.

Setup/provenance and examples: `docs/design/impeccable-setup.md`.
