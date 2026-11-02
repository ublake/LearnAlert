import Foundation
import SwiftUI
import Combine
import Security
import CryptoKit
import UIKit
import AuthenticationServices
import SwiftData

struct CommunityFieldMedia: Codable {
    var imageID: String? = nil
    var audioID: String? = nil
}

struct CommunityCardPayload: Codable, Identifiable {
    let id: String
    let question: String
    let correctAnswer: String
    let options: [String]
    let hint: String
    let cardType: String
    let matchingLeftItems: [String]
    let matchingRightItems: [String]
    let sectionName: String
    var promptImageID: String?
    var optionImageIDs: [String?]
    var promptAudioID: String?
    var answerImageID: String? = nil
    var fieldMedia: [String: CommunityFieldMedia]? = nil
    var correctOptionIndex: Int? = nil
    var ankiContent: AnkiCardContent? = nil
}

struct CommunityDeckPayload: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let authorHandle: String
    let categoryTag: String
    let colorHex: String
    let deckType: String
    let cardCount: Int
    let downloadCount: Int
    let publishedAt: Int?
    var cards: [CommunityCardPayload]?
    var authorAvatar: CommunityAvatar? = nil
    var reviewStatus: String? = nil
    var reviewMessage: String? = nil
    var submittedAt: Int? = nil
    var status: String? = nil
    var adminNote: String? = nil
    var adminAction: String? = nil
    var adminUpdatedAt: Int? = nil
    var isHidden: Bool? = nil
    var authorID: String? = nil
    var likeCount: Int? = nil
    var viewerHasLiked: Bool? = nil
    var ankiMedia: [String: [String: String]]? = nil
    // Optional for cached payloads and servers predating shared-deck media totals.
    var imageCount: Int? = nil
    var audioCount: Int? = nil

    var isRemoved: Bool { status == "deleted" }
}

enum CommunityDeckSort: String, CaseIterable {
    case popular, likes, recent, oldest
    var title: String {
        switch self {
        case .popular: AppLocalization.string("Downloads")
        case .likes: AppLocalization.string("Likes")
        case .recent: AppLocalization.string("Newest first")
        case .oldest: AppLocalization.string("Oldest first")
        }
    }
}

enum CommunityDeckLanguage: String, CaseIterable, Identifiable {
    case all = ""
    case english = "en"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case italian = "it"
    case portuguese = "pt"
    case korean = "ko"
    case japanese = "ja"
    case chinese = "zh"
    case arabic = "ar"

    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: AppLocalization.string("All languages")
        case .english: AppLocalization.string("English")
        case .spanish: AppLocalization.string("Spanish")
        case .french: AppLocalization.string("French")
        case .german: AppLocalization.string("German")
        case .italian: AppLocalization.string("Italian")
        case .portuguese: AppLocalization.string("Portuguese")
        case .korean: AppLocalization.string("Korean")
        case .japanese: AppLocalization.string("Japanese")
        case .chinese: AppLocalization.string("Chinese")
        case .arabic: AppLocalization.string("Arabic")
        }
    }
}

struct CommunityDeckPage: Decodable {
    let decks: [CommunityDeckPayload]
    let nextOffset: Int?
    var totalCount: Int? = nil
}

struct CommunityBlockedUser: Codable, Identifiable, Equatable {
    let id: String
    let handle: String
}

extension Deck {
    /// Provenance survives edits; content matching also catches built-in imports made before tracking existed.
    var isAnkiImport: Bool {
        if sourceKind == "anki" || sourceAnkiDeckID != nil { return true }
        // A bounded lookup covers legacy imports and cards moved into another
        // deck without sorting/faulting a large deck merely to build its menu.
        if let context = modelContext {
            let deckID = id
            var descriptor = FetchDescriptor<Flashcard>(predicate: #Predicate {
                $0.deck?.id == deckID && ($0.sourceAnkiCardID != nil || $0.cardTypeRaw == "anki")
            })
            descriptor.fetchLimit = 1
            descriptor.propertiesToFetch = [\.id]
            if let found = try? context.fetch(descriptor) { return !found.isEmpty }
        }
        return cards.contains { $0.sourceAnkiCardID != nil || $0.cardType == .anki }
    }
    var communitySharingRestriction: String? { sharingRestriction(allowAnkiUploads: false) }

    /// Cheap menu/form gates use provenance only. Legacy content matching still
    /// runs in sharingRestriction immediately before an actual publish request.
    func provenanceSharingRestriction(allowAnkiUploads: Bool) -> String? {
        if !allowAnkiUploads && isAnkiImport {
            return AppLocalization.string("Uploading decks imported from Anki are not supported yet")
        }
        if sourceCommunityID != nil { return AppLocalization.string("Downloaded shared decks can’t be republished. Share a deck you created.") }
        if sourcePremadeID != nil || deckType == "Course" || ["managedLanguage", "languageTopic"].contains(sourceKind ?? "") {
            return AppLocalization.string("Built-in decks can’t be published as shared decks.")
        }
        return nil
    }

    func sharingRestriction(allowAnkiUploads: Bool) -> String? {
        if let reason = provenanceSharingRestriction(allowAnkiUploads: allowAnkiUploads) { return reason }
        let orderedCards = cards
        if !allowAnkiUploads && orderedCards.contains(where: { $0.sourceAnkiCardID != nil || $0.cardType == .anki }) {
            return AppLocalization.string("Uploading decks imported from Anki are not supported yet")
        }
        func key(_ question: String, _ answer: String, _ left: [String], _ right: [String]) -> [String] {
            func normalized(_ text: String) -> String { text.precomposedStringWithCompatibilityMapping.lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ") }
            return [normalized(question), normalized(answer)] + zip(left, right).flatMap { [normalized($0), normalized($1)] }
        }
        let local = Set(orderedCards.map { key($0.question, $0.correctAnswer, $0.matchingLeftItems, $0.matchingRightItems) })
        // Legacy copies predate provenance IDs. New managed imports are protected
        // by sourcePremadeID above; this synchronous fallback uses bundled content.
        if PremadeDeckCatalog.bundledDecks.contains(where: { premade in
            !premade.cards.isEmpty && Set(premade.cards.map { key($0.question, $0.correctAnswer, $0.matchingLeftItems, $0.matchingRightItems) }).isSubset(of: local)
        }) { return AppLocalization.string("Built-in decks can’t be published as shared decks.") }
        return nil
    }

    var canShareToCommunity: Bool { communitySharingRestriction == nil }
    var canPresentCommunitySharing: Bool { provenanceSharingRestriction(allowAnkiUploads: false) == nil }
}

nonisolated struct CommunityAPIError: LocalizedError {
    let status: Int
    let message: String
    var code: String? = nil
    var errorDescription: String? { Self.localizedMessage(message) }

    /// Server protocol values stay stable. Translate only known service messages;
    /// any admin-authored detail is displayed in its original language.
    static func localizedMessage(_ message: String) -> String {
        switch message {
        case "A shared deck can contain up to 100 MB of media and 1,000 attachments.": AppLocalization.string("A shared deck can contain up to 100 MB of media and 1,000 attachments.")
        case "Accept the sharing rules before uploading or submitting a deck.": AppLocalization.string("Accept the sharing rules before uploading or submitting a deck.")
        case "Add a description of 1–2000 characters before sharing.": AppLocalization.string("Add a description of 1–2000 characters before sharing.")
        case "Add text, an image or audio to the answer.": AppLocalization.string("Add text, an image or audio to the answer.")
        case "Add text, an image or audio to the question.": AppLocalization.string("Add text, an image or audio to the question.")
        case "Anki decks support up to 1,000 attachments.": AppLocalization.string("Anki decks support up to 1,000 attachments.")
        case "Anki templates require the Anki card type.": AppLocalization.string("Anki templates require the Anki card type.")
        case "Apple sign-in is temporarily unavailable.": AppLocalization.string("Apple sign-in is temporarily unavailable.")
        case "Attachment field does not belong to this card type.": AppLocalization.string("Attachment field does not belong to this card type.")
        case "Attachment not found.": AppLocalization.string("Attachment not found.")
        case "Author not found.": AppLocalization.string("Author not found.")
        case "Card IDs must be unique.": AppLocalization.string("Card IDs must be unique.")
        case "Choice blanks need a ___ in the sentence.": AppLocalization.string("Choice blanks need a ___ in the sentence.")
        case "Choose a creator name of up to 80 characters.": AppLocalization.string("Choose a creator name of up to 80 characters.")
        case "Choose a profile change.": AppLocalization.string("Choose a profile change.")
        case "Choose a supported language filter.": AppLocalization.string("Choose a supported language filter.")
        case "Choose a username.": AppLocalization.string("Choose a username.")
        case "Choose a valid character.": AppLocalization.string("Choose a valid character.")
        case "Choose a valid community author.": AppLocalization.string("Choose a valid community author.")
        case "Choose a valid developer option.": AppLocalization.string("Choose a valid developer option.")
        case "Choose a valid profile privacy setting.": AppLocalization.string("Choose a valid profile privacy setting.")
        case "Choose a valid skin tone.": AppLocalization.string("Choose a valid skin tone.")
        case "Conflicting media references.": AppLocalization.string("Conflicting media references.")
        case "Couldn’t choose a username just now. Please try again.": AppLocalization.string("Couldn’t choose a username just now. Please try again.")
        case "Custom publishing names require developer access.": AppLocalization.string("Custom publishing names require developer access.")
        case "Deck not found.": AppLocalization.string("Deck not found.")
        case "Developer access is required.": AppLocalization.string("Developer access is required.")
        case "Drag to Answer needs 2–30 text, image or audio tokens in the correct order, without a correct-choice index or matching pairs.": AppLocalization.string("Drag to Answer needs 2–30 text, image or audio tokens in the correct order, without a correct-choice index or matching pairs.")
        case "Endpoint not found.": AppLocalization.string("Endpoint not found.")
        case "Every attachment must be uploaded to this deck before publishing.": AppLocalization.string("Every attachment must be uploaded to this deck before publishing.")
        case "Finish your username and character in Settings before sending a heart.": AppLocalization.string("Finish your username and character in Settings before sending a heart.")
        case "Image cards need a front image, an optional back image, and no question, answer, hint, choices, matching pairs, or audio.": AppLocalization.string("Image cards need a front image, an optional back image, and no question, answer, hint, choices, matching pairs, or audio.")
        case "Invalid Anki media folder.": AppLocalization.string("Invalid Anki media folder.")
        case "Invalid Anki media name.": AppLocalization.string("Invalid Anki media name.")
        case "Invalid Anki media.": AppLocalization.string("Invalid Anki media.")
        case "Invalid Anki template.": AppLocalization.string("Invalid Anki template.")
        case "Invalid answer images.": AppLocalization.string("Invalid answer images.")
        case "Invalid card type.": AppLocalization.string("Invalid card type.")
        case "Invalid card.": AppLocalization.string("Invalid card.")
        case "Invalid deck color.": AppLocalization.string("Invalid deck color.")
        case "Invalid deck.": AppLocalization.string("Invalid deck.")
        case "Invalid deletion request.": AppLocalization.string("Invalid deletion request.")
        case "Invalid field attachments.": AppLocalization.string("Invalid field attachments.")
        case "Invalid media reference.": AppLocalization.string("Invalid media reference.")
        case "Invalid media type.": AppLocalization.string("Invalid media type.")
        case "Invalid sign-in request.": AppLocalization.string("Invalid sign-in request.")
        case "Matching cards need at least two complete text, image or audio pairs.": AppLocalization.string("Matching cards need at least two complete text, image or audio pairs.")
        case "Media uploads are not configured yet.": AppLocalization.string("Media uploads are not configured yet.")
        case "Missing Anki media reference.": AppLocalization.string("Missing Anki media reference.")
        case "Please give a reason for reporting this deck.": AppLocalization.string("Please give a reason for reporting this deck.")
        case "Please sign in with Apple again.": AppLocalization.string("Please sign in with Apple again.")
        case "Please sign in with Apple to continue.": AppLocalization.string("Please sign in with Apple to continue.")
        case "Profile not found.": AppLocalization.string("Profile not found.")
        case "Publish between 1 and 500 cards per deck.": AppLocalization.string("Publish between 1 and 500 cards per deck.")
        case "Quiz cards need 2–4 text, image or audio choices and a correct choice index.": AppLocalization.string("Quiz cards need 2–4 text, image or audio choices and a correct choice index.")
        case "Reauthenticate with Apple before deleting.": AppLocalization.string("Reauthenticate with Apple before deleting.")
        case "Request body must be valid JSON.": AppLocalization.string("Request body must be valid JSON.")
        case "Share a deck you created. Built-in and downloaded community decks can’t be republished.": AppLocalization.string("Share a deck you created. Built-in and downloaded community decks can’t be republished.")
        case "Sign in with Apple again to authorize account deletion.": AppLocalization.string("Sign in with Apple again to authorize account deletion.")
        case "That username is taken. Try another one.": AppLocalization.string("That username is taken. Try another one.")
        case "The community library is not configured yet.": AppLocalization.string("The community library is not configured yet.")
        case "The file does not match its image or audio format.": AppLocalization.string("The file does not match its image or audio format.")
        case "The upload is empty.": AppLocalization.string("The upload is empty.")
        case "These Anki templates are too large to share. Split the deck into smaller decks.": AppLocalization.string("These Anki templates are too large to share. Split the deck into smaller decks.")
        case "These community profiles cannot interact while a block is active.": AppLocalization.string("These community profiles cannot interact while a block is active.")
        case "This community account is banned. Contact contact@learnalertapp.com to appeal.": AppLocalization.string("This community account is banned. Contact contact@learnalertapp.com to appeal.")
        case "This community account is suspended. Contact contact@learnalertapp.com for help.": AppLocalization.string("This community account is suspended. Contact contact@learnalertapp.com for help.")
        case "This community account was removed.": AppLocalization.string("This community account was removed.")
        case "This community content is unavailable.": AppLocalization.string("This community content is unavailable.")
        case "This deck changed. Refresh before deleting it.": AppLocalization.string("This deck changed. Refresh before deleting it.")
        case "This deck has reached its upload capacity. Remove unused attachments or try again after temporary uploads are cleared.": AppLocalization.string("This deck has reached its upload capacity. Remove unused attachments or try again after temporary uploads are cleared.")
        case "This deck was removed while publishing.": AppLocalization.string("This deck was removed while publishing.")
        case "This deck was removed while uploading.": AppLocalization.string("This deck was removed while uploading.")
        case "This matches an existing community deck. Downloaded decks can’t be republished.": AppLocalization.string("This matches an existing community deck. Downloaded decks can’t be republished.")
        case "This upload is too large.": AppLocalization.string("This upload is too large.")
        case "Uploading decks imported from Anki are not supported yet": AppLocalization.string("Uploading decks imported from Anki are not supported yet")
        case "Use 3–24 letters, numbers or underscores, starting with a letter.": AppLocalization.string("Use 3–24 letters, numbers or underscores, starting with a letter.")
        case "Use JPEG/PNG images or MP3/M4A/WAV audio.": AppLocalization.string("Use JPEG/PNG images or MP3/M4A/WAV audio.")
        case "Use correctOptionIndex for media-only or duplicate answer text.": AppLocalization.string("Use correctOptionIndex for media-only or duplicate answer text.")
        case "Use the Apple account associated with this community profile.": AppLocalization.string("Use the Apple account associated with this community profile.")
        case "You can have 50 shared decks and create up to 20 per day.": AppLocalization.string("You can have 50 shared decks and create up to 20 per day.")
        case "You cannot block your own profile.": AppLocalization.string("You cannot block your own profile.")
        case "You cannot heart your own deck.": AppLocalization.string("You cannot heart your own deck.")
        case "Your block list is full. Unblock an author first.": AppLocalization.string("Your block list is full. Unblock an author first.")
        case "Your username is permanent. You can still change your character.": AppLocalization.string("Your username is permanent. You can still change your character.")
        default: message
        }
    }
}

struct CommunityAPI {
    let baseURL: URL
    let session: URLSession

    init(baseURL: URL = URL(string: "https://api.learnalertapp.com")!, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    struct SignInResult: Codable {
        let token: String
        let expiresAt: Int
        var handle: String
        var profile: CommunityProfile? = nil
        var appleUserID: String? = nil
    }
    struct IDResult: Decodable { let id: String }
    struct SuccessResult: Decodable { let success: Bool }
    struct DeckResult: Decodable { let deck: CommunityDeckPayload }
    struct Metadata: Encodable {
        let name: String
        let description: String
        let categoryTag: String
        let colorHex: String
        let deckType: String
        var acceptedRules = false
    }
    struct PublishBody: Encodable {
        let name: String
        let description: String
        let categoryTag: String
        let colorHex: String
        let deckType: String
        let cards: [CommunityCardPayload]
        var origin = "personal"
        var publisherHandle: String? = nil
        var ankiMedia: [String: [String: String]]? = nil
        var acceptedRules = false
    }

    struct AppleReauthentication: Encodable {
        let identityToken: String
        let authorizationCode: String
        let nonce: String
    }

    func signIn(identityToken: String, nonce: String, givenName: String?, authorizationCode: String? = nil) async throws -> SignInResult {
        struct Body: Encodable { let identityToken: String; let nonce: String; let givenName: String?; let authorizationCode: String? }
        return try await jsonRequest("auth/apple", method: "POST", body: Body(identityToken: identityToken, nonce: nonce, givenName: givenName, authorizationCode: authorizationCode))
    }

    func list(search: String, category: String, language: CommunityDeckLanguage = .all, offset: Int = 0, sort: CommunityDeckSort = .recent, limit: Int = 30, token: String? = nil) async throws -> CommunityDeckPage {
        var components = URLComponents(url: endpoint("decks"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "q", value: search),
                                 URLQueryItem(name: "category", value: category == "All" ? "" : category),
                                 URLQueryItem(name: "language", value: language.rawValue),
                                 URLQueryItem(name: "offset", value: String(offset)),
                                 URLQueryItem(name: "sort", value: sort.rawValue),
                                 URLQueryItem(name: "limit", value: String(limit))]
        return try await decoded(viewerRequest(components.url!, token: token))
    }

    func profile(token: String) async throws -> CommunityProfile {
        var request = URLRequest(url: endpoint("account"))
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return try await decoded(request)
    }

    func saveProfile(username: String, avatar: CommunityAvatar, token: String) async throws -> CommunityProfile {
        struct Body: Encodable { let username: String; let avatar: CommunityAvatar }
        return try await jsonRequest("account", method: "PUT", body: Body(username: username, avatar: avatar), token: token)
    }

    func saveProfilePrivacy(hideStatsPublicly: Bool, token: String) async throws -> CommunityProfile {
        struct Body: Encodable { let hideStatsPublicly: Bool }
        return try await jsonRequest("account", method: "PUT", body: Body(hideStatsPublicly: hideStatsPublicly), token: token)
    }

    func saveDeveloperOptions(allowAnkiUploads: Bool, token: String) async throws -> CommunityProfile {
        struct Body: Encodable { let allowAnkiUploads: Bool }
        return try await jsonRequest("account/developer", method: "PUT", body: Body(allowAnkiUploads: allowAnkiUploads), token: token)
    }

    func publicProfile(authorID: String, offset: Int = 0, limit: Int = 20, token: String? = nil) async throws -> CommunityPublicProfilePage {
        var components = URLComponents(url: endpoint("profiles/\(authorID)"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "offset", value: String(offset)), URLQueryItem(name: "limit", value: String(limit))]
        return try await decoded(viewerRequest(components.url!, token: token))
    }

    func setLike(deckID: String, liked: Bool, token: String) async throws -> CommunityLikeResult {
        var request = viewerRequest(endpoint("decks/\(deckID)/like"), token: token)
        request.httpMethod = liked ? "PUT" : "DELETE"
        return try await decoded(request)
    }

    func receivedLikes(offset: Int = 0, limit: Int = 20, token: String) async throws -> CommunityLikesPage {
        var components = URLComponents(url: endpoint("account/likes"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "offset", value: String(offset)), URLQueryItem(name: "limit", value: String(limit))]
        return try await decoded(viewerRequest(components.url!, token: token))
    }

    func myDecks(token: String) async throws -> CommunityDeckPage {
        var decks: [CommunityDeckPayload] = []
        var offset = 0
        var totalCount: Int?
        while true {
            try Task.checkCancellation()
            var components = URLComponents(url: endpoint("account/decks"), resolvingAgainstBaseURL: false)!
            if offset > 0 { components.queryItems = [URLQueryItem(name: "offset", value: String(offset))] }
            var request = URLRequest(url: components.url!)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            let page: CommunityDeckPage = try await decoded(request)
            decks.append(contentsOf: page.decks)
            totalCount = page.totalCount ?? totalCount
            guard let next = page.nextOffset else { break }
            guard next > offset else { throw URLError(.cannotParseResponse) }
            offset = next
        }
        return CommunityDeckPage(decks: decks, nextOffset: nil, totalCount: totalCount)
    }

    func preview(deckID: String, token: String? = nil) async throws -> CommunityDeckPayload {
        let result: DeckResult = try await decoded(viewerRequest(endpoint("decks/\(deckID)/preview"), token: token))
        return result.deck
    }

    func draft(metadata: Metadata, token: String) async throws -> String {
        let result: IDResult = try await jsonRequest("decks/drafts", method: "POST", body: metadata, token: token)
        return result.id
    }

    func upload(_ data: Data, contentType: String, deckID: String, token: String, acceptedRules: Bool = false) async throws -> String {
        guard acceptedRules else {
            throw CommunityAPIError(status: 400, message: AppLocalization.string("Accept the sharing rules before uploading."), code: "COMMUNITY_RULES_REQUIRED")
        }
        var request = URLRequest(url: endpoint("decks/\(deckID)/media"))
        request.httpMethod = "POST"
        request.timeoutInterval = 180
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("true", forHTTPHeaderField: "X-Community-Rules-Accepted")
        let (responseData, response) = try await session.upload(for: request, from: data)
        try validate(responseData, response: response)
        return try JSONDecoder().decode(IDResult.self, from: responseData).id
    }

    func publish(_ body: PublishBody, deckID: String, token: String) async throws {
        let _: IDResult = try await jsonRequest("decks/\(deckID)", method: "PUT", body: body, token: token)
    }

    func remove(deckID: String, token: String) async throws {
        var request = URLRequest(url: endpoint("decks/\(deckID)"))
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let _: SuccessResult = try await decoded(request)
    }

    func deleteAccount(token: String, reauthentication: AppleReauthentication? = nil) async throws {
        var request = URLRequest(url: endpoint("account"))
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let reauthentication {
            request.httpBody = try JSONEncoder().encode(reauthentication)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let _: SuccessResult = try await decoded(request)
    }

    func blockedUsers(token: String) async throws -> [CommunityBlockedUser] {
        struct Result: Decodable { let users: [CommunityBlockedUser] }
        let result: Result = try await decoded(viewerRequest(endpoint("account/blocks"), token: token))
        return result.users
    }

    func block(authorID: String, token: String) async throws {
        struct Body: Encodable { let authorID: String }
        let _: SuccessResult = try await jsonRequest("account/blocks", method: "POST", body: Body(authorID: authorID), token: token)
    }

    func unblock(authorID: String, token: String) async throws {
        var request = viewerRequest(endpoint("account/blocks/\(authorID)"), token: token)
        request.httpMethod = "DELETE"
        let _: SuccessResult = try await decoded(request)
    }

    func detail(deckID: String, token: String? = nil) async throws -> CommunityDeckPayload {
        let result: DeckResult = try await decoded(viewerRequest(endpoint("decks/\(deckID)"), token: token))
        return result.deck
    }

    func report(deckID: String, reason: String, token: String) async throws {
        struct Body: Encodable { let reason: String }
        let _: SuccessResult = try await jsonRequest("decks/\(deckID)/reports", method: "POST", body: Body(reason: reason), token: token)
    }

    func media(id: String, maximumBytes: Int, token: String? = nil) async throws -> Data {
        let (data, response) = try await session.data(for: viewerRequest(endpoint("media/\(id)"), token: token))
        try validate(data, response: response)
        guard data.count <= maximumBytes else { throw CommunityAPIError(status: 413, message: AppLocalization.string("This attachment is too large.")) }
        return data
    }

    private func endpoint(_ path: String) -> URL { baseURL.appendingPathComponent("v1/community/\(path)") }

    private func viewerRequest(_ url: URL, token: String?) -> URLRequest {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        return request
    }

    private func jsonRequest<Body: Encodable, Result: Decodable>(_ path: String, method: String, body: Body, token: String? = nil) async throws -> Result {
        var request = URLRequest(url: endpoint(path))
        request.httpMethod = method
        request.httpBody = try JSONEncoder().encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        return try await decoded(request)
    }

    private func decoded<Result: Decodable>(_ request: URLRequest) async throws -> Result {
        let (data, response) = try await session.data(for: request)
        try validate(data, response: response)
        return try JSONDecoder().decode(Result.self, from: data)
    }

    private func validate(_ data: Data, response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200..<300).contains(http.statusCode) else {
            struct Envelope: Decodable { struct Failure: Decodable { let message: String; let code: String? }; let error: Failure }
            let failure = try? JSONDecoder().decode(Envelope.self, from: data)
            let message = failure?.error.message
                ?? AppLocalization.string("Shared decks are unavailable. Please try again.")
            throw CommunityAPIError(status: http.statusCode, message: message, code: failure?.error.code)
        }
    }
}

@MainActor
protocol CommunityCredentialStorage: AnyObject {
    func load() -> Data?
    func save(_ data: Data) throws
    func delete()
}

@MainActor
final class CommunitySession: ObservableObject {
    static let shared = CommunitySession()
    @Published private(set) var credentials: CommunityAPI.SignInResult?
    @Published var isSigningIn = false
    @Published var errorMessage: String?
    private let service: String
    private let credentialStorage: CommunityCredentialStorage?
    private let api: CommunityAPI
    private let credentialState: (String) async throws -> ASAuthorizationAppleIDProvider.CredentialState

    var isSignedIn: Bool { credentials.map { $0.expiresAt > Int(Date().timeIntervalSince1970) } ?? false }
    var handle: String { credentials?.handle ?? "" }
    var token: String? { isSignedIn ? credentials?.token : nil }
    var profile: CommunityProfile { credentials?.profile ?? CommunityProfile(handle: handle, avatar: .init(), isComplete: false) }
    var isDeveloper: Bool { isSignedIn && profile.isDeveloper == true }
    var canUploadAnki: Bool { isDeveloper && profile.allowAnkiUploads == true }
    var needsProfileSetup: Bool { isSignedIn && !profile.isComplete }
    var isRestricted: Bool { profile.accountStatus == "banned" || profile.accountStatus == "suspended" }

    init(service: String = "com.learnalert.community", api: CommunityAPI? = nil, credentialStorage: CommunityCredentialStorage? = nil,
         credentialState: @escaping (String) async throws -> ASAuthorizationAppleIDProvider.CredentialState = { userID in
             try await ASAuthorizationAppleIDProvider().credentialState(forUserID: userID)
         }) {
        self.service = service
        self.api = api ?? CommunityAPI()
        self.credentialState = credentialState
        self.credentialStorage = credentialStorage
        if let credentialStorage {
            if let data = credentialStorage.load() { credentials = try? JSONDecoder().decode(CommunityAPI.SignInResult.self, from: data) }
        } else {
            var query = keychainQuery
            query[kSecReturnData as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitOne
            var result: CFTypeRef?
            if SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data {
                credentials = try? JSONDecoder().decode(CommunityAPI.SignInResult.self, from: data)
            }
        }
    }

    private var keychainQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: "session"]
    }

    private func persist(_ result: CommunityAPI.SignInResult) throws {
        let data = try JSONEncoder().encode(result)
        if let credentialStorage {
            try credentialStorage.save(data)
        } else {
            var update: [String: Any] = [kSecValueData as String: data]
            update[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let status = SecItemUpdate(keychainQuery as CFDictionary, update as CFDictionary)
            if status == errSecItemNotFound {
                var item = keychainQuery
                for (key, value) in update { item[key] = value }
                guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else {
                    throw CommunityAPIError(status: 500, message: AppLocalization.string("Your profile could not be saved securely. Please try again."))
                }
            } else if status != errSecSuccess {
                throw CommunityAPIError(status: 500, message: AppLocalization.string("Your profile could not be saved securely. Please try again."))
            }
        }
        credentials = result
    }

    @discardableResult
    func signIn(identityToken: String, nonce: String, givenName: String?, authorizationCode: String? = nil, appleUserID: String? = nil) async -> Bool {
        isSigningIn = true
        errorMessage = nil
        defer { isSigningIn = false }
        do {
            var result = try await api.signIn(identityToken: identityToken, nonce: nonce, givenName: givenName, authorizationCode: authorizationCode)
            result.appleUserID = appleUserID
            try persist(result)
            return true
        } catch { errorMessage = error.localizedDescription; return false }
    }

    func refreshProfile() async {
        guard let token else { return }
        do {
            let profile = try await api.profile(token: token)
            guard var result = credentials, self.token == token else { return }
            result.profile = profile; result.handle = profile.handle
            try persist(result)
        } catch { if self.token == token { handle(error) } }
    }

    func validateAppleCredential() async {
        guard let token else { return }
        if let userID = credentials?.appleUserID {
            do {
                let state = try await credentialState(userID)
                guard self.token == token, !Task.isCancelled else { return }
                if state == .revoked || state == .notFound || state == .transferred {
                    appleCredentialRevoked()
                    return
                }
            } catch {
                // A temporary Apple connectivity failure must not delete a valid local session.
            }
        }
        guard self.token == token, !Task.isCancelled else { return }
        await refreshProfile()
    }

    func appleCredentialRevoked() {
        signOut()
        errorMessage = AppLocalization.string("Apple access changed. Sign in again to use your community account.")
    }

    func saveProfile(username: String, avatar: CommunityAvatar) async throws {
        guard let token else { throw CommunityAPIError(status: 401, message: AppLocalization.string("Sign in with Apple to save your profile.")) }
        do {
            let profile = try await api.saveProfile(username: username, avatar: avatar, token: token)
            guard var result = credentials, self.token == token else { throw CancellationError() }
            result.profile = profile; result.handle = profile.handle
            try persist(result)
            errorMessage = nil
            NotificationCenter.default.post(name: .communityLibraryChanged, object: nil)
        } catch { if self.token == token { handle(error) }; throw error }
    }

    func saveProfilePrivacy(hideStatsPublicly: Bool) async throws {
        guard let token else { throw CommunityAPIError(status: 401, message: AppLocalization.string("Sign in with Apple to update your profile.")) }
        do {
            let profile = try await api.saveProfilePrivacy(hideStatsPublicly: hideStatsPublicly, token: token)
            guard var result = credentials, self.token == token else { throw CancellationError() }
            result.profile = profile
            result.handle = profile.handle
            try persist(result)
            errorMessage = nil
            NotificationCenter.default.post(name: .communityLibraryChanged, object: nil)
        } catch { if self.token == token { handle(error) }; throw error }
    }

    func saveDeveloperOptions(allowAnkiUploads: Bool) async throws {
        guard let token else { throw CommunityAPIError(status: 401, message: AppLocalization.string("Sign in to change developer options.")) }
        let profile = try await api.saveDeveloperOptions(allowAnkiUploads: allowAnkiUploads, token: token)
        guard var result = credentials, self.token == token else { throw CancellationError() }
        result.profile = profile
        try persist(result)
    }

    func signOut() {
        if let credentialStorage { credentialStorage.delete() } else { SecItemDelete(keychainQuery as CFDictionary) }
        credentials = nil
        errorMessage = nil
    }

    /// Apple can revoke the local credential before the successful DELETE response arrives.
    func completeAccountDeletion(token: String) -> Bool {
        guard credentials == nil || credentials?.token == token else { return false }
        signOut()
        return true
    }

    func handle(_ error: Error) {
        if let apiError = error as? CommunityAPIError, apiError.status == 401 {
            if let credentialStorage { credentialStorage.delete() } else { SecItemDelete(keychainQuery as CFDictionary) }
            credentials = nil
        } else if let apiError = error as? CommunityAPIError,
                  ["ACCOUNT_BANNED", "ACCOUNT_SUSPENDED"].contains(apiError.code?.uppercased() ?? ""),
                  var result = credentials {
            var profile = self.profile
            profile.accountStatus = apiError.code?.uppercased() == "ACCOUNT_BANNED" ? "banned" : "suspended"
            profile.restrictionMessage = apiError.message
            result.profile = profile
            try? persist(result)
        }
        errorMessage = error.localizedDescription
    }

    static func makeNonce() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            return UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
                + UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        }
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    static func hashedNonce(_ nonce: String) -> String {
        SHA256.hash(data: Data(nonce.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

@MainActor
enum CommunityDeckTransfer {
    private struct Upload {
        let key: String
        let data: Data
        let contentType: String
    }

    static func publish(deck: Deck, category: String, description: String, token: String, publisherHandle: String? = nil,
                        acceptedRules: Bool = false,
                        api: CommunityAPI? = nil,
                        progress: @escaping (String) -> Void) async throws -> String {
        guard acceptedRules else {
            throw CommunityAPIError(status: 400, message: AppLocalization.string("Accept the sharing rules before uploading."), code: "COMMUNITY_RULES_REQUIRED")
        }
        let description = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !description.isEmpty, description.utf16.count <= 2000 else {
            throw CommunityAPIError(status: 400, message: AppLocalization.string("Add a description between 1 and 2,000 characters."), code: "COMMUNITY_DESCRIPTION_REQUIRED")
        }
        let api = api ?? CommunityAPI()
        if let reason = deck.sharingRestriction(allowAnkiUploads: false) {
            throw CommunityAPIError(status: 403, message: reason)
        }
        let profile = publisherHandle?.isEmpty == false ? try await api.profile(token: token) : nil
        if publisherHandle?.isEmpty == false && profile?.isDeveloper != true {
            throw CommunityAPIError(status: 403, message: AppLocalization.string("Custom publishing names require developer access."))
        }
        guard !deck.cards.isEmpty, deck.cards.count <= 500 else {
            throw CommunityAPIError(status: 400, message: AppLocalization.string("Publish between 1 and 500 cards per deck."))
        }
        let metadata = CommunityAPI.Metadata(name: deck.name, description: description, categoryTag: category,
                                             colorHex: deck.colorHex, deckType: deck.deckType, acceptedRules: acceptedRules)
        // Capture the deck before suspension, and verify all local media before creating a draft.
        var uploads: [Upload] = []
        var seen = Set<String>()
        func imageKey(_ name: String?) throws -> String? {
            guard let name, !name.isEmpty else { return nil }
            let key = "image:\(name)"
            if !seen.contains(key) {
                guard let image = CardImageStore.loadImage(named: name), let data = image.jpegData(compressionQuality: 0.82) else {
                    throw CommunityAPIError(status: 400, message: AppLocalization.string("A card image is missing. Reattach it before publishing."))
                }
                guard data.count <= 10 * 1024 * 1024 else { throw CommunityAPIError(status: 413, message: AppLocalization.string("Each image must be under 10 MB.")) }
                uploads.append(Upload(key: key, data: data, contentType: "image/jpeg"))
                seen.insert(key)
            }
            return key
        }
        func audioKey(_ name: String?) throws -> String? {
            guard let name, !name.isEmpty else { return nil }
            let key = "audio:\(name)"
            if !seen.contains(key) {
                let data = try Data(contentsOf: CardAudioStore.url(named: name))
                guard data.count <= CardAudioStore.maximumBytes else { throw CommunityAPIError(status: 413, message: AppLocalization.string("Each audio clip must be under 20 MB.")) }
                uploads.append(Upload(key: key, data: data, contentType: try CardAudioStore.contentType(for: name)))
                seen.insert(key)
            }
            return key
        }
        var ankiMedia: [String: [String: String]] = [:]
        var templateBytes = 0
        var cards: [CommunityCardPayload] = []
        for card in deck.cards {
            if let content = card.ankiContent {
                templateBytes += content.frontHTML.utf8.count + content.backHTML.utf8.count + content.css.utf8.count
                guard templateBytes <= 1024 * 1024 else {
                    throw CommunityAPIError(status: 413, message: AppLocalization.string("These Anki templates are too large to share. Split the deck into smaller decks."))
                }
            }
            if let content = card.ankiContent, ankiMedia[content.mediaFolder] == nil {
                guard let directory = content.mediaURL else { throw CommunityAPIError(status: 400, message: AppLocalization.string("Anki media is unavailable. Re-import the deck.")) }
                let index = AnkiCardContent.mediaIndex(in: directory)
                var media: [String: String] = [:]
                let names = index.isEmpty ? try FileManager.default.contentsOfDirectory(atPath: directory.path).filter { !$0.hasPrefix(".") } : Array(index.keys)
                for name in names {
                    guard let url = AnkiCardContent.safeMediaURL(name: name, directory: directory, index: index),
                          let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= 20 * 1024 * 1024 else {
                        throw CommunityAPIError(status: 400, message: AppLocalization.string("An Anki attachment is missing or exceeds 20 MB."))
                    }
                    guard uploads.count < 1000, uploads.reduce(0, { $0 + $1.data.count }) + size <= 100 * 1024 * 1024 else {
                        throw CommunityAPIError(status: 413, message: AppLocalization.string("A shared deck supports up to 100 MB of media and 1,000 attachments."))
                    }
                    let key = "anki:\(content.mediaFolder):\(name)"
                    uploads.append(Upload(key: key, data: try Data(contentsOf: url), contentType: "application/octet-stream"))
                    media[name] = key
                }
                ankiMedia[content.mediaFolder] = media
            }
            var fields: [String: CommunityFieldMedia] = [:]
            for (key, attachment) in card.fieldMedia {
                fields[key] = .init(imageID: try imageKey(attachment.image), audioID: try audioKey(attachment.audio))
            }
            cards.append(CommunityCardPayload(id: card.id.uuidString, question: card.question, correctAnswer: card.correctAnswer,
                options: card.options, hint: card.hint, cardType: card.cardType.rawValue,
                matchingLeftItems: card.matchingLeftItems, matchingRightItems: card.matchingRightItems,
                sectionName: card.section?.name ?? "", promptImageID: fields["prompt"]?.imageID,
                optionImageIDs: card.options.indices.map { fields["option:\($0)"]?.imageID }, promptAudioID: fields["prompt"]?.audioID,
                answerImageID: fields["answer"]?.imageID, fieldMedia: fields, correctOptionIndex: card.resolvedCorrectOptionIndex, ankiContent: card.ankiContent))
        }
        guard uploads.reduce(0, { $0 + $1.data.count }) <= 100 * 1024 * 1024 else {
            throw CommunityAPIError(status: 413, message: AppLocalization.string("A shared deck can contain up to 100 MB of images and audio."))
        }
        progress(AppLocalization.string("Preparing your deck…"))
        let existingID: String?
        if let previousID = deck.publishedCommunityID {
            // A device library can outlive an Apple account change or a public removal.
            // Only update an existing publication when it belongs to the signed-in account.
            let owned = try await api.myDecks(token: token)
            existingID = owned.decks.contains { $0.id == previousID && !$0.isRemoved } ? previousID : nil
        } else { existingID = nil }
        let id: String
        if let existingID { id = existingID }
        else { id = try await api.draft(metadata: metadata, token: token) }
        do {
            var remoteIDs: [String: String] = [:]
            for (index, upload) in uploads.enumerated() {
                try Task.checkCancellation()
                progress(AppLocalization.string("Uploading attachment \(index + 1) of \(uploads.count)…"))
                remoteIDs[upload.key] = try await api.upload(upload.data, contentType: upload.contentType, deckID: id, token: token, acceptedRules: acceptedRules)
            }
            for index in cards.indices {
                cards[index].promptImageID = cards[index].promptImageID.flatMap { remoteIDs[$0] }
                cards[index].optionImageIDs = cards[index].optionImageIDs.map { $0.flatMap { remoteIDs[$0] } }
                cards[index].promptAudioID = cards[index].promptAudioID.flatMap { remoteIDs[$0] }
                cards[index].answerImageID = cards[index].answerImageID.flatMap { remoteIDs[$0] }
                cards[index].fieldMedia = cards[index].fieldMedia?.mapValues { .init(imageID: $0.imageID.flatMap { remoteIDs[$0] }, audioID: $0.audioID.flatMap { remoteIDs[$0] }) }

            }
            progress(AppLocalization.string("Submitting for review…"))
            let remoteAnkiMedia = ankiMedia.mapValues { $0.compactMapValues { remoteIDs[$0] } }
            try await api.publish(.init(name: metadata.name, description: metadata.description, categoryTag: metadata.categoryTag,
                colorHex: metadata.colorHex, deckType: metadata.deckType, cards: cards, origin: deck.isAnkiImport ? "anki" : "personal",
                publisherHandle: publisherHandle, ankiMedia: remoteAnkiMedia.isEmpty ? nil : remoteAnkiMedia,
                acceptedRules: acceptedRules), deckID: id, token: token)
            return id
        } catch {
            if existingID == nil { try? await api.remove(deckID: id, token: token) }
            throw error
        }
    }

    static func download(_ summary: CommunityDeckPayload, api: CommunityAPI? = nil, token: String? = nil, progress: @escaping (String) -> Void) async throws -> PremadeDeck {
        let api = api ?? CommunityAPI()
        try Task.checkCancellation()
        let detail = try await api.detail(deckID: summary.id, token: token)
        guard let cards = detail.cards else { throw URLError(.cannotParseResponse) }
        try Task.checkCancellation()
        // Plan every reference before starting requests. Legacy columns, field
        // media and Anki filenames can all refer to the same remote attachment.
        var attachments: [String: CommunityDownloadAttachment] = [:]
        func addImage(_ id: String?) {
            guard let id else { return }
            attachments[id, default: .init(id: id)].image = true
        }
        func addAudio(_ id: String?) {
            guard let id else { return }
            attachments[id, default: .init(id: id)].audio = true
        }
        var ankiGroups = Set((detail.ankiMedia ?? [:]).keys)
        for card in cards {
            addImage(card.promptImageID)
            addImage(card.answerImageID)
            for id in card.optionImageIDs { addImage(id) }
            addAudio(card.promptAudioID)
            for attachment in (card.fieldMedia ?? [:]).values {
                addImage(attachment.imageID)
                addAudio(attachment.audioID)
            }
            if let content = card.ankiContent { ankiGroups.insert(content.mediaFolder) }
        }
        for (group, files) in detail.ankiMedia ?? [:] {
            for (name, id) in files {
                guard !name.isEmpty, name != ".", name != "..", !name.contains("/"), !name.contains("\\"), !name.unicodeScalars.contains(where: { $0.value < 32 }) else { throw URLError(.cannotParseResponse) }
                attachments[id, default: .init(id: id)].ankiFiles.append(.init(group: group, name: name))
            }
        }
        let storage = CommunityDownloadStorage()
        do {
            try await storage.prepareAnkiGroups(ankiGroups)
            let requests = Array(attachments.values)
            // Bound both responses in memory and work in flight. A completed
            // request is replaced immediately instead of waiting for a batch.
            try await withThrowingTaskGroup(of: Void.self) { group in
                var next = 0
                func enqueue() {
                    let attachment = requests[next]
                    next += 1
                    group.addTask {
                        try Task.checkCancellation()
                        let data = try await api.media(id: attachment.id, maximumBytes: attachment.maximumBytes, token: token)
                        try await storage.save(data, attachment: attachment)
                    }
                }
                for _ in 0..<min(4, requests.count) { enqueue() }
                var completed = 0
                while try await group.next() != nil {
                    try Task.checkCancellation()
                    completed += 1
                    progress(AppLocalization.string("Downloading deck…") + " \(completed.formatted(.number.locale(AppLocalization.locale)))/\(requests.count.formatted(.number.locale(AppLocalization.locale)))")
                    if next < requests.count { enqueue() }
                }
            }
            let media = try await storage.finish()
            var imported: [PremadeCard] = []
            imported.reserveCapacity(cards.count)
            for (index, card) in cards.enumerated() {
                try Task.checkCancellation()
                progress(AppLocalization.string("Downloading card \(index + 1) of \(cards.count)…"))
                let prompt = card.promptImageID.flatMap { media.images[$0] }
                let answer = card.answerImageID.flatMap { media.images[$0] }
                let options = card.optionImageIDs.map { $0.flatMap { media.images[$0] } ?? "" }
                let clip = card.promptAudioID.flatMap { media.audio[$0] }
                var fields: [String: CardFieldMedia] = [:]
                for (key, attachment) in card.fieldMedia ?? [:] {
                    fields[key] = .init(image: attachment.imageID.flatMap { media.images[$0] }, audio: attachment.audioID.flatMap { media.audio[$0] })
                }
                // Older public decks have only the original attachment columns.
                fields["prompt"] = fields["prompt"] ?? .init(image: prompt, audio: clip)
                fields["answer"] = fields["answer"] ?? .init(image: answer)
                for (i, name) in options.enumerated() where !name.isEmpty && fields["option:\(i)"] == nil { fields["option:\(i)"] = .init(image: name) }

                var ankiContent = card.ankiContent
                if var content = ankiContent {
                    guard let folder = media.ankiFolders[content.mediaFolder] else { throw URLError(.cannotParseResponse) }
                    content.mediaFolder = folder
                    ankiContent = content
                }
                imported.append(PremadeCard(id: card.id, question: card.question, options: card.options,
                    correctAnswer: card.correctAnswer, hint: card.hint,
                    cardType: FlashcardType(rawValue: card.cardType) ?? .tapReveal,
                    matchingLeftItems: card.matchingLeftItems, matchingRightItems: card.matchingRightItems,
                    promptImageName: prompt, answerImageName: answer, optionImageNames: options, promptAudioName: clip, fieldMedia: fields, correctOptionIndex: card.correctOptionIndex, sectionName: card.sectionName, ankiContent: ankiContent))
            }
            try Task.checkCancellation()
            return PremadeDeck(id: detail.id, name: detail.name, category: detail.categoryTag, subcategory: detail.categoryTag,
                description: detail.description, colorHex: detail.colorHex, deckType: detail.deckType, cards: imported, communitySourceID: detail.id)
        } catch {
            // A throwing task group waits for its cancelled children before
            // reaching this ledger, including files saved by an unconsumed result.
            await storage.removeAll()
            throw error
        }
    }
}

private nonisolated struct CommunityDownloadAttachment: Sendable {
    struct AnkiFile: Sendable {
        let group: String
        let name: String
    }
    let id: String
    var image = false
    var audio = false
    var ankiFiles: [AnkiFile] = []
    var maximumBytes: Int { image ? 10 * 1024 * 1024 : CardAudioStore.maximumBytes }
}

private nonisolated struct CommunityDownloadedMedia: Sendable {
    var images: [String: String] = [:]
    var audio: [String: String] = [:]
    var ankiFolders: [String: String] = [:]
}

/// Keep image rendering, audio validation and filesystem work off the UI actor.
/// The ledger owns every new file until the complete deck can be returned.
private actor CommunityDownloadStorage {
    private var media = CommunityDownloadedMedia()
    private var files: [URL] = []
    private var directories: [String: URL] = [:]
    private var indexes: [String: [String: String]] = [:]
    private var ankiBytes = 0

    func prepareAnkiGroups(_ groups: Set<String>) throws {
        for group in groups {
            try Task.checkCancellation()
            let folder = UUID().uuidString
            let directory = AnkiCardContent.mediaRoot.appendingPathComponent(folder, isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            directories[group] = directory
            indexes[group] = [:]
            media.ankiFolders[group] = folder
        }
    }

    func save(_ data: Data, attachment: CommunityDownloadAttachment) throws {
        try Task.checkCancellation()
        ankiBytes += data.count * attachment.ankiFiles.count
        guard ankiBytes <= 100 * 1024 * 1024 else {
            throw URLError(.dataLengthExceedsMaximum)
        }
        if attachment.image {
            guard let image = UIImage(data: data), let name = CardImageStore.saveImage(image) else {
                throw CommunityAPIError(status: 400, message: AppLocalization.string("A deck image could not be downloaded."))
            }
            files.append(CardImageStore.imagesDirectoryURL.appendingPathComponent(name))
            media.images[attachment.id] = name
        }
        if attachment.audio {
            let name = try CardAudioStore.saveDownloaded(data)
            files.append(CardAudioStore.directory.appendingPathComponent(name))
            media.audio[attachment.id] = name
        }
        for target in attachment.ankiFiles {
            try Task.checkCancellation()
            guard let directory = directories[target.group] else { throw URLError(.cannotParseResponse) }
            let filename = UUID().uuidString + "." + URL(fileURLWithPath: target.name).pathExtension
            try data.write(to: directory.appendingPathComponent(filename), options: .atomic)
            indexes[target.group, default: [:]][target.name] = filename
        }
        try Task.checkCancellation()
    }

    func finish() throws -> CommunityDownloadedMedia {
        for (group, directory) in directories {
            try Task.checkCancellation()
            try JSONEncoder().encode(indexes[group] ?? [:])
                .write(to: directory.appendingPathComponent(".learnalert-media.json"), options: .atomic)
        }
        return media
    }

    func removeAll() {
        for url in files + Array(directories.values) { try? FileManager.default.removeItem(at: url) }
    }
}
