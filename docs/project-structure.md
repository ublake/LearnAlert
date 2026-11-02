# Project structure

Open `LearnAlert.xcworkspace`. The app and test folders use Xcode's filesystem-synchronized groups, so these folders are visible both in Finder and the project navigator.

```text
LearnAlert/
  App/                     App entry point, root composition, launch and navigation
  Core/                    Shared data models and persistence
    Audio/                 Feedback playback and notification ringtone catalog
    Catalog/               Managed catalog and portable guide data
    Media/                 Card audio storage and attachment cleanup
  UI/                      Reusable visual styles and Safari wrapper
  Features/
    AI/                    Generation, refinement, document/PDF import and consent
    Anki/                  Package import, HTML rendering, review state and settings
    Cards/                 Card creation, media fields, crop and image flip controls
    Community/             Sharing, accounts, profiles, feed and appreciation
    Customization/         Notification appearance, themes and live preview
    Decks/                 Deck creation, detail and deck artwork
    Discover/              Browse categories and language collection entry points
    Languages/             Language content, topic projections and migration
    Library/               Home layout, ordering, pins and library operations
    Notifications/         Scheduling, budgets, timeline, handoffs and alert guidance
    Onboarding/            Welcome, tutorial coaching, completion and permission UI
    Settings/              Preferences, help, policies and existing preview utilities
    Study/                 In-app practice, saved sessions and progress dashboard
  Resources/Localization/  Localizable.xcstrings and InfoPlist.xcstrings
  Assets.xcassets/          Existing app images and icons
  Sounds/                  Existing feedback, ringtones and legacy sound aliases
  hangulaudio/             Existing Korean pronunciation clips
  koreanimages/            Existing replaceable vocabulary images
LearnAlertExtension/        Notification content extension entry point
LearnAlertTests/            Tests grouped by feature; fixtures retain their paths
Packages/                  Existing local dependencies, including AnkiArchive
Resources/AnkiWebAssets/    Existing bundled HTML-rendering dependencies
scripts/                   Content, localization and audio tooling
docs/                      Project notes and implementation history
```

`ContentView.swift` stays intact in `App`: it currently contains root composition alongside several screen sections. `Models.swift` stays intact in `Core`. This cleanup moves files without splitting types or changing app behavior.

The notification extension reuses selected app files. Its explicit paths are maintained in the `PBXFileSystemSynchronizedBuildFileExceptionSet` in `LearnAlert.xcodeproj/project.pbxproj`; update those entries whenever moving shared files again. Keep resource basenames stable because saved cards and queued alerts refer to them.

The localization validator reads `LearnAlert/Resources/Localization/Localizable.xcstrings`. Its compiler-data discovery already searches subdirectories. Catalog source-location comments may describe earlier layouts and can be refreshed separately when translations are intentionally updated.

The legacy `export-managed-catalog.py` now points at the moved existing sources. It already referenced a removed `CourseSectionGuide.swift` before this cleanup; repairing that retired-guide exporter is a separate content-tooling task.
