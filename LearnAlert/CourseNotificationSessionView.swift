import SwiftUI

struct CourseNotificationSessionView: View {
    let course: CourseDefinition
    let requestId: String
    var reviewOnly = false
    let openApp: () -> Void
    @State private var reviewingCheckpoint = false
    @State private var card: CourseLessonCard?
    @State private var checkpoint: CourseUnit?
    @State private var answered = false
    @State private var error: String?
    @State private var complete = false
    @State private var lastCardId: String?
    @State private var showingGuide = false
    private var guideUnit: CourseUnit? {
        if let card, let unit = course.units.first(where: { $0.lessons.contains { $0.cards.contains { $0.id == card.id } } }) { return unit }
        let lessonId = CourseLearningStore.shared.snapshot().currentLesson(course: course)?.id
        return checkpoint ?? course.units.first { $0.lessons.contains { $0.id == lessonId } } ?? course.units.last
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    Text(course.title).font(.headline); Spacer()
                    if guideUnit != nil {
                        Button { showingGuide.toggle() } label: {
                            Image(systemName: showingGuide ? "arrow.left" : "book.closed").frame(width: 44, height: 44)
                        }.accessibilityLabel(showingGuide ? "Back to question" : "Section guide")
                    }
                    Button(action: openApp) { Image(systemName: "arrow.up.forward.app").frame(width: 44, height: 44) }.accessibilityLabel("Open learning path")
                }
                if showingGuide, let guideUnit { CourseGuideContent(course: course, unit: guideUnit, compact: true) }
                VStack(spacing: 16) {
                    if checkpoint != nil {
                        Button("Take checkpoint in app", action: openApp).buttonStyle(.borderedProminent)
                        if !reviewingCheckpoint {
                            Button("Review this section") { reviewingCheckpoint = true; load() }.buttonStyle(.bordered)
                        }
                    }
                    if let card {
                        CourseQuestionPanel(card: card, allowAudio: false) { correct in answer(card, correct: correct) }.id(card.id)
                        if answered { Button("Continue") { lastCardId = card.id; load() }.buttonStyle(.borderedProminent) }
                    } else if let checkpoint {
                        Image(systemName: "checkmark.shield.fill").font(.largeTitle).foregroundStyle(.blue)
                        Text(checkpoint.checkpointQuiz?.title ?? "Checkpoint ready").font(.headline)
                        Text("Complete this quiz in the app to unlock the next section.").font(.callout).multilineTextAlignment(.center)
                    } else {
                        Text(complete ? "Course complete" : "You're caught up for now").font(.headline)
                        Text(complete ? "Keep practicing with spaced reviews." : "Missed cards return after a short break.").font(.callout).foregroundStyle(.secondary)
                        Button("Open learning path", action: openApp).buttonStyle(.bordered)
                    }
                    if let error { Text(error).font(.callout).foregroundStyle(.red) }
                }.frame(height: showingGuide ? 0 : nil).clipped().opacity(showingGuide ? 0 : 1)
                    .accessibilityHidden(showingGuide).allowsHitTesting(!showingGuide)
            }.padding(16)
        }
        .onAppear { load(); Task { try? await CourseNotificationScheduler.replenish() } }
        .onDisappear { KoreanSpeechManager.shared.stop() }
    }
    private func load() {
        let snapshot = CourseLearningStore.shared.snapshot()
        checkpoint = reviewOnly ? nil : snapshot.pendingCheckpoint(course: course)
        // Keep the in-app gate visible while allowing due reviews from learned lessons.
        card = checkpoint == nil || reviewingCheckpoint
            ? snapshot.batch(course: course, count: 8, reviewOnly: reviewOnly || reviewingCheckpoint, randomized: true).first(where: { $0.id != lastCardId }) : nil
        complete = snapshot.currentLesson(course: course) == nil && checkpoint == nil
        answered = false; error = CourseLearningStore.shared.lastError
    }
    private func answer(_ card: CourseLessonCard, correct: Bool) {
        guard !answered, let lesson = course.units.flatMap(\.lessons).first(where: { $0.cards.contains(where: { $0.id == card.id }) }) else { return }
        let token = "notification-\(requestId)-\(card.id)"
        let applied = CourseLearningStore.shared.transaction {
            $0.answer(course: course, lessonId: lesson.id, cardId: card.id, correct: correct, token: token)
        } ?? false
        if let failure = CourseLearningStore.shared.lastError { error = failure }
        else { answered = true; if !applied { error = "This answer was already recorded." } }
        Task { try? await CourseNotificationScheduler.replenish() }
    }
}
