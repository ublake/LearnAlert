import Foundation
import Testing
@testable import LearnAlert

private final class SocialTestProtocol: URLProtocol, @unchecked Sendable {
    static var response: ((URLRequest) throws -> Data)?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let data = try Self.response!(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data); client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() { }
}

@Suite("Community profiles and appreciation", .serialized)
@MainActor
struct CommunitySocialTests {
    private func api() -> CommunityAPI {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [SocialTestProtocol.self]
        return CommunityAPI(baseURL: URL(string: "https://community.test")!, session: URLSession(configuration: config))
    }
    private func json(_ value: Any) throws -> Data { try JSONSerialization.data(withJSONObject: value) }
    private func body(_ request: URLRequest) -> Data {
        if let data = request.httpBody { return data }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open(); defer { stream.close() }
        var data = Data(); var buffer = [UInt8](repeating: 0, count: 2048)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(contentsOf: buffer.prefix(count))
        }
        return data
    }

    @Test("Public profiles retain joined date while hidden statistics stay absent")
    func privateProfile() async throws {
        SocialTestProtocol.response = { request in
            #expect(request.url?.path == "/v1/community/profiles/public-author")
            #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
            let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!
            #expect(items.contains(URLQueryItem(name: "offset", value: "20")))
            #expect(items.contains(URLQueryItem(name: "limit", value: "20")))
            return try json(["profile": ["authorID": "public-author", "handle": "@cozy_otter",
                "avatar": ["hair": 2, "eyes": 4, "mouth": 1], "hideStatsPublicly": true,
                "profileCreatedAt": 1791900000, "stats": NSNull()], "decks": [], "nextOffset": NSNull(), "totalCount": 0])
        }
        defer { SocialTestProtocol.response = nil }
        let page = try await api().publicProfile(authorID: "public-author", offset: 20)
        #expect(page.profile.stats == nil && page.profile.hideStatsPublicly)
        #expect(page.profile.profileCreatedAt == 1791900000)
        #expect(page.profile.avatar.skinTone == 3)
    }

    @Test("Heart changes use idempotent authenticated methods and decode authoritative totals")
    func heartRequests() async throws {
        var methods: [String] = []
        SocialTestProtocol.response = { request in
            #expect(request.url?.path == "/v1/community/decks/deck-id/like")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer signed-in")
            methods.append(request.httpMethod!)
            return try json(["success": true, "likeCount": request.httpMethod == "PUT" ? 8 : 7, "viewerHasLiked": request.httpMethod == "PUT"])
        }
        defer { SocialTestProtocol.response = nil }
        let liked = try await api().setLike(deckID: "deck-id", liked: true, token: "signed-in")
        let unliked = try await api().setLike(deckID: "deck-id", liked: false, token: "signed-in")
        #expect(methods == ["PUT", "DELETE"])
        #expect(liked.likeCount == 8 && liked.viewerHasLiked)
        #expect(unliked.likeCount == 7 && !unliked.viewerHasLiked)
    }

    @Test("Privacy update sends only the new preference and preserves the complete account")
    func privacyPreference() async throws {
        SocialTestProtocol.response = { request in
            #expect(request.url?.path == "/v1/community/account" && request.httpMethod == "PUT")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer owner")
            let payload = try #require(JSONSerialization.jsonObject(with: body(request)) as? [String: Bool])
            #expect(payload == ["hideStatsPublicly": true])
            return try json(["handle": "@cozy_otter", "authorID": "author", "avatar": ["hair": 2, "eyes": 3, "mouth": 4],
                             "isComplete": true, "hideStatsPublicly": true, "profileCreatedAt": 100,
                             "stats": ["createdDeckCount": 4, "publishedDeckCount": 2, "downloadCount": 9,
                                       "receivedLikeCount": 0, "hasReceivedLikes": true]])
        }
        defer { SocialTestProtocol.response = nil }
        let profile = try await api().saveProfilePrivacy(hideStatsPublicly: true, token: "owner")
        #expect(profile.isComplete && profile.hideStatsPublicly == true)
        #expect(profile.stats?.hasReceivedLikes == true && profile.stats?.receivedLikeCount == 0)
        #expect(profile.avatar.hair == 2)
    }

    @Test("Received hearts stay owner-authenticated and include identities, decks, and whole-chart counts")
    func receivedLikes() async throws {
        SocialTestProtocol.response = { request in
            #expect(request.url?.path == "/v1/community/account/likes")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer owner")
            let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!
            #expect(items.contains(URLQueryItem(name: "offset", value: "20")))
            return try json(["totalCount": 25, "nextOffset": NSNull(),
                "likes": [["authorID": "fan", "handle": "@tiny_kiwi", "avatar": ["hair": 1, "eyes": 0, "mouth": 3],
                           "deckID": "deck", "deckName": "Korean words", "createdAt": 1791900000]],
                "deckCounts": [["deckID": "deck", "deckName": "Korean words", "likeCount": 25]]])
        }
        defer { SocialTestProtocol.response = nil }
        let page = try await api().receivedLikes(offset: 20, token: "owner")
        #expect(page.likes.first?.handle == "@tiny_kiwi" && page.likes.first?.deckID == "deck")
        #expect(page.deckCounts.first?.likeCount == 25 && page.totalCount == 25)
    }

    @Test("Profile age uses profile time and handles today or future timestamps")
    func profileAge() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        #expect(CommunityProfileAge.label(since: Int(now.timeIntervalSince1970), now: now, calendar: calendar) == "Joined today")
        #expect(CommunityProfileAge.label(since: Int(now.timeIntervalSince1970) + 1000, now: now, calendar: calendar) == "Joined today")
        #expect(CommunityProfileAge.label(since: Int(now.addingTimeInterval(-86400 * 3).timeIntervalSince1970), now: now, calendar: calendar) == "3 days on LearnAlert")
    }
}
