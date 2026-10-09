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
Korean includes 10 sections, 41 lessons, 489 practice cards, and graded section
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

In-app Korean speech supports normal/slower playback and optional automatic
pronunciation. Notification speech is disabled pending signed-device verification.
Vocabulary sheets provide sentence meanings, grammar notes, and dictionary lookups.
Curriculum content should receive native-speaker review before a public course release.

Community sharing uploads public card snapshots, selected images, and audio;
private source documents and study history are excluded. See the API repository's
COMMUNITY.md for storage, moderation, migrations, and account deletion.

Before App Store distribution, verify Apple sign-in, shared app/extension progress,
checkpoint handoffs, and notification layouts on a provisioned iPhone, and update
App Store privacy answers for community identifiers, content, images, and audio.
