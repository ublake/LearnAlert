import Foundation

public struct CourseGuideTopic: Identifiable, Codable, Hashable {
    public var id: String { title }
    public let title: String
    public let rule: String
    public let examples: [String]
}

public struct CourseGuidePresentation: Codable, Hashable {
    public var showsHangulDiagram: Bool = false
    public var referenceTitle: String?
    public var referenceURL: String?
    public var diagramTitle: String?
    public var diagramFooter: String?
    public var diagramExamples: [CourseGuideDiagramExample]?
}

public struct CourseGuideDiagramExample: Codable, Hashable {
    public let syllable: String
    public let caption: String
    public let initial: String
    public let vowel: String
    public var finalLetter: String? = nil
    public var layout: String = "beside"

    static let bundled: [CourseGuideDiagramExample] = [
        .init(syllable: "가", caption: "Vertical vowel", initial: "ㄱ", vowel: "ㅏ"),
        .init(syllable: "고", caption: "Horizontal vowel", initial: "ㄱ", vowel: "ㅗ", layout: "below"),
        .init(syllable: "한", caption: "With batchim", initial: "ㅎ", vowel: "ㅏ", finalLetter: "ㄴ")
    ]
}

extension CourseGuideDiagramExample {
    private enum CodingKeys: String, CodingKey { case syllable, caption, initial, vowel, finalLetter, layout }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(syllable: try c.decode(String.self, forKey: .syllable), caption: try c.decode(String.self, forKey: .caption),
            initial: try c.decode(String.self, forKey: .initial), vowel: try c.decode(String.self, forKey: .vowel),
            finalLetter: try c.decodeIfPresent(String.self, forKey: .finalLetter), layout: try c.decodeIfPresent(String.self, forKey: .layout) ?? "beside")
    }
}

extension CourseGuidePresentation {
    private enum CodingKeys: String, CodingKey { case showsHangulDiagram, referenceTitle, referenceURL, diagramTitle, diagramFooter, diagramExamples }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(showsHangulDiagram: try c.decodeIfPresent(Bool.self, forKey: .showsHangulDiagram) ?? false,
            referenceTitle: try c.decodeIfPresent(String.self, forKey: .referenceTitle),
            referenceURL: try c.decodeIfPresent(String.self, forKey: .referenceURL),
            diagramTitle: try c.decodeIfPresent(String.self, forKey: .diagramTitle),
            diagramFooter: try c.decodeIfPresent(String.self, forKey: .diagramFooter),
            diagramExamples: try c.decodeIfPresent([CourseGuideDiagramExample].self, forKey: .diagramExamples))
    }
}

/// Bundled, original teaching notes. No network connection is needed in an alert.
