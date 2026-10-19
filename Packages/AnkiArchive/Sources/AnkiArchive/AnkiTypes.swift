import Foundation

public enum AnkiImportError: LocalizedError {
    case invalid(String)
    public var errorDescription: String? {
        switch self { case .invalid(let reason): return reason }
    }
}

public struct AnkiImportProgress: Sendable {
    public let fraction: Double
    public let title: String
    public let detail: String
    public let completedItems: Int?
    public let totalItems: Int?
    public let unit: String
    public let processedBytes: Int?
    public let archiveBytes: Int?
    public init(_ fraction: Double, _ title: String, _ detail: String = "",
                completedItems: Int? = nil, totalItems: Int? = nil, unit: String = "",
                processedBytes: Int? = nil, archiveBytes: Int? = nil) {
        self.fraction = fraction; self.title = title; self.detail = detail
        self.completedItems = completedItems; self.totalItems = totalItems; self.unit = unit
        self.processedBytes = processedBytes; self.archiveBytes = archiveBytes
    }
}

public struct AnkiTemplate: Sendable {
    public let name: String
    public let front: String
    public let back: String
    public init(name: String, front: String, back: String) { self.name = name; self.front = front; self.back = back }
}

public struct AnkiNoteType: Sendable {
    public let id: String
    public let name: String
    public let fields: [String]
    public let templates: [AnkiTemplate]
    public let css: String
    public let isCloze: Bool
    public init(id: String, name: String, fields: [String], templates: [AnkiTemplate], css: String, isCloze: Bool) {
        self.id = id; self.name = name; self.fields = fields; self.templates = templates; self.css = css; self.isCloze = isCloze
    }
}

public struct AnkiImportedCard: Sendable, Identifiable {
    public let id: String
    public let noteGUID: String
    public let deckID: String
    public let deckName: String
    public let templateOrdinal: Int
    public let noteType: String
    public let front: String
    public let back: String
    public let css: String
    public let plainFront: String
    public let plainBack: String
    public let tags: [String]
    public let warnings: [String]
}

public struct AnkiImportedDeck: Sendable, Identifiable {
    public let id: String
    public let name: String
    public let cardCount: Int
}

public struct AnkiImportPackage: Sendable {
    public let cards: [AnkiImportedCard]
    public let decks: [AnkiImportedDeck]
    public let mediaDirectory: URL
    public let mediaCount: Int
    public let mediaBytes: Int
    public let mediaFiles: [String: String]
    public let warnings: [String]
    public let skippedCards: Int
}

// Minimal protobuf wire decoder for APKG metadata and modern collection records.
// Unknown fields are skipped, so additions do not change the fields we read.
struct AnkiProto {
    struct Field { let number: Int; let integer: UInt64?; let bytes: Data? }
    let fields: [Field]
    init(_ data: Data) throws {
        let bytes = [UInt8](data)
        var position = 0
        func varint() throws -> UInt64 {
            var value: UInt64 = 0
            for shift in stride(from: 0, through: 63, by: 7) {
                guard position < bytes.count else { throw AnkiImportError.invalid("The Anki package contains incomplete metadata.") }
                let byte = bytes[position]; position += 1
                if shift == 63 && byte > 1 { throw AnkiImportError.invalid("The Anki package contains invalid metadata.") }
                value |= UInt64(byte & 127) << shift
                if byte & 128 == 0 { return value }
            }
            throw AnkiImportError.invalid("The Anki package contains invalid metadata.")
        }
        var result: [Field] = []
        while position < bytes.count {
            let key = try varint(), number = Int(key >> 3)
            guard number > 0 else { throw AnkiImportError.invalid("The Anki package contains invalid metadata.") }
            switch key & 7 {
            case 0: result.append(Field(number: number, integer: try varint(), bytes: nil))
            case 1, 5:
                position += key & 7 == 1 ? 8 : 4
                guard position <= bytes.count else { throw AnkiImportError.invalid("The Anki package contains incomplete metadata.") }
            case 2:
                let length = try varint()
                guard length <= UInt64(bytes.count - position) else { throw AnkiImportError.invalid("The Anki package contains incomplete metadata.") }
                result.append(Field(number: number, integer: nil, bytes: Data(bytes[position..<position + Int(length)])))
                position += Int(length)
            default: throw AnkiImportError.invalid("This Anki metadata format is not supported.")
            }
        }
        fields = result
    }
    func integer(_ number: Int) -> UInt64 { fields.first { $0.number == number }?.integer ?? 0 }
    func string(_ number: Int) -> String { fields.first { $0.number == number }?.bytes.flatMap { String(data: $0, encoding: .utf8) } ?? "" }
    func messages(_ number: Int) -> [Data] { fields.filter { $0.number == number }.compactMap(\.bytes) }
}
