import Foundation

/// Converts Anki field/conditional/cloze syntax into self-contained front/back HTML.
/// Layout and scripts remain in the card; unknown filters are reported in the preview.
public enum AnkiTemplateRenderer {
    public struct Result: Sendable { public let front: String; public let back: String; public let warnings: [String] }
    private indirect enum Node { case text(String), field(String), section(String, Bool, [Node]) }

    public static func render(type: AnkiNoteType, values: [String], ordinal: Int,
                              deck: String, tags: [String]) throws -> Result {
        guard let template = type.templates[safe: type.isCloze ? 0 : ordinal] else {
            throw AnkiImportError.invalid("A card references a missing Anki template.")
        }
        var fields: [String: String] = [:]
        for (name, value) in zip(type.fields, values) { fields[name] = value }
        fields["Tags"] = tags.joined(separator: " "); fields["Type"] = type.name
        fields["Deck"] = deck; fields["Subdeck"] = deck.components(separatedBy: "::").last ?? deck
        fields["Card"] = template.name; fields["CardFlag"] = ""
        fields["c\(ordinal + 1)"] = "1"
        if template.front.contains("anki.imageOcclusion.setup"), fields["Occlusion"] != nil {
            return try AnkiImageOcclusion.render(fields: fields, ordinal: ordinal)
        }
        var warnings = Set<String>()
        let frontNodes = try parse(template.front), backNodes = try parse(template.back)
        let front = evaluate(frontNodes, fields: fields, answer: false, ordinal: ordinal, warnings: &warnings)
        fields["FrontSide"] = front
        let back = evaluate(backNodes, fields: fields, answer: true, ordinal: ordinal, warnings: &warnings)
        for content in [front, back, type.css] {
            if content.range(of: #"(?:src\s*=\s*["']?https?://|url\s*\(\s*["']?https?://|https?://[^\s"']+\.(?:js|css))"#, options: .regularExpression) != nil {
                warnings.insert("Some cards reference online media or libraries. Only bundled files are available during offline study.")
            }
            if content.contains("anki.imageOcclusion") || content.contains("anki.setupImageOcclusion") {
                warnings.insert("This deck uses Anki's image-occlusion runtime. Check the sample before importing.")
            }
            if content.contains("\\(") || content.contains("\\[") || content.contains("[latex]") {
                warnings.insert("Equations use LearnAlert's offline KaTeX renderer. Anki-specific MathJax macros and full LaTeX documents may need adjustment.")
            }
        }
        return Result(front: soundHTML(front), back: soundHTML(back), warnings: warnings.sorted())
    }

    private static func parse(_ input: String) throws -> [Node] {
        let expression = try NSRegularExpression(pattern: #"\{\{([^{}]+)\}\}"#)
        let text = input as NSString
        let matches = expression.matches(in: input, range: NSRange(location: 0, length: text.length))
        var index = 0, cursor = 0
        func nodes(until closing: String? = nil, depth: Int = 0) throws -> [Node] {
            guard depth < 64 else { throw AnkiImportError.invalid("An Anki template is nested too deeply.") }
            var result: [Node] = []
            while index < matches.count {
                let match = matches[index]
                if match.range.location > cursor { result.append(.text(text.substring(with: NSRange(location: cursor, length: match.range.location - cursor)))) }
                let token = text.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
                cursor = NSMaxRange(match.range); index += 1
                if token.hasPrefix("/") {
                    guard String(token.dropFirst()) == closing else { throw AnkiImportError.invalid("An Anki template contains an unmatched conditional.") }
                    return result
                }
                if token.hasPrefix("#") || token.hasPrefix("^") {
                    let name = String(token.dropFirst())
                    result.append(.section(name, token.hasPrefix("^"), try nodes(until: name, depth: depth + 1)))
                } else if !token.hasPrefix("!") { result.append(.field(token)) }
            }
            guard closing == nil else { throw AnkiImportError.invalid("An Anki template contains an unfinished conditional.") }
            if cursor < text.length { result.append(.text(text.substring(from: cursor))); cursor = text.length }
            return result
        }
        return try nodes()
    }

    private static func evaluate(_ nodes: [Node], fields: [String: String], answer: Bool, ordinal: Int,
                                 warnings: inout Set<String>) -> String {
        nodes.map { node -> String in
            switch node {
            case .text(let text): return text
            case .section(let name, let inverted, let children):
                let value = fields[name] ?? ""
                let exists = !plainText(value).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || value.range(of: #"<(?:img|audio|video)\b|\[sound:"#, options: .regularExpression) != nil
                return exists != inverted ? evaluate(children, fields: fields, answer: answer, ordinal: ordinal, warnings: &warnings) : ""
            case .field(let token):
                let parts = token.components(separatedBy: ":")
                let name = parts.last ?? token
                guard var value = fields[name] else { warnings.insert("Unknown template field: \(name)"); return "" }
                for filter in parts.dropLast().reversed() {
                    switch filter {
                    case "cloze", "cloze-only": value = cloze(value, target: ordinal + 1, answer: answer)
                    case "text": value = escape(plainText(value))
                    case "type":
                        // Self-assessment retains keyboard-free review for imported cards.
                        value = answer ? "<span class=\"type-answer\">\(escape(plainText(value)))</span>" : ""
                    case "furigana": value = furigana(value, mode: 0)
                    case "kana": value = furigana(value, mode: 1)
                    case "kanji": value = furigana(value, mode: 2)
                    case "hint": value = "<details><summary>\(escape(name))</summary>\(value)</details>"
                    case "": break
                    default:
                        if filter.hasPrefix("tts ") {
                            let language = filter.components(separatedBy: " ").first { $0.hasPrefix("lang=") }.map { String($0.dropFirst(5)) } ?? "en-US"
                            value = "<button class=\"anki-sound\" data-speech=\"\(escape(plainText(value)))\" data-language=\"\(escape(language))\">▶ Listen</button>"
                        } else { warnings.insert("Custom filter ‘\(filter)’ is shown without its Anki add-on transformation.") }
                    }
                }
                return value
            }
        }.joined()
    }

    // Recursive cloze parser preserves nested deletions and separate deletion groups.
    public static func cloze(_ text: String, target: Int, answer: Bool) -> String {
        cloze(text, target: target, answer: answer, depth: 0)
    }

    private static func cloze(_ text: String, target: Int, answer: Bool, depth recursion: Int) -> String {
        guard recursion < 64 else { return escape(text) }
        var output = "", cursor = text.startIndex
        while let open = text.range(of: "{{c", range: cursor..<text.endIndex) {
            output += String(text[cursor..<open.lowerBound])
            var pos = open.upperBound, digits = ""
            while pos < text.endIndex, text[pos].isNumber { digits.append(text[pos]); pos = text.index(after: pos) }
            guard !digits.isEmpty, text[pos...].hasPrefix("::") else { output += "{{c"; cursor = open.upperBound; continue }
            pos = text.index(pos, offsetBy: 2)
            let contentStart = pos
            var depth = 1, separator: String.Index?
            while pos < text.endIndex {
                if text[pos...].hasPrefix("{{") { depth += 1; pos = text.index(pos, offsetBy: 2); continue }
                if text[pos...].hasPrefix("}}") {
                    depth -= 1
                    if depth == 0 { break }
                    pos = text.index(pos, offsetBy: 2); continue
                }
                if depth == 1, separator == nil, text[pos...].hasPrefix("::") { separator = pos }
                pos = text.index(after: pos)
            }
            guard depth == 0 else { output += String(text[open.lowerBound...]); return output }
            let content = String(text[contentStart..<(separator ?? pos)])
            if Int(digits) == target {
                if answer { output += "<span class=\"cloze\">\(cloze(content, target: target, answer: true, depth: recursion + 1))</span>" }
                else {
                    let hint = separator.map { String(text[text.index($0, offsetBy: 2)..<pos]) } ?? "…"
                    output += "<span class=\"cloze\">[\(escape(hint))]</span>"
                }
            } else { output += cloze(content, target: target, answer: answer, depth: recursion + 1) }
            cursor = text.index(pos, offsetBy: 2)
        }
        output += String(text[cursor...]); return output
    }

    private static func furigana(_ value: String, mode: Int) -> String {
        replacing(value, pattern: #"([^\s\[\]<>]+)\[([^\[\]]+)\]"#) { parts in
            switch mode { case 1: return parts[2]; case 2: return parts[1]; default: return "<ruby>\(parts[1])<rt>\(parts[2])</rt></ruby>" }
        }
    }

    private static func soundHTML(_ text: String) -> String {
        replacing(text, pattern: #"\[sound:([^\]]+)\]"#) { "<button class=\"anki-sound\" data-sound=\"\(escape($0[1]))\" aria-label=\"Play audio\">▶ Listen</button>" }
    }

    public static func plainText(_ html: String) -> String {
        var text = html.replacingOccurrences(of: #"(?is)<(script|style)\b[^>]*>.*?</\1>"#, with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: #"(?i)<br\s*/?>|</(?:div|p|li|tr)>"#, with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: #"<[^>]*>"#, with: "", options: .regularExpression)
        for (entity, value) in [("&nbsp;", " "), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&#39;", "'"), ("&amp;", "&")] { text = text.replacingOccurrences(of: entity, with: value) }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;").replacingOccurrences(of: "'", with: "&#39;")
    }

    private static func replacing(_ value: String, pattern: String, transform: ([String]) -> String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return value }
        let text = value as NSString
        var result = value
        for match in regex.matches(in: value, range: NSRange(location: 0, length: text.length)).reversed() {
            let parts = (0..<match.numberOfRanges).map { match.range(at: $0).location == NSNotFound ? "" : text.substring(with: match.range(at: $0)) }
            if let range = Range(match.range, in: result) { result.replaceSubrange(range, with: transform(parts)) }
        }
        return result
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
