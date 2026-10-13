import Foundation
import SwiftUI
import Combine
import Security
import CryptoKit
import UIKit

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

    var isRemoved: Bool { status == "deleted" }
}

enum CommunityDeckSort: String, CaseIterable {
    case popular, recent
    var title: String { self == .popular ? "Popular" : "Recent" }
}

struct CommunityDeckPage: Decodable {
    let decks: [CommunityDeckPayload]
    let nextOffset: Int?
    var totalCount: Int? = nil
}

extension Deck {
    /// Provenance survives edits; content matching also catches built-in imports made before tracking existed.
    var communitySharingRestriction: String? {
        if sourceCommunityID != nil { return "Downloaded community decks can’t be republished. Share a deck you created." }
        if sourcePremadeID != nil || deckType == "Course" { return "Built-in decks and courses can’t be published to the community." }
        func key(_ question: String, _ answer: String, _ left: [String], _ right: [String]) -> [String] {
            func normalized(_ text: String) -> String { text.precomposedStringWithCompatibilityMapping.lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ") }
            return [normalized(question), normalized(answer)] + zip(left, right).flatMap { [normalized($0), normalized($1)] }
        }
        let local = Set(cards.map { key($0.question, $0.correctAnswer, $0.matchingLeftItems, $0.matchingRightItems) })
        if PremadeDeckCatalog.decks.contains(where: { premade in
            !premade.cards.isEmpty && Set(premade.cards.map { key($0.question, $0.correctAnswer, $0.matchingLeftItems, $0.matchingRightItems) }).isSubset(of: local)
        }) { return "Built-in decks can’t be published to the community." }
        return nil
    }

    var canShareToCommunity: Bool { communitySharingRestriction == nil }
}

struct CommunityAPIError: LocalizedError {
    let status: Int
    let message: String
    var errorDescription: String? { message }
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
    }
    struct PublishBody: Encodable {
        let name: String
        let description: String
        let categoryTag: String
        let colorHex: String
        let deckType: String
        let cards: [CommunityCardPayload]
        var origin = "personal"
    }

    func signIn(identityToken: String, nonce: String, givenName: String?) async throws -> SignInResult {
        struct Body: Encodable { let identityToken: String; let nonce: String; let givenName: String? }
        return try await jsonRequest("auth/apple", method: "POST", body: Body(identityToken: identityToken, nonce: nonce, givenName: givenName))
    }

    func list(search: String, category: String, offset: Int = 0, sort: CommunityDeckSort = .recent, limit: Int = 30) async throws -> CommunityDeckPage {
        var components = URLComponents(url: endpoint("decks"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "q", value: search),
                                 URLQueryItem(name: "category", value: category == "All" ? "" : category),
                                 URLQueryItem(name: "offset", value: String(offset)),
                                 URLQueryItem(name: "sort", value: sort.rawValue),
                                 URLQueryItem(name: "limit", value: String(limit))]
        return try await decoded(URLRequest(url: components.url!))
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

    func preview(deckID: String) async throws -> CommunityDeckPayload {
        let result: DeckResult = try await decoded(URLRequest(url: endpoint("decks/\(deckID)/preview")))
        return result.deck
    }

    func draft(metadata: Metadata, token: String) async throws -> String {
        let result: IDResult = try await jsonRequest("decks/drafts", method: "POST", body: metadata, token: token)
        return result.id
    }

    func upload(_ data: Data, contentType: String, deckID: String, token: String) async throws -> String {
        var request = URLRequest(url: endpoint("decks/\(deckID)/media"))
        request.httpMethod = "POST"
        request.timeoutInterval = 180
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
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

    func deleteAccount(token: String) async throws {
        var request = URLRequest(url: endpoint("account"))
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let _: SuccessResult = try await decoded(request)
    }

    func detail(deckID: String) async throws -> CommunityDeckPayload {
        let result: DeckResult = try await decoded(URLRequest(url: endpoint("decks/\(deckID)")))
        return result.deck
    }

    func report(deckID: String, reason: String, token: String) async throws {
        struct Body: Encodable { let reason: String }
        let _: SuccessResult = try await jsonRequest("decks/\(deckID)/reports", method: "POST", body: Body(reason: reason), token: token)
    }

    func media(id: String, maximumBytes: Int) async throws -> Data {
        let (data, response) = try await session.data(for: URLRequest(url: endpoint("media/\(id)")))
        try validate(data, response: response)
        guard data.count <= maximumBytes else { throw CommunityAPIError(status: 413, message: "This attachment is too large.") }
        return data
    }

    private func endpoint(_ path: String) -> URL { baseURL.appendingPathComponent("v1/community/\(path)") }

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
            struct Envelope: Decodable { struct Failure: Decodable { let message: String }; let error: Failure }
            let message = (try? JSONDecoder().decode(Envelope.self, from: data))?.error.message
                ?? "The community library is unavailable. Please try again."
            throw CommunityAPIError(status: http.statusCode, message: message)
        }
    }
}

@MainActor
final class CommunitySession: ObservableObject {
    static let shared = CommunitySession()
    @Published private(set) var credentials: CommunityAPI.SignInResult?
    @Published var isSigningIn = false
    @Published var errorMessage: String?
    private let service = "com.learnalert.community"

    var isSignedIn: Bool { credentials.map { $0.expiresAt > Int(Date().timeIntervalSince1970) } ?? false }
    var handle: String { credentials?.handle ?? "" }
    var token: String? { isSignedIn ? credentials?.token : nil }
    var profile: CommunityProfile { credentials?.profile ?? CommunityProfile(handle: handle, avatar: .init(), isComplete: false) }
    var needsProfileSetup: Bool { isSignedIn && !profile.isComplete }

    private init() {
        var query = keychainQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        if SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data {
            credentials = try? JSONDecoder().decode(CommunityAPI.SignInResult.self, from: data)
        }
    }

    private var keychainQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: "session"]
    }

    private func persist(_ result: CommunityAPI.SignInResult) throws {
        let data = try JSONEncoder().encode(result)
        var update: [String: Any] = [kSecValueData as String: data]
        update[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemUpdate(keychainQuery as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var item = keychainQuery
            for (key, value) in update { item[key] = value }
            guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else {
                throw CommunityAPIError(status: 500, message: "Your profile could not be saved securely. Please try again.")
            }
        } else if status != errSecSuccess {
            throw CommunityAPIError(status: 500, message: "Your profile could not be saved securely. Please try again.")
        }
        credentials = result
    }

    @discardableResult
    func signIn(identityToken: String, nonce: String, givenName: String?) async -> Bool {
        isSigningIn = true
        errorMessage = nil
        defer { isSigningIn = false }
        do {
            let result = try await CommunityAPI().signIn(identityToken: identityToken, nonce: nonce, givenName: givenName)
            try persist(result)
            return true
        } catch { errorMessage = error.localizedDescription; return false }
    }

    func refreshProfile() async {
        guard let token else { return }
        do {
            let profile = try await CommunityAPI().profile(token: token)
            guard var result = credentials, self.token == token else { return }
            result.profile = profile; result.handle = profile.handle
            try persist(result)
        } catch { if self.token == token { handle(error) } }
    }

    func saveProfile(username: String, avatar: CommunityAvatar) async throws {
        guard let token else { throw CommunityAPIError(status: 401, message: "Sign in with Apple to save your profile.") }
        do {
            let profile = try await CommunityAPI().saveProfile(username: username, avatar: avatar, token: token)
            guard var result = credentials, self.token == token else { throw CancellationError() }
            result.profile = profile; result.handle = profile.handle
            try persist(result)
            errorMessage = nil
            NotificationCenter.default.post(name: .communityLibraryChanged, object: nil)
        } catch { if self.token == token { handle(error) }; throw error }
    }

    func signOut() {
        SecItemDelete(keychainQuery as CFDictionary)
        credentials = nil
        errorMessage = nil
    }

    func handle(_ error: Error) {
        if let apiError = error as? CommunityAPIError, apiError.status == 401 {
            SecItemDelete(keychainQuery as CFDictionary)
            credentials = nil
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

    static func publish(deck: Deck, category: String, description: String, token: String,
                        api: CommunityAPI? = nil,
                        progress: @escaping (String) -> Void) async throws -> String {
        if let reason = deck.communitySharingRestriction { throw CommunityAPIError(status: 403, message: reason) }
        let api = api ?? CommunityAPI()
        guard !deck.cards.isEmpty, deck.cards.count <= 500 else {
            throw CommunityAPIError(status: 400, message: "Publish between 1 and 500 cards per deck.")
        }
        let metadata = CommunityAPI.Metadata(name: deck.name, description: description, categoryTag: category,
                                             colorHex: deck.colorHex, deckType: deck.deckType)
        // Capture the deck before suspension, and verify all local media before creating a draft.
        var uploads: [Upload] = []
        var seen = Set<String>()
        func imageKey(_ name: String?) throws -> String? {
            guard let name, !name.isEmpty else { return nil }
            let key = "image:\(name)"
            if !seen.contains(key) {
                guard let image = CardImageStore.loadImage(named: name), let data = image.jpegData(compressionQuality: 0.82) else {
                    throw CommunityAPIError(status: 400, message: "A card image is missing. Reattach it before publishing.")
                }
                guard data.count <= 10 * 1024 * 1024 else { throw CommunityAPIError(status: 413, message: "Each image must be under 10 MB.") }
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
                guard data.count <= CardAudioStore.maximumBytes else { throw CommunityAPIError(status: 413, message: "Each audio clip must be under 20 MB.") }
                uploads.append(Upload(key: key, data: data, contentType: try CardAudioStore.contentType(for: name)))
                seen.insert(key)
            }
            return key
        }
        var cards: [CommunityCardPayload] = []
        for card in deck.cards {
            cards.append(CommunityCardPayload(id: card.id.uuidString, question: card.question, correctAnswer: card.correctAnswer,
                options: card.options, hint: card.hint, cardType: card.cardType.rawValue,
                matchingLeftItems: card.matchingLeftItems, matchingRightItems: card.matchingRightItems,
                sectionName: card.section?.name ?? "", promptImageID: try imageKey(card.promptImageName),
                optionImageIDs: try card.optionImageNames.map { try imageKey($0) }, promptAudioID: try audioKey(card.promptAudioName)))
        }
        guard uploads.reduce(0, { $0 + $1.data.count }) <= 100 * 1024 * 1024 else {
            throw CommunityAPIError(status: 413, message: "A shared deck can contain up to 100 MB of images and audio.")
        }
        progress("Preparing your deck…")
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
                progress("Uploading attachment \(index + 1) of \(uploads.count)…")
                remoteIDs[upload.key] = try await api.upload(upload.data, contentType: upload.contentType, deckID: id, token: token)
            }
            for index in cards.indices {
                cards[index].promptImageID = cards[index].promptImageID.flatMap { remoteIDs[$0] }
                cards[index].optionImageIDs = cards[index].optionImageIDs.map { $0.flatMap { remoteIDs[$0] } }
                cards[index].promptAudioID = cards[index].promptAudioID.flatMap { remoteIDs[$0] }
            }
            progress("Submitting for review…")
            try await api.publish(.init(name: metadata.name, description: metadata.description, categoryTag: metadata.categoryTag,
                colorHex: metadata.colorHex, deckType: metadata.deckType, cards: cards), deckID: id, token: token)
            return id
        } catch {
            if existingID == nil { try? await api.remove(deckID: id, token: token) }
            throw error
        }
    }

    static func download(_ summary: CommunityDeckPayload, api: CommunityAPI? = nil, progress: @escaping (String) -> Void) async throws -> PremadeDeck {
        let api = api ?? CommunityAPI()
        let detail = try await api.detail(deckID: summary.id)
        guard let cards = detail.cards else { throw URLError(.cannotParseResponse) }
        var images: [String: String] = [:]
        var audio: [String: String] = [:]
        var savedFiles: [URL] = []
        func imageName(_ id: String?) async throws -> String? {
            guard let id else { return nil }
            if let name = images[id] { return name }
            let data = try await api.media(id: id, maximumBytes: 10 * 1024 * 1024)
            guard let image = UIImage(data: data), let name = CardImageStore.saveImage(image) else {
                throw CommunityAPIError(status: 400, message: "A deck image could not be downloaded.")
            }
            images[id] = name
            savedFiles.append(CardImageStore.imagesDirectoryURL.appendingPathComponent(name))
            return name
        }
        func audioName(_ id: String?) async throws -> String? {
            guard let id else { return nil }
            if let name = audio[id] { return name }
            let data = try await api.media(id: id, maximumBytes: CardAudioStore.maximumBytes)
            let name = try CardAudioStore.saveDownloaded(data)
            audio[id] = name
            savedFiles.append(CardAudioStore.url(named: name))
            return name
        }
        do {
            var imported: [PremadeCard] = []
            for (index, card) in cards.enumerated() {
                try Task.checkCancellation()
                progress("Downloading card \(index + 1) of \(cards.count)…")
                let prompt = try await imageName(card.promptImageID)
                var options: [String] = []
                for id in card.optionImageIDs { options.append(try await imageName(id) ?? "") }
                let clip = try await audioName(card.promptAudioID)
                imported.append(PremadeCard(id: card.id, question: card.question, options: card.options,
                    correctAnswer: card.correctAnswer, hint: card.hint,
                    cardType: FlashcardType(rawValue: card.cardType) ?? .tapReveal,
                    matchingLeftItems: card.matchingLeftItems, matchingRightItems: card.matchingRightItems,
                    promptImageName: prompt, optionImageNames: options, promptAudioName: clip, sectionName: card.sectionName))
            }
            return PremadeDeck(id: detail.id, name: detail.name, category: detail.categoryTag, subcategory: detail.categoryTag,
                description: detail.description, colorHex: detail.colorHex, deckType: detail.deckType, cards: imported, communitySourceID: detail.id)
        } catch {
            for file in savedFiles { try? FileManager.default.removeItem(at: file) }
            throw error
        }
    }
}
