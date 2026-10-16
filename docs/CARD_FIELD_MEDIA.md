# Card field media

Native card content fields support text, an image, audio, or any combination. A required prompt, answer, quiz choice, or matching item must contain at least one of these. Matching instructions and hints are optional. The Images card type retains its text-free image front/back layout; imported Anki cards keep their separate template editor.

The card editor uses compact text fields. Swipe left to reveal image/audio attachment buttons; photo uploads still use the crop preview. Hint starts unchecked and expands when enabled. Attached images/audio have previews and removal controls. Draft audio is discarded on cancellation; saved/replaced attachments are removed only after checking every stored reference.

`Flashcard.fieldMediaData` stores a dictionary of `CardFieldMedia` keyed by `prompt`, `answer`, `hint`, `option:0…3`, `left:0…19`, or `right:0…19`. Original image/audio columns remain synchronized for compatibility. `correctOptionIndex` distinguishes media-only/duplicate quiz choices; text-based legacy cards and notification handoffs still resolve by their answer text. New selection tokens retain the selected index through notification-to-app handoff. Matching uses indices, not its displayed text.

Audio playback never submits a quiz answer or assigns a match. The selection control is separate from the audio play button. Starting another clip stops the previous one. Media-only fill-blank answers use reveal/self-assessment because there is no text answer to compare.

Study views, card previews, community previews, and the notification extension render these fields. Notification payloads retain lightweight IDs/legacy fallbacks; current media is loaded from the shared database. Local audio/images retain the app's existing device-local media behavior.

The community API and admin editor use `fieldMedia` entries with `imageID`/`audioID` rather than local filenames. Existing promptImageID/answerImageID/promptAudioID/optionImageIDs aliases remain compatible. JSON imports use image/audio filenames; admin converts uploaded files into IDs. Fields are validated for card type, media kind, ownership, quotas and availability. Migration `0013_field_media.sql` extends the atomic publication/submission guard to every attachment field. The admin editor has compact per-field upload/preview/removal controls, choice radios, matching fields and optional hints.

Validation (October 16, 2026): 46 focused simulator test cases were checked across the media, community, image, Anki and scheduling suites; after correcting the new mock response, the 27-test community suite passed its rerun. The app and notification extension build succeeded. Manual simulator checks confirmed the compact quiz editor, swipe-revealed image/audio buttons, and unchecked/expanded Hint states; the unsaved preview was canceled. Backend tests cover media-only validation, ownership and atomic cleanup guards. Expanded-notification audio still needs physical-device validation.
