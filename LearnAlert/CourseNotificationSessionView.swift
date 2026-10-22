import SwiftUI
import Combine

private struct CourseNotificationCompactKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var courseNotificationCompact: Bool {
        get { self[CourseNotificationCompactKey.self] }
        set { self[CourseNotificationCompactKey.self] = newValue }
    }
}

/// Keep the familiar height unless readable content genuinely needs more room.
nonisolated enum CourseNotificationSizing {
    static func maximumHeight(screenHeight: CGFloat) -> CGFloat {
        NotificationViewportGeometry.maximumHeight(containerHeight: screenHeight)
    }
    static func height(contentHeight: CGFloat, screenHeight: CGFloat, preserveDrawingHeight: Bool = false) -> CGFloat {
        NotificationViewportGeometry.preferredHeight(contentHeight: preserveDrawingHeight ? 540 : contentHeight,
            containerHeight: screenHeight, baseline: 540)
    }
}

private struct CourseNotificationHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

struct CourseNotificationSessionView: View {
    let course: CourseDefinition
    let requestId: String
    var reviewOnly = false
    /// A section ID opens its checkpoint; nil opens the learning path.
    let openApp: (String?) -> Void
    var mediaPlaybackChanged: (Bool) -> Void = { _ in }
    var contentHeightChanged: (_ height: CGFloat, _ preserveDrawingHeight: Bool) -> Void = { _, _ in }
    @State private var assessmentPending = false
    @State private var starterNeedsApp = false
    @State private var reviewingCheckpoint = false
    @State private var card: CourseLessonCard?
    @State private var checkpoint: CourseUnit?
    @State private var progress: CourseNotificationProgress?
    @State private var answered = false
    @State private var exerciseAttemptID: String?
    @State private var pendingGrade: Bool?
    @State private var error: String?
    @State private var complete = false
    @State private var answeredCardIds: Set<String> = []
    @State private var answerToken = UUID().uuidString
    @State private var showingGuide = false
    @State private var readyAfterAnswer = false
    @State private var guidePage = 0
    @State private var prefersReading = false

    // Tracing stays on its existing presentation pending a separate interaction decision.
    private var compact: Bool { showingGuide || card?.activity?.kind != .trace }

    private var guideUnit: CourseUnit? {
        if let card, let unit = course.units.first(where: { $0.lessons.contains { $0.cards.contains { $0.id == card.id } } }) { return unit }
        return checkpoint ?? course.units.first { $0.id == progress?.unitId } ?? course.units.last
    }

    var body: some View {
        ScrollView {
            VStack(spacing: compact ? 8 : 14) {
                header
                if let progress { sectionProgress(progress) }
                if showingGuide, let guideUnit {
                    guideContent(guideUnit)
                }
                practiceContent
                    .frame(height: showingGuide ? 0 : nil)
                    .opacity(showingGuide ? 0 : 1)
                    .allowsHitTesting(!showingGuide)
                    .accessibilityHidden(showingGuide)
            }
            .padding(compact ? 12 : 16)
            .background(GeometryReader { geometry in
                Color.clear.preference(key: CourseNotificationHeightKey.self, value: geometry.size.height)
            })
        }
        .environment(\.courseNotificationCompact, compact)
        .scrollBounceBehavior(compact ? .basedOnSize : .automatic)
        .onPreferenceChange(CourseNotificationHeightKey.self) { height in
            if height > 0 { contentHeightChanged(compact ? height : 540, !compact) }
        }
        .onAppear {
            load()
            Task { try? await CourseNotificationScheduler.replenish() }
        }
        .onReceive(speechChanges) { mediaPlaybackChanged($0 || CardAudioPlayer.isAnyPlaying) }
        .onReceive(CardAudioPlayer.playbackChanges) { mediaPlaybackChanged($0 || (CourseAudioPolicy.allowsKoreanSpeech(for: course.language) && KoreanSpeechManager.shared.isSpeaking)) }
        .onDisappear {
            stopPlayback()
            mediaPlaybackChanged(false)
        }
    }

    private var speechChanges: AnyPublisher<Bool, Never> {
        CourseAudioPolicy.allowsKoreanSpeech(for: course.language)
            ? KoreanSpeechManager.shared.$isSpeaking.eraseToAnyPublisher()
            : Just(false).eraseToAnyPublisher()
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
                Button {
                    stopPlayback()
                    guidePage = 0
                    showingGuide.toggle()
                } label: {
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
        VStack(alignment: .leading, spacing: compact ? 4 : 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(progress.unitTitle).font(.caption.weight(.semibold)).lineLimit(compact ? 1 : 2)
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
                Text(lessonTitle).font(.caption).foregroundStyle(.secondary).lineLimit(compact ? 1 : 2)
            }
        }
    }

    @ViewBuilder
    private var practiceContent: some View {
        VStack(spacing: compact ? 8 : 14) {
            if assessmentPending || starterNeedsApp {
                Text(assessmentPending ? "Your starter check is saved in the app." : "Meet the new words in the app first.").font(.headline)
                Button(assessmentPending ? "Resume starter check" : "Open visual starter") { openApp(nil) }.buttonStyle(.borderedProminent).frame(minHeight: 44)
            } else if readyAfterAnswer, let checkpoint {
                checkpointPrompt(checkpoint)
            } else if let card {
                // Audio begins only from Play. Listening exercises retain a reading alternative.
                CourseQuestionPanel(card: card, allowRecordedAudio: true,
                    allowKoreanSpeech: CourseAudioPolicy.allowsKoreanSpeech(for: course.language),
                    prefersReading: prefersReading,
                    onReadingRequested: { stopPlayback(); prefersReading = true },
                    onListeningRequested: { prefersReading = false }) { correct in answer(card, correct: correct) }
                    .id(card.id + answerToken)
                    .environment(\.courseExercisePersistence, .shared(courseID: course.id, card: card))
                    .environment(\.courseExerciseAttemptReported, { exerciseAttemptID = $0 })
                if let pendingGrade {
                    Button("Retry saving answer") { answer(card, correct: pendingGrade) }.buttonStyle(.borderedProminent)
                } else if answered && !readyAfterAnswer {
                    Button("Continue") { load() }.buttonStyle(.borderedProminent)
                }
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

    /// Detailed notes remain complete, one topic at a time rather than one long scroll.
    private func guideContent(_ unit: CourseUnit) -> some View {
        let topics = CourseSectionGuides.topics(course: course, unit: unit)
        let hasDiagram = course.language == "Korean" && unit.unitNumber == 1
        let count = topics.count + (hasDiagram ? 1 : 0)
        let index = min(guidePage, max(0, count - 1))
        return VStack(alignment: .leading, spacing: 12) {
            if hasDiagram && index == 0 {
                HangulStackingDiagram()
            } else if topics.indices.contains(index - (hasDiagram ? 1 : 0)) {
                let topic = topics[index - (hasDiagram ? 1 : 0)]
                Text(topic.title).font(.headline)
                Text(CourseKoreanText.attributed(topic.rule)).font(.body).fixedSize(horizontal: false, vertical: true)
                ForEach(topic.examples, id: \.self) { example in
                    Text(CourseKoreanText.attributed(example)).font(.callout).fixedSize(horizontal: false, vertical: true)
                }
            }
            HStack {
                Button { guidePage = max(0, index - 1) } label: {
                    Label("Back", systemImage: "chevron.left").frame(minHeight: 44)
                }.disabled(index == 0)
                Spacer()
                Text("\(index + 1)/\(max(1, count))").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    .accessibilityLabel("Guide page \(index + 1) of \(max(1, count))")
                Spacer()
                Button { guidePage = min(count - 1, index + 1) } label: {
                    Label("Next", systemImage: "chevron.right").frame(minHeight: 44)
                }.disabled(index + 1 >= count)
            }.buttonStyle(.bordered)
            if hasDiagram && index + 1 == count {
                Link("More about Hangul", destination: URL(string: "https://www.korean.go.kr/eng_hangeul/principle/001.html")!)
                    .font(.footnote).frame(minHeight: 44)
            }
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
        stopPlayback()
        if answered, let card, card.activity?.exercise != nil {
            guard CourseLearningStore.shared.transaction({
                return $0.acknowledgeRenderedExercise(courseID: course.id, card: card, attemptID: exerciseAttemptID)
            }) == true else { error = "Continue couldn’t be saved. Try again."; return }
        }
        let pending = CourseLearningStore.shared.transaction { $0.resumeNotificationExercise(course: course) } ?? nil
        if let failure = CourseLearningStore.shared.lastError {
            error = "Your saved answer couldn’t be reopened. Open the app to try again. " + failure
            return
        }
        let snapshot = CourseLearningStore.shared.snapshot()
        if let failure = CourseLearningStore.shared.lastError {
            error = "Your progress couldn’t be loaded. Open the app to try again. \(failure)"
            return
        }
        refreshProgress(snapshot)
        assessmentPending = snapshot.activeAssessment(courseID: course.id).map { $0.finalizedAt == nil } ?? false
        starterNeedsApp = course.learning?.starter?.lessonIDs.contains(snapshot.currentLesson(course: course)?.id ?? "") == true && CourseNotificationProgress.nextLearningCard(course: course, snapshot: snapshot, excluding: []) == nil
        reviewingCheckpoint = checkpoint != nil && (reviewingCheckpoint || reviewOnly || CourseNotificationScheduler.isContinuingPractice(courseId: course.id, checkpointUnitId: checkpoint?.id))
        exerciseAttemptID = pending?.attemptID
        let pendingCard = pending.flatMap { acknowledgement in
            course.units.flatMap(\.lessons).flatMap(\.cards).first { $0.id == acknowledgement.cardID && $0.activity?.exercise != nil }
        }
        if let pendingCard { card = pendingCard }
        else if reviewingCheckpoint || reviewOnly {
            card = CourseNotificationProgress.practiceCards(course: course, snapshot: snapshot, excluding: answeredCardIds).first
        } else if checkpoint == nil {
            card = CourseNotificationProgress.nextLearningCard(course: course, snapshot: snapshot, excluding: answeredCardIds)
        } else {
            card = nil
        }
        answered = pendingCard != nil
        if let pendingCard { answeredCardIds.insert(pendingCard.id) }
        pendingGrade = nil
        readyAfterAnswer = false
        answerToken = UUID().uuidString
        error = nil
    }

    private func answer(_ card: CourseLessonCard, correct: Bool) {
        guard !answered, let lesson = course.units.flatMap(\.lessons).first(where: { $0.cards.contains(where: { $0.id == card.id }) }) else { return }
        stopPlayback()
        let token = "notification-\(requestId)-\(answerToken)-\(card.id)"
        let hadCheckpoint = checkpoint != nil
        let saved = CourseLearningStore.shared.transaction { snapshot in
            if snapshot.eventTokens.contains(token) { return true }
            return snapshot.answerNotificationExercise(course: course, lessonID: lesson.id, cardID: card.id, correct: correct, token: token, attemptID: exerciseAttemptID)
        } ?? false
        guard saved else {
            pendingGrade = correct
            error = CourseLearningStore.shared.lastError ?? "Your answer couldn’t be saved. Retry before continuing."
            return
        }
        AlertTimelineStore.shared.answered(requestId)
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

    private func stopPlayback() {
        if CourseAudioPolicy.allowsKoreanSpeech(for: course.language) { KoreanSpeechManager.shared.stop() }
        CardAudioPlayer.stopActive()
    }
}
