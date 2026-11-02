# Developer Settings Implementation Plan

> **For agentic workers:** Use subagent-driven-development for independent publishing and diagnostics changes; root integrates the Settings/session changes and simulator build.

**Goal:** Backend-granted developers get a private category at the bottom of app Settings, including their Anki-upload preference and useful diagnostic tools.

**Architecture:** Reuse the existing owner profile flags and authenticated developer-options endpoint. Settings and sharing screens observe CommunitySession; privileged publishing independently reads current server permissions. No local role grant or new backend privilege is introduced.

**Tech Stack:** SwiftUI, SwiftData, UserNotifications, existing Cloudflare community API.

**Spec:** User request in this chat; existing role manager and owner-profile API.

## Global Constraints

- Preserve ordinary accounts, imported-deck provenance, moderation and existing content limits.
- Developer status never grants admin-site access or bypasses server authorization.
- Preserve the two pre-existing localization edits.
- Build and install to the iPhone 18 Pro simulator; the user will perform runtime checks.

## Review Focus

- Revoked/signed-out accounts lose developer tools and cannot re-enable uploads.
- Settings profile refresh cannot overwrite a newer saved preference.
- Anki upload eligibility is consistent across library menus, picker and publishing preflight.
- Built-in and downloaded shared decks remain ineligible for republishing.
- Diagnostics reveal counts/configuration, never credentials or card content, and avoid loading large card relationships.

## Tasks

- [x] Inspect existing role, publishing and hidden-tool code.
- [x] Add DeveloperSettingsSection with Anki toggle, access refresh, System Check, Sound Studio and diagnostics.
- [x] Refresh roles on Settings appearance/foreground and protect option writes from stale profile reads/account changes.
- [x] Connect sharing menus/forms and fresh-server upload preflight to the existing capability.
- [x] Add sanitized diagnostics and repair System Check's storage claims/counting.
- [x] Review authorization boundaries and final diff.
- [x] Build/install simulator without running UI or unit tests.
- [x] Commit and push task changes.

Validation: final Xcode 27.1 simulator build succeeded, then installed on iPhone 18 Pro E9DFC12E-C493-4762-976E-268B3346BD38. Independent source review found a delayed preference-save race; the fix discards an older response and re-reads the current server profile. Follow-up review found no remaining actionable issue. No UI or unit tests were run, per the user's build-only preference.
