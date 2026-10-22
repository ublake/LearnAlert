import Foundation
import UserNotifications

/// The same section progress drives the expanded alert and its scheduled banner.
struct CourseNotificationProgress: Equatable {
    let unitId: String?
    let unitTitle: String
    let lessonTitle: String?
    let learnedCount: Int
    let totalCount: Int
    let completedLessons: Int
    let totalLessons: Int
    let checkpointUnitId: String?
    let isCourseComplete: Bool

    init(course: CourseDefinition, snapshot: CourseLearningSnapshot) {
        let checkpoint = snapshot.pendingCheckpoint(course: course)
        let lesson = snapshot.currentLesson(course: course)
        let unit = checkpoint ?? course.units.first { $0.lessons.contains { $0.id == lesson?.id } } ?? course.units.last
        unitId = unit?.id
        unitTitle = unit?.title ?? course.title
        lessonTitle = lesson?.title
        let lessons = unit?.lessons ?? []
        totalCount = lessons.reduce(0) { $0 + $1.cards.count }
        learnedCount = lessons.reduce(0) { total, lesson in
            let learned = Set(snapshot.progress[course.id]?[lesson.id]?.masteredCardIds ?? [])
            return total + learned.intersection(Set(lesson.cards.map(\.id))).count
        }
        totalLessons = lessons.count
        completedLessons = lessons.filter { snapshot.status(course: course, lessonId: $0.id) == .completed }.count
        checkpointUnitId = checkpoint?.id
        isCourseComplete = lesson == nil && checkpoint == nil
    }

    var fraction: Double { Double(learnedCount) / Double(max(1, totalCount)) }
    var compactLabel: String {
        if checkpointUnitId != nil { return "Practice complete · quiz ready" }
        if isCourseComplete { return "Course complete" }
        return "\(learnedCount) of \(totalCount) practiced"
    }

    static func nextLearningCard(course: CourseDefinition, snapshot: CourseLearningSnapshot, excluding: Set<String>) -> CourseLessonCard? {
        let taught = Set(snapshot.exerciseEvidence.values.filter { $0.courseID == course.id && $0.mode == "exposure" }.map(\.cardID))
            .union(snapshot.progress[course.id]?.values.flatMap(\.masteredCardIds) ?? [])
        let batch = snapshot.batch(course: course, count: 60, randomized: true).filter { card in
            guard let prerequisites = card.activity?.exercise?.prerequisiteIDs else { return true }
            return !card.isExposure && prerequisites.allSatisfy { taught.contains($0) }
        }
        return batch.first { !excluding.contains($0.id) }
            ?? batch.first { $0.activity?.practiceGroup != nil }
    }

    /// Optional extra practice stays inside completed, unlocked lessons even when nothing is due.
    static func practiceCards(course: CourseDefinition, snapshot: CourseLearningSnapshot, excluding: Set<String> = [], now: Date = Date()) -> [CourseLessonCard] {
        let due = snapshot.batch(course: course, count: 60, now: now, reviewOnly: true)
        let learned = course.units.flatMap(\.lessons)
            .filter { snapshot.status(course: course, lessonId: $0.id) == .completed }
            .flatMap { lesson in
                let known = Set(snapshot.progress[course.id]?[lesson.id]?.masteredCardIds ?? [])
                return lesson.cards.filter { !$0.isExposure && ($0.activity == nil || snapshot.srsRecord(courseId: course.id, cardId: $0.id) != nil || known.contains($0.id)) }
            }
            .sorted { (snapshot.srsRecord(courseId: course.id, cardId: $0.id)?.nextReviewDate ?? .distantPast) < (snapshot.srsRecord(courseId: course.id, cardId: $1.id)?.nextReviewDate ?? .distantPast) }
        var seen = excluding
        return (due + learned).filter { seen.insert($0.id).inserted }
    }
}

struct CourseAlertPlan: Codable, Equatable {
    let courseId: String
    let deckId: String
    let startHour: Int
    let startMinute: Int
    let endHour: Int
    let endMinute: Int
    let weekdays: [Int]
    let dailyCount: Int
    var expiresAt: Date? = nil
    var reviewOnly: Bool? = nil
    var stopWhenMastered: Bool? = nil
    var sound: String? = nil

    func dates(now: Date = Date(), calendar: Calendar = .current) -> [Date] {
        var result: [Date] = []
        // Include yesterday's start for an overnight window still open this morning.
        for offset in -1...7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now)),
                  weekdays.contains(calendar.component(.weekday, from: day)),
                  let start = calendar.date(bySettingHour: startHour, minute: startMinute, second: 0, of: day),
                  var end = calendar.date(bySettingHour: endHour, minute: endMinute, second: 0, of: day) else { continue }
            if end <= start { end = calendar.date(byAdding: .day, value: 1, to: end) ?? end }
            let count = min(50, max(1, dailyCount))
            let interval = end.timeIntervalSince(start) / Double(count)
            for index in 0..<count {
                let date = start.addingTimeInterval(interval * Double(index))
                if date > now.addingTimeInterval(1), expiresAt.map({ date < $0 }) ?? true { result.append(date) }
            }
        }
        return Array(result.sorted().prefix(60))
    }
}

@MainActor
enum CourseNotificationScheduler {
    private static var defaults: UserDefaults? { UserDefaults(suiteName: "group.com.learnalert.shared") }
    static var activePlan: CourseAlertPlan? {
        defaults?.synchronize()
        guard let data = defaults?.data(forKey: "course_alert_plan") else { return nil }
        return try? JSONDecoder().decode(CourseAlertPlan.self, from: data)
    }
    static func shouldStopWhenMastered(course: CourseDefinition, snapshot: CourseLearningSnapshot, enabled: Bool) -> Bool {
        enabled && snapshot.isFullyMastered(course: course)
    }
    static func clear() { defaults?.removeObject(forKey: "course_alert_plan"); defaults?.synchronize() }
    static func continuePractice(courseId: String, checkpointUnitId: String) {
        defaults?.set(checkpointUnitId, forKey: "course_checkpoint_practice_\(courseId)")
        defaults?.synchronize()
    }
    static func isContinuingPractice(courseId: String, checkpointUnitId: String?) -> Bool {
        defaults?.synchronize()
        guard let checkpointUnitId else { return false }
        return defaults?.string(forKey: "course_checkpoint_practice_\(courseId)") == checkpointUnitId
    }
    static func activate(_ plan: CourseAlertPlan) async throws -> [Date] {
        defaults?.set(try JSONEncoder().encode(plan), forKey: "course_alert_plan")
        defaults?.synchronize()
        do { return try await replenish() }
        catch { clear(); throw error }
    }
    @discardableResult
    static func replenish() async throws -> [Date] {
        guard let plan = activePlan, let course = CourseCurriculumCatalog.course(for: plan.courseId) else { return [] }
        let center = UNUserNotificationCenter.current()
        let dates = plan.dates()
        let ids = Set(dates.map { identifier(plan: plan, date: $0) })
        let pending = await center.pendingNotificationRequests()
        guard activePlan == plan else { return [] }
        let oldCourse = pending.filter { $0.content.userInfo["courseId"] != nil && !ids.contains($0.identifier) }
        center.removePendingNotificationRequests(withIdentifiers: oldCourse.map(\.identifier))
        let existing = Dictionary(uniqueKeysWithValues: pending.map { ($0.identifier, $0) })
        let snapshot = CourseLearningStore.shared.snapshot()
        // A failed shared-store read must not replace real progress with an empty snapshot.
        if let error = CourseLearningStore.shared.lastError { throw NSError(domain: "CourseLearning", code: 1, userInfo: [NSLocalizedDescriptionKey: error]) }
        let progress = CourseNotificationProgress(course: course, snapshot: snapshot)
        let continuingPractice = isContinuingPractice(courseId: course.id, checkpointUnitId: progress.checkpointUnitId)
        if shouldStopWhenMastered(course: course, snapshot: snapshot, enabled: plan.stopWhenMastered == true) {
            center.removePendingNotificationRequests(withIdentifiers: pending.filter { $0.content.userInfo["courseId"] as? String == course.id }.map(\.identifier))
            clear()
            defaults?.set(true, forKey: "extensionDidStopAlerts")
            defaults?.synchronize()
            return []
        }
        for date in dates {
            let id = identifier(plan: plan, date: date)
            guard activePlan == plan else { return [] }
            let content = UNMutableNotificationContent()
            content.title = course.title
            content.subtitle = progress.unitTitle
            if progress.checkpointUnitId != nil {
                content.body = continuingPractice || plan.reviewOnly == true
                    ? "More practice · your quiz is ready in the app"
                    : "Practice complete. Take your quiz in the app or expand to keep practicing."
            } else {
                content.body = plan.reviewOnly == true ? "Review learned material · expand to practice" : "\(progress.compactLabel) · expand to continue"
            }
            content.categoryIdentifier = "FLASHCARD_REVEAL"
            let sound = plan.sound ?? "Default"
            content.sound = sound == "Default" ? .default : UNNotificationSound(named: UNNotificationSoundName(sound))
            content.userInfo = ["courseId": course.id, "deckId": plan.deckId, "courseReviewOnly": plan.reviewOnly == true]
            if let unitId = progress.checkpointUnitId { content.userInfo["courseCheckpointSectionId"] = unitId }
            if existing[id]?.content.title == content.title && existing[id]?.content.body == content.body && existing[id]?.content.subtitle == content.subtitle { continue }
            let trigger = UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents([.year,.month,.day,.hour,.minute,.second], from: date), repeats: false)
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            try await center.add(request)
            AlertTimelineStore.shared.scheduled(request, date: date)
        }
        return dates
    }
    private static func identifier(plan: CourseAlertPlan, date: Date) -> String { "course-\(plan.courseId)-\(Int(date.timeIntervalSince1970))" }
}
