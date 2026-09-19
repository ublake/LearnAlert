import SwiftUI

#Preview("Spanish Quiz Notification") {
    FlashcardNotificationView(
        cardId: "preview-spanish-card",
        deckName: "Spanish",
        deckType: "Quiz",
        isRandom: false,
        progress: "3/17",
        question: "What does “Buenos días” mean?",
        options: ["Good evening", "Good morning", "Good night", "See you later"],
        correctAnswer: "Good morning",
        hint: "You would say this when greeting someone early in the day.",
        previewMode: true
    )
    .frame(width: 393, height: 620)
}

#Preview("Reveal Notification") {
    FlashcardNotificationView(
        cardId: "preview-reveal-card",
        deckName: "Spanish",
        deckType: "Flashcard",
        isRandom: false,
        progress: "4/17",
        question: "Buenos días",
        options: [],
        correctAnswer: "Good morning",
        hint: "A common greeting before noon.",
        previewMode: true
    )
    .frame(width: 393, height: 620)
}
