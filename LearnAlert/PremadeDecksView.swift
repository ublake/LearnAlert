import SwiftData
import SwiftUI
import AuthenticationServices

// MARK: - Models for Premade / Discover Decks

// MARK: - Main Discover Hub View (2-Column Category Grid)

struct PremadeDecksView: View {
    @ObservedObject private var managedCatalog = ManagedCatalogStore.shared
    @Environment(\.usesNativeStudyNavigation) private var usesNativeStudyNavigation
    @Environment(\.modelContext) private var context
    @Query private var libraryDecks: [Deck]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var addedDeckName: String?
    @State private var showingCourses = false
    @State private var showingAllCommunity = false
    @StateObject private var communityFeed = CommunityFeedStore()
    @State private var showingExamPrep = false
    @State private var showingShareSheet = false
    @State private var searchedCourse: CourseDefinition?

    @State private var discoverSearch = ""
    @State private var showingSearch = false
    @FocusState private var searchFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center) {
                    Text("Community decks").font(StudyStudioStyle.title(24))
                    Spacer()
                    Button {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { showingSearch.toggle() }
                        searchFocused = showingSearch
                        if !showingSearch { discoverSearch = "" }
                    } label: {
                        Image(systemName: showingSearch ? "xmark" : "magnifyingglass")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(LearnAlertStyle.appAccentForeground)
                            .frame(width: 44, height: 44)
                            .appCardSurface(cornerRadius: 14)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(showingSearch ? "Close search" : "Search Discover")
                    .accessibilityValue(showingSearch ? "Expanded" : "Collapsed")
                }
                .foregroundStyle(StudyStudioStyle.ink)

                if showingSearch {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundStyle(StudyStudioStyle.secondary)
                        TextField("Search decks & courses", text: $discoverSearch)
                            .font(.subheadline).textInputAutocapitalization(.never)
                            .autocorrectionDisabled().submitLabel(.search)
                            .focused($searchFocused)
                        if !discoverSearch.isEmpty {
                            Button { discoverSearch = "" } label: {
                                Image(systemName: "xmark.circle.fill").frame(width: 44, height: 44)
                            }.accessibilityLabel("Clear search")
                        }
                    }
                    .padding(.horizontal, 12).frame(minHeight: 48)
                    .background(StudyStudioStyle.field, in: RoundedRectangle(cornerRadius: 14))
                    .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(StudyStudioStyle.hairline, lineWidth: 1) }
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
                }

                destinationCards

                if !discoverSearch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    searchResults
                }

                CommunityFeedView(store: communityFeed, libraryDecks: libraryDecks,
                    onAddDeck: add, onShare: { showingShareSheet = true }, showsSearchField: false, showsTitle: false)

            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, usesNativeStudyNavigation ? 24 : 110)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .refreshable {
            await managedCatalog.refresh(force: true)
            await communityFeed.load()
        }
        .onChange(of: discoverSearch) { _, query in
            if communityFeed.search != query { communityFeed.search = query }
        }
        .onChange(of: communityFeed.search) { _, query in
            if discoverSearch != query { discoverSearch = query }
        }
        .background(StudyStudioStyle.canvas.ignoresSafeArea())
        .tint(StudyStudioStyle.violet)
        .navigationDestination(isPresented: $showingCourses) {
            CoursesCatalogListView()
        }
        .navigationDestination(isPresented: $showingAllCommunity) {
            AllCommunityDecksView(
                libraryDecks: libraryDecks,
                initialSearch: discoverSearch,
                onAddDeck: { add($0) },
                onOpenShareModal: { showingShareSheet = true }
            )
        }
        .navigationDestination(isPresented: $showingExamPrep) {
            ExamPrepHubView(libraryDecks: libraryDecks, onAddDeck: add)
        }
        .navigationDestination(item: $searchedCourse) { course in
            CoursePathView(course: course)
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareDeckToCommunitySheet(libraryDecks: libraryDecks)
        }
        .alert("Added to Library", isPresented: Binding(get: { addedDeckName != nil }, set: { if !$0 { addedDeckName = nil } })) {
            Button("Done", role: .cancel) { }
        } message: {
            Text("\(addedDeckName ?? "This deck") is now ready to study and editable in your library.")
        }
    }

    private var destinationCards: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ],
            spacing: 12
        ) {
            DiscoverCategoryTile(
                title: "Language courses",
                subtitle: "Structured language learning.",
                badge: "\(CourseCurriculumCatalog.courses.count) available",
                symbol: "character.bubble.fill",
                color: StudyStudioStyle.blue,
                action: { showingCourses = true }
            )

            DiscoverCategoryTile(
                title: "Exam & cert prep",
                subtitle: "MCAT, AWS, SAT & study skills.",
                badge: "Prep",
                symbol: "target",
                color: StudyStudioStyle.violet,
                action: { showingExamPrep = true }
            )
        }
    }

    private var searchResults: some View {
        let query = discoverSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        let courses = CourseCurriculumCatalog.courses.filter {
            $0.title.localizedCaseInsensitiveContains(query) || $0.language.localizedCaseInsensitiveContains(query)
        }
        let decks = PremadeDeckCatalog.decks.filter {
            $0.name.localizedCaseInsensitiveContains(query) || $0.category.localizedCaseInsensitiveContains(query)
                || $0.subcategory.localizedCaseInsensitiveContains(query)
        }
        return VStack(alignment: .leading, spacing: 16) {
            Text("Courses & exam decks").font(StudyStudioStyle.heading()).foregroundStyle(StudyStudioStyle.ink)
            ForEach(courses) { course in
                Button { searchedCourse = course } label: {
                    searchRow(title: course.title, subtitle: "Guided language course", symbol: "character.book.closed", action: "Open")
                }.buttonStyle(.plain)
            }
            ForEach(decks) { deck in
                let added = deck.isInLibrary(libraryDecks)
                Button { add(deck) } label: {
                    searchRow(title: deck.name, subtitle: "\(deck.category) · \(deck.cards.count) cards", symbol: "rectangle.stack", action: added ? "Added" : "Add")
                }.buttonStyle(.plain).disabled(added)
            }
            if courses.isEmpty && decks.isEmpty {
                Text("No matching courses or exam decks.")
                    .font(StudyStudioStyle.body()).foregroundStyle(StudyStudioStyle.secondary)
            }
            Button { showingAllCommunity = true } label: {
                Label("Search community decks", systemImage: "person.2")
                    .font(StudyStudioStyle.heading(14)).frame(maxWidth: .infinity, minHeight: 52)
                    .foregroundStyle(.white).background(StudyStudioStyle.violet, in: RoundedRectangle(cornerRadius: 16))
            }.buttonStyle(.plain)
        }
    }

    private func searchRow(title: String, subtitle: String, symbol: String, action: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: symbol).font(.system(size: 22)).foregroundStyle(StudyStudioStyle.violet)
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(StudyStudioStyle.heading(15)).foregroundStyle(StudyStudioStyle.ink)
                Text(subtitle).font(StudyStudioStyle.body(12)).foregroundStyle(StudyStudioStyle.secondary)
            }
            Spacer(minLength: 0)
            Text(action).font(StudyStudioStyle.heading(12)).foregroundStyle(StudyStudioStyle.violet)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(StudyStudioStyle.field, in: RoundedRectangle(cornerRadius: 20))
    }

    private func add(_ premadeDeck: PremadeDeck) {
        guard !premadeDeck.isInLibrary(libraryDecks) else { return }
        let deck = Deck(name: premadeDeck.name, colorHex: premadeDeck.colorHex, deckType: premadeDeck.deckType, orderIndex: libraryDecks.count)
        deck.sourceCommunityID = premadeDeck.communitySourceID
        deck.sourcePremadeID = premadeDeck.communitySourceID == nil ? premadeDeck.id : nil
        for (index, sourceCard) in premadeDeck.cards.enumerated() {
            let card = Flashcard(
                question: sourceCard.question,
                options: sourceCard.options,
                correctAnswer: sourceCard.correctAnswer,
                hint: sourceCard.hint,
                cardType: sourceCard.cardType,
                matchingLeftItems: sourceCard.matchingLeftItems,
                matchingRightItems: sourceCard.matchingRightItems,
                promptImageName: sourceCard.promptImageName,
                answerImageName: sourceCard.answerImageName,
                optionImageNames: sourceCard.optionImageNames
            )
            card.orderIndex = index
            card.promptAudioName = sourceCard.promptAudioName
            card.fieldMedia = sourceCard.resolvedFieldMedia
            card.correctOptionIndex = sourceCard.correctOptionIndex
            card.ankiContent = sourceCard.ankiContent
            deck.cards.append(card)
            deck.assignCardToSection(card: card, suggestedCategory: sourceCard.sectionName)
        }
        context.insert(deck)
        try? context.save()
        InteractionSoundPlayer.shared.play(.addDeck)
        HapticFeedback.success()
        addedDeckName = premadeDeck.name
    }
}

// MARK: - Dedicated Courses Catalog List View

private struct CoursesCatalogListView: View {
    @ObservedObject private var managedCatalog = ManagedCatalogStore.shared
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ObservedObject private var progressManager = CourseProgressManager.shared
    @State private var selectedCourse: CourseDefinition?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Language Courses")
                        .font(.custom("Poppins-Bold", size: 24))
                        .foregroundStyle(LearnAlertStyle.textPrimary)
                    Text("Structured tracks with spaced repetition & lock-screen alerts")
                        .font(.custom("Poppins-Regular", size: 12))
                        .foregroundStyle(LearnAlertStyle.textSecondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                VStack(spacing: 14) {
                    ForEach(CourseCurriculumCatalog.courses) { course in
                        LanguageCourseHeroCard(
                            course: course,
                            isEnrolled: progressManager.isEnrolled(in: course.id),
                            onSelect: { selectedCourse = course }
                        )
                    }
                }
                .padding(.horizontal, 20)

                Spacer().frame(height: 60)
            }
        }
        .background(LearnAlertStyle.courseCanvas.ignoresSafeArea())
        .navigationTitle("Courses")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedCourse) { course in
            CoursePathView(course: course)
        }
    }
}

// MARK: - Language Course Hero Card

private struct LanguageCourseHeroCard: View {
    let course: CourseDefinition
    let isEnrolled: Bool
    let onSelect: () -> Void

    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(alignment: .top, spacing: 14) {
                Text(course.flagEmoji)
                    .font(.system(size: 34))
                    .padding(8)
                    .background(Color(hex: course.colorHex).opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(course.title)
                            .font(.custom("Poppins-Bold", size: 15))
                            .foregroundStyle(LearnAlertStyle.textPrimary)

                        Spacer()

                        Text(course.levelTag)
                            .font(.custom("Poppins-SemiBold", size: 10))
                            .foregroundStyle(Color(hex: course.colorHex))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color(hex: course.colorHex).opacity(0.12), in: Capsule())
                    }

                    Text(course.summary)
                        .font(.custom("Poppins-Regular", size: 11))
                        .foregroundStyle(LearnAlertStyle.textSecondary)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        Text("\(course.totalLessonsCount) lessons • ~\(course.estimatedHours) hrs")
                            .font(.custom("Poppins-Medium", size: 10))
                            .foregroundStyle(LearnAlertStyle.textSecondary)

                        Spacer()

                        Text(isEnrolled ? "Continue" : "View Course")
                            .font(.custom("Poppins-SemiBold", size: 11))
                            .foregroundStyle(Color(hex: course.colorHex))
                    }
                    .padding(.top, 4)
                }
            }
            .padding(14)
            .background(LearnAlertStyle.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(LearnAlertStyle.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Dedicated Exam Prep Hub View (Placeholder / High-Yield Prep)

private struct ExamPrepHubView: View {
    @ObservedObject private var managedCatalog = ManagedCatalogStore.shared
    let libraryDecks: [Deck]
    let onAddDeck: (PremadeDeck) -> Void

    @State private var searchText = ""
    @State private var selectedFilter = "All"

    private var examDecks: [PremadeDeck] { managedCatalog.examDecks }
    private var examFilters: [String] { ["All"] + Set(examDecks.map(\.subcategory).filter { !$0.isEmpty }).sorted() }

    private var filteredDecks: [PremadeDeck] {
        examDecks.filter { deck in
            let matchesFilter = selectedFilter == "All" || deck.subcategory == selectedFilter

            let matchesSearch = searchText.isEmpty
                || deck.name.localizedCaseInsensitiveContains(searchText)
                || deck.description.localizedCaseInsensitiveContains(searchText)
                || deck.subcategory.localizedCaseInsensitiveContains(searchText)

            return matchesFilter && matchesSearch
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                DiscoverSearchField(searchText: $searchText, placeholder: "Search MCAT, SAT, AWS, USMLE, Law...")
                DiscoverFilterRow(categories: examFilters, selection: $selectedFilter, compact: true)

                if filteredDecks.isEmpty {
                    ContentUnavailableView("No Exam Decks Found", systemImage: "target", description: Text("Try adjusting your filter or search query."))
                        .padding(.vertical, 40)
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredDecks) { deck in
                            CleanDiscoverDeckCard(
                                title: deck.name,
                                subtitle: "\(deck.cards.count) cards • \(deck.subcategory)",
                                colorHex: deck.colorHex,
                                iconName: "graduationcap.fill",
                                isAdded: deck.isInLibrary(libraryDecks),
                                onAdd: { onAddDeck(deck) }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }

                Spacer().frame(height: 60)
            }
            .padding(.top, 14)
        }
        .background(LearnAlertStyle.courseCanvas.ignoresSafeArea())
        .navigationTitle("Exam & Cert Drills")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Dedicated "See All Premade Decks" View

private struct AllPremadeDecksView: View {
    @ObservedObject private var managedCatalog = ManagedCatalogStore.shared
    let libraryDecks: [Deck]
    let onAddDeck: (PremadeDeck) -> Void

    @State private var searchText = ""
    @State private var selectedCategory = "All"
    @State private var selectedSubcategory = "All"

    private var availableSubcategories: [String] {
        PremadeDeckCatalog.subcategoriesByCategory[selectedCategory] ?? []
    }

    private var filteredDecks: [PremadeDeck] {
        PremadeDeckCatalog.decks.filter { deck in
            let matchesCategory = selectedCategory == "All" || deck.category == selectedCategory
            let matchesSubcategory = selectedSubcategory == "All" || deck.subcategory == selectedSubcategory
            let matchesSearch = searchText.isEmpty
                || deck.name.localizedCaseInsensitiveContains(searchText)
                || deck.description.localizedCaseInsensitiveContains(searchText)
                || deck.category.localizedCaseInsensitiveContains(searchText)
                || deck.subcategory.localizedCaseInsensitiveContains(searchText)
            return matchesCategory && matchesSubcategory && matchesSearch
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                DiscoverSearchField(searchText: $searchText, placeholder: "Search all curated decks...")
                DiscoverFilterRow(categories: PremadeDeckCatalog.mainCategories, selection: $selectedCategory)

                if !availableSubcategories.isEmpty {
                    DiscoverFilterRow(categories: availableSubcategories, selection: $selectedSubcategory, compact: true)
                }

                if filteredDecks.isEmpty {
                    ContentUnavailableView("No Decks Found", systemImage: "magnifyingglass", description: Text("Try another search or category."))
                        .padding(.vertical, 40)
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredDecks) { deck in
                            CleanDiscoverDeckCard(
                                title: deck.name,
                                subtitle: "\(deck.cards.count) cards • \(deck.subcategory)",
                                colorHex: deck.colorHex,
                                iconName: "book.closed.fill",
                                isAdded: deck.isInLibrary(libraryDecks),
                                onAdd: { onAddDeck(deck) }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }

                Spacer().frame(height: 60)
            }
            .padding(.top, 14)
        }
        .background(LearnAlertStyle.courseCanvas.ignoresSafeArea())
        .navigationTitle("Curated Subjects")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedCategory) { _, _ in selectedSubcategory = "All" }
    }
}

// MARK: - Clean Discover Deck Card (Title + Small Plus Button)

private struct CleanDiscoverDeckCard: View {
    let title: String
    let subtitle: String
    let colorHex: String
    let iconName: String
    let isAdded: Bool
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(hex: colorHex).opacity(0.18))
                    .frame(width: 38, height: 38)
                Image(systemName: iconName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(hex: colorHex))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.custom("Poppins-SemiBold", size: 14))
                    .foregroundStyle(LearnAlertStyle.textPrimary)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.custom("Poppins-Regular", size: 11))
                    .foregroundStyle(LearnAlertStyle.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Button {
                onAdd()
            } label: {
                Image(systemName: isAdded ? "checkmark" : "plus")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(isAdded ? LearnAlertStyle.textSecondary : Color.white)
                    .frame(width: 28, height: 28)
                    .background(isAdded ? Color.gray.opacity(0.15) : LearnAlertStyle.indigo)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(isAdded)
            .accessibilityLabel(isAdded ? "\(title) already added" : "Add \(title)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(LearnAlertStyle.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(LearnAlertStyle.hairline, lineWidth: 1)
        )
    }
}

// MARK: - Search Field Component

private struct DiscoverSearchField: View {
    @Binding var searchText: String
    var placeholder: String = "Search decks..."

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(LearnAlertStyle.textSecondary)
            TextField(placeholder, text: $searchText)
                .font(.custom("Poppins-Medium", size: 13))
                .foregroundStyle(LearnAlertStyle.textPrimary)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(LearnAlertStyle.textSecondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(LearnAlertStyle.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(LearnAlertStyle.hairline, lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }
}

// MARK: - Filter Row Component

private struct DiscoverFilterRow: View {
    let categories: [String]
    @Binding var selection: String
    var compact: Bool = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories, id: \.self) { category in
                    let isSelected = selection == category
                    Button {
                        withAnimation(.snappy) { selection = category }
                    } label: {
                        Text(category)
                            .font(.custom(isSelected ? "Poppins-SemiBold" : "Poppins-Medium", size: compact ? 11 : 12))
                            .padding(.horizontal, compact ? 10 : 14)
                            .padding(.vertical, compact ? 5 : 7)
                            .background(isSelected ? LearnAlertStyle.indigo : LearnAlertStyle.surface)
                            .foregroundStyle(isSelected ? Color.white : LearnAlertStyle.textPrimary)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(isSelected ? Color.clear : LearnAlertStyle.hairline, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
    }
}
