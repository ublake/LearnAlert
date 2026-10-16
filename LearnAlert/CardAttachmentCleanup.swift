import SwiftData

enum CardAttachmentCleanup {
    static func removeUnreferenced(_ candidates: [String: CardFieldMedia], context: ModelContext) {
        guard let cards = try? context.fetch(FetchDescriptor<Flashcard>()) else { return }
        let fields = cards.flatMap { $0.fieldMedia.values }
        let images = Set(fields.compactMap(\.image)), audio = Set(fields.compactMap(\.audio))
        for name in Set(candidates.values.compactMap(\.image)) where !images.contains(name) { CardImageStore.deleteImage(named: name) }
        for name in Set(candidates.values.compactMap(\.audio)) where !audio.contains(name) { CardAudioStore.delete(named: name) }
    }
}
