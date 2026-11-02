# Interface localization

LearnAlert supports English plus Spanish (`es`), Brazilian Portuguese (`pt-BR`), French (`fr`), German (`de`), Japanese (`ja`), and Korean (`ko`). iOS selects its preferred supported app language and falls back to English.

`LearnAlert/Localizable.xcstrings` is shared by the app and notification extension. `InfoPlist.xcstrings` translates the photo-library permission explanation. Keep translated display copy separate from persisted enum raw values, schedule tags, API parameters, filter IDs, and progress keys. Deck questions, answers, titles, imported Anki templates, recordings, author names, and admin notes are authored content and retain their original language. Linked website pages, including the policy documents, have their own localization lifecycle.

For new UI copy, use literal SwiftUI `Text`/`Label`/`Button` labels or `String(localized:)` for computed values. Helper views with fixed interface labels should accept `LocalizedStringResource`. Do not wrap arbitrary deck content in localization lookups. Translate complete interpolated phrases, retain the argument types, and use plural variants when a count changes the wording. Native controls injected into Anki HTML are localized at render time, which also covers already-imported cards without rewriting their templates.

After building with `SWIFT_EMIT_LOC_STRINGS=YES`, synchronize compiler-extracted keys:

```sh
python3 scripts/localizations.py --extract /tmp/LearnAlertWeightedBundles/Build/Intermediates.noindex
python3 scripts/localizations.py
```

The script preserves translations/plurals and reports missing entries and invalid format arguments. AnkiArchive diagnostics use the host app's catalog; the explicit extraction setting includes the package sources. Branding and format-only keys intentionally remain unchanged. Add all six translations before shipping new UI copy.

`LocalizationTests` checks compiled language resources and stable stored values. Simulator review should also cover Home, Discover, Customize, Settings, card creation, onboarding, and expanded notifications, including long German/French labels and Japanese/Korean text. Language changes must not reset any personal learning history.

Apple references: [String catalogs](https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog), [Localization](https://developer.apple.com/localization/).
