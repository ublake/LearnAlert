---
name: LearnAlert iOS
description: Existing compact study interface; preserve and refine its identity.
colors:
  accent-light: "rgb(65% 81% 95% / 88%)"
  accent-dark: "rgb(66% 83% 97% / 88%)"
  accent-ink: "rgb(10.5% 22.5% 34%)"
  canvas-light: "rgb(96.9% 97.7% 98.6%)"
  canvas-dark: "rgb(7.5% 8% 9.5%)"
  surface-light: "#ffffff"
  surface-dark: "rgb(14% 15% 18%)"
  inset-light: "rgb(92.9% 95.3% 97.7%)"
  inset-dark: "rgb(19% 20% 24%)"
  text-light: "rgb(15% 18% 21%)"
  text-dark: "rgb(95% 96% 98%)"
  border-light: "rgb(65% 73% 82%)"
  border-dark: "rgb(100% 100% 100% / 7%)"
rounded:
  card: "20pt"
  editorial: "18pt"
  field: "14pt"
spacing:
  screen: "20pt"
  section: "24pt"
  card: "16pt"
  grid: "12pt"
---

# Design System: LearnAlert

## Overview

This records the existing interface, not a new visual direction. The owner's explicit preference is to keep its design. Cool neutral surfaces, translucent baby-blue actions, rounded containers, playful deck artwork, and familiar SF Symbols give it a calm study-tool identity. Improvements should feel like the same app becoming clearer.

Extracted on 2026-11-08 from `3e6d8f7`. Source values and current semantic SwiftUI styles are authoritative. Spacing entries above describe recurring conventions, not a new token API. No rendered screenshot was captured for this baseline.

## Colors

`LearnAlertStyle` in `LearnAlert/UI/DesignSystem.swift` owns the adaptive palette. `appAccent` is a translucent fill; `appAccentInk` and `appAccentForeground` provide readable action text. Do not use a pale fill as small text on a light canvas. `courseCanvas`, `courseSurface`, and `insetSurface` provide the neutral hierarchy in both appearances. Existing deck/category/notification-theme palettes keep their own roles.

Use the exact source decimals above instead of inventing a replacement palette. Preserve the stronger light-mode outlines. Evaluate actual composited colors before claiming a contrast ratio.

## Typography

Active Home, Settings, and shared-deck rows primarily use system semantic text styles. `StudyStudioStyle` and selected display/Discover elements also use Poppins with relative text styles. This is the current mixed system: preserve it during refinement rather than applying a blanket font replacement. Use semantic or relative text sizing and let content grow at accessibility sizes.

## Layout

Home places the logo/tools above Alert Schedule and Your library. Decks use a compact one-column phone list and adaptive larger-screen layouts. Keep pinned items in the library and secondary scheduling actions in their existing swipe affordance. Avoid adding large page titles, permanent search fields, or progress decorations the owner removed.

Four destinations are Home, Discover, Customize, and Settings. The central plus is a creation action. Preserve the existing dock geometry, keyboard behavior, and separate large-screen/Duo adaptations. Do not replace it with a stock tab bar merely because generic guidance prefers one.

## Elevation & Depth

Favor borders and tonal separation. The owner explicitly rejected added shadows around Home's library and scheduling boxes. Shared helpers still have shadow defaults; retain intentional existing effects elsewhere, but do not reintroduce those rejected Home shadows as "polish." System glass/material is already used for appropriate controls.

## Shapes

Common surfaces use continuous rounded rectangles: default app cards 20pt, editorial containers 18pt, fields 14pt. These are observed defaults, not a reason to normalize every existing shape. Keep the distinctive deck artwork and central creation button.

## Components

- `HomeAlertSetupCard`: selected deck, scheduling controls, and active timeline; preserve Edit/Stop and all scheduling policy.
- `HomeStudyCard` / `DeckCreatureView`: deck identity and compact library affordances; no new decorative statistics by default.
- `BottomNavigationBar` / `NavigationDock`: existing four destinations, selected state, creation menu, accessibility behavior, and adaptive layouts.
- `SettingsPreferencesGroup` / `SettingsGroupedRow`: active grouped preferences, native menus/toggles, semantic text, accessible stacking, account tools, and role-gated developer section. Do not mistake older unused Settings structs for the active screen.
- `CommunityDeckCard`: compact title plus relevant count icons; preserve search/filter/paging behavior and conditional media counts.
- `CommunityDeckPreviewSheet`: detailed media preview, creator/profile link, appreciation, and embedded add-to-library action.
- `NotificationDesignTheme`: six existing theme choices; keep theme styling separate from card-solving mechanics.

## Do's and Don'ts

- Do preserve baby blue, cool neutrals, light/dark parity, readable outlines, existing art, and the current navigation identity.
- Do distinguish visual size from hit area: compact controls can retain at least a 44pt interactive area.
- Do honor Reduce Motion and preserve visible non-color feedback.
- Do use current source and actual simulator captures for future visual conclusions.
- Don't replace branded fonts/navigation, add new shadows, or change features under a general polish request.
- Don't treat a web detector's empty SwiftUI result as evidence of quality.
- Don't let design work change study budgets, card grading, persistence, authentication, or moderation.
