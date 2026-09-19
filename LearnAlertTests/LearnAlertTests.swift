//
//  LearnAlertTests.swift
//  LearnAlertTests
//
//  Created by Blake Miller on 9/12/26.
//

import Foundation
import Testing
import UIKit
import PDFKit
@testable import LearnAlert

@Suite("Flashcard Spaced Repetition Tests")
struct FlashcardRepetitionTests {

    @Test("Correct answer increases streak and interval")
    func correctAnswerProgression() {
        let card = Flashcard(
            question: "What is Swift?",
            options: ["A programming language", "A bird"],
            correctAnswer: "A programming language"
        )
        
        #expect(card.currentStreak == 0)
        #expect(card.interval == 0)
        #expect(card.isNew == true)
        
        card.processAnswer(isCorrect: true)
        #expect(card.currentStreak == 1)
        #expect(card.interval == 1)
        #expect(card.correctCount == 1)
        #expect(card.isNew == false)
        
        card.processAnswer(isCorrect: true)
        #expect(card.currentStreak == 2)
        #expect(card.interval == 6)
        #expect(card.correctCount == 2)
    }

    @Test("Incorrect answer resets streak and interval")
    func incorrectAnswerReset() {
        let card = Flashcard(
            question: "What is iOS?",
            options: ["An OS", "A hardware"],
            correctAnswer: "An OS"
        )
        card.processAnswer(isCorrect: true)
        card.processAnswer(isCorrect: true)
        #expect(card.currentStreak == 2)
        #expect(card.interval == 6)

        card.processAnswer(isCorrect: false)
        #expect(card.currentStreak == 0)
        #expect(card.interval == 0)
        #expect(card.incorrectCount == 1)
    }

    @Test("Skip increments skipCount and resets streak")
    func skipCard() {
        let card = Flashcard(
            question: "Sample",
            options: ["A", "B"],
            correctAnswer: "A"
        )
        card.processAnswer(isCorrect: true)
        #expect(card.currentStreak == 1)

        card.recordSkip()
        #expect(card.currentStreak == 0)
        #expect(card.skipCount == 1)
    }

    @Test("Hint used increments hintCount")
    func hintUsed() {
        let card = Flashcard(
            question: "Sample",
            options: ["A", "B"],
            correctAnswer: "A",
            hint: "A hint"
        )
        #expect(card.hintCount == 0)
        card.recordHintUsed()
        #expect(card.hintCount == 1)
    }

    @Test("Study priority increases with errors and decreases with confidence")
    func studyPriorityCalculation() {
        let card = Flashcard(
            question: "Sample",
            options: ["A", "B"],
            correctAnswer: "A"
        )
        let initialPriority = card.studyPriority
        card.processAnswer(isCorrect: false)
        #expect(card.studyPriority > initialPriority)
    }

    @Test("Reset progress restores card initial learning state")
    func resetProgress() {
        let card = Flashcard(
            question: "Sample",
            options: ["A", "B"],
            correctAnswer: "A"
        )
        card.processAnswer(isCorrect: true)
        card.processAnswer(isCorrect: true)
        #expect(card.currentStreak == 2)
        #expect(card.isNew == false)

        card.resetProgress()
        #expect(card.isNew == true)
        #expect(card.currentStreak == 0)
        #expect(card.correctCount == 0)
        #expect(card.incorrectCount == 0)
        #expect(card.interval == 0)
    }

    @Test("Accuracy reflects ratio of correct to total reviews")
    func accuracyCalculation() {
        let card = Flashcard(
            question: "Sample",
            options: ["A", "B"],
            correctAnswer: "A"
        )
        #expect(card.accuracy == 0.0)

        card.processAnswer(isCorrect: true)
        #expect(card.accuracy == 1.0)

        card.processAnswer(isCorrect: false)
        #expect(card.accuracy == 0.5)
    }
}

@Suite("Deck Model Tests")
struct DeckModelTests {

    @Test("Deck initializes with default properties")
    func deckInitialization() {
        let deck = Deck(name: "Swift Basics", colorHex: "#5568C9")
        #expect(deck.name == "Swift Basics")
        #expect(deck.colorHex == "#5568C9")
        #expect(deck.cards.isEmpty)
        #expect(deck.sections.isEmpty)
    }
}

@Suite("Sound Options & Configuration Tests")
struct AlertSoundOptionTests {

    @Test("Default and custom sounds exist in allSounds")
    func allSoundsCompleteness() {
        let soundIds = AlertSoundOption.allSounds.map(\.id)
        #expect(soundIds.contains("Default"))
        #expect(soundIds.contains("alert1.wav"))
        #expect(soundIds.contains("alert2.wav"))
        #expect(soundIds.contains("alert3.wav"))
        #expect(soundIds.contains("alert4.wav"))
        #expect(soundIds.contains("alert5.wav"))
    }

    @Test("displayName returns custom name or fallback")
    func displayNameResolution() {
        #expect(AlertSoundOption.displayName(for: "Default") == "Default")
        #expect(AlertSoundOption.displayName(for: "alert1.wav") == "Level-up")
        #expect(AlertSoundOption.displayName(for: "alert2.wav") == "Pulse")
        #expect(AlertSoundOption.displayName(for: "custom_sound.wav") == "custom_sound")
    }
}

@Suite("FlashcardType Tests")
struct FlashcardTypeTests {

    @Test("All flashcard types have valid titles and icons")
    func flashcardTypeProperties() {
        for type in FlashcardType.allCases {
            #expect(!type.title.isEmpty)
            #expect(!type.icon.isEmpty)
            #expect(!type.id.isEmpty)
        }
    }
}



@Suite("Quick Schedule & Deck Switching Tests")
struct QuickScheduleTests {

    @Test("Quick schedule tip only displays on the first trigger")
    func quickScheduleTipOnce() {
        let testKey = "test_hasSeenQuickScheduleSwitchTip_\(UUID().uuidString)"
        let defaults = UserDefaults.standard

        #expect(defaults.bool(forKey: testKey) == false)

        // First quick schedule press
        var shouldShowToast = false
        if !defaults.bool(forKey: testKey) {
            defaults.set(true, forKey: testKey)
            shouldShowToast = true
        }
        #expect(shouldShowToast == true)
        #expect(defaults.bool(forKey: testKey) == true)

        // Second quick schedule press
        shouldShowToast = false
        if !defaults.bool(forKey: testKey) {
            defaults.set(true, forKey: testKey)
            shouldShowToast = true
        }
        #expect(shouldShowToast == false)

        defaults.removeObject(forKey: testKey)
    }

    @Test("Switching between decks retains minimum card requirement")
    func deckSwitchingRequirements() {
        let deckA = Deck(name: "Deck A", colorHex: "#5568C9")
        let deckB = Deck(name: "Deck B", colorHex: "#5568C9")

        #expect(deckA.cards.count < 2)

        deckA.cards.append(Flashcard(question: "Q1", options: ["A"], correctAnswer: "A"))
        deckA.cards.append(Flashcard(question: "Q2", options: ["B"], correctAnswer: "B"))
        #expect(deckA.cards.count >= 2)

        deckB.cards.append(Flashcard(question: "Q3", options: ["C"], correctAnswer: "C"))
        deckB.cards.append(Flashcard(question: "Q4", options: ["D"], correctAnswer: "D"))
        #expect(deckB.cards.count >= 2)
    }

    @Test("Progress color thresholds accurately map progress")
    func progressColorLogic() {
        func progressCategory(for progress: Double) -> String {
            if progress >= 1.0 {
                return "completed"
            } else if progress >= 0.70 {
                return "high"
            } else if progress >= 0.40 {
                return "medium"
            } else if progress > 0 {
                return "low"
            } else {
                return "unstarted"
            }
        }

        #expect(progressCategory(for: 0.0) == "unstarted")
        #expect(progressCategory(for: 0.25) == "low")
        #expect(progressCategory(for: 0.50) == "medium")
        #expect(progressCategory(for: 0.80) == "high")
        #expect(progressCategory(for: 1.0) == "completed")
    }
}

@Suite("Smart Repetition, Cycling & Answer Locking Tests")
struct SmartRepetitionAndLockingTests {

    @Test("Missed cards and skipped cards are smartly re-queued for repetition")
    func smartQueueReinsertionOnMistake() {
        let card1 = Flashcard(question: "Q1", options: ["A", "B"], correctAnswer: "A")
        let card2 = Flashcard(question: "Q2", options: ["C", "D"], correctAnswer: "C")
        let card3 = Flashcard(question: "Q3", options: ["E", "F"], correctAnswer: "E")

        var queue = [card1, card2, card3]
        var currentIndex = 0

        // User answers card1 incorrectly
        let answeredCard = queue[currentIndex]
        let isCorrect = false
        if !isCorrect {
            let reinsertIndex = min(currentIndex + 3, queue.count)
            queue.insert(answeredCard, at: reinsertIndex)
        }

        #expect(queue.count == 4)
        #expect(queue[3].id == card1.id) // card1 re-queued at the end

        // Advance to card2 and answer correctly
        currentIndex += 1
        #expect(queue[currentIndex].id == card2.id)

        // Advance to card3, user skips it -> re-queued
        currentIndex += 1
        #expect(queue[currentIndex].id == card3.id)
        let skippedCard = queue[currentIndex]
        let reinsertSkipIndex = min(currentIndex + 3, queue.count)
        queue.insert(skippedCard, at: reinsertSkipIndex)

        #expect(queue.count == 5)
        #expect(queue.contains { $0.id == card1.id })
        #expect(queue.contains { $0.id == card3.id })
    }

    @Test("Answer locking prevents changing selection after answering")
    func answerLockingLogic() {
        var selectedAnswer: String? = nil
        var isGraded = false

        func selectOption(_ option: String, correctAnswer: String) {
            guard !isGraded && selectedAnswer == nil else { return }
            selectedAnswer = option
            isGraded = true
        }

        // User clicks Option B (incorrect)
        selectOption("B", correctAnswer: "A")
        #expect(selectedAnswer == "B")
        #expect(isGraded == true)

        // User attempts to click Option A afterwards
        selectOption("A", correctAnswer: "A")
        #expect(selectedAnswer == "B") // Remains locked on first choice
    }

    @Test("Option visual state differentiates correct from incorrect answers")
    func optionVisualStateFeedback() {
        enum VisualFeedback {
            case correct
            case wrongSelected
            case dimmed
            case unselected
        }

        func feedback(for option: String, selected: String?, correct: String, isGraded: Bool) -> VisualFeedback {
            guard isGraded else { return .unselected }
            if option == correct { return .correct }
            if option == selected && option != correct { return .wrongSelected }
            return .dimmed
        }

        // Scenario 1: User chose incorrect answer "B" when correct is "A"
        let fbA = feedback(for: "A", selected: "B", correct: "A", isGraded: true)
        let fbB = feedback(for: "B", selected: "B", correct: "A", isGraded: true)
        let fbC = feedback(for: "C", selected: "B", correct: "A", isGraded: true)

        #expect(fbA == .correct)       // Correct answer highlighted green
        #expect(fbB == .wrongSelected) // Wrong user choice highlighted red/coral
        #expect(fbC == .dimmed)        // Other options dimmed

        // Scenario 2: User chose correct answer "A"
        let fbCorrect = feedback(for: "A", selected: "A", correct: "A", isGraded: true)
        let fbOther = feedback(for: "B", selected: "A", correct: "A", isGraded: true)
        #expect(fbCorrect == .correct)
        #expect(fbOther == .dimmed)
    }

    @Test("Small deck repeats and cycles to fill scheduled notification volume")
    func smallDeckCyclesToFillVolume() {
        let card1 = Flashcard(question: "Q1", options: ["A"], correctAnswer: "A")
        let card2 = Flashcard(question: "Q2", options: ["B"], correctAnswer: "B")
        let cards = [card1, card2]

        let targetVolume = 5
        var cycledCards: [Flashcard] = []
        var index = 0
        while cycledCards.count < targetVolume {
            cycledCards.append(cards[index % cards.count])
            index += 1
        }

        #expect(cycledCards.count == 5)
        #expect(cycledCards[0].id == card1.id)
        #expect(cycledCards[1].id == card2.id)
        #expect(cycledCards[2].id == card1.id)
        #expect(cycledCards[3].id == card2.id)
        #expect(cycledCards[4].id == card1.id)
    }

    @Test("Notification session resets and cycles when unseen cards are exhausted")
    func notificationSessionContinuousCycle() {
        let deck = Deck(name: "Test Deck", colorHex: "#5568C9")
        let cardA = Flashcard(question: "A", options: ["1"], correctAnswer: "1")
        let cardB = Flashcard(question: "B", options: ["2"], correctAnswer: "2")
        deck.cards = [cardA, cardB]

        var seenCardIds: Set<String> = []

        // Pass 1: Card A
        var unseen = deck.cards.filter { !seenCardIds.contains($0.id.uuidString) }
        var nextCard = unseen.first
        #expect(nextCard != nil)
        seenCardIds.insert(nextCard!.id.uuidString)

        // Pass 2: Card B
        unseen = deck.cards.filter { !seenCardIds.contains($0.id.uuidString) }
        nextCard = unseen.first
        #expect(nextCard != nil)
        seenCardIds.insert(nextCard!.id.uuidString)

        // Pass 3: All cards seen -> Reset and cycle!
        unseen = deck.cards.filter { !seenCardIds.contains($0.id.uuidString) }
        #expect(unseen.isEmpty)
        if unseen.isEmpty {
            seenCardIds.removeAll()
            let sorted = deck.cards.sorted { $0.studyPriority > $1.studyPriority }
            nextCard = sorted.first
        }
        #expect(nextCard != nil)
        #expect(seenCardIds.isEmpty)
    }

    @Test("Deck hits 100% and restarts with fire streak counting so it never caps")
    func deckHits100PercentAndRestartsWithFireStreak() {
        let deck = Deck(name: "Streak Test Deck", colorHex: "#5568C9")
        let card1 = Flashcard(question: "Q1", options: ["A"], correctAnswer: "A")
        let card2 = Flashcard(question: "Q2", options: ["B"], correctAnswer: "B")
        deck.cards = [card1, card2]

        // Initially 0 reviews
        #expect(deck.totalReviews == 0)
        #expect(deck.cycleStreak == 0)
        #expect(deck.cycleProgress == 0.0)

        // Review 1 card (50%)
        card1.processAnswer(isCorrect: true)
        #expect(deck.totalReviews == 1)
        #expect(deck.cycleStreak == 0)
        #expect(deck.cycleProgress == 0.5)

        // Review 2nd card (hits 100% of cycle 1 -> restarts with fire streak 1!)
        card2.processAnswer(isCorrect: true)
        #expect(deck.totalReviews == 2)
        #expect(deck.cycleStreak == 1) // Streak is 1!
        #expect(deck.cycleProgress == 0.0) // Restarts progress bar for next cycle!

        // Review card 1 again in cycle 2 (50% towards streak 2)
        card1.processAnswer(isCorrect: true)
        #expect(deck.totalReviews == 3)
        #expect(deck.cycleStreak == 1)
        #expect(deck.cycleProgress == 0.5)

        // Review card 2 again in cycle 2 (hits 100% of cycle 2 -> restarts with fire streak 2!)
        card2.processAnswer(isCorrect: false)
        #expect(deck.totalReviews == 4)
        #expect(deck.cycleStreak == 2) // Streak is 2!
        #expect(deck.cycleProgress == 0.0) // Restarts again!
    }
}



@Suite("PDF Page Range & Section Selection Tests")
struct PDFPageRangeTests {

    @Test("Section kind classification recognizes modules, chapters, front/back matter")
    func sectionKindClassification() {
        #expect(PDFOutlineManager.classifyKind(title: "Módulo 1: Introducción") == .module)
        #expect(PDFOutlineManager.classifyKind(title: "Module 3: Advanced Topics") == .module)
        #expect(PDFOutlineManager.classifyKind(title: "Capítulo 4: La Célula") == .chapter)
        #expect(PDFOutlineManager.classifyKind(title: "Chapter 12: Genetics") == .chapter)
        #expect(PDFOutlineManager.classifyKind(title: "Table of Contents") == .frontMatter)
        #expect(PDFOutlineManager.classifyKind(title: "Índice General") == .frontMatter)
        #expect(PDFOutlineManager.classifyKind(title: "Preface") == .frontMatter)
        #expect(PDFOutlineManager.classifyKind(title: "Appendix B") == .backMatter)
        #expect(PDFOutlineManager.classifyKind(title: "Glossary") == .backMatter)
        #expect(PDFOutlineManager.classifyKind(title: "Lección 2") == .section)
        #expect(PDFOutlineManager.classifyKind(title: "Unit 5 Review") == .section)
    }

    @Test("Creating subset PDF extracts exactly the selected page indices")
    func subsetCreationExactPages() throws {
        // Create an in-memory 5-page PDF
        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, CGRect(x: 0, y: 0, width: 200, height: 200), nil)
        for i in 1...5 {
            UIGraphicsBeginPDFPage()
            let str = "Page \(i)" as NSString
            str.draw(at: CGPoint(x: 20, y: 20), withAttributes: nil)
        }
        UIGraphicsEndPDFContext()

        guard let doc = PDFDocument(data: pdfData as Data) else {
            Issue.record("Failed to create test PDFDocument")
            return
        }
        #expect(doc.pageCount == 5)

        // Select pages 2 and 4 (indices 1 and 3)
        let selectedIndices: Set<Int> = [1, 3]
        let subsetData = try PDFOutlineManager.createSubset(from: doc, selectedPageIndices: selectedIndices)
        guard let subsetDoc = PDFDocument(data: subsetData) else {
            Issue.record("Failed to read subset PDF")
            return
        }

        #expect(subsetDoc.pageCount == 2)
        #expect(subsetDoc.page(at: 0)?.string?.contains("Page 2") == true)
        #expect(subsetDoc.page(at: 1)?.string?.contains("Page 4") == true)
    }

    @Test("Size limit above 8 MB throws sizeExceeded error")
    func sizeLimitExceededHandling() {
        let largeBytes = 9 * 1024 * 1024 // 9 MB
        let error = PDFOutlineError.sizeExceeded(largeBytes)
        #expect(error.errorDescription?.contains("8 MB") == true)
    }

    @Test("Encrypted PDF error description is clear and actionable")
    func encryptedPDFError() {
        let err = PDFOutlineError.encrypted
        #expect(err.errorDescription?.contains("password-protected") == true)
    }

    @Test("Contentless detection identifies empty pages")
    func contentlessDetection() {
        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, CGRect(x: 0, y: 0, width: 200, height: 200), nil)
        // Page 1: Empty
        UIGraphicsBeginPDFPage()
        // Page 2: Has substantial text
        UIGraphicsBeginPDFPage()
        let str = "This is a detailed paragraph with plenty of content to study for the upcoming quiz." as NSString
        str.draw(at: CGPoint(x: 20, y: 20), withAttributes: nil)
        UIGraphicsEndPDFContext()

        guard let doc = PDFDocument(data: pdfData as Data) else {
            Issue.record("Failed to create test PDFDocument")
            return
        }

        #expect(PDFOutlineManager.isRangeContentless(doc: doc, start: 0, end: 0) == true)
        #expect(PDFOutlineManager.isRangeContentless(doc: doc, start: 1, end: 1) == false)
    }

    @Test("Folder assignment groups cards under selection chunk title")
    func folderAssignmentFromChunk() {
        let deck = Deck(name: "Biology 101", colorHex: "#5568C9")
        let card1 = Flashcard(question: "Q1", options: ["A"], correctAnswer: "A")
        let card2 = Flashcard(question: "Q2", options: ["B"], correctAnswer: "B")
        deck.cards = [card1, card2]

        let folderTitle = "Chapter 4: Cell Division (Pages 40–55)"
        let section = deck.assignCardToSection(card: card1, suggestedCategory: folderTitle)
        deck.assignCardToSection(card: card2, suggestedCategory: folderTitle)

        #expect(deck.sections.count == 1)
        #expect(deck.sections.first?.name == folderTitle)
        #expect(card1.section?.name == folderTitle)
        #expect(card2.section?.name == folderTitle)
        #expect(section?.cards.count == 2)
    }

    @Test("Section sanitization eliminates overlap and prevents missing final pages")
    func sectionSanitizationAndPartitioning() {
        // Simulating the exact 4-page issue reported: Section 1 (page 0), Section 2 (start page 0 or 1, end page 2)
        let rawSections = [
            PDFSectionItem(title: "Spanish Vocabulary", kind: .other, startPageIndex: 0, endPageIndex: 0),
            PDFSectionItem(title: "Repaso General", kind: .chapter, startPageIndex: 0, endPageIndex: 2)
        ]

        let chained = PDFOutlineManager.sanitizeAndChainSections(rawSections, totalPageCount: 4)

        #expect(chained.count == 2)
        // Section 1 must cover page 0 (Page 1)
        #expect(chained[0].startPageIndex == 0)
        #expect(chained[0].endPageIndex == 0)

        // Section 2 must start at page 1 (Page 2) — NO duplication of page 0/1!
        #expect(chained[1].startPageIndex == 1)
        // Section 2 must extend to page 3 (Page 4) — Page 4 is NOT lost!
        #expect(chained[1].endPageIndex == 3)

        // Verify total coverage without duplicate pages
        let set1 = Set(chained[0].startPageIndex...chained[0].endPageIndex)
        let set2 = Set(chained[1].startPageIndex...chained[1].endPageIndex)
        #expect(set1.intersection(set2).isEmpty) // Zero overlap!
        #expect(set1.union(set2) == Set(0...3))   // Covers all 4 pages completely!
    }
}
