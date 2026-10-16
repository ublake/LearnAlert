# Anki import

The third action in the bottom + menu opens a dedicated APKG import sheet. Conversion is local, not an AI upload. The file picker and Open In handler accept `.apkg`; no backend endpoint, AI quota, community upload, notification schedule, or Apple login is involved.

## Import and storage

`Packages/AnkiArchive` decodes legacy `collection.anki2` / `collection.anki21` and modern Zstandard `collection.anki21b` packages, including modern protobuf media maps and normalized note-type tables. Actual card rows preserve reversed templates and individual cloze groups. Anki review history and scheduling presets are not imported.

Before committing, users select decks/subdecks, preview both sides, review compatibility notes, and choose whether to update existing imports. Default repeat imports leave existing cards alone. Updates retain LearnAlert card UUIDs and review history. Matching card identities as well as deck IDs keeps unrelated packages with reused Anki IDs separate. Missing templates/cards and media omissions are reported before import.

Source deck IDs and note-GUID/template-ordinal identities persist in SwiftData. Imported content uses a separate `anki` card type, excluded from the manual card-type picker. Its HTML/CSS editor is available through the normal card edit action. Imported decks/cards are marked as external material and cannot be republished as original community decks.

Media is streamed to a temporary workspace, then copied to the app-group `AnkiMedia/<UUID>` folder on a background model actor. An index maps original filenames to safe storage names, preserving long Unicode names and case-distinct files on iOS filesystems. Bytes retain their original formats; no forced crops, JPEG conversion, or image downscaling occurs. Cancellation/failure removes temporary work and rolls back unsaved library changes. Replaced/deleted media is removed only when no card still references its folder.

Limits: 1 GB input, 100,000 cards, 100,000 media files, 256 MB decoded collection database, 64 MB per media file, 2 GB total decoded media/database, and 192 MB rendered card content. CRCs and decompression output/window limits are checked. SQLite is opened read-only and immutable, with trusted-schema execution disabled. Archive paths and symlinks are never extracted as supplied.

## Study and notifications

Both the app and notification extension render imported HTML/CSS and bundled JavaScript in an ephemeral WKWebView. Network access, forms, frames, and external navigation are blocked. The limited native bridge plays audio from the import folder or speaks a bounded TTS phrase. No profile, token, or account bridge exists.

Built-in Anki image occlusion is rendered locally from its normalized masks; older image-based occlusion templates retain their bundled images/SVG. Basic/reversed cards, standard/nested cloze, conditionals, FrontSide, text/hint/furigana/kana/kanji and TTS filters are converted. Imported typing templates use self-assessment. Offline KaTeX renders common math delimiters; full LaTeX documents and Anki-specific MathJax macros may require adjustment.

Notification payloads contain ordinary card IDs/text, not full imported documents. The extension resolves current HTML/media from the shared database, supports answer reveal/self-assessment and local audio, and retains reveal/grading state when continuing in-app.

Custom Anki add-on APIs, unknown filters, online libraries, and arbitrary MathJax configurations are not guaranteed compatible. The importer reports known limitations and provides a real card preview rather than claiming universal Anki runtime parity. Media stays on the importing device, consistent with the app's existing local media stores; this change does not add cross-device media sync or an Anki scheduler.

## Dependencies and checks

ZIPFoundation 0.9.20 (MIT), decompression-only Zstandard 1.5.7 (BSD), KaTeX 0.19.0 (MIT). Sources/versions and license notices are retained in `Packages/AnkiArchive` and `Resources/AnkiWebAssets`. No Anki application implementation is linked into LearnAlert.

Regenerate the small fixture decks with `scripts/make_anki_fixtures.py` in an environment with the official `anki` Python package. They exercise both package formats, reversed cards, cloze groups, custom CSS/JavaScript, image/audio media, and built-in image occlusion.

Run parser/format tests with `swift test --package-path Packages/AnkiArchive`. Native `AnkiImportTests` cover persistence, duplicate/update handling, original review-history preservation, offline HTML/CSS/JS/media/math rendering, network blocking, and media path boundaries. Notification interaction still benefits from testing a real imported deck on a physical iPhone; a simulator build or renderer test is not evidence of every custom deck's notification compatibility.

Validation on October 16, 2026: 11 format/parser tests passed; 42 focused signed iPhone 18 Pro simulator app tests passed, including six native Anki tests, media persistence/transfer, scheduling, and Apple-session tests. An initial unsigned test run could not persist mock Keychain sessions; rerunning with simulator signing enabled passed those tests.

Manual simulator check: opened the third + action, selected a modern APKG through Files, previewed front/back content, imported all nine sample cards into three decks, and returned to the updated library without replacing the existing course alert schedule. A simulated Anki notification was delivered. The simulator notification shade did not reliably expose its expanded View action, so expanded-notification interaction remains a device-validation gap.
