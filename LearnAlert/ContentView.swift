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
    @State private var showingCreationActions = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
                    case 2: NotificationCustomizeView()
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
                .accessibilityHidden(showingCreationActions)

                if showingCreationActions {
                    Button {
                        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.44, dampingFraction: 0.72)) {
                            showingCreationActions = false
                        }
                    } label: {
                        Color.black.opacity(0.14).ignoresSafeArea()
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close new deck options")
                    .transition(.opacity)
                }

                VStack {
                    Spacer()
                    BottomNavigationBar(
                        selectedTab: $selectedTab,
                        tabDragOffset: $tabDragOffset,
                        showingCreationActions: $showingCreationActions,
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
            .navigationDestination(item: $notificationManager.pendingCourseHandoff) { handoff in
                if let course = CourseCurriculumCatalog.course(for: handoff.id) { CoursePathView(course: course, initialCheckpointSectionId: handoff.sectionId) }
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
        .tint(LearnAlertStyle.appAccentForeground)
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

                VStack(spacing: 12) {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.orange.opacity(0.15))
                                .frame(width: 40, height: 40)
                            Image(systemName: "hand.tap.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.orange)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("Tapping alert")
                                    .font(.custom("Poppins-SemiBold", size: 14))
                                    .foregroundStyle(LearnAlertStyle.textPrimary)
                                Text("Opens App")
                                    .font(.custom("Poppins-Medium", size: 10))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.15), in: Capsule())
                                    .foregroundStyle(.orange)
                            }
                            Text("Opens the full in-app study session.")
                                .font(.custom("Poppins-Regular", size: 12))
                                .foregroundStyle(LearnAlertStyle.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(LearnAlertStyle.courseSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    )

                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(LearnAlertStyle.indigo.opacity(0.18))
                                .frame(width: 40, height: 40)
                            Image(systemName: "hand.draw.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(LearnAlertStyle.sky)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("Swipe down / Press & Hold")
                                    .font(.custom("Poppins-SemiBold", size: 14))
                                    .foregroundStyle(LearnAlertStyle.textPrimary)
                                Text("Recommended")
                                    .font(.custom("Poppins-Medium", size: 10))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(LearnAlertStyle.indigo.opacity(0.18), in: Capsule())
                                    .foregroundStyle(LearnAlertStyle.sky)
                            }
                            Text("Expands the quiz card without opening the app!")
                                .font(.custom("Poppins-Regular", size: 12))
                                .foregroundStyle(LearnAlertStyle.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(LearnAlertStyle.courseSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(LearnAlertStyle.indigo.opacity(0.4), lineWidth: 1.2)
                    )
                }

                Button(action: dismiss) {
                    Text("Got It!")
                        .font(.custom("Poppins-SemiBold", size: 15))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(LearnAlertStyle.indigo)
                        .clipShape(Capsule())
                        .shadow(color: LearnAlertStyle.indigo.opacity(0.35), radius: 8, y: 4)
                }
            }
            .padding(20)
            .background(LearnAlertStyle.courseSurface)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(LearnAlertStyle.surfaceOutline(darkOpacity: 0.3), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.3), radius: 24, y: 12)
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - LearnAlert Custom Header
struct CoursezyHeaderView: View {
    @Binding var searchText: String
    @Binding var searchIsFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            LearnAlertLogoMark()

            Spacer()

            if searchIsFocused {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(LearnAlertStyle.textSecondary)
                        .font(.footnote)
                    TextField("Search decks...", text: $searchText)
                        .font(.custom("Poppins-Regular", size: 14, relativeTo: .body))
                        .foregroundStyle(LearnAlertStyle.textPrimary)
                    Button {
                        searchIsFocused = false
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(LearnAlertStyle.textSecondary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(LearnAlertStyle.courseSurface)
                .clipShape(Capsule())
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                Button {
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

// MARK: - Tab 1: Home Library
struct HomeLibraryView: View {
    @Query(sort: \Deck.orderIndex) private var allDecks: [Deck]
    @Environment(\.modelContext) private var context
    @ObservedObject private var sharedDB = SharedDatabase.shared
    @ObservedObject private var progressManager = CourseProgressManager.shared
    @ObservedObject private var engine = StudyEngine.shared
    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var draggedDeck: Deck?
    @State private var isSearchExpanded = false
    @State private var showingAIComposer = false
    @State private var showingAlertSettings = false
    @State private var showingDeckRequirementAlert = false
    @State private var showingNotificationPermissionPrompt = false
    @State private var pendingDeckToSchedule: Deck?
    @State private var pendingFromDeckCard = false
    @State private var scheduleCelebrationEvent: CelebrationEvent?
    @State private var deckPendingDeletion: Deck?
    @State private var homeAlertMessage: String?
    @State private var showingQuickScheduleTipToast = false
    @State private var showingPinnedReorderSheet = false
    @State private var selectedCourseStudy: HomeCourseStudySelection?
    @State private var selectedCourseForOverview: CourseDefinition?
    @State private var coursePendingUnenroll: CourseDefinition?

    @AppStorage("hasSeenQuickScheduleSwitchTip") private var hasSeenQuickScheduleSwitchTip = false
    @AppStorage("homeTutorialStep") private var homeTutorialStep: Int = 0
    @AppStorage("tutorialDeckId") private var tutorialDeckId: String = ""
    @AppStorage("targetDeckId") private var targetDeckId: String = "ALL"
    @State private var liveTutorialStartTime: TimeInterval = 0

    @Binding var searchText: String
    @Binding var selectedTab: Int
    @Binding var showingCreateDeck: Bool

    struct CelebrationEvent: Equatable {
        let id = UUID()
        let timestamp = Date()
    }

    private var ordinaryDecks: [Deck] {
        allDecks.filter { $0.deckType != "Course" }
    }

    private var enrolledCourses: [CourseDefinition] {
        progressManager.allEnrolledCourses
    }

    private enum HomeLibraryItem: Identifiable, Equatable {
        case course(CourseDefinition)
        case deck(Deck)

        var id: String {
            switch self {
            case .course(let course): return "course:\(course.id)"
            case .deck(let deck): return "deck:\(deck.id.uuidString)"
            }
        }
    }

    private var pinnedItems: [HomeLibraryItem] {
        progressManager.pinnedItemIds.compactMap { itemId -> HomeLibraryItem? in
            if itemId.hasPrefix("course:") {
                let courseId = String(itemId.dropFirst("course:".count))
                if let course = enrolledCourses.first(where: { $0.id == courseId }) {
                    return .course(course)
                }
            } else if itemId.hasPrefix("deck:") {
                let deckId = String(itemId.dropFirst("deck:".count))
                if let deck = ordinaryDecks.first(where: { $0.id.uuidString == deckId }) {
                    return .deck(deck)
                }
            }
            return nil
        }
    }

    private var unpinnedCourses: [CourseDefinition] {
        let list = enrolledCourses.filter { !progressManager.isCoursePinned(courseId: $0.id) }
        if searchText.isEmpty { return list }
        return list.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.language.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var unpinnedDecks: [Deck] {
        let list = ordinaryDecks.filter { !progressManager.isDeckPinned(deckId: $0.id) }
        var result = searchText.isEmpty ? list : list.filter { $0.name.localizedCaseInsensitiveContains(searchText) }

        if homeTutorialStep > 0, let tutDeck = activeTutorialDeck {
            if let index = result.firstIndex(where: { $0.id == tutDeck.id }) {
                let deck = result.remove(at: index)
                result.insert(deck, at: 0)
            }
        }
        return result
    }

    private var activeTutorialDeck: Deck? {
        if !tutorialDeckId.isEmpty, let deck = ordinaryDecks.first(where: { $0.id.uuidString == tutorialDeckId }) {
            return deck
        }
        if !targetDeckId.isEmpty && targetDeckId != "ALL", let deck = ordinaryDecks.first(where: { $0.id.uuidString == targetDeckId }) {
            return deck
        }
        return ordinaryDecks.first
    }

    @ViewBuilder
    private var storageNoticeView: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.orange)
                .font(.system(size: 16))
            VStack(alignment: .leading, spacing: 2) {
                Text("Storage Notice")
                    .font(.custom("Poppins-SemiBold", size: 13))
                    .foregroundStyle(.white)
                Text(sharedDB.storageErrorMessage ?? "Running in temporary memory mode. Flashcards may not persist between app restarts.")
                    .font(.custom("Poppins-Regular", size: 11))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(12)
        .background(Color.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 2)
    }

    @ViewBuilder
    private var headerBarView: some View {
        let layout = dynamicTypeSize.isAccessibilitySize && !isSearchExpanded
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
            : AnyLayout(HStackLayout(spacing: 12))
        layout {
            if !isSearchExpanded {
                HStack(spacing: 8) {
                    LearnAlertLogoMark()
                    Text("Home")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(LearnAlertStyle.textPrimary)
                }
            }

            if !dynamicTypeSize.isAccessibilitySize && !isSearchExpanded { Spacer() }

            HStack(spacing: 12) {
                if homeTutorialStep > 0 {
                    Button {
                        withAnimation(.snappy) {
                            homeTutorialStep = 0
                        }
                    } label: {
                        Text("Skip Tour")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(LearnAlertStyle.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                } else {
                    if isSearchExpanded {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(LearnAlertStyle.textSecondary)
                            TextField("Search your decks", text: $searchText)
                                .font(.body)
                                .foregroundStyle(LearnAlertStyle.textPrimary)
                                .submitLabel(.search)
                        }
                        .padding(.horizontal, 14)
                        .frame(minHeight: 48)
                        .background(LearnAlertStyle.insetSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    } else {
                        NavigationLink {
                            ProgressDashboardView()
                        } label: {
                            Image(systemName: "chart.bar.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(LearnAlertStyle.textPrimary)
                                .frame(width: 44, height: 44)
                                .appCardSurface(cornerRadius: 14)
                        }
                        .accessibilityLabel("View progress statistics")
                    }

                    Button {
                        withAnimation(.snappy) {
                            isSearchExpanded.toggle()
                            if !isSearchExpanded { searchText = "" }
                        }
                    } label: {
                        Image(systemName: isSearchExpanded ? "xmark" : "magnifyingglass")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(LearnAlertStyle.textPrimary)
                            .frame(width: 44, height: 44)
                            .appCardSurface(cornerRadius: 14)
                    }
                    .accessibilityLabel(isSearchExpanded ? "Close deck search" : "Search decks")
                }
            }
            .frame(maxWidth: dynamicTypeSize.isAccessibilitySize || isSearchExpanded ? .infinity : nil, alignment: .trailing)
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var alertSetupSection: some View {
        HomeAlertSetupCard(
            decks: ordinaryDecks,
            engine: engine,
            targetDeckId: $targetDeckId,
            homeTutorialStep: homeTutorialStep,
            showSettings: { showingAlertSettings = true },
            showDeckRequirement: {
                withAnimation(.snappy) { showingDeckRequirementAlert = true }
            },
            schedule: { quickSchedule($0, fromDeckCard: false) }
        )
        .padding(.horizontal, 20)
        .opacity((homeTutorialStep == 1 || homeTutorialStep == 4) ? 0.20 : 1.0)
        .blur(radius: (homeTutorialStep == 1 || homeTutorialStep == 4) ? 2.0 : 0)
        .allowsHitTesting(homeTutorialStep == 0 || homeTutorialStep == 3)
    }

    @ViewBuilder
    private var pinnedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Pinned")
                    .font(.headline)
                    .foregroundStyle(LearnAlertStyle.textPrimary)

                Spacer()

                if pinnedItems.count > 1 {
                    Button {
                        showingPinnedReorderSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Reorder")
                                .font(.custom("Poppins-Medium", size: 12))
                        }
                        .foregroundStyle(LearnAlertStyle.appAccentForeground)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)

            LazyVStack(spacing: 12) {
                ForEach(pinnedItems) { item in
                    switch item {
                    case .course(let course):
                        let isTargeted = engine.isActive && engine.activeDeckId?.uuidString == progressManager.enrollment(for: course.id)?.linkedDeckId
                        HomeCourseCard(
                            course: course,
                            isPinned: true,
                            isTargeted: isTargeted,
                            onContinue: {
                                resumeCourse(course)
                            },
                            onOpenOverview: {
                                selectedCourseForOverview = course
                            },
                            schedule: {
                                scheduleCourse(course)
                            },
                            togglePin: {
                                progressManager.togglePin(id: "course:\(course.id)")
                            },
                            unenroll: {
                                coursePendingUnenroll = course
                            }
                        )
                    case .deck(let deck):
                        let isTargeted = engine.isActive && (targetDeckId == "ALL" || targetDeckId == deck.id.uuidString)
                        HomeStudyCard(
                            deck: deck,
                            isPinned: true,
                            isTargeted: isTargeted,
                            isTutorialHighlighted: false,
                            isTutorialActive: homeTutorialStep > 0,
                            onTapped: nil,
                            schedule: { quickSchedule(deck, fromDeckCard: true) },
                            togglePin: { progressManager.togglePin(id: "deck:\(deck.id.uuidString)") },
                            shuffleAppearance: { shuffleAppearance(for: deck) },
                            delete: { deckPendingDeletion = deck }
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    @ViewBuilder
    private var librarySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Your library")
                    .font(.headline)
                    .foregroundStyle(LearnAlertStyle.textPrimary)
                Spacer()
                let totalCount = unpinnedCourses.count + unpinnedDecks.count
                Text("\(totalCount) \(totalCount == 1 ? "item" : "items")")
                    .font(.subheadline)
                    .foregroundStyle(LearnAlertStyle.textSecondary)
            }
            .padding(.horizontal, 20)

            if unpinnedCourses.isEmpty && unpinnedDecks.isEmpty && pinnedItems.isEmpty {
                EmptyLibraryCard(
                    isSearching: !searchText.isEmpty,
                    onCreateDeck: { showingCreateDeck = true },
                    onBrowseDiscover: { selectedTab = 1 }
                )
                .padding(.horizontal, 20)
            } else {
                LazyVStack(spacing: 12) {
                    // Unpinned Courses
                    ForEach(unpinnedCourses) { course in
                        let isTargeted = engine.isActive && engine.activeDeckId?.uuidString == progressManager.enrollment(for: course.id)?.linkedDeckId
                        HomeCourseCard(
                            course: course,
                            isPinned: false,
                            isTargeted: isTargeted,
                            onContinue: {
                                resumeCourse(course)
                            },
                            onOpenOverview: {
                                selectedCourseForOverview = course
                            },
                            schedule: {
                                scheduleCourse(course)
                            },
                            togglePin: {
                                progressManager.togglePin(id: "course:\(course.id)")
                            },
                            unenroll: {
                                coursePendingUnenroll = course
                            }
                        )
                    }

                    // Unpinned Decks
                    ForEach(unpinnedDecks) { deck in
                        let isTargeted = engine.isActive && (targetDeckId == "ALL" || targetDeckId == deck.id.uuidString)
                        let isHighlightedInTour = homeTutorialStep == 1 && (deck.id == activeTutorialDeck?.id)
                        let isOtherDeckInStep1 = homeTutorialStep == 1 && !isHighlightedInTour

                        HomeStudyCard(
                            deck: deck,
                            isPinned: false,
                            isTargeted: isTargeted,
                            isTutorialHighlighted: isHighlightedInTour,
                            isTutorialActive: homeTutorialStep > 0,
                            onTapped: {
                                if homeTutorialStep == 1 && isHighlightedInTour {
                                    homeTutorialStep = 2
                                }
                            },
                            schedule: { quickSchedule(deck, fromDeckCard: true) },
                            togglePin: { progressManager.togglePin(id: "deck:\(deck.id.uuidString)") },
                            shuffleAppearance: { shuffleAppearance(for: deck) },
                            delete: { deckPendingDeletion = deck }
                        )
                        .opacity(isOtherDeckInStep1 ? 0.18 : 1.0)
                        .blur(radius: isOtherDeckInStep1 ? 2.0 : 0)
                        .allowsHitTesting(homeTutorialStep == 0 || isHighlightedInTour)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .opacity((homeTutorialStep == 3 || homeTutorialStep == 4) ? 0.18 : 1.0)
        .blur(radius: (homeTutorialStep == 3 || homeTutorialStep == 4) ? 2.5 : 0)
        .allowsHitTesting(homeTutorialStep == 0 || homeTutorialStep == 1)
    }

    @ViewBuilder
    private var tourOverlays: some View {
        if homeTutorialStep == 4 {
            VStack(spacing: 16) {
                Spacer()

                HandDrawnUpwardArrowView()

                LiveTestAlertFloatingBanner(
                    deckName: ordinaryDecks.first(where: { $0.id.uuidString == targetDeckId })?.name ?? "Starter Deck",
                    onResend: {
                        sendTutorialTestAlert()
                    },
                    onComplete: {
                        HapticFeedback.success()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                            homeTutorialStep = 5
                        }
                    },
                    onDismiss: {
                        withAnimation(.snappy) {
                            homeTutorialStep = 0
                        }
                    }
                )
                .padding(.horizontal, 20)

                Spacer()
            }
            .transition(.scale(scale: 0.94).combined(with: .opacity))
            .zIndex(30)
        }

        if homeTutorialStep == 5 {
            VStack {
                TutorialCompletedBanner {
                    withAnimation(.snappy) {
                        homeTutorialStep = 0
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                Spacer()
            }
            .transition(.move(edge: .top).combined(with: .opacity))
            .zIndex(30)
            .task {
                try? await Task.sleep(nanoseconds: 3_500_000_000)
                withAnimation(.snappy) {
                    if homeTutorialStep == 5 {
                        homeTutorialStep = 0
                    }
                }
            }
        }

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
                .padding(.bottom, 120)
            }
            .transition(.asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .move(edge: .bottom).combined(with: .opacity)
            ))
            .zIndex(25)
        }

        if showingNotificationPermissionPrompt {
            NotificationPermissionPromptModal(
                targetDeckName: pendingDeckToSchedule?.name ?? "your deck",
                onAllow: {
                    withAnimation(.snappy) {
                        showingNotificationPermissionPrompt = false
                    }
                    if let deck = pendingDeckToSchedule {
                        applySchedule(for: deck, fromDeckCard: pendingFromDeckCard)
                        pendingDeckToSchedule = nil
                    }
                },
                onStudyInAppOnly: {
                    withAnimation(.snappy) {
                        showingNotificationPermissionPrompt = false
                    }
                    pendingDeckToSchedule = nil
                    if homeTutorialStep == 3 {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                            homeTutorialStep = 0
                        }
                    }
                },
                onOpenSettings: {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
            )
            .transition(.opacity)
            .zIndex(40)
        }
    }

    var body: some View {
        ZStack {
            HomeWallpaperBackground()

            ScheduleLightBurst(event: scheduleCelebrationEvent)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if sharedDB.isUsingTemporaryStorage {
                        storageNoticeView
                    }

                    headerBarView

                    alertSetupSection

                    if !pinnedItems.isEmpty {
                        pinnedSection
                    }

                    librarySection

                    Spacer().frame(height: 210)
                }
                .padding(.top, 22)
            }
            .blur(radius: showingDeckRequirementAlert ? 3 : 0)
            .animation(.easeInOut(duration: 0.25), value: showingDeckRequirementAlert)

            tourOverlays
        }
        .task(id: homeTutorialStep) {
            guard homeTutorialStep == 4 else { return }
            let defaults = UserDefaults(suiteName: "group.com.learnalert.shared")
            defaults?.set(false, forKey: "lastNotificationWasGraded")

            while homeTutorialStep == 4 && !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000)
                defaults?.synchronize()
                let wasGraded = defaults?.bool(forKey: "lastNotificationWasGraded") ?? false
                let answeredTime = defaults?.double(forKey: "lastNotificationAnsweredTimestamp") ?? 0

                if wasGraded && answeredTime >= (liveTutorialStartTime - 1.5) {
                    HapticFeedback.success()
                    defaults?.set(false, forKey: "lastNotificationWasGraded")
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        homeTutorialStep = 5
                    }
                    break
                }
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
        .sheet(isPresented: $showingPinnedReorderSheet) {
            PinnedReorderSheet(
                progressManager: progressManager,
                enrolledCourses: enrolledCourses,
                decks: ordinaryDecks
            )
        }
        .sheet(item: $selectedCourseForOverview) { course in
            NavigationStack {
                CourseOverviewView(course: course)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { selectedCourseForOverview = nil }
                        }
                    }
            }
        }
        .fullScreenCover(item: $selectedCourseStudy) { selection in
            CourseLessonStudyView(course: selection.course, lesson: selection.lesson,
                onDismiss: { selectedCourseStudy = nil })
        }
        .confirmationDialog(
            "Unenroll from \(coursePendingUnenroll?.title ?? "this course")?",
            isPresented: Binding(
                get: { coursePendingUnenroll != nil },
                set: { if !$0 { coursePendingUnenroll = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Unenroll", role: .destructive) {
                if let course = coursePendingUnenroll {
                    progressManager.unenroll(courseId: course.id)
                    coursePendingUnenroll = nil
                }
            }
            Button("Cancel", role: .cancel) { coursePendingUnenroll = nil }
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
    }

    private func resumeCourse(_ course: CourseDefinition) {
        if let current = progressManager.currentLesson(for: course) {
            selectedCourseStudy = HomeCourseStudySelection(course: course, lesson: current)
        } else {
            selectedCourseForOverview = course
        }
    }

    private func scheduleCourse(_ course: CourseDefinition) {
        let deck = progressManager.createOrSyncCourseDeck(for: course, in: context)
        quickSchedule(deck, fromDeckCard: true)
    }

    private func sendTutorialTestAlert() {
        guard let deck = ordinaryDecks.first(where: { $0.id.uuidString == targetDeckId }) ?? ordinaryDecks.first,
              let card = deck.cards.first else { return }

        liveTutorialStartTime = Date().timeIntervalSince1970
        NotificationManager.shared.scheduleTutorialAlert(
            deckTitle: deck.name,
            question: card.question,
            options: card.options,
            correctAnswer: card.correctAnswer,
            hint: card.hint,
            cardId: card.id,
            deckId: deck.id,
            delay: 0.6
        )
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
            case .notDetermined, .denied:
                // Halt actual notifications until permission is allowed!
                pendingDeckToSchedule = deck
                pendingFromDeckCard = fromDeckCard
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showingNotificationPermissionPrompt = true
                }
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

        if homeTutorialStep == 3 {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                homeTutorialStep = 4
            }
            sendTutorialTestAlert()
            return
        }

        Task { @MainActor in
            do {
                _ = try await engine.startAlerts(for: deck)
                InteractionSoundPlayer.shared.play(.scheduledAlerts)
                HapticFeedback.success()
                scheduleCelebrationEvent = CelebrationEvent()

                if fromDeckCard && !hasSeenQuickScheduleSwitchTip {
                    hasSeenQuickScheduleSwitchTip = true
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                        showingQuickScheduleTipToast = true
                    }
                }
            } catch {
                HapticFeedback.warning()
                homeAlertMessage = error.localizedDescription
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
        guard let deck = ordinaryDecks.first(where: { $0.name == engine.activeDeckName }) else { return 0 }
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
                    .foregroundStyle(LearnAlertStyle.appAccentInk)
                    .background(LearnAlertStyle.appAccent)
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
    let event: HomeLibraryView.CelebrationEvent?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var celebrationStart: Date?
    @State private var handledEventId: UUID?

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

                        if localTime < launchDuration {
                            let launchProgress = CGFloat(localTime / launchDuration)
                            let eased = 1 - pow(1 - launchProgress, 2.2)
                            let start = CGPoint(x: firework.launchX, y: size.height + 20)
                            let head = CGPoint(
                                x: start.x + (firework.burst.x - start.x) * eased + sin(launchProgress * CGFloat.pi) * CGFloat(fireworkIndex - 1) * 10,
                                y: start.y + (firework.burst.y - start.y) * eased
                            )

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

                            context.fill(Path(ellipseIn: CGRect(x: head.x - 7, y: head.y - 7, width: 14, height: 14)), with: .color(firework.color.opacity(0.35)))
                            context.fill(Path(ellipseIn: CGRect(x: head.x - 3, y: head.y - 3, width: 6, height: 6)), with: .color(Color.white))
                            continue
                        }

                        let burstTime = localTime - launchDuration
                        guard burstTime < burstDuration else { continue }

                        let burstProgress = CGFloat(burstTime / burstDuration)
                        let fade = pow(max(0, 1.0 - burstProgress), 1.5)
                        let shrink = max(0.0, 1.0 - burstProgress * 0.88)
                        let gravity = 190.0 * pow(burstProgress, 1.65)
                        let dragDecay = 1.0 - exp(-CGFloat(burstTime) * 2.8)

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

                            let flicker = 0.72 + 0.28 * sin(CGFloat(particleIndex * 17) + CGFloat(burstTime * 22))
                            let particleAlpha = Double(fade * flicker)

                            var trail = Path()
                            trail.move(to: previous)
                            trail.addLine(to: position)
                            context.stroke(
                                trail,
                                with: .color(firework.color.opacity(particleAlpha * 0.55)),
                                lineWidth: max(0.8, 1.8 * shrink)
                            )

                            let coreSize = max(1.0, 3.8 * shrink)
                            context.fill(
                                Path(ellipseIn: CGRect(x: position.x - coreSize/2, y: position.y - coreSize/2, width: coreSize, height: coreSize)),
                                with: .color(firework.color.opacity(particleAlpha))
                            )

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
        .onAppear {
            handledEventId = event?.id
        }
        .onDisappear {
            celebrationStart = nil
        }
        .onChange(of: event) { _, newEvent in
            guard let newEvent, newEvent.id != handledEventId else { return }
            handledEventId = newEvent.id
            guard abs(newEvent.timestamp.timeIntervalSinceNow) < 1.5 else { return }
            celebrationStart = .now
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(reduceMotion ? 800 : 3_200))
                celebrationStart = nil
            }
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
    var homeTutorialStep: Int = 0
    let showSettings: () -> Void
    let showDeckRequirement: () -> Void
    let schedule: (Deck) -> Void
    @State private var pulseScheduleButton = false

    private var selectedDeck: Deck? {
        if let deck = decks.first(where: { $0.id.uuidString == targetDeckId && $0.cards.count >= 2 }) {
            return deck
        }
        return schedulableDecks.first
    }

    private var schedulableDecks: [Deck] {
        decks.filter { $0.cards.count >= 2 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if homeTutorialStep == 3 {
                HStack(spacing: 6) {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text("Step 3 of 3: Tap Schedule Alerts to try a live alert")
                        .font(.custom("Poppins-SemiBold", size: 11))
                    Image(systemName: "arrow.down")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(LearnAlertStyle.appAccentInk)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(LearnAlertStyle.appAccent, in: Capsule())
                .shadow(color: LearnAlertStyle.appAccent.opacity(0.6), radius: 6, y: 2)
                .transition(.opacity.combined(with: .scale))
            }

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
            .appCardSurface(cornerRadius: 20)
            .overlay {
                if homeTutorialStep == 3 {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(LearnAlertStyle.appAccent, lineWidth: 2)
                        .shadow(color: LearnAlertStyle.appAccent.opacity(0.5), radius: 10)
                }
            }
            .overlay(alignment: .topTrailing) {
                ScheduleStatusDot(isActive: engine.isActive)
                    .padding(16)
            }
        }
        .animation(.spring(response: 0.48, dampingFraction: 0.84), value: engine.isActive)
        .onAppear {
            if homeTutorialStep == 3 {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    pulseScheduleButton = true
                }
            }
        }
        .onChange(of: homeTutorialStep) { _, newStep in
            if newStep == 3 {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    pulseScheduleButton = true
                }
            }
        }
    }

    private var setupContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Alert Schedule")
                    .font(.headline)
                    .foregroundStyle(LearnAlertStyle.textPrimary)
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
                                targetDeckId = deck.id.uuidString
                            }
                        }
                    } label: {
                        DeckPickerLabel(selectedDeck: selectedDeck)
                    }
                    .disabled(homeTutorialStep == 3)
                }
            }
            .overlay { DeckSelectionHintBorder(isVisible: !schedulableDecks.isEmpty && selectedDeck == nil) }



            HStack(spacing: 10) {
                Button {
                    guard let selectedDeck else { return }
                    schedule(selectedDeck)
                } label: {
                    Label(homeTutorialStep == 3 ? "Try Test Alert" : "Schedule Alerts", systemImage: homeTutorialStep == 3 ? "sparkles" : "bell.badge.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 48)
                }
                .foregroundStyle(selectedDeck == nil ? LearnAlertStyle.textSecondary : LearnAlertStyle.appAccentInk)
                .background(selectedDeck == nil ? LearnAlertStyle.insetSurface : LearnAlertStyle.appAccent)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(homeTutorialStep == 3 ? LearnAlertStyle.appAccent : Color.clear, lineWidth: homeTutorialStep == 3 ? 2.5 : 0)
                        .shadow(color: homeTutorialStep == 3 ? LearnAlertStyle.appAccent.opacity(0.85) : Color.clear, radius: 8)
                )
                .lightModeOutline(cornerRadius: 12, opacity: selectedDeck == nil ? 0.65 : 1)
                .scaleEffect(homeTutorialStep == 3 && pulseScheduleButton ? 1.025 : 1.0)
                .disabled(selectedDeck == nil)

                Button(action: showSettings) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(LearnAlertStyle.textPrimary)
                        .frame(width: 48, height: 48)
                        .background(LearnAlertStyle.insetSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(LearnAlertStyle.cardBorder, lineWidth: 1)
                        }
                }
                .disabled(homeTutorialStep > 0)
                .opacity(homeTutorialStep > 0 ? 0.35 : 1.0)
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
                            .font(.headline)
                        Text(engine.activeDeckName)
                            .font(.subheadline)
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
                        .frame(minHeight: 48)
                }
                .foregroundStyle(LearnAlertStyle.appAccentForeground)
                .background(.clear)
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(LearnAlertStyle.cardBorder, lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Button(role: .destructive) {
                    HapticFeedback.impact(.medium)
                    withAnimation { engine.stopAlerts() }
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 48)
                }
                .foregroundStyle(LearnAlertStyle.destructiveRed)
                .background(LearnAlertStyle.destructiveRed.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .font(.subheadline.weight(.semibold))

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
                    .font(.subheadline.weight(.medium))
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(selectedDeck.map { "\($0.cards.count) cards" } ?? "Nothing selected")
                    .font(.caption)
                    .foregroundStyle(LearnAlertStyle.textSecondary)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(LearnAlertStyle.textSecondary)
        }
        .foregroundStyle(LearnAlertStyle.textPrimary)
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
        .background(LearnAlertStyle.insetSurface)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(LearnAlertStyle.cardBorder, lineWidth: 1)
        )
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
                    withAnimation(.easeInOut(duration: 1.2)) {
                        glowOpacity = 0.80
                    }
                    try? await Task.sleep(nanoseconds: 1_200_000_000)

                    withAnimation(.easeInOut(duration: 1.4)) {
                        glowOpacity = 0.15
                    }
                    try? await Task.sleep(nanoseconds: 1_400_000_000)

                    withAnimation(.easeInOut(duration: 0.8)) {
                        glowOpacity = 0.0
                    }
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
                    .foregroundStyle(LearnAlertStyle.appAccentForeground)
                    .frame(width: 54, height: 54)
                    .background(.ultraThinMaterial, in: Circle())

                VStack(spacing: 7) {
                    Text("You need a study-ready deck")
                        .font(.custom("Poppins-SemiBold", size: 17, relativeTo: .headline))
                        .foregroundStyle(LearnAlertStyle.textPrimary)
                        .multilineTextAlignment(.center)
                    Text("Create a deck with at least 2 cards, or pick one on Discover.")
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
                    .foregroundStyle(LearnAlertStyle.appAccentInk)
                    .background(LearnAlertStyle.appAccent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

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
                                    .foregroundStyle(LearnAlertStyle.appAccentInk)
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
                            colors: [LearnAlertStyle.aqua, LearnAlertStyle.appAccent],
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
                                : (date <= currentDate ? LearnAlertStyle.appAccent : LearnAlertStyle.textSecondary.opacity(0.45))
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
    var isPinned: Bool = false
    let isTargeted: Bool
    var isTutorialHighlighted: Bool = false
    var isTutorialActive: Bool = false
    var onTapped: (() -> Void)? = nil
    let schedule: () -> Void
    var togglePin: (() -> Void)? = nil
    let shuffleAppearance: () -> Void
    let delete: () -> Void
    @State private var pulseGlow = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isTutorialHighlighted {
                HStack(spacing: 6) {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text("Step 1 of 3: Tap here to explore flashcards")
                        .font(.custom("Poppins-SemiBold", size: 11))
                    Image(systemName: "arrow.down")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(LearnAlertStyle.appAccentInk)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(LearnAlertStyle.appAccent, in: Capsule())
                .shadow(color: LearnAlertStyle.appAccent.opacity(0.6), radius: 6, y: 2)
                .scaleEffect(pulseGlow ? 1.03 : 0.98)
                .transition(.opacity.combined(with: .scale))
            }

            ZStack(alignment: .topTrailing) {
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
                                    .font(.headline)
                                    .foregroundStyle(LearnAlertStyle.textPrimary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)

                                Text("\(deck.deckType) · \(deck.cards.count) cards")
                                    .font(.subheadline)
                                    .foregroundStyle(LearnAlertStyle.textSecondary)

                                Spacer(minLength: 0)

                                HStack(spacing: 6) {
                                    if deck.cycleStreak > 0 {
                                        HStack(spacing: 2) {
                                            Text("🔥")
                                                .font(.system(size: 11))
                                            Text("\(deck.cycleStreak)")
                                                .font(.caption.weight(.semibold))
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
                                .font(.caption.weight(.medium))
                            }
                            .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(TapGesture().onEnded {
                        onTapped?()
                    })
                    .accessibilityLabel("Open \(deck.name), \(deck.cards.count) cards")

                    Button(action: {
                        if !isTutorialActive {
                            schedule()
                        }
                    }) {
                        Image(systemName: isTargeted ? "bell.badge.fill" : "bell.badge")
                            .foregroundStyle(isTargeted ? LearnAlertStyle.appAccentForeground : LearnAlertStyle.textSecondary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 9)
                    .padding(.bottom, 7)
                    .disabled(isTutorialActive)
                    .opacity(isTutorialActive ? 0.35 : 1.0)
                    .accessibilityLabel(isTargeted ? "Deck alerts active" : "Quick schedule \(deck.name)")
                }

                if isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(LearnAlertStyle.appAccentForeground)
                        .padding(10)
                        .accessibilityLabel("Pinned")
                }
            }
            .frame(maxWidth: .infinity)
            .appCardSurface()
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        isTutorialHighlighted ? LearnAlertStyle.appAccent : Color.clear,
                        lineWidth: isTutorialHighlighted ? 2.5 : 0.9
                    )
                    .shadow(color: isTutorialHighlighted ? LearnAlertStyle.appAccent.opacity(0.75) : Color.clear, radius: 10)
            }
            .contextMenu {
                if !isTutorialActive {
                    if let togglePin {
                        Button(action: togglePin) {
                            Label(isPinned ? "Unpin Deck" : "Pin Deck", systemImage: isPinned ? "pin.slash" : "pin")
                        }
                    }
                    Button(action: shuffleAppearance) {
                        Label("Shuffle Appearance", systemImage: "shuffle")
                    }
                    Button(role: .destructive, action: delete) { Label("Delete", systemImage: "trash") }
                }
            }
        }
        .onAppear {
            if isTutorialHighlighted {
                withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                    pulseGlow = true
                }
            }
        }
        .onChange(of: isTutorialHighlighted) { _, highlighted in
            if highlighted {
                withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                    pulseGlow = true
                }
            }
        }
    }

    private var progressColor: Color {
        if deck.cycleStreak > 0 {
            if deck.cycleProgress >= 0.70 {
                return Color(red: 0.18, green: 0.80, blue: 0.44)
            } else if deck.cycleProgress >= 0.40 {
                return LearnAlertStyle.appAccent
            } else {
                return LearnAlertStyle.appAccent
            }
        } else {
            return LearnAlertStyle.textSecondary
        }
    }
}

/// A presentation contains both values, so the first launch cannot capture a missing course.
private struct HomeCourseStudySelection: Identifiable {
    let course: CourseDefinition
    let lesson: CourseLesson
    var id: String { course.id + ":" + lesson.id }
}

// MARK: - HomeCourseCard
private struct HomeCourseCard: View {
    let course: CourseDefinition
    let isPinned: Bool
    let isTargeted: Bool
    let onContinue: () -> Void
    let onOpenOverview: () -> Void
    let schedule: () -> Void
    let togglePin: () -> Void
    let unenroll: () -> Void

    @ObservedObject private var progressManager = CourseProgressManager.shared
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var enrollment: CourseEnrollment? {
        progressManager.enrollment(for: course.id)
    }

    private var completionPercent: Double {
        progressManager.completionPercentage(for: course)
    }

    private var currentLesson: CourseLesson? {
        progressManager.currentLesson(for: course)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button(action: onOpenOverview) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Text(course.flagEmoji).font(.system(size: 28))
                            .frame(width: 48, height: 48)
                            .background(Color(hex: course.colorHex).opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(course.title).font(.title3.weight(.semibold)).foregroundStyle(LearnAlertStyle.textPrimary)
                            Text(course.levelTag).font(.caption).foregroundStyle(LearnAlertStyle.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        if isPinned { Image(systemName: "pin.fill").font(.caption).foregroundStyle(.secondary).accessibilityLabel("Pinned") }
                    }
                    Text(currentLesson?.title ?? "All lessons completed")
                        .font(.subheadline).foregroundStyle(LearnAlertStyle.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 8) {
                let statsLayout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                    : AnyLayout(HStackLayout(spacing: 8))
                statsLayout {
                    Text(completionPercent, format: .percent.precision(.fractionLength(0)))
                        .font(.caption.weight(.semibold))
                    if !dynamicTypeSize.isAccessibilitySize { Spacer() }
                    if let lesson = currentLesson {
                        let answered = progressManager.answeredCardsCount(course: course, lesson: lesson)
                        if answered > 0 {
                            Text("\(answered) of \(lesson.cards.count) answered")
                                .font(.caption)
                        }
                    }
                }
                .foregroundStyle(LearnAlertStyle.textSecondary)
                ProgressView(value: completionPercent).tint(Color(hex: course.colorHex))
            }
            HStack(spacing: 12) {
                Button(action: onContinue) {
                    HStack(spacing: 8) {
                        Text(currentLesson == nil ? "Review" : "Continue")
                        Image(systemName: "arrow.right").font(.caption.weight(.bold))
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LearnAlertStyle.appAccentInk)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(LearnAlertStyle.appAccent, in: RoundedRectangle(cornerRadius: 14))
                    .lightModeOutline(cornerRadius: 14)
                }.buttonStyle(.plain)
                Button(action: schedule) {
                    Image(systemName: isTargeted ? "bell.badge.fill" : "bell")
                        .foregroundStyle(isTargeted ? LearnAlertStyle.appAccentForeground : LearnAlertStyle.textSecondary)
                        .frame(width: 48, height: 48)
                        .background(LearnAlertStyle.insetSurface, in: RoundedRectangle(cornerRadius: 14))
                        .lightModeOutline(cornerRadius: 14)
                }.buttonStyle(.plain)
                    .accessibilityLabel(isTargeted ? "Course alerts active" : "Schedule \(course.title)")
            }
        }.padding(16)
        .appCardSurface()
        .contextMenu {
            Button(action: togglePin) {
                Label(isPinned ? "Unpin Course" : "Pin Course", systemImage: isPinned ? "pin.slash" : "pin")
            }
            Button(action: schedule) {
                Label("Schedule Alerts", systemImage: "bell.badge")
            }
            Button(role: .destructive, action: unenroll) {
                Label("Unenroll", systemImage: "xmark.circle")
            }
        }
    }
}

// MARK: - PinnedReorderSheet
private struct PinnedReorderSheet: View {
    @ObservedObject var progressManager: CourseProgressManager
    let enrolledCourses: [CourseDefinition]
    let decks: [Deck]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(progressManager.pinnedItemIds, id: \.self) { itemId in
                    HStack(spacing: 12) {
                        Image(systemName: "line.3.horizontal")
                            .foregroundStyle(LearnAlertStyle.textSecondary)

                        if itemId.hasPrefix("course:") {
                            let courseId = String(itemId.dropFirst("course:".count))
                            if let course = enrolledCourses.first(where: { $0.id == courseId }) {
                                Text(course.flagEmoji)
                                    .font(.system(size: 20))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(course.title)
                                        .font(.custom("Poppins-Medium", size: 14))
                                        .foregroundStyle(LearnAlertStyle.textPrimary)
                                    Text("Course")
                                        .font(.custom("Poppins-Regular", size: 11))
                                        .foregroundStyle(LearnAlertStyle.textSecondary)
                                }
                            }
                        } else if itemId.hasPrefix("deck:") {
                            let deckId = String(itemId.dropFirst("deck:".count))
                            if let deck = decks.first(where: { $0.id.uuidString == deckId }) {
                                Image(systemName: "rectangle.stack.fill")
                                    .foregroundStyle(LearnAlertStyle.sky)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(deck.name)
                                        .font(.custom("Poppins-Medium", size: 14))
                                        .foregroundStyle(LearnAlertStyle.textPrimary)
                                    Text("\(deck.cards.count) cards")
                                        .font(.custom("Poppins-Regular", size: 11))
                                        .foregroundStyle(LearnAlertStyle.textSecondary)
                                }
                            }
                        }

                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .onMove { indices, newOffset in
                    progressManager.movePinned(from: indices, to: newOffset)
                }
            }
            .listStyle(.insetGrouped)
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Reorder Pinned")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Guided Walkthrough Top & Floating Banners// MARK: - Guided Walkthrough Top & Floating Banners
private struct TutorialStepTopBanner: View {
    let stepNumber: Int
    let totalSteps: Int
    let title: String
    let subtitle: String
    let icon: String
    let onSkip: () -> Void

    @State private var pulse = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LearnAlertStyle.indigo.opacity(0.18))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(LearnAlertStyle.sky)
                    .scaleEffect(pulse ? 1.12 : 0.95)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("STEP \(stepNumber) OF \(totalSteps)")
                        .font(.custom("Poppins-SemiBold", size: 10))
                        .foregroundStyle(LearnAlertStyle.sky)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(LearnAlertStyle.sky.opacity(0.14), in: Capsule())

                    Spacer()

                    Button(action: onSkip) {
                        Text("Skip Tour")
                            .font(.custom("Poppins-Medium", size: 11))
                            .foregroundStyle(LearnAlertStyle.textSecondary)
                    }
                    .buttonStyle(.plain)
                }

                Text(title)
                    .font(.custom("Poppins-SemiBold", size: 13))
                    .foregroundStyle(LearnAlertStyle.textPrimary)

                Text(subtitle)
                    .font(.custom("Poppins-Regular", size: 11))
                    .foregroundStyle(LearnAlertStyle.textSecondary)
            }
        }
        .padding(14)
        .background(LearnAlertStyle.courseSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [LearnAlertStyle.sky, LearnAlertStyle.indigo.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: LearnAlertStyle.sky.opacity(0.24), radius: 12, y: 5)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

// MARK: - Hand Drawn Upward Arrow & Tutorial Banners
private struct HandDrawnUpwardArrowShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        // Curvy hand-drawn stem from bottom to top
        let start = CGPoint(x: rect.midX + 8, y: rect.maxY)
        let control1 = CGPoint(x: rect.midX + 18, y: rect.midY + 12)
        let control2 = CGPoint(x: rect.midX - 14, y: rect.midY - 8)
        let end = CGPoint(x: rect.midX, y: rect.minY + 3)

        path.move(to: start)
        path.addCurve(to: end, control1: control1, control2: control2)

        // Left wing of arrow head
        path.move(to: CGPoint(x: end.x - 10, y: end.y + 12))
        path.addQuadCurve(to: end, control: CGPoint(x: end.x - 4, y: end.y + 4))

        // Right wing of arrow head
        path.move(to: CGPoint(x: end.x + 9, y: end.y + 13))
        path.addQuadCurve(to: end, control: CGPoint(x: end.x + 4, y: end.y + 4))

        return path
    }
}

private struct HandDrawnUpwardArrowView: View {
    @State private var bounce = false

    var body: some View {
        VStack(spacing: 6) {
            HandDrawnUpwardArrowShape()
                .stroke(
                    LinearGradient(
                        colors: [LearnAlertStyle.sky, LearnAlertStyle.indigo],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round)
                )
                .frame(width: 44, height: 52)
                .offset(y: bounce ? -8 : 3)
                .shadow(color: LearnAlertStyle.sky.opacity(0.6), radius: 8)

            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .bold))
                Text("Notification sent above!")
                    .font(.custom("Poppins-SemiBold", size: 12))
            }
            .foregroundStyle(LearnAlertStyle.sky)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(LearnAlertStyle.sky.opacity(0.14), in: Capsule())
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                bounce = true
            }
        }
    }
}

private struct LiveTestAlertFloatingBanner: View {
    let deckName: String
    let onResend: () -> Void
    let onComplete: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(LearnAlertStyle.sky.opacity(0.2))
                        .frame(width: 32, height: 32)
                    Image(systemName: "bell.badge.waveform.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(LearnAlertStyle.sky)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Real Notification Sent!")
                        .font(.custom("Poppins-SemiBold", size: 14))
                        .foregroundStyle(LearnAlertStyle.textPrimary)
                    Text("Swipe down or press & hold the banner above to answer the quiz live.")
                        .font(.custom("Poppins-Regular", size: 12))
                        .foregroundStyle(LearnAlertStyle.textSecondary)
                }

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(LearnAlertStyle.textSecondary)
                        .frame(width: 26, height: 26)
                        .background(Color.primary.opacity(0.06), in: Circle())
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                Button(action: onResend) {
                    Label("Resend Alert", systemImage: "arrow.counterclockwise")
                        .font(.custom("Poppins-Medium", size: 12))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.primary.opacity(0.08))
                        .foregroundStyle(LearnAlertStyle.textPrimary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: onComplete) {
                    Label("I Answered It", systemImage: "checkmark.circle.fill")
                        .font(.custom("Poppins-SemiBold", size: 12))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(LearnAlertStyle.indigo)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .shadow(color: LearnAlertStyle.indigo.opacity(0.35), radius: 6, y: 2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(LearnAlertStyle.courseSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(LearnAlertStyle.sky.opacity(0.5), lineWidth: 1.2)
        )
        .shadow(color: LearnAlertStyle.sky.opacity(0.20), radius: 14, y: 6)
    }
}

private struct TutorialCompletedBanner: View {
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LearnAlertStyle.lime.opacity(0.2))
                    .frame(width: 36, height: 36)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(LearnAlertStyle.lime)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("🎉 You're all set!")
                    .font(.custom("Poppins-SemiBold", size: 14))
                    .foregroundStyle(LearnAlertStyle.textPrimary)
                Text("You've scheduled your alerts. Quizzes will arrive directly in your notifications.")
                    .font(.custom("Poppins-Regular", size: 11))
                    .foregroundStyle(LearnAlertStyle.textSecondary)
            }

            Spacer()

            Button(action: onDismiss) {
                Text("Done")
                    .font(.custom("Poppins-SemiBold", size: 12))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(LearnAlertStyle.indigo)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(LearnAlertStyle.courseSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(LearnAlertStyle.lime.opacity(0.4), lineWidth: 1)
        )
        .shadow(color: LearnAlertStyle.lime.opacity(0.2), radius: 12, y: 5)
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
            VStack(alignment: .leading, spacing: 24) {
                Text("Settings")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(LearnAlertStyle.textPrimary)
                    .padding(.horizontal, 20)

                SettingsPreferencesGroup(
                    alertSound: $alertSound,
                    availableSounds: availableSounds,
                    appearanceMode: $appearanceMode,
                    deckCreaturesHaveFaces: $deckCreaturesHaveFaces
                )

                SettingsSupportGroup()

                SettingsNavigationGroup()

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
