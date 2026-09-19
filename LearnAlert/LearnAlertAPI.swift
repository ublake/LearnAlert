import Foundation
import SwiftData

enum GeneratedCardType: String, Codable, CaseIterable, Sendable {
    case tapReveal = "tap_reveal"
    case multipleChoice = "multiple_choice"
    case matching = "matching"
    case fillBlank = "fill_blank"

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawString = (try? container.decode(String.self)) ?? ""
        let normalized = rawString.lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")

        switch normalized {
        case "tap_reveal", "tapreveal", "reveal", "flashcard", "card":
            self = .tapReveal
        case "multiple_choice", "multiplechoice", "quiz", "mcq":
            self = .multipleChoice
        case "matching", "match", "pairs":
            self = .matching
        case "fill_blank", "fillblank", "fill_in_the_blank", "cloze":
            self = .fillBlank
        default:
            self = .tapReveal
        }
    }
}

struct GeneratedMatchingPair: Codable, Sendable, Equatable {
    var left: String
    var right: String

    init(left: String, right: String) {
        self.left = left
        self.right = right
    }

    private enum CodingKeys: String, CodingKey {
        case left, right
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.left = (try? container.decodeIfPresent(String.self, forKey: .left)) ?? ""
        self.right = (try? container.decodeIfPresent(String.self, forKey: .right)) ?? ""
    }
}

struct GeneratedDeck: Codable, Sendable, Equatable {
    var title: String
    var subject: String
    var deckKind: String
    var detectedLanguage: String
    var summary: String
    var cards: [GeneratedCard]

    init(
        title: String,
        subject: String,
        deckKind: String,
        detectedLanguage: String,
        summary: String,
        cards: [GeneratedCard]
    ) {
        self.title = title
        self.subject = subject
        self.deckKind = deckKind
        self.detectedLanguage = detectedLanguage
        self.summary = summary
        self.cards = cards
    }

    private enum CodingKeys: String, CodingKey {
        case title, subject, deckKind, detectedLanguage, summary, cards
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.title = (try? container.decodeIfPresent(String.self, forKey: .title)) ?? "Generated Deck"
        self.subject = (try? container.decodeIfPresent(String.self, forKey: .subject)) ?? "Study"
        self.deckKind = (try? container.decodeIfPresent(String.self, forKey: .deckKind)) ?? "study"
        self.detectedLanguage = (try? container.decodeIfPresent(String.self, forKey: .detectedLanguage)) ?? "auto"
        self.summary = (try? container.decodeIfPresent(String.self, forKey: .summary)) ?? ""
        self.cards = (try? container.decodeIfPresent([GeneratedCard].self, forKey: .cards)) ?? []
    }
}

struct GeneratedCard: Codable, Identifiable, Sendable, Equatable {
    var id: String
    var type: GeneratedCardType
    var prompt: String
    var answer: String
    var hint: String
    var explanation: String
    var options: [String]
    var correctAnswerIndex: Int
    var difficulty: String
    var tags: [String]
    var sourceExcerpt: String
    var sourceLocator: String
    var matchingPairs: [GeneratedMatchingPair]? = nil

    init(
        id: String,
        type: GeneratedCardType,
        prompt: String,
        answer: String,
        hint: String,
        explanation: String,
        options: [String],
        correctAnswerIndex: Int,
        difficulty: String,
        tags: [String],
        sourceExcerpt: String,
        sourceLocator: String,
        matchingPairs: [GeneratedMatchingPair]? = nil
    ) {
        self.id = id
        self.type = type
        self.prompt = prompt
        self.answer = answer
        self.hint = hint
        self.explanation = explanation
        self.options = options
        self.correctAnswerIndex = correctAnswerIndex
        self.difficulty = difficulty
        self.tags = tags
        self.sourceExcerpt = sourceExcerpt
        self.sourceLocator = sourceLocator
        self.matchingPairs = matchingPairs
    }

    private enum CodingKeys: String, CodingKey {
        case id, type, prompt, answer, hint, explanation, options
        case correctAnswerIndex, difficulty, tags, sourceExcerpt, sourceLocator, matchingPairs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // ID: can be String, Int, or fallback
        if let strId = try? container.decodeIfPresent(String.self, forKey: .id), !strId.isEmpty {
            self.id = strId
        } else if let intId = try? container.decodeIfPresent(Int.self, forKey: .id) {
            self.id = String(intId)
        } else {
            self.id = UUID().uuidString
        }

        // Type
        self.type = (try? container.decodeIfPresent(GeneratedCardType.self, forKey: .type)) ?? .tapReveal

        self.prompt = (try? container.decodeIfPresent(String.self, forKey: .prompt)) ?? ""
        self.answer = (try? container.decodeIfPresent(String.self, forKey: .answer)) ?? ""
        self.hint = (try? container.decodeIfPresent(String.self, forKey: .hint)) ?? ""
        self.explanation = (try? container.decodeIfPresent(String.self, forKey: .explanation)) ?? ""
        self.options = (try? container.decodeIfPresent([String].self, forKey: .options)) ?? []

        // Correct Answer Index
        if let intIdx = try? container.decodeIfPresent(Int.self, forKey: .correctAnswerIndex) {
            self.correctAnswerIndex = intIdx
        } else if let strIdx = try? container.decodeIfPresent(String.self, forKey: .correctAnswerIndex), let parsed = Int(strIdx) {
            self.correctAnswerIndex = parsed
        } else {
            self.correctAnswerIndex = -1
        }

        self.difficulty = (try? container.decodeIfPresent(String.self, forKey: .difficulty)) ?? "medium"
        self.tags = (try? container.decodeIfPresent([String].self, forKey: .tags)) ?? []
        self.sourceExcerpt = (try? container.decodeIfPresent(String.self, forKey: .sourceExcerpt)) ?? ""
        self.sourceLocator = (try? container.decodeIfPresent(String.self, forKey: .sourceLocator)) ?? ""
        self.matchingPairs = try? container.decodeIfPresent([GeneratedMatchingPair].self, forKey: .matchingPairs)
    }
}

struct BackendChatMessage: Encodable {
    let role: String
    let content: String
}

struct DeckChatMessage: Codable, Identifiable, Sendable, Equatable {
    let id: UUID
    let role: String
    let content: String
    let displayAttachmentName: String?
    var suggestedActions: [String]?
    var diagnosticReport: AIDiagnosticReport?

    init(
        id: UUID = UUID(),
        role: String,
        content: String,
        displayAttachmentName: String? = nil,
        suggestedActions: [String]? = nil,
        diagnosticReport: AIDiagnosticReport? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.displayAttachmentName = displayAttachmentName
        self.suggestedActions = suggestedActions
        self.diagnosticReport = diagnosticReport
    }

    private enum CodingKeys: String, CodingKey {
        case id, role, content, displayAttachmentName, suggestedActions, diagnosticReport
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
        self.role = try container.decode(String.self, forKey: .role)
        self.content = try container.decode(String.self, forKey: .content)
        self.displayAttachmentName = try? container.decodeIfPresent(String.self, forKey: .displayAttachmentName)
        self.suggestedActions = try? container.decodeIfPresent([String].self, forKey: .suggestedActions)
        self.diagnosticReport = try? container.decodeIfPresent(AIDiagnosticReport.self, forKey: .diagnosticReport)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(role, forKey: .role)
        try container.encode(content, forKey: .content)
        try container.encodeIfPresent(displayAttachmentName, forKey: .displayAttachmentName)
        try container.encodeIfPresent(suggestedActions, forKey: .suggestedActions)
        try container.encodeIfPresent(diagnosticReport, forKey: .diagnosticReport)
    }
}

extension DeckChatMessage {
    private static let optionRegex: NSRegularExpression? = {
        let pattern = #"(?:^|[\r\n]|(?<=[.!?])\s+|[-*•]\s*)\*?\*?Option\s*\d*\s*:\s*\*?\*?\s*(.+?)(?=(?:\s+(?:[-*•]\s*)?(?:\*?\*?Option\s*\d*\s*:))|[\r\n]|$)"#
        return try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }()

    var displayContent: String {
        guard let regex = Self.optionRegex else {
            let lines = content.components(separatedBy: "\n")
            let cleaned = lines.filter { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                return !trimmed.lowercased().hasPrefix("option:")
            }
            let result = cleaned.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            return result.isEmpty ? content : result
        }

        let nsString = content as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)
        let cleaned = regex.stringByReplacingMatches(in: content, options: [], range: fullRange, withTemplate: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? content : cleaned
    }

    var parsedSuggestions: [String] {
        if let suggestedActions, !suggestedActions.isEmpty {
            return suggestedActions
        }

        guard let regex = Self.optionRegex else {
            return []
        }

        let nsString = content as NSString
        let matches = regex.matches(in: content, options: [], range: NSRange(location: 0, length: nsString.length))
        var options: [String] = []

        for match in matches {
            if match.numberOfRanges > 1 {
                let captureRange = match.range(at: 1)
                if captureRange.location != NSNotFound {
                    var optionText = nsString.substring(with: captureRange).trimmingCharacters(in: .whitespacesAndNewlines)
                    if optionText.hasSuffix(".") || optionText.hasSuffix(";") {
                        optionText.removeLast()
                    }
                    optionText = optionText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !optionText.isEmpty {
                        options.append(optionText)
                    }
                }
            }
        }
        return options
    }
}

struct GeneratedSource: Decodable, Sendable, Equatable {
    let id: String
    let kind: String
    let name: String
    let mimeType: String?
    let expiresAt: String?

    init(
        id: String,
        kind: String,
        name: String,
        mimeType: String? = nil,
        expiresAt: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.mimeType = mimeType
        self.expiresAt = expiresAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, kind, name, mimeType, expiresAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decodeIfPresent(String.self, forKey: .id)) ?? ""
        self.kind = (try? container.decodeIfPresent(String.self, forKey: .kind)) ?? "file"
        self.name = (try? container.decodeIfPresent(String.self, forKey: .name)) ?? ""
        self.mimeType = try? container.decodeIfPresent(String.self, forKey: .mimeType)
        if let string = try? container.decodeIfPresent(String.self, forKey: .expiresAt) {
            self.expiresAt = string
        } else if let number = try? container.decodeIfPresent(Double.self, forKey: .expiresAt) {
            self.expiresAt = number.formatted(.number.grouping(.never))
        } else {
            self.expiresAt = nil
        }
    }
}

struct GeneratedDeckResult: Sendable {
    let action: String
    let assistantMessage: String
    let deck: GeneratedDeck?
}

private struct GenerateTextDeckRequest: Encodable {
    let text: String
    let sourceName: String
    let maxCards: Int
    let mode: String
    let difficulty: String
    let languageDirection: String
    let preferredCardTypes: [GeneratedCardType]
    let userInstruction: String
    let chatHistory: [BackendChatMessage]?
}

private struct RefineUploadedDeckRequest: Encodable {
    let deck: GeneratedDeck
    let instruction: String
    let chatHistory: [BackendChatMessage]?
    let sourceText: String? = nil
    let sourceName: String?
    let maxCards: Int?
    let sourceId: String?
    let sourceKind: String?
}

private struct RefineTextDeckRequest: Encodable {
    let deck: GeneratedDeck
    let instruction: String
    let chatHistory: [BackendChatMessage]?
    let sourceText: String?
    let sourceName: String?
    let maxCards: Int?
}

private struct DeckResponse: Decodable {
    let action: String?
    let title: String?
    let name: String?
    let sourceId: String?
    let sourceKind: String?
    let source: GeneratedSource?
    let assistantMessage: String?
    let deck: GeneratedDeck?
    let cards: [GeneratedCard]?
    let message: String?
    let error: String?
    let requestId: String?
    let errorCode: String?
    let errorDetails: String?

    private enum CodingKeys: String, CodingKey {
        case success, requestId, action, title, name, sourceId, sourceKind, source, assistantMessage, deck, cards, message, error
    }

    private enum NestedErrorKeys: String, CodingKey {
        case code, message, details
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try? container.decodeIfPresent(Bool.self, forKey: .success)
        requestId = try? container.decodeIfPresent(String.self, forKey: .requestId)
        action = try? container.decodeIfPresent(String.self, forKey: .action)
        title = try? container.decodeIfPresent(String.self, forKey: .title)
        name = try? container.decodeIfPresent(String.self, forKey: .name)
        sourceId = try? container.decodeIfPresent(String.self, forKey: .sourceId)
        sourceKind = try? container.decodeIfPresent(String.self, forKey: .sourceKind)
        source = try? container.decodeIfPresent(GeneratedSource.self, forKey: .source)
        assistantMessage = try? container.decodeIfPresent(String.self, forKey: .assistantMessage)
        deck = try? container.decodeIfPresent(GeneratedDeck.self, forKey: .deck)
        cards = try? container.decodeIfPresent([GeneratedCard].self, forKey: .cards)
        message = try? container.decodeIfPresent(String.self, forKey: .message)

        if let stringError = try? container.decodeIfPresent(String.self, forKey: .error) {
            error = stringError
            errorCode = nil
            errorDetails = nil
        } else if let nested = try? container.nestedContainer(keyedBy: NestedErrorKeys.self, forKey: .error) {
            errorCode = try? nested.decodeIfPresent(String.self, forKey: .code)
            error = try? nested.decodeIfPresent(String.self, forKey: .message)
            if let strDetails = try? nested.decodeIfPresent(String.self, forKey: .details) {
                errorDetails = strDetails
            } else {
                errorDetails = nil
            }
        } else {
            error = nil
            errorCode = nil
            errorDetails = nil
        }
    }

    private(set) var success: Bool?
}

enum LearnAlertAPIError: LocalizedError {
    case emptyStudyMaterial
    case invalidMaximumCards
    case unauthorized(diagnostic: AIDiagnosticReport? = nil)
    case unavailable(diagnostic: AIDiagnosticReport? = nil)
    case serverError(String?, diagnostic: AIDiagnosticReport? = nil)
    case generationFailed(String?, diagnostic: AIDiagnosticReport? = nil)
    case invalidResponse(reason: String? = nil, diagnostic: AIDiagnosticReport? = nil)

    var errorDescription: String? {
        switch self {
        case .emptyStudyMaterial:
            "Add notes or select a file before generating a deck."
        case .invalidMaximumCards:
            "Card count must be between 1 and 500."
        case .unauthorized:
            "This version of the app is out of date — please update."
        case .unavailable:
            "LearnAlert’s AI service is unavailable right now. Please try again shortly."
        case .serverError(let message, _):
            message ?? "The server couldn’t complete this request. Please try again."
        case .generationFailed(let message, _):
            message ?? "AI deck generation failed. Please try again with different study material."
        case .invalidResponse:
            "The generated deck couldn’t be read. Please try generating it again."
        }
    }

    var diagnosticReport: AIDiagnosticReport? {
        switch self {
        case .unauthorized(let diag),
             .unavailable(let diag),
             .serverError(_, let diag),
             .generationFailed(_, let diag),
             .invalidResponse(_, let diag):
            return diag
        default:
            return nil
        }
    }
}

struct LearnAlertAPI: Sendable {
    private let session: URLSession

    static var apiKey: String? {
        if let key = Bundle.main.object(forInfoDictionaryKey: "APIKey") as? String,
           !key.isEmpty,
           !key.hasPrefix("$(") {
            return key
        }
        if let env = ProcessInfo.processInfo.environment["API_KEY"], !env.isEmpty {
            return env
        }
        return nil
    }

    #if DEBUG
    private var debugToken: String? {
        if let token = Bundle.main.object(forInfoDictionaryKey: "DebugToken") as? String,
           !token.isEmpty,
           !token.hasPrefix("$(") {
            return token
        }
        if let env = ProcessInfo.processInfo.environment["DEBUG_TOKEN"], !env.isEmpty {
            return env
        }
        return nil
    }
    #endif
    private let baseURL = URL(string: "https://api.learnalertapp.com")!

    init(session: URLSession = .shared) {
        self.session = session
    }

    func generateDeck(
        text: String,
        sourceName: String,
        maxCards: Int,
        mode: String,
        userInstruction: String,
        chatHistory: [DeckChatMessage] = []
    ) async throws -> GeneratedDeckResult {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { throw LearnAlertAPIError.emptyStudyMaterial }
        try validate(maxCards: maxCards)

        let backendHistory = chatHistory.isEmpty ? nil : sanitizeChatHistory(chatHistory)
        let requestBody = GenerateTextDeckRequest(
            text: trimmedText,
            sourceName: sourceName,
            maxCards: maxCards,
            mode: mode,
            difficulty: "auto",
            languageDirection: "auto",
            preferredCardTypes: [.tapReveal, .multipleChoice, .matching, .fillBlank],
            userInstruction: userInstruction,
            chatHistory: backendHistory
        )
        let bodyData = try JSONEncoder().encode(requestBody)
        logDiagnostics(
            endpoint: "/v1/decks/generate",
            instruction: userInstruction,
            history: backendHistory,
            bodyByteSize: bodyData.count
        )
        return try await postJSON(
            path: "v1/decks/generate",
            bodyData: bodyData
        )
    }

    func generateDeck(
        fileData: Data,
        fileName: String,
        mimeType: String,
        maxCards: Int,
        mode: String,
        userInstruction: String,
        chatHistory: [DeckChatMessage] = []
    ) async throws -> GeneratedDeckResult {
        guard !fileData.isEmpty else { throw LearnAlertAPIError.emptyStudyMaterial }
        try validate(maxCards: maxCards)

        let boundary = "LearnAlert-\(UUID().uuidString)"
        var body = Data()
        body.appendMultipartFile(
            fieldName: "file",
            fileName: fileName,
            mimeType: mimeType,
            data: fileData,
            boundary: boundary
        )
        var fields = [
            "maxCards": String(maxCards),
            "mode": mode,
            "difficulty": "auto",
            "languageDirection": "auto",
            "preferredCardTypes": "[\"tap_reveal\",\"multiple_choice\",\"matching\",\"fill_blank\"]",
            "userInstruction": userInstruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Create comprehensive study flashcards from this material. Name the deck with a concise, topic-focused title describing the subject matter (do not name it after the file)."
                : userInstruction.trimmingCharacters(in: .whitespacesAndNewlines),
            "sourceName": fileName
        ]
        let backendHistory = chatHistory.isEmpty ? nil : sanitizeChatHistory(chatHistory)
        if let backendHistory {
            if let historyData = try? JSONEncoder().encode(backendHistory), let historyStr = String(data: historyData, encoding: .utf8) {
                fields["chatHistory"] = historyStr
            }
        }
        for (name, value) in fields {
            body.appendMultipartField(name: name, value: value, boundary: boundary)
        }
        body.append(Data("--\(boundary)--\r\n".utf8))

        logDiagnostics(
            endpoint: "/v1/decks/generate",
            instruction: userInstruction,
            history: backendHistory,
            bodyByteSize: body.count
        )

        var request = URLRequest(url: baseURL.appending(path: "v1/decks/generate"), timeoutInterval: 180)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = body
        let result = try await perform(request)
        return result
    }

    func refineUploadedDeck(
        instruction: String,
        maxCards: Int,
        sourceId: String,
        sourceKind: String,
        sourceName: String,
        deck: GeneratedDeck,
        chatHistory: [DeckChatMessage]
    ) async throws -> GeneratedDeckResult {
        let sanitizedInstruction = try validatedInstruction(instruction)
        let formattedHistory = sanitizeChatHistory(chatHistory)
        let requestBody = RefineUploadedDeckRequest(
            deck: deck,
            instruction: sanitizedInstruction,
            chatHistory: formattedHistory,
            sourceName: sourceName,
            maxCards: maxCards,
            sourceId: sourceId,
            sourceKind: sourceKind
        )
        let bodyData = try JSONEncoder().encode(requestBody)
        logDiagnostics(
            endpoint: "/v1/decks/refine",
            instruction: sanitizedInstruction,
            history: formattedHistory,
            bodyByteSize: bodyData.count
        )
        return try await postJSON(
            path: "v1/decks/refine",
            bodyData: bodyData
        )
    }

    func refineTextDeck(
        instruction: String,
        maxCards: Int,
        sourceName: String,
        sourceText: String,
        deck: GeneratedDeck,
        chatHistory: [DeckChatMessage]
    ) async throws -> GeneratedDeckResult {
        let sanitizedInstruction = try validatedInstruction(instruction)
        let formattedHistory = sanitizeChatHistory(chatHistory)
        let requestBody = RefineTextDeckRequest(
            deck: deck,
            instruction: sanitizedInstruction,
            chatHistory: formattedHistory,
            sourceText: sourceText,
            sourceName: sourceName,
            maxCards: maxCards
        )
        let bodyData = try JSONEncoder().encode(requestBody)
        logDiagnostics(
            endpoint: "/v1/decks/refine",
            instruction: sanitizedInstruction,
            history: formattedHistory,
            bodyByteSize: bodyData.count
        )
        return try await postJSON(
            path: "v1/decks/refine",
            bodyData: bodyData
        )
    }

    private func sanitizeChatHistory(_ history: [DeckChatMessage]) -> [BackendChatMessage]? {
        let valid = history
            .filter { $0.role == "user" || $0.role == "assistant" }
            .filter { !$0.content.hasPrefix("⚠️") }
            .suffix(12)
            .map {
                BackendChatMessage(
                    role: $0.role,
                    content: String($0.content.prefix(1500))
                )
            }
        return valid.isEmpty ? nil : Array(valid)
    }

    private func logDiagnostics(
        endpoint: String,
        instruction: String,
        history: [BackendChatMessage]?,
        bodyByteSize: Int
    ) {
        let historyCount = history?.count ?? 0
        let historyCharCount = history?.reduce(0) { $0 + $1.content.count } ?? 0
        print("""
        [LearnAlertAPI Diagnostics] Calling \(endpoint):
          • instruction.count: \(instruction.count)
          • chatHistory.count: \(historyCount) (total characters: \(historyCharCount))
          • JSON body byte size: \(bodyByteSize) bytes
        """)
    }

    private func validate(maxCards: Int) throws {
        guard maxCards >= 1 && maxCards <= 500 else { throw LearnAlertAPIError.invalidMaximumCards }
    }

    private func validatedInstruction(_ instruction: String) throws -> String {
        guard !instruction.isEmpty else { throw LearnAlertAPIError.generationFailed(nil) }
        return instruction
    }

    private func postJSON(path: String, bodyData: Data) async throws -> GeneratedDeckResult {
        var request = URLRequest(url: baseURL.appending(path: path), timeoutInterval: 120)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = bodyData
        return try await perform(request)
    }

    private func postJSON<Body: Encodable>(path: String, body: Body) async throws -> GeneratedDeckResult {
        let bodyData = try JSONEncoder().encode(body)
        return try await postJSON(path: path, bodyData: bodyData)
    }

    private func perform(_ inputRequest: URLRequest) async throws -> GeneratedDeckResult {
        var request = inputRequest
        if let key = Self.apiKey {
            request.setValue(key, forHTTPHeaderField: "X-API-Key")
        }
        #if DEBUG
        if let token = debugToken {
            request.setValue(token, forHTTPHeaderField: "X-Debug-Token")
        }
        #endif
        let endpoint = request.url?.path ?? "/v1/decks"
        let requestBodySnippet: String? = request.httpBody.flatMap { String(data: $0, encoding: .utf8) }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            let diag = AIDiagnosticReport(
                endpoint: endpoint,
                requestMethod: request.httpMethod ?? "POST",
                httpStatusCode: nil,
                httpStatusText: "Network Request Failed",
                errorCode: (error as? URLError)?.code.rawValue.description ?? "NETWORK_ERROR",
                userFriendlySummary: "The network request could not reach LearnAlert's AI service. The device may be offline or the connection timed out.",
                technicalError: error.localizedDescription,
                decodingPath: nil,
                decodingExpectedType: nil,
                rawPayloadSnippet: nil,
                requestPayloadSnippet: requestBodySnippet.map { String($0.prefix(1200)) },
                suggestedFix: "Check your Wi-Fi or cellular network connection and try again."
            )
            throw LearnAlertAPIError.unavailable(diagnostic: diag)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            let diag = AIDiagnosticReport(
                endpoint: endpoint,
                requestMethod: request.httpMethod ?? "POST",
                httpStatusCode: nil,
                httpStatusText: "Non-HTTP Protocol",
                errorCode: "INVALID_PROTOCOL",
                userFriendlySummary: "An unexpected response protocol was returned by the network layer.",
                technicalError: "Expected HTTPURLResponse but received \(type(of: response)).",
                decodingPath: nil,
                decodingExpectedType: nil,
                rawPayloadSnippet: nil,
                suggestedFix: "Ensure your network or VPN is not proxying HTTPS requests."
            )
            throw LearnAlertAPIError.invalidResponse(reason: "Invalid protocol", diagnostic: diag)
        }

        let rawPayloadStr = String(data: data, encoding: .utf8)

        let decoder = JSONDecoder()
        let payload: DeckResponse?
        var decodingErrorDetail: String? = nil
        var decodingPathStr: String? = nil
        var decodingExpectedTypeStr: String? = nil

        do {
            payload = try decoder.decode(DeckResponse.self, from: data)
        } catch let decErr as DecodingError {
            #if DEBUG
            print("[LearnAlertAPI] Decoding DeckResponse failed: \(decErr)")
            if let raw = rawPayloadStr {
                print("[LearnAlertAPI] Raw response: \(raw)")
            }
            #endif
            switch decErr {
            case .keyNotFound(let key, let ctx):
                decodingPathStr = (ctx.codingPath.map(\.stringValue) + [key.stringValue]).joined(separator: ".")
                decodingErrorDetail = "Missing required key '\(key.stringValue)' at '\(decodingPathStr ?? "")'. \(ctx.debugDescription)"
                decodingExpectedTypeStr = "Key: \(key.stringValue)"
            case .typeMismatch(let type, let ctx):
                decodingPathStr = ctx.codingPath.map(\.stringValue).joined(separator: ".")
                decodingErrorDetail = "Type mismatch for type '\(type)' at '\(decodingPathStr ?? "")'. \(ctx.debugDescription)"
                decodingExpectedTypeStr = String(describing: type)
            case .valueNotFound(let type, let ctx):
                decodingPathStr = ctx.codingPath.map(\.stringValue).joined(separator: ".")
                decodingErrorDetail = "Null/missing value for type '\(type)' at '\(decodingPathStr ?? "")'. \(ctx.debugDescription)"
                decodingExpectedTypeStr = String(describing: type)
            case .dataCorrupted(let ctx):
                decodingPathStr = ctx.codingPath.map(\.stringValue).joined(separator: ".")
                decodingErrorDetail = "Data corrupted at '\(decodingPathStr ?? "")': \(ctx.debugDescription)"
            @unknown default:
                decodingErrorDetail = decErr.localizedDescription
            }
            payload = nil
        } catch {
            decodingErrorDetail = error.localizedDescription
            payload = nil
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            var extractedRequestId = payload?.requestId
            var extractedDetails = payload?.errorDetails
            var serverMsg = payload?.error ?? payload?.message ?? "Request failed with status code \(httpResponse.statusCode)"
            var serverCode = payload?.errorCode ?? "HTTP_\(httpResponse.statusCode)"

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let rId = json["requestId"] as? String {
                    extractedRequestId = rId
                }
                if let errObj = json["error"] as? [String: Any] {
                    if let c = errObj["code"] as? String {
                        serverCode = c
                    }
                    if let msg = errObj["message"] as? String {
                        serverMsg = msg
                    }
                    if let d = errObj["details"] {
                        if let str = d as? String {
                            extractedDetails = str
                        } else if let objData = try? JSONSerialization.data(withJSONObject: d, options: [.prettyPrinted, .sortedKeys]),
                                  let str = String(data: objData, encoding: .utf8) {
                            extractedDetails = str
                        }
                    }
                }
            }

            #if DEBUG
            print("[LearnAlertAPI Diagnostics] Non-2xx response (\(httpResponse.statusCode)) for \(endpoint). requestId: \(extractedRequestId ?? "unknown")")
            if let details = extractedDetails {
                print("[LearnAlertAPI Diagnostics] error.details: \(details)")
            }
            #endif

            if httpResponse.statusCode == 401 {
                let diag = AIDiagnosticReport(
                    endpoint: endpoint,
                    requestMethod: request.httpMethod ?? "POST",
                    httpStatusCode: 401,
                    httpStatusText: "Unauthorized",
                    errorCode: (serverCode.isEmpty || serverCode == "HTTP_401") ? "UNAUTHORIZED" : serverCode,
                    userFriendlySummary: "This version of the app is out of date — please update.",
                    technicalError: serverMsg,
                    decodingPath: nil,
                    decodingExpectedType: nil,
                    rawPayloadSnippet: rawPayloadStr,
                    requestPayloadSnippet: requestBodySnippet.map { String($0.prefix(1200)) },
                    suggestedFix: "Please update LearnAlert from the App Store.",
                    requestId: extractedRequestId,
                    errorDetails: extractedDetails
                )
                throw LearnAlertAPIError.unauthorized(diagnostic: diag)
            }

            let diag = AIDiagnosticReport(
                endpoint: endpoint,
                requestMethod: request.httpMethod ?? "POST",
                httpStatusCode: httpResponse.statusCode,
                httpStatusText: HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode),
                errorCode: serverCode,
                userFriendlySummary: "The AI service responded with HTTP \(httpResponse.statusCode): \(serverMsg)",
                technicalError: serverMsg,
                decodingPath: nil,
                decodingExpectedType: nil,
                rawPayloadSnippet: rawPayloadStr,
                requestPayloadSnippet: requestBodySnippet.map { String($0.prefix(1200)) },
                suggestedFix: (httpResponse.statusCode == 400)
                    ? "The request was rejected by the server. Check your prompt or source material."
                    : "The AI server encountered an error processing the request. Check your prompt or try a smaller section.",
                requestId: extractedRequestId,
                errorDetails: extractedDetails
            )
            throw LearnAlertAPIError.serverError(serverMsg, diagnostic: diag)
        }

        guard let payload else {
            let diag = AIDiagnosticReport(
                endpoint: endpoint,
                requestMethod: request.httpMethod ?? "POST",
                httpStatusCode: httpResponse.statusCode,
                httpStatusText: HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode),
                errorCode: "DECODING_FAILURE",
                userFriendlySummary: "The AI response was received with HTTP 200 OK, but could not be parsed into the expected deck schema.",
                technicalError: decodingErrorDetail ?? "Unknown JSON decoding error.",
                decodingPath: decodingPathStr,
                decodingExpectedType: decodingExpectedTypeStr,
                rawPayloadSnippet: rawPayloadStr,
                requestPayloadSnippet: requestBodySnippet.map { String($0.prefix(1200)) },
                suggestedFix: "A required field was missing or formatted unexpectedly in the JSON response."
            )
            throw LearnAlertAPIError.invalidResponse(
                reason: decodingErrorDetail,
                diagnostic: diag
            )
        }

        let action = (payload.action ?? (payload.deck != nil || payload.cards != nil ? "deck" : "chat")).lowercased()
        var finalDeck: GeneratedDeck? = nil
        let apiTitle = (payload.title ?? payload.name)?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let rawDeck = payload.deck {
            var validDeck = sanitizeDeck(rawDeck)
            if let apiTitle, !apiTitle.isEmpty {
                validDeck.title = apiTitle
            }
            if !validDeck.cards.isEmpty {
                finalDeck = validDeck
            }
        } else if let rawCards = payload.cards, !rawCards.isEmpty {
            let fallbackDeck = GeneratedDeck(
                title: (apiTitle?.isEmpty == false) ? apiTitle! : "Generated Deck",
                subject: "Study",
                deckKind: "study",
                detectedLanguage: "auto",
                summary: payload.assistantMessage ?? "",
                cards: rawCards
            )
            let validDeck = sanitizeDeck(fallbackDeck)
            if !validDeck.cards.isEmpty {
                finalDeck = validDeck
            }
        }

        let resolvedAction = (finalDeck != nil && action != "chat") ? "deck" : "chat"

        return GeneratedDeckResult(
            action: resolvedAction,
            assistantMessage: payload.assistantMessage ?? (resolvedAction == "chat" ? "How can I help you study?" : "Your deck is ready."),
            deck: finalDeck
        )
    }

    private func sanitizeDeck(_ deck: GeneratedDeck) -> GeneratedDeck {
        var sanitized = deck
        var title = deck.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty {
            title = "New Deck"
        }
        let extensions = [".pdf", ".txt", ".png", ".jpg", ".jpeg", ".docx"]
        for ext in extensions {
            if title.lowercased().hasSuffix(ext) {
                title = String(title.dropLast(ext.count))
            }
        }
        sanitized.title = title
        sanitized.cards = sanitizeCards(deck.cards)
        return sanitized
    }

    private func sanitizeCards(_ cards: [GeneratedCard]) -> [GeneratedCard] {
        cards.compactMap { card in
            guard !card.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            var c = card
            switch c.type {
            case .tapReveal:
                guard !c.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
                return c
            case .multipleChoice:
                guard c.options.count >= 2 else { return nil }
                if !c.options.indices.contains(c.correctAnswerIndex) {
                    if let foundIdx = c.options.firstIndex(of: c.answer) {
                        c.correctAnswerIndex = foundIdx
                    } else {
                        c.correctAnswerIndex = 0
                        c.answer = c.options[0]
                    }
                }
                return c
            case .fillBlank:
                guard !c.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
                return c
            case .matching:
                guard let pairs = c.matchingPairs, pairs.count >= 2 else { return nil }
                let validPairs = pairs.filter {
                    !$0.left.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                    !$0.right.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                }
                guard validPairs.count >= 2 else { return nil }
                c.matchingPairs = validPairs
                return c
            }
        }
    }
}

extension Deck {
    var chatHistory: [DeckChatMessage] {
        get {
            guard let chatHistoryData,
                  let decoded = try? JSONDecoder().decode([DeckChatMessage].self, from: chatHistoryData) else {
                return []
            }
            return decoded
        }
        set {
            chatHistoryData = try? JSONEncoder().encode(newValue)
        }
    }

    func toGeneratedDeck() -> GeneratedDeck {
        let genCards = cards.map { card in
            let pairs: [GeneratedMatchingPair]? = (card.cardType == .matching && !card.matchingLeftItems.isEmpty)
                ? zip(card.matchingLeftItems, card.matchingRightItems).map { GeneratedMatchingPair(left: $0, right: $1) }
                : nil
            let options = card.cardType == .multipleChoice ? card.options : []
            let correctIdx = card.cardType == .multipleChoice ? (options.firstIndex(of: card.correctAnswer) ?? 0) : 0
            return GeneratedCard(
                id: card.id.uuidString,
                type: GeneratedCardType(rawValue: card.cardType.rawValue) ?? .multipleChoice,
                prompt: card.question,
                answer: card.correctAnswer,
                hint: card.hint,
                explanation: "",
                options: options,
                correctAnswerIndex: correctIdx,
                difficulty: "medium",
                tags: card.section != nil ? [card.section!.name] : card.tags,
                sourceExcerpt: card.sourceExcerpt ?? "",
                sourceLocator: card.sourceLocator ?? (card.section?.name ?? ""),
                matchingPairs: pairs
            )
        }
        return GeneratedDeck(
            title: name,
            subject: "General",
            deckKind: deckType,
            detectedLanguage: "en",
            summary: documentCoverageSummary ?? "",
            cards: genCards
        )
    }
}

private extension Data {
    mutating func appendMultipartField(name: String, value: String, boundary: String) {
        append(Data("--\(boundary)\r\n".utf8))
        append(Data("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".utf8))
        append(Data("\(value)\r\n".utf8))
    }

    mutating func appendMultipartFile(
        fieldName: String,
        fileName: String,
        mimeType: String,
        data: Data,
        boundary: String
    ) {
        let safeName = fileName
            .replacingOccurrences(of: "\"", with: "_")
            .replacingOccurrences(of: "\r", with: "_")
            .replacingOccurrences(of: "\n", with: "_")
        append(Data("--\(boundary)\r\n".utf8))
        append(Data("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(safeName)\"\r\n".utf8))
        append(Data("Content-Type: \(mimeType)\r\n\r\n".utf8))
        append(data)
        append(Data("\r\n".utf8))
    }
}
