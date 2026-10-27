import Foundation

nonisolated enum AlertPaceMode: String, Codable, CaseIterable, Identifiable {
    case automatic, custom
    var id: Self { self }
    var title: String { self == .automatic ? "Automatic" : "Custom" }
}

/// Personal scheduling preferences; community exports do not include these settings.
nonisolated struct DeckAlertSettings: Codable, Equatable {
    var paceMode = AlertPaceMode.automatic
    var dailyCount = 10
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
        result.paceMode = savedIndex == nil ? .automatic : .custom
        let index = savedIndex ?? 3
        result.dailyCount = index == 5 ? min(50, max(1, defaults.object(forKey: "customVolume") as? Int ?? 20)) : options[min(4, max(0, index))]
        result.startHour = defaults.object(forKey: "startHour") as? Int ?? 10
        result.startMinute = defaults.object(forKey: "startMinute") as? Int ?? 0
        result.endHour = defaults.object(forKey: "endHour") as? Int ?? 19
        result.endMinute = defaults.object(forKey: "endMinute") as? Int ?? 0
        result.stopCondition = defaults.string(forKey: "stopCondition") ?? "Until I say so"
        result.smartSRS = defaults.object(forKey: "smartSRS") as? Bool ?? true
        return result
    }

    var isCustomDaily: Bool { paceMode == .custom && dailyCount == 1 }
    var dailyHour: Int { isCustomDaily && useSpecificTime ? specificHour : startHour }
    var dailyMinute: Int { isCustomDaily && useSpecificTime ? specificMinute : startMinute }

    func resolvedDailyCount(automaticCount: Int) -> Int {
        min(50, max(1, paceMode == .automatic ? automaticCount : dailyCount))
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
        paceMode = try values.decodeIfPresent(AlertPaceMode.self, forKey: .paceMode) ?? .custom
        dailyCount = try values.decodeIfPresent(Int.self, forKey: .dailyCount) ?? 10
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
    /// Compatibility for saved recurring language alerts, now ordinary decks.
    /// New deck schedules continue using the existing daily time behavior.
    var compatibilityWindow: LegacyDeckScheduleWindow? = nil

    var identifierPrefix: String { compatibilityWindow?.identifierPrefix ?? "daily-deck-\(id)" }

    /// Calendar days keep the selected local time across daylight-saving changes.
    func slots(now: Date = Date(), calendar: Calendar = .current) -> [(date: Date, cardId: UUID)] {
        guard !cardIds.isEmpty else { return [] }
        if let window = compatibilityWindow {
            var result: [(Date, UUID)] = []
            for offset in -1...7 {
                guard let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now)),
                      window.weekdays.contains(calendar.component(.weekday, from: day)),
                      let start = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day),
                      var end = calendar.date(bySettingHour: window.endHour, minute: window.endMinute, second: 0, of: day) else { continue }
                if end <= start { end = calendar.date(byAdding: .day, value: 1, to: end) ?? end }
                let count = min(50, max(1, window.dailyCount))
                let dayOrdinal = calendar.dateComponents([.day], from: calendar.startOfDay(for: anchor), to: day).day ?? 0
                for index in 0..<count {
                    let date = start.addingTimeInterval(end.timeIntervalSince(start) * Double(index) / Double(count))
                    if date > now.addingTimeInterval(1), expiresAt.map({ date < $0 }) ?? true {
                        let ordinal = dayOrdinal * count + index
                        let cardIndex = (ordinal % cardIds.count + cardIds.count) % cardIds.count
                        result.append((date, cardIds[cardIndex]))
                    }
                }
            }
            return Array(result.sorted { $0.0 < $1.0 }.prefix(60))
        }
        let origin = calendar.startOfDay(for: anchor)
        let today = calendar.startOfDay(for: now)
        var result: [(Date, UUID)] = []
        for offset in 0...60 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  let ordinal = calendar.dateComponents([.day], from: origin, to: day).day, ordinal >= 0,
                  let date = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day),
                  date > now.addingTimeInterval(1), expiresAt.map({ date < $0 }) ?? true else { continue }
            result.append((date, cardIds[ordinal % cardIds.count]))
        }
        return Array(result.prefix(60))
    }
}

nonisolated struct LegacyDeckScheduleWindow: Codable, Equatable {
    let identifierPrefix: String
    let weekdays: [Int]
    let endHour: Int
    let endMinute: Int
    let dailyCount: Int
}
