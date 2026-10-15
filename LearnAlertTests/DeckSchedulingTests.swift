import Foundation
import SwiftData
import Testing
@testable import LearnAlert

@MainActor
@Suite("Deck schedules")
struct DeckSchedulingTests {
    @Test("Fresh defaults run until stopped; existing preferences migrate")
    func defaultsAndMigration() throws {
        let suite = "deck-schedule-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(DeckAlertSettings.defaults(in: defaults).stopCondition == "Until I say so")
        defaults.set("Until Day Ends", forKey: "stopCondition")
        defaults.set(5, forKey: "volumeSelectionIndex")
        defaults.set(1, forKey: "customVolume")
        defaults.set(9, forKey: "startHour")
        let migrated = DeckAlertSettings.defaults(in: defaults)
        #expect(migrated.stopCondition == "Until Day Ends" && migrated.dailyCount == 1 && migrated.startHour == 9)
    }

    @Test("Each deck persists its schedule and switching does not overwrite another deck or defaults")
    func deckIsolation() throws {
        let container = try ModelContainer(for: Deck.self, DeckSection.self, Flashcard.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let a = Deck(name: "Word a day"), b = Deck(name: "Exam")
        context.insert(a); context.insert(b)
        var daily = DeckAlertSettings(); daily.dailyCount = 1; daily.useSpecificTime = true
        var frequent = DeckAlertSettings(); frequent.dailyCount = 15
        a.alertSettings = daily; b.alertSettings = frequent
        try context.save()
        let engine = StudyEngine(restoreSavedSession: false)
        let original = engine.globalSettings
        engine.selectSettings(for: a)
        #expect(engine.activeVolume == 1 && engine.settings.dailyHour == 17)
        engine.startHour = 8
        engine.selectSettings(for: b)
        #expect(engine.activeVolume == 15 && engine.startHour == 10)
        engine.selectSettings(for: a)
        #expect(engine.startHour == 8)
        #expect(b.alertSettings == frequent && engine.globalSettings == original)
        let reloaded = try #require(ModelContext(container).fetch(FetchDescriptor<Deck>()).first { $0.id == a.id })
        #expect(reloaded.alertSettings?.startHour == 8)
        a.alertSettings = nil
        engine.selectSettings(for: a)
        #expect(engine.settings == original)
    }

    @Test("5 PM daily slots rotate cards, survive replenishment, and skip a passed time")
    func dailySlots() throws {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        func date(_ day: Int, _ hour: Int) -> Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour))! }
        let ids = [UUID(), UUID(), UUID()]
        let plan = DailyDeckAlertPlan(deckId: UUID(), sectionId: nil, cardIds: ids,
            anchor: date(15, 17), hour: 17, minute: 0, expiresAt: nil)
        let slots = plan.slots(now: date(15, 12), calendar: calendar)
        #expect(slots.count == 60 && Set(slots.map(\.date)).count == 60)
        #expect(slots.first?.date == date(15, 17))
        #expect(Array(slots.prefix(4)).map(\.cardId) == [ids[0], ids[1], ids[2], ids[0]])
        let later = plan.slots(now: date(15, 18), calendar: calendar)
        #expect(later.first?.date == date(16, 17) && later.first?.cardId == ids[1])
        #expect(later.allSatisfy { calendar.component(.hour, from: $0.date) == 17 })
        #expect(later.first?.cardId == slots[1].cardId)
        let endsToday = DailyDeckAlertPlan(deckId: UUID(), sectionId: nil, cardIds: ids,
            anchor: date(15, 17), hour: 17, minute: 0, expiresAt: date(16, 0))
        #expect(endsToday.slots(now: date(15, 12), calendar: calendar).count == 1)
        #expect(endsToday.slots(now: date(15, 18), calendar: calendar).isEmpty)
    }

    @Test("Daily alerts stay at 5 PM across daylight-saving changes")
    func daylightSaving() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/New_York"))
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 31, hour: 12)))
        let anchor = try #require(calendar.date(bySettingHour: 17, minute: 0, second: 0, of: now))
        let plan = DailyDeckAlertPlan(deckId: UUID(), sectionId: nil, cardIds: [UUID()], anchor: anchor,
            hour: 17, minute: 0, expiresAt: nil)
        let slots = plan.slots(now: now, calendar: calendar)
        #expect(slots.allSatisfy { calendar.component(.hour, from: $0.date) == 17 })
        #expect(slots[1].date.timeIntervalSince(slots[0].date) == 25 * 3600)
    }
}
