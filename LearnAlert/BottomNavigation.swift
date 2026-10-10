import SwiftUI

enum BottomNavigationStyle: String, CaseIterable, Identifiable {
    case drift, cradle, split, frame

    var id: String { rawValue }
    var title: String {
        switch self {
        case .drift: "Glass"
        case .cradle: "Lift"
        case .split: "Islands"
        case .frame: "Rail"
        }
    }
}

struct BottomNavigationBar: View {
    @Binding var selectedTab: Int
    @Binding var tabDragOffset: CGFloat
    @Binding var showingCreationActions: Bool
    let createDeck: () -> Void
    let importWithAI: () -> Void
    @AppStorage("navigationBarStyle") private var storedStyle = BottomNavigationStyle.drift.rawValue
    @AppStorage("homeTutorialStep") private var homeTutorialStep = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var style: BottomNavigationStyle { BottomNavigationStyle(rawValue: storedStyle) ?? .drift }
    private var motion: Animation { reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.44, dampingFraction: 0.72) }

    var body: some View {
        VStack(spacing: 12) {
            if showingCreationActions && homeTutorialStep == 0 {
                creationMenu
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }

            NavigationDock(
                style: style,
                selectedTab: selectedTab,
                isExpanded: showingCreationActions,
                selectTab: { tab in
                    withAnimation(motion) {
                        selectedTab = tab
                        showingCreationActions = false
                    }
                },
                toggleCreation: {
                    withAnimation(motion) { showingCreationActions.toggle() }
                }
            )
            .id(style)
            .transition(.opacity)
            .disabled(homeTutorialStep > 0)
            .opacity(homeTutorialStep > 0 ? 0.30 : 1)
            .offset(x: reduceMotion ? 0 : tabDragOffset)
            .simultaneousGesture(
                DragGesture(minimumDistance: 24)
                    .onChanged { value in
                        guard homeTutorialStep == 0, abs(value.translation.width) > abs(value.translation.height) else { return }
                        tabDragOffset = value.translation.width / 4
                    }
                    .onEnded { value in
                        guard homeTutorialStep == 0 else { return }
                        withAnimation(motion) {
                            if abs(value.translation.width) > abs(value.translation.height) {
                                if value.translation.width > 40 { selectedTab = max(0, selectedTab - 1) }
                                if value.translation.width < -40 { selectedTab = min(3, selectedTab + 1) }
                            }
                            tabDragOffset = 0
                            showingCreationActions = false
                        }
                    }
            )
        }
        .frame(maxWidth: 560)
        .padding(.horizontal, 16)
        .animation(motion, value: storedStyle)
        .onChange(of: selectedTab) { _, _ in showingCreationActions = false }
        .onChange(of: storedStyle) { _, _ in showingCreationActions = false }
        .onChange(of: homeTutorialStep) { _, step in
            if step > 0 { showingCreationActions = false }
        }
    }

    private var creationMenu: some View {
        VStack(spacing: 0) {
            creationAction("Create Deck", icon: "rectangle.stack.badge.plus", action: createDeck)
            Rectangle().fill(LearnAlertStyle.cardBorder).frame(height: 1).padding(.horizontal, 16)
            creationAction("Import with AI", icon: "sparkles", action: importWithAI)
        }
        .appCardSurface(cornerRadius: 20)
        .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : 300)
        .accessibilityElement(children: .contain)
    }

    private func creationAction(_ title: LocalizedStringKey, icon: String, action: @escaping () -> Void) -> some View {
        Button {
            InteractionSoundPlayer.shared.play(.click)
            withAnimation(motion) { showingCreationActions = false }
            action()
        } label: {
            Label(title, systemImage: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(LearnAlertStyle.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
        }
        .buttonStyle(DockPressStyle())
    }
}

// Settings renders this same component at a smaller scale for accurate previews.
private struct NavigationDock: View {
    let style: BottomNavigationStyle
    let selectedTab: Int
    var isExpanded = false
    let selectTab: (Int) -> Void
    let toggleCreation: () -> Void
    @Namespace private var selectionNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private let tabs: [(title: String, symbol: String, outline: String)] = [
        ("Home", "rectangle.stack.fill", "rectangle.stack"),
        ("Discover", "books.vertical.fill", "books.vertical"),
        ("Customize", "slider.horizontal.3", "slider.horizontal.3"),
        ("Settings", "gearshape.fill", "gearshape")
    ]
    private var motion: Animation {
        reduceMotion ? .easeOut(duration: 0.15) : .spring(response: style == .cradle ? 0.38 : 0.46, dampingFraction: style == .cradle ? 0.64 : 0.78)
    }
    private var glass: AnyShapeStyle {
        reduceTransparency ? AnyShapeStyle(LearnAlertStyle.courseSurface) : AnyShapeStyle(.regularMaterial)
    }

    var body: some View {
        ZStack(alignment: .top) {
            switch style {
            case .drift: glassDock
            case .cradle: liftDock
            case .split: islandDock
            case .frame: railDock
            }

            creationBall
                .offset(y: isExpanded && !reduceMotion ? 10 : 12)
                .zIndex(2)
        }
        .frame(height: 108, alignment: .top)
        .animation(motion, value: selectedTab)
        .animation(motion, value: isExpanded)
    }

    // Glass: one translucent surface with a sliding, illuminated tab tile.
    private var glassDock: some View {
        pairedTabs { index in
            tabButton(index) {
                VStack(spacing: 4) {
                    Image(systemName: tabs[index].symbol)
                        .font(.system(size: 18, weight: selectedTab == index ? .semibold : .medium))
                        .frame(height: 22)
                    tabTitle(index)
                }
                .foregroundStyle(tabColor(index))
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background {
                    if selectedTab == index {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(LearnAlertStyle.appAccent.opacity(0.18))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14).strokeBorder(LearnAlertStyle.appAccent.opacity(0.24), lineWidth: 1)
                            }
                            .modifier(DockSelectionMotion(namespace: selectionNamespace, reduceMotion: reduceMotion))
                            .padding(4)
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 12, topTrailingRadius: 12)
                .fill(glass)
                .overlay { UnevenRoundedRectangle(topLeadingRadius: 12, topTrailingRadius: 12).fill(LearnAlertStyle.appAccent.opacity(0.06)) }
                .ignoresSafeArea(.container, edges: .bottom)
        }
        .padding(.top, 32)
    }

    // Lift: a solid notched stage. The active icon rises out of its circular seat.
    private var liftDock: some View {
        pairedTabs { index in
            let selected = selectedTab == index
            tabButton(index) {
                VStack(spacing: 4) {
                    Image(systemName: selected ? tabs[index].symbol : tabs[index].outline)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(selected ? LearnAlertStyle.appAccentInk : LearnAlertStyle.textSecondary)
                        .frame(width: 36, height: 36)
                        .background {
                            Circle().fill(selected ? LearnAlertStyle.appAccent : LearnAlertStyle.insetSurface)
                                .overlay { Circle().strokeBorder(selected ? Color.white.opacity(0.36) : LearnAlertStyle.cardBorder, lineWidth: 1) }
                                .shadow(color: selected ? .black.opacity(0.16) : .clear, radius: 6, y: 4)
                        }
                        .offset(y: selected && !reduceMotion ? -6 : 0)
                        .scaleEffect(selected && !reduceMotion ? 1.10 : 1)
                    tabTitle(index)
                        .foregroundStyle(tabColor(index))
                        .offset(y: selected && !reduceMotion ? -3 : 0)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 60)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background {
            TopCradleDockShape()
                .fill(LearnAlertStyle.courseSurface)
                .ignoresSafeArea(.container, edges: .bottom)
        }
        .padding(.top, 32)
    }

    // Islands: two separate compact panels; the selected icon expands into a label.
    private var islandDock: some View {
        HStack(spacing: 72) {
            island([0, 1])
            island([2, 3])
        }
        .padding(.top, 40)
    }

    private func island(_ indices: [Int]) -> some View {
        HStack(spacing: 4) {
            ForEach(indices, id: \.self) { index in
                let selected = selectedTab == index
                tabButton(index) {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 6) {
                            Image(systemName: tabs[index].outline)
                                .font(.system(size: 18, weight: .semibold))
                            if selected {
                                Text(tabs[index].title)
                                    .font(.system(size: 10, weight: .semibold))
                                    .fixedSize()
                                    .transition(.opacity)
                            }
                        }
                        VStack(spacing: 3) {
                            Image(systemName: tabs[index].outline).font(.system(size: 17, weight: .semibold))
                            if selected { tabTitle(index) }
                        }
                    }
                    .foregroundStyle(selected ? LearnAlertStyle.appAccentInk : LearnAlertStyle.textSecondary)
                    .padding(.horizontal, selected ? 8 : 0)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background {
                        if selected {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(LearnAlertStyle.appAccent)
                                .modifier(DockSelectionMotion(namespace: selectionNamespace, reduceMotion: reduceMotion))
                        }
                    }
                }
                .frame(width: selected ? nil : 44)
                .frame(maxWidth: selected ? .infinity : nil)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 12, topTrailingRadius: 12)
                .fill(LearnAlertStyle.courseSurface)
                .ignoresSafeArea(.container, edges: .bottom)
        }
    }

    // Rail: four continuous segments, text-led controls, matte finish, moving rule.
    private var railDock: some View {
        HStack(spacing: 0) {
            ForEach(0..<4, id: \.self) { index in
                tabButton(index) {
                    HStack(spacing: 5) {
                        Image(systemName: tabs[index].outline)
                            .font(.system(size: 13, weight: .medium))
                        Text(tabs[index].title.uppercased())
                            .font(.system(size: 9, weight: selectedTab == index ? .bold : .medium))
                            .tracking(0.3)
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                    }
                    .foregroundStyle(tabColor(index))
                    .padding(.horizontal, 5)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .overlay(alignment: .bottom) {
                        ZStack {
                            Rectangle().fill(LearnAlertStyle.cardBorder)
                            if selectedTab == index {
                                Rectangle().fill(LearnAlertStyle.appAccentForeground)
                                    .modifier(DockSelectionMotion(namespace: selectionNamespace, reduceMotion: reduceMotion))
                            }
                        }
                        .frame(height: 2)
                        .padding(.horizontal, 8)
                        .padding(.bottom, 4)
                    }
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 8, topTrailingRadius: 8)
                .fill(LearnAlertStyle.courseSurface)
                .ignoresSafeArea(.container, edges: .bottom)
        }
        .padding(.top, 36)
    }

    private func pairedTabs<Content: View>(@ViewBuilder content: (Int) -> Content) -> some View {
        HStack(spacing: 0) {
            content(0)
            content(1)
            Color.clear.frame(width: 68, height: 60)
            content(2)
            content(3)
        }
    }

    private func tabButton<Content: View>(_ index: Int, @ViewBuilder content: () -> Content) -> some View {
        Button { selectTab(index) } label: {
            content().contentShape(Rectangle())
        }
        .buttonStyle(DockPressStyle())
        .accessibilityLabel(tabs[index].title)
        .accessibilityAddTraits(selectedTab == index ? .isSelected : [])
        .accessibilityShowsLargeContentViewer { Label(tabs[index].title, systemImage: tabs[index].symbol) }
        .frame(maxWidth: .infinity)
    }

    private func tabTitle(_ index: Int) -> some View {
        Text(tabs[index].title)
            .font(.system(size: 10, weight: selectedTab == index ? .semibold : .medium))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }

    private func tabColor(_ index: Int) -> Color {
        selectedTab == index ? LearnAlertStyle.appAccentForeground : LearnAlertStyle.textSecondary
    }

    private var creationBall: some View {
        Button(action: toggleCreation) {
            Image(systemName: reduceMotion && isExpanded ? "xmark" : "plus")
                .font(.system(size: style == .frame ? 22 : 24, weight: .medium))
                .rotationEffect(.degrees(isExpanded && !reduceMotion ? 45 : 0))
                .foregroundStyle(style == .frame ? LearnAlertStyle.appAccentForeground : LearnAlertStyle.appAccentInk)
                .frame(width: 56, height: 56)
                .background {
                    ballSurface
                }
                .scaleEffect(isExpanded && !reduceMotion ? 1.06 : 1)
                .contentShape(Circle())
        }
        .buttonStyle(DockPressStyle())
        .accessibilityLabel(isExpanded ? "Close new deck options" : "New deck options")
        .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
        .accessibilityHint("Create a deck or import with AI")
        .accessibilityShowsLargeContentViewer { Label("New deck", systemImage: "plus") }
    }

    @ViewBuilder private var ballSurface: some View {
        if style == .frame {
            Circle().fill(LearnAlertStyle.courseSurface)
                .overlay { Circle().fill(LearnAlertStyle.appAccent.opacity(0.12)) }
                .overlay { Circle().strokeBorder(LearnAlertStyle.appAccentForeground.opacity(0.65), lineWidth: 1.5) }
        } else {
            Circle().fill(reduceTransparency ? AnyShapeStyle(LearnAlertStyle.courseSurface) : AnyShapeStyle(.thinMaterial))
                .overlay { Circle().fill(LearnAlertStyle.appAccent) }
                .overlay { Circle().fill(LinearGradient(colors: [.white.opacity(style == .cradle ? 0.10 : 0.24), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)) }
                .overlay { Circle().strokeBorder(.white.opacity(colorScheme == .dark ? 0.45 : 0.80), lineWidth: 1) }
                .overlay {
                    if style == .split {
                        Circle().stroke(LearnAlertStyle.appAccent.opacity(0.22), lineWidth: 1)
                            .padding(isExpanded && !reduceMotion ? -10 : -6)
                    }
                }
        }
    }
}

private struct DockSelectionMotion: ViewModifier {
    let namespace: Namespace.ID
    let reduceMotion: Bool

    @ViewBuilder func body(content: Content) -> some View {
        if reduceMotion {
            content.transition(.opacity)
        } else {
            content.matchedGeometryEffect(id: "selection", in: namespace)
        }
    }
}

private struct DockPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.94 : 1)
            .opacity(configuration.isPressed ? 0.78 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

// A deeper top seat lets the button settle into the bar; the bottom joins the screen edge.
private struct TopCradleDockShape: Shape {
    func path(in rect: CGRect) -> Path {
        let c = rect.midX
        let radius: CGFloat = 12
        var path = Path()
        path.move(to: CGPoint(x: radius, y: 0))
        path.addLine(to: CGPoint(x: c - 48, y: 0))
        path.addCurve(to: CGPoint(x: c, y: 40), control1: CGPoint(x: c - 36, y: 0), control2: CGPoint(x: c - 34, y: 40))
        path.addCurve(to: CGPoint(x: c + 48, y: 0), control1: CGPoint(x: c + 34, y: 40), control2: CGPoint(x: c + 36, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: 0))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: radius), control: CGPoint(x: rect.maxX, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: 0, y: rect.maxY))
        path.addLine(to: CGPoint(x: 0, y: radius))
        path.addQuadCurve(to: CGPoint(x: radius, y: 0), control: .zero)
        path.closeSubpath()
        return path
    }
}

struct SettingsNavigationGroup: View {
    @AppStorage("navigationBarStyle") private var storedStyle = BottomNavigationStyle.drift.rawValue
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Navigation")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(LearnAlertStyle.textSecondary)
                .padding(.leading, 4)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2), spacing: 12) {
                ForEach(BottomNavigationStyle.allCases) { style in
                    Button {
                        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.44, dampingFraction: 0.72)) {
                            storedStyle = style.rawValue
                        }
                    } label: {
                        VStack(spacing: 12) {
                            NavigationDock(style: style, selectedTab: 0, selectTab: { _ in }, toggleCreation: {})
                                .frame(width: 288, height: 108)
                                .scaleEffect(0.40)
                                .frame(width: 116, height: 44)
                                .frame(maxWidth: .infinity)
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                            HStack(spacing: 8) {
                                Text(style.title).font(.body.weight(.semibold))
                                Spacer(minLength: 0)
                                Image(systemName: storedStyle == style.rawValue ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(storedStyle == style.rawValue ? LearnAlertStyle.appAccentForeground : LearnAlertStyle.textSecondary.opacity(0.45))
                            }
                        }
                        .foregroundStyle(LearnAlertStyle.textPrimary)
                        .padding(16)
                        .frame(maxWidth: .infinity)
                        .appCardSurface(cornerRadius: 20)
                        .overlay {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(storedStyle == style.rawValue ? LearnAlertStyle.appAccentForeground.opacity(0.70) : .clear, lineWidth: 1.5)
                        }
                        .contentShape(RoundedRectangle(cornerRadius: 20))
                    }
                    .buttonStyle(DockPressStyle())
                    .accessibilityLabel("\(style.title) navigation")
                    .accessibilityAddTraits(storedStyle == style.rawValue ? .isSelected : [])
                    .accessibilityHint("Changes the bottom navigation bar immediately")
                }
            }
        }
        .padding(.horizontal, 20)
    }
}
