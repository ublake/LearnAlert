import Foundation
import PDFKit

public enum PDFSectionKind: String, Codable, Sendable, CaseIterable {
    case module
    case chapter
    case section
    case frontMatter = "front_matter"
    case backMatter = "back_matter"
    case other

    public var displayTitle: String {
        switch self {
        case .module: return AppLocalization.string("Module")
        case .chapter: return AppLocalization.string("Chapter")
        case .section: return AppLocalization.string("Section")
        case .frontMatter: return AppLocalization.string("Front Matter")
        case .backMatter: return AppLocalization.string("Back Matter")
        case .other: return AppLocalization.string("Topic")
        }
    }

    public var iconName: String {
        switch self {
        case .module: return "book.closed.fill"
        case .chapter: return "bookmark.fill"
        case .section: return "doc.text.fill"
        case .frontMatter: return "text.alignleft"
        case .backMatter: return "text.badge.checkmark"
        case .other: return "folder.fill"
        }
    }
}

public struct PDFSectionItem: Identifiable, Hashable, Sendable {
    public let id: String
    public var title: String
    public var kind: PDFSectionKind
    public var startPageIndex: Int // 0-based
    public var endPageIndex: Int   // 0-based (inclusive)
    public var pageCount: Int {
        max(1, endPageIndex - startPageIndex + 1)
    }
    public var summary: String?
    public var isContentless: Bool

    public init(
        id: String = UUID().uuidString,
        title: String,
        kind: PDFSectionKind,
        startPageIndex: Int,
        endPageIndex: Int,
        summary: String? = nil,
        isContentless: Bool = false
    ) {
        self.id = id
        self.title = title
        self.kind = kind
        self.startPageIndex = startPageIndex
        self.endPageIndex = endPageIndex
        self.summary = summary
        self.isContentless = isContentless
    }
}

public enum PDFOutlineError: LocalizedError, Sendable {
    case corruptOrEncrypted
    case encrypted
    case emptyDocument
    case scanWithoutText
    case sizeExceeded(Int)

    public var errorDescription: String? {
        switch self {
        case .corruptOrEncrypted:
            return AppLocalization.string("The selected PDF couldn't be read or is corrupted.")
        case .encrypted:
            return AppLocalization.string("This PDF is password-protected or encrypted. Please provide an unlocked PDF.")
        case .emptyDocument:
            return AppLocalization.string("This PDF contains no pages.")
        case .scanWithoutText:
            return AppLocalization.string("This scanned PDF contains no readable text layer.")
        case .sizeExceeded(let bytes):
            let mb = Double(bytes) / (1024 * 1024)
            return String(format: AppLocalization.string("Selected pages are %.1f MB. The maximum upload size is 8 MB. Please select fewer sections."), locale: .current, mb)
        }
    }
}

public enum PDFOutlineManager {

    public enum DetectionMethod: String, Sendable {
        case outline = "Document Bookmarks"
        case regex = "Heading Detection"
        case none = "Manual Selection"

        public var displayTitle: String {
            switch self {
            case .outline: AppLocalization.string("Document Bookmarks")
            case .regex: AppLocalization.string("Heading Detection")
            case .none: AppLocalization.string("Manual Selection")
            }
        }
    }

    public struct AnalysisResult: @unchecked Sendable {
        public let document: PDFDocument
        public let sections: [PDFSectionItem]
        public let method: DetectionMethod
    }

    /// Finds sections on device before the learner chooses pages to send.
    public static func analyzePDF(url: URL) throws -> AnalysisResult {
        // PDFDocument(url:) returns nil for encrypted or corrupt PDFs.
        guard let doc = PDFDocument(url: url) else {
            throw PDFOutlineError.corruptOrEncrypted
        }
        if doc.isLocked {
            throw PDFOutlineError.encrypted
        }
        let totalPages = doc.pageCount
        guard totalPages > 0 else {
            throw PDFOutlineError.emptyDocument
        }

        // STEP 1 — Try the PDF's own outline FIRST (free, instant)
        let outlineSections = extractFromOutline(doc: doc)
        if outlineSections.count >= 2 {
            return AnalysisResult(document: doc, sections: outlineSections, method: .outline)
        }

        // STEP 2 — Regex fallback (free)
        let regexSections = extractFromRegex(doc: doc)
        if regexSections.count >= 2 {
            return AnalysisResult(document: doc, sections: regexSections, method: .regex)
        }

        return AnalysisResult(document: doc, sections: [], method: .none)
    }

    // MARK: - Section Sanitization & Partitioning

    /// Ensures that sections form a clean, non-overlapping partition of the PDF without gaps or lost pages.
    public static func sanitizeAndChainSections(
        _ rawSections: [PDFSectionItem],
        totalPageCount: Int
    ) -> [PDFSectionItem] {
        guard !rawSections.isEmpty, totalPageCount > 0 else { return [] }

        // Sort by startPageIndex ascending
        var sorted = rawSections.sorted {
            if $0.startPageIndex != $1.startPageIndex {
                return $0.startPageIndex < $1.startPageIndex
            }
            return $0.endPageIndex < $1.endPageIndex
        }

        // If the first section starts after page 0, extend it backwards to 0 so page 0 isn't orphaned
        if sorted[0].startPageIndex > 0 {
            sorted[0].startPageIndex = 0
        }

        var chained: [PDFSectionItem] = []
        for i in 0..<sorted.count {
            var item = sorted[i]
            // Start page cannot be less than the previous section's end + 1
            if let last = chained.last {
                if item.startPageIndex <= last.endPageIndex {
                    item.startPageIndex = last.endPageIndex + 1
                }
            }

            // If startPageIndex has reached or exceeded totalPageCount, skip
            if item.startPageIndex >= totalPageCount {
                continue
            }

            // End page is bounded by next section's start page - 1, or totalPageCount - 1 for the last section
            if i + 1 < sorted.count {
                let rawNextStart = sorted[i + 1].startPageIndex
                let candidateNextStart = max(item.startPageIndex + 1, rawNextStart)
                item.endPageIndex = min(totalPageCount - 1, candidateNextStart - 1)
            } else {
                // Last section always extends to totalPageCount - 1 (no lost pages!)
                item.endPageIndex = totalPageCount - 1
            }

            if item.endPageIndex >= item.startPageIndex {
                chained.append(item)
            }
        }

        // Ensure the final section extends to totalPageCount - 1 so the last pages are never dropped
        if var last = chained.last {
            if last.endPageIndex < totalPageCount - 1 {
                last.endPageIndex = totalPageCount - 1
                chained[chained.count - 1] = last
            }
        }

        return chained
    }

    // MARK: - Contentless Page Detection Helper

    public static func isRangeContentless(doc: PDFDocument, start: Int, end: Int) -> Bool {
        var charCount = 0
        let clampedStart = max(0, min(start, doc.pageCount - 1))
        let clampedEnd = max(clampedStart, min(end, doc.pageCount - 1))
        for i in clampedStart...clampedEnd {
            if let page = doc.page(at: i), let text = page.string {
                let trimmed = text.components(separatedBy: .whitespacesAndNewlines).filter({ !$0.isEmpty }).joined(separator: " ")
                charCount += trimmed.count
                if charCount >= 80 { return false }
            }
        }
        return charCount < 80
    }

    // MARK: - STEP 1: PDF OutlineRoot Walk

    private static func extractFromOutline(doc: PDFDocument) -> [PDFSectionItem] {
        guard let root = doc.outlineRoot else { return [] }

        var rawNodes: [(title: String, pageIndex: Int)] = []

        func walk(_ outline: PDFOutline) {
            if let label = outline.label?.trimmingCharacters(in: .whitespacesAndNewlines), !label.isEmpty {
                var targetPage: PDFPage? = outline.destination?.page
                if targetPage == nil, let gotoAction = outline.action as? PDFActionGoTo {
                    targetPage = gotoAction.destination.page
                }
                if let page = targetPage {
                    let idx = doc.index(for: page)
                    if idx >= 0 && idx < doc.pageCount {
                        rawNodes.append((label, idx))
                    }
                }
            }
            for i in 0..<outline.numberOfChildren {
                if let child = outline.child(at: i) {
                    walk(child)
                }
            }
        }

        for i in 0..<root.numberOfChildren {
            if let child = root.child(at: i) {
                walk(child)
            }
        }

        // Sort by pageIndex ascending
        rawNodes.sort { $0.pageIndex < $1.pageIndex }

        // Deduplicate consecutive identical starting page indices
        var uniqueNodes: [(title: String, pageIndex: Int)] = []
        for node in rawNodes {
            if let last = uniqueNodes.last, last.pageIndex == node.pageIndex {
                if node.title.count > last.title.count {
                    uniqueNodes[uniqueNodes.count - 1] = node
                }
                continue
            }
            uniqueNodes.append(node)
        }

        guard uniqueNodes.count >= 2 else { return [] }

        var sections: [PDFSectionItem] = []
        for i in 0..<uniqueNodes.count {
            let current = uniqueNodes[i]
            let nextStart = (i + 1 < uniqueNodes.count) ? uniqueNodes[i + 1].pageIndex : doc.pageCount
            let endPage = max(current.pageIndex, nextStart - 1)
            let clampedEnd = min(endPage, doc.pageCount - 1)
            let kind = classifyKind(title: current.title)
            let contentless = isRangeContentless(doc: doc, start: current.pageIndex, end: clampedEnd)

            sections.append(
                PDFSectionItem(
                    title: current.title,
                    kind: kind,
                    startPageIndex: current.pageIndex,
                    endPageIndex: clampedEnd,
                    isContentless: contentless
                )
            )
        }

        return sanitizeAndChainSections(sections, totalPageCount: doc.pageCount)
    }

    // MARK: - STEP 2: Regex Heading Detection

    private static func extractFromRegex(doc: PDFDocument) -> [PDFSectionItem] {
        let pattern = #"^\s*(Módulo|Modulo|Lección|Leccion|Unidad|Capítulo|Capitulo|Tema|Module|Lesson|Unit|Chapter|Section|Part)\s+(\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }

        var rawMatches: [(title: String, lessonKey: String, pageIndex: Int)] = []

        for pageIndex in 0..<doc.pageCount {
            guard let page = doc.page(at: pageIndex), let pageText = page.string else { continue }
            let lines = pageText.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            let first3Lines = lines.prefix(3)
            for line in first3Lines {
                let nsLine = line as NSString
                let range = NSRange(location: 0, length: nsLine.length)
                if let match = regex.firstMatch(in: line, options: [], range: range) {
                    // Extract normalized key like "lesson-5" to detect repeating running headers
                    let prefix = nsLine.substring(with: match.range(at: 1)).lowercased()
                    let number = nsLine.substring(with: match.range(at: 2))
                    let key = "\(prefix)-\(number)"
                    rawMatches.append((title: line, lessonKey: key, pageIndex: pageIndex))
                    break
                }
            }
        }

        // Deduplicate headings that repeat the same lesson/unit/chapter across multiple pages (e.g. running headers)
        var deduplicated: [(title: String, pageIndex: Int)] = []
        for match in rawMatches {
            if let last = deduplicated.last {
                // If this heading has the exact same title, or same lesson key as the last heading,
                // it is a running header or continuation: ignore it so it doesn't fracture the section!
                let lastKey = rawMatches.last(where: { $0.pageIndex == last.pageIndex })?.lessonKey
                let isSameKey = (lastKey != nil && lastKey == match.lessonKey)
                let isSameTitle = (last.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                                   == match.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())

                if isSameKey || isSameTitle {
                    continue
                }
            }
            deduplicated.append((title: match.title, pageIndex: match.pageIndex))
        }

        guard deduplicated.count >= 2 else { return [] }

        var sections: [PDFSectionItem] = []
        for i in 0..<deduplicated.count {
            let current = deduplicated[i]
            let nextStart = (i + 1 < deduplicated.count) ? deduplicated[i + 1].pageIndex : doc.pageCount
            let endPage = max(current.pageIndex, nextStart - 1)
            let clampedEnd = min(endPage, doc.pageCount - 1)
            let kind = classifyKind(title: current.title)
            let contentless = isRangeContentless(doc: doc, start: current.pageIndex, end: clampedEnd)

            sections.append(
                PDFSectionItem(
                    title: current.title,
                    kind: kind,
                    startPageIndex: current.pageIndex,
                    endPageIndex: clampedEnd,
                    isContentless: contentless
                )
            )
        }

        return sanitizeAndChainSections(sections, totalPageCount: doc.pageCount)
    }

    // MARK: - Classification Helper

    public static func classifyKind(title: String) -> PDFSectionKind {
        let lower = title.lowercased()

        // Prioritize structural container units (module, chapter)
        if lower.contains("módulo") || lower.contains("modulo") || lower.contains("module") {
            return .module
        }
        if lower.contains("capítulo") || lower.contains("capitulo") || lower.contains("chapter") {
            return .chapter
        }

        let frontMatterKeywords = [
            "table of contents", "contents", "preface", "foreword",
            "introduction", "acknowledgement", "acknowledgment", "copyright",
            "title page", "title", "cover", "front matter", "frontmatter",
            "dedication", "epigraph", "prologue", "credits", "about the author",
            "publisher", "índice", "prefacio", "introducción", "sumario", "toc"
        ]
        if frontMatterKeywords.contains(where: { lower.contains($0) }) {
            return .frontMatter
        }

        let backMatterKeywords = [
            "appendix", "glossary", "index", "bibliography",
            "references", "apéndice", "glosario", "bibliografía",
            "answers", "soluciones", "solutions"
        ]
        if backMatterKeywords.contains(where: { lower.contains($0) }) {
            return .backMatter
        }

        if lower.contains("lección") || lower.contains("leccion") || lower.contains("lesson") ||
           lower.contains("unidad") || lower.contains("unit") || lower.contains("sección") ||
           lower.contains("section") || lower.contains("tema") || lower.contains("part") || lower.contains("parte") {
            return .section
        }

        return .other
    }

    // MARK: - Create Subset Document

    /// Builds a PDF document containing only the selected page indices and returns its data representation.
    /// Throws if corrupted or if size exceeds 8 MB.
    public static func createSubset(
        from doc: PDFDocument,
        selectedPageIndices: Set<Int>
    ) throws -> Data {
        let subset = PDFDocument()
        var i = 0
        for pageIndex in selectedPageIndices.sorted() {
            guard let page = doc.page(at: pageIndex) else { continue }
            if let copy = page.copy() as? PDFPage {
                subset.insert(copy, at: i)
            } else {
                subset.insert(page, at: i)
            }
            i += 1
        }
        guard let data = subset.dataRepresentation() else {
            throw PDFOutlineError.corruptOrEncrypted
        }
        if data.count > 8 * 1024 * 1024 {
            throw PDFOutlineError.sizeExceeded(data.count)
        }
        return data
    }
}
