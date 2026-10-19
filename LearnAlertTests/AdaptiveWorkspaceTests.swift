import Foundation
import CoreGraphics
import Testing
@testable import LearnAlert

@Suite("Adaptive workspace and notification viewport")
struct AdaptiveWorkspaceTests {
    @Test("Eligible Duo workspaces still follow local usable width")
    func expansion() {
        for size in [CGSize(width: 669, height: 951), CGSize(width: 951, height: 669), CGSize(width: 1024, height: 768)] {
            let layout = LibraryWorkspaceGeometry.resolve(size: size, regularWidth: true, supportsDualPane: true)
            #expect(layout.presentation == .columns)
            #expect(layout.home.width >= 300 && layout.discover.width >= 300)
            #expect(!layout.home.intersects(layout.discover))
        }
        for size in [CGSize(width: 393, height: 852), CGSize(width: 500, height: 900)] {
            #expect(LibraryWorkspaceGeometry.resolve(size: size, regularWidth: true, supportsDualPane: true).presentation == .single)
        }
        #expect(LibraryWorkspaceGeometry.resolve(size: .init(width: 951, height: 669), regularWidth: false).presentation == .single)
        // A keyboard can shorten the container without erasing the two-pane workspace.
        #expect(LibraryWorkspaceGeometry.resolve(size: .init(width: 951, height: 300), regularWidth: true, supportsDualPane: true).presentation == .columns)
    }
    @Test("Vertical folds and the dock stay outside reserved geometry, including RTL")
    func verticalFold() {
        let fold = CGRect(x: 450, y: -40, width: 36, height: 900)
        for rtl in [false, true] {
            let layout = LibraryWorkspaceGeometry.resolve(size: .init(width: 951, height: 669), regularWidth: true, supportsDualPane: true,
                rightToLeft: rtl, divisions: [fold])
            #expect(layout.presentation == .columns)
            for rect in [layout.home, layout.discover, layout.dock] { #expect(!rect.intersects(fold)) }
            #expect(rtl ? layout.home.minX > layout.discover.minX : layout.home.minX < layout.discover.minX)
        }
    }
    @Test("Folded portrait keeps the selected page in one usable region")
    func horizontalFold() {
        let fold = CGRect(x: -30, y: 450, width: 800, height: 35)
        let layout = LibraryWorkspaceGeometry.resolve(size: .init(width: 669, height: 951), regularWidth: true, supportsDualPane: true, divisions: [fold])
        #expect(layout.presentation == .single)
        #expect(layout.home == layout.discover && layout.home == layout.dock)
        #expect(layout.home.minY >= fold.maxY)
        #expect(!layout.dock.intersects(fold))
        let vertical = CGRect(x: 320, y: 0, width: 29, height: 951)
        let portraitBook = LibraryWorkspaceGeometry.resolve(size: .init(width: 669, height: 951), regularWidth: true,
            supportsDualPane: true, divisions: [vertical])
        #expect(portraitBook.presentation == .single)
        #expect(portraitBook.home == portraitBook.discover)
        #expect(!portraitBook.home.intersects(vertical))
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


extension AdaptiveWorkspaceTests {
    @Test("iPad and ordinary iPhones keep independent full-page tabs")
    func workspaceEligibility() {
        for width in [CGFloat(669), 951, 1366] {
            let layout = LibraryWorkspaceGeometry.resolve(size: .init(width: width, height: 900), regularWidth: true)
            #expect(layout.presentation == .single)
            #expect(layout.home.width == width && layout.discover.width == width)
        }
    }
    @Test("Discover fills the workspace at the end of the slide and keeps safe intermediate frames")
    func discoverExpansion() {
        let bounds = CGRect(x: 0, y: 0, width: 951, height: 669)
        for rtl in [false, true] {
            let layout = LibraryWorkspaceGeometry.resolve(size: bounds.size, regularWidth: true, supportsDualPane: true, rightToLeft: rtl)
            let start = layout.paneFrames(in: bounds, expansion: 0, rightToLeft: rtl)
            let middle = layout.paneFrames(in: bounds, expansion: 0.5, rightToLeft: rtl)
            let end = layout.paneFrames(in: bounds, expansion: 1, rightToLeft: rtl)
            #expect(start.home == layout.home && start.discover == layout.discover)
            #expect(end.discover == bounds)
            #expect(middle.discover.width > start.discover.width && middle.discover.width < bounds.width)
            #expect(!end.home.intersects(bounds))
            #expect(layout.paneFrames(in: bounds, expansion: 2, rightToLeft: rtl).discover == bounds)
        }
    }
    @Test("iPad grid keeps two readable columns, collapsing in narrow windows")
    func iPadGrid() {
        #expect(HomeLibraryGrid.columnCount(width: 1024, isPad: true, accessibilitySize: false) == 2)
        #expect(HomeLibraryGrid.columnCount(width: 500, isPad: true, accessibilitySize: false) == 1)
        #expect(HomeLibraryGrid.columnCount(width: 1024, isPad: false, accessibilitySize: false) == 1)
        #expect(HomeLibraryGrid.columnCount(width: 1024, isPad: true, accessibilitySize: true) == 1)
    }
    @Test("Floating navigation is limited to roomy iPad and inner Duo scenes")
    func floatingNavigation() {
        #expect(NavigationDockPresentation.usesFloatingDock(sceneWidth: 1024, dockWidth: 1024, isPad: true, isDuo: false))
        #expect(NavigationDockPresentation.usesFloatingDock(sceneWidth: 951, dockWidth: 450, isPad: false, isDuo: true))
        #expect(NavigationDockPresentation.usesFloatingDock(sceneWidth: 669, dockWidth: 669, isPad: false, isDuo: true))
        #expect(!NavigationDockPresentation.usesFloatingDock(sceneWidth: 393, dockWidth: 393, isPad: false, isDuo: true))
        #expect(!NavigationDockPresentation.usesFloatingDock(sceneWidth: 951, dockWidth: 951, isPad: false, isDuo: false))
        #expect(!NavigationDockPresentation.usesFloatingDock(sceneWidth: 390, dockWidth: 390, isPad: true, isDuo: false))
    }
    @Test("Duo side navigation stays on the physical right outside folds and camera regions")
    func sideNavigation() {
        let wide = CGSize(width: 951, height: 669)
        let edge = NavigationDockPresentation.sideRegion(size: wide, isDuo: true, avoiding: [])
        #expect(edge == CGRect(x: 867, y: 0, width: 84, height: 669))
        let fold = CGRect(x: 0, y: 450, width: 669, height: 35)
        let tabletop = NavigationDockPresentation.sideRegion(size: .init(width: 669, height: 951), isDuo: true, avoiding: [fold])
        #expect(tabletop?.minY == 485)
        #expect(tabletop?.maxX == 669)
        let camera = CGRect(x: 900, y: 0, width: 51, height: 100)
        let clear = NavigationDockPresentation.sideRegion(size: wide, isDuo: true, avoiding: [camera])
        #expect(clear?.intersects(camera) == false)
        #expect(NavigationDockPresentation.sideRegion(size: wide, isDuo: false, avoiding: []) == nil)
        #expect(NavigationDockPresentation.sideRegion(size: .init(width: 393, height: 852), isDuo: true, avoiding: []) == nil)
        #expect(NavigationDockPresentation.sideRegion(size: .init(width: 951, height: 300), isDuo: true, avoiding: []) == nil)
    }
}
