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

private struct CoursePracticeView: View {
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

    private var isCheckpoint: Bool { checkpointUnit != nil }
    private var missedCards: [CourseLessonCard] { cards.filter { missed.contains($0.id) } }

    var body: some View {
        NavigationStack {
            ZStack {
                LearnAlertStyle.courseCanvas.ignoresSafeArea()
                if finished {
                    VStack(spacing: 18) {
                        Image(systemName: result?.passed == true ? "checkmark.seal.fill" : "flag.checkered").font(.system(size: 48)).foregroundStyle(.blue)
                        Text(finishTitle).font(.title2.bold())
                        Text("\(cards.count - missed.count) / \(cards.count)").font(.headline)
                        if let result, !result.passed {
                            Text("Score \(Int(result.percentage * 100))% · Pass at \(Int((manager.enrollment(for: course.id)?.checkpointPassingThreshold ?? checkpointUnit?.checkpointQuiz?.passingScoreThreshold ?? 0.8) * 100))%")
                                .font(.callout).foregroundStyle(.secondary)
                            if !result.missedConcepts.isEmpty { Text(result.missedConcepts.joined(separator: " · ")).font(.callout).multilineTextAlignment(.center) }
                            Button("Practice missed questions") { reviewMisses = true }.buttonStyle(.bordered)
                            Button("Retry checkpoint") { reset() }.buttonStyle(.borderedProminent)
                        } else if !missed.isEmpty {
                            Text("Missed cards return in later reviews.").font(.callout).foregroundStyle(.secondary)
                        }
                        Button("Back to path") { onDismiss() }.buttonStyle(.borderedProminent)
                    }.padding(24)
                } else if cards.indices.contains(index) {
                    VStack(spacing: 14) {
                        HStack {
                            Text("\(index + 1) / \(cards.count)").font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            if !isCheckpoint && course.language == "Korean" {
                                Toggle(isOn: $autoPronounce) { Image(systemName: "speaker.wave.2") }.labelsHidden()
                                    .accessibilityLabel("Automatic Korean pronunciation")
                            }
                        }
                        ProgressView(value: Double(index), total: Double(max(1, cards.count))).tint(Color(hex: course.colorHex))
                        ScrollView {
                            CourseQuestionPanel(card: cards[index], checkpoint: isCheckpoint,
                                allowAudio: course.language == "Korean") { correct in record(correct: correct) }
                                .id("\(session)-\(index)")
                        }
                        if let saveError {
                            Text(saveError).font(.callout).foregroundStyle(.red)
                            if let pendingGrade { Button("Retry saving") { record(correct: pendingGrade) }.buttonStyle(.bordered) }
                        }
                        if answered {
                            Button(index == cards.count - 1 ? "Finish" : "Continue") { advance() }
                                .buttonStyle(.borderedProminent).controlSize(.large).frame(maxWidth: .infinity)
                        }
                    }.padding(20)
                } else { ContentUnavailableView("No questions", systemImage: "book.closed") }
            }
            .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Exit") { onDismiss() } } }
            .onAppear { autoPronounce = manager.enrollment(for: course.id)?.autoPronounceInStudy ?? false; speakCurrent() }
            .onChange(of: index) { _, _ in speakCurrent() }
            .onChange(of: autoPronounce) { _, value in
                manager.setAutoPronounce(value, courseId: course.id)
                if value { speakCurrent() } else { KoreanSpeechManager.shared.stop() }
            }
            .onDisappear { KoreanSpeechManager.shared.stop() }
            .sheet(isPresented: $reviewMisses) {
                // Checkpoint remediation is practice only: it cannot unlock the next section.
                CourseCheckpointRemediation(course: course, cards: missedCards) { reviewMisses = false }
            }
        }.interactiveDismissDisabled(isCheckpoint && answered)
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
        if !isCheckpoint, let unit = course.units.first(where: { $0.lessons.contains(where: { $0.cards.contains(where: { $0.id == card.id }) }) }),
           let lesson = unit.lessons.first(where: { $0.cards.contains(where: { $0.id == card.id }) }) {
            let success = manager.recordCardAnswer(courseId: course.id, sectionId: unit.id, lessonId: lesson.id,
                cardId: card.id, isCorrect: correct, eventToken: "\(session)-\(card.id)")
            if !success { pendingGrade = correct; saveError = CourseLearningStore.shared.lastError ?? "This lesson is locked. Return to the path."; return }
        }
        pendingGrade = nil; saveError = nil
        if !correct { missed.append(card.id) }
        answered = true
        HapticFeedback.selection()
    }
    private func advance() {
        if index + 1 < cards.count { index += 1; answered = false; saveError = nil }
        else {
            if let unit = checkpointUnit, let quiz = unit.checkpointQuiz {
                result = manager.recordCheckpointResult(courseId: course.id, sectionId: unit.id, checkpointId: quiz.id,
                    score: cards.count - missed.count, totalQuestions: cards.count, missedQuestionIds: missed,
                    missedConcepts: cards.filter { missed.contains($0.id) }.compactMap(\.conceptTag))
                if let error = CourseLearningStore.shared.lastError { saveError = error; return }
            }
            finished = true
        }
    }
    private func reset() { index = 0; answered = false; missed = []; finished = false; result = nil; session = UUID().uuidString }
}

private struct CourseCheckpointRemediation: View {
    let course: CourseDefinition
    let cards: [CourseLessonCard]
    let onDismiss: () -> Void
    @State private var index = 0
    @State private var answered = false
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if cards.indices.contains(index) {
                    ScrollView { CourseQuestionPanel(card: cards[index]) { _ in answered = true }.id(index) }
                    if answered { Button("Continue") { index += 1; answered = false }.buttonStyle(.borderedProminent) }
                } else { Button("Back to checkpoint") { onDismiss() }.buttonStyle(.borderedProminent) }
            }.padding(20).navigationTitle("Targeted practice").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { onDismiss() } } }
        }
    }
}
