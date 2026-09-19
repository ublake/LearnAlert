import Foundation
import PDFKit
import UniformTypeIdentifiers

struct ImportedStudyMaterial: Identifiable, Sendable {
    let id = UUID()
    let filename: String
    let text: String
}

enum DocumentTextExtractorError: LocalizedError {
    case unsupportedFileType
    case fileCouldNotBeOpened
    case noReadableText
    case scannedPDF

    var errorDescription: String? {
        switch self {
        case .unsupportedFileType:
            "This file type isn’t supported yet. Choose a PDF or plain-text file."
        case .fileCouldNotBeOpened:
            "The selected file couldn’t be opened."
        case .noReadableText:
            "The selected file contained no readable text."
        case .scannedPDF:
            "This PDF appears to contain scanned images. Image-based document support is coming next."
        }
    }
}

enum DocumentTextExtractor {
    static func extractText(from url: URL) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            switch url.pathExtension.lowercased() {
            case "pdf":
                return try extractPDFText(from: url)
            case "txt", "text", "md":
                return try extractPlainText(from: url)
            default:
                throw DocumentTextExtractorError.unsupportedFileType
            }
        }.value
    }

    private static func extractPDFText(from url: URL) throws -> String {
        guard let document = PDFDocument(url: url) else {
            throw DocumentTextExtractorError.fileCouldNotBeOpened
        }

        let pages = (0..<document.pageCount).compactMap { index in
            document.page(at: index)?.string
        }
        let text = pages.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw DocumentTextExtractorError.scannedPDF }
        return text
    }

    private static func extractPlainText(from url: URL) throws -> String {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw DocumentTextExtractorError.fileCouldNotBeOpened
        }

        let text = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .utf16)
        guard let text else { throw DocumentTextExtractorError.fileCouldNotBeOpened }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw DocumentTextExtractorError.noReadableText }
        return trimmed
    }
}
