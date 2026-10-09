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

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack { Text(course.title).font(.headline); Spacer(); Button(action: openApp) { Image(systemName: "arrow.up.forward.app") }.accessibilityLabel("Open learning path") }
                if let checkpoint {
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
            ? snapshot.batch(course: course, count: 8, reviewOnly: reviewOnly || reviewingCheckpoint).first(where: { $0.id != lastCardId }) : nil
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
