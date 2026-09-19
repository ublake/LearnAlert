import SwiftUI
import SwiftData

struct CreateCardView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let deck: Deck
    var cardToEdit: Flashcard?

    @State private var selectedType: FlashcardType?
    @State private var question = ""
    @State private var answer = ""
    @State private var options = ["", "", "", ""]
    @State private var correctOptionIndex = 0
    @State private var visibleOptionCount = 4
    @State private var matchingLeft = ["", "", "", ""]
    @State private var matchingRight = ["", "", "", ""]
    @State private var visiblePairCount = 2
    @State private var hint = ""
    @State private var selectedSectionId = "NONE"

    private var selectedSection: DeckSection? {
        guard let id = UUID(uuidString: selectedSectionId) else { return nil }
        return deck.sections.first { $0.id == id }
    }

    private var isFormValid: Bool {
        guard let selectedType,
              !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        switch selectedType {
        case .tapReveal, .fillBlank:
            return !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .multipleChoice:
            return options.prefix(visibleOptionCount).allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        case .matching:
            return (0..<visiblePairCount).allSatisfy {
                !matchingLeft[$0].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !matchingRight[$0].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CoursezyBackground()
                if selectedType == nil {
                    typePicker
                } else {
                    editor
                }
            }
            .navigationTitle(cardToEdit == nil ? "New Card" : "Edit Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                if selectedType != nil, cardToEdit == nil {
                    ToolbarItem(placement: .topBarTrailing) { Button("Change Type") { selectedType = nil } }
                }
            }
            .toolbarBackground(LearnAlertStyle.courseCanvas, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .onAppear(perform: setupData)
        }
    }

    private var typePicker: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("What kind of card do you want?")
                    .font(.title2.bold())
                    .foregroundStyle(LearnAlertStyle.textPrimary)
                ForEach(FlashcardType.allCases) { type in
                    Button { selectedType = type } label: {
                        HStack(spacing: 16) {
                            Image(systemName: type.icon).font(.title2).frame(width: 34)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(type.title).font(.headline)
                                Text(typeDescription(type)).font(.caption).foregroundStyle(LearnAlertStyle.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .foregroundStyle(LearnAlertStyle.textPrimary)
                        .coursezyCard()
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
    }

    private var editor: some View {
        ScrollView {
            VStack(spacing: 18) {
                formSection("PROMPT") {
                    TextField(promptPlaceholder, text: $question, axis: .vertical)
                        .lineLimit(3...6).coursezyField()
                }

                if selectedType == .multipleChoice { multipleChoiceEditor }
                if selectedType == .tapReveal { answerEditor(title: "ANSWER", placeholder: "Answer shown after the tap") }
                if selectedType == .fillBlank { answerEditor(title: "MISSING ANSWER", placeholder: "Accepted answer (capitalization does not matter)") }
                if selectedType == .matching { matchingEditor }

                formSection("HINT · OPTIONAL") {
                    TextField("A small clue", text: $hint, axis: .vertical).lineLimit(2...4).coursezyField()
                }

                if !deck.sections.isEmpty {
                    formSection("CATEGORY · OPTIONAL") {
                        Picker("Category", selection: $selectedSectionId) {
                            Text("None").tag("NONE")
                            ForEach(deck.sections.sorted { $0.orderIndex < $1.orderIndex }) { Text($0.name).tag($0.id.uuidString) }
                        }.pickerStyle(.menu)
                    }
                }

                Button(action: saveCard) {
                    Label(cardToEdit == nil ? "Save Card" : "Update Card", systemImage: "checkmark")
                        .font(.headline.bold()).frame(maxWidth: .infinity).padding(.vertical, 16)
                }
                .foregroundStyle(.white)
                .background(isFormValid ? LearnAlertStyle.indigo : LearnAlertStyle.textSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .disabled(!isFormValid).opacity(isFormValid ? 1 : 0.45)
            }
            .padding(20)
        }
    }

    private var multipleChoiceEditor: some View {
        formSection("QUIZ ANSWERS") {
            countControl(label: "Number of choices", count: visibleOptionCount, minimum: 2, maximum: 4) { visibleOptionCount = $0 }
            ForEach(0..<visibleOptionCount, id: \.self) { index in
                HStack(spacing: 10) {
                    Button { correctOptionIndex = index } label: {
                        Image(systemName: correctOptionIndex == index ? "checkmark.circle.fill" : "circle").font(.title2)
                    }
                    TextField("Answer \(index + 1)", text: $options[index]).coursezyField()
                }
            }
            Text("Tap the circle beside the correct answer.").font(.caption).foregroundStyle(LearnAlertStyle.textSecondary)
        }
    }

    private var matchingEditor: some View {
        formSection("MATCHING PAIRS") {
            countControl(label: "Number of pairs", count: visiblePairCount, minimum: 2, maximum: 4) { visiblePairCount = $0 }
            ForEach(0..<visiblePairCount, id: \.self) { index in
                HStack(spacing: 8) {
                    TextField("Left \(index + 1)", text: $matchingLeft[index]).coursezyField()
                    Image(systemName: "arrow.left.arrow.right").foregroundStyle(LearnAlertStyle.indigo)
                    TextField("Match \(index + 1)", text: $matchingRight[index]).coursezyField()
                }
            }
        }
    }

    private func answerEditor(title: String, placeholder: String) -> some View {
        formSection(title) { TextField(placeholder, text: $answer, axis: .vertical).lineLimit(2...5).coursezyField() }
    }

    private func countControl(label: String, count: Int, minimum: Int, maximum: Int, update: @escaping (Int) -> Void) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(LearnAlertStyle.textSecondary)
            Spacer()
            Button { update(max(minimum, count - 1)) } label: { Image(systemName: "minus.circle") }.disabled(count == minimum)
            Text("\(count)").font(.headline.monospacedDigit()).frame(width: 24)
            Button { update(min(maximum, count + 1)) } label: { Image(systemName: "plus.circle") }.disabled(count == maximum)
        }
    }

    private func formSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.caption.bold()).foregroundStyle(LearnAlertStyle.textSecondary)
            content()
        }.coursezyCard()
    }

    private var promptPlaceholder: String { selectedType == .fillBlank ? "Example: The capital of France is ___." : "What should the learner answer?" }

    private func typeDescription(_ type: FlashcardType) -> String {
        switch type {
        case .multipleChoice: "Choose the correct answer from 2–4 options."
        case .tapReveal: "Think first, then reveal the answer."
        case .matching: "Drag 2–4 items onto their correct matches."
        case .fillBlank: "Type the missing answer; capitalization is ignored."
        }
    }

    private func setupData() {
        guard let card = cardToEdit else { return }
        selectedType = card.cardType
        question = card.question
        answer = card.correctAnswer
        hint = card.hint
        selectedSectionId = card.section?.id.uuidString ?? "NONE"
        if card.cardType == .multipleChoice {
            visibleOptionCount = min(4, max(2, card.options.count))
            for (index, option) in card.options.prefix(4).enumerated() { options[index] = option }
            correctOptionIndex = options.firstIndex(of: card.correctAnswer) ?? 0
        } else if card.cardType == .matching {
            visiblePairCount = min(4, max(2, card.matchingLeftItems.count))
            for (index, value) in card.matchingLeftItems.prefix(4).enumerated() { matchingLeft[index] = value }
            for (index, value) in card.matchingRightItems.prefix(4).enumerated() { matchingRight[index] = value }
        }
    }

    private func saveCard() {
        guard let selectedType else { return }
        let trimmedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalOptions = selectedType == .multipleChoice ? options.prefix(visibleOptionCount).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } : []
        let finalAnswer = selectedType == .multipleChoice ? finalOptions[correctOptionIndex] : answer.trimmingCharacters(in: .whitespacesAndNewlines)
        let left = selectedType == .matching ? matchingLeft.prefix(visiblePairCount).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } : []
        let right = selectedType == .matching ? matchingRight.prefix(visiblePairCount).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } : []

        let card = cardToEdit ?? Flashcard(question: trimmedQuestion, options: finalOptions, correctAnswer: finalAnswer, cardType: selectedType)
        card.question = trimmedQuestion
        card.options = finalOptions
        card.correctAnswer = finalAnswer
        card.hint = hint.trimmingCharacters(in: .whitespacesAndNewlines)
        card.cardType = selectedType
        card.matchingLeftItems = left
        card.matchingRightItems = right
        card.section = selectedSection
        if cardToEdit == nil { deck.cards.append(card) }
        try? context.save()
        dismiss()
    }
}
