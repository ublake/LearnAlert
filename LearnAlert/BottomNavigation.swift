import SwiftUI

enum BottomNavigationStyle: String, CaseIterable, Identifiable {
    case drift, cradle, split, frame

    var id: String { rawValue }
    var title: String {
        switch self {
        case .drift: "Drift"
        case .cradle: "Cradle"
        case .split: "Split"
        case .frame: "Frame"
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
        .padding(.bottom, 4)
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

// The live bar and the Settings thumbnails share the same silhouettes and materials.
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

    private var motion: Animation { reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.44, dampingFraction: 0.72) }
    private var barFill: AnyShapeStyle {
        reduceTransparency ? AnyShapeStyle(LearnAlertStyle.courseSurface) : AnyShapeStyle(.regularMaterial)
    }

    var body: some View {
        ZStack(alignment: .top) {
            dockSurface
                .allowsHitTesting(false)

            HStack(spacing: 0) {
                tab(0, "Home", "rectangle.stack.fill")
                tab(1, "Discover", "books.vertical.fill")
                Color.clear.frame(width: 68, height: 60)
                tab(2, "Customize", "slider.horizontal.3")
                tab(3, "Settings", "gearshape.fill")
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)

            creationBall
                .offset(y: isExpanded && !reduceMotion ? 40 : 38)
        }
        .frame(height: 96, alignment: .top)
        .animation(motion, value: selectedTab)
        .animation(motion, value: isExpanded)
    }

    @ViewBuilder private var dockSurface: some View {
        switch style {
        case .drift:
            surface(WeightedDockShape(sag: isExpanded && !reduceMotion ? 24 : 20))
                .frame(height: 92)
        case .cradle:
            surface(CradleDockShape())
                .frame(height: 72)
        case .split:
            HStack(spacing: 68) {
                surface(DockWingShape(isLeading: true))
                    .offset(y: isExpanded && !reduceMotion ? -2 : 0)
                surface(DockWingShape(isLeading: false))
                    .offset(y: isExpanded && !reduceMotion ? -2 : 0)
            }
            .frame(height: 72)
            .overlay(alignment: .top) {
                VStack(spacing: 0) {
                    Rectangle().fill(LearnAlertStyle.appAccent.opacity(0.24)).frame(width: 72, height: 1)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(LearnAlertStyle.appAccent.opacity(0.40))
                        .frame(width: 4, height: isExpanded && !reduceMotion ? 40 : 36)
                }
                .padding(.top, 16)
            }
        case .frame:
            surface(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .frame(height: 72)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(LearnAlertStyle.appAccent.opacity(0.50))
                        .frame(height: 2)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 8)
                }
        }
    }

    private func surface<S: Shape>(_ shape: S) -> some View {
        shape.fill(barFill)
            .overlay { shape.fill(LearnAlertStyle.appAccent.opacity(colorScheme == .dark ? 0.055 : 0.075)) }
            .overlay {
                shape.stroke(
                    LinearGradient(colors: [LearnAlertStyle.glassStroke, LearnAlertStyle.appAccent.opacity(0.16)], startPoint: .top, endPoint: .bottom),
                    lineWidth: 1
                )
            }
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.20 : 0.08), radius: 16, y: 8)
    }

    private func tab(_ index: Int, _ title: String, _ symbol: String) -> some View {
        let selected = selectedTab == index
        return Button { selectTab(index) } label: {
            VStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: selected ? .semibold : .medium))
                    .frame(height: 22)
                    .offset(y: selected && style == .split && !reduceMotion ? -2 : 0)
                    .scaleEffect(selected && style == .cradle && !reduceMotion ? 1.12 : 1)
                Text(title)
                    .font(.system(size: 10, weight: selected ? .semibold : .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(selected ? LearnAlertStyle.appAccentForeground : LearnAlertStyle.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background {
                if selected && (style == .drift || style == .cradle) {
                    RoundedRectangle(cornerRadius: style == .drift ? 14 : 10, style: .continuous)
                        .fill(LearnAlertStyle.appAccent.opacity(style == .drift ? 0.18 : 0.12))
                        .modifier(DockSelectionMotion(namespace: selectionNamespace, reduceMotion: reduceMotion))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 4)
                }
            }
            .overlay(alignment: style == .split ? .top : .bottom) {
                if selected && (style == .split || style == .frame) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(LearnAlertStyle.appAccentForeground)
                        .frame(width: style == .split ? 16 : 24, height: 3)
                        .modifier(DockSelectionMotion(namespace: selectionNamespace, reduceMotion: reduceMotion))
                        .padding(.vertical, 2)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(DockPressStyle())
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityShowsLargeContentViewer { Label(title, systemImage: symbol) }
        .frame(maxWidth: .infinity)
    }

    private var creationBall: some View {
        Button(action: toggleCreation) {
            Image(systemName: reduceMotion && isExpanded ? "xmark" : "plus")
                .font(.system(size: 24, weight: .medium))
                .rotationEffect(.degrees(isExpanded && !reduceMotion ? 45 : 0))
                .foregroundStyle(LearnAlertStyle.appAccentInk)
                .frame(width: 56, height: 56)
                .background {
                    Circle().fill(reduceTransparency ? AnyShapeStyle(LearnAlertStyle.courseSurface) : AnyShapeStyle(.thinMaterial))
                        .overlay { Circle().fill(LearnAlertStyle.appAccent) }
                        .overlay {
                            Circle().fill(LinearGradient(colors: [Color.white.opacity(0.24), .clear], startPoint: .topLeading, endPoint: .bottomTrailing))
                        }
                        .overlay {
                            Circle().strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.45 : 0.80), lineWidth: 1)
                        }
                        .overlay(alignment: .topLeading) {
                            Capsule().fill(Color.white.opacity(0.55)).frame(width: 16, height: 3).rotationEffect(.degrees(-35)).offset(x: 10, y: 10)
                        }
                        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.30 : 0.15), radius: 8, y: 6)
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

// A flat top and a soft belly make the center ball feel like a weight in the dock.
private struct WeightedDockShape: Shape {
    var sag: CGFloat
    var animatableData: CGFloat {
        get { sag }
        set { sag = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 20
        let bottom = rect.maxY - 20
        let center = rect.midX
        let shoulder = min(64.0, rect.width * 0.23)
        var path = Path()
        path.move(to: CGPoint(x: radius, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: 0))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: radius), control: CGPoint(x: rect.maxX, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX, y: bottom - radius))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - radius, y: bottom), control: CGPoint(x: rect.maxX, y: bottom))
        path.addLine(to: CGPoint(x: center + shoulder, y: bottom))
        path.addCurve(to: CGPoint(x: center, y: bottom + sag), control1: CGPoint(x: center + shoulder * 0.48, y: bottom), control2: CGPoint(x: center + shoulder * 0.42, y: bottom + sag))
        path.addCurve(to: CGPoint(x: center - shoulder, y: bottom), control1: CGPoint(x: center - shoulder * 0.42, y: bottom + sag), control2: CGPoint(x: center - shoulder * 0.48, y: bottom))
        path.addLine(to: CGPoint(x: radius, y: bottom))
        path.addQuadCurve(to: CGPoint(x: 0, y: bottom - radius), control: CGPoint(x: 0, y: bottom))
        path.addLine(to: CGPoint(x: 0, y: radius))
        path.addQuadCurve(to: CGPoint(x: radius, y: 0), control: .zero)
        path.closeSubpath()
        return path
    }
}

private struct CradleDockShape: Shape {
    func path(in rect: CGRect) -> Path {
        // Trace the outline explicitly so the material also follows the lower cradle.
        var path = Path()
        let c = rect.midX
        path.move(to: CGPoint(x: 20, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX - 20, y: 0))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: 20), control: CGPoint(x: rect.maxX, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - 20))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - 20, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: c + 48, y: rect.maxY))
        path.addCurve(to: CGPoint(x: c, y: 30), control1: CGPoint(x: c + 34, y: rect.maxY), control2: CGPoint(x: c + 36, y: 30))
        path.addCurve(to: CGPoint(x: c - 48, y: rect.maxY), control1: CGPoint(x: c - 36, y: 30), control2: CGPoint(x: c - 34, y: rect.maxY))
        path.addLine(to: CGPoint(x: 20, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: 0, y: rect.maxY - 20), control: CGPoint(x: 0, y: rect.maxY))
        path.addLine(to: CGPoint(x: 0, y: 20))
        path.addQuadCurve(to: CGPoint(x: 20, y: 0), control: .zero)
        path.closeSubpath()
        return path
    }
}

private struct DockWingShape: Shape {
    let isLeading: Bool
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 16, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX - 16, y: 0))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: 16), control: CGPoint(x: rect.maxX, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - (isLeading ? 28 : 16)))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - 16, y: rect.maxY - (isLeading ? 12 : 0)), control: CGPoint(x: rect.maxX, y: rect.maxY - (isLeading ? 12 : 0)))
        path.addLine(to: CGPoint(x: 16, y: rect.maxY - (isLeading ? 0 : 12)))
        path.addQuadCurve(to: CGPoint(x: 0, y: rect.maxY - (isLeading ? 16 : 28)), control: CGPoint(x: 0, y: rect.maxY - (isLeading ? 0 : 12)))
        path.addLine(to: CGPoint(x: 0, y: 16))
        path.addQuadCurve(to: CGPoint(x: 16, y: 0), control: .zero)
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
                                .frame(width: 288, height: 96)
                                .scaleEffect(0.40)
                                .frame(width: 116, height: 40)
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
