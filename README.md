# LearnAlert

### Your notifications. Now flashcards.

LearnAlert is a free study app for iPhone and iPad that turns notifications into small opportunities to learn. Create a deck, choose your schedule, and answer interactive questions directly from an expanded notification—without opening the app.

Study vocabulary, prepare for an exam, or practice something new. Bring your own material and make learning part of your day.

[**Download on the App Store**](https://apps.apple.com/us/app/learnalert-learn-from-alerts/id6813841439) · [**Website**](https://learnalertapp.com) · [**Support**](https://learnalertapp.com/support)

## What you can do

- **Study from notifications.** Touch and hold a study notification to expand it and interact with the question.
- **Choose your study schedule.** Pick a deck and set up alerts around your routine.
- **Create your own decks.** Organize material for classes, languages, hobbies, and other interests.
- **Turn study material into cards with AI.** Upload material, review the generated cards, and edit them before studying.
- **Refine cards with an AI assistant.** Adjust wording, difficulty, and focus through chat.
- **Practice in different ways.** Use multiple-choice questions, matching pairs, and tap-to-reveal flashcards.
- **Track your progress.** See how your practice is progressing across your decks.

## Getting started

1. Download LearnAlert from the App Store.
2. Create a deck or use AI to turn your study material into cards.
3. Allow notifications and schedule the deck you want to practice.
4. When a study alert arrives, touch and hold it to expand the question and answer it.

You can also study inside the app.

## In development

The repository may contain changes that are not yet available in the App Store release. Current work includes:

- Image support for card questions and answer choices.
- Notification backgrounds and Automatic/Compact layouts, with an interactive preview.
- A smoother first-use experience with starter decks and a test notification.

## Built with

LearnAlert is a native Apple-platform app built with **Swift**, **SwiftUI**, and **SwiftData**. Its interactive notifications use a **Notification Content Extension**, with an **App Group** connecting the app and extension.

## Building locally

Open `LearnAlert.xcworkspace` in Xcode and select the **LearnAlert** scheme. Keep local API configuration in the gitignored `Config.xcconfig` file.

For command-line simulator builds that exercise Sign in with Apple, keep `CODE_SIGNING_ALLOWED=YES`; `CODE_SIGN_IDENTITY=-` supplies simulator ad-hoc signing. Disabling signing skips Xcode’s simulated entitlements and can cause authorization to fail before the community API is contacted. Verify real Apple sign-in on a provisioned iPhone before distribution.

TikTok advertising measurement is disabled by default. Its integration code is retained, but disabled builds exclude the SDK and tracking permission prompt. `pod install` builds this default configuration. To intentionally enable it later, run `LEARNALERT_ENABLE_TIKTOK=1 pod install`, then rebuild; this also updates the tracking privacy declarations. To disable it again, run `LEARNALERT_ENABLE_TIKTOK=0 pod install` and rebuild.

## Privacy

AI features process submitted content through LearnAlert's backend and third-party AI services. Review the privacy policy before submitting personal or sensitive material. AI-generated cards can contain mistakes; check them against your source material.

[Privacy Policy](https://learnalertapp.com/privacy-policy) · [Terms & Conditions](https://learnalertapp.com/terms)

## Feedback

Found a bug or have an idea? [Open an issue](https://github.com/ublake/LearnAlert/issues) or visit the [support page](https://learnalertapp.com/support). For bug reports, include your device, app version, and the steps needed to reproduce the issue. Keep personal information and private study material out of public issues.

---

Created by **Blake Miller**.

## Courses and community decks

Discover includes Spanish and Korean courses, enrolled course tiles on Home,
persistent pins, mixed learned-material review, and explicit scheduling.
Korean includes 10 sections, 41 lessons, 1,410 practice cards, and graded section
checkpoints. Lessons require a correct answer for each card; spaced mastery is
tracked separately. Section checkpoints must be passed in the app (80% by default).
Course notifications choose unlocked material when expanded and share atomic
progress with the app. At a checkpoint, learned-material review remains available.
The system queues up to 60 course alerts and replenishes on app/notification use;
iOS cannot guarantee unlimited unattended background scheduling.

Course practice fills the screen with roomy answers and a fixed Continue button.
Both courses include 32 picture vocabulary exercises with simple cartoon art.
Artwork: [CourseVocabularyAtlas.png](LearnAlert/CourseVocabularyAtlas.png), generated
with the built-in image tool. Prompt: a regular 4×4 picture-dictionary atlas,
super-simple flat cartoons with bold outlines, solid colors, an ivory background,
and no labels; fruit, animals, drinks, and everyday objects.
Lessons and checkpoints save after every graded answer and resume at the next unanswered question, even after an app relaunch. Existing mastery is preserved, and Home shows the number of answers saved in the current lesson.
Customize uses one live preview, an appearance control, color swatches that adapt to light and dark mode, and a compact layout selector. The preview and notification share the light palette.

Korean lessons contain at least 33 cards each, including paired meanings, recognition,
written recall, matching, and 492 listening exercises. Matching accepts either side first,
shows colored selection and completed pairs, and lets a learner fix mistakes immediately.
Explanations use vocabulary cards with the information visible immediately.
Practice saves one randomized question order per attempt; resuming and curriculum
upgrades preserve that order and previously graded answers. Choices and matching pairs
are shuffled independently. Notification batches also vary fresh questions.

Each section has an offline guide with rules and worked examples. Open it from the
course overview, learning path, practice header, or expanded course notification.
The Hangul guide includes diagrams for vertical vowels, horizontal vowels, and batchim,
plus compound-vowel placement and reading order. Opening a notification guide keeps
the current question mounted so an unfinished match is preserved.

In-app Korean speech supports normal/slower playback and optional automatic
pronunciation. Listening questions hide the transcript until answered. “I can’t listen
right now” changes to a reading or written-recall alternative with the same card ID and
grading, and disables listening for that session. A missing Korean voice also uses the
written alternative. Notification speech is disabled pending signed-device verification.
Vocabulary sheets provide sentence meanings, grammar notes, and dictionary lookups.
Validation on October 9, 2026: 61 tests passed with no failures, skips, or runtime
warnings; the Release app and notification extension built successfully. Reviewed
light/dark renders for matching, listening, reading alternatives, vocabulary, guides,
and accessibility text sizes. Hands-on simulator interaction was unavailable because
the host Mac was locked. Signed-device notification/audio verification remains open.

Curriculum content should receive native-speaker review before a public course release.

Community sharing uploads public card snapshots, selected images, and audio;
private source documents and study history are excluded. See the API repository's
COMMUNITY.md for storage, moderation, migrations, and account deletion.

New community submissions and updates stay private until manually approved in the
owner's admin review queue. The app explains that review can take up to 3 days and
shows pending, approved, or needs-changes status in My community decks. Rejection
notes are visible there, with an option to edit and resubmit. Approval never happens
automatically; updates temporarily remove the community copy from public listings.

My community decks refreshes on opening, foregrounding, pull-to-refresh, and every
30 seconds while visible. Admin edits, hiding/restoring, and removals can include a
private note to the author. Removed community copies leave a dismissible notice;
personal decks and study history remain intact. Refresh errors keep the last loaded
list, while changing accounts clears the previous author's data.

Before App Store distribution, verify Apple sign-in, shared app/extension progress,
checkpoint handoffs, and notification layouts on a provisioned iPhone, and update
App Store privacy answers for community identifiers, content, images, and audio.

## Community account safeguards (1.1)

Signed-in learners can block a community author from the feed or deck preview and
manage blocked authors from their profile. Feed, preview, download, and media requests
include viewer authentication so the server can enforce blocks and account restrictions.
Changing accounts clears the previous viewer's feed and private owner lists.

Apple sign-in passes the short-lived authorization code to the backend for token
revocation support. Account deletion requires fresh confirmation from the same Apple
account. The app checks Apple's credential state on foregrounding and clears revoked
sessions. Restricted users retain account management and deletion access; restrictions
are enforced by the backend and survive profile deletion. Backend Apple signing and
token-encryption secrets must be configured for live authorization revocation.

Version 1.1 (build 3) includes App Group UserDefaults reason 1C8F.1 in both privacy
manifests. Community identifiers, shared text, images, and audio are declared as linked
app-functionality data. Advertising measurement remains disabled.

Release validation on October 14, 2026: all 88 app tests passed. The final simulator
build and signed Release archive passed, and an App Store Connect distribution export
succeeded after refreshing provisioning profiles for Sign in with Apple. The export is
local only; no build was uploaded or submitted by this validation. A live Apple
sign-out/re-sign-in and user-approved test-account deletion confirmed encrypted token
storage and a cleared Apple revocation queue. All 20 community tests passed after fixing
a race where Apple revoked the session before the delete response returned. Personal
study data stays on the device. Physical-device notification/extension checks and live
signed Apple server notification delivery remain unverified.
The AI consent screen was intentionally left unchanged; its third-party disclosure
must still be considered when assessing App Review readiness.

October 15 follow-up: all six notification appearance/routing tests passed, including
two new regression tests for Customize preview taps, legacy test alerts, dismissal,
and preserving unrelated real study handoffs. Tapping a Customize test alert now opens
an animated gesture guide instead of navigating to its synthetic deck ID. The guide
supports touch-and-hold and swipe-left/View, with a static Reduce Motion alternative.
Tutorial notifications no longer write study handoffs. In the iPhone 18 Pro simulator,
the delivered expanded Sunset alert showed its selected colors, hint, and correct-answer
feedback; a new preview tap opened the guide, verified in both light and dark appearance.
Leaving the Korean course after one response resumed at card 2 of 38 with 3% saved.
Its scheduling bell successfully scheduled a real local course alert, which arrived
and opened the correct learning path when tapped. The temporary schedule was stopped,
and the original 9 AM–6 PM timing, selected deck, and appearance were restored.
Expanded course-question answering and checkpoint handoff were not completed in this
runtime check; the simulator controls did not reliably expose that alert's View action.
The updated simulator build, signed stable Release archive, distribution export, and
signature verification passed. The refreshed local IPA is
`~/Desktop/LearnAlert-Releases/1.1-3/LearnAlert-1.1-3.ipa`.
App Store Connect's Paid Apps Agreement is Active; version 1.1 remains Prepare for
Submission with manual release selected, updated review instructions, and no build
uploaded or review submitted by these checks. Actual signed Apple notification delivery
is still unverified (the latest receipt count was zero); there is no documented SIWA
test-event API. Physical-device checks remain unverified because testing was limited
to the simulator at the owner's request.
