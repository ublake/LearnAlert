import SwiftUI

struct BottomNavigationBar: View {
    @Binding var selectedTab: Int
    @Binding var showingCreationActions: Bool
    let createDeck: () -> Void
    let importWithAI: () -> Void
    let importAnki: () -> Void
    @AppStorage("homeTutorialStep") private var homeTutorialStep = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var motion: Animation { reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.44, dampingFraction: 0.72) }

    var body: some View {
        VStack(spacing: 12) {
            creationMenu

            NavigationDock(
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
            .transition(.opacity)
            .disabled(homeTutorialStep > 0)
            .opacity(homeTutorialStep > 0 ? 0.30 : 1)
        }
        .frame(maxWidth: 560)
        .onChange(of: selectedTab) { _, _ in showingCreationActions = false }
        .onChange(of: homeTutorialStep) { _, step in
            if step > 0 { showingCreationActions = false }
        }
    }

    private var creationMenu: some View {
        HStack(alignment: .bottom, spacing: 10) {
            if showingCreationActions && homeTutorialStep == 0 {
                creationAction("Create Deck", icon: "rectangle.stack.badge.plus", action: createDeck)
                    .transition(creationActionTransition(isLeading: true))
                creationAction("Import with AI", icon: "sparkles", action: importWithAI)
                    .transition(creationActionTransition(isLeading: false))
                creationAction("Import Anki", icon: "square.and.arrow.down.on.square", action: importAnki)
                    .transition(creationActionTransition(isLeading: false))
            }
        }
        .padding(.horizontal, 16)
        .offset(y: 48)
        .accessibilityElement(children: .contain)
    }

    private func creationActionTransition(isLeading: Bool) -> AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .offset(x: isLeading ? 16 : -16, y: 32)
            .combined(with: .scale(scale: 0.92, anchor: isLeading ? .bottomTrailing : .bottomLeading))
            .combined(with: .opacity)
    }

    private func creationAction(_ title: LocalizedStringKey, icon: String, action: @escaping () -> Void) -> some View {
        Button {
            InteractionSoundPlayer.shared.play(.click)
            withAnimation(motion) { showingCreationActions = false }
            action()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(LearnAlertStyle.appAccentForeground)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LearnAlertStyle.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 88)
            .appCardSurface(cornerRadius: 20)
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(DockPressStyle())
        .accessibilityLabel(title)
    }
}

private struct NavigationDock: View {
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
        reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.46, dampingFraction: 0.78)
    }
    var body: some View {
        ZStack(alignment: .top) {
            islandDock

            creationBall
                .offset(y: 28 - (isExpanded && !reduceMotion ? 2 : 0))
                .zIndex(2)
        }
        .frame(height: 108, alignment: .top)
        .offset(y: 24)
        .animation(motion, value: selectedTab)
        .animation(motion, value: isExpanded)
    }

    // Islands: equal-width tabs keep the icons centered as their selected labels appear.
    private var islandDock: some View {
        pairedTabs(rowHeight: 52) { index in
            let selected = selectedTab == index
            tabButton(index) {
                VStack(spacing: 4) {
                    tabIcon(index, size: 21)
                        .frame(height: 24)
                    tabTitle(index)
                        .frame(height: 14)
                        .opacity(selected ? 1 : 0)
                        .accessibilityHidden(true)
                }
                .foregroundStyle(tabColor(index))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background {
                    if selected {
                        islandSelection(index)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background {
            Rectangle().fill(LearnAlertStyle.courseSurface)
                .ignoresSafeArea(.container, edges: .bottom)
        }
        .padding(.top, 40)
    }

    private func islandSelection(_ index: Int) -> some View {
        let leadingEdge = index == 0
        let trailingEdge = index == 3
        let outerEdge = leadingEdge || trailingEdge

        // Highlights fill the bar vertically; outer highlights also reach the screen corners.
        // Icon positions and tap areas stay fixed.
        return UnevenRoundedRectangle(
            topLeadingRadius: leadingEdge || !outerEdge ? 0 : 12,
            bottomLeadingRadius: leadingEdge || !outerEdge ? 0 : 12,
            bottomTrailingRadius: trailingEdge || !outerEdge ? 0 : 12,
            topTrailingRadius: trailingEdge || !outerEdge ? 0 : 12,
            style: .continuous
        )
        .fill(LearnAlertStyle.appAccent.opacity(0.18))
        .modifier(DockSelectionMotion(namespace: selectionNamespace, reduceMotion: reduceMotion))
        .padding(.leading, leadingEdge ? -20 : 0)
        .padding(.trailing, trailingEdge ? -20 : 0)
        .padding(.top, -8)
        .padding(.bottom, -48)
        .allowsHitTesting(false)
    }

    private func pairedTabs<Content: View>(rowHeight: CGFloat = 60, @ViewBuilder content: (Int) -> Content) -> some View {
        HStack(spacing: 0) {
            content(0)
            content(1)
            Color.clear.frame(maxWidth: .infinity).frame(height: rowHeight)
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

    private func tabIcon(_ index: Int, size: CGFloat, weight: Font.Weight = .semibold) -> some View {
        NavigationTabIcon(tab: index, outlineSymbol: tabs[index].outline,
                          isSelected: selectedTab == index, size: size, weight: weight)
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
                .font(.system(size: 24, weight: .medium))
                .rotationEffect(.degrees(isExpanded && !reduceMotion ? 45 : 0))
                .foregroundStyle(LearnAlertStyle.appAccentInk)
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
        .accessibilityHint("Create a deck, import with AI, or import an Anki file")
        .accessibilityShowsLargeContentViewer { Label("New deck", systemImage: "plus") }
    }

    private var ballSurface: some View {
        Circle().fill(reduceTransparency ? AnyShapeStyle(LearnAlertStyle.courseSurface) : AnyShapeStyle(.thinMaterial))
            .overlay { Circle().fill(LearnAlertStyle.appAccent) }
            .overlay { Circle().fill(LinearGradient(colors: [.white.opacity(0.24), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)) }
            .overlay { Circle().strokeBorder(.white.opacity(colorScheme == .dark ? 0.45 : 0.80), lineWidth: 1) }
            .background {
                Circle().fill(LearnAlertStyle.courseSurface).padding(-4)
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
