import SwiftUI

struct CourseLessonStudyView: View {
    let course: CourseDefinition
    let lesson: CourseLesson
    let onDismiss: () -> Void
    var body: some View {
        CoursePracticeView(course: course, title: lesson.title, cards: lesson.cards, lessonId: lesson.id, onDismiss: onDismiss)
    }
}

struct CourseReviewStudyView: View {
    let course: CourseDefinition
    let cards: [CourseLessonCard]
    let onDismiss: () -> Void
    var body: some View {
        CoursePracticeView(course: course, title: "Review", cards: cards, onDismiss: onDismiss)
    }
}

struct CourseCheckpointStudyView: View {
    let course: CourseDefinition
    let unit: CourseUnit
    let onDismiss: () -> Void
    var body: some View {
        CoursePracticeView(course: course, title: unit.checkpointQuiz?.title ?? "Checkpoint",
            cards: unit.checkpointQuiz?.questions ?? [], checkpointUnit: unit, onDismiss: onDismiss)
    }
}

struct CoursePracticeView: View {
    let course: CourseDefinition
    let title: String
    let cards: [CourseLessonCard]
    var lessonId: String? = nil
    var checkpointUnit: CourseUnit? = nil
    let onDismiss: () -> Void
    @ObservedObject var manager = CourseProgressManager.shared
    @State private var index = 0
    @State private var presentationId = UUID()
    @State private var answered = false
    @State private var missed: [String] = []
    @State private var finished = false
    @State private var result: CourseCheckpointResult?
    @State private var session = UUID().uuidString
    @State private var saveError: String?
    @State private var exerciseAttemptID: String?
    @State private var pendingGrade: Bool?
    @State private var reviewMisses = false
    @State private var autoPronounce = false
    @State private var lastCorrect = false
    @State private var savedAnswers: [String: Bool] = [:]
    @State private var loaded = false
    @State private var orderedIds: [String] = []
    @State private var prefersReading = false
    @State private var guideUnit: CourseUnit?
    private var practiceCards: [CourseLessonCard] {
        guard !orderedIds.isEmpty else { return cards }
        let lookup = Dictionary(uniqueKeysWithValues: cards.map { ($0.id, $0) })
        return orderedIds.compactMap { lookup[$0] }
    }
    private var currentUnit: CourseUnit? {
        if let checkpointUnit { return checkpointUnit }
        guard practiceCards.indices.contains(index) else { return nil }
        let cardId = practiceCards[index].id
        return course.units.first { $0.lessons.contains { $0.cards.contains { $0.id == cardId } } }
    }

    private var savesSession: Bool { lessonId != nil || checkpointUnit != nil }
    private var allowKoreanSpeech: Bool { CourseAudioPolicy.allowsKoreanSpeech(for: course.language) }

    private func isListening(_ card: CourseLessonCard) -> Bool {
        CourseAudioPolicy.isListening(card: card,
            source: CourseAudioPolicy.source(for: card, allowRecordedAudio: true, allowKoreanSpeech: allowKoreanSpeech),
            prefersReading: prefersReading)
    }

    private var isCheckpoint: Bool { checkpointUnit != nil }
    private var missedCards: [CourseLessonCard] { practiceCards.filter { missed.contains($0.id) } }
    private var completedActivityCount: Int {
        practiceCards.filter { card in
            savedAnswers[card.id] == true || (card.activity?.practiceGroup == nil && savedAnswers[card.id] != nil)
        }.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LearnAlertStyle.courseCanvas.ignoresSafeArea()
                if !loaded {
                    VStack(spacing: 16) {
                        if let saveError {
                            Text(saveError).foregroundStyle(.red)
                            Button("Retry opening practice", action: restoreSession)
                        } else { ProgressView() }
                    }.padding(24)
                } else if finished {
                    completion
                } else if practiceCards.indices.contains(index) {
                    ScrollView {
                        VStack(spacing: 16) {
                            if practiceCards[index].activity == nil {
                            Text(isCheckpoint ? "CHECKPOINT" : practiceCards[index].isListeningQuestion ? (isListening(practiceCards[index]) ? "LISTENING" : "READING") : practiceCards[index].optionImageNames.isEmpty && practiceCards[index].promptImageName == nil ? "PRACTICE" : "PICTURE PRACTICE")
                                .font(.caption.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
                            }
                            CourseQuestionPanel(card: practiceCards[index], immersive: true, checkpoint: isCheckpoint,
                                allowRecordedAudio: true, allowKoreanSpeech: allowKoreanSpeech, prefersReading: prefersReading,
                                allowTypedRecall: practiceCards[index].canOfferTypedRecall(
                                    masteryScore: manager.learningSnapshot.srsRecord(courseId: course.id, cardId: practiceCards[index].id)?.masteryScore ?? 0,
                                    checkpoint: isCheckpoint),
                                onReadingRequested: { stopPlayback(); prefersReading = true },
                                onListeningRequested: { prefersReading = false }) { correct in record(correct: correct) }
                                .id("\(session)-\(index)-\(presentationId)")
                                .environment(\.courseExercisePersistence, .shared(courseID: course.id, card: practiceCards[index], store: manager.learningStore))
                                .environment(\.courseExerciseAttemptReported, { exerciseAttemptID = $0 })
                        }.padding(.horizontal, 24).padding(.vertical, 24)
                            .tint(Color(hex: course.colorHex))
                            .frame(maxWidth: 640).frame(maxWidth: .infinity)
                    }.scrollDismissesKeyboard(.interactively)
                } else { ContentUnavailableView("No questions", systemImage: "book.closed") }
            }
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) { sessionHeader }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if loaded && !finished && practiceCards.indices.contains(index),
                   answered || practiceCards[index].activity?.exercise == nil || saveError != nil { answerFooter }
            }
            .onAppear {
                autoPronounce = manager.enrollment(for: course.id)?.autoPronounceInStudy ?? false
                if !loaded { restoreSession() }
                speakCurrent()
            }
            .onChange(of: index) { _, _ in speakCurrent() }
            .onChange(of: autoPronounce) { _, value in
                manager.setAutoPronounce(value, courseId: course.id)
                if value { speakCurrent() } else { KoreanSpeechManager.shared.stop() }
            }
            .onDisappear { stopPlayback() }
            .sheet(item: $guideUnit) { unit in CourseGuideSheet(course: course, unit: unit) }
            .fullScreenCover(isPresented: $reviewMisses) {
                CourseCheckpointRemediation(course: course, cards: missedCards, onDismiss: { reviewMisses = false }, manager: manager)
            }
        }
    }

    private var sessionHeader: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                Button { onDismiss() } label: {
                    Image(systemName: "xmark").font(.body.weight(.semibold)).frame(width: 44, height: 44)
                }.tint(.secondary).accessibilityLabel("Exit practice")
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.subheadline.weight(.semibold)).lineLimit(2)
                    Text(finished ? "Session complete" : "\(index + 1) of \(practiceCards.count)")
                        .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                }.frame(maxWidth: .infinity, alignment: .leading)
                if let currentUnit, !CourseSectionGuides.topics(course: course, unit: currentUnit).isEmpty {
                    Button { stopPlayback(); guideUnit = currentUnit } label: {
                        Image(systemName: "book.closed").frame(width: 44, height: 44)
                    }.accessibilityLabel("Section guide")
                }
                if !isCheckpoint && allowKoreanSpeech {
                    Button { if prefersReading { prefersReading = false }; autoPronounce.toggle() } label: {
                        Image(systemName: autoPronounce ? "speaker.wave.2.fill" : "speaker.slash")
                            .frame(width: 44, height: 44)
                    }.tint(autoPronounce ? Color(hex: course.colorHex) : .secondary)
                        .accessibilityLabel("Automatic pronunciation").accessibilityValue(autoPronounce ? "On" : "Off")
                }
            }
            if loaded && !finished {
                ProgressView(value: Double(savesSession ? completedActivityCount : index + (answered ? 1 : 0)), total: Double(max(1, practiceCards.count)))
                    .tint(Color(hex: course.colorHex)).animation(.snappy, value: answered)
            }
        }.padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 16)
            .background(LearnAlertStyle.courseCanvas)
    }

    private var answerFooter: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let saveError {
                Text(saveError).font(.callout).foregroundStyle(.red)
                if let pendingGrade { Button("Retry saving") { record(correct: pendingGrade) } }
            }
            if answered && practiceCards[index].activity?.exercise == nil {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: lastCorrect ? (practiceCards[index].isReadThrough ? "book.closed.fill" : "checkmark.circle.fill") : "arrow.counterclockwise.circle.fill")
                        .font(.title2).foregroundStyle(lastCorrect ? (practiceCards[index].isReadThrough ? CourseKoreanText.emphasisColor : Color.green) : Color.orange)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(practiceCards[index].isReadThrough ? practiceCards[index].feedbackTitle(isCorrect: lastCorrect) : (lastCorrect ? "Nicely done!" : "Let’s remember this one")).font(.headline)
                        if !lastCorrect {
                            if practiceCards[index].cardType == "matching" {
                                ForEach(practiceCards[index].matchingLeftItems.indices, id: \.self) { item in
                                    if practiceCards[index].matchingRightItems.indices.contains(item) {
                                        Text("\(practiceCards[index].matchingLeftItems[item]) → \(practiceCards[index].matchingRightItems[item])").font(.subheadline)
                                    }
                                }
                            } else { Text(practiceCards[index].correctAnswer).font(.subheadline.weight(.semibold)) }
                        }
                        if !isCheckpoint, let explanation = practiceCards[index].explanation {
                            Text(CourseKoreanText.attributed(explanation)).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }.accessibilityElement(children: .combine)
            }
            Button { advance() } label: {
                HStack {
                    Spacer()
                    Text(index == practiceCards.count - 1 ? "Finish" : "Continue").font(.headline)
                    Spacer()
                    Image(systemName: "arrow.right").font(.body.weight(.semibold))
                }.padding(.horizontal, 24).frame(minHeight: 56)
                    .foregroundStyle(answered ? .white : .secondary)
                    .background(answered ? Color(hex: course.colorHex) : Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 20))
            }.buttonStyle(.plain).disabled(!answered)
        }.padding(24).frame(maxWidth: 640).frame(maxWidth: .infinity)
            .background(LearnAlertStyle.courseCanvas)
    }

    private var completion: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: result?.passed == false ? "arrow.counterclockwise" : "checkmark")
                    .font(.system(size: 48, weight: .bold)).foregroundStyle(Color(hex: course.colorHex))
                    .frame(width: 128, height: 128)
                    .background(Color(hex: course.colorHex).opacity(0.12), in: Circle())
                Text(finishTitle).font(.largeTitle.bold()).multilineTextAlignment(.center)
                let scored = practiceCards.filter { $0.activity?.exercise?.format != "exposure" }
                Text("\(scored.filter { !missed.contains($0.id) }.count) of \(scored.count) practice questions correct").font(.title3).foregroundStyle(.secondary)
                if let result, !result.passed {
                    Text("\(Int(result.percentage * 100))% · \(Int((checkpointUnit?.checkpointQuiz?.passingScoreThreshold ?? 0.8) * 100))% to pass")
                        .font(.subheadline).foregroundStyle(.secondary)
                    if !result.missedConcepts.isEmpty { Text(result.missedConcepts.joined(separator: " · ")).font(.callout).multilineTextAlignment(.center) }
                    Button("Practice missed questions") { reviewMisses = true }.buttonStyle(.bordered).controlSize(.large)
                    Button("Retry checkpoint") { reset() }.buttonStyle(.borderedProminent).controlSize(.large)
                } else if !missed.isEmpty {
                    Text("We’ll revisit the missed questions in your reviews.").font(.callout).foregroundStyle(.secondary)
                }
                Button("Back to path") { onDismiss() }.buttonStyle(.borderedProminent).controlSize(.large)
            }.padding(.horizontal, 24).padding(.vertical, 48).frame(maxWidth: 640).frame(maxWidth: .infinity)
        }.tint(Color(hex: course.colorHex))
    }

    private var finishTitle: String {
        if let result { return result.passed ? "Checkpoint passed" : "Keep practicing" }
        if let lessonId, manager.getLessonStatus(courseId: course.id, lessonId: lessonId) == .completed { return "Lesson complete" }
        return "Practice complete"
    }
    private func speakCurrent() {
        guard autoPronounce, !prefersReading, !isCheckpoint, allowKoreanSpeech, practiceCards.indices.contains(index),
              // Don't speak the answer to a production exercise before it is graded.
              !practiceCards[index].usesTypedAnswer, !practiceCards[index].isListeningQuestion, let text = practiceCards[index].primaryKoreanText else { return }
        // Uploaded recordings are always played deliberately. Do not replace
        // an available recording with automatic synthesis of the same prompt.
        if case .recording = CourseAudioPolicy.source(for: practiceCards[index], allowRecordedAudio: true, allowKoreanSpeech: allowKoreanSpeech) { return }
        KoreanSpeechManager.shared.speak(text)
    }
    private func stopPlayback() {
        if allowKoreanSpeech { KoreanSpeechManager.shared.stop() }
        CardAudioPlayer.stopActive()
    }
    private func record(correct: Bool) {
        guard !answered else { return }
        stopPlayback()
        let card = practiceCards[index]
        if savesSession {
            guard manager.recordPracticeAnswer(course: course, lessonId: lessonId, checkpointUnitId: checkpointUnit?.id,
                sessionId: session, cardId: card.id, correct: correct, exerciseAttemptID: exerciseAttemptID) else {
                pendingGrade = correct; saveError = manager.learningStore.lastError ?? "Your progress couldn’t be saved. Please try again."; return
            }
            savedAnswers[card.id] = correct
        } else if !isCheckpoint, let unit = course.units.first(where: { $0.lessons.contains(where: { $0.cards.contains(where: { $0.id == card.id }) }) }),
           let lesson = unit.lessons.first(where: { $0.cards.contains(where: { $0.id == card.id }) }) {
            let success = manager.recordCardAnswer(courseId: course.id, sectionId: unit.id, lessonId: lesson.id,
                cardId: card.id, isCorrect: correct, eventToken: "\(session)-\(card.id)", exerciseAttemptID: exerciseAttemptID)
            if !success { pendingGrade = correct; saveError = manager.learningStore.lastError ?? "This lesson is locked. Return to the path."; return }
        }
        pendingGrade = nil; saveError = nil
        if !correct { missed.append(card.id) }
        lastCorrect = correct
        withAnimation(.snappy) { answered = true }
        if correct { HapticFeedback.success() } else { HapticFeedback.warning() }
    }
    private func restoreSession() {
        guard savesSession else { orderedIds = cards.shuffled().map(\.id); loaded = true; return }
        guard let restored = manager.resumePractice(course: course, lessonId: lessonId, checkpointUnitId: checkpointUnit?.id) else {
            saveError = manager.learningStore.lastError ?? "This practice is unavailable. Return to the path."
            return
        }
        orderedIds = restored.cardIds
        session = restored.id
        savedAnswers = restored.answers
        exerciseAttemptID = restored.pendingContinueAttemptID
        missed = restored.missedCardIds
        saveError = nil
        loaded = true
        if let pending = restored.pendingContinueCardID, let position = orderedIds.firstIndex(of: pending) {
            index = position; answered = true; lastCorrect = restored.answers[pending] ?? false
        } else if let next = restored.nextIndex { index = next; answered = false }
        else { finishSession() }
    }

    private func advance() {
        guard answered else { return }
        stopPlayback()
        presentationId = UUID()
        if !savesSession, practiceCards[index].activity?.exercise != nil {
            guard manager.learningStore.transaction({
                return $0.acknowledgeRenderedExercise(courseID: course.id, card: practiceCards[index], attemptID: exerciseAttemptID)
            }) == true else { saveError = "Continue couldn’t be saved. Try again."; return }
        }
        if savesSession {
            if practiceCards[index].activity?.exercise?.usesPracticeRenderer == true {
                guard manager.learningStore.transaction({
                    $0.continueExercise(courseID: course.id, lessonID: lessonId, checkpointID: checkpointUnit?.id, sessionID: session, cardID: practiceCards[index].id, attemptID: exerciseAttemptID)
                }) == true else {
                    saveError = manager.learningStore.lastError ?? "Continue couldn’t be saved. Try again."; return
                }
            }
            answered = false
            restoreSession()
        } else if index + 1 < practiceCards.count {
            index += 1; answered = false; saveError = nil
        } else { finishSession() }
    }

    private func finishSession() {
        stopPlayback()
        if savesSession {
            guard let completion = manager.finishPractice(course: course, lessonId: lessonId, checkpointUnitId: checkpointUnit?.id, sessionId: session) else {
                saveError = manager.learningStore.lastError ?? "Your result couldn’t be saved. Please try again."
                // The final answer is already saved; retry only finalization.
                index = max(0, practiceCards.count - 1); answered = true
                return
            }
            result = completion.checkpointResult
        }
        finished = true
    }

    private func reset() {
        stopPlayback()
        index = 0; answered = false; missed = []; finished = false; result = nil
        savedAnswers = [:]; session = UUID().uuidString; loaded = false
        restoreSession()
    }

}

private struct CourseCheckpointRemediation: View {
    let course: CourseDefinition
    let cards: [CourseLessonCard]
    let onDismiss: () -> Void
    @ObservedObject var manager = CourseProgressManager.shared
    var body: some View {
        CoursePracticeView(course: course, title: "Targeted practice", cards: cards, onDismiss: onDismiss, manager: manager)
    }
}
