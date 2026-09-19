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

    private var effectiveQuestion: String {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        if selectedType == .matching && trimmed.isEmpty {
            return "Match the correct pairs"
        }
        return trimmed
    }

    private var isFormValid: Bool {
        guard let selectedType else { return false }
        switch selectedType {
        case .tapReveal:
            return !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                   !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .fillBlank:
            return !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                   !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .multipleChoice:
            guard !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
            return correctOptionIndex < visibleOptionCount &&
                   options.prefix(visibleOptionCount).allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
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
                LearnAlertStyle.courseCanvas
                    .ignoresSafeArea()

                if selectedType == nil {
                    typePicker
                } else {
                    editor
                }
            }
            .navigationTitle(cardToEdit == nil ? "New Card" : "Edit Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(LearnAlertStyle.textSecondary)
                }
                if selectedType != nil && cardToEdit == nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Change Type") {
                            withAnimation(.snappy) { selectedType = nil }
                        }
                        .font(.custom("Poppins-Medium", size: 13))
                        .foregroundStyle(LearnAlertStyle.indigo)
                    }
                }
            }
            .toolbarBackground(LearnAlertStyle.courseCanvas, for: .navigationBar)
            .onAppear(perform: setupData)
        }
    }

    // MARK: - Type Picker
    private var typePicker: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Select Card Type")
                        .font(.custom("Poppins-SemiBold", size: 22, relativeTo: .title2))
                        .foregroundStyle(LearnAlertStyle.textPrimary)
                    Text("Choose how learners interact with this card during daily study and alert notifications.")
                        .font(.custom("Poppins-Regular", size: 13, relativeTo: .subheadline))
                        .foregroundStyle(LearnAlertStyle.textSecondary)
                        .lineSpacing(2)
                }
                .padding(.top, 4)

                ForEach(FlashcardType.allCases) { type in
                    Button {
                        selectType(type)
                    } label: {
                        HStack(spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(typeColor(type).opacity(0.15))
                                    .frame(width: 48, height: 48)
                                Image(systemName: type.icon)
                                    .font(.title3)
                                    .foregroundStyle(typeColor(type))
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(type.title)
                                        .font(.custom("Poppins-SemiBold", size: 16, relativeTo: .headline))
                                        .foregroundStyle(LearnAlertStyle.textPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption.bold())
                                        .foregroundStyle(LearnAlertStyle.textSecondary)
                                }
                                Text(typeDescription(type))
                                    .font(.custom("Poppins-Regular", size: 12, relativeTo: .caption))
                                    .foregroundStyle(LearnAlertStyle.textSecondary)
                                    .multilineTextAlignment(.leading)
                                    .lineSpacing(1.5)
                            }
                        }
                        .padding(16)
                        .settingsGlassSurface(cornerRadius: 18)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
    }

    private func selectType(_ type: FlashcardType) {
        withAnimation(.snappy) {
            selectedType = type
            if type == .matching && question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                question = "Match the correct pairs"
            }
        }
    }

    // MARK: - Card Editor
    private var editor: some View {
        ScrollView {
            VStack(spacing: 18) {
                // Header badge showing currently active card type
                if let selectedType {
                    HStack(spacing: 8) {
                        Image(systemName: selectedType.icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(typeColor(selectedType))
                        Text(selectedType.title.uppercased())
                            .font(.custom("Poppins-SemiBold", size: 11))
                            .foregroundStyle(typeColor(selectedType))
                        Spacer()
                        if cardToEdit == nil {
                            Button("Switch") {
                                withAnimation(.snappy) { self.selectedType = nil }
                            }
                            .font(.custom("Poppins-Medium", size: 12))
                            .foregroundStyle(LearnAlertStyle.indigo)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(typeColor(selectedType).opacity(0.08))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(typeColor(selectedType).opacity(0.2), lineWidth: 1))
                }

                // Main Content Form
                switch selectedType {
                case .multipleChoice:
                    multipleChoiceEditor
                case .tapReveal:
                    tapRevealEditor
                case .matching:
                    matchingEditor
                case .fillBlank:
                    fillBlankEditor
                case .none:
                    EmptyView()
                }

                // Hint section
                formCard("HINT (OPTIONAL)") {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("A small clue to help jog memory...", text: $hint, axis: .vertical)
                            .lineLimit(2...3)
                            .font(.custom("Poppins-Regular", size: 14))
                            .foregroundStyle(LearnAlertStyle.textPrimary)
                            .glassCardField()
                        Text("Appears when the learner taps \"Hint\" in study or notification.")
                            .font(.custom("Poppins-Regular", size: 11))
                            .foregroundStyle(LearnAlertStyle.textSecondary)
                    }
                }

                // Category Section
                if !deck.sections.isEmpty {
                    formCard("CATEGORY (OPTIONAL)") {
                        Picker("Category", selection: $selectedSectionId) {
                            Text("No Category").tag("NONE")
                            ForEach(deck.sections.sorted { $0.orderIndex < $1.orderIndex }) { section in
                                Text(section.name).tag(section.id.uuidString)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(LearnAlertStyle.indigo)
                        .padding(.vertical, 4)
                    }
                }

                // Live Preview Card
                formCard("LIVE PREVIEW") {
                    CardLiveMiniPreview(
                        type: selectedType ?? .multipleChoice,
                        question: effectiveQuestion.isEmpty ? "Question prompt will appear here" : effectiveQuestion,
                        answer: answer.isEmpty ? "Answer..." : answer,
                        options: Array(options.prefix(visibleOptionCount)),
                        correctOptionIndex: correctOptionIndex,
                        matchingLeft: Array(matchingLeft.prefix(visiblePairCount)),
                        matchingRight: Array(matchingRight.prefix(visiblePairCount)),
                        hint: hint
                    )
                }

                // Save Button
                Button(action: saveCard) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                        Text(cardToEdit == nil ? "Save Card" : "Update Card")
                    }
                    .font(.custom("Poppins-SemiBold", size: 15))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                }
                .foregroundStyle(.white)
                .background(
                    isFormValid
                        ? AnyShapeStyle(
                            LinearGradient(
                                colors: [LearnAlertStyle.indigo, LearnAlertStyle.indigo.opacity(0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        : AnyShapeStyle(Color.gray.opacity(0.3))
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(isFormValid ? Color.white.opacity(0.25) : Color.clear, lineWidth: 1)
                )
                .shadow(
                    color: isFormValid ? LearnAlertStyle.indigo.opacity(0.3) : Color.clear,
                    radius: 10,
                    y: 4
                )
                .disabled(!isFormValid)
                .padding(.top, 6)
            }
            .padding(20)
        }
    }

    // MARK: - Multiple Choice Editor
    private var multipleChoiceEditor: some View {
        VStack(spacing: 16) {
            formCard("QUESTION") {
                TextField("e.g. What is the powerhouse of the cell?", text: $question, axis: .vertical)
                    .lineLimit(2...4)
                    .font(.custom("Poppins-Medium", size: 14))
                    .foregroundStyle(LearnAlertStyle.textPrimary)
                    .glassCardField()
            }

            formCard("QUIZ CHOICES") {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Number of options")
                            .font(.custom("Poppins-Medium", size: 13))
                            .foregroundStyle(LearnAlertStyle.textSecondary)
                        Spacer()
                        HStack(spacing: 6) {
                            ForEach(2...4, id: \.self) { count in
                                Button {
                                    withAnimation(.snappy) {
                                        visibleOptionCount = count
                                        if correctOptionIndex >= count { correctOptionIndex = 0 }
                                    }
                                } label: {
                                    Text("\(count) Choices")
                                        .font(.custom("Poppins-SemiBold", size: 12))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(visibleOptionCount == count ? LearnAlertStyle.indigo : Color.primary.opacity(0.06))
                                        .foregroundStyle(visibleOptionCount == count ? Color.white : LearnAlertStyle.textPrimary)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }

                    VStack(spacing: 10) {
                        ForEach(0..<visibleOptionCount, id: \.self) { index in
                            HStack(spacing: 10) {
                                Button {
                                    correctOptionIndex = index
                                } label: {
                                    Image(systemName: correctOptionIndex == index ? "checkmark.circle.fill" : "circle")
                                        .font(.title3)
                                        .foregroundStyle(correctOptionIndex == index ? Color.green : LearnAlertStyle.textSecondary)
                                }
                                .buttonStyle(.plain)

                                TextField("Option \(index + 1)", text: $options[index])
                                    .font(.custom("Poppins-Medium", size: 14))
                                    .foregroundStyle(LearnAlertStyle.textPrimary)
                                    .glassCardField()
                            }
                        }
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle")
                            .font(.caption)
                            .foregroundStyle(Color.green)
                        Text("Tap the circle beside the correct answer.")
                            .font(.custom("Poppins-Regular", size: 11))
                            .foregroundStyle(LearnAlertStyle.textSecondary)
                    }
                }
            }
        }
    }

    // MARK: - Tap to Reveal Editor
    private var tapRevealEditor: some View {
        VStack(spacing: 16) {
            formCard("FRONT OF CARD (PROMPT)") {
                VStack(alignment: .leading, spacing: 6) {
                    TextField("e.g. Mitochondria, or \"What is photosynthesis?\"", text: $question, axis: .vertical)
                        .lineLimit(2...4)
                        .font(.custom("Poppins-Medium", size: 14))
                        .foregroundStyle(LearnAlertStyle.textPrimary)
                        .glassCardField()
                    Text("The question or term shown first.")
                        .font(.custom("Poppins-Regular", size: 11))
                        .foregroundStyle(LearnAlertStyle.textSecondary)
                }
            }

            formCard("BACK OF CARD (REVEALED ANSWER)") {
                VStack(alignment: .leading, spacing: 6) {
                    TextField("e.g. The powerhouse of the cell that generates ATP.", text: $answer, axis: .vertical)
                        .lineLimit(2...5)
                        .font(.custom("Poppins-Medium", size: 14))
                        .foregroundStyle(LearnAlertStyle.textPrimary)
                        .glassCardField()
                    Text("Shown when the learner taps to reveal.")
                        .font(.custom("Poppins-Regular", size: 11))
                        .foregroundStyle(LearnAlertStyle.textSecondary)
                }
            }
        }
    }

    // MARK: - Match Pairs Editor
    private var matchingEditor: some View {
        VStack(spacing: 16) {
            formCard("PROMPT (AUTO-FILLED)") {
                VStack(alignment: .leading, spacing: 6) {
                    TextField("Match the correct pairs", text: $question)
                        .font(.custom("Poppins-Medium", size: 14))
                        .foregroundStyle(LearnAlertStyle.textPrimary)
                        .glassCardField()
                    Text("Auto-filled as \"Match the correct pairs\". You can leave this as-is or specify custom instructions (e.g. \"Match Spanish verbs to English\").")
                        .font(.custom("Poppins-Regular", size: 11))
                        .foregroundStyle(LearnAlertStyle.textSecondary)
                        .lineSpacing(1.5)
                }
            }

            formCard("MATCHING PAIRS") {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Number of pairs")
                            .font(.custom("Poppins-Medium", size: 13))
                            .foregroundStyle(LearnAlertStyle.textSecondary)
                        Spacer()
                        HStack(spacing: 6) {
                            ForEach(2...4, id: \.self) { count in
                                Button {
                                    withAnimation(.snappy) { visiblePairCount = count }
                                } label: {
                                    Text("\(count) Pairs")
                                        .font(.custom("Poppins-SemiBold", size: 12))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(visiblePairCount == count ? LearnAlertStyle.indigo : Color.primary.opacity(0.06))
                                        .foregroundStyle(visiblePairCount == count ? Color.white : LearnAlertStyle.textPrimary)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }

                    VStack(spacing: 10) {
                        ForEach(0..<visiblePairCount, id: \.self) { index in
                            VStack(alignment: .leading, spacing: 6) {
                                Text("PAIR \(index + 1)")
                                    .font(.custom("Poppins-SemiBold", size: 10))
                                    .foregroundStyle(LearnAlertStyle.textSecondary)

                                HStack(spacing: 8) {
                                    TextField("Left item (e.g. Bonjour)", text: $matchingLeft[index])
                                        .font(.custom("Poppins-Medium", size: 13))
                                        .foregroundStyle(LearnAlertStyle.textPrimary)
                                        .glassCardField()

                                    Image(systemName: "arrow.left.arrow.right")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(LearnAlertStyle.indigo)

                                    TextField("Right match (e.g. Hello)", text: $matchingRight[index])
                                        .font(.custom("Poppins-Medium", size: 13))
                                        .foregroundStyle(LearnAlertStyle.textPrimary)
                                        .glassCardField()
                                }
                            }
                            .padding(10)
                            .background(Color.primary.opacity(0.03))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(LearnAlertStyle.hairline.opacity(0.25), lineWidth: 0.75)
                            )
                        }
                    }

                    Text("During study, right-hand items are shuffled. Learners match them by tapping or dragging.")
                        .font(.custom("Poppins-Regular", size: 11))
                        .foregroundStyle(LearnAlertStyle.textSecondary)
                }
            }
        }
    }

    // MARK: - Fill in the Blank Editor
    private var fillBlankEditor: some View {
        VStack(spacing: 16) {
            formCard("PROMPT WITH BLANK") {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("e.g. The capital of France is ___.", text: $question, axis: .vertical)
                        .lineLimit(2...4)
                        .font(.custom("Poppins-Medium", size: 14))
                        .foregroundStyle(LearnAlertStyle.textPrimary)
                        .glassCardField()

                    Button {
                        if !question.contains("___") {
                            if question.isEmpty {
                                question = "___"
                            } else {
                                question += " ___"
                            }
                        }
                    } label: {
                        Label("Insert Blank (___)", systemImage: "plus.square.dashed")
                            .font(.custom("Poppins-SemiBold", size: 12))
                            .foregroundStyle(LearnAlertStyle.indigo)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(LearnAlertStyle.indigo.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
            }

            formCard("TARGET ANSWER") {
                VStack(alignment: .leading, spacing: 6) {
                    TextField("e.g. Paris", text: $answer)
                        .font(.custom("Poppins-Medium", size: 14))
                        .foregroundStyle(LearnAlertStyle.textPrimary)
                        .glassCardField()
                    Text("The exact word or phrase that fills the blank. Evaluation is case-insensitive.")
                        .font(.custom("Poppins-Regular", size: 11))
                        .foregroundStyle(LearnAlertStyle.textSecondary)
                }
            }
        }
    }

    // MARK: - Helper Views & Methods
    private func formCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(LearnAlertStyle.textSecondary)
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .settingsGlassSurface(cornerRadius: 18)
    }

    private func typeColor(_ type: FlashcardType) -> Color {
        switch type {
        case .multipleChoice: LearnAlertStyle.indigo
        case .tapReveal: LearnAlertStyle.aqua
        case .matching: Color.purple
        case .fillBlank: Color.orange
        }
    }

    private func typeDescription(_ type: FlashcardType) -> String {
        switch type {
        case .multipleChoice: "Choose the correct answer from 2–4 options with instant grading."
        case .tapReveal: "Classic active-recall flashcard. Ponder the answer, then tap to reveal."
        case .matching: "Connect corresponding terms and definitions by tapping or dragging."
        case .fillBlank: "Type the missing keyword into the sentence. Case-insensitive."
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
        let finalQuestion = effectiveQuestion
        let finalOptions = selectedType == .multipleChoice
            ? options.prefix(visibleOptionCount).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            : []
        let finalAnswer = selectedType == .multipleChoice
            ? (finalOptions.indices.contains(correctOptionIndex) ? finalOptions[correctOptionIndex] : "")
            : answer.trimmingCharacters(in: .whitespacesAndNewlines)
        let left = selectedType == .matching
            ? matchingLeft.prefix(visiblePairCount).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            : []
        let right = selectedType == .matching
            ? matchingRight.prefix(visiblePairCount).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            : []

        let card = cardToEdit ?? Flashcard(
            question: finalQuestion,
            options: finalOptions,
            correctAnswer: finalAnswer,
            hint: hint.trimmingCharacters(in: .whitespacesAndNewlines),
            cardType: selectedType,
            matchingLeftItems: left,
            matchingRightItems: right
        )
        card.question = finalQuestion
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

// MARK: - Mini Live Preview in Card Editor
private struct CardLiveMiniPreview: View {
    let type: FlashcardType
    let question: String
    let answer: String
    let options: [String]
    let correctOptionIndex: Int
    let matchingLeft: [String]
    let matchingRight: [String]
    let hint: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(question)
                .font(.custom("Poppins-SemiBold", size: 14))
                .foregroundStyle(LearnAlertStyle.textPrimary)

            switch type {
            case .multipleChoice:
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(options.enumerated()), id: \.offset) { idx, opt in
                        HStack(spacing: 8) {
                            Image(systemName: idx == correctOptionIndex ? "checkmark.circle.fill" : "circle")
                                .font(.caption)
                                .foregroundStyle(idx == correctOptionIndex ? Color.green : LearnAlertStyle.textSecondary)
                            Text(opt.isEmpty ? "Choice \(idx + 1)" : opt)
                                .font(.custom("Poppins-Regular", size: 12))
                                .foregroundStyle(idx == correctOptionIndex ? Color.green : LearnAlertStyle.textPrimary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(idx == correctOptionIndex ? Color.green.opacity(0.1) : Color.primary.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }

            case .tapReveal:
                HStack(spacing: 8) {
                    Image(systemName: "eye.fill")
                        .font(.caption)
                        .foregroundStyle(LearnAlertStyle.aqua)
                    Text("Answer: \(answer)")
                        .font(.custom("Poppins-Medium", size: 13))
                        .foregroundStyle(LearnAlertStyle.textPrimary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LearnAlertStyle.aqua.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            case .matching:
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(0..<matchingLeft.count, id: \.self) { idx in
                        let l = matchingLeft[idx]
                        let r = matchingRight.indices.contains(idx) ? matchingRight[idx] : ""
                        HStack(spacing: 8) {
                            Text(l.isEmpty ? "Item \(idx + 1)" : l)
                                .font(.custom("Poppins-Medium", size: 12))
                                .foregroundStyle(LearnAlertStyle.textPrimary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.primary.opacity(0.04))
                                .clipShape(RoundedRectangle(cornerRadius: 6))

                            Image(systemName: "arrow.left.arrow.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(LearnAlertStyle.indigo)

                            Text(r.isEmpty ? "Match \(idx + 1)" : r)
                                .font(.custom("Poppins-Medium", size: 12))
                                .foregroundStyle(Color.purple)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.purple.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }

            case .fillBlank:
                HStack(spacing: 8) {
                    Image(systemName: "text.cursor")
                        .font(.caption)
                        .foregroundStyle(Color.orange)
                    Text("Target: \(answer)")
                        .font(.custom("Poppins-Medium", size: 13))
                        .foregroundStyle(LearnAlertStyle.textPrimary)
                }
                .padding(10)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            if !hint.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.yellow)
                    Text(hint)
                        .font(.custom("Poppins-Regular", size: 11))
                        .foregroundStyle(LearnAlertStyle.textSecondary)
                }
                .padding(.top, 2)
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(LearnAlertStyle.hairline.opacity(0.2), lineWidth: 0.75)
        )
    }
}

// MARK: - Glass Field View Extension
private extension View {
    func glassCardField() -> some View {
        self
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.primary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(LearnAlertStyle.hairline.opacity(0.3), lineWidth: 0.75)
            )
    }
}
