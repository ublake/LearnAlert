import SwiftUI
import SwiftData
import Combine
import AVFoundation
import AudioToolbox
import UserNotifications
import UIKit

struct ContentView: View {
    @Query private var decks: [Deck]
    @ObservedObject private var notificationManager = NotificationManager.shared
    @State private var selectedTab = 0
    @State private var showingCreateDeck = false
    @State private var showingAIComposer = false
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var tabDragOffset: CGFloat = 0
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    private var preferredColorScheme: ColorScheme? {
        switch appearanceMode {
        case "light": .light
        case "dark": .dark
        default: nil
        }
    }
    
    let enterForeground = NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
    
    var body: some View {
        NavigationStack {
            ZStack {
                LearnAlertStyle.courseCanvas
                    .ignoresSafeArea()
                
                Group {
                    switch selectedTab {
                    case 0:
                        HomeLibraryView(
                            searchText: $searchText,
                            selectedTab: $selectedTab,
                            showingCreateDeck: $showingCreateDeck
                        )
                    case 1: PremadeDecksView()
                    case 2: AlertsDashboardView()
                    case 3: AppSettingsView()
                    default:
                        HomeLibraryView(
                            searchText: $searchText,
                            selectedTab: $selectedTab,
                            showingCreateDeck: $showingCreateDeck
                        )
                    }
                }
                .animation(nil, value: selectedTab)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                VStack {
                    Spacer()
                    LiquidTabBar(
                        selectedTab: $selectedTab,
                        tabDragOffset: $tabDragOffset,
                        createDeck: { showingCreateDeck = true },
                        importWithAI: { showingAIComposer = true }
                    )
                }
            }
            .sheet(isPresented: $showingCreateDeck) { CreateDeckView() }
            .sheet(isPresented: $showingAIComposer) { GeneratedQuizImportView() }
            .fullScreenCover(isPresented: Binding(
                get: { !hasCompletedOnboarding },
                set: { if $0 { hasCompletedOnboarding = false } }
            )) {
                WelcomeOnboardingView {
                    hasCompletedOnboarding = true
                }
            }
            .onAppear {
                notificationManager.consumePendingStudyHandoff()
            }
            .onReceive(enterForeground) { _ in
                StudyEngine.shared.restoreSession()
                notificationManager.consumePendingStudyHandoff()
            }
            .onChange(of: notificationManager.pendingStudyHandoff) { _, handoff in
                guard handoff != nil else { return }
                selectedTab = 0
            }
            .navigationDestination(item: $notificationManager.pendingStudyHandoff) { handoff in
                if let deck = decks.first(where: { $0.id == handoff.deckId }) {
                    DeckStudyView(
                        deck: deck,
                        initialCardId: handoff.cardId,
                        initialSelectedAnswer: handoff.selectedAnswer,
                        initialWasCorrect: handoff.wasCorrect,
                        initialWasGraded: handoff.wasGraded,
                        initialHintVisible: handoff.wasHintVisible
                    )
                } else {
                    ContentUnavailableView("Deck Not Found", systemImage: "rectangle.stack.badge.exclamationmark")
                }
            }
        }
        .overlay {
            if notificationManager.shouldShowNotificationOpeningTip {
                NotificationOpeningTip {
                    withAnimation(.snappy) {
                        notificationManager.shouldShowNotificationOpeningTip = false
                    }
                }
                .transition(.scale(scale: 0.94).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: notificationManager.shouldShowNotificationOpeningTip)
        .preferredColorScheme(preferredColorScheme)
        .onChange(of: appearanceMode) { _, newMode in
            UserDefaults(suiteName: "group.com.learnalert.shared")?.set(newMode, forKey: "appearanceMode")
        }
        .onAppear {
            UserDefaults(suiteName: "group.com.learnalert.shared")?.set(appearanceMode, forKey: "appearanceMode")
        }
    }
}

private struct NotificationOpeningTip: View {
    let dismiss: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color.black.opacity(colorScheme == .dark ? 0.72 : 0.45)
                .ignoresSafeArea()
                .onTapGesture(perform: dismiss)

            VStack(spacing: 20) {
                // Header
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.12, green: 0.50, blue: 0.98),
                                        Color(red: 0.20, green: 0.78, blue: 0.85)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)
                        Image(systemName: "bell.badge.waveform.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Study Directly in Alerts")
                            .font(.custom("Poppins-SemiBold", size: 18))
                            .foregroundStyle(LearnAlertStyle.textPrimary)
                        Text("Did you know alerts are interactive flashcards?")
                            .font(.custom("Poppins-Regular", size: 12))
                            .foregroundStyle(LearnAlertStyle.textSecondary)
                    }

                    Spacer()

                    Button(action: dismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(LearnAlertStyle.textSecondary)
                            .frame(width: 32, height: 32)
                            .background(Color.primary.opacity(0.06), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close notification tip")
                }

                // Interactive Comparison Cards
                VStack(spacing: 12) {
                    // Card 1: Recommended Gesture (Pull Down / Long Press)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("RECOMMENDED", systemImage: "sparkles")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.green.opacity(0.14), in: Capsule())

                            Spacer()

                            Text("Studies in Alert")
                                .font(.custom("Poppins-SemiBold", size: 12))
                                .foregroundStyle(Color.green)
                        }

                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.green.opacity(0.12))
                                    .frame(width: 46, height: 46)
                                Image(systemName: "arrow.down.to.line.compact")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(Color.green)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Pull Down or Press & Hold")
                                    .font(.custom("Poppins-SemiBold", size: 14))
                                    .foregroundStyle(LearnAlertStyle.textPrimary)
                                Text("Expands the card into a live quiz. Answer questions directly without opening the app!")
                                    .font(.custom("Poppins-Regular", size: 12))
                                    .foregroundStyle(LearnAlertStyle.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.green.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.green.opacity(0.24), lineWidth: 1)
                    )

                    // Card 2: Quick Tap
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("QUICK TAP")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(LearnAlertStyle.textSecondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.primary.opacity(0.06), in: Capsule())

                            Spacer()

                            Text("Opens App")
                                .font(.custom("Poppins-Medium", size: 12))
                                .foregroundStyle(LearnAlertStyle.textSecondary)
                        }

                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.primary.opacity(0.06))
                                    .frame(width: 46, height: 46)
                                Image(systemName: "hand.tap.fill")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundStyle(LearnAlertStyle.textSecondary)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Tap the Banner Directly")
                                    .font(.custom("Poppins-SemiBold", size: 14))
                                    .foregroundStyle(LearnAlertStyle.textPrimary)
                                Text("Launches LearnAlert into your study session so you can edit, manage, and review.")
                                    .font(.custom("Poppins-Regular", size: 12))
                                    .foregroundStyle(LearnAlertStyle.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.primary.opacity(0.03))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(LearnAlertStyle.hairline.opacity(0.35), lineWidth: 1)
                    )
                }

                // Action Button
                Button(action: dismiss) {
                    Text("Got It, Thanks!")
                        .font(.custom("Poppins-SemiBold", size: 15))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(.white)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.12, green: 0.50, blue: 0.98),
                                    Color(red: 0.20, green: 0.68, blue: 0.96)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: Color(red: 0.12, green: 0.50, blue: 0.98).opacity(0.30), radius: 10, y: 4)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .frame(maxWidth: 390)
            .background(LearnAlertStyle.courseSurface)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(LearnAlertStyle.hairline.opacity(0.4), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.45 : 0.18), radius: 32, y: 16)
            .padding(20)
        }
    }
}

private struct LearnAlertLogoMark: View {
    var body: some View {
        Image("LearnAlertLogo")
            .resizable()
            .scaledToFit()
            .frame(width: 44, height: 44, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("LearnAlert logo")
    }
}

private struct LearnAlertWordmark: View {
    var body: some View {
        OutlinedLearnAlertText()
            .frame(height: 24)
            .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("LearnAlert")
    }
}

private struct OutlinedLearnAlertText: UIViewRepresentable {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.backgroundColor = .clear
        label.isAccessibilityElement = false
        label.adjustsFontForContentSizeCategory = true
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }

    func updateUIView(_ label: UILabel, context: Context) {
        let baseFont = UIFont.systemFont(ofSize: 17, weight: .black)
        let font = UIFontMetrics(forTextStyle: .subheadline).scaledFont(for: baseFont)
        let wordmark = NSMutableAttributedString(
            string: "LearnAlert",
            attributes: [
                .font: font,
                .foregroundColor: UIColor.clear,
                .strokeWidth: 7.0,
                .kern: -0.35
            ]
        )
        wordmark.addAttribute(
            .strokeColor,
            value: UIColor(LearnAlertStyle.figmaBlue),
            range: NSRange(location: 0, length: 5)
        )
        wordmark.addAttribute(
            .strokeColor,
            value: colorScheme == .dark
                ? UIColor.white.withAlphaComponent(0.58)
                : UIColor.black.withAlphaComponent(0.42),
            range: NSRange(location: 5, length: 5)
        )
        label.attributedText = wordmark
        label.sizeToFit()
        _ = dynamicTypeSize
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UILabel, context: Context) -> CGSize? {
        let size = uiView.sizeThatFits(
            CGSize(width: proposal.width ?? .greatestFiniteMagnitude, height: proposal.height ?? .greatestFiniteMagnitude)
        )
        return CGSize(width: ceil(size.width), height: ceil(size.height))
    }
}

// MARK: - Home Search
struct HomeSearchControl: View {
    @Binding var searchText: String
    @Binding var isSearching: Bool

    @ViewBuilder
    var body: some View {
        if #available(iOS 26.0, *) {
            LiquidHomeSearchControl(searchText: $searchText, isSearching: $isSearching)
        } else {
            LegacyHomeSearchControl(searchText: $searchText, isSearching: $isSearching)
        }
    }
}

@available(iOS 26.0, *)
private struct LiquidHomeSearchControl: View {
    @Binding var searchText: String
    @Binding var isSearching: Bool
    @FocusState private var searchIsFocused: Bool

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 4) {
                Spacer(minLength: 0)

                HStack(spacing: 10) {
                    if isSearching {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(LearnAlertStyle.indigo)
                            .transition(.opacity)

                        TextField("Search decks", text: $searchText)
                            .focused($searchIsFocused)
                            .foregroundStyle(LearnAlertStyle.textPrimary)
                            .tint(.white)
                            .transition(.opacity)

                        Button(action: closeSearch) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.headline)
                                .foregroundStyle(.white.opacity(0.82))
                        }
                        .accessibilityLabel("Close search")
                        .transition(.opacity)
                    } else {
                        Button(action: openSearch) {
                            Image(systemName: "magnifyingglass")
                                .font(.headline.bold())
                                .foregroundStyle(.white)
                                .frame(width: 48, height: 48)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Search decks")
                    }
                }
                .padding(.horizontal, isSearching ? 15 : 0)
                .frame(width: isSearching ? geometry.size.width : 48, height: 48)
                .glassEffect(.regular.interactive(), in: .capsule)
                .animation(.spring(duration: 0.5, bounce: 0.22), value: isSearching)
            }
        }
        .frame(height: 48)
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    private func openSearch() {
        withAnimation(.spring(duration: 0.5, bounce: 0.22)) {
            isSearching = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(360))
            searchIsFocused = true
        }
    }

    private func closeSearch() {
        searchText = ""
        searchIsFocused = false
        withAnimation(.spring(duration: 0.5, bounce: 0.22)) {
            isSearching = false
        }
    }
}

private struct LegacyHomeSearchControl: View {
    @Binding var searchText: String
    @Binding var isSearching: Bool
    @FocusState private var searchIsFocused: Bool

    var body: some View {
        HStack {
            Spacer()
            if isSearching {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                    TextField("Search decks", text: $searchText)
                        .focused($searchIsFocused)
                    Button {
                        searchText = ""
                        searchIsFocused = false
                        withAnimation(.spring) { isSearching = false }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 15)
                .frame(maxWidth: 330, minHeight: 48)
                .nativeGlass(cornerRadius: 24)
            } else {
                Button {
                    withAnimation(.spring) { isSearching = true }
                    searchIsFocused = true
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .nativeGlass(cornerRadius: 24)
                }
                .accessibilityLabel("Search decks")
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }
}

// MARK: - Liquid Tab Bar
struct LiquidTabBar: View {
    @Binding var selectedTab: Int
    @Binding var tabDragOffset: CGFloat
    let createDeck: () -> Void
    let importWithAI: () -> Void
    @Namespace private var selectionNamespace
    @State private var showingCreationActions = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            if showingCreationActions {
                creationAction(title: "Import with AI", systemImage: "sparkles") {
                    InteractionSoundPlayer.shared.play(.click)
                    showingCreationActions = false
                    importWithAI()
                }
                .offset(y: -138)
                .transition(.offset(y: 138))

                creationAction(title: "Create Deck", systemImage: "rectangle.stack.badge.plus") {
                    InteractionSoundPlayer.shared.play(.click)
                    showingCreationActions = false
                    createDeck()
                }
                .offset(y: -72)
                .transition(.offset(y: 72))
            }

            HStack(spacing: 10) {
                HStack {
                TabBarItem(icon: "rectangle.stack.fill", title: "Home", tab: 0, selectedTab: $selectedTab, selectionNamespace: selectionNamespace)
                TabBarItem(icon: "books.vertical.fill", title: "Discover", tab: 1, selectedTab: $selectedTab, selectionNamespace: selectionNamespace)
                TabBarItem(icon: "chart.bar.fill", title: "Progress", tab: 2, selectedTab: $selectedTab, selectionNamespace: selectionNamespace)
                TabBarItem(icon: "gearshape.fill", title: "Settings", tab: 3, selectedTab: $selectedTab, selectionNamespace: selectionNamespace)
                }
                .padding(5)
                .background(.ultraThinMaterial, in: Capsule())
                .background(LearnAlertStyle.glassTint, in: Capsule())
                .overlay(Capsule().stroke(LearnAlertStyle.glassStroke, lineWidth: 0.8))

                Button {
                    withAnimation(.spring(duration: 0.42, bounce: 0.16)) {
                        showingCreationActions.toggle()
                    }
                } label: {
                    Image(systemName: showingCreationActions ? "xmark" : "plus")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(LearnAlertStyle.textPrimary)
                        .frame(width: 54, height: 54)
                        .background(.ultraThinMaterial, in: Circle())
                        .background(LearnAlertStyle.glassTint, in: Circle())
                        .overlay(Circle().stroke(LearnAlertStyle.glassStroke, lineWidth: 0.8))
                }
                .accessibilityLabel("New deck options")
            }
            .zIndex(1)
        }
        .shadow(color: Color.black.opacity(0.12), radius: 14, y: 7)
        .offset(x: tabDragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in tabDragOffset = value.translation.width / 3 }
                .onEnded { value in
                    let threshold: CGFloat = 40
                    if value.translation.width > threshold && selectedTab > 0 {
                        selectedTab -= 1
                    } else if value.translation.width < -threshold && selectedTab < 3 {
                        selectedTab += 1
                    }
                    withAnimation(.easeOut(duration: 0.18)) {
                        tabDragOffset = 0
                    }
                }
        )
        .padding(.horizontal, 22)
        .padding(.bottom, 5)
        .animation(.spring(response: 0.36, dampingFraction: 0.68, blendDuration: 0.12), value: selectedTab)
    }

    private func creationAction(title: LocalizedStringResource, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.custom("Poppins-SemiBold", size: 15, relativeTo: .body))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(LearnAlertStyle.textPrimary)
        .buttonStyle(CreationActionButtonStyle())
        .frame(maxWidth: .infinity)
    }
}

private struct CreationActionButtonStyle: ButtonStyle {
    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        if #available(iOS 26.0, *) {
            configuration.label
                .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
                .padding(.horizontal, 18)
                .glassEffect(.regular.interactive(), in: .capsule)
        } else {
            configuration.label
                .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
                .padding(.horizontal, 18)
                .background(.ultraThinMaterial, in: Capsule())
                .background(LearnAlertStyle.glassTint, in: Capsule())
                .overlay(Capsule().stroke(LearnAlertStyle.glassStroke, lineWidth: 0.8))
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .opacity(configuration.isPressed ? 0.84 : 1)
        }
    }
}

struct TabBarItem: View {
    let icon: String
    let title: String
    let tab: Int
    @Binding var selectedTab: Int
    let selectionNamespace: Namespace.ID
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.36, dampingFraction: 0.68, blendDuration: 0.12)) {
                selectedTab = tab
            }
        }) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: selectedTab == tab ? .bold : .medium))
                    .scaleEffect(selectedTab == tab ? 1.08 : 1.0)
                    .frame(width: 24, height: 22, alignment: .center)

                Text(title)
                    .font(.system(size: 10, weight: selectedTab == tab ? .semibold : .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .frame(height: 13, alignment: .center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .foregroundStyle(selectedTab == tab ? (colorScheme == .light ? LearnAlertStyle.sky : Color.white) : LearnAlertStyle.textSecondary.opacity(0.60))
            .shadow(color: selectedTab == tab ? Color.black.opacity(0.24) : .clear, radius: 2, y: 1)
            .background {
                if selectedTab == tab {
                    selectionBackground
                        .matchedGeometryEffect(id: "tab-selection", in: selectionNamespace)
                }
            }
            .contentShape(Capsule())
        }
        .accessibilityLabel(title)
        .accessibilityShowsLargeContentViewer {
            Label(title, systemImage: icon)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var selectionBackground: some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: colorScheme == .light
                        ? [Color.white.opacity(0.92), Color.white.opacity(0.78)]
                        : [Color.white.opacity(0.24), Color.white.opacity(0.14)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                Capsule()
                    .stroke(
                    LinearGradient(
                        colors: colorScheme == .light
                            ? [Color.white.opacity(0.95), Color.white.opacity(0.40)]
                            : [Color.white.opacity(0.40), Color.white.opacity(0.10)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.9
                )
            )
            .shadow(color: (colorScheme == .light ? LearnAlertStyle.indigo.opacity(0.16) : Color.black.opacity(0.35)), radius: 7, x: 0, y: 2)
            .padding(.horizontal, 1)
            .padding(.vertical, 1)
    }
}

// MARK: - Tab 1: Home Library
struct HomeLibraryView: View {
    @Query(sort: \Deck.orderIndex) private var decks: [Deck]
    @Environment(\.modelContext) private var context
    @State private var draggedDeck: Deck?
    @State private var isSearchExpanded = false
    @State private var showingAIComposer = false
    @State private var showingAlertSettings = false
    @State private var showingDeckRequirementAlert = false
    @State private var showingNotificationsDisabledAlert = false
    @Environment(\.openURL) private var openURL
    @State private var scheduleCelebrationTrigger = 0
    @State private var deckPendingDeletion: Deck?
    @State private var homeAlertMessage: String?
    @AppStorage("hasSeenQuickScheduleSwitchTip") private var hasSeenQuickScheduleSwitchTip = false
    @State private var showingQuickScheduleTipToast = false
    @Binding var searchText: String
    @Binding var selectedTab: Int
    @Binding var showingCreateDeck: Bool
    let columns = [GridItem(.flexible())]
    
    @AppStorage("targetDeckId") private var targetDeckId: String = "ALL"
    @ObservedObject private var engine = StudyEngine.shared
    
    var filteredDecks: [Deck] {
        if searchText.isEmpty { return decks }
        return decks.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        ZStack {
            HomeWallpaperBackground()

            ScheduleLightBurst(trigger: scheduleCelebrationTrigger)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ZStack {
                        HStack(spacing: 12) {
                            LearnAlertLogoMark()

                            if isSearchExpanded {
                            HStack(spacing: 10) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(LearnAlertStyle.textSecondary)
                                TextField("Search your decks", text: $searchText)
                                    .font(.custom("Poppins-Regular", size: 14, relativeTo: .body))
                                    .foregroundStyle(LearnAlertStyle.textPrimary)
                                    .submitLabel(.search)
                            }
                            .padding(.horizontal, 14)
                            .frame(height: 48)
                            .background(LearnAlertStyle.courseSurface)
                            .clipShape(Capsule())
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                            } else {
                                Spacer()
                            }

                            Button {
                                withAnimation(.snappy) {
                                    isSearchExpanded.toggle()
                                    if !isSearchExpanded { searchText = "" }
                                }
                            } label: {
                                Image(systemName: isSearchExpanded ? "xmark" : "magnifyingglass")
                                    .font(.headline)
                                    .foregroundStyle(LearnAlertStyle.textPrimary)
                                    .frame(width: 48, height: 48)
                                    .background(LearnAlertStyle.courseSurface)
                                    .clipShape(Capsule())
                            }
                            .accessibilityLabel(isSearchExpanded ? "Close deck search" : "Search decks")
                        }

                    }
                    .padding(.horizontal, 20)

                    HomeAlertSetupCard(
                        decks: decks,
                        engine: engine,
                        targetDeckId: $targetDeckId,
                        showSettings: { showingAlertSettings = true },
                        showDeckRequirement: {
                            withAnimation(.snappy) { showingDeckRequirementAlert = true }
                        },
                        schedule: { quickSchedule($0, fromDeckCard: false) }
                    )
                    .padding(.horizontal, 20)

                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Your library")
                                .font(.custom("Poppins-SemiBold", size: 16, relativeTo: .headline))
                                .foregroundStyle(LearnAlertStyle.textPrimary)
                            Spacer()
                            Text("\(filteredDecks.count) decks")
                                .font(.custom("Poppins-Regular", size: 12, relativeTo: .caption))
                                .foregroundStyle(LearnAlertStyle.textSecondary)
                        }
                        .padding(.horizontal, 20)

                        if filteredDecks.isEmpty {
                            EmptyLibraryCard(
                                isSearching: !searchText.isEmpty,
                                onCreateDeck: { showingCreateDeck = true },
                                onBrowseDiscover: { selectedTab = 1 }
                            )
                            .padding(.horizontal, 20)
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredDecks) { deck in
                                    let isTargeted = engine.isActive && (targetDeckId == "ALL" || targetDeckId == deck.id.uuidString)
                                    HomeStudyCard(
                                        deck: deck,
                                        isTargeted: isTargeted,
                                        schedule: { quickSchedule(deck, fromDeckCard: true) },
                                        shuffleAppearance: { shuffleAppearance(for: deck) },
                                        delete: { deckPendingDeletion = deck }
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    Spacer().frame(height: 210)
                }
                .padding(.top, 22)
            }
            .blur(radius: showingDeckRequirementAlert ? 3 : 0)
            .animation(.easeInOut(duration: 0.25), value: showingDeckRequirementAlert)

            if showingDeckRequirementAlert {
                DeckRequirementAlert(
                    createDeck: {
                        showingDeckRequirementAlert = false
                        showingCreateDeck = true
                    },
                    discoverDecks: {
                        showingDeckRequirementAlert = false
                        selectedTab = 1
                    },
                    generateWithAI: {
                        showingDeckRequirementAlert = false
                        showingAIComposer = true
                    },
                    dismiss: {
                        withAnimation(.snappy) { showingDeckRequirementAlert = false }
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(10)
            }

            if showingQuickScheduleTipToast {
                VStack {
                    Spacer()
                    QuickScheduleTipPopup(dismiss: {
                        withAnimation(.snappy) { showingQuickScheduleTipToast = false }
                    })
                    .padding(.bottom, 96)
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
                .zIndex(25)
            }
        }
        .task(id: showingQuickScheduleTipToast) {
            if showingQuickScheduleTipToast {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                withAnimation(.easeInOut(duration: 0.35)) {
                    showingQuickScheduleTipToast = false
                }
            }
        }
        .sheet(isPresented: $showingAlertSettings) {
            NavigationStack {
                ScrollView {
                    SetupAlertsView(engine: engine)
                        .padding(.vertical, 20)
                }
                .background(LearnAlertStyle.courseCanvas.ignoresSafeArea())
                .navigationTitle("Alert Settings")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showingAlertSettings = false }
                    }
                }
            }
        }
        .sheet(isPresented: $showingAIComposer) {
            GeneratedQuizImportView()
        }
        .confirmationDialog(
            "Delete \(deckPendingDeletion?.name ?? "this deck")?",
            isPresented: Binding(
                get: { deckPendingDeletion != nil },
                set: { if !$0 { deckPendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Deck", role: .destructive) {
                guard let deckPendingDeletion else { return }
                InteractionSoundPlayer.shared.play(.deleteDeck)
                context.delete(deckPendingDeletion)
                try? context.save()
                self.deckPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) { deckPendingDeletion = nil }
        }
        .alert("LearnAlert", isPresented: Binding(
            get: { homeAlertMessage != nil },
            set: { if !$0 { homeAlertMessage = nil } }
        )) {
            Button("OK", role: .cancel) { homeAlertMessage = nil }
        } message: {
            Text(homeAlertMessage ?? "")
        }
        .alert("Notifications Disabled", isPresented: $showingNotificationsDisabledAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("LearnAlert needs notification permissions to deliver your scheduled flashcard alerts throughout the day. Please enable them in iOS Settings.")
        }
    }

    private func quickSchedule(_ deck: Deck, fromDeckCard: Bool = false) {
        guard deck.cards.count >= 2 else {
            HapticFeedback.warning()
            homeAlertMessage = "Add at least two cards before scheduling this deck."
            return
        }

        Task { @MainActor in
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                applySchedule(for: deck, fromDeckCard: fromDeckCard)
            case .notDetermined:
                let granted = await NotificationManager.shared.requestPermission()
                if granted {
                    applySchedule(for: deck, fromDeckCard: fromDeckCard)
                } else {
                    HapticFeedback.warning()
                    showingNotificationsDisabledAlert = true
                }
            case .denied:
                HapticFeedback.warning()
                showingNotificationsDisabledAlert = true
            @unknown default:
                applySchedule(for: deck, fromDeckCard: fromDeckCard)
            }
        }
    }

    private func applySchedule(for deck: Deck, fromDeckCard: Bool = false) {
        guard deck.cards.count >= 2 else {
            HapticFeedback.warning()
            homeAlertMessage = "Add at least two cards before scheduling this deck."
            return
        }
        targetDeckId = deck.id.uuidString
        InteractionSoundPlayer.shared.play(.scheduledAlerts)
        HapticFeedback.success()
        scheduleCelebrationTrigger += 1
        engine.startAlerts(for: deck)

        if fromDeckCard && !hasSeenQuickScheduleSwitchTip {
            hasSeenQuickScheduleSwitchTip = true
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                showingQuickScheduleTipToast = true
            }
        }
    }

    private func shuffleAppearance(for deck: Deck) {
        deck.appearanceSeed = DeckCreatureAppearance.newSavedSeed(excluding: deck.appearanceSeed)
        try? context.save()
    }

    @MainActor
    private func openAIComposerIfAvailable() async {
        guard await AIConnectivityCheck.isAvailable() else {
            homeAlertMessage = "AI features need an internet connection. You can still create decks manually, study, and schedule notifications offline."
            return
        }
        showingAIComposer = true
    }

    private var activeScheduledCardCount: Int {
        guard let deck = decks.first(where: { $0.name == engine.activeDeckName }) else { return 0 }
        if let sectionId = engine.activeSectionId {
            return deck.sections.first(where: { $0.id == sectionId })?.cards.count ?? deck.cards.count
        }
        return deck.cards.count
    }
}


private struct EmptyLibraryCard: View {
    let isSearching: Bool
    let onCreateDeck: () -> Void
    let onBrowseDiscover: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: isSearching ? "magnifyingglass" : "rectangle.stack.badge.plus")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(LearnAlertStyle.textSecondary)
                .padding(.top, 4)

            VStack(spacing: 5) {
                Text(isSearching ? "No matching decks" : "No decks created yet")
                    .font(.custom("Poppins-SemiBold", size: 16, relativeTo: .headline))
                    .foregroundStyle(LearnAlertStyle.textPrimary)

                Text(isSearching ? "Try searching with a different keyword." : "Create your first flashcard deck or explore Discover to start learning.")
                    .font(.custom("Poppins-Regular", size: 13, relativeTo: .subheadline))
                    .foregroundStyle(LearnAlertStyle.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if !isSearching {
                HStack(spacing: 10) {
                    Button(action: onCreateDeck) {
                        Label("Create a deck", systemImage: "plus")
                            .font(.custom("Poppins-SemiBold", size: 13, relativeTo: .subheadline))
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                    }
                    .foregroundStyle(.white)
                    .background(LearnAlertStyle.indigo)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

                    Button(action: onBrowseDiscover) {
                        Label("Discover", systemImage: "books.vertical.fill")
                            .font(.custom("Poppins-SemiBold", size: 13, relativeTo: .subheadline))
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                    }
                    .foregroundStyle(LearnAlertStyle.textPrimary)
                    .background(Color.primary.opacity(0.06))
                    .overlay {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .stroke(LearnAlertStyle.glassStroke, lineWidth: 1)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                }
                .padding(.top, 4)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(UIColor.secondarySystemBackground).opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(LearnAlertStyle.glassStroke, lineWidth: 1)
        )
    }
}

private struct HomeWallpaperBackground: View {
    var body: some View {
        LearnAlertStyle.courseCanvas
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct ScheduleLightBurst: View {
    let trigger: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var celebrationStart: Date?

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: celebrationStart == nil || reduceMotion)) { timeline in
            GeometryReader { geometry in
                let elapsed = celebrationStart.map { timeline.date.timeIntervalSince($0) } ?? 0

                Canvas { context, size in
                    guard elapsed > 0 else { return }

                    let fireworks: [(launchX: CGFloat, burst: CGPoint, delay: Double, color: Color)] = [
                        (size.width * 0.22, CGPoint(x: size.width * 0.30, y: 100), 0.00, Color(red: 1.0, green: 0.82, blue: 0.12)),
                        (size.width * 0.50, CGPoint(x: size.width * 0.52, y: 65), 0.20, Color(red: 0.16, green: 1.0, blue: 0.84)),
                        (size.width * 0.78, CGPoint(x: size.width * 0.72, y: 110), 0.40, Color(red: 0.48, green: 0.68, blue: 1.0))
                    ]

                    for (fireworkIndex, firework) in fireworks.enumerated() {
                        let localTime = elapsed - firework.delay
                        guard localTime > 0 else { continue }

                        let launchDuration: Double = 0.58
                        let burstDuration: Double = 1.95

                        // Phase 1: Rocket Ascending
                        if localTime < launchDuration {
                            let launchProgress = CGFloat(localTime / launchDuration)
                            let eased = 1 - pow(1 - launchProgress, 2.2)
                            let start = CGPoint(x: firework.launchX, y: size.height + 20)
                            let head = CGPoint(
                                x: start.x + (firework.burst.x - start.x) * eased + sin(launchProgress * CGFloat.pi) * CGFloat(fireworkIndex - 1) * 10,
                                y: start.y + (firework.burst.y - start.y) * eased
                            )

                            // Rocket trailing embers
                            for emberIndex in 0..<20 {
                                let trailOffset = CGFloat(emberIndex) * 0.015
                                let trailProgress = max(0, launchProgress - trailOffset)
                                let trailEased = 1 - pow(1 - trailProgress, 2.2)
                                let jitter = sin(CGFloat(emberIndex * 19 + fireworkIndex * 37)) * CGFloat(emberIndex) * 0.25
                                let point = CGPoint(
                                    x: start.x + (firework.burst.x - start.x) * trailEased + jitter,
                                    y: start.y + (firework.burst.y - start.y) * trailEased + CGFloat(emberIndex) * 1.6
                                )
                                let emberRadius = max(0.6, 3.2 - CGFloat(emberIndex) * 0.14)
                                let emberAlpha = max(0, 1.0 - Double(emberIndex) / 20.0) * 0.85
                                context.fill(
                                    Path(ellipseIn: CGRect(x: point.x - emberRadius, y: point.y - emberRadius, width: emberRadius * 2, height: emberRadius * 2)),
                                    with: .color(firework.color.opacity(emberAlpha))
                                )
                            }

                            // Glowing rocket head
                            context.fill(Path(ellipseIn: CGRect(x: head.x - 7, y: head.y - 7, width: 14, height: 14)), with: .color(firework.color.opacity(0.35)))
                            context.fill(Path(ellipseIn: CGRect(x: head.x - 3, y: head.y - 3, width: 6, height: 6)), with: .color(Color.white))
                            continue
                        }

                        // Phase 2: Burst & Sparks Falling / Shrinking / Extinguishing
                        let burstTime = localTime - launchDuration
                        guard burstTime < burstDuration else { continue }

                        let burstProgress = CGFloat(burstTime / burstDuration)
                        // Smooth fade curve that reaches zero before the end
                        let fade = pow(max(0, 1.0 - burstProgress), 1.5)
                        // Shrink curve
                        let shrink = max(0.0, 1.0 - burstProgress * 0.88)
                        // Downward gravity acceleration - sparks fall like real falling embers
                        let gravity = 190.0 * pow(burstProgress, 1.65)
                        // Drag deceleration
                        let dragDecay = 1.0 - exp(-CGFloat(burstTime) * 2.8)

                        // Central flash immediately after explosion
                        if burstTime < 0.12 {
                            let flashAlpha = max(0, 1.0 - burstTime / 0.12) * 0.75
                            let flashRadius = CGFloat(burstTime / 0.12) * 24.0
                            context.fill(
                                Path(ellipseIn: CGRect(x: firework.burst.x - flashRadius, y: firework.burst.y - flashRadius, width: flashRadius * 2, height: flashRadius * 2)),
                                with: .color(Color.white.opacity(flashAlpha))
                            )
                        }

                        for particleIndex in 0..<34 {
                            let baseAngle = CGFloat(particleIndex) / 34.0 * CGFloat.pi * 2
                            let angle = baseAngle + CGFloat(fireworkIndex) * 0.28
                            let initialSpeed = CGFloat(60 + (particleIndex * 23 + fireworkIndex * 17) % 65)
                            let travel = initialSpeed * dragDecay * 1.35
                            let radialVariation = 0.85 + CGFloat((particleIndex * 11) % 9) * 0.035
                            let drift = sin(CGFloat(burstTime * 5.0) + CGFloat(particleIndex)) * 3.5 * burstProgress

                            let position = CGPoint(
                                x: firework.burst.x + cos(angle) * travel * radialVariation + drift,
                                y: firework.burst.y + sin(angle) * travel * radialVariation + gravity
                            )

                            let prevTime = max(0, burstTime - 0.045)
                            let prevDrag = 1.0 - exp(-CGFloat(prevTime) * 2.8)
                            let prevTravel = initialSpeed * prevDrag * 1.35
                            let prevGravity = 190.0 * pow(CGFloat(prevTime / burstDuration), 1.65)
                            let prevDrift = sin(CGFloat(prevTime * 5.0) + CGFloat(particleIndex)) * 3.5 * CGFloat(prevTime / burstDuration)
                            let previous = CGPoint(
                                x: firework.burst.x + cos(angle) * prevTravel * radialVariation + prevDrift,
                                y: firework.burst.y + sin(angle) * prevTravel * radialVariation + prevGravity
                            )

                            // Sparkling flicker as embers cool
                            let flicker = 0.72 + 0.28 * sin(CGFloat(particleIndex * 17) + CGFloat(burstTime * 22))
                            let particleAlpha = Double(fade * flicker)

                            // Streak trail - correctly fades out with particleAlpha!
                            var trail = Path()
                            trail.move(to: previous)
                            trail.addLine(to: position)
                            context.stroke(
                                trail,
                                with: .linearGradient(
                                    Gradient(colors: [
                                        firework.color.opacity(0.0),
                                        firework.color.opacity(particleAlpha * 0.80)
                                    ]),
                                    startPoint: previous,
                                    endPoint: position
                                ),
                                style: StrokeStyle(lineWidth: max(0.5, (particleIndex.isMultiple(of: 4) ? 2.4 : 1.4) * shrink), lineCap: .round)
                            )

                            // Glowing core spark
                            let coreSize: CGFloat = (particleIndex.isMultiple(of: 5) ? 2.6 : 1.6) * shrink
                            context.fill(
                                Path(ellipseIn: CGRect(x: position.x - coreSize, y: position.y - coreSize, width: coreSize * 2, height: coreSize * 2)),
                                with: .color(Color.white.opacity(particleAlpha))
                            )

                            // Soft colored glow around each spark
                            let glowSize = coreSize * 2.0
                            context.fill(
                                Path(ellipseIn: CGRect(x: position.x - glowSize, y: position.y - glowSize, width: glowSize * 2, height: glowSize * 2)),
                                with: .color(firework.color.opacity(particleAlpha * 0.40))
                            )
                        }
                    }
                }
                .blendMode(.plusLighter)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task(id: trigger) {
            guard trigger > 0 else { return }
            celebrationStart = .now
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 800 : 3_200))
            celebrationStart = nil
        }
    }
}

private enum AIConnectivityCheck {
    static func isAvailable() async -> Bool {
        guard let url = URL(string: "https://api.learnalertapp.com") else { return false }
        var request = URLRequest(url: url, timeoutInterval: 6)
        request.httpMethod = "HEAD"
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        if let key = LearnAlertAPI.apiKey {
            request.setValue(key, forHTTPHeaderField: "X-API-Key")
        }

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return response is HTTPURLResponse
        } catch {
            return false
        }
    }
}

private struct HomeAlertSetupCard: View {
    let decks: [Deck]
    @ObservedObject var engine: StudyEngine
    @Binding var targetDeckId: String
    let showSettings: () -> Void
    let showDeckRequirement: () -> Void
    let schedule: (Deck) -> Void
    private var selectedDeck: Deck? {
        decks.first { $0.id.uuidString == targetDeckId && $0.cards.count > 5 }
    }

    private var schedulableDecks: [Deck] {
        decks.filter { $0.cards.count > 5 }
    }

    var body: some View {
        Group {
            if engine.isActive {
                activeContent
                    .transition(.asymmetric(insertion: .scale(scale: 0.96).combined(with: .opacity), removal: .opacity))
            } else {
                setupContent
                    .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
            }
        }
        .padding(16)
        .clearGlassSurface(cornerRadius: 20)
        .lightModeGlassElevation(cornerRadius: 20)
        .overlay(alignment: .topTrailing) {
            ScheduleStatusDot(isActive: engine.isActive)
                .padding(16)
        }
        .animation(.spring(response: 0.48, dampingFraction: 0.84), value: engine.isActive)
    }

    private var setupContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Alert Schedule")
                        .font(.custom("Poppins-SemiBold", size: 17, relativeTo: .headline))
                        .foregroundStyle(LearnAlertStyle.textPrimary)
                    Text("Select what deck you want to schedule:")
                        .font(.custom("Poppins-Regular", size: 11, relativeTo: .caption2))
                        .foregroundStyle(LearnAlertStyle.textSecondary)
                }
                Spacer(minLength: 28)
            }

            Group {
                if schedulableDecks.isEmpty {
                    Button(action: showDeckRequirement) {
                        DeckPickerLabel(selectedDeck: selectedDeck)
                    }
                } else {
                    Menu {
                        ForEach(schedulableDecks) { deck in
                            Button(deck.name) {
                                InteractionSoundPlayer.shared.play(.selection)
                                targetDeckId = deck.id.uuidString
                            }
                        }
                    } label: {
                        DeckPickerLabel(selectedDeck: selectedDeck)
                    }
                }
            }
            .overlay { DeckSelectionHintBorder(isVisible: !schedulableDecks.isEmpty && selectedDeck == nil) }

            HStack(spacing: 10) {
                Button {
                    guard let selectedDeck else { return }
                    schedule(selectedDeck)
                } label: {
                    Label("Schedule Alerts", systemImage: "bell.badge.fill")
                        .font(.custom("Poppins-SemiBold", size: 12, relativeTo: .caption))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .foregroundStyle(.white)
                .background(selectedDeck == nil ? Color.gray.opacity(0.34) : LearnAlertStyle.indigo)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .disabled(selectedDeck == nil)

                Button(action: showSettings) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.headline)
                        .frame(width: 44, height: 44)
                        .background(.clear)
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(LearnAlertStyle.glassStroke, lineWidth: 1)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .accessibilityLabel("Edit alert settings")
            }
        }
    }

    private var activeContent: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .top) {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark")
                        .font(.footnote.bold())
                        .foregroundStyle(LearnAlertStyle.indigoDeep)
                        .frame(width: 30, height: 30)
                        .background(LearnAlertStyle.aqua)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Deck Scheduled")
                            .font(.custom("Poppins-SemiBold", size: 17, relativeTo: .headline))
                        Text(engine.activeDeckName)
                            .font(.custom("Poppins-Regular", size: 12, relativeTo: .subheadline))
                            .foregroundStyle(LearnAlertStyle.textSecondary)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 28)
            }
            .foregroundStyle(LearnAlertStyle.textPrimary)

            HStack(spacing: 10) {
                Button(action: showSettings) {
                    Label("Edit", systemImage: "slider.horizontal.3")
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                }
                .foregroundStyle(LearnAlertStyle.indigo)
                .background(.clear)
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(LearnAlertStyle.glassStroke, lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Button(role: .destructive) {
                    HapticFeedback.impact(.medium)
                    withAnimation { engine.stopAlerts() }
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                }
                .foregroundStyle(LearnAlertStyle.destructiveRed)
                .background(LearnAlertStyle.destructiveRed.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .font(.custom("Poppins-SemiBold", size: 14, relativeTo: .subheadline))

            UpcomingAlertsTimeline(scheduledDates: engine.scheduledDates)
        }
    }
}

private struct DeckPickerLabel: View {
    let selectedDeck: Deck?

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(selectedDeck?.name ?? "Choose a deck")
                    .font(.custom("Poppins-Medium", size: 13, relativeTo: .subheadline))
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(selectedDeck.map { "\($0.cards.count) cards" } ?? "Nothing selected")
                    .font(.custom("Poppins-Regular", size: 10, relativeTo: .caption2))
                    .foregroundStyle(LearnAlertStyle.textSecondary)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption.bold())
                .foregroundStyle(LearnAlertStyle.textSecondary)
        }
        .foregroundStyle(LearnAlertStyle.textPrimary)
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 66, alignment: .leading)
        .background(LearnAlertStyle.courseCanvas)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}

private struct ScheduleStatusDot: View {
    let isActive: Bool

    var body: some View {
        Circle()
            .fill(isActive ? Color.green : Color.clear)
            .overlay {
                Circle()
                    .stroke(isActive ? Color.green.opacity(0.45) : Color.gray.opacity(0.65), lineWidth: 2)
            }
            .frame(width: 12, height: 12)
            .shadow(color: isActive ? Color.green.opacity(0.45) : Color.clear, radius: 5)
            .accessibilityLabel(isActive ? "Schedule active" : "No active schedule")
    }
}

private struct DeckSelectionHintBorder: View {
    let isVisible: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var glowOpacity: CGFloat = 0.0

    var body: some View {
        RoundedRectangle(cornerRadius: 13, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [
                        Color(red: 1.0, green: 0.96, blue: 0.45).opacity(glowOpacity),
                        Color(red: 1.0, green: 0.82, blue: 0.18).opacity(glowOpacity * 0.85),
                        Color(red: 1.0, green: 0.96, blue: 0.45).opacity(glowOpacity)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1.5
            )
            .shadow(
                color: Color(red: 1.0, green: 0.88, blue: 0.22).opacity(glowOpacity * 0.45),
                radius: 4,
                x: 0,
                y: 0
            )
            .shadow(
                color: Color(red: 1.0, green: 0.78, blue: 0.12).opacity(glowOpacity * 0.22),
                radius: 8,
                x: 0,
                y: 0
            )
            .padding(1)
            .opacity(isVisible ? 1 : 0)
            .animation(.easeInOut(duration: 0.3), value: isVisible)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .task(id: isVisible) {
                glowOpacity = 0
                guard isVisible else { return }
                if reduceMotion {
                    glowOpacity = 0.35
                    return
                }
                while !Task.isCancelled {
                    // Smooth pulse in (neon / shiny ring highlight)
                    withAnimation(.easeInOut(duration: 1.2)) {
                        glowOpacity = 0.80
                    }
                    try? await Task.sleep(nanoseconds: 1_200_000_000)

                    // Gentle fade down
                    withAnimation(.easeInOut(duration: 1.4)) {
                        glowOpacity = 0.15
                    }
                    try? await Task.sleep(nanoseconds: 1_400_000_000)

                    // Fade to rest
                    withAnimation(.easeInOut(duration: 0.8)) {
                        glowOpacity = 0.0
                    }
                    // Less frequent: resting interval between pulses
                    try? await Task.sleep(nanoseconds: 4_000_000_000)
                }
            }
    }
}

private struct DeckRequirementAlert: View {
    let createDeck: () -> Void
    let discoverDecks: () -> Void
    var generateWithAI: (() -> Void)? = nil
    let dismiss: () -> Void

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Color.black.opacity(0.25))
                .ignoresSafeArea()
                .onTapGesture(perform: dismiss)

            VStack(spacing: 16) {
                Image(systemName: "rectangle.stack.badge.plus")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(LearnAlertStyle.figmaBlue)
                    .frame(width: 54, height: 54)
                    .background(.ultraThinMaterial, in: Circle())

                VStack(spacing: 7) {
                    Text("You need a study-ready deck")
                        .font(.custom("Poppins-SemiBold", size: 17, relativeTo: .headline))
                        .foregroundStyle(LearnAlertStyle.textPrimary)
                        .multilineTextAlignment(.center)
                    Text("Create a deck with more than 5 cards, add cards to an existing deck, or find one on Discover.")
                        .font(.custom("Poppins-Regular", size: 12, relativeTo: .subheadline))
                        .foregroundStyle(LearnAlertStyle.textSecondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 9) {
                    Button(action: createDeck) {
                        Label("Create a deck", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .buttonStyle(.plain)
                    .font(.custom("Poppins-SemiBold", size: 13, relativeTo: .body))
                    .foregroundStyle(.white)
                    .background(LearnAlertStyle.indigo, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Button(action: discoverDecks) {
                        Label("Browse Discover", systemImage: "books.vertical.fill")
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .buttonStyle(.plain)
                    .font(.custom("Poppins-SemiBold", size: 13, relativeTo: .body))
                    .foregroundStyle(LearnAlertStyle.textPrimary)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    if let generateWithAI {
                        Button(action: generateWithAI) {
                            HStack(spacing: 7) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color(red: 0.85, green: 0.65, blue: 1.0))
                                Text("Upload with AI")
                                    .font(.custom("Poppins-SemiBold", size: 13, relativeTo: .body))
                                    .foregroundStyle(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(.ultraThinMaterial)
                            )
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(red: 0.65, green: 0.35, blue: 0.95).opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.82, green: 0.58, blue: 1.0).opacity(0.38),
                                                Color(red: 0.60, green: 0.35, blue: 0.95).opacity(0.18)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                            .shadow(color: Color(red: 0.70, green: 0.40, blue: 1.0).opacity(0.16), radius: 6, x: 0, y: 0)
                        }
                        .buttonStyle(.plain)
                    }

                    Button("Not now", action: dismiss)
                        .font(.custom("Poppins-Medium", size: 12, relativeTo: .callout))
                        .foregroundStyle(LearnAlertStyle.textSecondary)
                        .padding(.top, 10)
                }
            }
            .padding(22)
            .frame(maxWidth: 330)
            .clearGlassSurface(cornerRadius: 24)
            .padding(.horizontal, 24)
        }
        .accessibilityAddTraits(.isModal)
    }
}

private struct UpcomingAlertsTimeline: View {
    let scheduledDates: [Date]

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { timeline in
            let dates = scheduledDates.sorted()
            let futureDates = dates.filter { $0 > timeline.date }

            if let nextDate = futureDates.first {
                HStack(spacing: 9) {
                    Image(systemName: "bell.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(LearnAlertStyle.aqua)

                    Text(nextDate, format: .dateTime.hour().minute())
                        .font(.custom("Poppins-Medium", size: 9, relativeTo: .caption2))
                        .foregroundStyle(LearnAlertStyle.textSecondary)
                        .fixedSize()

                    AlertTimelineTrack(dates: dates, currentDate: timeline.date)
                }
                .frame(height: 12)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Next notification at \(nextDate.formatted(date: .omitted, time: .shortened))")
            }
        }
    }
}

private struct AlertTimelineTrack: View {
    let dates: [Date]
    let currentDate: Date

    private var progress: Double {
        guard let first = dates.first, let last = dates.last, last > first else {
            return currentDate >= (dates.first ?? .distantFuture) ? 1 : 0
        }

        return min(max(currentDate.timeIntervalSince(first) / last.timeIntervalSince(first), 0), 1)
    }

    var body: some View {
        GeometryReader { geometry in
            let trackWidth = geometry.size.width

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(LearnAlertStyle.textSecondary.opacity(0.20))
                    .frame(height: 1.5)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [LearnAlertStyle.aqua, LearnAlertStyle.indigo],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: trackWidth * progress, height: 1.5)

                ForEach(Array(dates.enumerated()), id: \.offset) { index, date in
                    let position = dates.count == 1
                        ? trackWidth
                        : trackWidth * CGFloat(index) / CGFloat(dates.count - 1)
                    let isNext = date > currentDate && !dates.prefix(index).contains(where: { $0 > currentDate })

                    Circle()
                        .fill(
                            isNext
                                ? LearnAlertStyle.aqua
                                : (date <= currentDate ? LearnAlertStyle.indigo : LearnAlertStyle.textSecondary.opacity(0.45))
                        )
                        .frame(width: isNext ? 5 : 3.5, height: isNext ? 5 : 3.5)
                        .overlay {
                            if isNext {
                                Circle()
                                    .stroke(LearnAlertStyle.aqua.opacity(0.28), lineWidth: 3)
                            }
                        }
                        .position(x: min(max(position, 2.5), trackWidth - 2.5), y: geometry.size.height / 2)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(height: 8)
    }
}

private struct HomeStudyCard: View {
    let deck: Deck
    let isTargeted: Bool
    let schedule: () -> Void
    let shuffleAppearance: () -> Void
    let delete: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            NavigationLink(destination: DeckDetailView(deck: deck)) {
                HStack(spacing: 16) {
                    DeckCreatureView(
                        stableID: deck.id,
                        appearanceSeed: deck.appearanceSeed,
                        cardCount: deck.cards.count
                    )
                    .frame(width: 96, height: 88)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(deck.name)
                            .font(.custom("Poppins-SemiBold", size: 14, relativeTo: .headline))
                            .foregroundStyle(LearnAlertStyle.textPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        Text("\(deck.deckType) · \(deck.cards.count) cards")
                            .font(.custom("Poppins-Regular", size: 11, relativeTo: .caption))
                            .foregroundStyle(LearnAlertStyle.textSecondary)

                        Spacer(minLength: 0)

                        HStack(spacing: 6) {
                            if deck.cycleStreak > 0 {
                                HStack(spacing: 2) {
                                    Text("🔥")
                                        .font(.system(size: 11))
                                    Text("\(deck.cycleStreak)")
                                        .font(.custom("Poppins-SemiBold", size: 11, relativeTo: .caption))
                                        .foregroundStyle(Color(red: 1.00, green: 0.45, blue: 0.12))
                                        .monospacedDigit()
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.14), in: Capsule())
                            } else {
                                Image(systemName: "chart.bar.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(progressColor)
                            }

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(LearnAlertStyle.textSecondary.opacity(0.18))
                                        .frame(height: 4)

                                    Capsule()
                                        .fill(progressColor)
                                        .frame(
                                            width: max(geo.size.width * CGFloat(deck.cycleProgress), deck.cycleProgress > 0 ? 4 : 0),
                                            height: 4
                                        )
                                }
                                .frame(maxHeight: .infinity, alignment: .center)
                            }
                            .frame(width: 44, height: 12)

                            Text(deck.cycleProgress, format: .percent.precision(.fractionLength(0)))
                                .monospacedDigit()
                                .foregroundStyle(progressColor)

                            Spacer()
                        }
                        .font(.custom("Poppins-Medium", size: 11, relativeTo: .caption))
                    }
                    .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
                }
                .padding(11)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open \(deck.name), \(deck.cards.count) cards")

            Button(action: schedule) {
                Image(systemName: isTargeted ? "bell.badge.fill" : "bell.badge")
                    .foregroundStyle(isTargeted ? LearnAlertStyle.figmaBlue : LearnAlertStyle.textSecondary)
                    .frame(width: 44, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 9)
            .padding(.bottom, 7)
            .accessibilityLabel(isTargeted ? "Deck alerts active" : "Quick schedule \(deck.name)")
        }
        .background(LearnAlertStyle.courseSurface)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(colorScheme == .light ? LearnAlertStyle.hairline.opacity(0.58) : Color.clear, lineWidth: 0.9)
        }
        .shadow(
            color: colorScheme == .light ? LearnAlertStyle.indigoDeep.opacity(0.11) : LearnAlertStyle.indigoDeep.opacity(0.06),
            radius: 14,
            y: 7
        )
        .contextMenu {
            Button(action: shuffleAppearance) {
                Label("Shuffle Appearance", systemImage: "shuffle")
            }
            Button(role: .destructive, action: delete) { Label("Delete", systemImage: "trash") }
        }
    }

    private var progressColor: Color {
        if deck.cycleStreak > 0 {
            if deck.cycleProgress >= 0.70 {
                return Color(red: 0.18, green: 0.80, blue: 0.44)
            } else if deck.cycleProgress >= 0.40 {
                return Color(red: 0.35, green: 0.78, blue: 0.42)
            } else if deck.cycleProgress > 0 {
                return Color(red: 0.96, green: 0.76, blue: 0.18)
            } else {
                return Color(red: 1.00, green: 0.48, blue: 0.14)
            }
        } else {
            if deck.cycleProgress >= 1.0 {
                return Color(red: 0.18, green: 0.80, blue: 0.44)
            } else if deck.cycleProgress >= 0.70 {
                return Color(red: 0.35, green: 0.78, blue: 0.42)
            } else if deck.cycleProgress >= 0.40 {
                return Color(red: 0.96, green: 0.76, blue: 0.18)
            } else if deck.cycleProgress > 0 {
                return Color(red: 1.00, green: 0.58, blue: 0.18)
            } else {
                return Color.gray.opacity(0.55)
            }
        }
    }

    private func iconForType(_ type: String) -> String {
        switch type {
        case "Quiz": return "checkmark.rectangle.stack.fill"
        case "Vocabulary": return "text.book.closed.fill"
        case "True / False": return "switch.2"
        default: return "rectangle.stack.fill"
        }
    }
}

private struct HomeCommandPanel: View {
    let createDeck: () -> Void
    let openAIComposer: () -> Void
    let isScheduled: Bool
    let deckName: String
    let scheduledDates: [Date]
    let totalCardCount: Int

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                HomeCommandButton(title: "Create Deck", icon: "rectangle.stack.badge.plus", color: LearnAlertStyle.indigo, action: createDeck)
                    .frame(width: 105)
                Divider().frame(height: 58)
                HomeCommandButton(
                    title: "Paste notes or upload documents",
                    icon: "sparkles.rectangle.stack.fill",
                    color: Color(red: 0.88, green: 0.12, blue: 0.62),
                    action: openAIComposer
                )
                .frame(maxWidth: .infinity)
                .layoutPriority(1)
            }
            .padding(.vertical, 14)

            Rectangle()
                .fill(Color.white.opacity(0.34))
                .frame(height: 0.5)

            ScheduleProgressStrip(
                isScheduled: isScheduled,
                deckName: deckName,
                scheduledDates: scheduledDates,
                totalCardCount: totalCardCount
            )
        }
        .nativeGlass(cornerRadius: 12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.32), lineWidth: 1))
    }
}

private struct ScheduleProgressStrip: View {
    let isScheduled: Bool
    let deckName: String
    let scheduledDates: [Date]
    let totalCardCount: Int

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { timeline in
            if isScheduled, !scheduledDates.isEmpty, totalCardCount > 0 {
                scheduledContent(at: timeline.date)
            } else {
                HStack(spacing: 9) {
                    Circle()
                        .fill(Color.yellow)
                        .frame(width: 8, height: 8)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("No active schedule")
                            .font(.custom("Poppins-Medium", size: 12, relativeTo: .subheadline))
                        Text("Select a deck below when you’re ready.")
                            .font(.custom("Poppins-Regular", size: 10, relativeTo: .caption2))
                            .foregroundStyle(LearnAlertStyle.textSecondary)
                    }
                    Spacer(minLength: 0)
                }
                .foregroundStyle(LearnAlertStyle.textPrimary)
                .padding(.vertical, 3)
            }
        }
    }

    private func scheduledContent(at date: Date) -> some View {
        let orderedDates = scheduledDates.sorted()
        let deliveredCount = min(orderedDates.filter { $0 <= date }.count, totalCardCount)
        let progress = Double(deliveredCount) / Double(totalCardCount)
        let interval = notificationInterval(for: orderedDates)
        let estimatedDuration = interval * Double(max(totalCardCount - 1, 0))

        return VStack(spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "bell.badge.fill")
                    .foregroundStyle(LearnAlertStyle.indigo)
                Text(deckName)
                    .font(.caption.bold())
                    .lineLimit(2)
                Spacer(minLength: 8)
                Text("About \(estimatedDuration.formattedDuration)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(LearnAlertStyle.textSecondary)
            }

            ProgressView(value: progress)
                .tint(LearnAlertStyle.indigo)
                .scaleEffect(x: 1, y: 0.7)
        }
        .foregroundStyle(LearnAlertStyle.textPrimary)
        .padding(.horizontal, 14)
        .frame(height: 58)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(deckName), \(deliveredCount) of \(totalCardCount) notifications delivered, estimated duration \(estimatedDuration.formattedDuration)")
    }

    private func notificationInterval(for dates: [Date]) -> TimeInterval {
        guard dates.count > 1 else { return 60 * 60 }
        return max(dates[1].timeIntervalSince(dates[0]), 60)
    }
}

private extension TimeInterval {
    var formattedDuration: String {
        let totalMinutes = max(Int((self / 60).rounded()), 1)
        let days = totalMinutes / (24 * 60)
        let hours = (totalMinutes % (24 * 60)) / 60
        let minutes = totalMinutes % 60
        if days > 0 { return hours > 0 ? "\(days)d \(hours)h" : "\(days)d" }
        if hours > 0 { return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h" }
        return "\(minutes)m"
    }
}

private struct HomeCommandButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2.bold())
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(LearnAlertStyle.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tab 2: Alerts Dashboard
struct AlertsDashboardView: View {
    @Query(sort: \Deck.creationDate) private var decks: [Deck]
    @ObservedObject private var engine = StudyEngine.shared

    private var cards: [Flashcard] { decks.flatMap(\.cards) }
    private var reviewCount: Int { cards.reduce(0) { $0 + $1.reviewCount } }
    private var correctCount: Int { cards.reduce(0) { $0 + $1.correctCount } }
    private var accuracy: Int { reviewCount == 0 ? 0 : Int((Double(correctCount) / Double(reviewCount) * 100).rounded()) }
    private var longestStreak: Int { cards.map(\.longestStreak).max() ?? 0 }
    private var studiedDeckCount: Int { decks.filter { $0.cards.contains { $0.reviewCount > 0 } }.count }
    private var firstStudyDate: Date? { cards.compactMap(\.lastReviewedDate).min() }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                AppSectionHeader(
                    title: "Progress",
                    subtitle: "From your first deck to every in-app study session."
                )

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ProgressStatCard(title: "Answers", value: "\(reviewCount)", icon: "checkmark.circle.fill", color: LearnAlertStyle.sky)
                    ProgressStatCard(title: "Accuracy", value: reviewCount == 0 ? "—" : "\(accuracy)%", icon: "scope", color: LearnAlertStyle.sky)
                    ProgressStatCard(title: "Best streak", value: "\(longestStreak)", icon: "flame.fill", color: LearnAlertStyle.sky)
                    ProgressStatCard(title: "Decks studied", value: "\(studiedDeckCount)", icon: "rectangle.stack.fill", color: LearnAlertStyle.sky)
                }
                .padding(.horizontal, 24)

                VStack(alignment: .leading, spacing: 14) {
                    Text("LEARNING JOURNEY")
                        .font(.custom("Poppins-SemiBold", size: 11, relativeTo: .caption))
                        .tracking(1.1)
                        .foregroundStyle(LearnAlertStyle.textSecondary)
                    ProgressMilestone(icon: "rectangle.stack.badge.plus", title: "First deck created", detail: decks.first?.creationDate.formatted(date: .abbreviated, time: .omitted) ?? "Not yet")
                    ProgressMilestone(icon: "bell.badge.fill", title: "Alert learning", detail: engine.isActive ? "Active · \(engine.activeDeckName)" : "No active schedule")
                    ProgressMilestone(icon: "play.circle.fill", title: "In-app studying", detail: firstStudyDate?.formatted(date: .abbreviated, time: .shortened) ?? "No sessions yet")
                }
                .padding(18)
                .clearGlassSurface(cornerRadius: 20)
                .lightModeGlassElevation(cornerRadius: 20)
                .padding(.horizontal, 24)

                Spacer().frame(height: 120)
            }
            .padding(.top, 22)
        }
        .background(LearnAlertStyle.courseCanvas.ignoresSafeArea())
    }
}

private struct ProgressStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(value)
                .font(.custom("Poppins-SemiBold", size: 24, relativeTo: .title))
                .foregroundStyle(LearnAlertStyle.textPrimary)
            Text(title)
                .font(.custom("Poppins-Regular", size: 11, relativeTo: .caption))
                .foregroundStyle(LearnAlertStyle.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .clearGlassSurface(cornerRadius: 18)
        .lightModeGlassElevation(cornerRadius: 18)
    }
}

private struct ProgressMilestone: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(LearnAlertStyle.sky)
                .frame(width: 34, height: 34)
                .clearGlassSurface(cornerRadius: 17)
                .lightModeGlassElevation(cornerRadius: 17)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.custom("Poppins-Medium", size: 13, relativeTo: .subheadline))
                Text(detail).font(.custom("Poppins-Regular", size: 11, relativeTo: .caption)).foregroundStyle(LearnAlertStyle.textSecondary)
            }
            .foregroundStyle(LearnAlertStyle.textPrimary)
            Spacer()
        }
    }
}

private struct AlertsInfoControl: View {
    @State private var isExpanded = false

    var body: some View {
        GeometryReader { geometry in
            HStack {
                Spacer(minLength: 0)

                HStack(spacing: 10) {
                    Button {
                        withAnimation(.spring(duration: 0.5, bounce: 0.22)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isExpanded ? "xmark" : "info")
                            .font(.headline.bold())
                            .foregroundStyle(.white)
                            .frame(width: 48, height: 48)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isExpanded ? "Close alert information" : "About alert delivery")

                    if isExpanded {
                        Text("Alerts appear while your device is locked or on the Home Screen—not while you’re using LearnAlert.")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                            .transition(.opacity)
                    }
                }
                .padding(.trailing, isExpanded ? 14 : 0)
                .frame(width: isExpanded ? geometry.size.width : 48)
                .frame(minHeight: 48)
                .nativeGlass(cornerRadius: isExpanded ? 18 : 24)
                .animation(.spring(duration: 0.5, bounce: 0.22), value: isExpanded)
            }
        }
        .frame(height: 58)
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }
}

struct ActiveAlertsView: View {
    @ObservedObject var engine: StudyEngine
    @Query private var decks: [Deck]

    private var cards: [Flashcard] {
        guard let deck = decks.first(where: { $0.name == engine.activeDeckName }) else { return [] }
        if let sectionId = engine.activeSectionId {
            return deck.sections.first(where: { $0.id == sectionId })?.cards ?? []
        }
        return deck.cards
    }

    private var reviewCount: Int {
        cards.reduce(0) { $0 + $1.reviewCount }
    }

    private var correctCount: Int {
        cards.reduce(0) { $0 + $1.correctCount }
    }

    private var accuracy: Int {
        guard reviewCount > 0 else { return 0 }
        return Int((Double(correctCount) / Double(reviewCount) * 100).rounded())
    }

    private var nextAlertText: String {
        guard let nextDate = engine.scheduledDates.filter({ $0 > Date() }).min() else {
            return "Wrapping up"
        }
        return nextDate.formatted(date: .omitted, time: .shortened)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ALERTS ARE RUNNING")
                        .font(.caption.bold())
                        .foregroundStyle(LearnAlertStyle.textSecondary)
                    Text(engine.activeDeckName)
                        .font(.title2.bold())
                        .foregroundStyle(LearnAlertStyle.textPrimary)
                }

                Spacer()

                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.title3)
                    .foregroundStyle(LearnAlertStyle.sky)
            }

            HStack(spacing: 10) {
                LearningMetric(title: "Answers", value: "\(reviewCount)", icon: "checkmark.circle")
                LearningMetric(title: "Accuracy", value: reviewCount == 0 ? "—" : "\(accuracy)%", icon: "scope")
            }

            HStack {
                Label("Next alert", systemImage: "clock.fill")
                Spacer()
                Text(nextAlertText)
                    .fontWeight(.bold)
            }
            .font(.subheadline)
            .foregroundStyle(LearnAlertStyle.textPrimary)
            .padding(16)
            .nativeGlass(cornerRadius: 10)

            Text("You can leave the app. Your flashcards will arrive as notifications.")
                .font(.footnote)
                .foregroundStyle(LearnAlertStyle.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: { engine.stopAlerts() }) {
                Label("End Session", systemImage: "stop.circle.fill")
                    .font(.headline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .foregroundStyle(LearnAlertStyle.coral)
                    .nativeGlass(cornerRadius: 10)
            }
        }
        .padding(20)
        .foregroundStyle(LearnAlertStyle.textPrimary)
        .nativeGlass(cornerRadius: 16)
        .padding(.horizontal)
    }
}

private struct LearningMetric: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.bold())
                .foregroundStyle(LearnAlertStyle.sky)
            Text(value)
                .font(.title3.bold().monospacedDigit())
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(LearnAlertStyle.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 13)
        .nativeGlass(cornerRadius: 10)
    }
}

private struct CleanSettingsCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(LearnAlertStyle.courseSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.05),
                radius: 10,
                x: 0,
                y: 3
            )
    }
}

private extension View {
    func cleanSettingsCard() -> some View {
        modifier(CleanSettingsCardModifier())
    }
}

struct SetupAlertsView: View {
    @Query private var decks: [Deck]
    @ObservedObject var engine: StudyEngine
    @State private var selectedDeckId: String = "NONE"
    @State private var selectedSectionId: String = "ALL"
    @State private var showingWarning = false
    @AppStorage("targetDeckId") private var targetDeckId: String = "ALL"
    @AppStorage("alertSound") private var alertSound: String = "alert3.wav"

    private let availableSounds: [AlertSoundOption] = AlertSoundOption.allSounds

    private var selectedSoundName: String {
        AlertSoundOption.displayName(for: alertSound)
    }
    
    var selectedDeck: Deck? { decks.first { $0.id.uuidString == selectedDeckId } }

    var selectedSection: DeckSection? {
        guard selectedSectionId != "ALL",
              let id = UUID(uuidString: selectedSectionId) else { return nil }
        return selectedDeck?.sections.first { $0.id == id }
    }

    var selectedCardCount: Int {
        selectedSection?.cards.count ?? selectedDeck?.cards.count ?? 0
    }

    private var startTimeBinding: Binding<Date> {
        Binding<Date>(
            get: {
                Calendar.current.date(
                    bySettingHour: engine.startHour,
                    minute: engine.startMinute,
                    second: 0,
                    of: Date()
                ) ?? Date()
            },
            set: { newDate in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                if let hour = components.hour { engine.startHour = hour }
                if let minute = components.minute { engine.startMinute = minute }
            }
        )
    }

    private var endTimeBinding: Binding<Date> {
        Binding<Date>(
            get: {
                Calendar.current.date(
                    bySettingHour: engine.endHour,
                    minute: engine.endMinute,
                    second: 0,
                    of: Date()
                ) ?? Date()
            },
            set: { newDate in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                if let hour = components.hour { engine.endHour = hour }
                if let minute = components.minute { engine.endMinute = minute }
            }
        )
    }
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text("SELECT DECK")
                    .font(.caption.bold())
                    .foregroundStyle(LearnAlertStyle.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Menu {
                    Picker("Deck Target", selection: $selectedDeckId) {
                        Text("All Active Decks").tag("ALL")
                        ForEach(decks) { deck in Text(deck.name).tag(deck.id.uuidString) }
                    }
                } label: {
                    HStack {
                        Text(selectedDeckId == "ALL" ? "All Active Decks" : (selectedDeck?.name ?? "None"))
                            .font(.custom("Poppins-Regular", size: 15, relativeTo: .body))
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                            .foregroundStyle(LearnAlertStyle.textSecondary)
                    }
                    .padding(16)
                    .foregroundStyle(LearnAlertStyle.textPrimary)
                    .cleanSettingsCard()
                }
            }
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 10) {
                Text("DAILY SCHEDULE")
                    .font(.caption.bold())
                    .foregroundStyle(LearnAlertStyle.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 0) {
                    HStack {
                        Label("Starts Daily", systemImage: "sun.max.fill")
                            .font(.custom("Poppins-Regular", size: 15, relativeTo: .body))
                        Spacer()
                        DatePicker("", selection: startTimeBinding, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .tint(LearnAlertStyle.indigo)
                    }
                    .padding(16)

                    Divider().background(LearnAlertStyle.hairline.opacity(0.35))

                    HStack {
                        Label("Finishes Daily", systemImage: "moon.stars.fill")
                            .font(.custom("Poppins-Regular", size: 15, relativeTo: .body))
                        Spacer()
                        DatePicker("", selection: endTimeBinding, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .tint(LearnAlertStyle.indigo)
                    }
                    .padding(16)
                }
                .foregroundStyle(LearnAlertStyle.textPrimary)
                .cleanSettingsCard()
            }
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 10) {
                Text("ALERT SETTINGS")
                    .font(.caption.bold())
                    .foregroundStyle(LearnAlertStyle.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 0) {
                    HStack {
                        Text("Stop Alerts")
                            .font(.custom("Poppins-Regular", size: 15, relativeTo: .body))
                        Spacer()
                        Menu {
                            Picker("Stop Condition", selection: $engine.stopCondition) {
                                Text("Until Deck Learnt").tag("Until Deck Learnt")
                                Text("Until Day Ends").tag("Until Day Ends")
                                Text("Until I say so").tag("Until I say so")
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(engine.stopCondition).lineLimit(1)
                                Image(systemName: "chevron.up.chevron.down").font(.caption2)
                            }
                            .font(.custom("Poppins-SemiBold", size: 14, relativeTo: .body))
                            .foregroundStyle(LearnAlertStyle.indigo)
                        }
                    }
                    .padding(16)

                    Divider().background(LearnAlertStyle.hairline.opacity(0.35))

                    // Custom Sound Engine Picker
                    HStack {
                        Text("Alert Sound")
                            .font(.custom("Poppins-Regular", size: 15, relativeTo: .body))
                        Spacer()
                        Menu {
                            Picker("Sound", selection: $alertSound) {
                                ForEach(availableSounds) { sound in
                                    Text(sound.name).tag(sound.id)
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(selectedSoundName).lineLimit(1)
                                Image(systemName: "chevron.up.chevron.down").font(.caption2)
                            }
                            .font(.custom("Poppins-SemiBold", size: 14, relativeTo: .body))
                            .foregroundStyle(LearnAlertStyle.indigo)
                        }
                    }
                    .padding(16)
                }
                .foregroundStyle(LearnAlertStyle.textPrimary)
                .cleanSettingsCard()
            }
            .padding(.horizontal)

            VolumeSnappingSliderView(engine: engine).padding(.horizontal)
        }
        .onAppear {
            if decks.contains(where: { $0.id.uuidString == targetDeckId }) {
                selectedDeckId = targetDeckId
            }
        }
        .onChange(of: selectedDeckId) { _, newValue in
            targetDeckId = newValue
            selectedSectionId = "ALL"
        }
        .onChange(of: alertSound) { _, newValue in
            previewAlertSound(named: newValue)
        }
        .onDisappear {
            InteractionSoundPlayer.shared.stopPreview()
        }
    }

    private func previewAlertSound(named soundName: String) {
        guard soundName != "Default" else {
            AudioServicesPlaySystemSound(1007)
            return
        }
        InteractionSoundPlayer.shared.previewSound(named: soundName)
    }
}

struct VolumeSnappingSliderView: View {
    @ObservedObject var engine: StudyEngine

    private var totalMinutes: Int {
        let startMin = engine.startHour * 60 + engine.startMinute
        var endMin = engine.endHour * 60 + engine.endMinute
        if endMin <= startMin { endMin += 24 * 60 }
        return max(endMin - startMin, 1)
    }

    private var volumeLabels: [String] {
        engine.volumeOptions.map(String.init) + ["•••"]
    }

    private var selectedIntervalLabel: String {
        intervalLabel(for: engine.activeVolume)
    }

    private func intervalLabel(for cardCount: Int) -> String {
        let minutes = max(totalMinutes / max(cardCount, 1), 1)
        let hours = minutes / 60
        let remainder = minutes % 60
        if hours > 0, remainder > 0 { return "\(hours)h\(remainder)" }
        if hours > 0 { return "\(hours)h" }
        return "\(minutes)m"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("ALERT PACE")
                    .font(.caption.bold())
                    .foregroundStyle(LearnAlertStyle.textSecondary)
                Spacer()
                Label("\(engine.activeVolume) cards", systemImage: "rectangle.stack.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(LearnAlertStyle.indigo)
            }

            GeometryReader { geo in
                let itemWidth = geo.size.width / 6
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.primary.opacity(0.06))

                    RoundedRectangle(cornerRadius: 10)
                        .fill(LearnAlertStyle.indigo)
                        .padding(3)
                        .frame(width: itemWidth)
                        .offset(x: CGFloat(engine.volumeSelectionIndex) * itemWidth)
                        .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.7), value: engine.volumeSelectionIndex)

                    HStack(spacing: 0) {
                        ForEach(0..<6, id: \.self) { index in
                            Text(volumeLabels[index])
                                .font(.caption2.bold().monospacedDigit())
                                .foregroundStyle(index == engine.volumeSelectionIndex ? .white : LearnAlertStyle.textSecondary)
                                .minimumScaleFactor(0.65)
                                .frame(width: itemWidth)
                        }
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0).onChanged { value in
                        let newIndex = min(max(Int(value.location.x / itemWidth), 0), 5)
                        if newIndex != engine.volumeSelectionIndex {
                            HapticFeedback.impact(.light)
                        }
                        withAnimation(.interactiveSpring) {
                            engine.volumeSelectionIndex = newIndex
                        }
                    }
                )
            }
            .frame(height: 44)

            if engine.volumeSelectionIndex == 5 {
                HStack {
                    Text("Custom cards per day")
                        .font(.custom("Poppins-Regular", size: 14, relativeTo: .body))
                        .foregroundStyle(LearnAlertStyle.textSecondary)
                    TextField("20", value: $engine.customVolume, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(LearnAlertStyle.indigo)
                        .font(.headline.bold())
                        .onChange(of: engine.customVolume) { _, newValue in
                            if newValue > 50 { engine.customVolume = 50 }
                            else if newValue < 1 { engine.customVolume = 1 }
                        }
                }
                .padding(14)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            HStack(spacing: 0) {
                PaceSummaryValue(value: "\(engine.activeVolume)", label: "CARDS PER DAY")
                Divider()
                    .frame(height: 34)
                PaceSummaryValue(value: selectedIntervalLabel, label: "BETWEEN ALERTS")
            }
            .padding(.vertical, 12)
            .background(LearnAlertStyle.indigo.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(18)
        .cleanSettingsCard()
    }
}

private struct PaceSummaryValue: View {
    let value: String
    let label: LocalizedStringKey

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.bold().monospacedDigit())
                .foregroundStyle(LearnAlertStyle.textPrimary)
            Text(label)
                .font(.caption2.bold())
                .foregroundStyle(LearnAlertStyle.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Library Deck Row
struct DeckGridItem: View {
    let deck: Deck
    let isTargeted: Bool
    let schedule: () -> Void
    let delete: () -> Void
    @State private var swipeOffset: CGFloat = 0

    var body: some View {
        ZStack(alignment: .trailing) {
            Button(role: .destructive) {
                withAnimation(.snappy) { swipeOffset = 0 }
                delete()
            } label: {
                Label("Delete", systemImage: "trash.fill")
                    .labelStyle(.iconOnly)
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 78)
                    .frame(maxHeight: .infinity)
                    .background(Color.red)
            }

            HStack(spacing: 0) {
                NavigationLink(destination: DeckDetailView(deck: deck)) {
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(Color(hex: deck.colorHex))
                            .frame(width: 7)

                        VStack(alignment: .leading, spacing: 7) {
                            HStack {
                                Text(deck.name)
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                Spacer()
                                Text("\(deck.cards.count) cards")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.76))
                            }

                            HStack(spacing: 6) {
                                Image(systemName: iconForType(deck.deckType))
                                Text(deck.deckType)
                                if isTargeted {
                                    Text("• Active")
                                        .foregroundStyle(LearnAlertStyle.sky)
                                }
                            }
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white.opacity(0.78))
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 17)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button(action: schedule) {
                    Image(systemName: isTargeted ? "bell.badge.fill" : "bell.badge")
                        .font(.title3.bold())
                        .foregroundStyle(isTargeted ? LearnAlertStyle.sky : .white)
                        .frame(width: 62)
                        .frame(maxHeight: .infinity)
                        .background(Color.black.opacity(0.16))
                }
                .accessibilityLabel(isTargeted ? "Deck alerts active" : "Quick schedule \(deck.name)")
            }
            .background(
                LinearGradient(
                    colors: [LearnAlertStyle.indigo, LearnAlertStyle.indigoDeep],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .offset(x: swipeOffset)
            .gesture(
                DragGesture(minimumDistance: 18)
                    .onChanged { value in
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                        swipeOffset = min(0, max(-78, value.translation.width))
                    }
                    .onEnded { value in
                        withAnimation(.snappy) {
                            swipeOffset = value.translation.width < -38 ? -78 : 0
                        }
                    }
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isTargeted ? LearnAlertStyle.sky : Color.white.opacity(0.14), lineWidth: isTargeted ? 2 : 1)
        )
        .shadow(color: LearnAlertStyle.indigo.opacity(0.18), radius: 12, y: 7)
    }

    private func iconForType(_ type: String) -> String {
        switch type {
        case "Quiz": return "checkmark.rectangle.stack.fill"
        case "Vocabulary": return "text.book.closed.fill"
        case "True / False": return "switch.2"
        default: return "rectangle.stack.fill"
        }
    }
}

private struct ImportedDeckPayload: Decodable {
    let name: String
    let colorHex: String?
    let cards: [ImportedCardPayload]
}

private struct ImportedCardPayload: Decodable {
    let question: String
    let correctAnswer: String
    let options: [String]?
    let hint: String?
}

private struct ParsedDeckFile {
    let name: String
    let colorHex: String
    let cards: [ParsedCardFile]
}

private struct ParsedCardFile {
    let question: String
    let correctAnswer: String
    let options: [String]
    let hint: String
}

private enum DeckFileImport {
    static func parse(data: Data, fallbackName: String) throws -> ParsedDeckFile {
        if let payload = try? JSONDecoder().decode(ImportedDeckPayload.self, from: data) {
            let cards = payload.cards.map {
                ParsedCardFile(
                    question: $0.question,
                    correctAnswer: $0.correctAnswer,
                    options: normalizedOptions(correct: $0.correctAnswer, options: $0.options ?? []),
                    hint: $0.hint ?? ""
                )
            }
            guard !cards.isEmpty else { throw CocoaError(.fileReadCorruptFile) }
            return ParsedDeckFile(name: payload.name, colorHex: payload.colorHex ?? "#5568C9", cards: cards)
        }

        guard let text = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
        let rows = text.split(whereSeparator: \.isNewline).map(String.init)
        let cards = rows.enumerated().compactMap { index, row -> ParsedCardFile? in
            let separator: Character = row.contains("\t") ? "\t" : ","
            let columns = row.split(separator: separator, omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            guard columns.count >= 2 else { return nil }
            if index == 0, columns[0].localizedCaseInsensitiveContains("question") { return nil }
            let question = columns[0]
            let correct = columns[1]
            guard !question.isEmpty, !correct.isEmpty else { return nil }
            let alternatives = columns.count > 2 ? Array(columns[2...].prefix(3)) : []
            return ParsedCardFile(
                question: question,
                correctAnswer: correct,
                options: normalizedOptions(correct: correct, options: alternatives),
                hint: ""
            )
        }
        guard !cards.isEmpty else { throw CocoaError(.fileReadCorruptFile) }
        return ParsedDeckFile(name: fallbackName.isEmpty ? "Imported Deck" : fallbackName, colorHex: "#5568C9", cards: cards)
    }

    private static func normalizedOptions(correct: String, options: [String]) -> [String] {
        var result = [correct]
        for option in options where !option.isEmpty && !result.contains(option) {
            result.append(option)
        }
        return result
    }
}

struct DeckDropDelegate: DropDelegate {
    let item: Deck; var decks: [Deck]; @Binding var draggedItem: Deck?; let context: ModelContext
    func performDrop(info: DropInfo) -> Bool { draggedItem = nil; return true }
    func dropEntered(info: DropInfo) {
        guard let draggedItem, draggedItem.id != item.id else { return }
        guard let from = decks.firstIndex(of: draggedItem), let to = decks.firstIndex(of: item) else { return }
        var updatedDecks = decks
        updatedDecks.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        for (index, deck) in updatedDecks.enumerated() { deck.orderIndex = index }
        try? context.save()
    }
}

// MARK: - Tab 3: Premade Decks


// MARK: - Tab 4: App Settings View (Added Theme Engine)
struct AppSettingsView: View {
    @State private var permissionStatus: UNAuthorizationStatus = .notDetermined
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @AppStorage("alertSound") private var alertSound = "alert3.wav"
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    @AppStorage("deckCreaturesHaveFaces") private var deckCreaturesHaveFaces = false

    private let availableSounds = AlertSoundOption.allSounds
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                AppSectionHeader(
                    title: "Settings",
                    subtitle: "Personalize LearnAlert alerts and preferences."
                )

                SettingsPreferencesGroup(
                    alertSound: $alertSound,
                    availableSounds: availableSounds,
                    appearanceMode: $appearanceMode,
                    deckCreaturesHaveFaces: $deckCreaturesHaveFaces
                )

                SettingsSupportGroup()
                
                Spacer().frame(height: 120)
            }
            .padding(.top, 22)
        }
        .background {
            LearnAlertStyle.courseCanvas
                .ignoresSafeArea()
        }
        .task { await refreshPermissionStatus() }
        .onAppear {
            if !availableSounds.contains(where: { $0.id == alertSound }) {
                alertSound = "alert3.wav"
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await refreshPermissionStatus() }
        }
        .onChange(of: alertSound) { _, newValue in
            previewAlertSound(named: newValue)
        }
        .onDisappear {
            InteractionSoundPlayer.shared.stopPreview()
        }
    }

    @MainActor
    private func refreshPermissionStatus() async {
        permissionStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    private func openSystemSettings() {
        guard let settingsURL = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
        openURL(settingsURL)
    }

    private func previewAlertSound(named soundName: String) {
        guard soundName != "Default" else {
            AudioServicesPlaySystemSound(1007)
            return
        }
        InteractionSoundPlayer.shared.previewSound(named: soundName)
    }

}

struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}

private struct SystemCheckItem: Identifiable, Sendable {
    enum State: Sendable {
        case good
        case warning
        case unavailable
    }

    let id = UUID()
    let title: String
    let detail: String
    let state: State
}

private struct SystemCheckView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var decks: [Deck]
    @State private var items: [SystemCheckItem] = []
    @State private var isRunning = true

    var body: some View {
        NavigationStack {
            ZStack {
                CoursezyBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if isRunning {
                            HStack(spacing: 12) {
                                ProgressView()
                                Text("Checking LearnAlert…")
                                    .font(.custom("Poppins-Medium", size: 14, relativeTo: .body))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .coursezyCard()
                        }

                        ForEach(items) { item in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: icon(for: item.state))
                                    .foregroundStyle(color(for: item.state))
                                    .font(.title3)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.title)
                                        .font(.custom("Poppins-SemiBold", size: 14, relativeTo: .headline))
                                        .foregroundStyle(LearnAlertStyle.textPrimary)
                                    Text(item.detail)
                                        .font(.custom("Poppins-Regular", size: 11, relativeTo: .caption))
                                        .foregroundStyle(LearnAlertStyle.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer()
                            }
                            .coursezyCard(cornerRadius: 16, padding: 14)
                        }

                        Button {
                            Task { await runChecks() }
                        } label: {
                            Label("Run Again", systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(LearnAlertButtonStyle(kind: .outline, size: .medium, color: LearnAlertStyle.indigo, expands: true))
                        .disabled(isRunning)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("System Check")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await runChecks() }
        }
    }

    @MainActor
    private func runChecks() async {
        isRunning = true
        items = []

        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        let requests = await center.pendingNotificationRequests()
        let authorizationText: String
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: authorizationText = "Notifications are allowed"
        case .denied: authorizationText = "Notifications are disabled in System Settings"
        case .notDetermined: authorizationText = "Notification permission has not been requested"
        @unknown default: authorizationText = "Notification authorization is unknown"
        }

        items.append(SystemCheckItem(
            title: "Notification permission",
            detail: authorizationText,
            state: settings.authorizationStatus == .denied ? .warning : .good
        ))
        items.append(SystemCheckItem(
            title: "Scheduled notifications",
            detail: requests.isEmpty ? "No notifications are currently pending" : "\(requests.count) notifications are pending delivery",
            state: requests.isEmpty ? .warning : .good
        ))

        let cardCount = decks.reduce(0) { $0 + $1.cards.count }
        let reviewedCount = decks.flatMap(\.cards).filter { $0.reviewCount > 0 }.count
        items.append(SystemCheckItem(
            title: "Local library",
            detail: "\(decks.count) decks · \(cardCount) cards · \(reviewedCount) cards studied",
            state: decks.isEmpty ? .warning : .good
        ))
        items.append(SystemCheckItem(
            title: "Storage & Sync",
            detail: "SwiftData local database with background iCloud sync",
            state: .good
        ))

        let endpointResults = await checkAPIEndpoints()
        let reachableCount = endpointResults.filter(\.reachable).count
        items.append(SystemCheckItem(
            title: "LearnAlert API",
            detail: "\(reachableCount) of \(endpointResults.count) routes reachable",
            state: reachableCount == endpointResults.count ? .good : .warning
        ))
        for endpoint in endpointResults {
            items.append(SystemCheckItem(
                title: endpoint.name,
                detail: endpoint.detail,
                state: endpoint.reachable ? .good : .warning
            ))
        }

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        items.append(SystemCheckItem(
            title: "App environment",
            detail: "LearnAlert \(version) · iOS \(UIDevice.current.systemVersion) · \(ProcessInfo.processInfo.isLowPowerModeEnabled ? "Low Power Mode on" : "Low Power Mode off")",
            state: .good
        ))
        isRunning = false
    }

    private func checkAPIEndpoints() async -> [(name: String, detail: String, reachable: Bool)] {
        let endpoints = [
            ("API host", ""),
            ("Generate deck endpoint", "v1/decks/generate"),
            ("Refine deck endpoint", "v1/decks/refine")
        ]
        let apiKey = LearnAlertAPI.apiKey
        return await withTaskGroup(of: (Int, String, String, Bool).self) { group in
            for (index, endpoint) in endpoints.enumerated() {
                group.addTask {
                    let baseURL = URL(string: "https://api.learnalertapp.com")!
                    let url = endpoint.1.isEmpty ? baseURL : baseURL.appending(path: endpoint.1)
                    var request = URLRequest(url: url, timeoutInterval: 8)
                    request.httpMethod = "HEAD"
                    if let key = apiKey {
                        request.setValue(key, forHTTPHeaderField: "X-API-Key")
                    }
                    do {
                        let (_, response) = try await URLSession.shared.data(for: request)
                        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                        let reachable = (200..<500).contains(status)
                        return (index, endpoint.0, "HTTP \(status) · host responded", reachable)
                    } catch {
                        return (index, endpoint.0, error.localizedDescription, false)
                    }
                }
            }
            var results: [(Int, String, String, Bool)] = []
            for await result in group { results.append(result) }
            return results.sorted { $0.0 < $1.0 }.map { (name: $0.1, detail: $0.2, reachable: $0.3) }
        }
    }

    private func icon(for state: SystemCheckItem.State) -> String {
        switch state {
        case .good: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .unavailable: "clock.badge.questionmark"
        }
    }

    private func color(for state: SystemCheckItem.State) -> Color {
        switch state {
        case .good: LearnAlertStyle.aqua
        case .warning: .orange
        case .unavailable: LearnAlertStyle.textSecondary
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0; Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue:  Double(b) / 255, opacity: Double(a) / 255)
    }
    func toHex() -> String? {
        let uic = UIColor(self); guard let components = uic.cgColor.components, components.count >= 3 else { return nil }
        let r = Float(components[0]); let g = Float(components[1]); let b = Float(components[2])
        return String(format: "#%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
    }
}


// MARK: - Quick Schedule Tip Popup
private struct QuickScheduleTipPopup: View {
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 13) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(LearnAlertStyle.aqua)
                .frame(width: 40, height: 40)
                .background(Color.white.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text("Quick Switch Active")
                    .font(.custom("Poppins-SemiBold", size: 14, relativeTo: .subheadline))
                    .foregroundStyle(.white)

                Text("You can easily switch active alert decks anytime just by tapping this bell button—no need to reschedule!")
                    .font(.custom("Poppins-Regular", size: 11, relativeTo: .caption))
                    .foregroundStyle(.white.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 4)

            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 26, height: 26)
                    .background(Color.white.opacity(0.16), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss quick switch tip")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            LinearGradient(
                colors: [LearnAlertStyle.indigo, LearnAlertStyle.indigoDeep],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.28), lineWidth: 1)
        )
        .shadow(color: LearnAlertStyle.indigoDeep.opacity(0.38), radius: 18, y: 8)
        .padding(.horizontal, 18)
    }
}
