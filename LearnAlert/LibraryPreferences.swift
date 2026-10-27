import Foundation
import Combine

enum HomeLibraryOrdering {
    static func ordered(_ available: [String], saved: [String]) -> [String] {
        let valid = Set(available)
        var seen = Set<String>()
        return (saved + available).filter { valid.contains($0) && seen.insert($0).inserted }
    }

    static func moving(_ source: String, over target: String, in ids: [String]) -> [String] {
        guard source != target, let from = ids.firstIndex(of: source), let to = ids.firstIndex(of: target) else { return ids }
        var result = ids
        result.remove(at: from); result.insert(source, at: to)
        return result
    }
}

/// Library ordering remains independent of the retired language progression.
@MainActor
final class LibraryPreferences: ObservableObject {
    static let shared = LibraryPreferences()
    private let defaults: UserDefaults
    @Published private(set) var pinnedItemIds: [String] = []
    @Published private(set) var libraryItemIds: [String] = []
    private var unpinnedExplicitIds = Set<String>()

    init(defaults: UserDefaults = UserDefaults(suiteName: "group.com.learnalert.shared") ?? .standard) {
        self.defaults = defaults
        reloadFromSharedDefaults()
    }

    func reloadFromSharedDefaults() {
        pinnedItemIds = defaults.stringArray(forKey: "home_pinned_item_ids") ?? []
        libraryItemIds = defaults.stringArray(forKey: "home_library_item_ids") ?? []
        unpinnedExplicitIds = Set(defaults.stringArray(forKey: "home_unpinned_explicit_ids") ?? [])
    }

    func isPinned(id: String) -> Bool { pinnedItemIds.contains(id) }
    func isDeckPinned(deckId: UUID) -> Bool { isPinned(id: "deck:\(deckId.uuidString)") }

    func togglePin(id: String) {
        if isPinned(id: id) {
            pinnedItemIds.removeAll { $0 == id }
            unpinnedExplicitIds.insert(id)
        } else {
            pinnedItemIds.insert(id, at: 0)
            unpinnedExplicitIds.remove(id)
        }
        save()
    }

    func moveLibraryItem(_ source: String, over target: String, available: [String]) {
        guard isPinned(id: source) == isPinned(id: target) else { return }
        if isPinned(id: source) {
            pinnedItemIds = HomeLibraryOrdering.moving(source, over: target, in: pinnedItemIds)
        } else {
            libraryItemIds = HomeLibraryOrdering.moving(source, over: target,
                in: HomeLibraryOrdering.ordered(available, saved: libraryItemIds))
        }
        save()
    }

    func migrateCourseIdentity(courseID: String, to deckID: UUID) {
        let old = "course:\(courseID)", new = "deck:\(deckID.uuidString)"
        func replacing(_ values: [String]) -> [String] {
            var seen = Set<String>()
            return values.map { $0 == old ? new : $0 }.filter { seen.insert($0).inserted }
        }
        pinnedItemIds = replacing(pinnedItemIds)
        libraryItemIds = replacing(libraryItemIds)
        if unpinnedExplicitIds.remove(old) != nil { unpinnedExplicitIds.insert(new) }
        save()
    }

    private func save() {
        defaults.set(pinnedItemIds, forKey: "home_pinned_item_ids")
        defaults.set(libraryItemIds, forKey: "home_library_item_ids")
        defaults.set(Array(unpinnedExplicitIds), forKey: "home_unpinned_explicit_ids")
    }
}
