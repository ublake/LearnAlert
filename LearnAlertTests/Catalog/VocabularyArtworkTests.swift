import SwiftUI
import Testing
@testable import LearnAlert

@MainActor
@Suite("Individual vocabulary artwork")
struct VocabularyArtworkTests {
    @Test("Every bundled word resolves to one distinct tile rather than the whole sheet")
    func singleTiles() throws {
        let words = ["apple", "banana", "orange", "grapes", "cat", "dog", "rabbit", "bird",
                     "coffee", "water", "rice", "milk", "book", "bag", "chair", "clock"]
        var images = Set<Data>()
        for word in words {
            let image = try #require(CardImageStore.loadImage(named: "course-vocab-" + word))
            let pixels = try #require(image.cgImage)
            #expect(pixels.width >= 313 && pixels.width <= 315)
            #expect(pixels.height >= 313 && pixels.height <= 315)
            images.insert(try #require(image.pngData()))
        }
        #expect(images.count == words.count)
    }

    @Test("The broken Spanish and Korean book references use the correct image even offline")
    func legacyBooks() throws {
        let expected = try #require(CardImageStore.loadImage(named: "course-vocab-book")?.pngData())
        for reference in ["catalog:a5d45561-825b-440d-a9aa-98f4be7b5b8f", "catalog:44b87db9-c0a5-4e3e-a58c-55a3aec07388"] {
            let image = try #require(CardImageStore.loadImage(named: reference))
            #expect(image.pngData() == expected)
            #expect(CardImageStore.loadImage(named: reference.uppercased())?.pngData() == expected)
            Attachment.record(image, named: "book-\(reference.dropFirst(8)).png", as: .png)
        }
        // Collages deliberately attached by a learner must never be auto-cropped.
        #expect(CardImageStore.loadImage(named: "CourseVocabularyAtlas")?.cgImage?.width == 1254)
    }
}
