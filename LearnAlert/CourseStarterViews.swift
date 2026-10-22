import SwiftUI
import Combine

/// Uses production decoding/install/practice code with a separate cache, defaults
/// suite and progress directory. It never replaces the user's catalog or history.
@MainActor
final class CourseStarterPreviewContext {
    let catalog: ManagedCatalogStore
    let manager: CourseProgressManager
    let course: CourseDefinition
    init(baseCourse: CourseDefinition, directory: URL? = nil) throws {
        let base = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("VisualStarterDevelopmentPreview", isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        let defaults = UserDefaults(suiteName: "com.learnalert.development.visual-starter")
        catalog = ManagedCatalogStore(directory: base, defaults: defaults, developmentPreview: true, profile: "practice-v2")
        guard let url = Bundle.main.url(forResource: "visual-cafe-pilot", withExtension: "json") else { throw CocoaError(.fileReadNoSuchFile) }
        try catalog.installStarterPreview(baseCourse: baseCourse, componentData: Data(contentsOf: url))
        guard let installed = catalog.course(for: baseCourse.id) else { throw CocoaError(.coderReadCorrupt) }
        course = installed
        let store = CourseLearningStore(directory: base, defaults: defaults)
        let isolatedCatalog = catalog
        manager = CourseProgressManager(defaults: defaults, learningStore: store, isPreview: true, courseProvider: { id in isolatedCatalog.course(for: id) })
        _ = store.transaction { $0.assignRoute(course: installed, returningLearner: false); return true }
        manager.reloadFromSharedDefaults()
    }
}

struct CourseStarterPreviewHost: View {
    let baseCourse: CourseDefinition
    @State private var context: CourseStarterPreviewContext?
    @State private var failure: String?
    @State private var privateAudioQA = false
    @State private var confirmAudioQA = false
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Group {
                if let context {
                    CourseStarterHomeView(course: context.course, manager: context.manager)
                        .environment(\.coursePrivatePreviewAudio, privateAudioQA ? CoursePrivatePreviewAudio.url : { _ in nil })
                }
                else if let failure { ContentUnavailableView("Preview unavailable", systemImage: "exclamationmark.triangle", description: Text(failure)) }
                else { ProgressView("Opening separate preview…") }
            }
            .navigationTitle("Visual Spanish starter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close preview") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(privateAudioQA ? "Mute QA audio" : "Private audio QA") { if privateAudioQA { privateAudioQA = false; CardAudioPlayer.stopActive() } else { confirmAudioQA = true } }
                }
            }
            .alert("Private audio QA", isPresented: $confirmAudioQA) {
                Button("Enable for this preview") { privateAudioQA = true; UserDefaults.standard.set(true, forKey: "courseSyntheticVoiceDisclosureAccepted") }
                Button("Keep silent", role: .cancel) { }
            } message: { Text("These AI-generated cashier recordings await owner sound and pace approval. This enables manual playback of locally supplied files only. It does not approve or publish them.") }
        }.task {
            guard context == nil else { return }
            do { context = try CourseStarterPreviewContext(baseCourse: baseCourse) }
            catch { failure = error.localizedDescription }
        }
    }
}

struct CourseStarterHomeView: View {
    let course: CourseDefinition
    @ObservedObject var manager: CourseProgressManager
    @State private var lesson: CourseLesson?
    @State private var assessment = false
    @State private var failure: String?
    private var starterLessons: [CourseLesson] {
        manager.learningSnapshot.assignedStarterLessonIDs(course: course).compactMap { id in course.units.flatMap(\.lessons).first { $0.id == id } }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if manager.isPreview {
                    Label("Development preview · separate progress", systemImage: "hammer").font(.caption.weight(.semibold))
                    Text("Your normal Spanish course, history and alerts stay in their own store.").font(.callout).foregroundStyle(.secondary)
                }
                Text("Start with pictures").font(.system(.largeTitle, design: .serif).bold())
                Text((course.learning?.starter?.lessonIDs.count ?? 0) > 2 ? "Objects, short phrases, then a café visit. No typing or sound needed." : "Four everyday objects. Then one or two. No typing or sound needed.").font(.body).foregroundStyle(.secondary)
                Button(manager.learningSnapshot.activeAssessment(courseID: course.id)?.finalizedAt == nil && manager.learningSnapshot.activeAssessment(courseID: course.id) != nil ? "Resume starter check" : "Check what I know") { assessment = true }
                    .buttonStyle(.bordered).controlSize(.large)
                Text("Optional · 12 questions · covers starter lessons 1–2").font(.caption).foregroundStyle(.secondary)
                Text("Unlock with 10/12 overall and at least 2/3 in each area.").font(.caption).foregroundStyle(.secondary)
                if let revision = course.learning?.starter?.revision, let assigned = manager.learningSnapshot.routes[course.id], assigned.revision != revision {
                    Button("Use the updated starter route") {
                        _ = manager.learningStore.transaction { $0.adoptStarterRevision(course: course) }
                        manager.reloadFromSharedDefaults()
                    }.buttonStyle(.bordered).controlSize(.large)
                    Text("Your current lesson and previous progress stay in place.").font(.caption).foregroundStyle(.secondary)
                }
                ForEach(starterLessons) { item in
                    let status = manager.learningSnapshot.status(course: course, lessonId: item.id)
                    let credit = manager.learningSnapshot.assessmentAccess[course.id]?.contains(item.id) == true
                    Button {
                        _ = manager.learningStore.transaction { $0.selectStarter(course: course, selected: true); return true }
                        lesson = item
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top) {
                                Text(item.title).font(.title3.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 8)
                                Image(systemName: status == .locked ? "lock" : credit ? "arrow.forward.circle" : status == .completed ? "checkmark.circle" : "play.circle")
                            }
                            Text(credit ? "Access from starter check · study anytime" : status == .completed ? "Studied · practice again" : status == .locked ? "Finish the previous lesson to continue" : "Pictures, choices and short phrases")
                                .font(.callout).foregroundStyle(.secondary)
                        }.padding(.vertical, 16).frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                    }.buttonStyle(.plain).disabled(status == .locked)
                    Divider()
                }
                if manager.learningSnapshot.routes[course.id]?.returningLearner == true {
                    Button("Keep my previous Continue position") {
                        _ = manager.learningStore.transaction { $0.selectStarter(course: course, selected: false); return true }
                        manager.reloadFromSharedDefaults()
                    }.frame(minHeight: 44)
                }
                if let failure { Text(failure).foregroundStyle(.red).font(.callout) }
            }.padding(24).frame(maxWidth: 640).frame(maxWidth: .infinity, alignment: .leading)
        }.background(LearnAlertStyle.courseCanvas).tint(Color(hex: course.colorHex))
        .onAppear {
            let old = manager.learningSnapshot
            let returning = manager.isEnrolled(in: course.id) || old.progress[course.id]?.values.contains(where: { $0.totalAttemptsCount > 0 || $0.status == .completed }) == true
            if manager.learningStore.transaction({ $0.assignRoute(course: course, returningLearner: returning); return true }) != true { failure = manager.learningStore.lastError }
            manager.reloadFromSharedDefaults()
        }
        .fullScreenCover(item: $lesson, onDismiss: { manager.reloadFromSharedDefaults() }) { selected in
            CoursePracticeView(course: course, title: selected.title, cards: selected.cards, lessonId: selected.id, onDismiss: { lesson = nil }, manager: manager)
        }
        .sheet(isPresented: $assessment, onDismiss: { manager.reloadFromSharedDefaults() }) {
            NavigationStack { CourseStarterAssessmentView(course: course, manager: manager) }
        }
    }
}

struct CourseStarterAssessmentView: View {
    let course: CourseDefinition
    @ObservedObject var manager: CourseProgressManager
    @Environment(\.dismiss) private var dismiss
    @State private var attempt: CourseAssessmentAttempt?
    @State private var remediation: CourseLesson?
    @State private var error: String?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let attempt {
                    if attempt.finalizedAt != nil { result(attempt) }
                    else if let item = attempt.activeItem, let exercise = item.card.activity?.exercise {
                        Text("\(attempt.index + 1) of \(attempt.items.count)").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        ProgressView(value: Double(attempt.index), total: Double(attempt.items.count)).accessibilityLabel("Starter check progress")
                        CoursePracticeExercisePanel(card: item.card, exercise: exercise, immersive: true, checkpoint: true) { _ in reload() }
                            .id(attempt.id + item.id)
                            .environment(\.courseAssessmentPresentation, true)
                            .environment(\.courseExercisePersistence, CourseExercisePersistence(load: {
                                manager.learningStore.snapshot().assessmentAttempts[attempt.id]?.states[item.id]
                            }, save: { state in
                                manager.learningStore.transaction { $0.saveAssessmentState(courseID: course.id, assessmentID: attempt.id, itemID: item.id, state: state) } == true
                            }))
                        if attempt.states[item.id]?.result != nil {
                            Button(attempt.index == attempt.items.count - 1 ? "See results" : "Next question") { advance(attempt, item: item, skip: false) }
                                .buttonStyle(.borderedProminent).controlSize(.large)
                        } else {
                            Button("I don’t know") { advance(attempt, item: item, skip: true) }.frame(minHeight: 44)
                        }
                        Text("Answers stay saved. No hints or correctness feedback until the end.").font(.caption).foregroundStyle(.secondary)
                    }
                } else { ProgressView("Opening your check…") }
                if let error { Text(error).font(.callout).foregroundStyle(.red) }
            }.padding(24).frame(maxWidth: 640).frame(maxWidth: .infinity, alignment: .leading)
        }.background(LearnAlertStyle.courseCanvas).tint(Color(hex: course.colorHex))
        .navigationTitle("Starter check").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        .onAppear { start(retake: false) }
        .fullScreenCover(item: $remediation, onDismiss: { manager.reloadFromSharedDefaults() }) { lesson in
            CoursePracticeView(course: course, title: lesson.title, cards: lesson.cards, lessonId: lesson.id, onDismiss: { remediation = nil }, manager: manager)
        }
    }
    @ViewBuilder private func result(_ attempt: CourseAssessmentAttempt) -> some View {
        Text(attempt.passed == true ? "Starter access unlocked" : "A useful place to practise").font(.system(.largeTitle, design: .serif).bold())
        Text("\(attempt.score) of \(attempt.items.count) · \(attempt.passed == true ? "passed this small starter check" : "keep building these objects and quantities")").font(.title3)
        Text("This checks only the two visual starter lessons. It does not assess your overall Spanish level, listening or speaking. Access is separate from studied completion.").font(.callout).foregroundStyle(.secondary)
        ForEach(attempt.blueprint.objectiveIDs, id: \.self) { objective in
            Text("\(objectiveTitle(objective)) · \(attempt.score(objectiveID: objective))/3").font(.body)
        }
        if !attempt.remediationLessonIDs.isEmpty {
            Text("Practise next").font(.headline)
            ForEach(attempt.remediationLessonIDs, id: \.self) { id in
                if let target = remediationLesson(id) {
                    Button("Practise: " + target.title) { remediation = target }.frame(minHeight: 44)
                } else { Text("This lesson is unavailable in the current catalog.").font(.callout) }
            }
            Text("Return to these lessons for the short introductions and practice. If the second lesson is locked, start with the first.").font(.callout).foregroundStyle(.secondary)
        }
        Button("Back to starter lessons") { dismiss() }.buttonStyle(.borderedProminent).controlSize(.large)
        Button("Try the alternate check") { start(retake: true) }.frame(minHeight: 44)
    }
    private func remediationLesson(_ id: String) -> CourseLesson? {
        let lessons = course.units.flatMap(\.lessons)
        if manager.learningSnapshot.status(course: course, lessonId: id) != .locked { return lessons.first { $0.id == id } }
        return manager.learningSnapshot.assignedStarterLessonIDs(course: course).compactMap { target in lessons.first { $0.id == target } }.first { manager.learningSnapshot.status(course: course, lessonId: $0.id) != .locked }
    }
    private func objectiveTitle(_ id: String) -> String {
        switch id.suffix(3) { case "o01": "Spanish labels to meanings"; case "o02": "Meanings to Spanish labels"; case "o03": "One or two"; default: "Build a quantity phrase" }
    }
    private func start(retake: Bool) {
        let opened = manager.learningStore.transaction { $0.startAssessment(course: course, retake: retake) }
        guard let active = opened ?? nil else { error = manager.learningStore.lastError ?? "This starter check is unavailable."; return }
        attempt = active; error = nil
    }
    private func reload() {
        attempt = manager.learningStore.snapshot().activeAssessment(courseID: course.id)
        error = manager.learningStore.lastError
    }
    private func advance(_ attempt: CourseAssessmentAttempt, item: CourseAssessmentItem, skip: Bool) {
        guard manager.learningStore.transaction({ $0.advanceAssessment(courseID: course.id, assessmentID: attempt.id, itemID: item.id, skip: skip) }) == true else {
            reload()
            if self.attempt?.id == attempt.id, (self.attempt?.index ?? 0) > attempt.index { return }
            error = manager.learningStore.lastError ?? "The saved question changed. Close and reopen your check."; return
        }
        reload()
    }
}

/// No recording bytes are bundled or fetched here. A developer may place the
/// six reviewed files in this app-only preview folder. Ordinary courses never
/// receive this lookup environment, and it starts disabled every presentation.
@MainActor enum CoursePrivatePreviewAudio {
    static let files: [String: String] = [
        "Hola. ¿Qué te pongo?": "sp-cafe-cashier-01-order.mp3",
        "¿Solo o con leche?": "sp-cafe-cashier-02-milk-choice.mp3",
        "¿Para aquí o para llevar?": "sp-cafe-cashier-03-for-here-or-takeaway.mp3",
        "¿Algo más?": "sp-cafe-cashier-04-anything-else.mp3",
        "Son dos euros.": "sp-cafe-cashier-05-price.mp3",
        "Gracias. Hasta luego.": "sp-cafe-cashier-06-goodbye.mp3"
    ]
    static func url(_ utterance: String) -> URL? {
        guard let file = files[utterance] else { return nil }
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CafePrivateAudioQA", isDirectory: true).appendingPathComponent(file)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}
