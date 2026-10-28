import Foundation

nonisolated enum AlertPaceMode: String, Codable, CaseIterable, Identifiable {
    case automatic, custom
    var id: Self { self }
    var title: String { self == .automatic ? "Automatic" : "Custom" }
}

/// Personal scheduling preferences; community exports do not include these settings.
nonisolated struct DeckAlertSettings: Codable, Equatable {
    var paceMode = AlertPaceMode.custom
    var dailyCount = 20
    var minimumSpacingMinutes = 60
    var questionsPerAlert = 3
    var startHour = 10
    var startMinute = 0
    var endHour = 19
    var endMinute = 0
    var useSpecificTime = false
    var specificHour = 17
    var specificMinute = 0
    var stopCondition = "Until I say so"
    var smartSRS = true
    /// An optional starting level skips basics while retaining automatic progression.
    var bundleLevelID: String? = nil

    static func defaults(in defaults: UserDefaults = .standard) -> Self {
        if let data = defaults.data(forKey: "defaultDeckAlertSettings"),
           let saved = try? JSONDecoder().decode(Self.self, from: data) { return saved }
        var result = Self()
        let options = [3, 5, 7, 10, 15]
        let savedIndex = defaults.object(forKey: "volumeSelectionIndex") as? Int
        result.paceMode = .custom
        let index = savedIndex ?? 3
        result.dailyCount = savedIndex == nil ? 20 : index == 5 ? min(30, max(1, defaults.object(forKey: "customVolume") as? Int ?? 20)) : options[min(4, max(0, index))]
        result.startHour = defaults.object(forKey: "startHour") as? Int ?? 10
        result.startMinute = defaults.object(forKey: "startMinute") as? Int ?? 0
        result.endHour = defaults.object(forKey: "endHour") as? Int ?? 19
        result.endMinute = defaults.object(forKey: "endMinute") as? Int ?? 0
        result.stopCondition = defaults.string(forKey: "stopCondition") ?? "Until I say so"
        result.smartSRS = defaults.object(forKey: "smartSRS") as? Bool ?? true
        return result
    }

    var isCustomDaily: Bool { dailyCount == 1 }
    var dailyHour: Int { isCustomDaily && useSpecificTime ? specificHour : startHour }
    var dailyMinute: Int { isCustomDaily && useSpecificTime ? specificMinute : startMinute }

    func resolvedDailyCount(automaticCount: Int) -> Int {
        min(30, max(1, dailyCount))
    }

    var resolvedQuestionsPerAlert: Int { min(3, max(1, questionsPerAlert)) }
    var resolvedSpacingMinutes: Int { min(24 * 60, max(60, minimumSpacingMinutes)) }
    var plannedAlertsPerDay: Int { min(resolvedDailyCount(automaticCount: 20), Int(ceil(20.0 / Double(resolvedQuestionsPerAlert)))) }

    /// Describes the actual capacity instead of promising a crowded daily total.
    var scheduleSummary: String {
        let count: Int
        if isCustomDaily { count = 1 }
        else {
            let start = startHour * 60 + startMinute
            let end = endHour * 60 + endMinute
            let duration = end > start ? end - start : 24 * 60 - start + end
            count = min(plannedAlertsPerDay, max(1, Int(ceil(Double(duration) / Double(resolvedSpacingMinutes)))))
        }
        return "Up to \(count) \(count == 1 ? "alert" : "alerts") · \(resolvedSpacingMinutes) min apart · \(resolvedQuestionsPerAlert) \(resolvedQuestionsPerAlert == 1 ? "question" : "questions") each"
    }

    static func automaticDailyCount(cardCount: Int?, courseTarget: Int? = nil) -> Int {
        if let courseTarget { return min(50, max(1, courseTarget)) }
        return min(10, max(1, cardCount ?? 10))
    }
}

extension DeckAlertSettings {
    /// Saved numeric schedules predate the mode selector and remain explicit choices.
    nonisolated init(from decoder: Decoder) throws {
        self.init()
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let oldMode = try values.decodeIfPresent(AlertPaceMode.self, forKey: .paceMode) ?? .custom
        paceMode = .custom
        dailyCount = oldMode == .automatic ? 20 : min(30, max(1, try values.decodeIfPresent(Int.self, forKey: .dailyCount) ?? 20))
        minimumSpacingMinutes = max(60, min(24 * 60, try values.decodeIfPresent(Int.self, forKey: .minimumSpacingMinutes) ?? 60))
        questionsPerAlert = min(3, max(1, try values.decodeIfPresent(Int.self, forKey: .questionsPerAlert) ?? 3))
        startHour = try values.decodeIfPresent(Int.self, forKey: .startHour) ?? 10
        startMinute = try values.decodeIfPresent(Int.self, forKey: .startMinute) ?? 0
        endHour = try values.decodeIfPresent(Int.self, forKey: .endHour) ?? 19
        endMinute = try values.decodeIfPresent(Int.self, forKey: .endMinute) ?? 0
        useSpecificTime = try values.decodeIfPresent(Bool.self, forKey: .useSpecificTime) ?? false
        specificHour = try values.decodeIfPresent(Int.self, forKey: .specificHour) ?? 17
        specificMinute = try values.decodeIfPresent(Int.self, forKey: .specificMinute) ?? 0
        stopCondition = try values.decodeIfPresent(String.self, forKey: .stopCondition) ?? "Until I say so"
        smartSRS = try values.decodeIfPresent(Bool.self, forKey: .smartSRS) ?? true
        bundleLevelID = try values.decodeIfPresent(String.self, forKey: .bundleLevelID)
    }
}

/// An editor owns this value until Save; changing it never writes live preferences.
nonisolated struct AlertScheduleEdit: Equatable {
    var targetId = "ALL"
    var settings = DeckAlertSettings()
    var sound = "alert3.wav"
}

nonisolated struct DailyDeckAlertPlan: Codable, Equatable {
    var id = UUID().uuidString
    let deckId: UUID
    let sectionId: UUID?
    let cardIds: [UUID]
    let anchor: Date
    let hour: Int
    let minute: Int
    let expiresAt: Date?
    var stopWhenMastered = false
    var sound = "Default"
    /// Optional so older single-time plans continue decoding without migration.
    var window: DeckAlertWindow? = nil
    /// Compatibility for saved recurring language alerts, now ordinary decks.
    var compatibilityWindow: LegacyDeckScheduleWindow? = nil
    var singleTimeQuestionsPerAlert: Int? = nil
    var singleTimeSpacingMinutes: Int? = nil

    var questionsPerAlert: Int { min(3, max(1, window?.questionsPerAlert ?? singleTimeQuestionsPerAlert ?? 3)) }
    var minimumSpacingMinutes: Int { max(60, window?.minimumSpacingMinutes ?? singleTimeSpacingMinutes ?? 60) }
    var requestedDailyCount: Int { min(30, max(1, window?.notificationLimit ?? compatibilityWindow?.dailyCount ?? 1)) }

    var identifierPrefix: String { compatibilityWindow?.identifierPrefix ?? "daily-deck-\(id)" }

    /// Keep local availability across daylight-saving changes. A short window
    /// reduces capacity; it never compresses the minimum spacing to meet a target.
    func slots(now: Date = Date(), calendar: Calendar = .current) -> [(date: Date, cardId: UUID)] {
        guard !cardIds.isEmpty else { return [] }
        var origin = calendar.startOfDay(for: anchor)
        let today = calendar.startOfDay(for: now)
        let batch = questionsPerAlert
        let dailyMaximum = min(requestedDailyCount, Int(ceil(20.0 / Double(batch))))
        let spacing = Double(minimumSpacingMinutes) * 60
        let endHour = window?.endHour ?? compatibilityWindow?.endHour
        let endMinute = window?.endMinute ?? compatibilityWindow?.endMinute ?? 0
        if let endHour, endHour * 60 + endMinute <= hour * 60 + minute {
            let anchorMinute = calendar.component(.hour, from: anchor) * 60 + calendar.component(.minute, from: anchor)
            if anchorMinute < endHour * 60 + endMinute {
                origin = calendar.date(byAdding: .day, value: -1, to: origin) ?? origin
            }
        }
        var result: [(date: Date, cardId: UUID)] = []
        for offset in -1...90 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  let dayOrdinal = calendar.dateComponents([.day], from: origin, to: day).day, dayOrdinal >= 0,
                  compatibilityWindow?.weekdays.contains(calendar.component(.weekday, from: day)) ?? true,
                  let start = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) else { continue }
            var end: Date? = nil
            if let endHour, var finish = calendar.date(bySettingHour: endHour, minute: endMinute, second: 0, of: day) {
                if finish <= start { finish = calendar.date(byAdding: .day, value: 1, to: finish) ?? finish }
                end = finish
            }
            let capacity = end.map { max(1, Int(ceil($0.timeIntervalSince(start) / spacing))) } ?? 1
            let count = min(dailyMaximum, capacity)
            let interval = end.map { max(spacing, $0.timeIntervalSince(start) / Double(count)) } ?? spacing
            for index in 0..<count {
                let rawDate = start.addingTimeInterval(Double(index) * interval)
                // Calendar notification triggers carry whole seconds; reservations
                // must use the same precision when a plan is replenished later.
                let date = Date(timeIntervalSince1970: rawDate.timeIntervalSince1970.rounded(.down))
                guard date > now.addingTimeInterval(1), date >= anchor,
                      end.map({ date < $0 }) ?? true,
                      expiresAt.map({ date < $0 }) ?? true else { continue }
                let ordinal = dayOrdinal * dailyMaximum * batch + index * batch
                result.append((date, cardIds[ordinal % cardIds.count]))
            }
            if result.count >= 60 { break }
        }
        return Array(result.sorted { $0.date < $1.date }.prefix(60))
    }

}

nonisolated struct DeckAlertWindow: Codable, Equatable {
    let endHour: Int
    let endMinute: Int
    let notificationLimit: Int
    let minimumSpacingMinutes: Int
    let questionsPerAlert: Int
}

nonisolated struct LegacyDeckScheduleWindow: Codable, Equatable {
    let identifierPrefix: String
    let weekdays: [Int]
    let endHour: Int
    let endMinute: Int
    let dailyCount: Int
}
