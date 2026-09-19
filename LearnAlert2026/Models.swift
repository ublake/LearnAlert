//
//  Deck.swift
//  LearnAlert2026
//
//  Created by Blake Miller on 2/19/26.
//


import Foundation
import SwiftData

@Model
class Deck {
    var id: UUID
    var name: String
    var colorHex: String
    var creationDate: Date
    
    @Relationship(deleteRule: .cascade, inverse: \Flashcard.deck)
    var cards: [Flashcard]
    
    init(name: String, colorHex: String = "#00FFFF") {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.creationDate = Date()
        self.cards = []
    }
}

@Model
class Flashcard {
    var id: UUID
    var question: String
    var options: [String]
    var correctAnswer: String
    
    // Spaced Repetition (SRS) Engine Data
    var isNew: Bool
    var nextReviewDate: Date
    var easeFactor: Double
    var interval: Int // in days
    
    var deck: Deck?
    
    init(question: String, options: [String], correctAnswer: String) {
        self.id = UUID()
        self.question = question
        self.options = options
        self.correctAnswer = correctAnswer
        
        self.isNew = true
        self.nextReviewDate = Date() // Due immediately upon creation
        self.easeFactor = 2.5 // Standard SM-2 starting ease
        self.interval = 0
    }
    
    // MARK: - The Spaced Repetition Math
    func processAnswer(isCorrect: Bool) {
        if isCorrect {
            // Pushing the interval further into the future
            if interval == 0 {
                interval = 1
            } else if interval == 1 {
                interval = 6
            } else {
                interval = Int(round(Double(interval) * easeFactor))
            }
            isNew = false
        } else {
            // Reset the interval, drop the ease factor so it shows up more often
            interval = 0
            easeFactor = max(1.3, easeFactor - 0.2) // Floors at 1.3 so it doesn't get stuck forever
        }
        
        // Calculate the exact date for the next review
        if let nextDate = Calendar.current.date(byAdding: .day, value: interval, to: Date()) {
            self.nextReviewDate = nextDate
        }
    }
}
