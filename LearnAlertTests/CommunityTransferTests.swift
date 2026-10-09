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
}
