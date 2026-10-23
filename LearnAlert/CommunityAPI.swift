import Foundation
import SwiftUI
import Combine
import Security
import CryptoKit
import UIKit
import AuthenticationServices

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
    case popular, recent
    var title: String { self == .popular ? "Popular" : "Recent" }
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
        sourceKind == "anki" || sourceAnkiDeckID != nil || cards.contains { $0.sourceAnkiCardID != nil || $0.cardType == .anki }
    }
    var communitySharingRestriction: String? { sharingRestriction(allowAnkiUploads: false) }

    /// Cheap menu/form gates use provenance only. Legacy content matching still
    /// runs in sharingRestriction immediately before an actual publish request.
    func provenanceSharingRestriction(allowAnkiUploads: Bool) -> String? {
        if !allowAnkiUploads && (sourceKind == "anki" || sourceAnkiDeckID != nil) {
            return "Uploading decks imported from Anki are not supported yet"
        }
        if sourceCommunityID != nil { return "Downloaded shared decks can’t be republished. Share a deck you created." }
        if sourcePremadeID != nil || deckType == "Course" { return "Built-in decks and bundles can’t be published as shared decks." }
        return nil
    }

    func sharingRestriction(allowAnkiUploads: Bool) -> String? {
        if let reason = provenanceSharingRestriction(allowAnkiUploads: allowAnkiUploads) { return reason }
        let orderedCards = cards
        if !allowAnkiUploads && orderedCards.contains(where: { $0.sourceAnkiCardID != nil || $0.cardType == .anki }) {
            return "Uploading decks imported from Anki are not supported yet"
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
        }) { return "Built-in decks can’t be published as shared decks." }
        return nil
    }

    var canShareToCommunity: Bool { communitySharingRestriction == nil }
    var canPresentCommunitySharing: Bool { provenanceSharingRestriction(allowAnkiUploads: true) == nil }
}

struct CommunityAPIError: LocalizedError {
    let status: Int
    let message: String
    var code: String? = nil
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

    func list(search: String, category: String, offset: Int = 0, sort: CommunityDeckSort = .recent, limit: Int = 30, token: String? = nil) async throws -> CommunityDeckPage {
        var components = URLComponents(url: endpoint("decks"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "q", value: search),
                                 URLQueryItem(name: "category", value: category == "All" ? "" : category),
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
        guard data.count <= maximumBytes else { throw CommunityAPIError(status: 413, message: "This attachment is too large.") }
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
                ?? "Shared decks are unavailable. Please try again."
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
                    throw CommunityAPIError(status: 500, message: "Your profile could not be saved securely. Please try again.")
                }
            } else if status != errSecSuccess {
                throw CommunityAPIError(status: 500, message: "Your profile could not be saved securely. Please try again.")
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
        errorMessage = "Apple access changed. Sign in again to use your community account."
    }

    func saveProfile(username: String, avatar: CommunityAvatar) async throws {
        guard let token else { throw CommunityAPIError(status: 401, message: "Sign in with Apple to save your profile.") }
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
        guard let token else { throw CommunityAPIError(status: 401, message: "Sign in with Apple to update your profile.") }
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
        guard let token else { throw CommunityAPIError(status: 401, message: "Sign in to change developer options.") }
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
                        api: CommunityAPI? = nil,
                        progress: @escaping (String) -> Void) async throws -> String {
        let api = api ?? CommunityAPI()
        let profile = deck.isAnkiImport || publisherHandle?.isEmpty == false ? try await api.profile(token: token) : nil
        if let reason = deck.sharingRestriction(allowAnkiUploads: profile?.isDeveloper == true && profile?.allowAnkiUploads == true) {
            throw CommunityAPIError(status: 403, message: reason)
        }
        if publisherHandle?.isEmpty == false && profile?.isDeveloper != true {
            throw CommunityAPIError(status: 403, message: "Custom publishing names require developer access.")
        }
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
        var ankiMedia: [String: [String: String]] = [:]
        var templateBytes = 0
        var cards: [CommunityCardPayload] = []
        for card in deck.cards {
            if let content = card.ankiContent {
                templateBytes += content.frontHTML.utf8.count + content.backHTML.utf8.count + content.css.utf8.count
                guard templateBytes <= 1024 * 1024 else {
                    throw CommunityAPIError(status: 413, message: "These Anki templates are too large to share. Split the deck into smaller decks.")
                }
            }
            if let content = card.ankiContent, ankiMedia[content.mediaFolder] == nil {
                guard let directory = content.mediaURL else { throw CommunityAPIError(status: 400, message: "Anki media is unavailable. Re-import the deck.") }
                let index = AnkiCardContent.mediaIndex(in: directory)
                var media: [String: String] = [:]
                let names = index.isEmpty ? try FileManager.default.contentsOfDirectory(atPath: directory.path).filter { !$0.hasPrefix(".") } : Array(index.keys)
                for name in names {
                    guard let url = AnkiCardContent.safeMediaURL(name: name, directory: directory, index: index),
                          let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= 20 * 1024 * 1024 else {
                        throw CommunityAPIError(status: 400, message: "An Anki attachment is missing or exceeds 20 MB.")
                    }
                    guard uploads.count < 1000, uploads.reduce(0, { $0 + $1.data.count }) + size <= 100 * 1024 * 1024 else {
                        throw CommunityAPIError(status: 413, message: "A shared deck supports up to 100 MB of media and 1,000 attachments.")
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
                cards[index].answerImageID = cards[index].answerImageID.flatMap { remoteIDs[$0] }
                cards[index].fieldMedia = cards[index].fieldMedia?.mapValues { .init(imageID: $0.imageID.flatMap { remoteIDs[$0] }, audioID: $0.audioID.flatMap { remoteIDs[$0] }) }

            }
            progress("Submitting for review…")
            let remoteAnkiMedia = ankiMedia.mapValues { $0.compactMapValues { remoteIDs[$0] } }
            try await api.publish(.init(name: metadata.name, description: metadata.description, categoryTag: metadata.categoryTag,
                colorHex: metadata.colorHex, deckType: metadata.deckType, cards: cards, origin: deck.isAnkiImport ? "anki" : "personal",
                publisherHandle: publisherHandle, ankiMedia: remoteAnkiMedia.isEmpty ? nil : remoteAnkiMedia), deckID: id, token: token)
            return id
        } catch {
            if existingID == nil { try? await api.remove(deckID: id, token: token) }
            throw error
        }
    }

    static func download(_ summary: CommunityDeckPayload, api: CommunityAPI? = nil, token: String? = nil, progress: @escaping (String) -> Void) async throws -> PremadeDeck {
        let api = api ?? CommunityAPI()
        let detail = try await api.detail(deckID: summary.id, token: token)
        guard let cards = detail.cards else { throw URLError(.cannotParseResponse) }
        var images: [String: String] = [:]
        var audio: [String: String] = [:]
        var savedFiles: [URL] = []
        var savedAnkiFolders: [URL] = []
        var ankiFolders: [String: String] = [:]
        func imageName(_ id: String?) async throws -> String? {
            guard let id else { return nil }
            if let name = images[id] { return name }
            let data = try await api.media(id: id, maximumBytes: 10 * 1024 * 1024, token: token)
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
            let data = try await api.media(id: id, maximumBytes: CardAudioStore.maximumBytes, token: token)
            let name = try CardAudioStore.saveDownloaded(data)
            audio[id] = name
            savedFiles.append(CardAudioStore.url(named: name))
            return name
        }
        do {
            var ankiBytes = 0
            for (group, files) in detail.ankiMedia ?? [:] {
                let folder = UUID().uuidString
                let directory = AnkiCardContent.mediaRoot.appendingPathComponent(folder, isDirectory: true)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                savedAnkiFolders.append(directory)
                var index: [String: String] = [:]
                for (name, id) in files {
                    guard !name.isEmpty, name != ".", name != "..", !name.contains("/"), !name.contains("\\"), !name.unicodeScalars.contains(where: { $0.value < 32 }) else { throw URLError(.cannotParseResponse) }
                    let data = try await api.media(id: id, maximumBytes: 20 * 1024 * 1024, token: token)
                    ankiBytes += data.count
                    guard ankiBytes <= 100 * 1024 * 1024 else { throw URLError(.dataLengthExceedsMaximum) }
                    let filename = UUID().uuidString + "." + URL(fileURLWithPath: name).pathExtension
                    try data.write(to: directory.appendingPathComponent(filename), options: .atomic)
                    index[name] = filename
                }
                try JSONEncoder().encode(index).write(to: directory.appendingPathComponent(".learnalert-media.json"), options: .atomic)
                ankiFolders[group] = folder
            }
            var imported: [PremadeCard] = []
            for (index, card) in cards.enumerated() {
                try Task.checkCancellation()
                progress("Downloading card \(index + 1) of \(cards.count)…")
                let prompt = try await imageName(card.promptImageID)
                let answer = try await imageName(card.answerImageID)
                var options: [String] = []
                for id in card.optionImageIDs { options.append(try await imageName(id) ?? "") }
                let clip = try await audioName(card.promptAudioID)
                var fields: [String: CardFieldMedia] = [:]
                for (key, attachment) in card.fieldMedia ?? [:] {
                    fields[key] = .init(image: try await imageName(attachment.imageID), audio: try await audioName(attachment.audioID))
                }
                // Older public decks have only the original attachment columns.
                fields["prompt"] = fields["prompt"] ?? .init(image: prompt, audio: clip)
                fields["answer"] = fields["answer"] ?? .init(image: answer)
                for (i, name) in options.enumerated() where !name.isEmpty && fields["option:\(i)"] == nil { fields["option:\(i)"] = .init(image: name) }

                var ankiContent = card.ankiContent
                if var content = ankiContent {
                    if let folder = ankiFolders[content.mediaFolder] { content.mediaFolder = folder }
                    else {
                        let folder = UUID().uuidString
                        let directory = AnkiCardContent.mediaRoot.appendingPathComponent(folder, isDirectory: true)
                        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                        savedAnkiFolders.append(directory); content.mediaFolder = folder
                    }
                    ankiContent = content
                }
                imported.append(PremadeCard(id: card.id, question: card.question, options: card.options,
                    correctAnswer: card.correctAnswer, hint: card.hint,
                    cardType: FlashcardType(rawValue: card.cardType) ?? .tapReveal,
                    matchingLeftItems: card.matchingLeftItems, matchingRightItems: card.matchingRightItems,
                    promptImageName: prompt, answerImageName: answer, optionImageNames: options, promptAudioName: clip, fieldMedia: fields, correctOptionIndex: card.correctOptionIndex, sectionName: card.sectionName, ankiContent: ankiContent))
            }
            return PremadeDeck(id: detail.id, name: detail.name, category: detail.categoryTag, subcategory: detail.categoryTag,
                description: detail.description, colorHex: detail.colorHex, deckType: detail.deckType, cards: imported, communitySourceID: detail.id)
        } catch {
            for file in savedFiles + savedAnkiFolders { try? FileManager.default.removeItem(at: file) }
            throw error
        }
    }
}
