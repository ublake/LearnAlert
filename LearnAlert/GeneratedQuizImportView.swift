import PDFKit
import PhotosUI
import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers

private struct PendingSourceUpload: Sendable, Equatable {
    let data: Data
    let name: String
    let mimeType: String
}

struct GeneratedQuizImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var decks: [Deck]

    private let sourceCharacterLimit = 50_000

    @State private var sourceText = ""
    @State private var sourceName = "Pasted Notes"
    @State private var pendingUpload: PendingSourceUpload?
    @State private var activeUpload: PendingSourceUpload?
    private let defaultMaxCards = 50
    @State private var generatedDeck: GeneratedDeck?
    @State private var selectedCardIDs: Set<String> = []
    @State private var assistantMessage = ""
    @State private var chatHistory: [DeckChatMessage] = []
    @State private var chatInput = ""
    @State private var isGenerating = false
    @State private var isRefining = false
    @State private var errorMessage: String?
    @State private var savedDeck: Deck?
    @State private var showsSavedDeck = false
    @State private var requestTask: Task<Void, Never>?
    @State private var isShowingReview = false
    @State private var showingFileImporter = false
    @State private var showingPhotoPicker = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var isReadingAttachment = false
    @State private var pdfAnalysisResult: PDFOutlineManager.AnalysisResult?
    @State private var pendingPDFTempURL: URL?
    @State private var showingPDFSectionPicker = false
    @State private var activeDiagnosticReport: AIDiagnosticReport?
    @State private var failedRequestReport: AIDiagnosticReport?
    @State private var failedRequestMessage: String?
    @State private var pendingUserMessage: DeckChatMessage?
    @State private var selectedChunkFolderTitle: String?
    @State private var showingOneDocumentAlert = false
    @State private var showingAlreadyCreatedAlert = false

    private var hasProcessedDocument: Bool {
        activeUpload != nil
    }

    private func resetChatSession() {
        requestTask?.cancel()
        isGenerating = false
        isRefining = false
        isReadingAttachment = false
        chatHistory = []
        chatInput = ""
        sourceText = ""
        sourceName = "Pasted Notes"
        pendingUpload = nil
        activeUpload = nil
        generatedDeck = nil
        selectedCardIDs = []
        assistantMessage = ""
        errorMessage = nil
        activeDiagnosticReport = nil
        failedRequestReport = nil
        failedRequestMessage = nil
        pendingUserMessage = nil
        selectedChunkFolderTitle = nil
        if let temp = pendingPDFTempURL {
            try? FileManager.default.removeItem(at: temp)
            pendingPDFTempURL = nil
        }
        pdfAnalysisResult = nil
        savedDeck = nil
        isShowingReview = false
    }

    private var isReviewing: Bool { isShowingReview && generatedDeck != nil }

    var body: some View {
        NavigationStack {
            ZStack {
                AIChatAtmosphereBackground()

                if isShowingReview, let deckBinding = generatedDeckBinding {
                    GeneratedDeckReviewContent(
                        deck: deckBinding,
                        selectedCardIDs: $selectedCardIDs,
                        assistantMessage: assistantMessage,
                        isDeckSaved: savedDeck != nil,
                        saveDeck: addDeck,
                        backToChat: {
                            if savedDeck != nil {
                                showingAlreadyCreatedAlert = true
                            } else {
                                isShowingReview = false
                            }
                        }
                    )
                } else {
                    AIImportConversationView(
                        pendingUploadName: pendingUpload?.name,
                        messages: chatHistory,
                        messageText: $chatInput,
                        pendingUserMessage: pendingUserMessage,
                        failedRequestReport: failedRequestReport,
                        failedRequestMessage: failedRequestMessage,
                        onDismissError: {
                            failedRequestReport = nil
                            failedRequestMessage = nil
                        },
                        isWorking: isGenerating || isRefining,
                        isReadingAttachment: isReadingAttachment,
                        generatedDeck: generatedDeckBinding,
                        assistantMessage: assistantMessage,
                        chooseDocument: {
                            if hasProcessedDocument {
                                showingOneDocumentAlert = true
                            } else {
                                showingFileImporter = true
                            }
                        },
                        choosePhotos: {
                            if hasProcessedDocument {
                                showingOneDocumentAlert = true
                            } else {
                                showingPhotoPicker = true
                            }
                        },
                        removeUpload: { 
                            pendingUpload = nil
                            if let temp = pendingPDFTempURL {
                                try? FileManager.default.removeItem(at: temp)
                                pendingPDFTempURL = nil
                            }
                            pdfAnalysisResult = nil
                            if !hasProcessedDocument {
                                activeUpload = nil
                            }
                        },
                        send: sendMessage,
                        selectSuggestion: selectSuggestion,
                        review: { isShowingReview = true },
                        viewDiagnostics: { report in
                            activeDiagnosticReport = report
                        }
                    )
                }
            }
            .navigationTitle(isReviewing ? "Review Deck" : "Generate Deck")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if isReviewing {
                        if savedDeck != nil {
                            Button("Done") {
                                dismiss()
                            }
                            .font(.custom("Poppins-SemiBold", size: 15))
                            .foregroundStyle(LearnAlertStyle.indigo)
                        } else {
                            Button("Chat", systemImage: "chevron.backward") {
                                isShowingReview = false
                            }
                        }
                    } else {
                        Button("Cancel") {
                            requestTask?.cancel()
                            dismiss()
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if isReviewing, generatedDeck != nil {
                    Button(action: addDeck) {
                        Label(
                            savedDeck != nil ? "Deck Added to Library" : (selectedCardIDs.count == 1 ? "Add Deck with 1 Card" : "Add Deck with \(selectedCardIDs.count) Cards"),
                            systemImage: savedDeck != nil ? "checkmark.circle.fill" : "rectangle.stack.badge.plus"
                        )
                        .font(.headline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                    }
                    .foregroundStyle(.white)
                    .background(savedDeck != nil ? Color.green.opacity(0.8) : (selectedCardIDs.isEmpty ? Color.gray : LearnAlertStyle.indigo))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .disabled(selectedCardIDs.isEmpty || showsSavedDeck || isRefining || savedDeck != nil)
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .nativeGlass(cornerRadius: 0)
                }
            }

            .navigationDestination(isPresented: $showsSavedDeck) {
                if let savedDeck {
                    DeckDetailView(deck: savedDeck)
                }
            }
            .fileImporter(
                isPresented: $showingFileImporter,
                allowedContentTypes: [.pdf, .plainText, .image]
            ) { result in
                importDocument(result)
            }
            .photosPicker(
                isPresented: $showingPhotoPicker,
                selection: $selectedPhotos,
                maxSelectionCount: 1,
                matching: .images
            )
            .onChange(of: selectedPhotos) { _, photos in
                guard !photos.isEmpty else { return }
                importPhotos(photos)
            }
            .sheet(item: $activeDiagnosticReport) { report in
                AIDiagnosticInspectorSheet(report: report)
            }
            .alert("Only One Document Per Chat", isPresented: $showingOneDocumentAlert) {
                Button("Start New Chat") {
                    withAnimation(.snappy) {
                        resetChatSession()
                    }
                }
                Button("OK", role: .cancel) { }
            } message: {
                Text("Only one document or image can be used per chat session. To study another document, please start a new chat session.")
            }
            .alert("Deck Already Created", isPresented: $showingAlreadyCreatedAlert) {
                Button("Start New Chat") {
                    withAnimation(.snappy) {
                        resetChatSession()
                    }
                }
                Button("OK", role: .cancel) { }
            } message: {
                Text("This deck has already been created and added to your library. To generate more cards or create another deck, please start a new chat session.")
            }
            .sheet(isPresented: $showingPDFSectionPicker) {
                if let result = pdfAnalysisResult {
                    PDFSectionPickerSheet(
                        document: result.document,
                        sections: result.sections,
                        sourceName: sourceName,
                        detectionMethod: result.method,
                        onConfirm: { subsetData, formattedName, folderTitle in
                            pendingUpload = PendingSourceUpload(
                                data: subsetData,
                                name: formattedName.hasSuffix(".pdf") ? formattedName : "\(formattedName).pdf",
                                mimeType: "application/pdf"
                            )
                            sourceName = formattedName
                            selectedChunkFolderTitle = folderTitle
                            showingPDFSectionPicker = false
                            if let temp = pendingPDFTempURL {
                                try? FileManager.default.removeItem(at: temp)
                                pendingPDFTempURL = nil
                            }
                            pdfAnalysisResult = nil
                        },
                        onCancel: {
                            showingPDFSectionPicker = false
                            if let temp = pendingPDFTempURL {
                                try? FileManager.default.removeItem(at: temp)
                                pendingPDFTempURL = nil
                            }
                            pdfAnalysisResult = nil
                        }
                    )
                }
            }
        }
        .onDisappear { requestTask?.cancel() }
    }

    private var generatedDeckBinding: Binding<GeneratedDeck>? {
        guard let currentDeck = generatedDeck else { return nil }
        return Binding(
            get: { generatedDeck ?? currentDeck },
            set: { generatedDeck = $0 }
        )
    }

    private func sendMessage() {
        if savedDeck != nil {
            showingAlreadyCreatedAlert = true
            return
        }
        guard !isGenerating && !isRefining && !isReadingAttachment else { return }
        if generatedDeck == nil {
            generateDeck()
        } else {
            refineDeck()
        }
    }

    private func selectSuggestion(_ suggestion: String) {
        if savedDeck != nil {
            showingAlreadyCreatedAlert = true
            return
        }
        guard !isGenerating && !isRefining && !isReadingAttachment else { return }
        InteractionSoundPlayer.shared.play(.selection)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        chatInput = suggestion
        sendMessage()
    }

    private func generateDeck() {
        guard !isGenerating else { return }
        let message = chatInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveUpload = pendingUpload ?? activeUpload
        guard effectiveUpload != nil || !message.isEmpty else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                chatHistory.append(DeckChatMessage(
                    role: "assistant",
                    content: "Please paste notes or attach a document or photo first."
                ))
            }
            return
        }
        let isInitialAttachmentTurn = (pendingUpload != nil)
        if pendingUpload != nil {
            activeUpload = pendingUpload
            pendingUpload = nil
        }
        let upload = activeUpload
        let userMessage = message.isEmpty
            ? "Create a deck from this material."
            : message

        let originalInput = chatInput
        chatInput = ""
        failedRequestReport = nil
        failedRequestMessage = nil
        InteractionSoundPlayer.shared.play(.sentTo)
        isGenerating = true

        let pending = DeckChatMessage(
            role: "user",
            content: userMessage,
            displayAttachmentName: isInitialAttachmentTurn ? upload?.name : nil
        )
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            pendingUserMessage = pending
        }

        let currentHistory = chatHistory

        requestTask = Task {
            defer { isGenerating = false }
            do {
                let result: GeneratedDeckResult
                if let upload {
                    result = try await LearnAlertAPI().generateDeck(
                        fileData: upload.data,
                        fileName: upload.name,
                        mimeType: upload.mimeType,
                        maxCards: defaultMaxCards,
                        mode: "auto",
                        userInstruction: message,
                        chatHistory: currentHistory
                    )
                } else {
                    sourceText = sourceText.isEmpty ? message : sourceText
                    sourceName = "Pasted Notes"
                    result = try await LearnAlertAPI().generateDeck(
                        text: sourceText,
                        sourceName: sourceName,
                        maxCards: defaultMaxCards,
                        mode: "auto",
                        userInstruction: message,
                        chatHistory: currentHistory
                    )
                }
                try Task.checkCancellation()

                // 2xx and decoded successfully! Commit user message and assistant reply to chatHistory
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    chatHistory.append(pending)
                    pendingUserMessage = nil
                }

                if let deck = result.deck {
                    assistantMessage = result.assistantMessage
                    generatedDeck = deck
                    selectedCardIDs = Set(deck.cards.map(\.id))
                    
                    if !result.assistantMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            chatHistory.append(
                                DeckChatMessage(role: "assistant", content: result.assistantMessage)
                            )
                        }
                    }
                } else if !result.assistantMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        chatHistory.append(
                            DeckChatMessage(role: "assistant", content: result.assistantMessage)
                        )
                    }
                }
                InteractionSoundPlayer.shared.play(.receiveFrom)
            } catch is CancellationError {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    pendingUserMessage = nil
                }
                chatInput = originalInput
                return
            } catch {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    pendingUserMessage = nil
                }
                chatInput = originalInput
                let errorDesc = (error as? LocalizedError)?.errorDescription
                    ?? "I had trouble processing that request. Please try again or rephrase your question."
                let diag = (error as? LearnAlertAPIError)?.diagnosticReport
                failedRequestMessage = errorDesc
                failedRequestReport = diag
                InteractionSoundPlayer.shared.play(.receiveFrom)
            }
        }
    }

    private func refineDeck() {
        guard !isRefining,
              let currentDeck = generatedDeck else { return }
        let instruction = chatInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !instruction.isEmpty else { return }

        let originalInput = chatInput
        chatInput = ""
        failedRequestReport = nil
        failedRequestMessage = nil
        isRefining = true

        let pending = DeckChatMessage(role: "user", content: instruction)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            pendingUserMessage = pending
        }

        InteractionSoundPlayer.shared.play(.sentTo)

        let backendHistory = Array(chatHistory.dropFirst())

        requestTask = Task {
            defer { isRefining = false }
            do {
                let result = try await LearnAlertAPI().refineTextDeck(
                    instruction: instruction,
                    maxCards: defaultMaxCards,
                    sourceName: sourceName,
                    sourceText: sourceText,
                    deck: currentDeck,
                    chatHistory: backendHistory
                )
                try Task.checkCancellation()

                // 2xx and decoded successfully! Commit user message and assistant reply to chatHistory
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    chatHistory.append(pending)
                    pendingUserMessage = nil
                }

                if let refinedDeck = result.deck {
                    generatedDeck = refinedDeck
                    selectedCardIDs = Set(refinedDeck.cards.map(\.id))
                    if result.action != "chat" {
                        assistantMessage = result.assistantMessage
                    }
                }
                if !result.assistantMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        chatHistory.append(
                            DeckChatMessage(role: "assistant", content: result.assistantMessage)
                        )
                    }
                }
                InteractionSoundPlayer.shared.play(.receiveFrom)
            } catch is CancellationError {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    pendingUserMessage = nil
                }
                chatInput = originalInput
                return
            } catch {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    pendingUserMessage = nil
                }
                chatInput = originalInput
                let errorDesc = (error as? LocalizedError)?.errorDescription
                    ?? "I had trouble updating the deck. Please try again or rephrase your request."
                let diag = (error as? LearnAlertAPIError)?.diagnosticReport
                failedRequestMessage = errorDesc
                failedRequestReport = diag
                InteractionSoundPlayer.shared.play(.receiveFrom)
            }
        }
    }

    private func importDocument(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else {
            let diag = AIDiagnosticReport(
                endpoint: "File Import",
                requestMethod: "LOCAL",
                httpStatusCode: nil,
                httpStatusText: "File Selection Error",
                errorCode: "FILE_IMPORT_ERROR",
                userFriendlySummary: "The document could not be opened from the system file picker.",
                technicalError: "Security-scoped URL access failed or file selection was cancelled.",
                suggestedFix: "Ensure the file exists in iCloud Drive or on device and is a supported PDF, TXT, or image."
            )
            chatHistory.append(DeckChatMessage(role: "assistant", content: "⚠️ The selected file couldn’t be opened.", diagnosticReport: diag))
            return
        }
        if hasProcessedDocument {
            showingOneDocumentAlert = true
            return
        }
        if let oldTemp = pendingPDFTempURL {
            try? FileManager.default.removeItem(at: oldTemp)
            pendingPDFTempURL = nil
        }
        pdfAnalysisResult = nil
        isReadingAttachment = true
        requestTask = Task { @MainActor in
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer {
                if hasAccess { url.stopAccessingSecurityScopedResource() }
                isReadingAttachment = false
            }
            do {
                let data = try Data(contentsOf: url)
                let contentType = UTType(filenameExtension: url.pathExtension)
                if contentType?.conforms(to: .image) == true {
                    pendingUpload = try preparedImageUpload(
                        data: data,
                        name: url.lastPathComponent,
                        mimeType: contentType?.preferredMIMEType
                    )
                    sourceName = url.lastPathComponent
                } else if contentType?.conforms(to: .pdf) == true || url.pathExtension.lowercased() == "pdf" {
                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".pdf")
                    try data.write(to: tempURL)

                    do {
                        let analysis = try await PDFOutlineManager.analyzePDF(
                            url: tempURL,
                            sourceName: (url.lastPathComponent as NSString).deletingPathExtension
                        )
                        if analysis.document.pageCount <= 1 {
                            pendingUpload = PendingSourceUpload(
                                data: data,
                                name: url.lastPathComponent,
                                mimeType: "application/pdf"
                            )
                            sourceName = url.lastPathComponent
                            try? FileManager.default.removeItem(at: tempURL)
                        } else {
                            sourceName = url.lastPathComponent
                            pendingPDFTempURL = tempURL
                            pdfAnalysisResult = analysis
                            showingPDFSectionPicker = true
                        }
                    } catch {
                        try? FileManager.default.removeItem(at: tempURL)
                        let msg = (error as? LocalizedError)?.errorDescription ?? "The selected PDF couldn't be analyzed."
                        let diag = AIDiagnosticReport(
                            endpoint: "PDF Analysis",
                            requestMethod: "LOCAL",
                            httpStatusCode: nil,
                            httpStatusText: "PDF Read Failure",
                            errorCode: "PDF_ERROR",
                            userFriendlySummary: msg,
                            technicalError: error.localizedDescription,
                            suggestedFix: "Ensure the PDF is not encrypted or password-protected, and has readable pages."
                        )
                        chatHistory.append(DeckChatMessage(role: "assistant", content: "⚠️ \(msg)", diagnosticReport: diag))
                    }
                } else {
                    pendingUpload = PendingSourceUpload(
                        data: data,
                        name: url.lastPathComponent,
                        mimeType: contentType?.preferredMIMEType ?? "application/octet-stream"
                    )
                    sourceName = url.lastPathComponent
                }
            } catch {
                let msg = (error as? LocalizedError)?.errorDescription ?? "The selected document couldn’t be read."
                let diag = AIDiagnosticReport(
                    endpoint: "Local File Reading",
                    requestMethod: "LOCAL",
                    httpStatusCode: nil,
                    httpStatusText: "File Read Failure",
                    errorCode: "FILE_READ_ERROR",
                    userFriendlySummary: "The system could not read the binary data of the selected file.",
                    technicalError: error.localizedDescription,
                    suggestedFix: "Ensure the file is downloaded locally and not offloaded to iCloud."
                )
                chatHistory.append(DeckChatMessage(role: "assistant", content: "⚠️ \(msg)", diagnosticReport: diag))
            }
        }
    }

    private func importPhotos(_ photos: [PhotosPickerItem]) {
        if hasProcessedDocument {
            showingOneDocumentAlert = true
            return
        }
        if let oldTemp = pendingPDFTempURL {
            try? FileManager.default.removeItem(at: oldTemp)
            pendingPDFTempURL = nil
        }
        pdfAnalysisResult = nil
        isReadingAttachment = true
        requestTask = Task {
            defer {
                selectedPhotos = []
                isReadingAttachment = false
            }
            do {
                for (index, photo) in photos.enumerated() {
                    guard let data = try await photo.loadTransferable(type: Data.self) else { continue }
                    let contentType = photo.supportedContentTypes.first { $0.preferredMIMEType != nil }
                    let originalName = "Photo \(index + 1).\(contentType?.preferredFilenameExtension ?? "jpg")"
                    pendingUpload = try preparedImageUpload(
                        data: data,
                        name: originalName,
                        mimeType: contentType?.preferredMIMEType
                    )
                    sourceName = pendingUpload?.name ?? originalName
                }
            } catch {
                let msg = (error as? LocalizedError)?.errorDescription ?? "Text couldn’t be read from that photo."
                let diag = AIDiagnosticReport(
                    endpoint: "Photo Import",
                    requestMethod: "LOCAL",
                    httpStatusCode: nil,
                    httpStatusText: "Photo Processing Failure",
                    errorCode: "PHOTO_READ_ERROR",
                    userFriendlySummary: "Unable to process the selected image from Photos library.",
                    technicalError: error.localizedDescription,
                    suggestedFix: "Try selecting a standard JPEG or PNG image."
                )
                chatHistory.append(DeckChatMessage(role: "assistant", content: "⚠️ \(msg)", diagnosticReport: diag))
            }
        }
    }

    private func preparedImageUpload(data: Data, name: String, mimeType: String?) throws -> PendingSourceUpload {
        let directlySupportedTypes = ["image/jpeg", "image/png", "image/gif", "image/webp"]
        if let mimeType, directlySupportedTypes.contains(mimeType) {
            return PendingSourceUpload(data: data, name: name, mimeType: mimeType)
        }
        guard let image = UIImage(data: data), let jpegData = image.jpegData(compressionQuality: 0.9) else {
            throw SourceImportError.unsupportedImage
        }
        let jpegName = (name as NSString).deletingPathExtension + ".jpg"
        return PendingSourceUpload(data: jpegData, name: jpegName, mimeType: "image/jpeg")
    }

    private func addDeck() {
        guard savedDeck == nil else {
            showingAlreadyCreatedAlert = true
            return
        }
        guard let generatedDeck, !selectedCardIDs.isEmpty else { return }
        let color = DeckColorPalette.takeNextColor(existingColors: decks.map(\.colorHex))
        let deck = Deck(
            name: generatedDeck.title,
            colorHex: color,
            deckType: generatedDeck.deckKind,
            orderIndex: decks.count
        )
        deck.sourceName = activeUpload?.name ?? (sourceName.isEmpty ? nil : sourceName)
        deck.sourceText = sourceText.isEmpty ? nil : sourceText
        deck.documentCoverageSummary = assistantMessage
        deck.chatHistory = chatHistory

        context.insert(deck)

        for card in generatedDeck.cards where selectedCardIDs.contains(card.id) {
            let options = card.type == .multipleChoice ? card.options : []
            let correctAnswer: String
            if card.type == .multipleChoice, options.indices.contains(card.correctAnswerIndex) {
                correctAnswer = options[card.correctAnswerIndex]
            } else {
                correctAnswer = card.answer
            }
            let newCard = Flashcard(
                question: card.prompt.trimmingCharacters(in: .whitespacesAndNewlines),
                options: options,
                correctAnswer: correctAnswer.trimmingCharacters(in: .whitespacesAndNewlines),
                hint: card.hint.trimmingCharacters(in: .whitespacesAndNewlines),
                cardType: FlashcardType(rawValue: card.type.rawValue),
                matchingLeftItems: card.matchingPairs?.map(\.left) ?? [],
                matchingRightItems: card.matchingPairs?.map(\.right) ?? [],
                sourceLocator: card.sourceLocator.isEmpty ? nil : card.sourceLocator,
                sourceExcerpt: card.sourceExcerpt.isEmpty ? nil : card.sourceExcerpt,
                tags: card.tags
            )
            deck.cards.append(newCard)

            if let folderTitle = selectedChunkFolderTitle, !folderTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                deck.assignCardToSection(card: newCard, suggestedCategory: folderTitle)
            }
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

private enum SourceImportError: LocalizedError {
    case unsupportedImage

    var errorDescription: String? {
        "That photo format couldn’t be prepared for upload."
    }
}

private struct AIChatAtmosphereBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            // Deep dark obsidian canvas matching the rest of the dark UI
            (colorScheme == .dark
                ? Color(red: 0.055, green: 0.065, blue: 0.11)
                : Color(red: 0.96, green: 0.97, blue: 0.99))
                .ignoresSafeArea()

            // Atmospheric glowing color orbs (keeps vibrant color without overpowering the dark UI)
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height

                // Top right soft indigo glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                LearnAlertStyle.indigo.opacity(colorScheme == .dark ? 0.38 : 0.18),
                                LearnAlertStyle.indigo.opacity(0.0)
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 200
                        )
                    )
                    .frame(width: w * 0.95, height: w * 0.95)
                    .position(x: w * 0.85, y: h * 0.12)
                    .blur(radius: 40)

                // Middle left deep violet glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.52, green: 0.22, blue: 0.78).opacity(colorScheme == .dark ? 0.28 : 0.12),
                                Color(red: 0.52, green: 0.22, blue: 0.78).opacity(0.0)
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 180
                        )
                    )
                    .frame(width: w * 0.85, height: w * 0.85)
                    .position(x: w * 0.12, y: h * 0.46)
                    .blur(radius: 45)

                // Bottom right subtle cyan/aqua glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                LearnAlertStyle.aqua.opacity(colorScheme == .dark ? 0.22 : 0.10),
                                LearnAlertStyle.aqua.opacity(0.0)
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 160
                        )
                    )
                    .frame(width: w * 0.8, height: w * 0.8)
                    .position(x: w * 0.82, y: h * 0.82)
                    .blur(radius: 40)
            }
            .ignoresSafeArea()
        }
    }
}

private struct AIImportConversationView: View {
    let pendingUploadName: String?
    let messages: [DeckChatMessage]
    @Binding var messageText: String
    var pendingUserMessage: DeckChatMessage? = nil
    var failedRequestReport: AIDiagnosticReport? = nil
    var failedRequestMessage: String? = nil
    var onDismissError: (() -> Void)? = nil
    let isWorking: Bool
    let isReadingAttachment: Bool
    let generatedDeck: Binding<GeneratedDeck>?
    let assistantMessage: String
    let chooseDocument: () -> Void
    let choosePhotos: () -> Void
    let removeUpload: () -> Void
    let send: () -> Void
    let selectSuggestion: (String) -> Void
    let review: () -> Void
    var viewDiagnostics: ((AIDiagnosticReport) -> Void)? = nil

    @State private var isDeckCondensed: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 14) {
                        AIWelcomeBubble()
                        ForEach(messages) { message in
                            ConversationBubble(
                                message: message,
                                onSelectSuggestion: isWorking ? nil : selectSuggestion,
                                onViewDiagnostics: viewDiagnostics
                            )
                            .id(message.id)
                        }
                        if let pending = pendingUserMessage {
                            ConversationBubble(
                                message: pending,
                                onSelectSuggestion: nil,
                                onViewDiagnostics: nil
                            )
                            .id("pending_user_message")
                        }
                        if isReadingAttachment {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(LearnAlertStyle.indigo)
                                Text("Analyzing PDF document structure...")
                                    .font(.custom("Poppins-Medium", size: 12))
                                    .foregroundStyle(Color.white.opacity(0.8))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Capsule())
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if isWorking {
                            AIProcessingBubble()
                                .id("ai_processing")
                        }
                        if let generatedDeck {
                            GeneratedDeckReadyBubble(
                                deck: generatedDeck,
                                assistantMessage: assistantMessage,
                                hasAssistantMessages: messages.contains { $0.role == "assistant" },
                                isCondensed: $isDeckCondensed,
                                review: review
                            )
                            .id("deck_ready")
                        }
                    }
                    .padding(20)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: messages.count) { _, _ in
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        if let lastId = messages.last?.id {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: pendingUserMessage?.id) { _, pendingId in
                    if pendingId != nil {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            if generatedDeck != nil {
                                isDeckCondensed = true
                            }
                            proxy.scrollTo("pending_user_message", anchor: .bottom)
                        }
                    }
                }
                .onChange(of: isWorking) { oldWorking, newWorking in
                    if newWorking {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            proxy.scrollTo("ai_processing", anchor: .bottom)
                        }
                    } else if oldWorking && generatedDeck != nil {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            isDeckCondensed = false
                            proxy.scrollTo("deck_ready", anchor: .bottom)
                        }
                    }
                }
                .onChange(of: generatedDeck?.wrappedValue) { oldDeck, newDeck in
                    if newDeck != nil && newDeck != oldDeck {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            isDeckCondensed = false
                            proxy.scrollTo("deck_ready", anchor: .bottom)
                        }
                    }
                }
            }

            if let failedReport = failedRequestReport {
                VStack(spacing: 0) {
                    HStack(alignment: .center, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.orange)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(failedRequestMessage ?? failedReport.technicalError)
                                .font(.custom("Poppins-Medium", size: 12))
                                .foregroundStyle(Color.white)
                                .lineLimit(2)
                        }

                        Spacer()

                        Button {
                            viewDiagnostics?(failedReport)
                        } label: {
                            HStack(spacing: 4) {
                                Text("View Error Diagnostics")
                                    .font(.custom("Poppins-SemiBold", size: 11))
                                if let code = failedReport.httpStatusCode {
                                    Text("HTTP \(code)")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                }
                            }
                            .foregroundStyle(Color.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.orange.opacity(0.18), in: Capsule())
                        }
                        .buttonStyle(.plain)

                        Button {
                            onDismissError?()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.white.opacity(0.45))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(red: 0.12, green: 0.08, blue: 0.08).opacity(0.95))
                    .overlay(
                        Rectangle()
                            .frame(height: 1)
                            .foregroundStyle(Color.orange.opacity(0.35)),
                        alignment: .top
                    )
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            SourceComposer(
                messageText: $messageText,
                hasGeneratedDeck: generatedDeck != nil,
                pendingUploadName: pendingUploadName,
                isWorking: isWorking,
                isReadingAttachment: isReadingAttachment,
                chooseDocument: chooseDocument,
                choosePhotos: choosePhotos,
                removeUpload: removeUpload,
                send: send
            )

        }
    }
}

private struct ConversationBubble: View {
    let message: DeckChatMessage
    var onSelectSuggestion: ((String) -> Void)? = nil
    var onViewDiagnostics: ((AIDiagnosticReport) -> Void)? = nil

    var body: some View {
        VStack(alignment: message.role == "user" ? .trailing : .leading, spacing: 10) {
            HStack {
                if message.role == "user" { Spacer(minLength: 46) }
                VStack(alignment: message.role == "user" ? .trailing : .leading, spacing: 8) {
                    if let attachmentName = message.displayAttachmentName {
                        SentAttachmentPreview(name: attachmentName)
                    }
                    if !message.displayContent.isEmpty && (message.displayAttachmentName == nil || !message.displayContent.hasPrefix("Create a deck from")) {
                        AIMarkdownText(
                            text: message.displayContent,
                            size: 15,
                            color: .white,
                            lineSpacing: 2
                        )
                    }
                }
                .foregroundStyle(Color.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    message.role == "user"
                        ? AnyShapeStyle(
                            LinearGradient(
                                colors: [LearnAlertStyle.indigo, LearnAlertStyle.indigo.opacity(0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        : AnyShapeStyle(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.12),
                                    Color.white.opacity(0.04)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            message.role == "user"
                                ? AnyShapeStyle(Color.white.opacity(0.25))
                                : AnyShapeStyle(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.28),
                                            Color.white.opacity(0.08)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                ),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: message.role == "user"
                        ? LearnAlertStyle.indigo.opacity(0.30)
                        : Color.black.opacity(0.15),
                    radius: 8,
                    y: 3
                )
                if message.role != "user" { Spacer(minLength: 46) }
            }

            if message.role == "assistant" && (message.diagnosticReport != nil || message.content.hasPrefix("⚠️") || message.content.localizedCaseInsensitiveContains("couldn’t be read") || message.content.localizedCaseInsensitiveContains("couldn't be read")) {
                let report = message.diagnosticReport ?? AIDiagnosticReport.fallbackReport(for: message.content)
                Button {
                    onViewDiagnostics?(report)
                } label: {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color.orange.opacity(0.20))
                                .frame(width: 28, height: 28)
                            Image(systemName: "ladybug.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.orange)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("View Error Diagnostics")
                                    .font(.custom("Poppins-SemiBold", size: 12))
                                    .foregroundStyle(Color.white)
                                if let code = report.httpStatusCode {
                                    Text("HTTP \(code)")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundStyle(Color.orange)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(Color.orange.opacity(0.18), in: Capsule())
                                }
                            }

                            Text("Inspect exact server response, failed schema path & raw JSON")
                                .font(.custom("Poppins-Regular", size: 10))
                                .foregroundStyle(Color.white.opacity(0.70))
                        }

                        Spacer(minLength: 4)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.45))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.orange.opacity(0.18), Color.red.opacity(0.10)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.orange.opacity(0.40), lineWidth: 1)
                    )
                }
                .buttonStyle(AIReviewActionButtonStyle())
                .padding(.leading, 4)
                .padding(.trailing, 24)
            }

            if message.role == "assistant" && !message.parsedSuggestions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(message.parsedSuggestions, id: \.self) { suggestion in
                        Button {
                            onSelectSuggestion?(suggestion)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(LearnAlertStyle.indigo)
                                Text(suggestion)
                                    .font(.custom("Poppins-Medium", size: 13, relativeTo: .subheadline))
                                    .foregroundStyle(Color.white.opacity(0.95))
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 4)
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color.white.opacity(0.40))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                LearnAlertStyle.indigo.opacity(0.22),
                                                Color.white.opacity(0.06)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                LearnAlertStyle.indigo.opacity(0.50),
                                                Color.white.opacity(0.12)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                            .shadow(color: Color.black.opacity(0.15), radius: 4, y: 2)
                        }
                        .buttonStyle(AIReviewActionButtonStyle())
                        .disabled(onSelectSuggestion == nil)
                        .opacity(onSelectSuggestion == nil ? 0.45 : 1.0)
                    }
                }
                .padding(.leading, 4)
                .padding(.trailing, 24)
            }
        }
    }
}

private struct SentAttachmentPreview: View {
    let name: String

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: name.lowercased().hasSuffix(".pdf") ? "doc.richtext.fill" : "doc.fill")
                .font(.title2)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.white)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.custom("Poppins-SemiBold", size: 14, relativeTo: .subheadline))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                Text("Sent to LearnAlert AI")
                    .font(.custom("Poppins-Regular", size: 11, relativeTo: .caption2))
                    .foregroundStyle(Color.white.opacity(0.78))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Attached file, \(name)")
    }
}

private struct AIWelcomeBubble: View {
    @State private var showingPrivacy = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(LearnAlertStyle.indigo.opacity(0.20))
                    .frame(width: 34, height: 34)
                Image(systemName: "sparkles")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(LearnAlertStyle.indigo)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Send notes, text, PDFs, documents, or photos. I’ll build a deck you can review and refine.")
                    .font(.custom("Poppins-Regular", size: 13, relativeTo: .subheadline))
                    .foregroundStyle(Color.white.opacity(0.92))
                    .lineSpacing(2)

                Text("Please don’t send sensitive or personal info.")
                    .font(.custom("Poppins-Regular", size: 11, relativeTo: .caption))
                    .foregroundStyle(Color.white.opacity(0.60))

                Button {
                    showingPrivacy = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.shield.fill")
                        Text("How LearnAlert processes your data")
                    }
                    .font(.custom("Poppins-Medium", size: 11, relativeTo: .caption2))
                    .foregroundStyle(LearnAlertStyle.indigo)
                    .underline()
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 4)
        }
        .sheet(isPresented: $showingPrivacy) {
            NavigationStack {
                PrivacyPolicyView()
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Done") {
                                showingPrivacy = false
                            }
                            .font(.custom("Poppins-Medium", size: 15))
                            .foregroundStyle(LearnAlertStyle.indigo)
                        }
                    }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.11),
                            Color.white.opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.28),
                            Color.white.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.15), radius: 10, y: 4)
    }
}

private struct AIProcessingBubble: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack {
            TimelineView(.periodic(from: .now, by: 0.4)) { context in
                let activeDot = reduceMotion
                    ? 2
                    : Int(context.date.timeIntervalSinceReferenceDate / 0.4) % 3

                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(LearnAlertStyle.indigo)
                            .frame(width: 8, height: 8)
                            .opacity(index <= activeDot ? 1 : 0.28)
                    }
                }
                .frame(width: 38, height: 24)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.12),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                Capsule()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.30),
                                Color.white.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.15), radius: 8, y: 3)
            Spacer(minLength: 46)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("LearnAlert AI is responding")
    }
}

private struct GeneratedDeckReadyBubble: View {
    @Binding var deck: GeneratedDeck
    let assistantMessage: String
    var hasAssistantMessages: Bool = false
    @Binding var isCondensed: Bool
    let review: () -> Void
    @State private var isEditingTitle = false

    var body: some View {
        Group {
            if isCondensed {
                condensedView
            } else {
                expandedView
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isCondensed)
    }

    private var condensedView: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles.rectangle.stack.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(LearnAlertStyle.indigo)

            VStack(alignment: .leading, spacing: 2) {
                Text(deck.title)
                    .font(.custom("Poppins-SemiBold", size: 14))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text("\(deck.cards.count) cards generated")
                    .font(.custom("Poppins-Regular", size: 11))
                    .foregroundStyle(Color.white.opacity(0.72))
            }

            Spacer(minLength: 8)

            Button(action: review) {
                HStack(spacing: 4) {
                    Text("Review")
                        .font(.custom("Poppins-SemiBold", size: 12))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    LinearGradient(
                        colors: [LearnAlertStyle.indigo, LearnAlertStyle.indigo.opacity(0.85)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: Capsule()
                )
                .shadow(color: LearnAlertStyle.indigo.opacity(0.3), radius: 4, y: 1)
            }

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isCondensed = false
                }
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.70))
                    .padding(6)
                    .background(Color.white.opacity(0.10), in: Circle())
            }
            .accessibilityLabel("Expand deck overview")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.12), Color.white.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.20), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 8, y: 3)
    }

    private var expandedView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header Row: Title, Edit, and Collapse toggle
            HStack(alignment: .center) {
                if isEditingTitle {
                    TextField("Deck title", text: $deck.title)
                        .font(.custom("Poppins-SemiBold", size: 16))
                        .textFieldStyle(.roundedBorder)
                } else {
                    Text(deck.title)
                        .font(.custom("Poppins-SemiBold", size: 16))
                        .foregroundStyle(Color.white)
                        .lineLimit(1)
                }

                Spacer()

                Button(isEditingTitle ? "Done" : "Edit") {
                    isEditingTitle.toggle()
                }
                .font(.custom("Poppins-Medium", size: 12))
                .foregroundStyle(LearnAlertStyle.indigo)

                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isCondensed = true
                    }
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.70))
                        .padding(6)
                        .background(Color.white.opacity(0.10), in: Circle())
                }
                .accessibilityLabel("Collapse deck overview")
            }

            // Badges row
            HStack(spacing: 8) {
                Label("\(deck.cards.count) Flashcards", systemImage: "sparkles")
                    .font(.custom("Poppins-SemiBold", size: 11))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(LearnAlertStyle.indigo, in: Capsule())

                if !deck.subject.isEmpty {
                    Text(deck.subject)
                        .font(.custom("Poppins-Medium", size: 11))
                        .foregroundStyle(Color.white.opacity(0.80))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.10), in: Capsule())
                }
            }

            // Summary / Overview
            if !deck.summary.isEmpty {
                AIMarkdownText(
                    text: deck.summary,
                    size: 13,
                    color: Color.white.opacity(0.88),
                    lineSpacing: 2
                )
            } else if !hasAssistantMessages && !assistantMessage.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI Overview")
                        .font(.caption2.bold())
                        .foregroundStyle(LearnAlertStyle.indigo)

                    AIMarkdownText(
                        text: assistantMessage,
                        size: 13,
                        color: Color.white.opacity(0.90),
                        lineSpacing: 2
                    )
                }
                .padding(10)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
            }

            // Cards Preview List with Numbers
            if !deck.cards.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Cards (\(deck.cards.count))")
                            .font(.custom("Poppins-SemiBold", size: 12))
                            .foregroundStyle(Color.white.opacity(0.80))

                        Spacer()

                        Text("Numbered for chat edits")
                            .font(.custom("Poppins-Regular", size: 10))
                            .foregroundStyle(Color.white.opacity(0.50))
                    }

                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(Array(deck.cards.enumerated()), id: \.element.id) { index, card in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("#\(index + 1)")
                                        .font(.custom("Poppins-Bold", size: 11))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(LearnAlertStyle.indigo, in: RoundedRectangle(cornerRadius: 5))

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(card.prompt)
                                            .font(.custom("Poppins-Medium", size: 12))
                                            .foregroundStyle(Color.white.opacity(0.95))
                                            .lineLimit(2)

                                        Text(cardTypeTitle(for: card.type))
                                            .font(.custom("Poppins-Regular", size: 10))
                                            .foregroundStyle(Color.white.opacity(0.55))
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    .frame(maxHeight: 180)
                }
            }

            // Action button
            Button(action: review) {
                HStack(spacing: 6) {
                    Image(systemName: "rectangle.stack.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("Review Deck (\(deck.cards.count) Cards)")
                        .font(.custom("Poppins-SemiBold", size: 14))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    LinearGradient(
                        colors: [LearnAlertStyle.indigo, LearnAlertStyle.indigo.opacity(0.85)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: LearnAlertStyle.indigo.opacity(0.35), radius: 8, y: 3)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.12), Color.white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.28), Color.white.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.18), radius: 10, y: 4)
    }

    private func cardTypeTitle(for type: GeneratedCardType) -> String {
        switch type {
        case .matching: return "Matching Pairs"
        case .tapReveal: return "Tap Reveal"
        case .fillBlank: return "Fill in the Blank"
        case .multipleChoice: return "Multiple Choice"
        }
    }
}

private struct AIReviewActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.88 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

private struct SourceComposer: View {
    @Binding var messageText: String
    var hasGeneratedDeck: Bool = false
    let pendingUploadName: String?
    let isWorking: Bool
    let isReadingAttachment: Bool
    let chooseDocument: () -> Void
    let choosePhotos: () -> Void
    let removeUpload: () -> Void
    let send: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let pendingUploadName {
                HStack {
                    Label(pendingUploadName, systemImage: "paperclip")
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.90))
                        .lineLimit(1)
                    Spacer()
                    Button("Remove", role: .destructive, action: removeUpload)
                        .font(.caption.bold())
                        .foregroundStyle(Color.red.opacity(0.90))
                }
                .padding(.horizontal, 14)
                .frame(height: 38)
                .background(Color.white.opacity(0.12), in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.22), lineWidth: 1))
            }

            HStack(alignment: .bottom, spacing: 10) {
                Menu {
                    Button("Choose Document", systemImage: "doc") { chooseDocument() }
                    Button("Choose Photos", systemImage: "photo.on.rectangle") { choosePhotos() }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .liquidGlassCircle(interactive: true)
                }
                .accessibilityLabel("Add notes attachment")

                TextField(
                    "",
                    text: $messageText,
                    prompt: Text(hasGeneratedDeck ? "Ask a question or refine deck..." : "What are you studying?").foregroundStyle(Color.white.opacity(0.55)),
                    axis: .vertical
                )
                .lineLimit(1...8)
                .font(.custom("Poppins-Regular", size: 15))
                .foregroundStyle(.white)
                .tint(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .liquidGlassInput(cornerRadius: 22)
                .onChange(of: messageText) { _, text in
                    if text.count > 50_000 {
                        messageText = String(text.prefix(50_000))
                    }
                }

                Button(action: send) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(canSend ? Color.white : Color.white.opacity(0.35))
                        .frame(width: 44, height: 44)
                        .liquidGlassCircle(
                            interactive: canSend,
                            tint: canSend ? LearnAlertStyle.indigo : nil
                        )
                        .shadow(color: canSend ? LearnAlertStyle.indigo.opacity(0.35) : .clear, radius: 9, y: 4)
                }
                .disabled(!canSend)
                .accessibilityLabel("Generate deck")
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    private var canSend: Bool {
        let hasContent = pendingUploadName != nil
            || !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasContent && !isWorking && !isReadingAttachment
    }
}

private struct GeneratedDeckReviewContent: View {
    @Binding var deck: GeneratedDeck
    @Binding var selectedCardIDs: Set<String>
    let assistantMessage: String
    var isDeckSaved: Bool = false
    let saveDeck: () -> Void
    let backToChat: () -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                GeneratedDeckHeader(deck: $deck, assistantMessage: assistantMessage)
                ForEach($deck.cards) { $card in
                    let cardNumber = (deck.cards.firstIndex(where: { $0.id == card.id }) ?? 0) + 1
                    GeneratedCardReviewRow(
                        card: $card,
                        cardNumber: cardNumber
                    ) {
                        withAnimation(.snappy) {
                            selectedCardIDs.remove(card.id)
                            deck.cards.removeAll { $0.id == card.id }
                        }
                    }
                }

                // Review Footer
                VStack(spacing: 12) {
                    Button(action: saveDeck) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16, weight: .bold))
                            Text(isDeckSaved ? "Deck Added to Library" : "Save Deck (\(deck.cards.count) Cards)")
                                .font(.custom("Poppins-SemiBold", size: 16))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            isDeckSaved
                                ? LinearGradient(colors: [Color.green.opacity(0.85), Color.green.opacity(0.70)], startPoint: .leading, endPoint: .trailing)
                                : LinearGradient(colors: [LearnAlertStyle.indigo, LearnAlertStyle.indigo.opacity(0.85)], startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(Capsule())
                        .shadow(color: isDeckSaved ? Color.green.opacity(0.35) : LearnAlertStyle.indigo.opacity(0.35), radius: 10, y: 4)
                    }
                    .disabled(isDeckSaved)

                    Button(action: backToChat) {
                        HStack(spacing: 6) {
                            Image(systemName: isDeckSaved ? "plus.bubble.fill" : "sparkles")
                                .font(.system(size: 13, weight: .semibold))
                            Text(isDeckSaved ? "Start New AI Chat" : "Ask AI to Refine or Add More Cards")
                                .font(.custom("Poppins-Medium", size: 14))
                        }
                        .foregroundStyle(LearnAlertStyle.indigo)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                    }
                }
                .padding(.top, 10)
            }
            .padding(.horizontal)
            .padding(.top, 14)
            .padding(.bottom, 36)
        }
    }
}

private struct GeneratedDeckHeader: View {
    @Binding var deck: GeneratedDeck
    let assistantMessage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Generated deck title", text: $deck.title)
                .font(.title3.bold())
            if !deck.summary.isEmpty {
                Text(deck.summary)
                    .font(.subheadline)
                    .foregroundStyle(LearnAlertStyle.textSecondary)
            }
            if !assistantMessage.isEmpty {
                Label(assistantMessage, systemImage: "sparkles")
                    .font(.footnote)
                    .foregroundStyle(LearnAlertStyle.indigo)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.11),
                            Color.white.opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.28),
                            Color.white.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.15), radius: 10, y: 4)
    }
}

private struct GeneratedCardReviewRow: View {
    @Binding var card: GeneratedCard
    let cardNumber: Int
    let delete: () -> Void
    @State private var isEditing = false

    private var cardTypeTitle: String {
        switch card.type {
        case .matching: return "Matching Pairs"
        case .tapReveal: return "Tap Reveal"
        case .fillBlank: return "Fill in the Blank"
        case .multipleChoice: return "Multiple Choice"
        }
    }

    private var cardTypeIcon: String {
        switch card.type {
        case .matching: return "arrow.left.arrow.right"
        case .tapReveal: return "hand.tap"
        case .fillBlank: return "character.cursor.ibeam"
        case .multipleChoice: return "list.bullet"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text("#\(cardNumber)")
                    .font(.custom("Poppins-Bold", size: 11))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(LearnAlertStyle.indigo, in: RoundedRectangle(cornerRadius: 6))

                Label(cardTypeTitle, systemImage: cardTypeIcon)
                    .font(.caption.bold())
                    .foregroundStyle(card.type == .matching ? Color.purple : LearnAlertStyle.textSecondary)
                Spacer()
                Button(isEditing ? "Done" : "Edit") {
                    withAnimation(.snappy) { isEditing.toggle() }
                }
                .font(.subheadline.bold())
                Button(role: .destructive, action: delete) { Image(systemName: "trash") }
                    .accessibilityLabel("Delete generated card")
            }

            if isEditing {
                GeneratedCardEditor(card: $card)
            } else {
                GeneratedCardPreview(card: card)
            }
        }
        .padding(18)
        .clearGlassSurface(cornerRadius: 14)
    }
}

private struct GeneratedCardPreview: View {
    let card: GeneratedCard

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(card.prompt)
                .font(.headline)
                .foregroundStyle(LearnAlertStyle.textPrimary)

            if card.type == .multipleChoice {
                ForEach(card.options.enumerated(), id: \.offset) { index, option in
                    Label(option, systemImage: index == card.correctAnswerIndex ? "checkmark.circle.fill" : "circle")
                        .font(.subheadline)
                        .foregroundStyle(index == card.correctAnswerIndex ? LearnAlertStyle.green : LearnAlertStyle.textPrimary)
                }
            } else if card.type == .matching, let pairs = card.matchingPairs, !pairs.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(pairs.indices, id: \.self) { idx in
                        let pair = pairs[idx]
                        HStack(spacing: 8) {
                            Text(pair.left)
                                .font(.custom("Poppins-Medium", size: 12))
                                .foregroundStyle(LearnAlertStyle.textPrimary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                            Image(systemName: "arrow.left.arrow.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.purple)

                            Text(pair.right)
                                .font(.custom("Poppins-Medium", size: 12))
                                .foregroundStyle(Color.purple)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.purple.opacity(0.18))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                }
            } else {
                Label(card.answer, systemImage: "eye.fill")
                    .font(.subheadline)
                    .foregroundStyle(LearnAlertStyle.green)
            }

            if !card.hint.isEmpty {
                Label(card.hint, systemImage: "lightbulb.fill")
                    .font(.footnote)
                    .foregroundStyle(LearnAlertStyle.textSecondary)
            }

        }
    }
}

private struct GeneratedCardEditor: View {
    @Binding var card: GeneratedCard

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Prompt", text: $card.prompt, axis: .vertical)
                .lineLimit(2...6)
                .font(.headline)

            if card.type == .multipleChoice {
                TextField("Answer", text: $card.answer, axis: .vertical)
                    .lineLimit(1...5)

                ForEach(card.options.indices, id: \.self) { index in
                    HStack(spacing: 10) {
                        Button {
                            card.correctAnswerIndex = index
                            card.answer = card.options[index]
                        } label: {
                            Image(systemName: index == card.correctAnswerIndex ? "checkmark.circle.fill" : "circle")
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Mark as correct answer")
                        TextField("Option \(index + 1)", text: $card.options[index])
                    }
                }
            } else if card.type == .matching {
                if let pairs = card.matchingPairs {
                    ForEach(pairs.indices, id: \.self) { index in
                        HStack(spacing: 8) {
                            TextField("Left item", text: Binding(
                                get: { card.matchingPairs?[index].left ?? "" },
                                set: { card.matchingPairs?[index].left = $0 }
                            ))
                            Image(systemName: "arrow.left.arrow.right")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.purple)
                            TextField("Right item", text: Binding(
                                get: { card.matchingPairs?[index].right ?? "" },
                                set: { card.matchingPairs?[index].right = $0 }
                            ))
                        }
                    }
                }
            } else {
                TextField("Answer", text: $card.answer, axis: .vertical)
                    .lineLimit(1...5)
            }

            TextField("Hint", text: $card.hint, axis: .vertical)
                .lineLimit(1...3)
            TextField("Explanation", text: $card.explanation, axis: .vertical)
                .lineLimit(2...5)
        }
        .foregroundStyle(LearnAlertStyle.textPrimary)
        .textFieldStyle(.roundedBorder)
    }
}

