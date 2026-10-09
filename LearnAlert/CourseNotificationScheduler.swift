import Foundation
import UserNotifications

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
    static func clear() { defaults?.removeObject(forKey: "course_alert_plan"); defaults?.synchronize() }
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
        if plan.stopWhenMastered == true && snapshot.isFullyMastered(course: course) {
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
            content.body = plan.reviewOnly == true ? "Review learned material · expand to practice" : snapshot.pendingCheckpoint(course: course) != nil ? "Checkpoint ready. Open the app to continue." : "Continue your course · expand to practice"
            content.categoryIdentifier = "FLASHCARD_REVEAL"
            content.sound = .default
            content.userInfo = ["courseId": course.id, "deckId": plan.deckId, "courseReviewOnly": plan.reviewOnly == true]
            if existing[id]?.content.body == content.body { continue }
            let trigger = UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents([.year,.month,.day,.hour,.minute,.second], from: date), repeats: false)
            try await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        }
        return dates
    }
    private static func identifier(plan: CourseAlertPlan, date: Date) -> String { "course-\(plan.courseId)-\(Int(date.timeIntervalSince1970))" }
}
