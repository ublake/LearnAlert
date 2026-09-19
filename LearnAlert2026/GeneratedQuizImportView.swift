import SwiftData
import SwiftUI

private struct EditableGeneratedAnswer: Identifiable {
    let id = UUID()
    var text: String
}

private struct EditableGeneratedQuestion: Identifiable {
    let id = UUID()
    var question: String
    var hint: String
    var answers: [EditableGeneratedAnswer]
    var correctAnswerID: UUID
    var explanation: String
    var isIncluded = true

    init(_ generated: GeneratedQuestion) {
        let editableAnswers = generated.answers.map { EditableGeneratedAnswer(text: $0) }
        self.question = generated.question
        self.hint = generated.hint
        self.answers = editableAnswers
        self.correctAnswerID = editableAnswers[generated.correctAnswerIndex].id
        self.explanation = generated.explanation
    }
}

struct GeneratedQuizImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var decks: [Deck]

    let material: ImportedStudyMaterial

    @State private var questionCount = 10
    @State private var deckTitle = ""
    @State private var questions: [EditableGeneratedQuestion] = []
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var savedDeck: Deck?
    @State private var showsSavedDeck = false
    @State private var generationTask: Task<Void, Never>?

    private var isReviewing: Bool { !questions.isEmpty }
    private var includedCount: Int { questions.lazy.filter(\.isIncluded).count }

    var body: some View {
        NavigationStack {
            ZStack {
                LearnAlertBackground()

                if isReviewing {
                    GeneratedQuizReviewContent(
                        deckTitle: $deckTitle,
                        questions: $questions
                    )
                } else {
                    QuizGenerationSetupView(
                        filename: material.filename,
                        questionCount: $questionCount,
                        isGenerating: isGenerating,
                        generate: generateQuiz
                    )
                }
            }
            .navigationTitle(isReviewing ? "Review Quiz" : "Generate Quiz")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        generationTask?.cancel()
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if isReviewing {
                    Button(action: addToDeck) {
                        Label(
                            includedCount == 1 ? "Add 1 Question to Deck" : "Add \(includedCount) Questions to Deck",
                            systemImage: "rectangle.stack.badge.plus"
                        )
                        .font(.headline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                    }
                    .foregroundStyle(.white)
                    .background(includedCount == 0 ? Color.gray : LearnAlertStyle.indigo)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .disabled(includedCount == 0 || showsSavedDeck)
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .nativeGlass(cornerRadius: 0)
                }
            }
            .alert("Couldn’t Generate Quiz", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "Please try again.")
            }
            .navigationDestination(isPresented: $showsSavedDeck) {
                if let savedDeck {
                    DeckDetailView(deck: savedDeck)
                }
            }
        }
        .onDisappear {
            generationTask?.cancel()
        }
    }

    private func generateQuiz() {
        guard !isGenerating else { return }
        isGenerating = true
        errorMessage = nil

        generationTask = Task {
            defer { isGenerating = false }
            do {
                let quiz = try await LearnAlertAPI().generateQuiz(
                    text: material.text,
                    questionCount: questionCount
                )
                try Task.checkCancellation()
                deckTitle = quiz.deckTitle
                questions = quiz.questions.map(EditableGeneratedQuestion.init)
            } catch is CancellationError {
                return
            } catch let error as LearnAlertAPIError {
                errorMessage = error.localizedDescription
            } catch {
                errorMessage = LearnAlertAPIError.generationFailed.localizedDescription
            }
        }
    }

    private func addToDeck() {
        let selectedQuestions = questions.filter(\.isIncluded)
        guard !selectedQuestions.isEmpty else { return }

        let trimmedTitle = deckTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = trimmedTitle.isEmpty ? material.filename.deletingPathExtension : trimmedTitle
        let color = DeckColorPalette.takeNextColor(existingColors: decks.map(\.colorHex))
        let deck = Deck(name: title, colorHex: color, deckType: "Quiz", orderIndex: decks.count)
        context.insert(deck)

        for generated in selectedQuestions {
            let options = generated.answers.map(\.text)
            guard let correctAnswer = generated.answers.first(where: { $0.id == generated.correctAnswerID })?.text else {
                continue
            }
            deck.cards.append(
                Flashcard(
                    question: generated.question.trimmingCharacters(in: .whitespacesAndNewlines),
                    options: options,
                    correctAnswer: correctAnswer,
                    hint: generated.hint.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            )
        }

        do {
            try context.save()
            savedDeck = deck
            showsSavedDeck = true
        } catch {
            context.delete(deck)
            errorMessage = "The generated deck couldn’t be saved. Please try again."
        }
    }
}

private struct QuizGenerationSetupView: View {
    let filename: String
    @Binding var questionCount: Int
    let isGenerating: Bool
    let generate: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundStyle(LearnAlertStyle.indigo)

                    Text(filename)
                        .font(.title3.bold())
                        .foregroundStyle(LearnAlertStyle.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)

                    Text("Ready to turn this document into editable flashcards.")
                        .font(.subheadline)
                        .foregroundStyle(LearnAlertStyle.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .nativeGlass(cornerRadius: 16)

                VStack(alignment: .leading, spacing: 14) {
                    Text("QUESTION COUNT")
                        .font(.caption.bold())
                        .foregroundStyle(LearnAlertStyle.textSecondary)

                    Picker("Question count", selection: $questionCount) {
                        Text("10").tag(10)
                        Text("20").tag(20)
                        Text("30").tag(30)
                    }
                    .pickerStyle(.segmented)

                    Text("You’ll review every generated question before anything is saved.")
                        .font(.footnote)
                        .foregroundStyle(LearnAlertStyle.textSecondary)
                }
                .padding(20)
                .nativeGlass(cornerRadius: 16)

                Button(action: generate) {
                    HStack(spacing: 10) {
                        if isGenerating {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text(isGenerating ? "Generating quiz…" : "Generate Quiz")
                    }
                    .font(.headline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
                .foregroundStyle(.white)
                .background(LearnAlertStyle.indigo)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .disabled(isGenerating)
                .opacity(isGenerating ? 0.72 : 1)
            }
            .padding(20)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

private struct GeneratedQuizReviewContent: View {
    @Binding var deckTitle: String
    @Binding var questions: [EditableGeneratedQuestion]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("DECK TITLE")
                        .font(.caption.bold())
                        .foregroundStyle(LearnAlertStyle.textSecondary)
                    TextField("Generated deck title", text: $deckTitle)
                        .font(.title3.bold())
                        .foregroundStyle(LearnAlertStyle.textPrimary)
                        .padding(14)
                        .background(Color.white.opacity(0.64))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .padding(18)
                .nativeGlass(cornerRadius: 14)

                ForEach($questions) { $question in
                    GeneratedQuestionReviewRow(
                        question: $question,
                        delete: {
                            withAnimation(.snappy) {
                                questions.removeAll { $0.id == question.id }
                            }
                        }
                    )
                }
            }
            .padding(.horizontal)
            .padding(.top, 14)
            .padding(.bottom, 30)
        }
    }
}

private struct GeneratedQuestionReviewRow: View {
    @Binding var question: EditableGeneratedQuestion
    let delete: () -> Void
    @State private var isEditing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Toggle("Include", isOn: $question.isIncluded)
                    .font(.subheadline.bold())
                    .tint(LearnAlertStyle.indigo)

                Spacer()

                Button(isEditing ? "Done" : "Edit") {
                    withAnimation(.snappy) { isEditing.toggle() }
                }
                .font(.subheadline.bold())

                Button(role: .destructive, action: delete) {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Delete generated question")
            }

            if isEditing {
                GeneratedQuestionEditor(question: $question)
            } else {
                GeneratedQuestionPreview(question: question)
            }
        }
        .padding(18)
        .nativeGlass(cornerRadius: 14)
        .opacity(question.isIncluded ? 1 : 0.58)
    }
}

private struct GeneratedQuestionPreview: View {
    let question: EditableGeneratedQuestion

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(question.question)
                .font(.headline)
                .foregroundStyle(LearnAlertStyle.textPrimary)

            ForEach(question.answers) { answer in
                HStack(spacing: 10) {
                    Image(systemName: answer.id == question.correctAnswerID ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(answer.id == question.correctAnswerID ? LearnAlertStyle.green : LearnAlertStyle.textSecondary)
                    Text(answer.text)
                        .font(.subheadline)
                        .foregroundStyle(LearnAlertStyle.textPrimary)
                    Spacer()
                }
                .padding(11)
                .background(answer.id == question.correctAnswerID ? LearnAlertStyle.green.opacity(0.14) : Color.white.opacity(0.42))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            if !question.hint.isEmpty {
                Label(question.hint, systemImage: "lightbulb.fill")
                    .font(.footnote)
                    .foregroundStyle(LearnAlertStyle.textSecondary)
            }

            if !question.explanation.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("EXPLANATION")
                        .font(.caption2.bold())
                    Text(question.explanation)
                        .font(.footnote)
                }
                .foregroundStyle(LearnAlertStyle.textSecondary)
            }
        }
    }
}

private struct GeneratedQuestionEditor: View {
    @Binding var question: EditableGeneratedQuestion

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Question", text: $question.question, axis: .vertical)
                .font(.headline)
                .lineLimit(2...5)

            ForEach($question.answers) { $answer in
                HStack(spacing: 10) {
                    Button {
                        question.correctAnswerID = answer.id
                    } label: {
                        Image(systemName: answer.id == question.correctAnswerID ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(answer.id == question.correctAnswerID ? LearnAlertStyle.green : LearnAlertStyle.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Mark as correct answer")

                    TextField("Answer", text: $answer.text)
                        .font(.subheadline)
                }
                .padding(11)
                .background(Color.white.opacity(0.56))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            TextField("Hint", text: $question.hint, axis: .vertical)
                .lineLimit(1...3)
                .padding(11)
                .background(Color.white.opacity(0.56))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            TextField("Explanation", text: $question.explanation, axis: .vertical)
                .lineLimit(2...5)
                .padding(11)
                .background(Color.white.opacity(0.56))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .foregroundStyle(LearnAlertStyle.textPrimary)
    }
}

private extension String {
    var deletingPathExtension: String {
        (self as NSString).deletingPathExtension
    }
}
