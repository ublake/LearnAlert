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
    @State private var showingMinigames = false
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
                        TextField("Search decks & bundles", text: $discoverSearch)
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
        .navigationDestination(isPresented: $showingMinigames) {
            MinigamesView()
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
                title: "Language learning bundles",
                subtitle: "Quiz and flashcard collections.",
                badge: "\(CourseCurriculumCatalog.courses.count) available",
                symbol: "character.bubble.fill",
                color: StudyStudioStyle.blue,
                action: { showingCourses = true }
            )

            DiscoverCategoryTile(
                title: "Minigames",
                subtitle: "Play, practise, repeat.",
                badge: "Play",
                symbol: "target",
                color: StudyStudioStyle.violet,
                action: { showingMinigames = true }
            )
        }
    }

    private var searchResults: some View {
        let query = discoverSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        let courses = CourseCurriculumCatalog.courses.filter {
            $0.title.localizedCaseInsensitiveContains(query) || $0.language.localizedCaseInsensitiveContains(query)
        }
        let decks = PremadeDeckCatalog.decks.filter {
            $0.category != "Exam Prep" && ($0.name.localizedCaseInsensitiveContains(query)
                || $0.category.localizedCaseInsensitiveContains(query) || $0.subcategory.localizedCaseInsensitiveContains(query))
        }
        return VStack(alignment: .leading, spacing: 16) {
            Text("Learning bundles & decks").font(StudyStudioStyle.heading()).foregroundStyle(StudyStudioStyle.ink)
            ForEach(courses) { course in
                Button { searchedCourse = course } label: {
                    searchRow(title: course.title, subtitle: "Language learning bundle", symbol: "character.book.closed", action: "Open")
                }.buttonStyle(.plain)
            }
            ForEach(decks) { deck in
                let added = deck.isInLibrary(libraryDecks)
                Button { add(deck) } label: {
                    searchRow(title: deck.name, subtitle: "\(deck.category) · \(deck.cards.count) cards", symbol: "rectangle.stack", action: added ? "Added" : "Add")
                }.buttonStyle(.plain).disabled(added)
            }
            if courses.isEmpty && decks.isEmpty {
                Text("No matching bundles or decks.")
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
                    Text("Language Learning Bundles")
                        .font(.custom("Poppins-Bold", size: 24))
                        .foregroundStyle(LearnAlertStyle.textPrimary)
                    Text("Small topic decks. Pick one and start practising.")
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
        .navigationTitle("Language Learning Bundles")
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
                        Text("\(LanguageDeckProjection.topics(course).count) topic decks")
                            .font(.custom("Poppins-Medium", size: 10))
                            .foregroundStyle(LearnAlertStyle.textSecondary)

                        Spacer()

                        Text(isEnrolled ? "Continue" : "View Bundle")
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

// MARK: - Minigames

struct MinigamesView: View {
    var body: some View {
        LearnAlertStyle.courseCanvas
            .ignoresSafeArea()
            .navigationTitle("Minigames")
            .navigationBarTitleDisplayMode(.inline)
    }
}
