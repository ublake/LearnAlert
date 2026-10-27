import Foundation
import SwiftData

/// Read-only compatibility with saved study history. Retired journey files and
/// enrollment preferences are kept intact; only their card evidence is imported.
struct LegacyLanguageHistory: Decodable {
    var srs: [String: CourseCardSRSRecord] = [:]
    var progress: [String: [String: CourseLessonProgressRecord]] = [:]
    var courseSRS: [String: [String: CourseCardSRSRecord]] = [:]

    private enum CodingKeys: String, CodingKey { case srs, courseSRS, progress }
    init() {}
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        progress = try values.decodeIfPresent([String: [String: CourseLessonProgressRecord]].self, forKey: .progress) ?? [:]
        srs = try values.decodeIfPresent([String: CourseCardSRSRecord].self, forKey: .srs) ?? [:]
        courseSRS = try values.decodeIfPresent([String: [String: CourseCardSRSRecord]].self, forKey: .courseSRS) ?? [:]
    }

    func record(courseID: String, cardID: String) -> CourseCardSRSRecord? {
        if let record = courseSRS[courseID]?[cardID] { return record }
        if Self.legacyOwners[cardID] == courseID, let record = srs[cardID] { return record }
        if progress[courseID]?.values.contains(where: { $0.masteredCardIds.contains(cardID) }) == true {
            return .init(cardId: cardID, masteryScore: 3)
        }
        return nil
    }

    /// Unqualified pre-managed records belong only to their original author.
    /// Another catalog reusing the same card ID must not inherit that history.
    private static let legacyOwners: [String: String] = {
        var owners: [String: String] = [:]
        for course in CourseCurriculumCatalog.bundledCourses {
            for card in course.units.flatMap(\.lessons).flatMap(\.cards) where owners[card.id] == nil { owners[card.id] = course.id }
        }
        return owners
    }()

    static func load() throws -> Self {
        let manager = FileManager.default
        var directories: [URL] = []
        if let group = manager.containerURL(forSecurityApplicationGroupIdentifier: "group.com.learnalert.shared") { directories.append(group) }
        #if targetEnvironment(simulator)
        if let support = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            directories.append(support.appendingPathComponent("CourseLearning"))
        }
        #endif
        for directory in directories {
            for name in ["course-learning-v2.json", "course-learning-v1.json"] {
                let url = directory.appendingPathComponent(name)
                if manager.fileExists(atPath: url.path) { return try JSONDecoder().decode(Self.self, from: Data(contentsOf: url)) }
            }
        }
        var history = Self()
        if let data = UserDefaults(suiteName: "group.com.learnalert.shared")?.data(forKey: "course_srs_records") {
            history.srs = try JSONDecoder().decode([String: CourseCardSRSRecord].self, from: data)
        }
        return history
    }
}

@MainActor
enum LanguageDeckMigration {
    private static var defaults: UserDefaults? { UserDefaults(suiteName: "group.com.learnalert.shared") }

    /// Idempotent, additive conversion. No cards, relationships, files, or
    /// notification requests are deleted, and unrelated schedules are untouched.
    @discardableResult
    static func run(in context: ModelContext) throws -> String? {
        let history: LegacyLanguageHistory
        let warning: String?
        do { history = try LegacyLanguageHistory.load(); warning = nil }
        catch {
            history = .init()
            warning = "Your saved decks are available. Older language study history could not be read, so its original files have been kept for recovery. No cards or history files were deleted."
        }
        var decks = try context.fetch(FetchDescriptor<Deck>())
        let storedCollections = UserDefaults.standard.string(forKey: "languageCollections") ?? ""
        let enrolled = defaults?.stringArray(forKey: "course_enrolled_ids") ?? []
        let savedIDs = Set(storedCollections.split(separator: "|").map(String.init) + enrolled)
        for id in savedIDs {
            guard !decks.contains(where: { $0.sourceId == id || $0.sourcePremadeID == "course:\(id)" || $0.sourcePremadeID == "language:\(id):all" }),
                  let course = CourseCurriculumCatalog.course(for: id) else { continue }
            let topics = LanguageDeckProjection.topics(course)
            guard !topics.isEmpty else { continue }
            let deck = try LanguageTopicStore.open(course: course,
                topic: .init(id: "all", title: course.language, cards: topics.flatMap(\.cards)), context: context)
            decks.append(deck)
        }
        for deck in decks {
            let legacy = deck.deckType == "Course" || ["languageTopic", "managedLanguage"].contains(deck.sourceKind ?? "") || deck.sourcePremadeID?.hasPrefix("course:") == true
            guard legacy else { continue }
            let courseID = deck.sourceId ?? deck.sourcePremadeID.flatMap { $0.hasPrefix("course:") ? String($0.dropFirst(7)) : nil }
                ?? enrollmentCourseID(linkedTo: deck.id)
            deck.deckType = "Quiz"
            deck.sourceKind = "managedLanguage"
            if let courseID { deck.sourceId = courseID }
            if warning == nil, deck.legacyLanguageHistoryImported != true {
              for card in deck.cards {
                guard let courseID, let cardID = card.sourceCourseCardID,
                      let record = history.record(courseID: courseID, cardID: cardID), (record.reviewCount > card.reviewCount || card.reviewCount == 0 && record.masteryScore > card.masteryScore) else { continue }
                card.reviewCount = record.reviewCount
                card.correctCount = record.correctCount
                card.masteryScore = record.masteryScore
                card.streak = record.streak
                card.longestStreak = max(card.longestStreak, record.streak)
                card.lastReviewedDate = record.lastReviewedDate
              }
              deck.legacyLanguageHistoryImported = true
            }
        }
        try context.save()
        // Saved course identities become the ordinary deck identity, preserving
        // explicit pins and ordering. Raw enrollment/history records stay intact.
        for id in savedIDs {
            if let deck = decks.first(where: { $0.sourcePremadeID == "language:\(id):all" })
                ?? decks.first(where: { $0.id.uuidString == enrollmentLinkedDeckID(courseID: id) })
                ?? decks.first(where: { $0.sourceId == id }) {
                LibraryPreferences.shared.migrateCourseIdentity(courseID: id, to: deck.id)
                if UserDefaults.standard.string(forKey: "targetDeckId") == "course:\(id)" {
                    UserDefaults.standard.set(deck.id.uuidString, forKey: "targetDeckId")
                }
            }
        }
        try migrateAlertPlan(in: context)
        return warning
    }

    private static func enrollmentLinkedDeckID(courseID: String) -> String? {
        guard let data = defaults?.data(forKey: "course_enrollment_\(courseID)"),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return object["linkedDeckId"] as? String
    }
    private static func enrollmentCourseID(linkedTo id: UUID) -> String? {
        (defaults?.stringArray(forKey: "course_enrolled_ids") ?? []).first { enrollmentLinkedDeckID(courseID: $0) == id.uuidString }
    }

    private struct OldAlertPlan: Decodable {
        let courseId: String
        let deckId: String
        let startHour: Int
        let startMinute: Int
        let endHour: Int
        let endMinute: Int
        let weekdays: [Int]
        let dailyCount: Int
        var expiresAt: Date?
        var stopWhenMastered: Bool?
        var sound: String?
    }
    private static func migrateAlertPlan(in context: ModelContext) throws {
        guard let data = defaults?.data(forKey: "course_alert_plan"),
              defaults?.data(forKey: "dailyDeckAlertPlan") == nil else { return }
        let old = try JSONDecoder().decode(OldAlertPlan.self, from: data)
        guard let id = UUID(uuidString: old.deckId),
              let deck = try context.fetch(FetchDescriptor<Deck>(predicate: #Predicate { $0.id == id })).first,
              !deck.cards.isEmpty else { return }
        var plan = DailyDeckAlertPlan(deckId: id, sectionId: nil, cardIds: deck.cards.map(\.id), anchor: Date(),
            hour: old.startHour, minute: old.startMinute, expiresAt: old.expiresAt,
            stopWhenMastered: old.stopWhenMastered ?? false, sound: old.sound ?? "Default")
        plan.compatibilityWindow = .init(identifierPrefix: "course-\(old.courseId)", weekdays: old.weekdays,
            endHour: old.endHour, endMinute: old.endMinute, dailyCount: old.dailyCount)
        defaults?.set(try JSONEncoder().encode(plan), forKey: "dailyDeckAlertPlan")
        defaults?.set(data, forKey: "retiredCourseAlertPlanBackup")
        defaults?.removeObject(forKey: "course_alert_plan")
        defaults?.synchronize()
    }

    /// Handles already delivered alerts that predate card IDs in the payload.
    /// It reads the preserved local deck, without creating a course or a route.
    static func legacyCard(deckID: String?, courseID: String?, in context: ModelContext) -> Flashcard? {
        let decks = (try? context.fetch(FetchDescriptor<Deck>())) ?? []
        let deck = decks.first {
            $0.id.uuidString == deckID && (courseID == nil || $0.sourceId == courseID ||
                $0.sourcePremadeID == courseID.map { "course:\($0)" } || $0.deckType == "Course")
        }
            ?? decks.first { $0.sourceId == courseID && $0.sourcePremadeID?.hasSuffix(":all") == true }
            ?? decks.first { $0.sourcePremadeID == courseID.map { "course:\($0)" } }
        return deck?.cards.sorted { $0.studyPriority > $1.studyPriority }.first
    }
}
