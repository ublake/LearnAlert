import Foundation
import SwiftData
import CryptoKit
import Testing
@testable import LearnAlert

@MainActor
@Suite("Published managed catalog")
struct ManagedCatalogTests {
    private struct Document<T: Encodable>: Encodable {
        let id: String
        let kind: String
        let revision: Int
        let document: T
    }
    private func item(_ id: String, kind: String = "course", revision: Int = 1) -> ManagedCatalogItem {
        .init(id: id, kind: kind, title: id, revision: revision, updatedAt: 0,
            contentURL: "https://api.learnalertapp.com/v1/catalog/\(id)?revision=\(revision)")
    }
    private func manifest(_ items: [ManagedCatalogItem], revision: String = "one", initialized: Bool = true) -> ManagedCatalogManifest {
        .init(schemaVersion: 1, revision: revision, initialized: initialized, items: items)
    }
    private func fixture() throws -> (URL, UserDefaults, String) {
        let id = "ManagedCatalogTests.\(UUID().uuidString)"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(id)
        return (url, try #require(UserDefaults(suiteName: id)), id)
    }
    private func data(_ course: CourseDefinition, revision: Int = 1) throws -> Data {
        try JSONEncoder().encode(Document(id: course.id, kind: "course", revision: revision, document: course))
    }

    @Test("Authoritative removals do not resurrect bundled courses and survive relaunch offline")
    func removals() throws {
        let (url, defaults, suite) = try fixture()
        defer { try? FileManager.default.removeItem(at: url); defaults.removePersistentDomain(forName: suite) }
        let store = ManagedCatalogStore(directory: url, defaults: defaults)
        #expect(store.courses.count == CourseCurriculumCatalog.bundledCourses.count)
        let course = CourseCurriculumCatalog.koreanCourse
        try store.install(manifest([item(course.id)]), documents: [course.id: data(course)])
        #expect(store.courses.map(\.id) == [course.id])
        try store.install(manifest([], revision: "two"), documents: [:])
        #expect(store.courses.isEmpty)
        #expect(store.examDecks.isEmpty)
        let offline = ManagedCatalogStore(directory: url, defaults: defaults)
        #expect(offline.courses.isEmpty)
        #expect(offline.revision == "two")
        // A corrupt cache after publication must not bring retired bundled content back.
        try Data("broken".utf8).write(to: url.appendingPathComponent("managed-catalog-v1.json"))
        #expect(ManagedCatalogStore(directory: url, defaults: defaults).courses.isEmpty)
    }

    @Test("Removed enrolled courses remain studyable without reappearing in Discover")
    func retainedEnrollment() throws {
        let (url, defaults, suite) = try fixture()
        defer { try? FileManager.default.removeItem(at: url); defaults.removePersistentDomain(forName: suite) }
        let course = CourseCurriculumCatalog.koreanCourse
        defaults.set([course.id], forKey: "course_enrolled_ids")
        defaults.set(Data("untouched-srs".utf8), forKey: "course_srs_records")
        let store = ManagedCatalogStore(directory: url, defaults: defaults)
        try store.install(manifest([], revision: "retired"), documents: [:])
        #expect(store.courses.isEmpty)
        #expect(store.course(for: course.id)?.units == course.units)
        #expect(defaults.data(forKey: "course_srs_records") == Data("untouched-srs".utf8))
        #expect(ManagedCatalogStore(directory: url, defaults: defaults).course(for: course.id)?.id == course.id)
        defaults.removeObject(forKey: "course_enrolled_ids")
        #expect(store.course(for: course.id) == nil)
    }

    @Test("Invalid revision batches preserve the entire last-good snapshot")
    func atomicValidation() throws {
        let (url, defaults, suite) = try fixture()
        defer { try? FileManager.default.removeItem(at: url); defaults.removePersistentDomain(forName: suite) }
        let store = ManagedCatalogStore(directory: url, defaults: defaults)
        let course = CourseCurriculumCatalog.spanishCourse
        try store.install(manifest([item(course.id)]), documents: [course.id: data(course)])
        #expect(throws: (any Error).self) {
            try store.install(manifest([item(course.id, revision: 2)], revision: "invalid"), documents: [course.id: data(course)])
        }
        #expect(store.revision == "one")
        #expect(store.courses.map(\.id) == [course.id])
        try store.install(manifest([], revision: "not-ready", initialized: false), documents: [:])
        #expect(store.revision == "one")
    }

    @Test("All guides, checkpoints, activities, and optional media survive Codable publication")
    func courseDocumentRoundTrip() throws {
        let source = CourseCurriculumCatalog.koreanCourse
        let unit = try #require(source.units.first)
        let guides = [unit.id: CourseSectionGuides.topics(course: source, unit: unit)]
        let course = CourseDefinition(id: source.id, title: source.title, language: source.language,
            flagEmoji: source.flagEmoji, levelTag: source.levelTag, colorHex: source.colorHex,
            summary: source.summary, estimatedHours: source.estimatedHours, outcomes: source.outcomes,
            units: source.units, guides: guides, guidePresentation: [unit.id: .init(showsHangulDiagram: false)])
        let decoded = try JSONDecoder().decode(CourseDefinition.self, from: JSONEncoder().encode(course))
        #expect(decoded == course)
        #expect(CourseSectionGuides.topics(course: decoded, unit: unit) == guides[unit.id])
        let card = CourseLessonCard(id: "media", question: "", options: ["", ""], correctAnswer: "",
            promptAudioName: "catalog:\(UUID().uuidString)", fieldMedia: ["option:0": .init(audio: "catalog:\(UUID().uuidString)")], correctOptionIndex: 1)
        #expect(try JSONDecoder().decode(CourseLessonCard.self, from: JSONEncoder().encode(card)) == card)
        #expect(card.resolvedCorrectOptionIndex == 1)
        #expect(card.hasChoiceMedia)
        #expect(ManagedCatalogMedia.url(reference: "catalog:../../private") == nil)
        #expect(ManagedCatalogMedia.url(reference: "catalog:\(UUID().uuidString)") != nil)
    }

    @Test("Minimal published cards use native defaults and exam identity survives title changes")
    func decoderDefaultsAndExamIdentity() throws {
        let raw = Data(#"{"id":"one","question":"Question","correctAnswer":"Yes","cardType":"multipleChoice","activity":{"kind":"teach","sequence":0}}"#.utf8)
        let courseCard = try JSONDecoder().decode(CourseLessonCard.self, from: raw)
        #expect(courseCard.options.isEmpty)
        #expect(courseCard.activity?.layout == .inline)
        #expect(courseCard.activity?.tokens.isEmpty == true)
        let examRaw = Data(#"{"id":"one","question":"Question","correctAnswer":"Yes","cardType":"multiple_choice"}"#.utf8)
        #expect(try JSONDecoder().decode(PremadeCard.self, from: examRaw).fieldMedia.isEmpty)
        let deck = Deck(name: "Original exam title", colorHex: "#123456", deckType: "Quiz")
        deck.sourcePremadeID = "stable-exam"
        let published = PremadeDeck(id: "stable-exam", name: "Renamed exam", category: "Exam Prep", subcategory: "New", description: "", colorHex: "#123456", deckType: "Quiz", cards: [])
        #expect(published.isInLibrary([deck]))
        let personal = Deck(name: published.name, colorHex: "#123456", deckType: "Quiz")
        #expect(!published.isInLibrary([personal]))
    }

    @Test("Independent courses can reuse card IDs without sharing mastery, reviews, or statistics")
    func independentCourseSRS() throws {
        func course(_ id: String) -> CourseDefinition {
            .init(id: id, title: id, language: "Test", flagEmoji: "🌱", levelTag: "", colorHex: "#123456", summary: "", estimatedHours: 1, outcomes: [], units: [
                .init(id: "unit", unitNumber: 1, title: "Unit", subtitle: "", colorHex: "#123456", badgeIcon: "book", lessons: [
                    .init(id: "lesson", lessonNumber: 1, title: "Lesson", subtitle: "", cards: [.init(id: "card-1", question: "Question", options: ["Yes", "No"], correctAnswer: "Yes")])
                ])
            ])
        }
        let first = course("one")
        let second = course("two")
        var state = CourseLearningSnapshot()
        for attempt in 0..<3 {
            let accepted = state.answer(course: first, lessonId: "lesson", cardId: "card-1", correct: true, token: "one-\(attempt)")
            #expect(accepted)
        }
        #expect(state.srsRecord(courseId: first.id, cardId: "card-1")?.masteryScore == 3)
        #expect(state.srsRecord(courseId: second.id, cardId: "card-1") == nil)
        #expect(state.batch(course: second, count: 1).first?.id == "card-1")
        #expect(!state.isFullyMastered(course: second))
        let secondAccepted = state.answer(course: second, lessonId: "lesson", cardId: "card-1", correct: false, token: "two-1")
        #expect(secondAccepted)
        #expect(state.srsRecord(courseId: first.id, cardId: "card-1")?.reviewCount == 3)
        #expect(state.srsRecord(courseId: second.id, cardId: "card-1")?.reviewCount == 1)
        let restored = try JSONDecoder().decode(CourseLearningSnapshot.self, from: JSONEncoder().encode(state))
        #expect(restored.courseSRS == state.courseSRS)
        let summary = StudyProgressSummary(decks: [], courses: [first, second], snapshot: restored)
        #expect(summary.cardCount == 2 && summary.reviewedCardCount == 2)
        #expect(summary.masteredCardCount == 1 && summary.reviewCount == 4)
    }

    @Test("Legacy native SRS migrates without lending its mastery to a new course")
    func legacySRSMigration() throws {
        let native = CourseCurriculumCatalog.koreanCourse
        let unit = try #require(native.units.first)
        let lesson = try #require(unit.lessons.first)
        let card = try #require(lesson.cards.first)
        let ai = CourseDefinition(id: "new-ai-course", title: "New", language: native.language, flagEmoji: native.flagEmoji,
            levelTag: native.levelTag, colorHex: native.colorHex, summary: "", estimatedHours: 1, outcomes: [], units: [unit])
        let record = CourseCardSRSRecord(cardId: card.id, masteryScore: 3, streak: 7, reviewCount: 7, correctCount: 7, nextReviewDate: .distantFuture)
        var legacy = CourseLearningSnapshot()
        legacy.srs[card.id] = record
        legacy.progress[native.id] = [lesson.id: .init(status: .current, correctAnswersCount: 7, totalAttemptsCount: 7, masteredCardIds: [card.id])]
        var raw = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(legacy)) as? [String: Any])
        raw.removeValue(forKey: "courseSRS")
        var migrated = try JSONDecoder().decode(CourseLearningSnapshot.self, from: JSONSerialization.data(withJSONObject: raw))
        #expect(migrated.courseSRS[native.id]?[card.id] == record)
        #expect(migrated.srs[card.id] == record)
        #expect(migrated.srsRecord(courseId: ai.id, cardId: card.id) == nil)
        #expect(migrated.progress[native.id]?[lesson.id]?.masteredCardIds == [card.id])
        let accepted = migrated.answer(course: ai, lessonId: lesson.id, cardId: card.id, correct: false, token: "new-course")
        #expect(accepted)
        #expect(migrated.srsRecord(courseId: native.id, cardId: card.id) == record)
        #expect(migrated.srsRecord(courseId: ai.id, cardId: card.id)?.reviewCount == 1)
    }

    @Test("AI media aliases decode in course and exam choices and encode native field keys")
    func mediaAliasCompatibility() throws {
        let image = "catalog:\(UUID().uuidString)"
        let audio = "catalog:\(UUID().uuidString)"
        let aliases: [String: Any] = ["imageID": image, "audioID": audio]
        let media = try JSONDecoder().decode(CardFieldMedia.self, from: JSONSerialization.data(withJSONObject: aliases))
        #expect(media.image == image && media.audio == audio)
        let encoded = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(media)) as? [String: String])
        #expect(encoded == ["image": image, "audio": audio])
        let preferred = try JSONDecoder().decode(CardFieldMedia.self, from: JSONSerialization.data(withJSONObject: ["image": "native", "imageID": image, "audio": "native-audio", "audioID": audio]))
        #expect(preferred.image == "native" && preferred.audio == "native-audio")
        var document: [String: Any] = ["id": "media", "question": "", "correctAnswer": "", "options": ["", ""], "correctOptionIndex": 0, "cardType": "multipleChoice", "fieldMedia": ["option:0": aliases]]
        let course = try JSONDecoder().decode(CourseLessonCard.self, from: JSONSerialization.data(withJSONObject: document))
        #expect(course.resolvedFieldMedia["option:0"] == media)
        document["cardType"] = "multiple_choice"
        let exam = try JSONDecoder().decode(PremadeCard.self, from: JSONSerialization.data(withJSONObject: document))
        #expect(exam.resolvedFieldMedia["option:0"] == media)
    }

    @Test("Automatic sync skips unchanged payloads while explicit repair and missing-deck recovery still run")
    func automaticSyncDoesNotRepeat() throws {
        let container = try ModelContainer(for: Deck.self, DeckSection.self, Flashcard.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let context = ModelContext(container)
        let id = "automatic-sync-\(UUID().uuidString)"
        let course = CourseDefinition(id: id, title: "Test", language: "Test", flagEmoji: "🌱", levelTag: "", colorHex: "#123456", summary: "", estimatedHours: 1, outcomes: [], units: [
            .init(id: "unit", unitNumber: 1, title: "Unit", subtitle: "", colorHex: "#123456", badgeIcon: "book", lessons: [
                .init(id: "lesson", lessonNumber: 1, title: "Lesson", subtitle: "", cards: [.init(id: "card", question: "Original", correctAnswer: "Yes", cardType: "vocabulary")])
            ])
        ])
        let manager = CourseProgressManager.shared
        #expect(manager.syncManagedCourseDeckIfNeeded(for: course, in: context))
        let deck = try #require(context.fetch(FetchDescriptor<Deck>()).first)
        let card = try #require(deck.cards.first)
        let firstDeckID = deck.id
        card.question = "Locally changed"
        card.reviewCount = 9
        try context.save()
        // The return value reports that the expensive migration was not entered.
        #expect(!manager.syncManagedCourseDeckIfNeeded(for: course, in: context))
        #expect(card.question == "Locally changed")
        let repaired = manager.createOrSyncCourseDeck(for: course, in: context)
        #expect(repaired.id == firstDeckID)
        #expect(card.question == "Original" && card.reviewCount == 9)
        #expect(manager.syncManagedCourseDeckIfNeeded(for: course, in: context))
        #expect(!manager.syncManagedCourseDeckIfNeeded(for: course, in: context))
        context.delete(deck)
        try context.save()
        #expect(manager.syncManagedCourseDeckIfNeeded(for: course, in: context))
        #expect(try context.fetch(FetchDescriptor<Deck>()).first?.id != firstDeckID)
    }

    @Test("Bulk sync preserves extras and inverse relationships when a card changes sections")
    func bulkRelationshipsPreserveHistory() throws {
        let container = try ModelContainer(for: Deck.self, DeckSection.self, Flashcard.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let context = ModelContext(container)
        let id = "bulk-sync-\(UUID().uuidString)"
        func course(updated: Bool) -> CourseDefinition {
            let a = CourseLessonCard(id: "a", question: "A", correctAnswer: "A", cardType: "vocabulary")
            let b = CourseLessonCard(id: "b", question: "B", correctAnswer: "B", cardType: "vocabulary")
            let c = CourseLessonCard(id: "c", question: "C", correctAnswer: "C", cardType: "vocabulary")
            func unit(_ name: String, number: Int, cards: [CourseLessonCard]) -> CourseUnit {
                .init(id: name, unitNumber: number, title: name, subtitle: "", colorHex: "#123456", badgeIcon: "book", lessons: [
                    .init(id: name + "-lesson", lessonNumber: 1, title: name, subtitle: "", cards: cards)
                ])
            }
            return .init(id: id, title: "Test", language: "Test", flagEmoji: "🌱", levelTag: "", colorHex: "#123456", summary: "", estimatedHours: 1, outcomes: [], units: [
                unit("one", number: 1, cards: updated ? [c] : [a]), unit("two", number: 2, cards: updated ? [a] : [b])
            ])
        }
        let manager = CourseProgressManager.shared
        let deck = manager.createOrSyncCourseDeck(for: course(updated: false), in: context)
        let originalIDs = Set(deck.cards.map(\.id))
        let a = try #require(deck.cards.first { $0.sourceCourseCardID == "a" })
        a.reviewCount = 7
        let firstSection = try #require(deck.sections.first { $0.sourceCourseUnitID == "one" })
        let extra = Flashcard(question: "Personal extra", correctAnswer: "Keep me")
        context.insert(extra)
        extra.deck = deck
        extra.section = firstSection
        extra.reviewCount = 12
        try context.save()
        let updated = manager.createOrSyncCourseDeck(for: course(updated: true), in: context)
        #expect(updated.cards.count == 4)
        #expect(originalIDs.isSubset(of: Set(updated.cards.map(\.id))))
        #expect(a.reviewCount == 7 && a.section?.sourceCourseUnitID == "two")
        #expect(extra.reviewCount == 12 && extra.section?.sourceCourseUnitID == "one")
        #expect(updated.cards.allSatisfy { $0.deck?.id == deck.id })
        #expect(updated.sections.flatMap(\.cards).count == updated.cards.count)
        let ids = Set(updated.cards.map(\.id))
        let repeated = manager.createOrSyncCourseDeck(for: course(updated: true), in: context)
        #expect(Set(repeated.cards.map(\.id)) == ids)
    }

    @Test("Course renames preserve personal card identity and review state")
    func stablePersonalCards() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Deck.self, DeckSection.self, Flashcard.self, configurations: configuration)
        let context = ModelContext(container)
        let id = "managed-test-\(UUID().uuidString)"
        func course(question: String, title: String) -> CourseDefinition {
            .init(id: id, title: question == "Old question" ? "Original course name" : "New course name", language: "Test", flagEmoji: "🌱", levelTag: "", colorHex: "#123456", summary: "", estimatedHours: 1, outcomes: [], units: [
                .init(id: "stable-unit", unitNumber: 1, title: title, subtitle: "", colorHex: "#123456", badgeIcon: "book", lessons: [
                    .init(id: "stable-lesson", lessonNumber: 1, title: "Lesson", subtitle: "", cards: [.init(id: "stable-card", question: question, options: ["Yes", "No"], correctAnswer: "Yes")])
                ])
            ])
        }
        let manager = CourseProgressManager.shared
        let original = manager.createOrSyncCourseDeck(for: course(question: "Old question", title: "Old unit"), in: context)
        let card = try #require(original.cards.first)
        card.reviewCount = 8
        card.correctCount = 6
        let originalID = card.id
        let updated = manager.createOrSyncCourseDeck(for: course(question: "New question", title: "New unit"), in: context)
        #expect(updated.id == original.id)
        #expect(updated.cards.count == 1)
        #expect(updated.cards.first?.id == originalID)
        #expect(updated.cards.first?.reviewCount == 8)
        #expect(updated.cards.first?.question == "New question")
        #expect(updated.sections.count == 1)
        #expect(updated.sections.first?.name == "New unit")
    }
    private func deliveryCourses() throws -> (CourseDefinition, CourseDefinition) {
        struct Component: Decodable { var unit: CourseUnit; var learning: CourseLearningGraph }
        let url = try #require(Bundle.main.url(forResource: "visual-starter-pilot", withExtension: "json")), component = try JSONDecoder().decode(Component.self, from: Data(contentsOf: url))
        let legacy = CourseUnit(id: "legacy", unitNumber: 1, title: "Legacy", subtitle: "", colorHex: "#123456", badgeIcon: "book", lessons: [.init(id: "old", lessonNumber: 1, title: "Old", subtitle: "", cards: [.init(id: "old-card", question: "Q", correctAnswer: "A", cardType: "vocabulary")])])
        func make(_ units: [CourseUnit], _ graph: CourseLearningGraph?) -> CourseDefinition { .init(id: "spanish-course", title: "Spanish (SP)", language: "Spanish", flagEmoji: "🇪🇸", levelTag: "Starter", colorHex: "#123456", summary: "", estimatedHours: 1, outcomes: [], units: units, learning: graph) }
        return (make([legacy], nil), make([legacy, component.unit], component.learning))
    }
    private func delivery(_ course: CourseDefinition, revision: Int = 11) throws -> (ManagedCatalogManifest, Data) {
        let payload = try JSONEncoder().encode(course), digest = SHA256.hash(data: payload).map { String(format: "%02x", $0) }.joined(), contracts = CourseDeliveryContracts.v1.sorted()
        let document = try JSONSerialization.data(withJSONObject: ["schemaVersion":2,"id":course.id,"kind":"course","revision":revision,"deliveryProfile":"practice-v1","requiredContracts":contracts,"contentDigest":digest,"payload":payload.base64EncodedString()])
        var record = ManagedCatalogItem(id: course.id, kind: "course", title: course.title, revision: revision, updatedAt: 0, contentURL: "https://api.learnalertapp.com/v1/catalog/" + course.id + "?profile=practice-v1&revision=" + String(revision)); record.deliveryProfile = "practice-v1"; record.requiredContracts = contracts; record.contentDigest = digest
        return (.init(schemaVersion: 2, revision: "practice:" + digest, initialized: true, items: [record], deliveryProfile: "practice-v1"), document)
    }
    @Test("Modern caches are isolated, digest checked, offline safe and never replaced by a legacy rollback")
    func profileCacheAndRollback() throws {
        let (url, defaults, suite) = try fixture(); defer { try? FileManager.default.removeItem(at: url); defaults.removePersistentDomain(forName: suite) }
        let (old, modern) = try deliveryCourses(), legacy = ManagedCatalogStore(directory: url, defaults: defaults)
        try legacy.install(manifest([item(old.id, revision: 9)]), documents: [old.id: data(old, revision: 9)])
        let legacyURL = url.appendingPathComponent("managed-catalog-v1.json"), legacyBytes = try Data(contentsOf: legacyURL)
        let blocked = ManagedCatalogStore(directory: url, defaults: defaults, profile: "practice-v1", replacementAllowed: { _, _ in false })
        #expect(blocked.courses.isEmpty && blocked.lastError != nil)
        let store = ManagedCatalogStore(directory: url, defaults: defaults, profile: "practice-v1")
        #expect(store.courses.first == old)
        let (release, bytes) = try delivery(modern)
        try store.install(release, documents: [modern.id: bytes])
        let unchangedLegacy = try Data(contentsOf: legacyURL)
        #expect(store.courses.first == modern && unchangedLegacy == legacyBytes)
        let offline = ManagedCatalogStore(directory: url, defaults: defaults, profile: "practice-v1")
        #expect(offline.courses.first == modern)
        #expect(ManagedCatalogStore(directory: url, defaults: defaults).courses.first == old)
        #expect(throws: (any Error).self) { try store.install(manifest([item(old.id, revision: 9)], revision: "older-server"), documents: [old.id: data(old, revision: 9)]) }
        var corrupt = try JSONSerialization.jsonObject(with: bytes) as! [String: Any]; corrupt["payload"] = Data("{}".utf8).base64EncodedString()
        #expect(throws: (any Error).self) { try store.install(release, documents: [modern.id: JSONSerialization.data(withJSONObject: corrupt)]) }
        var incompatible = release; var records = release.items; records[0].requiredContracts = ["unknown-contract"]
        incompatible = .init(schemaVersion: 2, revision: "incompatible", initialized: true, items: records, deliveryProfile: "practice-v1")
        #expect(throws: (any Error).self) { try store.install(incompatible, documents: [modern.id: bytes]) }
        #expect(throws: (any Error).self) { try legacy.install(release, documents: [modern.id: bytes]) }
        var changedJSON = try JSONSerialization.jsonObject(with: JSONEncoder().encode(modern)) as! [String: Any]
        var changedUnits = changedJSON["units"] as! [[String: Any]], changedUnit = changedUnits.removeLast(), changedLessons = changedUnit["lessons"] as! [[String: Any]], changedLesson = changedLessons[0], changedCards = changedLesson["cards"] as! [[String: Any]], extra = changedCards[0]
        extra["id"] = "test-new-variant-in-old-lesson"; changedCards.append(extra); changedLesson["cards"] = changedCards; changedLessons[0] = changedLesson; changedUnit["lessons"] = changedLessons; changedUnits.append(changedUnit); changedJSON["units"] = changedUnits
        let changedCourse = try JSONDecoder().decode(CourseDefinition.self, from: JSONSerialization.data(withJSONObject: changedJSON)), changedRelease = try delivery(changedCourse, revision: 12)
        #expect(throws: (any Error).self) { try store.install(changedRelease.0, documents: [modern.id: changedRelease.1]) }
        let futureManifest = ManagedCatalogManifest(schemaVersion: 3, revision: "future", initialized: true, items: release.items, deliveryProfile: "practice-v1")
        #expect(throws: (any Error).self) { try store.install(futureManifest, documents: [modern.id: bytes]) }
        #expect(store.courses.first == modern && store.revision == release.revision)
        #expect(ManagedCatalogStore(directory: url, defaults: defaults, profile: "practice-v1").courses.first == modern)
    }

    @Test("Modern refresh bootstraps old-client cache and retains last-good content after incompatible, missing-media and network responses")
    func deliveryRefreshFailureMatrix() async throws {
        let (url, defaults, suite) = try fixture(); defer { try? FileManager.default.removeItem(at: url); defaults.removePersistentDomain(forName: suite) }
        let (old, course) = try deliveryCourses(), (modernManifest, modernData) = try delivery(course)
        let oldManifest = manifest([item(old.id, revision: 9)]), oldData = try data(old, revision: 9)
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [DeliveryTestProtocol.self]
        let session = URLSession(configuration: config); defer { session.invalidateAndCancel(); DeliveryTestProtocol.response = nil }
        let legacyManifestData = try JSONEncoder().encode(oldManifest)
        let later = try delivery(course, revision: 12)
        var badRecords = later.0.items; badRecords[0].requiredContracts = ["unsupported"]
        let badData = try JSONEncoder().encode(ManagedCatalogManifest(schemaVersion: 2, revision: "bad-contract", initialized: true, items: badRecords, deliveryProfile: "practice-v1"))
        var mediaRecords = later.0.items; let missingID = "00000000-0000-4000-8000-000000009999"
        mediaRecords[0].assets = [.init(id: missingID, reference: "catalog:" + missingID, contentType: "image/png", url: "https://api.learnalertapp.com/v1/catalog/media/" + missingID)]
        let missingMediaData = try JSONEncoder().encode(ManagedCatalogManifest(schemaVersion: 2, revision: "missing-media", initialized: true, items: mediaRecords, deliveryProfile: "practice-v1"))
        let modernManifestData = try JSONEncoder().encode(modernManifest), laterManifestData = try JSONEncoder().encode(later.0)
        var phase = 0
        DeliveryTestProtocol.response = { request in
            let requestURL = request.url!, modern = URLComponents(url: requestURL, resolvingAgainstBaseURL: false)?.queryItems?.contains { $0.name == "profile" && $0.value == "practice-v1" } == true
            if phase == 5 { throw URLError(.notConnectedToInternet) }
            if phase == 6 { return (304, Data()) }
            if phase == 7 { return (200, Data("malformed manifest".utf8)) }
            if requestURL.path == "/v1/catalog" {
                if !modern { #expect(request.value(forHTTPHeaderField: "X-LearnAlert-Contracts") == nil); return (200, legacyManifestData) }
                #expect(Set((request.value(forHTTPHeaderField: "X-LearnAlert-Contracts") ?? "").split(separator: ",").map(String.init)) == CourseDeliveryContracts.supported)
                if phase == 3 { return (200, legacyManifestData) }
                if phase == 1 { return (200, badData) }
                if phase == 4 { return (200, missingMediaData) }
                return (200, phase == 0 ? modernManifestData : laterManifestData)
            }
            if requestURL.path.contains("/media/") || (modern && phase == 2) { return (404, Data("missing".utf8)) }
            if modern { return (200, phase == 0 ? modernData : later.1) }
            return (200, oldData)
        }
        let store = ManagedCatalogStore(directory: url, defaults: defaults, session: session, profile: "practice-v1")
        await store.refresh(force: true)
        #expect(store.lastError == nil && store.courses.first == course)
        #expect(ManagedCatalogStore(directory: url, defaults: defaults).courses.first == old)
        let cacheURL = url.appendingPathComponent("managed-catalog-v2-practice-v1.json"), saved = try Data(contentsOf: cacheURL)
        for failure in 1...7 {
            phase = failure; await store.refresh(force: true)
            #expect(store.lastError != nil && store.courses.first == course)
            #expect(try Data(contentsOf: cacheURL) == saved)
        }
        #expect(ManagedCatalogStore(directory: url, defaults: defaults, profile: "practice-v1").courses.first == course)
        #expect(!CourseDeliveryContracts.notificationCanRender(profile: "practice-v1", contracts: Array(CourseDeliveryContracts.supported), course: old))
        #expect(CourseDeliveryContracts.notificationCanRender(profile: "practice-v1", contracts: Array(CourseDeliveryContracts.supported), course: course))
        #expect(!CourseDeliveryContracts.notificationCanRender(profile: "future", contracts: [], course: course))
    }

}

private final class DeliveryTestProtocol: URLProtocol, @unchecked Sendable {
    static var response: ((URLRequest) throws -> (Int, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            guard let handler = Self.response else { throw URLError(.badServerResponse) }
            let (status, data) = try handler(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data); client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() { }
}
