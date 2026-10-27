import Foundation
import SwiftData
import Testing
@testable import LearnAlert

@MainActor
@Suite("Library order, manual pins and deck colors", .serialized)
struct LibraryInteractionTests {
    @Test("Saved order tolerates removed items, duplicates and newly added decks")
    func reconcileOrder() {
        #expect(HomeLibraryOrdering.ordered(["course:korean", "deck:a", "deck:b"],
            saved: ["deck:deleted", "deck:b", "deck:b", "course:korean"]) == ["deck:b", "course:korean", "deck:a"])
        #expect(HomeLibraryOrdering.ordered([], saved: ["deck:deleted"]).isEmpty)
    }

    @Test("Dragging supports both directions and safely ignores unknown targets")
    func dragDirections() {
        let ids = ["course:korean", "deck:a", "deck:b"]
        #expect(HomeLibraryOrdering.moving(ids[0], over: ids[2], in: ids) == [ids[1], ids[2], ids[0]])
        #expect(HomeLibraryOrdering.moving(ids[2], over: ids[0], in: ids) == [ids[2], ids[0], ids[1]])
        #expect(HomeLibraryOrdering.moving("missing", over: ids[0], in: ids) == ids)
        #expect(HomeLibraryOrdering.moving(ids[0], over: "missing", in: ids) == ids)
    }

    private func withManager(_ body: (LibraryPreferences, UserDefaults) throws -> Void) throws {
        let suite = "LibraryInteractionTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        try body(LibraryPreferences(defaults: defaults), defaults)
    }

    @Test("Mixed library order survives reload while pinning remains an explicit action")
    func persistentOrderAndPins() throws {
        try withManager { manager, defaults in
            let ids = ["course:korean", "deck:a", "deck:b", "deck:c"]
            manager.moveLibraryItem(ids[2], over: ids[0], available: ids)
            let expected = [ids[2], ids[0], ids[1], ids[3]]
            #expect(manager.libraryItemIds == expected && manager.pinnedItemIds.isEmpty)
            let reloaded = LibraryPreferences(defaults: defaults)
            #expect(reloaded.libraryItemIds == expected)
            reloaded.togglePin(id: ids[0]); reloaded.togglePin(id: ids[1])
            #expect(reloaded.pinnedItemIds == [ids[1], ids[0]])
            reloaded.moveLibraryItem(ids[0], over: ids[1], available: ids)
            #expect(reloaded.pinnedItemIds == [ids[0], ids[1]])
            reloaded.moveLibraryItem(ids[0], over: ids[3], available: ids)
            reloaded.moveLibraryItem("missing", over: ids[3], available: ids)
            #expect(reloaded.pinnedItemIds == [ids[0], ids[1]] && reloaded.libraryItemIds == expected)
            reloaded.reloadFromSharedDefaults()
            #expect(reloaded.pinnedItemIds == [ids[0], ids[1]])
            reloaded.togglePin(id: ids[0]); reloaded.reloadFromSharedDefaults()
            #expect(!reloaded.isPinned(id: ids[0]) && reloaded.isPinned(id: ids[1]))
        }
    }

    @Test("Every selectable deck color fills the icon and keeps lighter stack layers")
    func selectedIconColors() throws {
        for hex in DeckColorPalette.palette {
            let appearance = DeckCreatureAppearance.make(stableID: "color-fixture", savedSeed: 42, colorHex: hex)
            let color = try #require(DeckCreatureAppearance.RGB(hex: hex))
            #expect(appearance.palette.front == color)
            #expect(appearance.palette.middle.red > color.red && appearance.palette.back.red > appearance.palette.middle.red)
            #expect(appearance.palette.middle.green > color.green && appearance.palette.back.green > appearance.palette.middle.green)
            #expect(appearance.palette.middle.blue > color.blue && appearance.palette.back.blue > appearance.palette.middle.blue)
        }
    }

    @Test("Changing a deck color preserves its face, stack and shuffled appearance")
    func stableAppearance() {
        let base = DeckCreatureAppearance.make(stableID: "color-fixture", savedSeed: 42)
        let tinted = DeckCreatureAppearance.make(stableID: "color-fixture", savedSeed: 42, colorHex: "#3B82C4")
        #expect(base.eyeSpacing == tinted.eyeSpacing && base.eyeHeight == tinted.eyeHeight)
        #expect(base.pupilOffset == tinted.pupilOffset && base.pupilScale == tinted.pupilScale)
        #expect(base.mouthStyle == tinted.mouthStyle && base.frontTilt == tinted.frontTilt)
        #expect(base.layerTilts == tinted.layerTilts && base.layerOffsets == tinted.layerOffsets)
        #expect(base.tabOnLeadingEdge == tinted.tabOnLeadingEdge && base.bookmarkOnLeadingEdge == tinted.bookmarkOnLeadingEdge)
        #expect(DeckCreatureAppearance.make(stableID: "color-fixture", savedSeed: 42, colorHex: "invalid") == base)
    }
}
