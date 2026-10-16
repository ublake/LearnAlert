import SwiftUI

struct CourseNotificationSessionView: View {
    let course: CourseDefinition
    let requestId: String
    var reviewOnly = false
    /// A section ID opens its checkpoint; nil opens the learning path.
    let openApp: (String?) -> Void
    var mediaPlaybackChanged: (Bool) -> Void = { _ in }
    @State private var reviewingCheckpoint = false
    @State private var card: CourseLessonCard?
    @State private var checkpoint: CourseUnit?
    @State private var progress: CourseNotificationProgress?
    @State private var answered = false
    @State private var pendingGrade: Bool?
    @State private var error: String?
    @State private var complete = false
    @State private var answeredCardIds: Set<String> = []
    @State private var answerToken = UUID().uuidString
    @State private var showingGuide = false
    @State private var readyAfterAnswer = false

    private var guideUnit: CourseUnit? {
        if let card, let unit = course.units.first(where: { $0.lessons.contains { $0.cards.contains { $0.id == card.id } } }) { return unit }
        return checkpoint ?? course.units.first { $0.id == progress?.unitId } ?? course.units.last
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                header
                if let progress { sectionProgress(progress) }
                if showingGuide, let guideUnit {
                    CourseGuideContent(course: course, unit: guideUnit, compact: true)
                } else {
                    practiceContent
                }
            }
            .padding(16)
        }
        .onAppear {
            load()
            Task { try? await CourseNotificationScheduler.replenish() }
        }
        .onReceive(KoreanSpeechManager.shared.$isSpeaking) { mediaPlaybackChanged($0) }
        .onDisappear {
            KoreanSpeechManager.shared.stop()
            mediaPlaybackChanged(false)
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text(course.title).font(.headline)
            Spacer(minLength: 4)
            if let checkpoint {
                Button { openApp(checkpoint.id) } label: {
                    Image(systemName: "bell.badge.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.red, .secondary)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Quiz ready. Take \(checkpoint.checkpointQuiz?.title ?? "checkpoint") in the app")
            }
            if guideUnit != nil {
                Button { showingGuide.toggle() } label: {
                    Image(systemName: showingGuide ? "arrow.left" : "book.closed").frame(width: 44, height: 44)
                }
                .accessibilityLabel(showingGuide ? "Back to question" : "Section guide")
            }
            Button { openApp(nil) } label: {
                Image(systemName: "arrow.up.forward.app").frame(width: 44, height: 44)
            }
            .accessibilityLabel("Open learning path")
        }
    }

    private func sectionProgress(_ progress: CourseNotificationProgress) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(progress.unitTitle).font(.caption.weight(.semibold)).lineLimit(2)
                Spacer()
                Text(progress.checkpointUnitId != nil ? "Quiz ready" : "\(progress.learnedCount)/\(progress.totalCount)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(progress.checkpointUnitId != nil ? Color.red : Color.secondary)
            }
            ProgressView(value: progress.fraction)
                .tint(progress.checkpointUnitId != nil ? .green : .accentColor)
                .accessibilityLabel("Section progress")
                .accessibilityValue(progress.compactLabel)
            if checkpoint == nil, let lessonTitle = progress.lessonTitle {
                Text(lessonTitle).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
        }
    }

    @ViewBuilder
    private var practiceContent: some View {
        VStack(spacing: 14) {
            if let card {
                // Audio begins only from Play. Listening exercises retain a reading alternative.
                CourseQuestionPanel(card: card, allowAudio: true) { correct in answer(card, correct: correct) }
                    .id(card.id + answerToken)
                if let pendingGrade {
                    Button("Retry saving answer") { answer(card, correct: pendingGrade) }.buttonStyle(.borderedProminent)
                } else if answered && !readyAfterAnswer {
                    Button("Continue") { load() }.buttonStyle(.borderedProminent)
                }
                if readyAfterAnswer, let checkpoint { checkpointPrompt(checkpoint) }
            } else if let checkpoint, !reviewingCheckpoint {
                checkpointPrompt(checkpoint)
            } else {
                Image(systemName: complete ? "checkmark.seal.fill" : "checkmark.circle")
                    .font(.largeTitle).foregroundStyle(.green)
                Text(complete ? "Course complete" : reviewingCheckpoint ? "Practice complete" : "You're caught up for now").font(.headline)
                Text(reviewingCheckpoint ? "Your quiz is ready whenever you are." : complete ? "Keep practicing with spaced reviews." : "Missed cards return after a short break.")
                    .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                if let checkpoint {
                    Button("Take quiz in app") { openApp(checkpoint.id) }.buttonStyle(.borderedProminent)
                    Button("Practice again") { answeredCardIds = []; load() }.buttonStyle(.bordered)
                } else {
                    Button("Open learning path") { openApp(nil) }.buttonStyle(.bordered)
                }
            }
            if let error { Text(error).font(.callout).foregroundStyle(.red).multilineTextAlignment(.center) }
        }
    }

    private func checkpointPrompt(_ unit: CourseUnit) -> some View {
        VStack(spacing: 10) {
            Label("Quiz ready", systemImage: "checkmark.shield.fill").font(.headline).foregroundStyle(.green)
            Text("\(unit.checkpointQuiz?.questions.count ?? 0) questions in the app to unlock the next section.")
                .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Take quiz in app") { openApp(unit.id) }.buttonStyle(.borderedProminent)
            Button("Keep practicing in alerts") {
                CourseNotificationScheduler.continuePractice(courseId: course.id, checkpointUnitId: unit.id)
                reviewingCheckpoint = true
                load()
                Task { try? await CourseNotificationScheduler.replenish() }
            }
            .buttonStyle(.bordered)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(.green.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
    }

    private func refreshProgress(_ snapshot: CourseLearningSnapshot) {
        checkpoint = snapshot.pendingCheckpoint(course: course)
        progress = CourseNotificationProgress(course: course, snapshot: snapshot)
        complete = progress?.isCourseComplete == true
    }

    private func load() {
        KoreanSpeechManager.shared.stop()
        let snapshot = CourseLearningStore.shared.snapshot()
        if let failure = CourseLearningStore.shared.lastError {
            error = "Your progress couldn’t be loaded. Open the app to try again. \(failure)"
            return
        }
        refreshProgress(snapshot)
        reviewingCheckpoint = checkpoint != nil && (reviewingCheckpoint || reviewOnly || CourseNotificationScheduler.isContinuingPractice(courseId: course.id, checkpointUnitId: checkpoint?.id))
        if reviewingCheckpoint || reviewOnly {
            card = CourseNotificationProgress.practiceCards(course: course, snapshot: snapshot, excluding: answeredCardIds).first
        } else if checkpoint == nil {
            card = CourseNotificationProgress.nextLearningCard(course: course, snapshot: snapshot, excluding: answeredCardIds)
        } else {
            card = nil
        }
        answered = false
        pendingGrade = nil
        readyAfterAnswer = false
        answerToken = UUID().uuidString
        error = nil
    }

    private func answer(_ card: CourseLessonCard, correct: Bool) {
        guard !answered, let lesson = course.units.flatMap(\.lessons).first(where: { $0.cards.contains(where: { $0.id == card.id }) }) else { return }
        let token = "notification-\(requestId)-\(answerToken)-\(card.id)"
        let hadCheckpoint = checkpoint != nil
        let saved = CourseLearningStore.shared.transaction { snapshot in
            if snapshot.eventTokens.contains(token) { return true }
            return snapshot.answer(course: course, lessonId: lesson.id, cardId: card.id, correct: correct, token: token)
        } ?? false
        guard saved else {
            pendingGrade = correct
            error = CourseLearningStore.shared.lastError ?? "Your answer couldn’t be saved. Retry before continuing."
            return
        }
        answered = true
        pendingGrade = nil
        answeredCardIds.insert(card.id)
        error = nil
        let snapshot = CourseLearningStore.shared.snapshot()
        if let failure = CourseLearningStore.shared.lastError {
            error = "Answer saved. Progress couldn’t be refreshed: \(failure)"
        } else {
            refreshProgress(snapshot)
            readyAfterAnswer = !hadCheckpoint && checkpoint != nil
        }
        Task { try? await CourseNotificationScheduler.replenish() }
    }
}
