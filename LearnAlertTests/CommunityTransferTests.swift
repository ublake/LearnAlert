import Foundation
import Testing
import UIKit
@testable import LearnAlert

private final class CommunityTestProtocol: URLProtocol, @unchecked Sendable {
    static var response: ((URLRequest) throws -> (Int, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (status, data) = try Self.response!(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() { }
}

@Suite("Community media transfers", .serialized)
@MainActor
struct CommunityTransferTests {
    private func api() -> CommunityAPI {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [CommunityTestProtocol.self]
        return CommunityAPI(baseURL: URL(string: "https://community.test")!, session: URLSession(configuration: config))
    }

    private func json(_ value: Any) throws -> Data { try JSONSerialization.data(withJSONObject: value) }

    private func waveData() -> Data {
        // A short 8 kHz, mono PCM tone, playable by AVAudioPlayer.
        let count = 800
        var data = Data("RIFF".utf8)
        func append<T: FixedWidthInteger>(_ value: T) { var little = value.littleEndian; withUnsafeBytes(of: &little) { data.append(contentsOf: $0) } }
        append(UInt32(36 + count * 2))
        data.append(Data("WAVEfmt ".utf8))
        append(UInt32(16)); append(UInt16(1)); append(UInt16(1)); append(UInt32(8000))
        append(UInt32(16000)); append(UInt16(2)); append(UInt16(16))
        data.append(Data("data".utf8)); append(UInt32(count * 2))
        for index in 0..<count { append(Int16(sin(Double(index) * 2 * .pi * 440 / 8000) * 3000)) }
        return data
    }

    private func requestBody(_ request: URLRequest) -> Data {
        if let data = request.httpBody { return data }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open(); defer { stream.close() }
        var data = Data()
        var bytes = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&bytes, maxLength: bytes.count)
            if count <= 0 { break }
            data.append(contentsOf: bytes.prefix(count))
        }
        return data
    }

    @Test("Publishing includes image/audio references and excludes private study material")
    func publishesMedia() async throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20)).image { context in
            UIColor.red.setFill(); context.fill(CGRect(x: 0, y: 0, width: 20, height: 20))
        }
        let imageName = try #require(CardImageStore.saveImage(image))
        let audioName = try CardAudioStore.saveDownloaded(waveData())
        defer { CardImageStore.deleteImage(named: imageName); CardAudioStore.delete(named: audioName); CommunityTestProtocol.response = nil }
        let deck = Deck(name: "Media deck")
        deck.sourceText = "PRIVATE SOURCE"
        let card = Flashcard(question: "Listen", correctAnswer: "Answer", cardType: .tapReveal, promptImageName: imageName)
        card.promptAudioName = audioName
        card.masteryScore = 3
        deck.cards = [card]
        let draftID = UUID().uuidString
        let imageID = UUID().uuidString
        let audioID = UUID().uuidString
        var published: [String: Any]?
        var uploadedTypes: [String] = []
        CommunityTestProtocol.response = { request in
            let path = request.url!.path
            if path.hasSuffix("/drafts") { return (201, try json(["id": draftID])) }
            if path.hasSuffix("/media") {
                let type = request.value(forHTTPHeaderField: "Content-Type") ?? ""
                uploadedTypes.append(type)
                return (201, try json(["id": type.hasPrefix("image/") ? imageID : audioID]))
            }
            published = try JSONSerialization.jsonObject(with: requestBody(request)) as? [String: Any]
            return (200, try json(["id": draftID, "success": true]))
        }
        let id = try await CommunityDeckTransfer.publish(deck: deck, category: "Science", description: "With media", token: "test", api: api()) { _ in }
        #expect(id == draftID)
        #expect(uploadedTypes == ["image/jpeg", "audio/wav"])
        #expect(published?["sourceText"] == nil)
        let cards = try #require(published?["cards"] as? [[String: Any]])
        #expect(cards[0]["promptImageID"] as? String == imageID)
        #expect(cards[0]["promptAudioID"] as? String == audioID)
        #expect(cards[0]["masteryScore"] == nil)
    }

    @Test("Downloaded decks keep playable audio, viewable images, sections, and choice positions")
    func downloadsMedia() async throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20)).image { context in
            UIColor.blue.setFill(); context.fill(CGRect(x: 0, y: 0, width: 20, height: 20))
        }
        let imageData = try #require(image.jpegData(compressionQuality: 0.8))
        let audioData = waveData()
        let imageID = UUID().uuidString
        let audioID = UUID().uuidString
        let id = UUID().uuidString
        let body: [String: Any] = ["id": id, "name": "Shared", "description": "Test", "authorHandle": "@learner", "categoryTag": "Science", "colorHex": "#5B70E0", "deckType": "Mixed", "cardCount": 1, "downloadCount": 1,
            "cards": [["id": "one", "question": "Q", "correctAnswer": "A", "options": ["A", "B"], "hint": "", "cardType": "multiple_choice", "matchingLeftItems": [], "matchingRightItems": [], "sectionName": "Section", "promptImageID": imageID, "optionImageIDs": [NSNull(), imageID], "promptAudioID": audioID]]]
        CommunityTestProtocol.response = { request in
            if request.url!.path.hasSuffix(imageID) { return (200, imageData) }
            if request.url!.path.hasSuffix(audioID) { return (200, audioData) }
            return (200, try json(["deck": body]))
        }
        defer { CommunityTestProtocol.response = nil }
        let summary = CommunityDeckPayload(id: id, name: "Shared", description: "Test", authorHandle: "@learner", categoryTag: "Science", colorHex: "#5B70E0", deckType: "Mixed", cardCount: 1, downloadCount: 0, publishedAt: nil)
        let downloaded = try await CommunityDeckTransfer.download(summary, api: api()) { _ in }
        let card = try #require(downloaded.cards.first)
        defer {
            CardImageStore.deleteImage(named: card.promptImageName)
            if let name = card.promptAudioName { CardAudioStore.delete(named: name) }
        }
        #expect(downloaded.communitySourceID == id)
        #expect(card.sectionName == "Section")
        #expect(card.optionImageNames[0] == "")
        #expect(card.optionImageNames[1] == card.promptImageName)
        #expect(CardImageStore.loadImage(named: card.promptImageName) != nil)
        let name = try #require(card.promptAudioName)
        #expect(try Data(contentsOf: CardAudioStore.url(named: name)) == audioData)
        #expect(try CardAudioStore.contentType(for: name) == "audio/wav")
    }
    @Test("Existing Apple credentials remain readable before profile setup")
    func legacyCredentials() throws {
        let result = try JSONDecoder().decode(CommunityAPI.SignInResult.self,
            from: json(["token": "saved", "expiresAt": 2000000000, "handle": "@learner"]))
        #expect(result.token == "saved")
        #expect(result.profile == nil)
    }

    @Test("Profile saving sends only the chosen public fields with account authentication")
    func savesProfile() async throws {
        let avatar = CommunityAvatar(hair: 5, eyes: 4, mouth: 3)
        CommunityTestProtocol.response = { request in
            #expect(request.url?.path == "/v1/community/account")
            #expect(request.httpMethod == "PUT")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer account-token")
            let body = try #require(JSONSerialization.jsonObject(with: requestBody(request)) as? [String: Any])
            #expect(Set(body.keys) == ["username", "avatar"])
            #expect(body["username"] as? String == "funny_buddy")
            return (200, try json(["handle": "@funny_buddy", "avatar": ["hair": 5, "eyes": 4, "mouth": 3], "isComplete": true]))
        }
        defer { CommunityTestProtocol.response = nil }
        let profile = try await api().saveProfile(username: "funny_buddy", avatar: avatar, token: "account-token")
        #expect(profile.handle == "@funny_buddy")
        #expect(profile.avatar == avatar)
        #expect(profile.isComplete)
    }

    @Test("Preview uses its dedicated endpoint and keeps public author and media data")
    func previewsDeck() async throws {
        let id = UUID().uuidString
        CommunityTestProtocol.response = { request in
            #expect(request.url?.path == "/v1/community/decks/\(id)/preview")
            #expect(request.httpMethod == "GET")
            #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
            return (200, try json(["deck": ["id": id, "name": "Sample", "description": "", "authorHandle": "@buddy",
                "authorAvatar": ["hair": 2, "eyes": 1, "mouth": 5], "categoryTag": "General", "colorHex": "#5B70E0",
                "deckType": "Mixed", "cardCount": 10, "downloadCount": 0,
                "cards": [["id": "one", "question": "Q", "correctAnswer": "A", "options": [], "hint": "", "cardType": "tap_reveal",
                    "matchingLeftItems": [], "matchingRightItems": [], "sectionName": "", "promptAudioID": "audio-id", "optionImageIDs": []]]]]))
        }
        defer { CommunityTestProtocol.response = nil }
        let preview = try await api().preview(deckID: id)
        #expect(preview.authorAvatar == CommunityAvatar(hair: 2, eyes: 1, mouth: 5))
        #expect(preview.cards?.first?.promptAudioID == "audio-id")
        #expect(preview.downloadCount == 0)
    }

    @Test("Publishing after an account change creates a new deck without updating the previous account")
    func accountChangePublication() async throws {
        let deck = Deck(name: "My deck")
        let previousID = UUID().uuidString
        let newID = UUID().uuidString
        deck.publishedCommunityID = previousID
        deck.cards = [Flashcard(question: "Q", correctAnswer: "A", cardType: .tapReveal)]
        var paths: [String] = []
        CommunityTestProtocol.response = { request in
            let path = request.url!.path
            paths.append(path)
            if path == "/v1/community/account/decks" { return (200, try json(["decks": [], "nextOffset": NSNull()])) }
            if path == "/v1/community/decks/drafts" { return (201, try json(["id": newID])) }
            #expect(path == "/v1/community/decks/\(newID)")
            return (200, try json(["id": newID, "success": true]))
        }
        defer { CommunityTestProtocol.response = nil }
        let id = try await CommunityDeckTransfer.publish(deck: deck, category: "General", description: "", token: "new-account", api: api()) { _ in }
        #expect(id == newID)
        #expect(paths == ["/v1/community/account/decks", "/v1/community/decks/drafts", "/v1/community/decks/\(newID)"])
        #expect(deck.publishedCommunityID == previousID)
    }

    @Test("Characters without a stored skin tone use the middle shade; chosen tones survive encoding")
    func skinToneCompatibility() throws {
        let legacy = try JSONDecoder().decode(CommunityAvatar.self, from: json(["hair": 2, "eyes": 4, "mouth": 5]))
        #expect(legacy.skinTone == 3)
        #expect(CommunityAvatar().skinTone == CommunityAvatar.skinTones.count / 2)
        for tone in 0...6 {
            let avatar = CommunityAvatar(hair: 2, eyes: 4, mouth: 5, skinTone: tone)
            let restored = try JSONDecoder().decode(CommunityAvatar.self, from: JSONEncoder().encode(avatar))
            #expect(restored == avatar)
        }
    }

}
