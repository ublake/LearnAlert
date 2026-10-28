# Notification learning and app practice

Notification learning has one device-wide daily goal across all decks and card
types: 20 completed questions, including reviews and incorrect answers. Explicit
ratings and Reviewed actions count; opening, revealing, listening, and skipping do
not. Calendar days use the device's local calendar.

An expanded study alert contains one to three questions (three by default). A
skip uses a slot in that alert, but does not increase the daily answered total.
Reopening the same alert restores its batch rather than allocating another one.
The last graded answer remains visible until Finish is tapped. Finishing a batch
offers app practice; reaching the daily goal also removes today's pending study
alerts while retaining future days. Synthetic tutorial and test alerts are exempt.

Anki notification questions prioritize due learning/relearning steps, then due
reviews, then new cards. The first question is selected for its scheduled slot
and resolved again when the alert opens using the current saved review state.
Selection stays within the scheduled deck/folder and excludes cards already
handled in that notification batch. Reviews use the same daily answer allowance
as new cards. A one-minute learning step makes a card eligible again; it does not
create an extra notification or shorten the delivery spacing.

## Delivery policy

- The explicit daily alert ceiling defaults to 20 and accepts 1 through 30.
- Availability and the question goal reduce the actual scheduled total. With
  three questions per alert, at most seven alerts are planned per day.
- The minimum gap is 60 minutes. Longer gaps can be selected; a shorter window
  reduces capacity instead of compressing intervals.
- The one-alert-per-day specific-time option is preserved.
- The previous Automatic pace choice is no longer displayed or used. Its enum
  remains solely for decoding older settings; old automatic settings migrate to 20.
- A file-locked journal reserves delivery slots before OS scheduling, preserves
  elapsed slots across rescheduling, and applies the current ceiling across decks.
- Recurring plans replenish a bounded queue of at most 60 future requests.

The app and extension share `NotificationLearning/budget.json` in the app group.
The journal serializes answer claims and records their card-save acknowledgment.
Interrupted claims are checked against saved review data after a short grace
period so a failed review does not permanently consume an answer. Corrupt or
unavailable state pauses scheduling rather than silently resetting the quota.

## Independent practice

`DeckStudyView` uses local session answers and a separate durable Anki practice
state on each card. It never writes
notification card mastery, review dates, the notification learning goal, or alert
timeline answers. A notification handoff can acknowledge an already graded card
without grading it again.

`ankiReviewStateData` retains notification learning;
`ankiPracticeReviewStateData` retains in-app learning. Each in-app Anki rating is
saved before advancing. New practice sessions select due learning steps, then
due reviews, then new cards from the practice state; future review cards keep
their saved dates. Starting a session or changing the scheduled deck does not
reset either track. Practice has no notification answer budget.

Existing bookmarks migrate their latest rated Anki state once per card into the
practice field. A resumed bookmark supplies the queue position and session
answers, while the card supplies its latest learning state, so an older bookmark
cannot rewind later ratings. Explicit Reset Progress clears both learning tracks
and checkpoints. It stores a fresh practice state to prevent interrupted
checkpoint cleanup from restoring discarded ratings.

The latest three practice sessions are saved per deck under Application Support:
`LearnAlert/PracticeSessions/<deck UUID>.json`. They retain stable card order,
position, reviewed-card totals, answers, reveal/hint state, typed answers, and
Anki repeat bookmarks. The three-session limit does not limit durable per-card
learning history. Encoding and atomic writes run off the UI actor. Deleting or
resetting a deck removes its checkpoints; deleting all decks removes all sessions.

The session picker shows Resume for unfinished sessions, Results for completed
sessions, and Start a new session. Deleted cards are omitted safely on resume.
Unfinished matching-pair and blank-choice interactions restart the current
unanswered question; completed questions and the session position remain saved.
