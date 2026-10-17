# Deck view and alert trail

The deck header has a small deck character, a single compact icon/count strip, and Add cards, Add folder, and Study actions. Study opens the existing full-screen study flow without scheduling alerts. Search is an icon that expands only on demand. The deck settings action is labeled “Add custom schedule settings for this deck”. Existing folders, filters, editing, deletion, sharing restrictions and progress reset remain available.

Native card rows display the actual prompt and answer media with small thumbnails and inline audio controls. Quiz cards show every choice and mark the correct choice by index, including empty-text media choices. Matching rows keep their paired positions. Image cards show front/back thumbnails. Hints expand separately. Imported Anki cards have small image/text previews and an optional full formatted front/back renderer so arbitrary templates do not start a WebView for every collapsed list row. No eye button or separate preview step is needed for native card content.

The Home alert timeline has a subtle accent surface, a next-alert ring and a quiet bell pulse that respects Reduce Motion. Tapping it opens the alert trail. Dots show nearby upcoming slots and recent history, with at most fourteen visible dots.

History is device-local in an app-group journal, bounded to 500 records/seven days; the visible trail includes the previous 24 hours and upcoming slots. Atomic writes and file locks protect app/extension updates. Scheduling, confirmed delivery, opening, answering and dismissing are distinct events. Both a correct and an incorrect response count as Answered. Reviewing an image/vocabulary card counts once confirmed with its review action; revealing, skipping or opening alone does not count as an answer.

- Green: answered, after saving progress.
- Accent blue: upcoming; the next slot has a ring. Lavender: freshly confirmed delivery.
- Amber: a confirmed delivered notification was dismissed without an answer, or has no response after fifteen minutes.
- Purple: opened in the app, separately from whether an answer can be attributed to it. Native deck notification handoffs retain their request ID through in-app grading. Course path handoffs remain Opened until a notification answer is actually recorded; opening a course path does not prove an answer.
- Gray: the scheduled time passed without delivery confirmation.

Past delivery is confirmed only by iOS's delivered-notification list or actual notification delegate/extension callbacks. The app cannot claim an alert audibly rang, infer delivery from an elapsed clock, recover cleared pre-update alerts, or retroactively attribute old answers. Synthetic tutorials and customization tests are excluded. Reconciliation removes canceled future slots but does not overwrite answered history or reschedule the user's alerts.

## Validation

The signed Debug simulator build succeeded for the app and notification extension. All 32 focused simulator tests passed across AlertTimelineTests, CardFieldMediaTests, DeckSchedulingTests, NotificationAppearanceTests and CourseNotificationFlowTests. The timeline tests cover persistence, response priority, concurrent store updates, cancellation, retention, deck isolation and exclusion of synthetic alerts.

The final build was installed on the iPhone 18 Pro simulator. The compact header, restored Study action and return, icon-only search control, renamed schedule menu and highlighted Home timeline were observed. Imported Anki mini-preview and formatted disclosures were opened; the existing fixture image is a 1×1 transparent placeholder, so this does not establish visual quality of real artwork. Every native media/card variant and delivery/answer color transition has not been manually exercised on a physical device in this pass.
