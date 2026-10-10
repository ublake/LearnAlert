import PhotosUI
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

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

    // Image Support
    @State private var promptImage: UIImage?
    @State private var promptPhotoPickerItem: PhotosPickerItem?
    @State private var promptImageName: String?

    @State private var optionImages: [UIImage?] = [nil, nil, nil, nil]
    @State private var optionPhotoPickerItems: [PhotosPickerItem?] = [nil, nil, nil, nil]
    @State private var optionImageNames: [String] = []
    @State private var promptAudioName: String?
    @State private var showingAudioImporter = false
    @State private var audioError: String?
    @State private var didSave = false

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
        case .vocabulary, .tapReveal, .fillBlank:
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
                        .font(.custom("Poppins-Regular", size: 15))
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
            .onChange(of: promptPhotoPickerItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        await MainActor.run {
                            self.promptImage = uiImage
                        }
                    }
                }
            }
            .onChange(of: optionPhotoPickerItems) { _, newItems in
                for (index, item) in newItems.enumerated() {
                    if let item {
                        Task {
                            if let data = try? await item.loadTransferable(type: Data.self),
                               let uiImage = UIImage(data: data) {
                                await MainActor.run {
                                    if index < self.optionImages.count {
                                        self.optionImages[index] = uiImage
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .fileImporter(isPresented: $showingAudioImporter,
                          allowedContentTypes: [UTType(filenameExtension: "mp3"), UTType(filenameExtension: "m4a"), UTType(filenameExtension: "wav")].compactMap { $0 }) { result in
                do {
                    let source = try result.get()
                    let name = try CardAudioStore.importFile(source)
                    discardUnsavedAudio()
                    promptAudioName = name
                } catch { audioError = error.localizedDescription }
            }
            .alert("Audio Attachment", isPresented: Binding(get: { audioError != nil }, set: { if !$0 { audioError = nil } })) {
                Button("OK", role: .cancel) { }
            } message: { Text(audioError ?? "") }
            .onDisappear { if !didSave { discardUnsavedAudio() } }
        }
    }

    // MARK: - Type Picker
    private var typePicker: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Select Card Type")
                        .font(.custom("Poppins-SemiBold", size: 20, relativeTo: .title2))
                        .foregroundStyle(LearnAlertStyle.textPrimary)
                    Text("Choose how this card will appear in alerts & study.")
                        .font(.custom("Poppins-Regular", size: 13, relativeTo: .subheadline))
                        .foregroundStyle(LearnAlertStyle.textSecondary)
                }
                .padding(.top, 4)

                ForEach(FlashcardType.allCases) { type in
                    Button {
                        selectType(type)
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(typeColor(type).opacity(0.14))
                                    .frame(width: 44, height: 44)
                                Image(systemName: type.icon)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(typeColor(type))
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(type.title)
                                        .font(.custom("Poppins-SemiBold", size: 15))
                                        .foregroundStyle(LearnAlertStyle.textPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(LearnAlertStyle.textSecondary.opacity(0.6))
                                }
                                Text(typeDescription(type))
                                    .font(.custom("Poppins-Regular", size: 12))
                                    .foregroundStyle(LearnAlertStyle.textSecondary)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(2)
                            }
                        }
                        .padding(14)
                        .background(LearnAlertStyle.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(LearnAlertStyle.hairline, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
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
            VStack(spacing: 16) {
                // Sleek Type Banner (Without duplicate switch button)
                if let selectedType {
                    HStack(spacing: 8) {
                        Image(systemName: selectedType.icon)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(typeColor(selectedType))
                        Text(selectedType.title)
                            .font(.custom("Poppins-SemiBold", size: 12))
                            .foregroundStyle(typeColor(selectedType))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(typeColor(selectedType).opacity(0.08))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(typeColor(selectedType).opacity(0.2), lineWidth: 1))
                }

                // Core Form Content
                switch selectedType {
                case .vocabulary:
                    vocabularyEditor
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

                VStack(alignment: .leading, spacing: 8) {
                    Text("Audio (optional)")
                        .font(.headline)
                        .foregroundStyle(LearnAlertStyle.textPrimary)
                    Text("Attach a pronunciation, question, or explanation. MP3, M4A, or WAV up to 20 MB.")
                        .font(.subheadline)
                        .foregroundStyle(LearnAlertStyle.textSecondary)
                    HStack(spacing: 16) {
                        if let promptAudioName {
                            CardAudioPlaybackButton(name: promptAudioName)
                            Spacer()
                            Button("Remove", role: .destructive) {
                                discardUnsavedAudio()
                                self.promptAudioName = nil
                            }.frame(minHeight: 44)
                        } else {
                            Button { showingAudioImporter = true } label: {
                                Label("Attach audio", systemImage: "waveform.badge.plus")
                                    .frame(minHeight: 44)
                            }
                            .tint(LearnAlertStyle.indigo)
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LearnAlertStyle.surface, in: RoundedRectangle(cornerRadius: 16))

                // Hint (Optional - Hidden for Vocabulary)
                if selectedType != .vocabulary {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("HINT (OPTIONAL)")
                            .font(.custom("Poppins-SemiBold", size: 11))
                            .foregroundStyle(LearnAlertStyle.textSecondary)

                        TextField("A small clue...", text: $hint, axis: .vertical)
                            .lineLimit(1...2)
                            .font(.custom("Poppins-Regular", size: 14))
                            .foregroundStyle(LearnAlertStyle.textPrimary)
                            .glassCardField()
                    }
                    .padding(14)
                    .background(LearnAlertStyle.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(LearnAlertStyle.hairline, lineWidth: 1)
                    )
                }

                // Category Section (Optional)
                if !deck.sections.isEmpty {
                    HStack {
                        Text("Category")
                            .font(.custom("Poppins-Medium", size: 13))
                            .foregroundStyle(LearnAlertStyle.textSecondary)
                        Spacer()
                        Picker("Category", selection: $selectedSectionId) {
                            Text("None").tag("NONE")
                            ForEach(deck.sections.sorted { $0.orderIndex < $1.orderIndex }) { section in
                                Text(section.name).tag(section.id.uuidString)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(LearnAlertStyle.indigo)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(LearnAlertStyle.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(LearnAlertStyle.hairline, lineWidth: 1)
                    )
                }

                // Primary Action Button
                Button(action: saveCard) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 15, weight: .semibold))
                        Text(cardToEdit == nil ? "Save Card" : "Update Card")
                            .font(.custom("Poppins-SemiBold", size: 15))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
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
                        : AnyShapeStyle(Color.gray.opacity(0.25))
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(
                    color: isFormValid ? LearnAlertStyle.indigo.opacity(0.25) : Color.clear,
                    radius: 8,
                    y: 3
                )
                .disabled(!isFormValid)
                .padding(.top, 4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Vocabulary Editor
    private var vocabularyEditor: some View {
        VStack(alignment: .leading, spacing: 14) {
            PromptInputField(
                title: "TERM",
                placeholder: "Term or word",
                text: $question,
                axis: .vertical,
                lineLimit: 1...2,
                promptImage: $promptImage,
                promptImageName: $promptImageName,
                promptPhotoPickerItem: $promptPhotoPickerItem
            )

            VStack(alignment: .leading, spacing: 6) {
                Text("DEFINITION")
                    .font(.custom("Poppins-SemiBold", size: 11))
                    .foregroundStyle(LearnAlertStyle.textSecondary)

                TextField("Definition or explanation", text: $answer, axis: .vertical)
                    .lineLimit(2...4)
                    .font(.custom("Poppins-Regular", size: 14))
                    .foregroundStyle(LearnAlertStyle.textPrimary)
                    .glassCardField()
            }
        }
        .padding(16)
        .background(LearnAlertStyle.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(LearnAlertStyle.hairline, lineWidth: 1)
        )
    }

    // MARK: - Multiple Choice Editor
    private var multipleChoiceEditor: some View {
        VStack(spacing: 14) {
            // Question Field with embedded prompt photo picker
            VStack(alignment: .leading, spacing: 6) {
                PromptInputField(
                    title: "QUESTION",
                    placeholder: "Question prompt",
                    text: $question,
                    axis: .vertical,
                    lineLimit: 1...3,
                    promptImage: $promptImage,
                    promptImageName: $promptImageName,
                    promptPhotoPickerItem: $promptPhotoPickerItem
                )
            }
            .padding(14)
            .background(LearnAlertStyle.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(LearnAlertStyle.hairline, lineWidth: 1)
            )

            // Choices Section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("CHOICES")
                        .font(.custom("Poppins-SemiBold", size: 11))
                        .foregroundStyle(LearnAlertStyle.textSecondary)

                    Spacer()

                    // Compact segmented pills (never wraps on mini)
                    HStack(spacing: 4) {
                        ForEach(2...4, id: \.self) { count in
                            Button {
                                withAnimation(.snappy) {
                                    visibleOptionCount = count
                                    if correctOptionIndex >= count { correctOptionIndex = 0 }
                                }
                            } label: {
                                Text("\(count)")
                                    .font(.custom("Poppins-SemiBold", size: 12))
                                    .frame(width: 28, height: 26)
                                    .background(visibleOptionCount == count ? LearnAlertStyle.indigo : Color.primary.opacity(0.06))
                                    .foregroundStyle(visibleOptionCount == count ? Color.white : LearnAlertStyle.textPrimary)
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                VStack(spacing: 8) {
                    ForEach(0..<visibleOptionCount, id: \.self) { index in
                        HStack(spacing: 8) {
                            Button {
                                correctOptionIndex = index
                            } label: {
                                Image(systemName: correctOptionIndex == index ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 20))
                                    .foregroundStyle(correctOptionIndex == index ? Color.green : LearnAlertStyle.textSecondary.opacity(0.6))
                            }
                            .buttonStyle(.plain)

                            TextField("Choice \(index + 1)", text: $options[index])
                                .font(.custom("Poppins-Medium", size: 14))
                                .foregroundStyle(LearnAlertStyle.textPrimary)
                                .glassCardField()

                            PhotosPicker(
                                selection: Binding(
                                    get: { optionPhotoPickerItems[index] },
                                    set: { optionPhotoPickerItems[index] = $0 }
                                ),
                                matching: .images,
                                photoLibrary: .shared()
                            ) {
                                if let optImg = optionImages[index] {
                                    Image(uiImage: optImg)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 36, height: 36)
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .stroke(LearnAlertStyle.indigo, lineWidth: 1.5)
                                        )
                                } else {
                                    Image(systemName: "photo.badge.plus")
                                        .font(.system(size: 13))
                                        .foregroundStyle(LearnAlertStyle.textSecondary)
                                        .frame(width: 36, height: 36)
                                        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                                }
                            }
                            .buttonStyle(.plain)

                            if optionImages[index] != nil {
                                Button {
                                    optionImages[index] = nil
                                    optionPhotoPickerItems[index] = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Color.red.opacity(0.7))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Text("Tap the circle next to the correct answer.")
                    .font(.custom("Poppins-Regular", size: 11))
                    .foregroundStyle(LearnAlertStyle.textSecondary)
            }
            .padding(14)
            .background(LearnAlertStyle.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(LearnAlertStyle.hairline, lineWidth: 1)
            )
        }
    }

    // MARK: - Tap to Reveal Editor
    private var tapRevealEditor: some View {
        VStack(alignment: .leading, spacing: 14) {
            PromptInputField(
                title: "FRONT (PROMPT)",
                placeholder: "Question or prompt",
                text: $question,
                axis: .vertical,
                lineLimit: 1...3,
                promptImage: $promptImage,
                promptImageName: $promptImageName,
                promptPhotoPickerItem: $promptPhotoPickerItem
            )

            VStack(alignment: .leading, spacing: 6) {
                Text("BACK (REVEALED ANSWER)")
                    .font(.custom("Poppins-SemiBold", size: 11))
                    .foregroundStyle(LearnAlertStyle.textSecondary)

                TextField("Answer revealed on tap", text: $answer, axis: .vertical)
                    .lineLimit(2...4)
                    .font(.custom("Poppins-Regular", size: 14))
                    .foregroundStyle(LearnAlertStyle.textPrimary)
                    .glassCardField()
            }
        }
        .padding(16)
        .background(LearnAlertStyle.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(LearnAlertStyle.hairline, lineWidth: 1)
        )
    }

    // MARK: - Match Pairs Editor (Responsive for iPhone mini)
    private var matchingEditor: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                PromptInputField(
                    title: "PROMPT",
                    placeholder: "Match the correct pairs",
                    text: $question,
                    axis: .horizontal,
                    lineLimit: 1...1,
                    promptImage: $promptImage,
                    promptImageName: $promptImageName,
                    promptPhotoPickerItem: $promptPhotoPickerItem
                )
            }
            .padding(14)
            .background(LearnAlertStyle.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(LearnAlertStyle.hairline, lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("PAIRS")
                        .font(.custom("Poppins-SemiBold", size: 11))
                        .foregroundStyle(LearnAlertStyle.textSecondary)

                    Spacer()

                    // Compact segmented pills (never wraps on mini)
                    HStack(spacing: 4) {
                        ForEach(2...4, id: \.self) { count in
                            Button {
                                withAnimation(.snappy) { visiblePairCount = count }
                            } label: {
                                Text("\(count)")
                                    .font(.custom("Poppins-SemiBold", size: 12))
                                    .frame(width: 28, height: 26)
                                    .background(visiblePairCount == count ? LearnAlertStyle.indigo : Color.primary.opacity(0.06))
                                    .foregroundStyle(visiblePairCount == count ? Color.white : LearnAlertStyle.textPrimary)
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                VStack(spacing: 8) {
                    ForEach(0..<visiblePairCount, id: \.self) { index in
                        HStack(spacing: 6) {
                            TextField("Left item", text: $matchingLeft[index])
                                .font(.custom("Poppins-Medium", size: 13))
                                .foregroundStyle(LearnAlertStyle.textPrimary)
                                .glassCardField()

                            Image(systemName: "arrow.left.arrow.right")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(LearnAlertStyle.indigo)
                                .frame(width: 18)

                            TextField("Match", text: $matchingRight[index])
                                .font(.custom("Poppins-Medium", size: 13))
                                .foregroundStyle(LearnAlertStyle.textPrimary)
                                .glassCardField()
                        }
                    }
                }
            }
            .padding(14)
            .background(LearnAlertStyle.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(LearnAlertStyle.hairline, lineWidth: 1)
            )
        }
    }

    // MARK: - Fill in the Blank Editor
    private var fillBlankEditor: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("SENTENCE")
                        .font(.custom("Poppins-SemiBold", size: 11))
                        .foregroundStyle(LearnAlertStyle.textSecondary)
                    Spacer()
                    Button {
                        if !question.contains("___") {
                            if question.isEmpty {
                                question = "___"
                            } else {
                                question += " ___"
                            }
                        }
                    } label: {
                        Label("Insert Blank", systemImage: "plus.square.dashed")
                            .font(.custom("Poppins-SemiBold", size: 11))
                            .foregroundStyle(LearnAlertStyle.indigo)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(LearnAlertStyle.indigo.opacity(0.1), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }

                PromptInputField(
                    title: "",
                    placeholder: "Sentence with a ___ blank",
                    text: $question,
                    axis: .vertical,
                    lineLimit: 2...3,
                    promptImage: $promptImage,
                    promptImageName: $promptImageName,
                    promptPhotoPickerItem: $promptPhotoPickerItem
                )
            }
            .padding(14)
            .background(LearnAlertStyle.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(LearnAlertStyle.hairline, lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 6) {
                Text("TARGET ANSWER")
                    .font(.custom("Poppins-SemiBold", size: 11))
                    .foregroundStyle(LearnAlertStyle.textSecondary)

                TextField("Word that fills the blank", text: $answer)
                    .font(.custom("Poppins-Medium", size: 14))
                    .foregroundStyle(LearnAlertStyle.textPrimary)
                    .glassCardField()
            }
            .padding(14)
            .background(LearnAlertStyle.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(LearnAlertStyle.hairline, lineWidth: 1)
            )
        }
    }

    // MARK: - Helper Methods
    private func typeColor(_ type: FlashcardType) -> Color {
        switch type {
        case .vocabulary: LearnAlertStyle.cyan
        case .multipleChoice: LearnAlertStyle.indigo
        case .tapReveal: LearnAlertStyle.aqua
        case .matching: Color.purple
        case .fillBlank: Color.orange
        }
    }

    private func typeDescription(_ type: FlashcardType) -> String {
        switch type {
        case .vocabulary: "Key term & definition flashcard."
        case .multipleChoice: "Quiz question with 2–4 choices."
        case .tapReveal: "Active recall card: prompt & answer."
        case .matching: "Connect corresponding word pairs."
        case .fillBlank: "Type the missing word in the sentence."
        }
    }

    private func setupData() {
        guard let card = cardToEdit else { return }
        selectedType = card.cardType
        question = card.question
        answer = card.correctAnswer
        hint = card.hint
        selectedSectionId = card.section?.id.uuidString ?? "NONE"

        promptImageName = card.promptImageName
        promptAudioName = card.promptAudioName
        if let pName = card.promptImageName {
            promptImage = CardImageStore.loadImage(named: pName)
        }

        optionImageNames = card.optionImageNames
        for (idx, optName) in card.optionImageNames.enumerated() where idx < 4 {
            if !optName.isEmpty {
                optionImages[idx] = CardImageStore.loadImage(named: optName)
            }
        }

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

        // Process prompt image
        var finalPromptImageName: String? = promptImageName
        if let promptImage {
            finalPromptImageName = CardImageStore.saveImage(promptImage, name: promptImageName)
        } else if cardToEdit?.promptImageName != nil {
            CardImageStore.deleteImage(named: cardToEdit?.promptImageName)
            finalPromptImageName = nil
        }

        // Process option images
        var finalOptionImageNames: [String] = []
        if selectedType == .multipleChoice {
            for index in 0..<visibleOptionCount {
                if let optImg = optionImages[index] {
                    let existingName = (index < optionImageNames.count) ? optionImageNames[index] : nil
                    if let saved = CardImageStore.saveImage(optImg, name: existingName) {
                        finalOptionImageNames.append(saved)
                    } else {
                        finalOptionImageNames.append("")
                    }
                } else {
                    finalOptionImageNames.append("")
                }
            }
        }

        let card = cardToEdit ?? Flashcard(
            question: finalQuestion,
            options: finalOptions,
            correctAnswer: finalAnswer,
            hint: hint.trimmingCharacters(in: .whitespacesAndNewlines),
            cardType: selectedType,
            matchingLeftItems: left,
            matchingRightItems: right,
            promptImageName: finalPromptImageName,
            optionImageNames: finalOptionImageNames
        )
        card.question = finalQuestion
        card.options = finalOptions
        card.correctAnswer = finalAnswer
        card.hint = hint.trimmingCharacters(in: .whitespacesAndNewlines)
        card.cardType = selectedType
        card.matchingLeftItems = left
        card.matchingRightItems = right
        card.promptImageName = finalPromptImageName
        card.optionImageNames = finalOptionImageNames
        card.promptAudioName = promptAudioName
        card.section = selectedSection
        if cardToEdit == nil { deck.cards.append(card) }
        try? context.save()
        didSave = true
        dismiss()
    }

    private func discardUnsavedAudio() {
        if let promptAudioName, promptAudioName != cardToEdit?.promptAudioName {
            CardAudioStore.delete(named: promptAudioName)
        }
    }
}

// MARK: - Prompt Input Field with Embedded Photo Picker
private struct PromptInputField: View {
    var title: String = ""
    let placeholder: String
    @Binding var text: String
    var axis: Axis = .vertical
    var lineLimit: ClosedRange<Int> = 1...3
    @Binding var promptImage: UIImage?
    @Binding var promptImageName: String?
    @Binding var promptPhotoPickerItem: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !title.isEmpty {
                Text(title)
                    .font(.custom("Poppins-SemiBold", size: 11))
                    .foregroundStyle(LearnAlertStyle.textSecondary)
            }

            VStack(spacing: 8) {
                HStack(alignment: .center, spacing: 8) {
                    TextField(placeholder, text: $text, axis: axis)
                        .lineLimit(lineLimit)
                        .font(.custom("Poppins-Medium", size: 15))
                        .foregroundStyle(LearnAlertStyle.textPrimary)

                    // Embedded Image Attachment Button / Thumbnail
                    PhotosPicker(
                        selection: $promptPhotoPickerItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        if let promptImage {
                            Image(uiImage: promptImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 32, height: 32)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(LearnAlertStyle.indigo, lineWidth: 1.5)
                                )
                        } else {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(LearnAlertStyle.textSecondary)
                                .frame(width: 32, height: 32)
                                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                    .buttonStyle(.plain)

                    if promptImage != nil {
                        Button {
                            promptImage = nil
                            promptImageName = nil
                            promptPhotoPickerItem = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.red.opacity(0.75))
                                .frame(width: 20, height: 32)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(LearnAlertStyle.surfaceOutline(darkOpacity: 0.35), lineWidth: 0.75)
                )

                // Inline Preview Strip when image is selected
                if let promptImage {
                    HStack(spacing: 8) {
                        Image(uiImage: promptImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 90)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(LearnAlertStyle.surfaceOutline(darkOpacity: 0.4), lineWidth: 0.75)
                            )
                        Spacer()
                    }
                    .padding(.top, 2)
                }
            }
        }
    }
}

// MARK: - Glass Field View Extension
private extension View {
    func glassCardField() -> some View {
        self
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.primary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(LearnAlertStyle.surfaceOutline(darkOpacity: 0.35), lineWidth: 0.75)
            )
    }
}
