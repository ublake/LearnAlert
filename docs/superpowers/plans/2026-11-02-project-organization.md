# Project File Organization Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans for this mechanical relocation; source bodies are preserved.

**Goal:** Group the existing app and test files into usable feature folders in the current Xcode project.
**Architecture:** Retain the existing synchronized Xcode groups and target membership. Move files physically, translate path references, and preserve all runtime resources and application behavior.
**Tech Stack:** Swift, SwiftUI, SwiftData, Xcode synchronized filesystem groups, Python tooling.
**Spec:** The user requested file/folder organization; `docs/project-structure.md` records the resulting layout.

## Global Constraints

- Work in the existing LearnAlertApp checkout used by Xcode; the user has authorized commit/push and simulator builds.
- No type, function, model, identifier, or behavior changes. Keep resource/fixture basenames and platform configuration locations stable.
- Preserve the two preexisting catalog edits byte-for-byte and leave their content changes unstaged.
- No new dependencies or generated/vendor directory changes. No app UI tests; build/install/launch as previously requested.

## Review Focus

- Every Swift source and test must retain its contents and target membership.
- The extension whitelist must resolve all relocated shared source files and its localization resource.
- Both dirty catalog payloads must survive at their new paths without being included in this commit.
- Localization and catalog-export scripts must find relocated sources; do not expand the unrelated obsolete guide exporter scope.
- Existing audio, artwork, fixtures, entitlement and plist paths must remain usable.

## Task 1: Relocate and update path references

- [x] Record hashes, index blobs and preexisting catalog backups before changing paths.
- [x] Use git mv for the app source groups listed below, mirrored test groups, and both localization catalogs.
- [x] Rewrite the extension membership whitelist; update the localization validator, current catalog-export source paths, and documentation.
- [x] Verify all 126 moved payloads and their staged blobs match the captured originals.

### App source groups

- `LearnAlert/App/`: `LearnAlertApp.swift`, `ContentView.swift`, `LaunchLoadingView.swift`, `BottomNavigation.swift`, `NavigationTabIcon.swift`
- `LearnAlert/Core/`: `Models.swift`, `SharedDatabase.swift`
- `LearnAlert/Core/Audio/`: `AlertSoundCatalog.swift`, `InteractionSoundConfiguration.swift`, `InteractionSoundPlayer.swift`
- `LearnAlert/Core/Catalog/`: `CatalogGuideModels.swift`, `ManagedCatalog.swift`
- `LearnAlert/Core/Media/`: `CardAttachmentCleanup.swift`, `CardAudioStore.swift`
- `LearnAlert/UI/`: `DesignSystem.swift`, `StudyStudioStyle.swift`, `SafariView.swift`
- `LearnAlert/Features/Library/`: `AdaptiveLibraryWorkspace.swift`, `HomeLibraryOrdering.swift`, `HomeMasteryBars.swift`, `LibraryDataOperations.swift`, `LibraryPreferences.swift`
- `LearnAlert/Features/Decks/`: `CreateDeckView.swift`, `DeckDetailView.swift`, `DeckCreature.swift`
- `LearnAlert/Features/Cards/`: `CreateCardView.swift`, `DeckCardPreviewRow.swift`, `CardImageCropView.swift`, `CardFieldMedia.swift`, `ImageCardFlipView.swift`
- `LearnAlert/Features/Study/`: `DeckStudyView.swift`, `PracticeSessionStore.swift`, `ProgressDashboardView.swift`, `StudyEngine.swift`, `StudyProgressSummary.swift`, `StudyScheduling.swift`
- `LearnAlert/Features/Anki/`: `AnkiCardContent.swift`, `AnkiCardEditorView.swift`, `AnkiCardView.swift`, `AnkiExpandedPreview.swift`, `AnkiImportSession.swift`, `AnkiImportView.swift`, `AnkiNotificationSelection.swift`, `AnkiReviewAlerts.swift`, `AnkiReviewScheduling.swift`, `AnkiSessionReviewQueue.swift`, `AnkiStudyPreferences.swift`, `AnkiStudySettingsView.swift`
- `LearnAlert/Features/Community/`: `CommunityAPI.swift`, `CommunityLikesActivityView.swift`, `CommunityProfile.swift`, `CommunityPublicProfileView.swift`, `CommunitySocialModels.swift`, `CommunityViews.swift`
- `LearnAlert/Features/Discover/`: `DiscoverCategoryStyle.swift`, `LanguageDeckDiscoveryView.swift`, `PremadeDecksView.swift`
- `LearnAlert/Features/Languages/`: `CourseActivity.swift`, `CourseCurriculum.swift`, `CourseCurriculum+ExpandedKorean.swift`, `CourseCurriculum+FoundationWorkshop.swift`, `CourseCurriculum+Korean.swift`, `CourseCurriculum+Practice.swift`, `CourseModels.swift`, `HangulAudio.swift`, `KoreanLexicon.swift`, `LanguageDeckMigration.swift`
- `LearnAlert/Features/Notifications/`: `AlertPaceControls.swift`, `AlertScheduleTimelineView.swift`, `AlertTimelineStore.swift`, `DailyDeckAlertScheduler.swift`, `DeckAlertSettings.swift`, `DeckScheduleSettingsView.swift`, `NotificationLearningBudget.swift`, `NotificationManager.swift`, `NotificationTestGuideView.swift`, `NotificationViewportGeometry.swift`
- `LearnAlert/Features/Customization/`: `NotificationCanvasPreview.swift`, `NotificationCustomizeView.swift`, `NotificationDesignTheme.swift`
- `LearnAlert/Features/Settings/`: `HelpView.swift`, `PrivacyPolicyView.swift`, `SettingsPreviewGroup.swift`, `SettingsSections.swift`, `SoundPreviewGallery.swift`, `TermsOfServiceView.swift`
- `LearnAlert/Features/Onboarding/`: `TutorialCoachOverlay.swift`, `TutorialCompletionView.swift`, `TutorialNotificationProgress.swift`, `WelcomeOnboardingView.swift`, `NotificationPermissionPromptView.swift`
- `LearnAlert/Features/AI/`: `AIConsentSheet.swift`, `AIDiagnosticInspectorSheet.swift`, `DeckAIAssistantSheet.swift`, `DocumentTextExtractor.swift`, `GeneratedQuizImportView.swift`, `LearnAlertAPI.swift`, `PDFOutlineManager.swift`, `PDFSectionPickerSheet.swift`

### Test groups

- `LearnAlertTests/Anki/`: `AnkiExpansionTests.swift`, `AnkiImportTests.swift`, `AnkiReviewSchedulingTests.swift`, `AnkiSessionReviewQueueTests.swift`
- `LearnAlertTests/Catalog/`: `LanguageDeckTests.swift`, `LanguageQuestionTextTests.swift`, `ManagedCatalogTests.swift`, `VocabularyArtworkTests.swift`
- `LearnAlertTests/Library/`: `AdaptiveWorkspaceTests.swift`, `DeckDetailSnapshotTests.swift`, `DeckSchedulingTests.swift`, `LibraryInteractionTests.swift`, `LibraryPerformanceTests.swift`
- `LearnAlertTests/Cards/`: `CardFieldMediaTests.swift`, `CardImageCropTests.swift`, `ImageCardPersistenceTests.swift`, `MatchingCardTests.swift`
- `LearnAlertTests/Community/`: `CommunitySocialTests.swift`, `CommunityTransferTests.swift`, `CommunityFeedPagingTests.swift`
- `LearnAlertTests/Notifications/`: `AlertTimelineTests.swift`, `NotificationAppearanceTests.swift`
- `LearnAlertTests/Study/`: `StudyProgressSummaryTests.swift`
- `LearnAlertTests/Core/`: `LearnAlertTests.swift`, `LocalizationTests.swift`

## Task 2: Verify, review and finish

- [x] Validate all synchronized target membership entries and localized resources.
- [x] Run `python3 scripts/localizations.py` and `git diff --check`.
- [x] Build LearnAlert.xcworkspace / LearnAlert for the iPhone 18 Pro simulator and inspect build output.
- [x] Get an independent review of the relocation and staged diff; address concrete path issues.
- [x] Install and launch the built app.
- Finalization: commit/push this cleanup under the existing user instructions; preserve only the original catalog content edits as unstaged changes.

## Execution decisions

- This is a behavior-preserving organization request, so source identity, target membership, resource checks and a simulator build are the appropriate verification; no implementation-mirroring unit tests are added.
- The legacy managed-catalog exporter already refers to removed CourseSectionGuide.swift. Update the moved input paths but leave that preexisting retired-guide issue outside this file-move task.

## Verification record

- All 126 moved payload SHA-256 hashes match the before-state, and each staged blob matches its original Git index blob. The 124 Swift bodies are byte-identical.
- Both original dirty catalog payloads remain byte-identical at the new paths. Their content changes are not staged.
- Xcode project parses successfully; independent review confirmed its object graph is unchanged apart from the 34 intended path substitutions, and all 86 extension member entries exist.
- Normal simulator build and build-for-testing passed on iPhone 18 Pro / iOS 27.0 using Xcode 27.1. Test execution and app UI checks were not requested for this cleanup.
- App and notification extension each contain all seven locale bundles. Ten ringtones, five legacy aliases, atlas artwork, pronunciation clips and fonts retain their runtime paths.
- Localization validation reports the same preexisting empty key (`''`) before and after relocation: 1,416 real interface keys remain covered in all six languages. The empty Xcode placeholder was preserved rather than changing the user's catalogs.
- The built app was installed and launched in the simulator. Independent review found no source, membership, resource or staging regressions.
