# LearnAlert

<!-- impeccable:product-schema 1 -->

## Platform

ios

## Users

Learners who bring their own study material or use shared decks, and want short practice sessions inside the app or directly in an expanded notification. No narrower demographic is assumed.

## Product Purpose

Make flashcard practice easy to fit into everyday life. Notifications are interactive study sessions, not just reminders to open the app. In-app study remains a first-class choice.

## Operating Context

Native SwiftUI/SwiftData app with a notification content extension and shared App Group storage. Home holds the personal library and alert scheduling. Discover contains shared decks and language deck discovery; Customize controls notification design; Settings holds preferences and account/data tools. Creation supports manual decks, AI-assisted import, and Anki `.apkg` import.

## Capabilities and Constraints

- Preserve existing card types, text/image/audio fields, Anki rendering, review ratings, and saved study sessions.
- Keep the current shared daily study allowance and the separate in-app/notification review histories intact. Design work must not change learning policy.
- Notification content has a system-controlled size limit; readable content and working answer controls matter more than eliminating every scrolling fallback.
- Apple sign-in enables profiles and sharing. Shared submissions are moderated; developer access does not imply admin-site access.
- Home, Discover, and Settings have established implementations. Older course/path descriptions in README are historical and must be checked against current source before use.

## Brand Commitments

The owner likes the current app design and wants to explore improvements without losing its identity. Preserve the LearnAlert name/logo, calm playful tone, compact presentation, and useful feedback. Avoid decorative clutter, redundant explanations, and excessive sound or animation.

## Evidence on Hand

`LearnAlert/App/ContentView.swift`, `LearnAlert/App/BottomNavigation.swift`, `LearnAlert/UI/DesignSystem.swift`, `LearnAlert/UI/StudyStudioStyle.swift`, and the feature views are the implementation evidence. This baseline was extracted from checkout `3e6d8f7` on 2026-11-08. The accompanying initial review is source-only; it is not a fresh simulator, device, or production certification.

## Product Principles

1. Preserve core study mechanics while improving clarity and ease of use.
2. Prefer small, targeted refinements over replacing an established screen.
3. Keep common actions compact and secondary options progressively disclosed.
4. Support both light and dark appearance and accessible interaction.
5. Distinguish a proposed improvement from a verified problem.
