# Localization verification — 2026-11-02

Implemented English plus Spanish, Brazilian Portuguese, French, German, Japanese, and Korean. Each new language covers all 1,416 translatable interface keys; additional branding/format-only keys intentionally remain unchanged.

## Checks completed

- String-catalog validator: full coverage for all six languages; no empty values or mismatched format arguments.
- iPhone 18 Pro / iOS 27.0 simulator: Home, Settings, Discover, and Customize checked in each language. Longer Spanish, Portuguese, French, and German settings labels wrap without losing controls. Japanese/Korean fonts and selected navigation labels render correctly.
- German saved-deck preview and New Card type chooser checked. Card front/back face labels use a separate key from Back navigation; theme Outline uses a visual-border translation.
- Korean onboarding checked in light mode; other main-screen checks used dark mode. Original simulator language/region and dark appearance restored afterward.
- Compiled app and notification extension each contain all seven language bundles.
- Targeted `LocalizationTests`: three tests / eight executed cases passed, covering six compiled locale bundles, independent singular/plural counts, and stable raw card/schedule values with authored card text unchanged.
- Existing test compilation fixtures updated for retired course arguments, the current deck summary shape, and the current handoff API; existing meaningful assertions retained. The whole test target builds; this task executed only the targeted localization tests.

## Verification limits

The simulator received a translated test-notification title/body. Automated View actions did not open the expanded notification, and automated swipes dismissed the synthetic alerts. Actual expanded-notification rendering and answering therefore remain a manual runtime check. Its resource inclusion, strings, and shared controls were checked in code/compiled bundles; this is not a claim of real-device or complete notification runtime verification.

Authored deck contents, imported Anki HTML, media, account names, and admin-authored notes retain their original language. Linked website policy documents are independently managed content. No backend or App Store submission was required for these interface translations.
