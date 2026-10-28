import SwiftData
import SwiftUI
import AuthenticationServices

// MARK: - Discover

struct PremadeDecksView: View {
    @ObservedObject private var managedCatalog = ManagedCatalogStore.shared
    @Environment(\.usesNativeStudyNavigation) private var usesNativeStudyNavigation
    @Environment(\.modelContext) private var context
    @Query private var libraryDecks: [Deck]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var addedDeckName: String?
    @State private var showingAllCommunity = false
    @StateObject private var communityFeed = CommunityFeedStore()
    @State private var showingShareSheet = false
    @State private var searchedCourse: CourseDefinition?

    @State private var discoverSearch = ""
    @State private var showingSearch = false
    @FocusState private var searchFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                // Keep the language rail available for a future design pass.

                if showingSearch {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundStyle(StudyStudioStyle.secondary)
                        TextField("Search decks & languages", text: $discoverSearch)
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


                if !discoverSearch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    searchResults
                }

                CommunityFeedView(store: communityFeed, libraryDecks: libraryDecks,
                    onAddDeck: add, onShare: { showingShareSheet = true }, showsSearchField: false, showsTitle: false,
                    searchAction: toggleSearch, searchExpanded: showingSearch)

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
        .navigationDestination(isPresented: $showingAllCommunity) {
            AllCommunityDecksView(
                libraryDecks: libraryDecks,
                initialSearch: discoverSearch,
                onAddDeck: { add($0) },
                onOpenShareModal: { showingShareSheet = true }
            )
        }
        .navigationDestination(item: $searchedCourse) { course in
            LanguageDeckDiscoveryView(course: course)
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

    private func toggleSearch() {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { showingSearch.toggle() }
        searchFocused = showingSearch
        if !showingSearch { discoverSearch = "" }
    }

    private var languageRail: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Languages")
                .font(StudyStudioStyle.heading(21))
                .foregroundStyle(StudyStudioStyle.ink)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHGrid(
                    rows: Array(repeating: GridItem(.fixed(43), spacing: 6, alignment: .top), count: 2),
                    alignment: .top,
                    spacing: 12
                ) {
                    ForEach(DiscoverLanguageChoice.choices) { choice in
                        let course = CourseCurriculumCatalog.courses.first {
                            $0.language.caseInsensitiveCompare(choice.name) == .orderedSame && !LanguageDeckProjection.topics($0).isEmpty
                        }
                        Button {
                            guard let course else { return }
                            HapticFeedback.impact(.light)
                            searchedCourse = course
                        } label: {
                            DiscoverLanguageButton(choice: choice, available: course != nil)
                        }
                        .buttonStyle(.plain)
                        .disabled(course == nil)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(choice.name)
                        .accessibilityValue(course == nil ? "Not available yet" : "Available")
                        .accessibilityHint(course == nil ? "" : "Opens \(choice.name) decks")
                    }
                }
            }
            Text("More languages on the way")
                .font(StudyStudioStyle.heading(23))
                .foregroundStyle(StudyStudioStyle.ink.opacity(0.16))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
    }

    private var searchResults: some View {
        let query = discoverSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        let courses = CourseCurriculumCatalog.courses.filter {
            !LanguageDeckProjection.topics($0).isEmpty &&
                ($0.title.localizedCaseInsensitiveContains(query) || $0.language.localizedCaseInsensitiveContains(query))
        }
        let decks = PremadeDeckCatalog.decks.filter {
            $0.category != "Exam Prep" && ($0.name.localizedCaseInsensitiveContains(query)
                || $0.category.localizedCaseInsensitiveContains(query) || $0.subcategory.localizedCaseInsensitiveContains(query))
        }
        return VStack(alignment: .leading, spacing: 16) {
            Text("Languages & decks").font(StudyStudioStyle.heading()).foregroundStyle(StudyStudioStyle.ink)
            ForEach(courses) { course in
                Button { searchedCourse = course } label: {
                    searchRow(title: course.title, subtitle: "Language decks", symbol: "character.book.closed", action: "Open")
                }.buttonStyle(.plain)
            }
            ForEach(decks) { deck in
                let added = deck.isInLibrary(libraryDecks)
                Button { add(deck) } label: {
                    searchRow(title: deck.name, subtitle: "\(deck.category) · \(deck.cards.count) cards", symbol: "rectangle.stack", action: added ? "Added" : "Add")
                }.buttonStyle(.plain).disabled(added)
            }
            if courses.isEmpty && decks.isEmpty {
                Text("No matching languages or decks.")
                    .font(StudyStudioStyle.body()).foregroundStyle(StudyStudioStyle.secondary)
            }
            Button { showingAllCommunity = true } label: {
                Label("Search shared decks", systemImage: "person.2")
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

private struct DiscoverLanguageChoice: Identifiable {
    let name: String
    let flagAssetName: String
    var id: String { name }

    static let choices = [
        Self(name: "Spanish", flagAssetName: "FlagSpain"),
        Self(name: "Korean", flagAssetName: "FlagKorea"),
        Self(name: "French", flagAssetName: "FlagFrance"),
        Self(name: "Japanese", flagAssetName: "FlagJapan"),
        Self(name: "English", flagAssetName: "FlagUnitedKingdom"),
        Self(name: "German", flagAssetName: "FlagGermany"),
        Self(name: "Italian", flagAssetName: "FlagItaly"),
        Self(name: "Portuguese", flagAssetName: "FlagPortugal"),
        Self(name: "Chinese", flagAssetName: "FlagChina"),
        Self(name: "Arabic", flagAssetName: "FlagSaudiArabia")
    ]
}

private struct DiscoverLanguageButton: View {
    let choice: DiscoverLanguageChoice
    let available: Bool
    var body: some View {
        Image(choice.flagAssetName)
            .resizable()
            .scaledToFill()
            .frame(width: 64, height: 43)
            .clipped()
            .saturation(available ? 1 : 0.55)
            .opacity(available ? 1 : 0.6)
            .accessibilityHidden(true)
            .contentShape(Rectangle())
    }
}
