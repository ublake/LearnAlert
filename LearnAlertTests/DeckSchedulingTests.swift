import Foundation
import SwiftData
import Testing
@testable import LearnAlert

@MainActor
@Suite("Deck schedules", .serialized)
struct DeckSchedulingTests {
    @Test("An explicit save applies the edited deck preferences before rescheduling and leaves defaults alone")
    func saveAndReschedule() async throws {
        let container = try ModelContainer(for: Deck.self, DeckSection.self, Flashcard.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let context = ModelContext(container)
        let deck = Deck(name: "Edited schedule")
        context.insert(deck)
        try context.save()
        let engine = StudyEngine(restoreSavedSession: false)
        let defaults = engine.globalSettings
        let previousSound = UserDefaults.standard.object(forKey: "alertSound")
        defer {
            if let previousSound { UserDefaults.standard.set(previousSound, forKey: "alertSound") }
            else { UserDefaults.standard.removeObject(forKey: "alertSound") }
        }
        var edit = AlertScheduleEdit(targetId: deck.id.uuidString, settings: defaults, sound: "Default")
        edit.settings.paceMode = .custom
        edit.settings.dailyCount = 1
        edit.settings.useSpecificTime = true
        edit.settings.specificHour = 17
        // Editing a draft must not mutate the engine, persisted deck, or sound.
        #expect(deck.alertSettings == nil && engine.globalSettings == defaults)
        #expect(UserDefaults.standard.object(forKey: "alertSound") as? String == previousSound as? String)
        var scheduled = false
        try await engine.saveAlertSettings(edit.settings, sound: edit.sound, for: deck) {
            #expect(engine.settings == edit.settings && engine.activeVolume == 1)
            #expect(engine.settings.dailyHour == 17)
            #expect(UserDefaults.standard.string(forKey: "alertSound") == "Default")
            scheduled = true
        }
        #expect(scheduled && engine.globalSettings == defaults)
        let reloaded = try #require(ModelContext(container).fetch(FetchDescriptor<Deck>()).first)
        #expect(reloaded.alertSettings == edit.settings)
    }

    @Test("A failed reschedule restores the prior preferences, deck inheritance, selection, and sound")
    func failedReschedule() async throws {
        enum Failure: Error { case scheduling }
        let engine = StudyEngine(restoreSavedSession: false)
        let deck = Deck(name: "Inherited schedule")
        let other = Deck(name: "Other selection")
        engine.selectSettings(for: other)
        let defaults = engine.globalSettings
        let previousSound = UserDefaults.standard.object(forKey: "alertSound") as? String
        var edited = defaults
        edited.paceMode = .custom
        edited.dailyCount = 3
        do {
            try await engine.saveAlertSettings(edited, sound: "alert1.wav", for: deck) { throw Failure.scheduling }
            Issue.record("The failed scheduling operation should throw")
        } catch Failure.scheduling {}
        #expect(deck.alertSettings == nil)
        #expect(engine.globalSettings == defaults && engine.settingsDeck?.id == other.id)
        #expect(UserDefaults.standard.string(forKey: "alertSound") == previousSound)
    }

    @Test("Fresh defaults run until stopped; existing preferences migrate")
    func defaultsAndMigration() throws {
        let suite = "deck-schedule-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(DeckAlertSettings.defaults(in: defaults).stopCondition == "Until I say so")
        #expect(DeckAlertSettings.defaults(in: defaults).paceMode == .automatic)
        defaults.set("Until Day Ends", forKey: "stopCondition")
        defaults.set(5, forKey: "volumeSelectionIndex")
        defaults.set(1, forKey: "customVolume")
        defaults.set(9, forKey: "startHour")
        let migrated = DeckAlertSettings.defaults(in: defaults)
        #expect(migrated.stopCondition == "Until Day Ends" && migrated.dailyCount == 1 && migrated.startHour == 9 && migrated.paceMode == .custom)
    }

    @Test("Custom mode stays selected when its number matches a preset and survives relaunch")
    func customPaceIsExplicit() throws {
        var settings = DeckAlertSettings()
        settings.paceMode = .custom
        for count in [20, 10, 5, 1, 15, 7] {
            settings.dailyCount = count
            let saved = try JSONDecoder().decode(DeckAlertSettings.self, from: JSONEncoder().encode(settings))
            #expect(saved.paceMode == .custom)
            #expect(saved.resolvedDailyCount(automaticCount: 3) == count)
        }
        settings.dailyCount = 1
        settings.useSpecificTime = true
        #expect(settings.isCustomDaily && settings.dailyHour == 17)
        settings.paceMode = .automatic
        #expect(!settings.isCustomDaily && settings.dailyHour == 10)
        #expect(settings.resolvedDailyCount(automaticCount: 5) == 5)
        settings.paceMode = .custom
        #expect(settings.isCustomDaily && settings.dailyCount == 1 && settings.dailyHour == 17)
    }

    @Test("Old saved numeric schedules retain their exact pace and daily time")
    func legacyNumericPace() throws {
        let data = Data(#"{"dailyCount":1,"startHour":9,"useSpecificTime":true,"specificHour":17}"#.utf8)
        let settings = try JSONDecoder().decode(DeckAlertSettings.self, from: data)
        #expect(settings.paceMode == .custom && settings.resolvedDailyCount(automaticCount: 10) == 1)
        #expect(settings.dailyHour == 17)
    }

    @Test("Automatic uses the course target or a manageable deck batch, bounded to the alert budget")
    func automaticPace() throws {
        #expect(DeckAlertSettings.automaticDailyCount(cardCount: 4) == 4)
        #expect(DeckAlertSettings.automaticDailyCount(cardCount: 100) == 10)
        #expect(DeckAlertSettings.automaticDailyCount(cardCount: nil) == 10)
        #expect(DeckAlertSettings.automaticDailyCount(cardCount: 100, courseTarget: 7) == 7)
        #expect(DeckAlertSettings.automaticDailyCount(cardCount: 100, courseTarget: 100) == 50)
        var settings = DeckAlertSettings()
        #expect(settings.resolvedDailyCount(automaticCount: 7) == 7)
        settings.dailyCount = 20
        #expect(settings.resolvedDailyCount(automaticCount: 7) == 7)
        let engine = StudyEngine(restoreSavedSession: false)
        let deck = Deck(name: "Automatic")
        let cards = (0..<4).map { Flashcard(question: "Q\($0)", options: ["A"], correctAnswer: "A") }
        deck.cards = cards
        deck.alertSettings = settings
        engine.selectSettings(for: deck)
        #expect(engine.activeVolume == 4)
        engine.settings.paceMode = .custom
        engine.settings.dailyCount = 10
        #expect(engine.activeVolume == 10 && engine.settings.paceMode == .custom)
    }

    @Test("Each deck persists its schedule and switching does not overwrite another deck or defaults")
    func deckIsolation() throws {
        let container = try ModelContainer(for: Deck.self, DeckSection.self, Flashcard.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let context = ModelContext(container)
        let a = Deck(name: "Word a day"), b = Deck(name: "Exam")
        context.insert(a); context.insert(b)
        var daily = DeckAlertSettings(); daily.paceMode = .custom; daily.dailyCount = 1; daily.useSpecificTime = true
        var frequent = DeckAlertSettings(); frequent.paceMode = .custom; frequent.dailyCount = 15
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
