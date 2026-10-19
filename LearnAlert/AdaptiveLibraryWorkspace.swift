import SwiftUI
import UIKit

/// Content constraints, not device names or hinge angles, choose the workspace.
nonisolated struct LibraryWorkspaceGeometry: Equatable {
    enum Presentation: Equatable { case single, columns, rows }
    let presentation: Presentation
    let home: CGRect
    let discover: CGRect
    let dock: CGRect

    static func resolve(size: CGSize, regularWidth: Bool, supportsDualPane: Bool = false,
                        rightToLeft: Bool = false, divisions: [CGRect] = []) -> Self {
        let bounds = CGRect(origin: .zero, size: CGSize(width: max(0, size.width), height: max(0, size.height)))
        let clipped = divisions.map { $0.intersection(bounds) }.filter { !$0.isNull && $0.width > 0 && $0.height > 0 }
        let vertical = clipped.filter { $0.height >= bounds.height * 0.7 && $0.width < bounds.width * 0.3 }
            .sorted { $0.width > $1.width }.first
        let horizontal = clipped.filter { $0.width >= bounds.width * 0.7 && $0.height < bounds.height * 0.3 }
            .sorted { $0.height > $1.height }.first
        // A folded portrait display keeps one reachable page instead of stacking tabs.
        let foldedPortrait = bounds.height > bounds.width && !clipped.isEmpty
        if supportsDualPane, regularWidth, !foldedPortrait, bounds.width >= 640, bounds.height >= 240 {
            if let fold = horizontal {
                let top = CGRect(x: 0, y: 0, width: bounds.width, height: fold.minY)
                let bottom = CGRect(x: 0, y: fold.maxY, width: bounds.width, height: bounds.height - fold.maxY)
                if top.height >= 240, bottom.height >= 300 {
                    return .init(presentation: .rows, home: top, discover: bottom, dock: bottom)
                }
            } else {
                let left = CGRect(x: 0, y: 0, width: vertical?.minX ?? (bounds.width - 1) / 2, height: bounds.height)
                let start = vertical?.maxX ?? (left.maxX + 1)
                let right = CGRect(x: start, y: 0, width: bounds.width - start, height: bounds.height)
                if left.width >= 300, right.width >= 300 {
                    let home = rightToLeft ? right : left, discover = rightToLeft ? left : right
                    return .init(presentation: .columns, home: home, discover: discover, dock: vertical == nil ? bounds : home)
                }
            }
        }
        // A fold may leave too little room for two usable panes. Keep both tabs available.
        let usable = NotificationViewportGeometry.usableRect(in: bounds, avoiding: clipped)
        return .init(presentation: .single, home: usable, discover: usable, dock: usable)
    }
}

extension LibraryWorkspaceGeometry {
    @MainActor static func resolve(proxy: GeometryProxy, regularWidth: Bool,
                                   direction: LayoutDirection) -> Self {
        var divisions: [CGRect] = []
        var hasFoldRegion = false
        if #available(iOS 27.1, *) {
            // Use physical frames once; semantic pane ordering is handled by the layout.
            let regions = proxy.reservedRegions(kind: .division, options: .includeInactive,
                layoutDirectionBehavior: .fixed)
            hasFoldRegion = !regions.isEmpty
            divisions = regions.filter(\.isActive).map(\.frame)
        }
        // Device family gates this product feature only; local geometry still controls layout.
        let supportsDualPane = UIDevice.current.userInterfaceIdiom == .phone && hasFoldRegion
        return resolve(size: proxy.size, regularWidth: regularWidth, supportsDualPane: supportsDualPane,
                       rightToLeft: direction == .rightToLeft, divisions: divisions)
    }
}

/// Both children retain their identity through display transitions and tab switches.
struct AdaptiveLibraryWorkspace: View {
    let geometry: LibraryWorkspaceGeometry
    @Binding var searchText: String
    @Binding var selectedTab: Int
    @Binding var showingCreateDeck: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.layoutDirection) private var direction
    private var expanded: Bool { geometry.presentation != .single && selectedTab == 1 }

    var body: some View {
        LibraryPaneLayout(geometry: geometry, expansion: expanded ? 1 : 0, rightToLeft: direction == .rightToLeft) {
            HomeLibraryView(searchText: $searchText, selectedTab: $selectedTab, showingCreateDeck: $showingCreateDeck)
                .clipped()
                .opacity(selectedTab == 0 ? 1 : 0)
                .allowsHitTesting(selectedTab == 0)
                .accessibilityHidden(selectedTab != 0)
            PremadeDecksView()
                .clipped()
                .opacity(geometry.presentation != .single || selectedTab == 1 ? 1 : 0)
                .allowsHitTesting(geometry.presentation != .single || selectedTab == 1)
                .accessibilityHidden(geometry.presentation == .single && selectedTab != 1)
        }
        .overlay {
            if geometry.presentation == .columns {
                Rectangle().fill(LearnAlertStyle.cardBorder).frame(width: 1)
                    .position(x: (min(geometry.home.maxX, geometry.discover.maxX) + max(geometry.home.minX, geometry.discover.minX)) / 2,
                              y: max(geometry.home.height, geometry.discover.height) / 2)
                    .opacity(expanded ? 0 : 1)
                    .allowsHitTesting(false).accessibilityHidden(true)
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.46, dampingFraction: 0.9), value: expanded)
        .clipped()
    }
}

private struct LibraryPaneLayout: Layout {
    let geometry: LibraryWorkspaceGeometry
    var expansion: CGFloat
    let rightToLeft: Bool
    var animatableData: CGFloat {
        get { expansion }
        set { expansion = newValue }
    }
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let frames = geometry.paneFrames(in: CGRect(origin: .zero, size: bounds.size),
            expansion: expansion, rightToLeft: rightToLeft)
        for (index, subview) in subviews.enumerated() {
            let rect = index == 0 ? frames.home : frames.discover
            subview.place(at: CGPoint(x: bounds.minX + rect.minX, y: bounds.minY + rect.minY), anchor: .topLeading,
                          proposal: ProposedViewSize(rect.size))
        }
    }
}


extension LibraryWorkspaceGeometry {
    /// Interpolate positions and size while keeping both page trees mounted.
    func paneFrames(in bounds: CGRect, expansion: CGFloat, rightToLeft: Bool) -> (home: CGRect, discover: CGRect) {
        guard presentation != .single else { return (home, discover) }
        let amount = min(1, max(0, expansion))
        let offscreenHome = home.offsetBy(dx: rightToLeft ? bounds.maxX - home.minX : bounds.minX - home.maxX, dy: 0)
        func blend(_ start: CGRect, _ end: CGRect) -> CGRect {
            CGRect(x: start.minX + (end.minX - start.minX) * amount,
                   y: start.minY + (end.minY - start.minY) * amount,
                   width: start.width + (end.width - start.width) * amount,
                   height: start.height + (end.height - start.height) * amount)
        }
        return (blend(home, offscreenHome), blend(discover, bounds))
    }
}

nonisolated enum HomeLibraryGrid {
    static func columnCount(width: CGFloat, isPad: Bool, accessibilitySize: Bool) -> Int {
        isPad && !accessibilitySize && width >= 700 ? 2 : 1
    }
}
