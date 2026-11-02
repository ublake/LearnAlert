import Foundation
import Testing
@testable import LearnAlert

private final class FeedPagingProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var respond: ((FeedPagingProtocol) -> Void)?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() { Self.respond?(self) }
    override func stopLoading() { }

    func finish(status: Int = 200, json: [String: Any]) {
        do {
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: try JSONSerialization.data(withJSONObject: json))
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
}

private final class FeedPendingResponse: @unchecked Sendable {
    private let lock = NSLock()
    private var value: FeedPagingProtocol?
    func hold(_ response: FeedPagingProtocol) { lock.lock(); value = response; lock.unlock() }
    var hasResponse: Bool { lock.lock(); defer { lock.unlock() }; return value != nil }
    func take() -> FeedPagingProtocol? { lock.lock(); defer { lock.unlock() }; let response = value; value = nil; return response }
}

@Suite("Continuous community feed", .serialized)
@MainActor
struct CommunityFeedPagingTests {
    private func api() -> CommunityAPI {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [FeedPagingProtocol.self]
        return CommunityAPI(baseURL: URL(string: "https://feed.test")!, session: URLSession(configuration: config))
    }

    private func query(_ request: URLRequest) -> [String: String] {
        let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
        return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
    }

    private func deck(_ id: Int) -> [String: Any] {
        ["id": "deck-\(id)", "name": "Deck \(id)", "description": "", "authorHandle": "@cozy_otter",
         "categoryTag": "Science", "colorHex": "#4868F8", "deckType": "Quiz", "cardCount": 10, "downloadCount": 0]
    }

    @Test("Scrolling appends twenty-card batches, deduplicates overlap, and ends without a pager")
    func appendsUniqueBatches() async {
        var offsets: [Int] = []
        FeedPagingProtocol.respond = { response in
            let values = query(response.request)
            #expect(values["limit"] == "20" && values["sort"] == "popular")
            #expect(values["q"] == "anatomy" && values["category"] == "Science")
            #expect(response.request.value(forHTTPHeaderField: "Authorization") == "Bearer viewer")
            let offset = Int(values["offset"] ?? "") ?? -1
            offsets.append(offset)
            let range = offset == 0 ? 0..<20 : offset == 20 ? 19..<39 : 39..<40
            response.finish(json: ["decks": range.map(deck), "totalCount": 40,
                "nextOffset": offset < 40 ? offset + 20 : NSNull()])
        }
        defer { FeedPagingProtocol.respond = nil }
        let store = CommunityFeedStore(api: api())
        store.setViewer(token: "viewer"); store.search = "anatomy"; store.category = "Science"
        await store.load()
        #expect(store.decks.count == 20 && store.canLoadMore)
        await store.loadNextPage()
        #expect(store.decks.count == 39 && store.decks[20].id == "deck-20")
        await store.loadNextPage()
        #expect(store.decks.count == 40 && !store.hasMore)
        await store.loadNextPage()
        #expect(offsets == [0, 20, 40])
    }

    @Test("A failed next batch keeps existing cards and retries the same cursor")
    func retriesWithoutLosingRows() async {
        var failed = false
        var offsets: [Int] = []
        FeedPagingProtocol.respond = { response in
            let offset = Int(query(response.request)["offset"] ?? "") ?? -1
            offsets.append(offset)
            if offset == 0 {
                response.finish(json: ["decks": (0..<20).map(deck), "nextOffset": 20])
            } else if !failed {
                failed = true
                response.finish(status: 503, json: ["error": "Try again shortly."])
            } else {
                response.finish(json: ["decks": [deck(20)], "nextOffset": NSNull()])
            }
        }
        defer { FeedPagingProtocol.respond = nil }
        let store = CommunityFeedStore(api: api())
        await store.load(); await store.loadNextPage()
        #expect(store.decks.count == 20 && store.loadMoreErrorMessage != nil && store.canLoadMore)
        await store.loadNextPage()
        #expect(store.decks.count == 21 && store.loadMoreErrorMessage == nil && !store.hasMore)
        #expect(offsets == [0, 20, 20])
    }

    @Test("An old search response cannot replace or append to the new search")
    func rejectsStaleSearchResponse() async throws {
        let pending = FeedPendingResponse()
        FeedPagingProtocol.respond = { response in
            if query(response.request)["q"] == "old" { pending.hold(response) }
            else { response.finish(json: ["decks": [deck(99)], "nextOffset": NSNull()]) }
        }
        defer {
            pending.take()?.finish(json: ["decks": [], "nextOffset": NSNull()])
            FeedPagingProtocol.respond = nil
        }
        let store = CommunityFeedStore(api: api())
        store.search = "old"
        let oldLoad = Task { await store.load() }
        defer { oldLoad.cancel() }
        for _ in 0..<100 where !pending.hasResponse { try await Task.sleep(for: .milliseconds(10)) }
        let delayed = try #require(pending.take())
        store.search = "new"
        #expect(store.decks.isEmpty && !store.hasLoaded && !store.hasMore)
        await store.load()
        delayed.finish(json: ["decks": [deck(1)], "nextOffset": 20])
        await oldLoad.value
        #expect(store.decks.map(\.id) == ["deck-99"] && !store.hasMore)
    }

    @Test("A nonadvancing next cursor stops automatic pagination and exposes retry")
    func rejectsRepeatedCursor() async {
        FeedPagingProtocol.respond = { response in
            let offset = Int(query(response.request)["offset"] ?? "") ?? -1
            response.finish(json: ["decks": [deck(offset)], "nextOffset": 20])
        }
        defer { FeedPagingProtocol.respond = nil }
        let store = CommunityFeedStore(api: api())
        await store.load(); await store.loadNextPage()
        #expect(store.decks.map(\.id) == ["deck-0"] && store.loadMoreErrorMessage != nil)
        #expect(!store.isLoadingMore)
    }
}
