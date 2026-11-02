import Foundation
import Testing
@testable import LearnAlert

@MainActor
@Suite("Interface localizations", .serialized)
struct LocalizationTests {
    @Test("All six compiled language bundles include app and notification controls",
          arguments: ["es", "pt-BR", "fr", "de", "ja", "ko"])
    func bundledTranslations(language: String) throws {
        let path = try #require(Bundle.main.path(forResource: language, ofType: "lproj"))
        let bundle = try #require(Bundle(path: path))
        for key in ["Settings", "Your library", "Cancel", "Listen", "Again", "Continue in App", "Questions per alert"] {
            let translated = bundle.localizedString(forKey: key, value: nil, table: "Localizable")
            #expect(!translated.isEmpty)
            #expect(translated != key, "Missing \(language) translation for \(key)")
        }
    }

    @Test("Count summaries select independent singular and plural forms")
    func pluralSummaries() throws {
        let path = try #require(Bundle.main.path(forResource: "en", ofType: "lproj"))
        let bundle = try #require(Bundle(path: path))
        let key = "Up to %lld alerts · %lld min apart · %lld questions each"
        let template = bundle.localizedString(forKey: key, value: nil, table: "Localizable")
        #expect(String.localizedStringWithFormat(template, Int64(1), Int64(60), Int64(1)) == "Up to 1 alert · 60 min apart · 1 question each")
        #expect(String.localizedStringWithFormat(template, Int64(7), Int64(60), Int64(3)) == "Up to 7 alerts · 60 min apart · 3 questions each")
    }

    @Test("Localized presentation does not change stored kinds or schedule values")
    func stableStoredValues() throws {
        #expect(FlashcardType.multipleChoice.rawValue == "multiple_choice")
        #expect(FlashcardType.dragAnswer.rawValue == "drag_answer")
        #expect(AnkiStudyPresentation.tapToFlip.rawValue == "tapToFlip")
        for stop in ["Until I say so", "Until Day Ends", "Until Deck Learnt"] {
            var settings = DeckAlertSettings()
            settings.stopCondition = stop
            settings.dailyCount = 17
            let data = try JSONEncoder().encode(settings)
            #expect(try JSONDecoder().decode(DeckAlertSettings.self, from: data) == settings)
        }
        let deck = Deck(name: "한국어 :: My cards", deckType: "Quiz")
        let card = Flashcard(question: "la manzana", deck: deck)
        #expect(deck.name == "한국어 :: My cards")
        #expect(deck.deckType == "Quiz")
        #expect(card.question == "la manzana")
    }
}
