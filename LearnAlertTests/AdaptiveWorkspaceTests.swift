import Foundation
import CoreGraphics
import Testing
@testable import LearnAlert

@Suite("Adaptive workspace and notification viewport")
struct AdaptiveWorkspaceTests {
    @Test("Expansion follows local usable width, not iPhone/iPad device identity")
    func expansion() {
        for size in [CGSize(width: 669, height: 951), CGSize(width: 951, height: 669), CGSize(width: 1024, height: 768)] {
            let layout = LibraryWorkspaceGeometry.resolve(size: size, regularWidth: true)
            #expect(layout.presentation == .columns)
            #expect(layout.home.width >= 300 && layout.discover.width >= 300)
            #expect(!layout.home.intersects(layout.discover))
        }
        for size in [CGSize(width: 393, height: 852), CGSize(width: 500, height: 900)] {
            #expect(LibraryWorkspaceGeometry.resolve(size: size, regularWidth: true).presentation == .single)
        }
        #expect(LibraryWorkspaceGeometry.resolve(size: .init(width: 951, height: 669), regularWidth: false).presentation == .single)
        // A keyboard can shorten the container without erasing the two-pane workspace.
        #expect(LibraryWorkspaceGeometry.resolve(size: .init(width: 951, height: 300), regularWidth: true).presentation == .columns)
    }
    @Test("Vertical folds and the dock stay outside reserved geometry, including RTL")
    func verticalFold() {
        let fold = CGRect(x: 450, y: -40, width: 36, height: 900)
        for rtl in [false, true] {
            let layout = LibraryWorkspaceGeometry.resolve(size: .init(width: 951, height: 669), regularWidth: true,
                rightToLeft: rtl, divisions: [fold])
            #expect(layout.presentation == .columns)
            for rect in [layout.home, layout.discover, layout.dock] { #expect(!rect.intersects(fold)) }
            #expect(rtl ? layout.home.minX > layout.discover.minX : layout.home.minX < layout.discover.minX)
        }
    }
    @Test("Tabletop folds use reachable panes; narrow regions keep a single usable pane")
    func horizontalFold() {
        let fold = CGRect(x: -30, y: 450, width: 800, height: 35)
        let layout = LibraryWorkspaceGeometry.resolve(size: .init(width: 669, height: 951), regularWidth: true, divisions: [fold])
        #expect(layout.presentation == .rows)
        #expect(layout.home.maxY <= fold.minY && layout.discover.minY >= fold.maxY)
        #expect(!layout.dock.intersects(fold))
        let small = LibraryWorkspaceGeometry.resolve(size: .init(width: 420, height: 600), regularWidth: false,
            divisions: [.init(x: 0, y: 200, width: 420, height: 30)])
        #expect(small.presentation == .single)
        #expect(small.home.height == 370)
    }
    @Test("Viewport avoids multiple, partial, external and nonzero-origin occlusions")
    func occlusions() {
        let bounds = CGRect(x: 20, y: 10, width: 640, height: 500)
        let regions = [CGRect(x: 290, y: -10, width: 30, height: 600),
                       CGRect(x: 500, y: 10, width: 200, height: 40),
                       CGRect(x: 2000, y: 2000, width: 40, height: 40)]
        let usable = NotificationViewportGeometry.usableRect(in: bounds, avoiding: regions)
        #expect(bounds.contains(usable))
        #expect(usable.width > 250 && usable.height > 400)
        for region in regions { #expect(!usable.intersects(region)) }
        #expect(NotificationViewportGeometry.usableRect(in: bounds, avoiding: []) == bounds)
        #expect(NotificationViewportGeometry.usableRect(in: .zero, avoiding: regions) == .zero)
        #expect(NotificationViewportGeometry.usableRect(in: bounds, avoiding: [bounds]) == .zero)
    }
    @Test("Preferred notification height fits the active scene and grows again when space returns")
    func heightBudget() {
        for height in [CGFloat(280), 430, 667, 844, 1366] {
            let preferred = NotificationViewportGeometry.preferredHeight(contentHeight: 1800, containerHeight: height, baseline: 540)
            #expect(preferred <= height)
            #expect(preferred <= 680)
        }
        #expect(NotificationViewportGeometry.preferredHeight(contentHeight: .nan, containerHeight: 844, baseline: 540) == 540)
        #expect(NotificationViewportGeometry.preferredHeight(contentHeight: 650, containerHeight: 430) < NotificationViewportGeometry.preferredHeight(contentHeight: 650, containerHeight: 951))
    }
}
