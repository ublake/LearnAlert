import SwiftData
import SwiftUI

struct DeckAIAssistantSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Bindable var deck: Deck

    @State private var chatHistory: [DeckChatMessage] = []
    @State private var messageInput: String = ""
    @State private var isWorking: Bool = false
    @State private var errorMessage: String?
    @State private var statusToast: String?
    @State private var showingCoverageDetails: Bool = false
    @State private var activeDiagnosticReport: AIDiagnosticReport?
    @State private var failedDiagnosticReport: AIDiagnosticReport?
    @State private var failedErrorMessage: String?
    @State private var pendingUserMessage: DeckChatMessage?

    private var hasSourceDocument: Bool {
        deck.sourceId != nil || (deck.sourceText != nil && !(deck.sourceText?.isEmpty ?? true))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AIChatBackground()

                VStack(spacing: 0) {
                    // Header document info & prompt caching banner
                    if hasSourceDocument {
                        documentContextBanner
                    }

                    // Conversation history
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                if chatHistory.isEmpty {
                                    assistantWelcomeCard
                                }

                                ForEach(chatHistory) { message in
                                    AssistantChatBubble(
                                        message: message,
                                        onSelectSuggestion: { suggestion in
                                            handleSuggestion(suggestion)
                                        },
                                        onViewDiagnostics: { report in
                                            activeDiagnosticReport = report
                                        }
                                    )
                                    .id(message.id)
                                }

                                if let pending = pendingUserMessage {
                                    AssistantChatBubble(message: pending)
                                        .id("pending_user_message")
                                }

                                if isWorking {
                                    AssistantWorkingBubble()
                                        .id("working_bubble")
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }
                        .scrollDismissesKeyboard(.interactively)
                        .onChange(of: chatHistory.count) { _, _ in
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                if let lastId = chatHistory.last?.id {
                                    proxy.scrollTo(lastId, anchor: .bottom)
                                }
                            }
                        }
                        .onChange(of: pendingUserMessage?.id) { _, pendingId in
                            if pendingId != nil {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    proxy.scrollTo("pending_user_message", anchor: .bottom)
                                }
                            }
                        }
                        .onChange(of: isWorking) { _, working in
                            if working {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    proxy.scrollTo("working_bubble", anchor: .bottom)
                                }
                            }
                        }
                    }

                    // Quick prompt action chips
                    quickActionChips

                    if let failedReport = failedDiagnosticReport {
                        HStack(alignment: .center, spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.orange)

                            Text(failedErrorMessage ?? failedReport.technicalError)
                                .font(.custom("Poppins-Medium", size: 12))
                                .foregroundStyle(Color.white)
                                .lineLimit(2)

                            Spacer()

                            Button {
                                activeDiagnosticReport = failedReport
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
                                failedDiagnosticReport = nil
                                failedErrorMessage = nil
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
                    }

                    // Chat composer
                    chatComposer
                }

                if let statusToast {
                    VStack {
                        Spacer()
                        Text(statusToast)
                            .font(.custom("Poppins-SemiBold", size: 14))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [LearnAlertStyle.indigo, LearnAlertStyle.indigo.opacity(0.85)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                            .shadow(color: LearnAlertStyle.indigo.opacity(0.4), radius: 8, y: 3)
                            .padding(.bottom, 75)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: statusToast)
                }
            }
            .navigationTitle("AI Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(LearnAlertStyle.courseCanvas, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .font(.custom("Poppins-Regular", size: 15))
                    .foregroundStyle(LearnAlertStyle.indigo)
                }
            }
            .sheet(item: $activeDiagnosticReport) { report in
                AIDiagnosticInspectorSheet(report: report)
            }
        }
        .onAppear {
            chatHistory = deck.chatHistory
            if chatHistory.isEmpty, let summary = deck.documentCoverageSummary, !summary.isEmpty {
                chatHistory.append(
                    DeckChatMessage(
                        role: "assistant",
                        content: summary,
                        suggestedActions: ["Simplify cards", "Add hints to cards", "Explain difficult concepts"]
                    )
                )
            }
        }
    }

    private var documentContextBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LearnAlertStyle.indigo)

                Text(deck.sourceName ?? "Source Material")
                    .font(.custom("Poppins-SemiBold", size: 13))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)

                Spacer()
            }

            HStack(spacing: 12) {
                Label("\(deck.cards.count) cards", systemImage: "rectangle.stack")
                    .font(.caption2)
                    .foregroundStyle(Color.white.opacity(0.75))

                if !deck.sections.isEmpty {
                    Label("\(deck.sections.count) categories", systemImage: "folder")
                        .font(.caption2)
                        .foregroundStyle(Color.white.opacity(0.75))
                }

                Spacer()

                if deck.documentCoverageSummary != nil {
                    Button {
                        withAnimation(.snappy) { showingCoverageDetails.toggle() }
                    } label: {
                        HStack(spacing: 3) {
                            Text(showingCoverageDetails ? "Hide Coverage" : "View Coverage")
                                .font(.custom("Poppins-Medium", size: 11))
                            Image(systemName: showingCoverageDetails ? "chevron.up" : "chevron.down")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundStyle(LearnAlertStyle.indigo)
                    }
                }
            }

            if showingCoverageDetails, let summary = deck.documentCoverageSummary {
                AIMarkdownText(
                    text: summary,
                    size: 12,
                    color: Color.white.opacity(0.85),
                    lineSpacing: 2
                )
                .padding(10)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.07))
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private var assistantWelcomeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(LearnAlertStyle.indigo.opacity(0.25))
                        .frame(width: 36, height: 36)
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(LearnAlertStyle.indigo)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("AI Deck Assistant")
                        .font(.custom("Poppins-SemiBold", size: 15))
                        .foregroundStyle(Color.white)
                    Text("Ready to help you edit, clarify, and explain your deck.")
                        .font(.custom("Poppins-Regular", size: 12))
                        .foregroundStyle(Color.white.opacity(0.65))
                }
            }

            Text("Ask to refine your cards, simplify explanations, improve hints, or explain challenging concepts.")
                .font(.custom("Poppins-Regular", size: 13))
                .foregroundStyle(Color.white.opacity(0.85))
                .lineSpacing(2)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }

    private var quickActionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                quickChip(title: "Add hints", icon: "lightbulb") {
                    handleSuggestion("Add helpful, memorable hints to cards that need them")
                }
                quickChip(title: "Simplify cards", icon: "text.badge.minus") {
                    handleSuggestion("Simplify and clarify card questions and answers to make them easier to remember")
                }
                quickChip(title: "Fix confusing phrasing", icon: "pencil.and.outline") {
                    handleSuggestion("Review the deck and polish any awkwardly phrased questions or answer options")
                }
                quickChip(title: "Explain hardest concept", icon: "graduationcap") {
                    handleSuggestion("Which concept in this deck is easiest to confuse, and can you explain it simply?")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private func quickChip(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(LearnAlertStyle.indigo)
                Text(title)
                    .font(.custom("Poppins-Medium", size: 12))
                    .foregroundStyle(Color.white.opacity(0.92))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.10))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.20), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var chatComposer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField(
                "",
                text: $messageInput,
                prompt: Text("Ask to edit, simplify, or explain cards...")
                    .foregroundStyle(Color.white.opacity(0.50)),
                axis: .vertical
            )
            .lineLimit(1...5)
            .font(.custom("Poppins-Regular", size: 15))
            .foregroundStyle(Color.white)
            .tint(LearnAlertStyle.indigo)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
            )

            Button {
                sendUserMessage()
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(canSend ? Color.white : Color.white.opacity(0.35))
                    .frame(width: 42, height: 42)
                    .background(
                        Circle()
                            .fill(canSend ? LearnAlertStyle.indigo : Color.white.opacity(0.10))
                    )
                    .shadow(color: canSend ? LearnAlertStyle.indigo.opacity(0.4) : .clear, radius: 6, y: 2)
            }
            .disabled(!canSend)
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(
            Rectangle()
                .fill(LearnAlertStyle.courseCanvas.opacity(0.95))
                .ignoresSafeArea()
        )
    }

    private var canSend: Bool {
        !messageInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isWorking
    }

    private func handleSuggestion(_ text: String) {
        messageInput = text
        sendUserMessage()
    }

    private func sendUserMessage() {
        let userText = messageInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userText.isEmpty, !isWorking else { return }

        let originalInput = messageInput
        messageInput = ""
        isWorking = true
        failedDiagnosticReport = nil
        failedErrorMessage = nil

        let pending = DeckChatMessage(role: "user", content: userText)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            pendingUserMessage = pending
        }

        InteractionSoundPlayer.shared.play(.sentTo)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        let priorHistory = chatHistory

        Task {
            defer { isWorking = false }

            do {
                let api = LearnAlertAPI()
                let currentGenerated = deck.toGeneratedDeck()

                let lower = userText.lowercased()
                let isExpanding = lower.contains("add") || lower.contains("lesson") || lower.contains("more") || lower.contains("continue") || lower.contains("next") || lower.contains("challenging") || lower.contains("tricky")

                let targetCards: Int
                if lower.contains("50") {
                    targetCards = currentGenerated.cards.count + 50
                } else if lower.contains("20") {
                    targetCards = currentGenerated.cards.count + 20
                } else if isExpanding {
                    targetCards = currentGenerated.cards.count + 25
                } else {
                    targetCards = max(currentGenerated.cards.count, 20)
                }

                // Send userText verbatim - no directives concatenated!
                let instruction = userText

                let result: GeneratedDeckResult
                if let sourceId = deck.sourceId, let sourceKind = deck.sourceKind {
                    result = try await api.refineUploadedDeck(
                        instruction: instruction,
                        maxCards: min(targetCards, 200),
                        sourceId: sourceId,
                        sourceKind: sourceKind,
                        sourceName: deck.sourceName ?? deck.name,
                        deck: currentGenerated,
                        chatHistory: priorHistory
                    )
                } else {
                    let sourceText = deck.sourceText ?? deck.cards.map { "\($0.question) - \($0.correctAnswer)" }.joined(separator: "\n")
                    result = try await api.refineTextDeck(
                        instruction: instruction,
                        maxCards: min(targetCards, 200),
                        sourceName: deck.sourceName ?? deck.name,
                        sourceText: sourceText,
                        deck: currentGenerated,
                        chatHistory: priorHistory
                    )
                }

                // Append user message and assistant reply to chat AFTER 2xx and successful decode
                let reply = DeckChatMessage(
                    role: "assistant",
                    content: result.assistantMessage
                )
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    chatHistory.append(pending)
                    chatHistory.append(reply)
                    pendingUserMessage = nil
                }
                deck.chatHistory = chatHistory

                // If deck cards were refined / updated
                if let returnedDeck = result.deck, !returnedDeck.cards.isEmpty {
                    var updatedCount = 0
                    var addedCount = 0

                    for (index, card) in returnedDeck.cards.enumerated() {
                        let cleanPrompt = card.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
                        let options = card.type == .multipleChoice ? card.options : []
                        let correctAnswer: String
                        if card.type == .multipleChoice, options.indices.contains(card.correctAnswerIndex) {
                            correctAnswer = options[card.correctAnswerIndex]
                        } else {
                            correctAnswer = card.answer
                        }
                        let cleanAnswer = correctAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
                        let cleanHint = card.hint.trimmingCharacters(in: .whitespacesAndNewlines)

                        if let existingIndex = deck.cards.firstIndex(where: { $0.question.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == cleanPrompt.lowercased() }) {
                            let existing = deck.cards[existingIndex]
                            var changed = false
                            if !cleanHint.isEmpty && existing.hint != cleanHint {
                                existing.hint = cleanHint
                                changed = true
                            }
                            if !cleanAnswer.isEmpty && existing.correctAnswer != cleanAnswer {
                                existing.correctAnswer = cleanAnswer
                                changed = true
                            }
                            if !options.isEmpty && existing.options != options {
                                existing.options = options
                                changed = true
                            }
                            if changed { updatedCount += 1 }
                        } else if returnedDeck.cards.count == deck.cards.count && index < deck.cards.count {
                            let existing = deck.cards[index]
                            existing.question = cleanPrompt
                            existing.correctAnswer = cleanAnswer
                            existing.options = options
                            if !cleanHint.isEmpty { existing.hint = cleanHint }
                            updatedCount += 1
                        } else {
                            let newCard = Flashcard(
                                question: cleanPrompt,
                                options: options,
                                correctAnswer: cleanAnswer,
                                hint: cleanHint,
                                cardType: FlashcardType(rawValue: card.type.rawValue),
                                matchingLeftItems: card.matchingPairs?.map(\.left) ?? [],
                                matchingRightItems: card.matchingPairs?.map(\.right) ?? [],
                                sourceLocator: card.sourceLocator.isEmpty ? nil : card.sourceLocator,
                                sourceExcerpt: card.sourceExcerpt.isEmpty ? nil : card.sourceExcerpt,
                                tags: card.tags
                            )
                            deck.cards.append(newCard)
                            let categoryName = card.tags.first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
                                ?? (card.sourceLocator.isEmpty ? nil : card.sourceLocator)
                            deck.assignCardToSection(card: newCard, suggestedCategory: categoryName)
                            addedCount += 1
                        }
                    }

                    if updatedCount > 0 || addedCount > 0 {
                        deck.documentCoverageSummary = result.assistantMessage
                        try? context.save()
                        if updatedCount > 0 && addedCount > 0 {
                            showToast("Updated \(updatedCount) cards, added \(addedCount) cards!")
                        } else if updatedCount > 0 {
                            showToast("Updated \(updatedCount) cards!")
                        } else {
                            showToast("Added \(addedCount) new cards!")
                        }
                    }
                }

                InteractionSoundPlayer.shared.play(.receiveFrom)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } catch {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    pendingUserMessage = nil
                }
                messageInput = originalInput
                let desc = (error as? LocalizedError)?.errorDescription ?? "Failed to complete request."
                let diag = (error as? LearnAlertAPIError)?.diagnosticReport
                failedErrorMessage = desc
                failedDiagnosticReport = diag
                InteractionSoundPlayer.shared.play(.receiveFrom)
            }
        }
    }

    private func showToast(_ message: String) {
        statusToast = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if statusToast == message {
                statusToast = nil
            }
        }
    }
}

private struct AssistantChatBubble: View {
    let message: DeckChatMessage
    var onSelectSuggestion: ((String) -> Void)? = nil
    var onViewDiagnostics: ((AIDiagnosticReport) -> Void)? = nil

    var body: some View {
        VStack(alignment: message.role == "user" ? .trailing : .leading, spacing: 8) {
            HStack {
                if message.role == "user" { Spacer(minLength: 40) }

                AIMarkdownText(
                    text: message.displayContent,
                    size: 14,
                    color: .white,
                    lineSpacing: 2
                )
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        message.role == "user"
                            ? AnyShapeStyle(
                                LinearGradient(
                                    colors: [LearnAlertStyle.indigo, LearnAlertStyle.indigo.opacity(0.85)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            : AnyShapeStyle(Color.white.opacity(0.10))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(message.role == "user" ? 0.25 : 0.15), lineWidth: 1)
                    )

                if message.role != "user" { Spacer(minLength: 40) }
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
                                .frame(width: 26, height: 26)
                            Image(systemName: "ladybug.fill")
                                .font(.system(size: 11, weight: .bold))
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
                                .foregroundStyle(Color.white.opacity(0.68))
                        }

                        Spacer(minLength: 4)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.40))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.orange.opacity(0.18), Color.red.opacity(0.10)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.orange.opacity(0.38), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .padding(.trailing, 20)
            }

            if message.role == "assistant" && !message.parsedSuggestions.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(message.parsedSuggestions, id: \.self) { suggestion in
                        Button {
                            onSelectSuggestion?(suggestion)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(LearnAlertStyle.indigo)
                                Text(suggestion)
                                    .font(.custom("Poppins-Medium", size: 12))
                                    .foregroundStyle(Color.white.opacity(0.95))
                                Spacer(minLength: 4)
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color.white.opacity(0.4))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.white.opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(LearnAlertStyle.indigo.opacity(0.4), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.leading, 4)
            }
        }
    }
}

private struct AssistantWorkingBubble: View {
    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .tint(LearnAlertStyle.indigo)
            Text("Consulting cached document...")
                .font(.custom("Poppins-Regular", size: 13))
                .foregroundStyle(Color.white.opacity(0.70))
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct AIChatBackground: View {
    var body: some View {
        ZStack {
            Color(red: 0.055, green: 0.065, blue: 0.11)
                .ignoresSafeArea()

            Circle()
                .fill(LearnAlertStyle.indigo.opacity(0.18))
                .frame(width: 300, height: 300)
                .position(x: 300, y: 100)
                .blur(radius: 50)
                .ignoresSafeArea()

            Circle()
                .fill(LearnAlertStyle.aqua.opacity(0.10))
                .frame(width: 250, height: 250)
                .position(x: 80, y: 500)
                .blur(radius: 40)
                .ignoresSafeArea()
        }
    }
}
