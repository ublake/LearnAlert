import Foundation

/// Personal scheduling preferences; community exports do not include these settings.
nonisolated struct DeckAlertSettings: Codable, Equatable {
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

    static func defaults(in defaults: UserDefaults = .standard) -> Self {
        if let data = defaults.data(forKey: "defaultDeckAlertSettings"),
           let saved = try? JSONDecoder().decode(Self.self, from: data) { return saved }
        var result = Self()
        let options = [3, 5, 7, 10, 15]
        let index = defaults.object(forKey: "volumeSelectionIndex") as? Int ?? 3
        result.dailyCount = index == 5 ? min(50, max(1, defaults.object(forKey: "customVolume") as? Int ?? 20)) : options[min(4, max(0, index))]
        result.startHour = defaults.object(forKey: "startHour") as? Int ?? 10
        result.startMinute = defaults.object(forKey: "startMinute") as? Int ?? 0
        result.endHour = defaults.object(forKey: "endHour") as? Int ?? 19
        result.endMinute = defaults.object(forKey: "endMinute") as? Int ?? 0
        result.stopCondition = defaults.string(forKey: "stopCondition") ?? "Until I say so"
        result.smartSRS = defaults.object(forKey: "smartSRS") as? Bool ?? true
        return result
    }

    var dailyHour: Int { useSpecificTime ? specificHour : startHour }
    var dailyMinute: Int { useSpecificTime ? specificMinute : startMinute }
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

    /// Calendar days keep the selected local time across daylight-saving changes.
    func slots(now: Date = Date(), calendar: Calendar = .current) -> [(date: Date, cardId: UUID)] {
        guard !cardIds.isEmpty else { return [] }
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
