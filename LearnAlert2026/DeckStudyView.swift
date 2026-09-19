import SwiftUI
import SwiftData

struct DeckStudyView: View {
    @Bindable var deck: Deck
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var cardIndex = 0
    @State private var selectedAnswer: String?
    @State private var isRevealed = false
    @State private var isGraded = false
    @State private var correctCount = 0

    private var cards: [Flashcard] {
        deck.cards.sorted { $0.id.uuidString < $1.id.uuidString }
    }

    private var currentCard: Flashcard? {
        cards.indices.contains(cardIndex) ? cards[cardIndex] : nil
    }

    var body: some View {
        ZStack {
            LearnAlertBackground(emphasized: true)

            if let card = currentCard {
                VStack(spacing: 22) {
                    HStack {
                        Text("\(cardIndex + 1) of \(cards.count)")
                        Spacer()
                        Label("\(correctCount)", systemImage: "checkmark.circle.fill")
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(.white.opacity(0.8))

                    Spacer(minLength: 10)

                    VStack(spacing: 22) {
                        Text(card.question)
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        if deck.deckType == "Quiz" || deck.deckType == "True / False" {
                            quizOptions(for: card)
                        } else {
                            revealContent(for: card)
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity)
                    .nativeGlass(cornerRadius: 24)

                    Spacer(minLength: 10)

                    if isGraded {
                        Button(cardIndex + 1 < cards.count ? "Next Card" : "Finish") {
                            advance()
                        }
                        .buttonStyle(PrimaryActionButtonStyle())
                    }
                }
                .padding(20)
            } else {
                ContentUnavailableView(
                    "No Cards Yet",
                    systemImage: "rectangle.stack.badge.plus",
                    description: Text("Add cards before starting a study session.")
                )
                .foregroundStyle(.white)
            }
        }
        .navigationTitle("Study \(deck.name)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private func quizOptions(for card: Flashcard) -> some View {
        VStack(spacing: 12) {
            ForEach(card.options, id: \.self) { option in
                Button {
                    guard selectedAnswer == nil else { return }
                    selectedAnswer = option
                    grade(card, isCorrect: option == card.correctAnswer)
                } label: {
                    HStack {
                        Text(option)
                            .font(.headline)
                        Spacer()
                        if selectedAnswer != nil && option == card.correctAnswer {
                            Image(systemName: "checkmark.circle.fill")
                        } else if selectedAnswer == option {
                            Image(systemName: "xmark.circle.fill")
                        }
                    }
                    .foregroundStyle(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(optionColor(option, card: card))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(selectedAnswer != nil)
            }
        }
    }

    @ViewBuilder
    private func revealContent(for card: Flashcard) -> some View {
        if !isRevealed {
            Button("Reveal Answer") {
                withAnimation(.snappy) { isRevealed = true }
            }
            .buttonStyle(PrimaryActionButtonStyle())
        } else {
            Text(card.correctAnswer)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            if !isGraded {
                HStack(spacing: 12) {
                    Button("Missed It") { grade(card, isCorrect: false) }
                        .buttonStyle(StudyGradeButtonStyle(color: LearnAlertStyle.coral))
                    Button("Knew It") { grade(card, isCorrect: true) }
                        .buttonStyle(StudyGradeButtonStyle(color: LearnAlertStyle.lime))
                }
            }
        }
    }

    private func optionColor(_ option: String, card: Flashcard) -> Color {
        guard let selectedAnswer else { return Color.white.opacity(0.12) }
        if option == card.correctAnswer { return LearnAlertStyle.lime.opacity(0.55) }
        if option == selectedAnswer { return LearnAlertStyle.coral.opacity(0.65) }
        return Color.white.opacity(0.06)
    }

    private func grade(_ card: Flashcard, isCorrect: Bool) {
        card.processAnswer(isCorrect: isCorrect)
        if isCorrect { correctCount += 1 }
        isGraded = true
        try? context.save()
    }

    private func advance() {
        guard cardIndex + 1 < cards.count else {
            dismiss()
            return
        }
        cardIndex += 1
        selectedAnswer = nil
        isRevealed = false
        isGraded = false
    }
}

private struct StudyGradeButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(color.opacity(configuration.isPressed ? 0.55 : 0.8))
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
