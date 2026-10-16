import Foundation
import Testing
import UIKit
import AuthenticationServices
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

    @Test("Media-only quiz, reveal, hint and matching fields round-trip through publishing and download")
    func allFieldMediaRoundTrip() async throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20)).image { context in
            UIColor.blue.setFill(); context.fill(CGRect(x: 0, y: 0, width: 20, height: 20))
        }
        let name = try #require(CardImageStore.saveImage(image))
        let audio = try CardAudioStore.saveDownloaded(waveData())
        var downloaded: [PremadeCard] = []
        defer {
            CardImageStore.deleteImage(named: name); CardAudioStore.delete(named: audio)
            for card in downloaded { for media in card.fieldMedia.values {
                if let image = media.image { CardImageStore.deleteImage(named: image) }
                if let audio = media.audio { CardAudioStore.delete(named: audio) }
            } }
            CommunityTestProtocol.response = nil
        }
        let quiz = Flashcard(question: "", options: ["", ""], cardType: .multipleChoice)
        quiz.correctOptionIndex = 1
        quiz.fieldMedia = ["prompt": .init(audio: audio), "option:0": .init(image: name), "option:1": .init(audio: audio), "hint": .init(image: name, audio: audio)]
        let reveal = Flashcard(question: "", cardType: .tapReveal)
        reveal.fieldMedia = ["prompt": .init(image: name), "answer": .init(image: name, audio: audio)]
        let pairs = Flashcard(question: "", cardType: .matching, matchingLeftItems: ["", ""], matchingRightItems: ["", ""])
        pairs.fieldMedia = ["left:0": .init(image: name), "left:1": .init(audio: audio), "right:0": .init(audio: audio), "right:1": .init(image: name)]
        let deck = Deck(name: "Mixed media"); deck.cards = [quiz, reveal, pairs]
        let draftID = UUID().uuidString
        var published: [CommunityCardPayload] = [], mediaBytes: [String: Data] = [:]
        CommunityTestProtocol.response = { request in
            let path = request.url!.path
            if path.hasSuffix("/drafts") { return (201, try json(["id": draftID])) }
            if path.hasSuffix("/media") {
                let id = UUID().uuidString; mediaBytes[id] = requestBody(request)
                return (201, try json(["id": id]))
            }
            if request.httpMethod == "PUT" {
                let body = try #require(JSONSerialization.jsonObject(with: requestBody(request)) as? [String: Any])
                published = try JSONDecoder().decode([CommunityCardPayload].self, from: json(body["cards"]!))
                #expect(published[0].correctOptionIndex == 1)
                #expect(published[0].options == ["", ""])
                #expect(published[0].fieldMedia?["option:1"]?.audioID != nil)
                return (202, try json(["success": true, "id": draftID]))
            }
            if let bytes = mediaBytes[request.url!.lastPathComponent] { return (200, bytes) }
            let detail = CommunityDeckPayload(id: draftID, name: deck.name, description: "", authorHandle: "@tester", categoryTag: "General", colorHex: "#A9D7F5", deckType: "Mixed", cardCount: 3, downloadCount: 0, publishedAt: nil, cards: published)
            return (200, try json(["deck": JSONSerialization.jsonObject(with: JSONEncoder().encode(detail))]))
        }
        _ = try await CommunityDeckTransfer.publish(deck: deck, category: "General", description: "", token: "test", api: api()) { _ in }
        #expect(mediaBytes.count == 2)
        let summary = CommunityDeckPayload(id: draftID, name: deck.name, description: "", authorHandle: "@tester", categoryTag: "General", colorHex: "#A9D7F5", deckType: "Mixed", cardCount: 3, downloadCount: 0, publishedAt: nil, cards: nil)
        downloaded = try await CommunityDeckTransfer.download(summary, api: api()) { _ in }.cards
        #expect(downloaded.count == 3 && downloaded[0].correctOptionIndex == 1)
        #expect(downloaded[0].fieldMedia["option:1"]?.audio != nil)
        #expect(downloaded[1].fieldMedia["answer"]?.image != nil && downloaded[1].fieldMedia["answer"]?.audio != nil)
        #expect(downloaded[2].fieldMedia["right:0"]?.audio != nil)
        #expect(downloaded[0].fieldMedia["hint"]?.audio == downloaded[2].fieldMedia["right:0"]?.audio)
    }

    @Test("Image-only cards publish without invented question or answer text")
    func publishesImageOnlyCard() async throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 30, height: 20)).image { context in
            UIColor.green.setFill(); context.fill(CGRect(x: 0, y: 0, width: 30, height: 20))
        }
        let name = try #require(CardImageStore.saveImage(image))
        defer { CardImageStore.deleteImage(named: name); CommunityTestProtocol.response = nil }
        let deck = Deck(name: "Visual review")
        deck.cards = [Flashcard(question: "", correctAnswer: "", cardType: .images, promptImageName: name)]
        let draftID = UUID().uuidString
        let imageID = UUID().uuidString
        CommunityTestProtocol.response = { request in
            if request.url!.path.hasSuffix("/drafts") { return (201, try json(["id": draftID])) }
            if request.url!.path.hasSuffix("/media") { return (201, try json(["id": imageID])) }
            let body = try #require(JSONSerialization.jsonObject(with: requestBody(request)) as? [String: Any])
            let cards = try #require(body["cards"] as? [[String: Any]])
            #expect(cards.count == 1)
            #expect(cards[0]["cardType"] as? String == "images")
            #expect(cards[0]["question"] as? String == "")
            #expect(cards[0]["correctAnswer"] as? String == "")
            #expect(cards[0]["promptImageID"] as? String == imageID)
            #expect(cards[0]["promptAudioID"] == nil || cards[0]["promptAudioID"] is NSNull)
            return (202, try json(["id": draftID, "success": true, "reviewStatus": "pending"]))
        }
        let id = try await CommunityDeckTransfer.publish(deck: deck, category: "General", description: "", token: "test", api: api()) { _ in }
        #expect(id == draftID)
    }

    @Test("Front and back image cards publish both attachments without text and reuse uploads")
    func publishesFrontAndBackImages() async throws {
        let front = UIGraphicsImageRenderer(size: CGSize(width: 30, height: 20)).image { context in
            UIColor.red.setFill(); context.fill(CGRect(x: 0, y: 0, width: 30, height: 20))
        }
        let back = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 30)).image { context in
            UIColor.blue.setFill(); context.fill(CGRect(x: 0, y: 0, width: 20, height: 30))
        }
        let frontName = try #require(CardImageStore.saveImage(front))
        let backName = try #require(CardImageStore.saveImage(back))
        defer {
            CardImageStore.deleteImage(named: frontName)
            CardImageStore.deleteImage(named: backName)
            CommunityTestProtocol.response = nil
        }
        let deck = Deck(name: "Picture pairs")
        deck.cards = (0..<2).map { _ in
            let card = Flashcard(question: "", correctAnswer: "", cardType: .images, promptImageName: frontName)
            card.answerImageName = backName
            return card
        }
        let draftID = UUID().uuidString
        let imageIDs = [UUID().uuidString, UUID().uuidString]
        var uploads = 0
        CommunityTestProtocol.response = { request in
            if request.url!.path.hasSuffix("/drafts") { return (201, try json(["id": draftID])) }
            if request.url!.path.hasSuffix("/media") {
                #expect(request.value(forHTTPHeaderField: "Content-Type") == "image/jpeg")
                let index = uploads
                uploads += 1
                return (201, try json(["id": imageIDs[min(index, imageIDs.count - 1)]]))
            }
            let body = try #require(JSONSerialization.jsonObject(with: requestBody(request)) as? [String: Any])
            let cards = try #require(body["cards"] as? [[String: Any]])
            #expect(cards.count == 2)
            for card in cards {
                #expect(card["cardType"] as? String == "images")
                #expect(card["question"] as? String == "")
                #expect(card["correctAnswer"] as? String == "")
                #expect(card["promptImageID"] as? String == imageIDs[0])
                #expect(card["answerImageID"] as? String == imageIDs[1])
            }
            return (202, try json(["id": draftID, "success": true, "reviewStatus": "pending"]))
        }
        let id = try await CommunityDeckTransfer.publish(deck: deck, category: "General", description: "", token: "test", api: api()) { _ in }
        #expect(id == draftID)
        #expect(uploads == 2)
    }

    @Test("Older single-picture payloads decode without a back image")
    func legacySinglePicturePayload() throws {
        let old = try json(["id": "old-picture", "question": "", "correctAnswer": "", "options": [], "hint": "", "cardType": "images",
                            "matchingLeftItems": [], "matchingRightItems": [], "sectionName": "", "promptImageID": "front", "optionImageIDs": []])
        let card = try JSONDecoder().decode(CommunityCardPayload.self, from: old)
        #expect(card.promptImageID == "front")
        #expect(card.answerImageID == nil)
        let encoded = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(card)) as? [String: Any])
        #expect(encoded["answerImageID"] == nil)
    }

    @Test("Image-only downloads retain their media and text-free type")
    func downloadsImageOnlyCard() async throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 30)).image { context in
            UIColor.yellow.setFill(); context.fill(CGRect(x: 0, y: 0, width: 20, height: 30))
        }
        let imageData = try #require(image.jpegData(compressionQuality: 0.8))
        let imageID = UUID().uuidString
        let id = UUID().uuidString
        CommunityTestProtocol.response = { request in
            if request.url!.path.hasSuffix(imageID) { return (200, imageData) }
            return (200, try json(["deck": ["id": id, "name": "Pictures", "description": "", "authorHandle": "@buddy",
                "categoryTag": "General", "colorHex": "#5B70E0", "deckType": "Mixed", "cardCount": 1, "downloadCount": 0,
                "cards": [["id": "picture", "question": "", "correctAnswer": "", "options": [], "hint": "", "cardType": "images",
                           "matchingLeftItems": [], "matchingRightItems": [], "sectionName": "", "promptImageID": imageID, "optionImageIDs": []]]]]))
        }
        defer { CommunityTestProtocol.response = nil }
        let summary = CommunityDeckPayload(id: id, name: "Pictures", description: "", authorHandle: "@buddy", categoryTag: "General", colorHex: "#5B70E0", deckType: "Mixed", cardCount: 1, downloadCount: 0, publishedAt: nil)
        let downloaded = try await CommunityDeckTransfer.download(summary, api: api()) { _ in }
        let card = try #require(downloaded.cards.first)
        defer { CardImageStore.deleteImage(named: card.promptImageName) }
        #expect(card.cardType == .images)
        #expect(card.answerImageName == nil)
        #expect(card.question.isEmpty && card.correctAnswer.isEmpty && card.options.isEmpty)
        let picture = try #require(CardImageStore.loadImage(named: card.promptImageName))
        #expect(abs(picture.size.width / picture.size.height - 2.0 / 3.0) < 0.01)
    }

    @Test("Downloaded front and back pictures stay separate while repeated media is cached")
    func downloadsFrontAndBackImages() async throws {
        let front = UIGraphicsImageRenderer(size: CGSize(width: 30, height: 20)).image { context in
            UIColor.red.setFill(); context.fill(CGRect(x: 0, y: 0, width: 30, height: 20))
        }
        let back = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 30)).image { context in
            UIColor.blue.setFill(); context.fill(CGRect(x: 0, y: 0, width: 20, height: 30))
        }
        let frontData = try #require(front.jpegData(compressionQuality: 0.8))
        let backData = try #require(back.jpegData(compressionQuality: 0.8))
        let frontID = UUID().uuidString
        let backID = UUID().uuidString
        let deckID = UUID().uuidString
        var requests = [frontID: 0, backID: 0]
        CommunityTestProtocol.response = { request in
            if request.url!.path.hasSuffix(frontID) { requests[frontID, default: 0] += 1; return (200, frontData) }
            if request.url!.path.hasSuffix(backID) { requests[backID, default: 0] += 1; return (200, backData) }
            let cards: [[String: Any]] = (0..<2).map { index in
                ["id": "picture-\(index)", "question": "", "correctAnswer": "", "options": [], "hint": "", "cardType": "images",
                 "matchingLeftItems": [], "matchingRightItems": [], "sectionName": "", "promptImageID": frontID,
                 "answerImageID": backID, "optionImageIDs": []]
            }
            return (200, try json(["deck": ["id": deckID, "name": "Pairs", "description": "", "authorHandle": "@buddy",
                "categoryTag": "General", "colorHex": "#5B70E0", "deckType": "Mixed", "cardCount": 2, "downloadCount": 0,
                "cards": cards]]))
        }
        defer { CommunityTestProtocol.response = nil }
        let summary = CommunityDeckPayload(id: deckID, name: "Pairs", description: "", authorHandle: "@buddy", categoryTag: "General", colorHex: "#5B70E0", deckType: "Mixed", cardCount: 2, downloadCount: 0, publishedAt: nil)
        let downloaded = try await CommunityDeckTransfer.download(summary, api: api()) { _ in }
        let first = try #require(downloaded.cards.first)
        let frontName = try #require(first.promptImageName)
        let backName = try #require(first.answerImageName)
        defer { CardImageStore.deleteImage(named: frontName); CardImageStore.deleteImage(named: backName) }
        #expect(frontName != backName)
        #expect(downloaded.cards.count == 2)
        #expect(downloaded.cards[1].promptImageName == frontName)
        #expect(downloaded.cards[1].answerImageName == backName)
        #expect(requests[frontID] == 1 && requests[backID] == 1)
        let frontImage = try #require(CardImageStore.loadImage(named: frontName))
        let backImage = try #require(CardImageStore.loadImage(named: backName))
        #expect(abs(frontImage.size.width / frontImage.size.height - 1.5) < 0.01)
        #expect(abs(backImage.size.width / backImage.size.height - 2.0 / 3.0) < 0.01)
        #expect(first.cardType == .images && first.question.isEmpty && first.correctAnswer.isEmpty)
    }

    @Test("AI refinement preserves image-only cards outside its text context")
    func aiContextExcludesImageOnlyCards() {
        let deck = Deck(name: "Mixed")
        let picture = Flashcard(question: "", correctAnswer: "", cardType: .images, promptImageName: "picture.jpg")
        picture.answerImageName = "back.jpg"
        let word = Flashcard(question: "Hello", correctAnswer: "A greeting", cardType: .vocabulary)
        deck.cards = [picture, word]
        let generated = deck.toGeneratedDeck()
        #expect(generated.cards.count == 1)
        #expect(generated.cards.first?.id == word.id.uuidString)
        #expect(picture.promptImageName == "picture.jpg" && picture.answerImageName == "back.jpg")
        #expect(picture.cardType.isReviewOnly)
        #expect(!FlashcardType.multipleChoice.isReviewOnly)
    }

    @Test("Accepted review submissions include image/audio references and exclude private study material")
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
            return (202, try json(["id": draftID, "success": true, "reviewStatus": "pending"]))
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

    @Test("A removed community notice is not reused as a deck ID when submitting again")
    func removedPublication() async throws {
        let deck = Deck(name: "My deck")
        let previousID = UUID().uuidString
        let newID = UUID().uuidString
        deck.publishedCommunityID = previousID
        deck.cards = [Flashcard(question: "Q", correctAnswer: "A", cardType: .tapReveal)]
        CommunityTestProtocol.response = { request in
            let path = request.url!.path
            if path == "/v1/community/account/decks" {
                return (200, try json(["decks": [["id": previousID, "name": "Removed deck", "description": "",
                    "authorHandle": "@buddy", "categoryTag": "General", "colorHex": "#4868F8", "deckType": "Quiz",
                    "cardCount": 1, "downloadCount": 0, "status": "deleted", "adminAction": "removed"]], "nextOffset": NSNull()]))
            }
            if path == "/v1/community/decks/drafts" { return (201, try json(["id": newID])) }
            #expect(path == "/v1/community/decks/\(newID)")
            return (202, try json(["id": newID, "success": true]))
        }
        defer { CommunityTestProtocol.response = nil }
        let id = try await CommunityDeckTransfer.publish(deck: deck, category: "General", description: "", token: "owner", api: api()) { _ in }
        #expect(id == newID)
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

    @Test("Built-in and downloaded decks are blocked before any network or media transfer")
    func preventsRepublication() async throws {
        var requests = 0
        CommunityTestProtocol.response = { _ in requests += 1; return (500, Data()) }
        defer { CommunityTestProtocol.response = nil }
        let downloaded = Deck(name: "Renamed downloaded deck")
        downloaded.sourceCommunityID = UUID().uuidString
        let builtIn = Deck(name: "Renamed exam deck")
        builtIn.sourcePremadeID = "exam-original"
        let course = Deck(name: "Renamed course", deckType: "Course")
        for deck in [downloaded, builtIn, course] {
            deck.cards = [Flashcard(question: "Q", correctAnswer: "A", cardType: .tapReveal)]
            #expect(!deck.canShareToCommunity)
            do {
                _ = try await CommunityDeckTransfer.publish(deck: deck, category: "General", description: "", token: "test", api: api()) { _ in }
                Issue.record("A restricted deck was published")
            } catch let error as CommunityAPIError { #expect(error.status == 403) }
        }
        #expect(requests == 0)
        let personal = Deck(name: "Original")
        personal.publishedCommunityID = UUID().uuidString
        personal.cards = [Flashcard(question: "My own Q", correctAnswer: "My own A", cardType: .tapReveal)]
        #expect(personal.canShareToCommunity)
    }

    @Test("Older built-in imports remain restricted after renaming, reordering, and adding a card")
    func recognizesLegacyBuiltIn() throws {
        let source = try #require(PremadeDeckCatalog.decks.first)
        let deck = Deck(name: "A renamed built-in")
        deck.cards = source.cards.reversed().map { Flashcard(question: $0.question.uppercased(), correctAnswer: $0.correctAnswer,
            cardType: $0.cardType, matchingLeftItems: $0.matchingLeftItems, matchingRightItems: $0.matchingRightItems) }
        deck.cards.append(Flashcard(question: "An extra question", correctAnswer: "Extra", cardType: .tapReveal))
        #expect(deck.sourcePremadeID == nil)
        #expect(!deck.canShareToCommunity)
    }

    @Test("All expanded character choices retain their original IDs and survive profile encoding")
    func expandedCharacterCompatibility() throws {
        #expect(CommunityAvatar.hairNames.count == 16)
        #expect(CommunityAvatar.eyeNames.count == 16)
        #expect(CommunityAvatar.mouthNames.count == 16)
        for part in 0..<16 {
            let avatar = CommunityAvatar(hair: part, eyes: part, mouth: part, skinTone: part % 7)
            #expect(try JSONDecoder().decode(CommunityAvatar.self, from: JSONEncoder().encode(avatar)) == avatar)
        }
    }

    @Test("Community browsing appends twenty-card batches and resets when the query changes")
    func communityPaging() async throws {
        let total = 43
        var offsets: [Int] = []
        CommunityTestProtocol.response = { request in
            let components = try #require(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
            let values = Dictionary(uniqueKeysWithValues: components.queryItems!.map { ($0.name, $0.value ?? "") })
            #expect(values["limit"] == "20")
            #expect(values["sort"] == "popular")
            let offset = Int(values["offset"]!)!
            offsets.append(offset)
            let decks: [[String: Any]] = offset >= total ? [] : (offset..<min(offset + 20, total)).map { index in
                ["id": "deck-\(index)", "name": "Deck \(index)", "description": "", "authorHandle": "@cozy_otter", "categoryTag": "Science",
                 "colorHex": "#4868F8", "deckType": "Quiz", "cardCount": 10, "downloadCount": index]
            }
            return (200, try json(["decks": decks, "totalCount": total, "nextOffset": offset + 20 < total ? offset + 20 : NSNull()]))
        }
        defer { CommunityTestProtocol.response = nil }
        let store = CommunityFeedStore(api: api())
        await store.load()
        #expect(store.decks.count == 20 && store.hasMore)
        await store.loadNextPage()
        #expect(store.decks.count == 40 && store.decks.last?.id == "deck-39")
        await store.loadNextPage()
        #expect(store.decks.count == 43 && !store.hasMore)
        await store.loadNextPage()
        #expect(offsets == [0, 20, 40])
        store.search = "new query"
        #expect(!store.hasLoaded && store.decks.isEmpty)
        await store.load()
        #expect(store.decks.count == 20 && store.hasMore)
    }

    @Test("My community decks includes review status and rejection notes; older payloads still decode")
    func communityReviewStates() async throws {
        CommunityTestProtocol.response = { request in
            #expect(request.url?.path == "/v1/community/account/decks")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer owner-token")
            let rows: [[String: Any]] = ["pending", "approved", "rejected"].map { status in
                ["id": status, "name": "My deck", "description": "", "authorHandle": "@cozy_otter", "categoryTag": "General",
                 "colorHex": "#4868F8", "deckType": "Quiz", "cardCount": 5, "downloadCount": 0,
                 "reviewStatus": status, "reviewMessage": status == "rejected" ? "Please correct the answer on card 2." : "",
                 "submittedAt": 1791900000]
            }
            return (200, try json(["decks": rows, "nextOffset": NSNull()]))
        }
        defer { CommunityTestProtocol.response = nil }
        let page = try await api().myDecks(token: "owner-token")
        #expect(page.decks.map(\.reviewStatus) == ["pending", "approved", "rejected"])
        #expect(page.decks.last?.reviewMessage == "Please correct the answer on card 2.")
        #expect(page.decks.first?.submittedAt == 1791900000)
        let legacy = try JSONDecoder().decode(CommunityDeckPayload.self, from: json([
            "id": "legacy", "name": "Published deck", "description": "", "authorHandle": "@buddy", "categoryTag": "General",
            "colorHex": "#4868F8", "deckType": "Quiz", "cardCount": 5, "downloadCount": 4]))
        #expect(legacy.reviewStatus == nil && legacy.reviewMessage == nil && legacy.submittedAt == nil)
        #expect(legacy.adminNote == nil && !legacy.isRemoved)
    }

    @Test("Refreshing owned decks replaces admin edits with removal notices and keeps data on connection failure")
    func refreshesAdminChanges() async throws {
        var removed = false
        var failing = false
        CommunityTestProtocol.response = { request in
            #expect(request.cachePolicy == .reloadIgnoringLocalCacheData)
            if failing { throw URLError(.notConnectedToInternet) }
            return (200, try json(["decks": [[
                "id": "moderated-deck", "name": removed ? "Corrected deck" : "Original deck", "description": "",
                "authorHandle": "@cozy_otter", "categoryTag": "General", "colorHex": "#4868F8", "deckType": "Quiz",
                "cardCount": 5, "downloadCount": 0, "status": removed ? "deleted" : "published",
                "adminNote": removed ? "Removed due to inappropriate content." : "Corrected the title.",
                "adminAction": removed ? "removed" : "edited", "adminUpdatedAt": 1791900000, "isHidden": false
            ]], "nextOffset": NSNull()]))
        }
        defer { CommunityTestProtocol.response = nil }
        let store = CommunityOwnedDeckStore(api: api())
        await store.load(token: "owner")
        #expect(store.decks.first?.adminNote == "Corrected the title.")
        #expect(store.decks.first?.isRemoved == false)
        removed = true
        await store.load(token: "owner")
        #expect(store.decks.count == 1 && store.decks.first?.name == "Corrected deck")
        #expect(store.decks.first?.isRemoved == true)
        #expect(store.decks.first?.adminAction == "removed")
        #expect(store.decks.first?.adminNote == "Removed due to inappropriate content.")
        failing = true
        await store.load(token: "owner")
        #expect(store.decks.count == 1 && store.errorMessage != nil && !store.isLoading)
        // A different account must never keep the previous author's notices, even offline.
        await store.load(token: "another-owner")
        #expect(store.decks.isEmpty && store.errorMessage != nil)
        store.clear()
        #expect(store.errorMessage == nil && !store.isLoading)
    }

    @Test("Owned deck pagination includes older admin notices and authenticates every page")
    func ownedDeckPagination() async throws {
        var offsets: [String?] = []
        CommunityTestProtocol.response = { request in
            let offset = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first?.value
            offsets.append(offset)
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer owner")
            #expect(request.cachePolicy == .reloadIgnoringLocalCacheData)
            return (200, try json(["decks": [[
                "id": offset == nil ? "active" : "removed", "name": "My deck", "description": "",
                "authorHandle": "@buddy", "categoryTag": "General", "colorHex": "#4868F8", "deckType": "Quiz",
                "cardCount": 5, "downloadCount": 0, "status": offset == nil ? "published" : "deleted"
            ]], "nextOffset": offset == nil ? 50 : NSNull()]))
        }
        defer { CommunityTestProtocol.response = nil }
        let page = try await api().myDecks(token: "owner")
        #expect(offsets == [nil, "50"])
        #expect(page.decks.map(\.id) == ["active", "removed"])
        #expect(page.decks.last?.isRemoved == true && page.nextOffset == nil)
    }

    @Test("Blocking and unblocking authenticate requests without exposing an Apple identifier")
    func authorBlocks() async throws {
        let authorID = UUID().uuidString
        var calls: [String] = []
        CommunityTestProtocol.response = { request in
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer viewer")
            let path = request.url!.path
            calls.append("\(request.httpMethod ?? "GET") \(path)")
            if request.httpMethod == "POST" {
                let body = try JSONSerialization.jsonObject(with: requestBody(request)) as! [String: String]
                #expect(body == ["authorID": authorID])
            }
            if request.httpMethod == "GET" { return (200, try json(["users": [["id": authorID, "handle": "@cozy_otter"]]])) }
            return (200, try json(["success": true]))
        }
        defer { CommunityTestProtocol.response = nil }
        let client = api()
        try await client.block(authorID: authorID, token: "viewer")
        let users = try await client.blockedUsers(token: "viewer")
        #expect(users == [.init(id: authorID, handle: "@cozy_otter")])
        try await client.unblock(authorID: authorID, token: "viewer")
        #expect(calls == ["POST /v1/community/account/blocks", "GET /v1/community/account/blocks", "DELETE /v1/community/account/blocks/\(authorID)"])
    }

    @Test("Switching viewers clears the feed and reloads using that viewer's blocks")
    func viewerSpecificFeed() async throws {
        CommunityTestProtocol.response = { request in
            let token = request.value(forHTTPHeaderField: "Authorization")
            return (200, try json(["decks": [[
                "id": token == "Bearer first" ? "first" : "second", "name": "Deck", "description": "", "authorHandle": "@buddy",
                "authorID": "public-author", "categoryTag": "General", "colorHex": "#4868F8", "deckType": "Quiz", "cardCount": 5, "downloadCount": 0
            ]], "nextOffset": NSNull(), "totalCount": 1]))
        }
        defer { CommunityTestProtocol.response = nil }
        let store = CommunityFeedStore(api: api())
        store.setViewer(token: "first")
        await store.load()
        #expect(store.decks.first?.id == "first")
        store.setViewer(token: "second")
        #expect(store.decks.isEmpty && !store.hasLoaded)
        await store.load()
        #expect(store.decks.first?.id == "second" && store.decks.first?.authorID == "public-author")
    }

    @Test("Apple confirmation is included in account deletion without signing into a different account")
    func accountDeletionConfirmation() async throws {
        CommunityTestProtocol.response = { request in
            #expect(request.httpMethod == "DELETE" && request.url?.path == "/v1/community/account")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer original-session")
            let body = try JSONSerialization.jsonObject(with: requestBody(request)) as! [String: String]
            #expect(body == ["identityToken": "fresh-identity", "authorizationCode": "fresh-code", "nonce": "fresh-nonce"])
            return (200, try json(["success": true]))
        }
        defer { CommunityTestProtocol.response = nil }
        try await api().deleteAccount(token: "original-session", reauthentication: .init(identityToken: "fresh-identity", authorizationCode: "fresh-code", nonce: "fresh-nonce"))
    }

    @Test("Deletion finishes after Apple's revocation notification without clearing another account")
    func deletionRevocationRace() async throws {
        var responseToken = "deleting-session"
        CommunityTestProtocol.response = { _ in
            (200, try json(["token": responseToken, "expiresAt": Int(Date().timeIntervalSince1970) + 3600, "handle": "@buddy"]))
        }
        defer { CommunityTestProtocol.response = nil }
        let session = CommunitySession(service: "com.learnalert.tests.\(UUID())", api: api()) { _ in .authorized }
        defer { session.signOut() }
        let signedIn = await session.signIn(identityToken: "identity", nonce: "nonce", givenName: nil)
        #expect(signedIn, "Session error: \(session.errorMessage ?? "none")")
        session.appleCredentialRevoked()
        #expect(session.completeAccountDeletion(token: "deleting-session"))
        #expect(session.credentials == nil && session.errorMessage == nil)

        responseToken = "other-account-session"
        let switched = await session.signIn(identityToken: "other-identity", nonce: "nonce", givenName: nil)
        #expect(switched)
        #expect(!session.completeAccountDeletion(token: "deleting-session"))
        #expect(session.token == "other-account-session")
        #expect(session.completeAccountDeletion(token: "other-account-session"))
        #expect(session.credentials == nil)
    }

    @Test("Revoked Apple credentials clear a session; transient Apple errors preserve it")
    func appleCredentialLifecycle() async throws {
        var state: ASAuthorizationAppleIDProvider.CredentialState = .authorized
        var appleOffline = false
        var checkedIDs: [String] = []
        CommunityTestProtocol.response = { request in
            if request.httpMethod == "POST" {
                let body = try JSONSerialization.jsonObject(with: requestBody(request)) as! [String: String]
                #expect(body["authorizationCode"] == "single-use-code")
                return (200, try json(["token": "local-session", "expiresAt": Int(Date().timeIntervalSince1970) + 3600, "handle": "@buddy"]))
            }
            return (200, try json(["handle": "@buddy", "avatar": ["hair": 0, "eyes": 0, "mouth": 0], "isComplete": true, "authorID": "public-id"]))
        }
        defer { CommunityTestProtocol.response = nil }
        let session = CommunitySession(service: "com.learnalert.tests.\(UUID())", api: api()) { id in
            checkedIDs.append(id)
            if appleOffline { throw URLError(.notConnectedToInternet) }
            return state
        }
        defer { session.signOut() }
        let signedIn = await session.signIn(identityToken: "identity", nonce: "nonce", givenName: nil, authorizationCode: "single-use-code", appleUserID: "apple-user")
        #expect(signedIn && session.credentials?.appleUserID == "apple-user", "Session error: \(session.errorMessage ?? "none")")
        await session.validateAppleCredential()
        #expect(session.isSignedIn && session.profile.authorID == "public-id")
        appleOffline = true
        await session.validateAppleCredential()
        #expect(session.isSignedIn)
        appleOffline = false; state = .revoked
        await session.validateAppleCredential()
        #expect(!session.isSignedIn && session.credentials == nil)
        #expect(checkedIDs == ["apple-user", "apple-user", "apple-user"])
        #expect(session.errorMessage?.contains("Apple access changed") == true)
        let signedInAgain = await session.signIn(identityToken: "identity", nonce: "nonce", givenName: nil, authorizationCode: "single-use-code", appleUserID: "apple-user")
        #expect(signedInAgain)
        session.handle(CommunityAPIError(status: 403, message: "Community access restricted.", code: "ACCOUNT_BANNED"))
        #expect(session.isSignedIn && session.isRestricted)
        #expect(session.profile.restrictionMessage == "Community access restricted.")
        // A restored account gets its current status from the owner-only profile endpoint.
        await session.refreshProfile()
        #expect(session.isSignedIn && !session.isRestricted)
    }

}
