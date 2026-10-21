import Foundation
import CoreGraphics

/// Activities belong to the course curriculum, independently of FlashcardType.
public struct CourseActivity: Codable, Hashable {
    public enum Kind: String, Codable { case teach, trace, buildBlock, placeTokens, listenChoose, situation, matchPairs }
    public enum Layout: String, Codable { case beside, below, besideWithFinal, belowWithFinal, inline }
    public let kind: Kind
    public let sequence: Int
    public var rule: String? = nil
    public var example: String? = nil
    public var symbol: String? = nil
    public var layout: Layout = .inline
    public var tokens: [String] = []
    public var slots: [String] = []
    public var slotLabels: [String] = []
    public var optionHints: [String: String] = [:]
    public var readingCue: String? = nil
    public var practiceGroup: String? = nil
}

struct CourseTraceGuidance {
    let attempt: Int
    var needsHelp = false
    var elapsed: TimeInterval = 0
    var showsGuide: Bool { attempt <= 2 || needsHelp || elapsed >= 60 }
    var highlightsDirection: Bool { needsHelp || elapsed >= 60 }
}

struct CoursePlacementState {
    var values: [String?]
    var selectedToken: String?
    var hadMistake = false
    init(count: Int) { values = Array(repeating: nil, count: count) }
    var filled: Bool { !values.isEmpty && values.allSatisfy { $0 != nil } }
    mutating func place(_ token: String, in slot: Int, available: [String]) -> Bool {
        guard values.indices.contains(slot), available.contains(token) else { return false }
        values[slot] = token
        selectedToken = nil
        return true
    }
    mutating func check(expected: [String]) -> Bool {
        let correct = values.count == expected.count && zip(values, expected).allSatisfy { $0.0 == $0.1 }
        if !correct { hadMistake = true }
        return correct
    }
}

/// Normalized stroke guides, with ordered geometric checking rather than handwriting recognition.
enum HangulStrokeGuide {
    static func strokes(for symbol: String) -> [[CGPoint]] {
        func p(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x, y: y) }
        switch symbol {
        case "ㅏ": return [[p(0.44, 0.18), p(0.44, 0.82)], [p(0.44, 0.49), p(0.75, 0.49)]]
        case "ㅓ": return [[p(0.25, 0.49), p(0.57, 0.49)], [p(0.57, 0.18), p(0.57, 0.82)]]
        case "ㅗ": return [[p(0.50, 0.25), p(0.50, 0.64)], [p(0.20, 0.64), p(0.80, 0.64)]]
        case "ㅜ": return [[p(0.20, 0.38), p(0.80, 0.38)], [p(0.50, 0.38), p(0.50, 0.77)]]
        case "ㅡ": return [[p(0.18, 0.50), p(0.82, 0.50)]]
        case "ㅣ": return [[p(0.50, 0.18), p(0.50, 0.82)]]
        case "ㄱ": return [[p(0.22, 0.25), p(0.76, 0.25), p(0.76, 0.78)]]
        case "ㄴ": return [[p(0.25, 0.20), p(0.25, 0.76), p(0.80, 0.76)]]
        case "ㅁ": return [[p(0.25, 0.24), p(0.25, 0.76)], [p(0.25, 0.24), p(0.75, 0.24), p(0.75, 0.76)], [p(0.25, 0.76), p(0.75, 0.76)]]
        case "ㄷ": return [[p(0.24, 0.24), p(0.78, 0.24)], [p(0.24, 0.24), p(0.24, 0.77), p(0.78, 0.77)]]
        case "ㄹ": return [[p(0.22, 0.23), p(0.76, 0.23), p(0.76, 0.48)], [p(0.22, 0.48), p(0.76, 0.48)], [p(0.22, 0.48), p(0.22, 0.77), p(0.78, 0.77)]]
        case "ㅂ": return [[p(0.27, 0.20), p(0.27, 0.78)], [p(0.73, 0.20), p(0.73, 0.78)], [p(0.27, 0.48), p(0.73, 0.48)], [p(0.27, 0.78), p(0.73, 0.78)]]
        case "ㅅ": return [[p(0.50, 0.22), p(0.43, 0.48), p(0.21, 0.77)], [p(0.46, 0.43), p(0.77, 0.77)]]
        case "ㅈ": return [[p(0.22, 0.23), p(0.78, 0.23)], [p(0.50, 0.23), p(0.43, 0.49), p(0.21, 0.78)], [p(0.46, 0.44), p(0.77, 0.78)]]
        case "ㅎ": return [[p(0.35, 0.17), p(0.65, 0.17)], [p(0.22, 0.32), p(0.78, 0.32)], (0...32).map { index in
            let angle = -Double.pi / 2 - Double(index) / 32 * 2 * Double.pi
            return p(0.5 + cos(angle) * 0.22, 0.63 + sin(angle) * 0.20)
        }]
        case "ㅇ": return [(0...32).map { index in
            let angle = -Double.pi / 2 - Double(index) / 32 * 2 * Double.pi
            return p(0.5 + cos(angle) * 0.29, 0.5 + sin(angle) * 0.29)
        }]
        default: return []
        }
    }

    static func accepts(_ input: [CGPoint], target: [CGPoint], tolerance: CGFloat = 0.13) -> Bool {
        let length = zip(input, input.dropFirst()).reduce(CGFloat.zero) { $0 + distance($1.0, $1.1) }
        guard input.count >= 2, length > 0.15, let first = input.first, let last = input.last,
              let start = target.first, let end = target.last,
              distance(first, start) < tolerance * 1.5, distance(last, end) < tolerance * 1.5 else { return false }
        let samples = resample(target)
        // A fast straight stroke may deliver only its endpoints. Judge its path,
        // rather than requiring a particular number of touchscreen events.
        let drawn = resample(input)
        let onGuide = drawn.filter { point in samples.contains { distance(point, $0) < tolerance } }.count
        let covered = samples.filter { point in drawn.contains { distance(point, $0) < tolerance } }.count
        guard Double(onGuide) / Double(drawn.count) >= 0.8,
              Double(covered) / Double(max(1, samples.count)) >= 0.85 else { return false }
        // Follow the guide in order, including a closed circle's direction.
        var cursor = 0
        for point in samples {
            guard let next = drawn.indices.dropFirst(cursor).first(where: { distance(drawn[$0], point) < tolerance }) else { return false }
            cursor = next
        }
        return true
    }

    private static func distance(_ lhs: CGPoint, _ rhs: CGPoint) -> CGFloat { hypot(lhs.x - rhs.x, lhs.y - rhs.y) }
    private static func resample(_ points: [CGPoint]) -> [CGPoint] {
        guard points.count > 1 else { return points }
        return zip(points, points.dropFirst()).flatMap { start, end in
            let steps = max(1, Int(ceil(distance(start, end) / 0.02)))
            return (0...steps).map { index in
                let t = CGFloat(index) / CGFloat(steps)
                return CGPoint(x: start.x + (end.x - start.x) * t, y: start.y + (end.y - start.y) * t)
            }
        }
    }
}

extension CourseActivity {
    private enum CodingKeys: String, CodingKey {
        case kind, sequence, rule, example, symbol, layout, tokens, slots, slotLabels, optionHints, readingCue, practiceGroup
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(kind: try c.decode(Kind.self, forKey: .kind), sequence: try c.decode(Int.self, forKey: .sequence))
        rule = try c.decodeIfPresent(String.self, forKey: .rule)
        example = try c.decodeIfPresent(String.self, forKey: .example)
        symbol = try c.decodeIfPresent(String.self, forKey: .symbol)
        layout = try c.decodeIfPresent(Layout.self, forKey: .layout) ?? .inline
        tokens = try c.decodeIfPresent([String].self, forKey: .tokens) ?? []
        slots = try c.decodeIfPresent([String].self, forKey: .slots) ?? []
        slotLabels = try c.decodeIfPresent([String].self, forKey: .slotLabels) ?? []
        optionHints = try c.decodeIfPresent([String: String].self, forKey: .optionHints) ?? [:]
        readingCue = try c.decodeIfPresent(String.self, forKey: .readingCue)
        practiceGroup = try c.decodeIfPresent(String.self, forKey: .practiceGroup)
    }
}
