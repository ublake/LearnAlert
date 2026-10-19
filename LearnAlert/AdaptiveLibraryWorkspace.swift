import SwiftUI

/// Content constraints, not device names or hinge angles, choose the workspace.
nonisolated struct LibraryWorkspaceGeometry: Equatable {
    enum Presentation: Equatable { case single, columns, rows }
    let presentation: Presentation
    let home: CGRect
    let discover: CGRect
    let dock: CGRect

    static func resolve(size: CGSize, regularWidth: Bool,
                        rightToLeft: Bool = false, divisions: [CGRect] = []) -> Self {
        let bounds = CGRect(origin: .zero, size: CGSize(width: max(0, size.width), height: max(0, size.height)))
        let clipped = divisions.map { $0.intersection(bounds) }.filter { !$0.isNull && $0.width > 0 && $0.height > 0 }
        let vertical = clipped.filter { $0.height >= bounds.height * 0.7 && $0.width < bounds.width * 0.3 }
            .sorted { $0.width > $1.width }.first
        let horizontal = clipped.filter { $0.width >= bounds.width * 0.7 && $0.height < bounds.height * 0.3 }
            .sorted { $0.height > $1.height }.first
        if regularWidth, bounds.width >= 640, bounds.height >= 240 {
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
        if #available(iOS 27.1, *) {
            // Use physical frames once; semantic pane ordering is handled by the layout.
            divisions = proxy.reservedRegions(kind: .division, options: .includeInactive,
                layoutDirectionBehavior: .fixed).filter(\.isActive).map(\.frame)
        }
        return resolve(size: proxy.size, regularWidth: regularWidth,
                       rightToLeft: direction == .rightToLeft, divisions: divisions)
    }
}

/// Both children retain their identity through display transitions and tab switches.
struct AdaptiveLibraryWorkspace: View {
    let geometry: LibraryWorkspaceGeometry
    @Binding var searchText: String
    @Binding var selectedTab: Int
    @Binding var showingCreateDeck: Bool

    var body: some View {
        LibraryPaneLayout(geometry: geometry) {
            HomeLibraryView(searchText: $searchText, selectedTab: $selectedTab, showingCreateDeck: $showingCreateDeck)
                .clipped()
                .opacity(geometry.presentation != .single || selectedTab == 0 ? 1 : 0)
                .allowsHitTesting(geometry.presentation != .single || selectedTab == 0)
                .accessibilityHidden(geometry.presentation == .single && selectedTab != 0)
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
                    .allowsHitTesting(false).accessibilityHidden(true)
            }
        }
    }
}

private struct LibraryPaneLayout: Layout {
    let geometry: LibraryWorkspaceGeometry
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (index, subview) in subviews.enumerated() {
            let rect = index == 0 ? geometry.home : geometry.discover
            subview.place(at: CGPoint(x: bounds.minX + rect.minX, y: bounds.minY + rect.minY), anchor: .topLeading,
                          proposal: ProposedViewSize(rect.size))
        }
    }
}
