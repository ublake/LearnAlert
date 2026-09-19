# Xcode Security Audit — Plan
**Project:** LearnAlert · 3 targets · languages: Swift
**Generated:** 2026-09-12

Edit the items below — set what steps to perform now, or leave them unchecked to defer them. Questions about any item, or want a more detailed plan? Just ask — I'll answer, and can expand this plan on the points you care about before you decide.

## Phases
- **Enhanced Security** — the project's runtime-protection bundle. Apply to: LearnAlert. (Group — check the sub-items below.)
  - [x] **[Enable Enhanced Security](doc://com.apple.documentation/documentation/Xcode/enabling-enhanced-security-for-your-app)** — sets `ENABLE_ENHANCED_SECURITY=YES` at the project level. (Your project doesn't use a project-level xcconfig — I'll walk you through enabling it in Xcode's Build Settings UI yourself, then verify by reading project file.)
  - [x] **[Update entitlements](doc://com.apple.documentation/documentation/BundleResources/Entitlements/com.apple.security.hardened-process)** — adds the hardened-process entitlement family per target (Memory Safety, Runtime Protections).
  - [x] **[Hardware memory tagging](doc://com.apple.documentation/documentation/BundleResources/Entitlements/com.apple.security.hardened-process.checked-allocations)** — adds the hardware memory tagging entitlement, in soft mode, on supported platforms (LearnAlert).
  - [x] **[Checked pointer arithmetic](doc://com.apple.documentation/documentation/BundleResources/Entitlements/com.apple.security.hardened-process.checked-allocations.enforce-checked-pointer-arithmetic-overflow)** — adds the arm64e.x1 slice and the entitlement to enforce pointer-arithmetic overflow checking (LearnAlert). Run time enforcement requires hardware memory tagging enabled. Latent pointer-arithmetic bugs will terminate the app on capable hardware.
- [ ] **Additional diagnostic settings** — extra opt-in warnings/checkers beyond the defaults. Off by default: they surface more findings to review and can be noisier (more false positives).

## Decision document
The skill creates or updates `xcode-security-settings.md` to record every setting decision (kept, deferred, disabled, with rationale). Edit the path to relocate.
- Path: `xcode-security-settings.md`
