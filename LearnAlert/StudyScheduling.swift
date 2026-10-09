import Foundation

enum StudyScheduling {
    static func window(now: Date, startHour: Int, startMinute: Int, endHour: Int,
                       endMinute: Int, calendar: Calendar = .current) -> (start: Date, end: Date)? {
        guard var start = calendar.date(bySettingHour: startHour, minute: startMinute, second: 0, of: now),
              var end = calendar.date(bySettingHour: endHour, minute: endMinute, second: 0, of: now) else { return nil }
        if endHour * 60 + endMinute <= startHour * 60 + startMinute {
            // Before the closing hour, yesterday's overnight window is still open.
            if now < end {
                start = calendar.date(byAdding: .day, value: -1, to: start) ?? start
            } else { end = calendar.date(byAdding: .day, value: 1, to: end) ?? end }
        }
        if now.addingTimeInterval(300) > end {
            start = calendar.date(byAdding: .day, value: 1, to: start) ?? start
            end = calendar.date(byAdding: .day, value: 1, to: end) ?? end
        } else if now > start {
            start = now.addingTimeInterval(90)
        }
        return (start, end)
    }

    static func sequentialBatch<T: Identifiable>(_ ordered: [T], nextID: T.ID?, count: Int) -> [T] {
        guard !ordered.isEmpty, count > 0 else { return [] }
        let start = nextID.flatMap { id in ordered.firstIndex { $0.id == id } } ?? 0
        return (0..<min(count, ordered.count)).map { ordered[(start + $0) % ordered.count] }
    }
}
