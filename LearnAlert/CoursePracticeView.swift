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
    @ObservedObject private var manager = CourseProgressManager.shared
    @State private var index = 0
    @State private var answered = false
    @State private var missed: [String] = []
    @State private var finished = false
    @State private var result: CourseCheckpointResult?
    @State private var session = UUID().uuidString
    @State private var saveError: String?
    @State private var pendingGrade: Bool?
    @State private var reviewMisses = false
    @State private var autoPronounce = false
    @State private var lastCorrect = false
    @State private var savedAnswers: [String: Bool] = [:]
    @State private var loaded = false

    private var savesSession: Bool { lessonId != nil || checkpointUnit != nil }

    private var isCheckpoint: Bool { checkpointUnit != nil }
    private var missedCards: [CourseLessonCard] { cards.filter { missed.contains($0.id) } }

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
                } else if cards.indices.contains(index) {
                    ScrollView {
                        VStack(spacing: 16) {
                            Text(isCheckpoint ? "CHECKPOINT" : cards[index].optionImageNames.isEmpty && cards[index].promptImageName == nil ? "PRACTICE" : "PICTURE PRACTICE")
                                .font(.caption.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
                            CourseQuestionPanel(card: cards[index], immersive: true, checkpoint: isCheckpoint,
                                allowAudio: course.language == "Korean") { correct in record(correct: correct) }
                                .id("\(session)-\(index)")
                        }.padding(.horizontal, 24).padding(.vertical, 24)
                            .frame(maxWidth: 640).frame(maxWidth: .infinity)
                    }.scrollDismissesKeyboard(.interactively)
                } else { ContentUnavailableView("No questions", systemImage: "book.closed") }
            }
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) { sessionHeader }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if loaded && !finished && cards.indices.contains(index) { answerFooter }
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
            .onDisappear { KoreanSpeechManager.shared.stop() }
            .fullScreenCover(isPresented: $reviewMisses) {
                CourseCheckpointRemediation(course: course, cards: missedCards) { reviewMisses = false }
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
                    Text(finished ? "Session complete" : "\(index + 1) of \(cards.count)")
                        .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                }.frame(maxWidth: .infinity, alignment: .leading)
                if !isCheckpoint && course.language == "Korean" {
                    Button { autoPronounce.toggle() } label: {
                        Image(systemName: autoPronounce ? "speaker.wave.2.fill" : "speaker.slash")
                            .frame(width: 44, height: 44)
                    }.tint(autoPronounce ? Color(hex: course.colorHex) : .secondary)
                        .accessibilityLabel("Automatic pronunciation").accessibilityValue(autoPronounce ? "On" : "Off")
                }
            }
            if loaded && !finished {
                ProgressView(value: Double(savesSession ? savedAnswers.count : index + (answered ? 1 : 0)), total: Double(max(1, cards.count)))
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
            if answered {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: lastCorrect ? "checkmark.circle.fill" : "arrow.counterclockwise.circle.fill")
                        .font(.title2).foregroundStyle(lastCorrect ? Color.green : Color.orange)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(lastCorrect ? "Nicely done!" : "Let’s remember this one").font(.headline)
                        if !lastCorrect {
                            if cards[index].cardType == "matching" {
                                ForEach(cards[index].matchingLeftItems.indices, id: \.self) { item in
                                    if cards[index].matchingRightItems.indices.contains(item) {
                                        Text("\(cards[index].matchingLeftItems[item]) → \(cards[index].matchingRightItems[item])").font(.subheadline)
                                    }
                                }
                            } else { Text(cards[index].correctAnswer).font(.subheadline.weight(.semibold)) }
                        }
                        if !isCheckpoint, let explanation = cards[index].explanation {
                            Text(explanation).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }.accessibilityElement(children: .combine)
            }
            Button { advance() } label: {
                HStack {
                    Spacer()
                    Text(index == cards.count - 1 ? "Finish" : "Continue").font(.headline)
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
                Text("\(cards.count - missed.count) of \(cards.count) correct").font(.title3).foregroundStyle(.secondary)
                if let result, !result.passed {
                    Text("\(Int(result.percentage * 100))% · \(Int((manager.enrollment(for: course.id)?.checkpointPassingThreshold ?? checkpointUnit?.checkpointQuiz?.passingScoreThreshold ?? 0.8) * 100))% to pass")
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
        guard autoPronounce, !isCheckpoint, course.language == "Korean", cards.indices.contains(index),
              // Don't speak the answer to a production exercise before it is graded.
              cards[index].cardType != "fillBlank", let text = cards[index].primaryKoreanText else { return }
        KoreanSpeechManager.shared.speak(text)
    }
    private func record(correct: Bool) {
        guard !answered else { return }
        let card = cards[index]
        if savesSession {
            guard manager.recordPracticeAnswer(course: course, lessonId: lessonId, checkpointUnitId: checkpointUnit?.id,
                sessionId: session, cardId: card.id, correct: correct) else {
                pendingGrade = correct; saveError = CourseLearningStore.shared.lastError ?? "Your progress couldn’t be saved. Please try again."; return
            }
            savedAnswers[card.id] = correct
        } else if !isCheckpoint, let unit = course.units.first(where: { $0.lessons.contains(where: { $0.cards.contains(where: { $0.id == card.id }) }) }),
           let lesson = unit.lessons.first(where: { $0.cards.contains(where: { $0.id == card.id }) }) {
            let success = manager.recordCardAnswer(courseId: course.id, sectionId: unit.id, lessonId: lesson.id,
                cardId: card.id, isCorrect: correct, eventToken: "\(session)-\(card.id)")
            if !success { pendingGrade = correct; saveError = CourseLearningStore.shared.lastError ?? "This lesson is locked. Return to the path."; return }
        }
        pendingGrade = nil; saveError = nil
        if !correct { missed.append(card.id) }
        lastCorrect = correct
        withAnimation(.snappy) { answered = true }
        if correct { HapticFeedback.success() } else { HapticFeedback.warning() }
    }
    private func restoreSession() {
        guard savesSession else { loaded = true; return }
        guard let restored = manager.resumePractice(course: course, lessonId: lessonId, checkpointUnitId: checkpointUnit?.id) else {
            saveError = CourseLearningStore.shared.lastError ?? "This practice is unavailable. Return to the path."
            return
        }
        session = restored.id
        savedAnswers = restored.answers
        missed = restored.missedCardIds
        saveError = nil
        loaded = true
        if let next = restored.nextIndex { index = next }
        else { finishSession() }
    }

    private func advance() {
        let next = savesSession ? cards.indices.first { savedAnswers[cards[$0].id] == nil } : (index + 1 < cards.count ? index + 1 : nil)
        if let next { index = next; answered = false; saveError = nil }
        else { finishSession() }
    }

    private func finishSession() {
        if savesSession {
            guard let completion = manager.finishPractice(course: course, lessonId: lessonId, checkpointUnitId: checkpointUnit?.id, sessionId: session) else {
                saveError = CourseLearningStore.shared.lastError ?? "Your result couldn’t be saved. Please try again."
                // The final answer is already saved; retry only finalization.
                index = max(0, cards.count - 1); answered = true
                return
            }
            result = completion.checkpointResult
        }
        finished = true
    }

    private func reset() {
        index = 0; answered = false; missed = []; finished = false; result = nil
        savedAnswers = [:]; session = UUID().uuidString; loaded = false
        restoreSession()
    }

}

private struct CourseCheckpointRemediation: View {
    let course: CourseDefinition
    let cards: [CourseLessonCard]
    let onDismiss: () -> Void
    var body: some View {
        CoursePracticeView(course: course, title: "Targeted practice", cards: cards, onDismiss: onDismiss)
    }
}
