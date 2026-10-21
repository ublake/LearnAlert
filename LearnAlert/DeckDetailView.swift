import SwiftUI
import SwiftData

struct DeckDetailView: View {
    @Bindable var deck: Deck
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage("homeTutorialStep") private var homeTutorialStep: Int = 0
    @AppStorage("tutorialDeckId") private var tutorialDeckId = ""

    @State private var showingScheduleSettings = false
    @State private var showingCreateCard = false
    @State private var showingCommunityShare = false
    @State private var showingCreateCategory = false
    @State private var isEditingDeck = false
    @State private var cardToEdit: Flashcard?
    @State private var showingStudy = false
    @State private var isSearching = false
    @FocusState private var searchFocused: Bool
    @State private var showingResetConfirmation = false
    @State private var searchText = ""
    @State private var selectedSectionFilter: String = "ALL"
    @State private var collapsedFolderIDs: Set<UUID> = []
    @State private var folderBeingEdited: DeckSection?
    @State private var editingFolderName: String = ""
    @State private var showingRenameFolderAlert = false

    private var orderedSections: [DeckSection] {
        deck.sections.sorted { $0.orderIndex < $1.orderIndex }
    }

    private var cardsDueToday: Int {
        deck.cards.filter { $0.nextReviewDate <= Date() }.count
    }

    private var filteredCards: [Flashcard] {
        var result = deck.cards

        if selectedSectionFilter != "ALL" {
            if selectedSectionFilter == "NONE" {
                result = result.filter { $0.section == nil }
            } else if let id = UUID(uuidString: selectedSectionFilter) {
                result = result.filter { $0.section?.id == id }
            }
        }

        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            result = result.filter { card in
                card.question.lowercased().contains(query) ||
                card.correctAnswer.lowercased().contains(query) ||
                card.matchingLeftItems.contains { $0.lowercased().contains(query) } ||
                card.matchingRightItems.contains { $0.lowercased().contains(query) } ||
                card.options.contains { $0.lowercased().contains(query) } ||
                card.hint.lowercased().contains(query)
            }
        }

        return result
    }

    var body: some View {
        ZStack {
            LearnAlertStyle.courseCanvas
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if homeTutorialStep == 2 {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.left")
                            .font(.system(size: 13, weight: .bold))
                            .accessibilityHidden(true)
                        Text("Step 2 of 3: Tap Back above to schedule alerts")
                            .font(.custom("Poppins-SemiBold", size: 11))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(
                        LinearGradient(
                            colors: [LearnAlertStyle.indigo, LearnAlertStyle.sky],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: Capsule()
                    )
                    .shadow(color: LearnAlertStyle.sky.opacity(0.6), radius: 6, y: 2)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 6)
                    .transition(.opacity.combined(with: .scale))
                }

                deckHeader

                // Inline Rename Deck Banner
                if isEditingDeck {
                    HStack(spacing: 10) {
                        TextField("Deck Name", text: $deck.name)
                            .font(.custom("Poppins-SemiBold", size: 15))
                            .foregroundStyle(LearnAlertStyle.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(LearnAlertStyle.courseSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                        Button("Done") {
                            withAnimation {
                                isEditingDeck = false
                                try? context.save()
                            }
                        }
                        .font(.custom("Poppins-SemiBold", size: 14))
                        .foregroundStyle(LearnAlertStyle.indigo)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
                }

                if isSearching {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundStyle(LearnAlertStyle.textSecondary)
                        TextField("Search cards", text: $searchText).font(.subheadline).focused($searchFocused)
                        Button { withAnimation(.snappy) { searchText = ""; isSearching = false } } label: {
                            Image(systemName: "xmark.circle.fill")
                        }.accessibilityLabel("Close card search")
                    }
                    .padding(10).background(LearnAlertStyle.insetSurface, in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16).padding(.bottom, 8)
                    .onAppear { searchFocused = true }
                }

                // Filters only occupy space when the deck has folders.
                if !orderedSections.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        sectionFilterPill(title: "All", tag: "ALL", count: deck.cards.count)

                        ForEach(orderedSections) { section in
                            sectionFilterPill(
                                title: section.name,
                                tag: section.id.uuidString,
                                count: section.cards.count,
                                colorHex: section.colorHex
                            )
                        }

                        let uncategorizedCount = deck.cards.filter { $0.section == nil }.count
                        if uncategorizedCount > 0 && !deck.sections.isEmpty {
                            sectionFilterPill(title: "Unsorted", tag: "NONE", count: uncategorizedCount)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 8)
                }

                // Cards List
                if filteredCards.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "rectangle.stack.badge.plus")
                            .font(.system(size: 44))
                            .foregroundStyle(LearnAlertStyle.textSecondary.opacity(0.6))
                        Text(deck.cards.isEmpty ? "No cards in this deck yet" : "No cards match your filter")
                            .font(.custom("Poppins-Medium", size: 15))
                            .foregroundStyle(LearnAlertStyle.textSecondary)
                        if deck.cards.isEmpty {
                            Button("Add First Card") {
                                showingCreateCard = true
                            }
                            .buttonStyle(PrimaryActionButtonStyle())
                            .frame(width: 180)
                        }
                        Spacer()
                    }
                } else {
                    List {
                        if selectedSectionFilter == "ALL" && !orderedSections.isEmpty {
                            ForEach(orderedSections) { section in
                                let sectionCards = section.cards.filter { card in
                                    searchText.isEmpty || filteredCards.contains(where: { $0.id == card.id })
                                }
                                if !sectionCards.isEmpty {
                                    Section {
                                        if !collapsedFolderIDs.contains(section.id) {
                                            ForEach(sectionCards) { card in
                                                cardRow(card)
                                                    .deleteDisabled(homeTutorialStep > 0)
                                            }
                                            .onDelete { offsets in
                                                delete(offsets, from: sectionCards)
                                            }
                                        }
                                    } header: {
                                        folderSectionHeader(section: section, count: sectionCards.count)
                                    }
                                }
                            }

                            let uncategorized = deck.cards.filter { card in
                                card.section == nil && (searchText.isEmpty || filteredCards.contains(where: { c in c.id == card.id }))
                            }
                            if !uncategorized.isEmpty {
                                Section {
                                    ForEach(uncategorized) { card in
                                        cardRow(card)
                                            .deleteDisabled(homeTutorialStep > 0)
                                    }
                                    .onDelete { offsets in
                                        delete(offsets, from: uncategorized)
                                    }
                                } header: {
                                    Text("Unsorted")
                                        .font(.custom("Poppins-SemiBold", size: 13))
                                        .foregroundStyle(LearnAlertStyle.textSecondary)
                                }
                            }
                        } else {
                            ForEach(filteredCards) { card in
                                cardRow(card)
                                    .deleteDisabled(homeTutorialStep > 0)
                            }
                            .onDelete { offsets in
                                delete(offsets, from: filteredCards)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .contentMargins(.bottom, 20, for: .scrollContent)
                }
            }
            // Keep the native Back button active while the deck remains a passive preview.
            .disabled(homeTutorialStep > 0)
            .allowsHitTesting(homeTutorialStep == 0)
        }
        .navigationTitle(deck.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if homeTutorialStep == 0 {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { withAnimation(.snappy) { isSearching.toggle(); if !isSearching { searchText = "" } } } label: {
                        Image(systemName: "magnifyingglass")
                    }.accessibilityLabel("Search cards")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showingCreateCard = true
                        } label: {
                            Label("Add Flashcard", systemImage: "plus")
                        }

                        Button {
                            showingCreateCategory = true
                        } label: {
                            Label("New Folder", systemImage: "folder.badge.plus")
                        }

                        Divider()

                        if deck.canPresentCommunitySharing {
                            Button { showingCommunityShare = true } label: {
                                Label("Share to Community", systemImage: "square.and.arrow.up")
                            }
                            .disabled(deck.cards.isEmpty)
                        }

                        Button {
                            withAnimation { isEditingDeck.toggle() }
                        } label: {
                            Label("Rename Deck", systemImage: "pencil")
                        }

                        Button { showingScheduleSettings = true } label: {
                            Label("Add custom schedule settings for this deck", systemImage: "bell.badge")
                        }

                        Button(role: .destructive) {
                            showingResetConfirmation = true
                        } label: {
                            Label("Reset Progress", systemImage: "arrow.counterclockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(LearnAlertStyle.indigo)
                    }
                }
            }
        }
        .onAppear {
            // Accessibility activation can open a NavigationLink without its tap gesture.
            if homeTutorialStep == 1 && tutorialDeckId == deck.id.uuidString {
                homeTutorialStep = 2
            }
        }
        .onDisappear {
            if homeTutorialStep == 2 {
                homeTutorialStep = 3
            }
        }
        .sheet(isPresented: $showingScheduleSettings) { DeckScheduleSettingsView(deck: deck) }
        .sheet(isPresented: $showingCreateCard) {
            CreateCardView(deck: deck)
        }
        .sheet(isPresented: $showingCommunityShare) {
            ShareDeckToCommunitySheet(libraryDecks: [deck], initialDeckID: deck.id)
        }
        .sheet(isPresented: $showingCreateCategory) {
            CreateCategoryView(deck: deck)
        }
        .sheet(item: $cardToEdit) { card in
            if card.cardType == .anki { AnkiCardEditorView(card: card) }
            else { CreateCardView(deck: deck, cardToEdit: card) }
        }
        .fullScreenCover(isPresented: $showingStudy) { NavigationStack { DeckStudyView(deck: deck) } }
        .confirmationDialog(
            "Reset all progress for this deck?",
            isPresented: $showingResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset Progress", role: .destructive) {
                deck.cards.forEach { $0.resetProgress() }
                try? context.save()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Card history, streaks, and mastery will return to their starting values. Your cards will not be deleted.")
        }
        .alert("Rename Folder", isPresented: $showingRenameFolderAlert) {
            TextField("Folder Name", text: $editingFolderName)
            Button("Save") {
                if let folder = folderBeingEdited {
                    let trimmed = editingFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        folder.name = trimmed
                        try? context.save()
                    }
                }
                folderBeingEdited = nil
            }
            Button("Cancel", role: .cancel) {
                folderBeingEdited = nil
            }
        } message: {
            Text("Enter a new name for this folder.")
        }
    }

    // MARK: - Folder Header View
    private func folderSectionHeader(section: DeckSection, count: Int) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color(hex: section.colorHex))
                .frame(width: 8, height: 8)

            Text(section.name)
                .font(.custom("Poppins-SemiBold", size: 13))
                .foregroundStyle(LearnAlertStyle.textPrimary)

            Text("(\(count))")
                .font(.custom("Poppins-Regular", size: 12))
                .foregroundStyle(LearnAlertStyle.textSecondary)

            Spacer()

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    if collapsedFolderIDs.contains(section.id) {
                        collapsedFolderIDs.remove(section.id)
                    } else {
                        collapsedFolderIDs.insert(section.id)
                    }
                }
            } label: {
                Image(systemName: collapsedFolderIDs.contains(section.id) ? "chevron.right" : "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(LearnAlertStyle.textSecondary)
            }
            .buttonStyle(.plain)

            Menu {
                Button {
                    folderBeingEdited = section
                    editingFolderName = section.name
                    showingRenameFolderAlert = true
                } label: {
                    Label("Rename", systemImage: "pencil")
                }

                Button(role: .destructive) {
                    deleteSection(section)
                } label: {
                    Label("Delete Folder", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12))
                    .foregroundStyle(LearnAlertStyle.textSecondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
        }
        .textCase(nil)
    }

    private func sectionFilterPill(title: String, tag: String, count: Int, colorHex: String? = nil) -> some View {
        let isSelected = selectedSectionFilter == tag
        return Button {
            selectedSectionFilter = tag
        } label: {
            HStack(spacing: 5) {
                if let hex = colorHex, tag != "ALL" {
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 8, height: 8)
                }
                Text(title)
                Text("\(count)")
                    .font(.custom("Poppins-Regular", size: 10))
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : LearnAlertStyle.textSecondary)
            }
            .font(.custom("Poppins-Medium", size: 12))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? LearnAlertStyle.indigo : Color.primary.opacity(0.06))
            .foregroundStyle(isSelected ? .white : LearnAlertStyle.textPrimary)
            .clipShape(Capsule())
        }
    }

    private var deckHeader: some View {
        VStack(spacing: 9) {
            HStack(spacing: 8) {
                DeckCreatureView(stableID: deck.id, appearanceSeed: deck.appearanceSeed, cardCount: deck.cards.count,
                                 compactStack: DeckCreatureAppearance.visibleLayerCount(for: deck.cards.count) >= 7)
                    .frame(width: 34, height: 28).accessibilityHidden(true)
                compactStat("Cards", value: deck.cards.count, icon: "rectangle.stack.fill", color: LearnAlertStyle.deckPrimaryAccent)
                compactStat("Due", value: cardsDueToday, icon: "clock.badge.exclamationmark", color: cardsDueToday > 0 ? .orange : .green)
                compactStat("Mastered", value: deck.cards.filter { $0.interval >= 7 }.count, icon: "checkmark.seal.fill", color: LearnAlertStyle.aqua)
            }
            HStack(spacing: 8) {
                deckAction("Add cards", icon: "plus.rectangle.on.rectangle") { showingCreateCard = true }
                deckAction("Add folder", icon: "folder.badge.plus") { showingCreateCategory = true }
                deckAction("Study", icon: "play.fill", prominent: true) { showingStudy = true }
                    .disabled(deck.cards.isEmpty)
            }
        }.padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 10)
    }

    private func compactStat(_ title: String, value: Int, icon: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 11, weight: .semibold)).foregroundStyle(color)
            Text("\(value)").font(.subheadline.weight(.semibold)).foregroundStyle(LearnAlertStyle.textPrimary)
            Text(title).font(.caption2).foregroundStyle(LearnAlertStyle.textSecondary)
        }.frame(maxWidth: .infinity).lineLimit(1).minimumScaleFactor(0.8)
            .accessibilityElement(children: .ignore).accessibilityLabel("\(value) \(title)")
    }

    private func deckAction(_ title: String, icon: String, prominent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon).font(.caption.weight(.semibold)).lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: 40)
                .foregroundStyle(prominent ? LearnAlertStyle.appAccentInk : LearnAlertStyle.textPrimary)
                .background(prominent ? LearnAlertStyle.appAccent : LearnAlertStyle.insetSurface, in: RoundedRectangle(cornerRadius: 11))
                .overlay(RoundedRectangle(cornerRadius: 11).stroke(LearnAlertStyle.cardBorder, lineWidth: 0.8))
        }.buttonStyle(.plain)
    }

    private func cardRow(_ card: Flashcard) -> some View {
        DeckCardPreviewRow(card: card) { cardToEdit = card }
            .listRowBackground(Color.clear).listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 5, leading: 0, bottom: 5, trailing: 0))
    }

    private func delete(_ offsets: IndexSet, from list: [Flashcard]) {
        let ankiFolders = Set(offsets.compactMap { list[$0].ankiContent?.mediaFolder })
        let media = offsets.flatMap { list[$0].fieldMedia.values }.enumerated().reduce(into: [String: CardFieldMedia]()) { $0[String($1.offset)] = $1.element }
        for index in offsets {
            let card = list[index]
            if let idx = deck.cards.firstIndex(where: { $0.id == card.id }) {
                let removed = deck.cards.remove(at: idx)
                context.delete(removed)
            }
        }
        if (try? context.save()) != nil {
            AnkiMediaCleanup.removeUnreferenced(ankiFolders, context: context)
            CardAttachmentCleanup.removeUnreferenced(media, context: context)
        }
    }

    private func deleteSection(_ section: DeckSection) {
        deck.cards.filter { $0.section?.id == section.id }.forEach { $0.section = nil }
        if let idx = deck.sections.firstIndex(where: { $0.id == section.id }) {
            let removed = deck.sections.remove(at: idx)
            context.delete(removed)
        }
        try? context.save()
    }
}

struct CreateCategoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let deck: Deck

    @State private var name: String = ""
    @State private var selectedColorHex: String = "#5B78C7"

    private let colors = [
        "#5B78C7", "#4D8B88", "#758D54", "#A66F78",
        "#A47D52", "#75689B", "#3B82F6", "#10B981"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Folder Name") {
                    TextField("Folder name (e.g. Chapter 1)", text: $name)
                }

                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                        ForEach(colors, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(height: 36)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: selectedColorHex == hex ? 3 : 0)
                                )
                                .shadow(radius: selectedColorHex == hex ? 4 : 0)
                                .onTapGesture {
                                    selectedColorHex = hex
                                }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("New Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            let section = DeckSection(name: trimmed, colorHex: selectedColorHex, orderIndex: deck.sections.count)
                            section.deck = deck
                            deck.sections.append(section)
                            try? context.save()
                        }
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct CardInteractivePreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let card: Flashcard
    let onEdit: () -> Void

    @State private var selectedAnswer: String? = nil
    @State private var isRevealed = false
    @State private var showHint = false
    @State private var matchingGraded = false
    private var hasImageBack: Bool { card.answerImageName?.isEmpty == false }

    var body: some View {
        NavigationStack {
            ZStack {
                LearnAlertStyle.courseCanvas
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Question card
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("CARD PREVIEW")
                                    .font(.caption.bold())
                                    .foregroundStyle(LearnAlertStyle.indigo)
                                Spacer()
                                if let section = card.section {
                                    Text(section.name)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color(hex: section.colorHex).opacity(0.2), in: Capsule())
                                }
                            }

                            if card.cardType == .anki, let content = card.ankiContent {
                                AnkiCardView(content: content, showingBack: isRevealed).frame(height: 380)
                            } else if card.cardType == .images {
                                Group {
                                    if hasImageBack {
                                        ImageCardFlipView(isShowingBack: $isRevealed) {
                                            imageFace(card.promptImageName)
                                        } back: {
                                            imageFace(card.answerImageName)
                                        }
                                    } else {
                                        imageFace(card.promptImageName)
                                    }
                                }
                                .frame(maxWidth: .infinity).frame(height: 340)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            } else {
                                CardFieldContent(text: card.question, media: card.fieldMedia["prompt"] ?? .init())
                                    .font(.headline).foregroundStyle(LearnAlertStyle.textPrimary)
                            }

                            if (card.fieldMedia["hint"] ?? .init()).hasContent(card.hint) {
                                if showHint {
                                    CardFieldContent(text: card.hint, media: card.fieldMedia["hint"] ?? .init())
                                        .font(.custom("Poppins-Regular", size: 13))
                                        .foregroundStyle(LearnAlertStyle.textSecondary)
                                        .padding(8)
                                        .background(LearnAlertStyle.indigo.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                                } else {
                                    Button("Show Hint") {
                                        withAnimation { showHint = true }
                                    }
                                    .font(.custom("Poppins-Medium", size: 12))
                                    .foregroundStyle(LearnAlertStyle.indigo)
                                }
                            }
                        }
                        .padding(18)
                        .coursezyCard()

                        // Options / Answer
                        if card.cardType == .multipleChoice {
                            CardMediaChoiceList(options: card.options, fields: card.fieldMedia,
                                correctIndex: card.resolvedCorrectOptionIndex, selection: selectedAnswer,
                                isGraded: selectedAnswer != nil) { selectedAnswer = $0 }
                        } else if card.cardType == .matching {
                            CardMediaMatchingBoard(left: card.matchingLeftItems, right: card.matchingRightItems,
                                fields: card.fieldMedia, isGraded: matchingGraded) { _ in matchingGraded = true }
                        } else if card.cardType == .anki {
                            Button(isRevealed ? "Show front" : "Show answer") {
                                withAnimation(.snappy) { isRevealed.toggle() }
                            }.buttonStyle(PrimaryActionButtonStyle())
                        } else if card.cardType != .images {
                            VStack(spacing: 12) {
                                if isRevealed {
                                    CardFieldContent(text: card.correctAnswer, media: card.fieldMedia["answer"] ?? .init())
                                        .font(.custom("Poppins-SemiBold", size: 16))
                                        .foregroundStyle(LearnAlertStyle.aqua)
                                        .padding()
                                } else {
                                    Button("Tap to Reveal Answer") {
                                        withAnimation { isRevealed = true }
                                    }
                                    .buttonStyle(PrimaryActionButtonStyle())
                                }
                            }
                            .padding(18)
                            .coursezyCard()
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Flashcard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Edit") {
                        dismiss()
                        onEdit()
                    }
                }
            }
        }
    }

    @ViewBuilder private func imageFace(_ name: String?) -> some View {
        if let image = CardImageStore.loadImage(named: name) {
            Image(uiImage: image).resizable().scaledToFit()
        } else {
            ContentUnavailableView("Image unavailable", systemImage: "photo",
                description: Text("Edit this card to upload the picture again."))
        }
    }

    private func backgroundColor(for option: String) -> Color {
        guard let selected = selectedAnswer else {
            return LearnAlertStyle.courseSurface
        }
        if option == card.correctAnswer {
            return Color.green.opacity(0.15)
        } else if option == selected {
            return Color.red.opacity(0.15)
        }
        return LearnAlertStyle.courseSurface
    }

    private func textColor(for option: String) -> Color {
        LearnAlertStyle.textPrimary
    }

    private func borderColor(for option: String) -> Color {
        guard let selected = selectedAnswer else {
            return LearnAlertStyle.glassStroke
        }
        if option == card.correctAnswer {
            return Color.green
        } else if option == selected {
            return Color.red
        }
        return LearnAlertStyle.glassStroke
    }
}

private struct DeckTutorialGuideBar: View {
    let onBack: () -> Void
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LearnAlertStyle.indigo.opacity(0.25))
                    .frame(width: 38, height: 38)
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(LearnAlertStyle.sky)
                    .scaleEffect(pulse ? 1.15 : 0.95)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("STEP 2 OF 3")
                        .font(.custom("Poppins-SemiBold", size: 10))
                        .foregroundStyle(LearnAlertStyle.sky)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(LearnAlertStyle.sky.opacity(0.14), in: Capsule())
                    Text("Inspect Flashcards")
                        .font(.custom("Poppins-SemiBold", size: 12))
                        .foregroundStyle(LearnAlertStyle.textPrimary)
                }

                Text("Tap ‹ Back at the top to return and schedule your alerts!")
                    .font(.custom("Poppins-Regular", size: 11))
                    .foregroundStyle(LearnAlertStyle.textSecondary)
            }

            Spacer()

            Button(action: onBack) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .bold))
                    Text("Back")
                        .font(.custom("Poppins-SemiBold", size: 12))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(LearnAlertStyle.indigo)
                .clipShape(Capsule())
                .shadow(color: LearnAlertStyle.indigo.opacity(0.4), radius: 6, y: 2)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LearnAlertStyle.courseSurface)
        )
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
        .shadow(color: LearnAlertStyle.sky.opacity(0.25), radius: 12, y: 5)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}
