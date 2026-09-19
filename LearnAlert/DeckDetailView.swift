import SwiftUI
import SwiftData

struct DeckDetailView: View {
    @Bindable var deck: Deck
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var showingCreateCard = false
    @State private var showingCreateCategory = false
    @State private var isEditingDeck = false
    @State private var cardToEdit: Flashcard?
    @State private var cardToPreview: Flashcard?
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
                // Header & Stats
                VStack(spacing: 12) {
                    DeckCreatureView(
                        stableID: deck.id,
                        appearanceSeed: deck.appearanceSeed,
                        cardCount: deck.cards.count
                    )
                    .frame(width: 124, height: 96)

                    HStack(spacing: 10) {
                        StatBox(
                            title: "CARDS",
                            value: "\(deck.cards.count)",
                            color: LearnAlertStyle.deckPrimaryAccent,
                            icon: "rectangle.stack.fill"
                        )
                        StatBox(
                            title: "DUE",
                            value: "\(cardsDueToday)",
                            color: cardsDueToday > 0 ? Color.orange : Color.green,
                            icon: "clock.badge.exclamationmark"
                        )
                        StatBox(
                            title: "MASTERED",
                            value: "\(deck.cards.filter { $0.interval >= 7 }.count)",
                            color: LearnAlertStyle.aqua,
                            icon: "checkmark.seal.fill"
                        )
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.top, 6)
                .padding(.bottom, 12)

                // Inline Rename Deck Banner
                if isEditingDeck {
                    HStack(spacing: 10) {
                        TextField("Deck Name", text: $deck.name)
                            .font(.custom("Poppins-SemiBold", size: 15))
                            .foregroundStyle(LearnAlertStyle.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.primary.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                        Button("Done") {
                            withAnimation(.snappy) { isEditingDeck = false }
                            try? context.save()
                        }
                        .font(.custom("Poppins-SemiBold", size: 13))
                        .foregroundStyle(LearnAlertStyle.indigo)
                    }
                    .padding(14)
                    .settingsGlassSurface(cornerRadius: 16)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }

                // Section Filter & Search Bar
                VStack(spacing: 10) {
                    // Category Filter Pills
                    if !deck.sections.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                categoryFilterChip(title: "All", count: deck.cards.count, tag: "ALL")

                                ForEach(orderedSections) { section in
                                    categoryFilterChip(
                                        title: section.name,
                                        count: section.cards.count,
                                        tag: section.id.uuidString,
                                        colorHex: section.colorHex
                                    )
                                }

                                Button {
                                    showingCreateCategory = true
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus")
                                        Text("Category")
                                    }
                                    .font(.custom("Poppins-Medium", size: 12))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(LearnAlertStyle.deckPrimaryAccent.opacity(0.08))
                                    .foregroundStyle(LearnAlertStyle.deckPrimaryAccent)
                                    .clipShape(Capsule())
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }

                    // Search field (if more than 3 cards)
                    if deck.cards.count > 3 {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 13))
                                .foregroundStyle(LearnAlertStyle.textSecondary)

                            TextField("Search cards in deck...", text: $searchText)
                                .font(.custom("Poppins-Regular", size: 13))
                                .foregroundStyle(LearnAlertStyle.textPrimary)

                            if !searchText.isEmpty {
                                Button {
                                    searchText = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(LearnAlertStyle.textSecondary)
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.primary.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(LearnAlertStyle.hairline.opacity(0.3), lineWidth: 0.75)
                        )
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 8)

                // Cards List
                List {
                    if deck.cards.isEmpty {
                        VStack(spacing: 14) {
                            Image(systemName: "rectangle.stack.badge.plus")
                                .font(.system(size: 40))
                                .foregroundStyle(LearnAlertStyle.indigo.opacity(0.7))
                            Text("No Cards Yet")
                                .font(.custom("Poppins-SemiBold", size: 18))
                                .foregroundStyle(LearnAlertStyle.textPrimary)
                            Text("Tap \"+ New Card\" below to add your first quiz, tap-to-reveal, or matching card.")
                                .font(.custom("Poppins-Regular", size: 13))
                                .foregroundStyle(LearnAlertStyle.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)


                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 36)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    } else if filteredCards.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .font(.title2)
                                .foregroundStyle(LearnAlertStyle.textSecondary)
                            Text("No matching cards")
                                .font(.custom("Poppins-Medium", size: 14))
                                .foregroundStyle(LearnAlertStyle.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    } else if deck.sections.isEmpty {
                        ForEach(filteredCards) { card in
                            cardRow(card)
                        }
                        .onDelete { offsets in
                            delete(offsets, from: filteredCards)
                        }
                    } else {
                        // Display folders with collapsible headers & pencil edit button (auto-opened by default)
                        ForEach(orderedSections) { section in
                            let sectionCards = filteredCards.filter { $0.section?.id == section.id }
                            let isCollapsed = collapsedFolderIDs.contains(section.id)

                            if !sectionCards.isEmpty || searchText.isEmpty {
                                Section {
                                    if !isCollapsed {
                                        if sectionCards.isEmpty {
                                            Text("No cards in this folder")
                                                .font(.custom("Poppins-Regular", size: 12))
                                                .foregroundStyle(LearnAlertStyle.textSecondary.opacity(0.6))
                                                .padding(.vertical, 8)
                                                .listRowBackground(Color.clear)
                                        } else {
                                            ForEach(sectionCards) { card in
                                                cardRow(card)
                                            }
                                            .onDelete { offsets in
                                                delete(offsets, from: sectionCards)
                                            }
                                        }
                                    }
                                } header: {
                                    folderHeaderView(section: section, cardCount: sectionCards.count, isCollapsed: isCollapsed)
                                }
                            }
                        }

                        let unassignedCards = filteredCards.filter { $0.section == nil }
                        if !unassignedCards.isEmpty {
                            Section {
                                ForEach(unassignedCards) { card in
                                    cardRow(card)
                                }
                                .onDelete { offsets in
                                    delete(offsets, from: unassignedCards)
                                }
                            } header: {
                                HStack(spacing: 6) {
                                    Image(systemName: "rectangle.stack")
                                        .font(.system(size: 11))
                                        .foregroundStyle(LearnAlertStyle.textSecondary)
                                    Text("Other Cards (\(unassignedCards.count))")
                                        .font(.custom("Poppins-SemiBold", size: 12))
                                        .foregroundStyle(LearnAlertStyle.textSecondary)
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                                .textCase(nil)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)

                // Floating Bottom Action Bar
                HStack(spacing: 10) {
                    NavigationLink(destination: DeckStudyView(deck: deck)) {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                                .font(.subheadline.bold())
                            Text("Study (\(deck.cards.count))")
                                .font(.custom("Poppins-SemiBold", size: 14))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .foregroundStyle(.white)
                        .background(
                            deck.cards.isEmpty
                                ? AnyShapeStyle(Color.gray.opacity(0.30))
                                : AnyShapeStyle(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.12, green: 0.50, blue: 0.98),
                                            Color(red: 0.18, green: 0.65, blue: 0.96)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(deck.cards.isEmpty ? Color.clear : Color.white.opacity(0.28), lineWidth: 1)
                        )
                        .shadow(
                            color: deck.cards.isEmpty ? Color.clear : Color(red: 0.12, green: 0.50, blue: 0.98).opacity(0.35),
                            radius: 10,
                            y: 4
                        )
                    }
                    .disabled(deck.cards.isEmpty)

                    Button {
                        showingCreateCard = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 15, weight: .bold))
                            Text("Add Card")
                                .font(.custom("Poppins-SemiBold", size: 14))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .foregroundStyle(LearnAlertStyle.deckPrimaryAccent)
                        .background(LearnAlertStyle.deckPrimaryAccent.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(LearnAlertStyle.deckPrimaryAccent.opacity(0.32), lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    Rectangle()
                        .fill(LearnAlertStyle.courseCanvas.opacity(0.92))
                        .ignoresSafeArea()
                )
            }
        }
        .navigationTitle(deck.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(LearnAlertStyle.courseCanvas, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Edit Deck Title", systemImage: "pencil") {
                        withAnimation(.snappy) { isEditingDeck = true }
                    }
                    Button("Add Category", systemImage: "folder.badge.plus") {
                        showingCreateCategory = true
                    }
                    Button("Shuffle Appearance", systemImage: "shuffle") {
                        deck.appearanceSeed = DeckCreatureAppearance.newSavedSeed(excluding: deck.appearanceSeed)
                        try? context.save()
                    }
                    Button("Reset Progress", systemImage: "arrow.counterclockwise") {
                        showingResetConfirmation = true
                    }
                    Button("Delete Deck", role: .destructive) {
                        InteractionSoundPlayer.shared.play(.deleteDeck)
                        context.delete(deck)
                        dismiss()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 18))
                        .foregroundStyle(LearnAlertStyle.textPrimary)
                }
            }
        }
        .sheet(isPresented: $showingCreateCard) {
            CreateCardView(deck: deck)
        }
        .sheet(isPresented: $showingCreateCategory) {
            CreateCategoryView(deck: deck)
        }
        .sheet(item: $cardToEdit) { card in
            CreateCardView(deck: deck, cardToEdit: card)
        }
        .sheet(item: $cardToPreview) { card in
            CardInteractivePreviewSheet(card: card) {
                cardToPreview = nil
                cardToEdit = card
            }
        }
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
    private func folderHeaderView(section: DeckSection, cardCount: Int, isCollapsed: Bool) -> some View {
        HStack(spacing: 8) {
            Button {
                withAnimation(.snappy(duration: 0.2)) {
                    if isCollapsed {
                        collapsedFolderIDs.remove(section.id)
                    } else {
                        collapsedFolderIDs.insert(section.id)
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(LearnAlertStyle.textSecondary)
                        .frame(width: 14)

                    Image(systemName: isCollapsed ? "folder.fill" : "folder.badge.gearshape.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(hex: section.colorHex))

                    Text(section.name)
                        .font(.custom("Poppins-SemiBold", size: 13))
                        .foregroundStyle(LearnAlertStyle.textPrimary)
                        .lineLimit(1)

                    Text("(\(cardCount))")
                        .font(.custom("Poppins-Medium", size: 12))
                        .foregroundStyle(LearnAlertStyle.textSecondary)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                folderBeingEdited = section
                editingFolderName = section.name
                showingRenameFolderAlert = true
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(LearnAlertStyle.textSecondary)
                    .padding(6)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Rename folder \(section.name)")
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .textCase(nil)
    }

    // MARK: - Category Filter Chip
    private func categoryFilterChip(title: String, count: Int, tag: String, colorHex: String? = nil) -> some View {
        let isSelected = selectedSectionFilter == tag
        return Button {
            withAnimation(.snappy) { selectedSectionFilter = tag }
        } label: {
            HStack(spacing: 5) {
                if let colorHex {
                    Circle()
                        .fill(Color(hex: colorHex))
                        .frame(width: 7, height: 7)
                }
                Text(title)
                Text("(\(count))")
                    .font(.caption2.monospacedDigit())
                    .opacity(0.8)
            }
            .font(.custom("Poppins-Medium", size: 12))
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(
                isSelected
                    ? AnyShapeStyle(
                        LinearGradient(
                            colors: [LearnAlertStyle.deckPrimaryAccent, Color(red: 0.20, green: 0.68, blue: 0.95)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    : AnyShapeStyle(Color.primary.opacity(0.05))
            )
            .foregroundStyle(isSelected ? Color.white : LearnAlertStyle.textPrimary)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(isSelected ? Color.white.opacity(0.2) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Card Row
    @ViewBuilder
    private func cardRow(_ card: Flashcard) -> some View {
        CardRowView(card: card) {
            cardToPreview = card
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                context.delete(card)
                try? context.save()
            } label: {
                Label("Delete", systemImage: "trash")
            }
            Button {
                cardToEdit = card
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.indigo)
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
    }

    private func delete(_ offsets: IndexSet, from cards: [Flashcard]) {
        for index in offsets {
            context.delete(cards[index])
        }
        try? context.save()
    }
}

// MARK: - Modern Glassy CardRowView
struct CardRowView: View {
    let card: Flashcard
    let onPreview: () -> Void

    private var mastery: (text: String, color: Color) {
        if card.isNew { return ("New", Color.cyan) }
        if card.interval == 0 { return ("Learning", Color.red) }
        if card.interval < 7 { return ("Reviewing", Color.orange) }
        return ("Mastered", Color.green)
    }

    private var typeColor: Color {
        switch card.cardType {
        case .multipleChoice: LearnAlertStyle.indigo
        case .tapReveal: LearnAlertStyle.aqua
        case .matching: Color.purple
        case .fillBlank: Color.orange
        }
    }

    var body: some View {
        Button(action: onPreview) {
            VStack(alignment: .leading, spacing: 10) {
                // Header: Card Type + Section Tag + Mastery
                HStack(spacing: 8) {
                    HStack(spacing: 5) {
                        Image(systemName: card.cardType.icon)
                            .font(.system(size: 10, weight: .bold))
                        Text(card.cardType.title)
                            .font(.custom("Poppins-SemiBold", size: 10))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(typeColor.opacity(0.12))
                    .foregroundStyle(typeColor)
                    .clipShape(Capsule())



                    Spacer()

                    Text(mastery.text)
                        .font(.custom("Poppins-SemiBold", size: 10))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3.5)
                        .background(mastery.color.opacity(0.15))
                        .foregroundStyle(mastery.color)
                        .clipShape(Capsule())
                }

                // Prompt / Question (Auto-fallback for matching)
                Text(card.question.isEmpty && card.cardType == .matching ? "Match the correct pairs" : card.question)
                    .font(.custom("Poppins-SemiBold", size: 14, relativeTo: .body))
                    .foregroundStyle(LearnAlertStyle.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                // Dynamic Preview Content by Card Type
                cardDynamicPreview

                // Hint tag if present
                if !card.hint.isEmpty {
                    HStack(spacing: 5) {
                        Image(systemName: "lightbulb.fill")
                            .font(.caption2)
                            .foregroundStyle(Color.yellow)
                        Text(card.hint)
                            .font(.custom("Poppins-Regular", size: 11))
                            .foregroundStyle(LearnAlertStyle.textSecondary)
                            .lineLimit(1)
                    }
                    .padding(.top, 2)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .settingsGlassSurface(cornerRadius: 16)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var cardDynamicPreview: some View {
        switch card.cardType {
        case .multipleChoice:
            VStack(alignment: .leading, spacing: 6) {
                // Correct Answer pill
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.green)
                    Text("Answer: \(card.correctAnswer)")
                        .font(.custom("Poppins-Medium", size: 12))
                        .foregroundStyle(Color.green)
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.green.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                // Alternate choices preview
                let alternates = card.options.filter { $0 != card.correctAnswer && !$0.isEmpty }
                if !alternates.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(alternates, id: \.self) { choice in
                                Text(choice)
                                    .font(.custom("Poppins-Regular", size: 11))
                                    .foregroundStyle(LearnAlertStyle.textSecondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3.5)
                                    .background(Color.primary.opacity(0.04))
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            }
                        }
                    }
                }
            }

        case .tapReveal:
            HStack(spacing: 8) {
                Image(systemName: "eye.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(LearnAlertStyle.aqua)
                Text(card.correctAnswer.isEmpty ? "Tap to reveal answer" : card.correctAnswer)
                    .font(.custom("Poppins-Medium", size: 12))
                    .foregroundStyle(LearnAlertStyle.textPrimary)
                    .lineLimit(2)
                Spacer()
                Image(systemName: "hand.tap")
                    .font(.caption2)
                    .foregroundStyle(LearnAlertStyle.textSecondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(LearnAlertStyle.aqua.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(LearnAlertStyle.aqua.opacity(0.2), lineWidth: 0.75)
            )

        case .matching:
            let lefts = card.matchingLeftItems
            let rights = card.matchingRightItems
            let pairCount = min(lefts.count, rights.count)

            if pairCount > 0 {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(0..<min(pairCount, 3), id: \.self) { idx in
                        HStack(spacing: 6) {
                            Text(lefts[idx])
                                .font(.custom("Poppins-Medium", size: 11))
                                .foregroundStyle(LearnAlertStyle.textPrimary)
                                .lineLimit(1)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3.5)
                                .background(Color.primary.opacity(0.04))
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                            Image(systemName: "arrow.left.arrow.right")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color.purple)

                            Text(rights[idx])
                                .font(.custom("Poppins-Medium", size: 11))
                                .foregroundStyle(Color.purple)
                                .lineLimit(1)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3.5)
                                .background(Color.purple.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                    }

                    if pairCount > 3 {
                        Text("+ \(pairCount - 3) more pair\(pairCount - 3 > 1 ? "s" : "")")
                            .font(.custom("Poppins-Regular", size: 10))
                            .foregroundStyle(LearnAlertStyle.textSecondary)
                            .padding(.leading, 4)
                    }
                }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.caption2)
                        .foregroundStyle(Color.purple)
                    Text("Interactive matching pairs")
                        .font(.custom("Poppins-Regular", size: 11))
                        .foregroundStyle(LearnAlertStyle.textSecondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.purple.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

        case .fillBlank:
            HStack(spacing: 7) {
                Image(systemName: "text.cursor")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.orange)
                Text("Blank: \(card.correctAnswer)")
                    .font(.custom("Poppins-Medium", size: 12))
                    .foregroundStyle(Color.orange)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.orange.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

// MARK: - Interactive Card Full Preview Sheet
private struct CardInteractivePreviewSheet: View {
    let card: Flashcard
    let onEdit: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedAnswer: String?
    @State private var isRevealed = false
    @State private var matchingSelections: [String: String] = [:]
    @State private var selectedMatchingLeft: String?
    @State private var fillBlankInput = ""
    @State private var fillBlankChecked = false
    @State private var showingHint = false

    var body: some View {
        NavigationStack {
            ZStack {
                LearnAlertStyle.courseCanvas
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Card Type & Info Header
                        HStack {
                            Label(card.cardType.title, systemImage: card.cardType.icon)
                                .font(.custom("Poppins-SemiBold", size: 12))
                                .foregroundStyle(LearnAlertStyle.indigo)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(LearnAlertStyle.indigo.opacity(0.12))
                                .clipShape(Capsule())

                            Spacer()

                            if !card.hint.isEmpty {
                                Button {
                                    withAnimation(.snappy) { showingHint.toggle() }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "lightbulb.fill")
                                        Text(showingHint ? "Hide Hint" : "Hint")
                                    }
                                    .font(.custom("Poppins-Medium", size: 12))
                                    .foregroundStyle(Color.yellow)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.yellow.opacity(0.15))
                                    .clipShape(Capsule())
                                }
                            }
                        }

                        if showingHint && !card.hint.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundStyle(Color.yellow)
                                Text(card.hint)
                                    .font(.custom("Poppins-Regular", size: 13))
                                    .foregroundStyle(LearnAlertStyle.textPrimary)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .settingsGlassSurface(cornerRadius: 12)
                        }

                        // Question Prompt
                        Text(card.question.isEmpty && card.cardType == .matching ? "Match the correct pairs" : card.question)
                            .font(.custom("Poppins-SemiBold", size: 20, relativeTo: .title3))
                            .foregroundStyle(LearnAlertStyle.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        // Interactive Playground
                        VStack(alignment: .leading, spacing: 14) {
                            switch card.cardType {
                            case .multipleChoice:
                                interactiveQuizSection
                            case .tapReveal:
                                interactiveRevealSection
                            case .matching:
                                interactiveMatchingSection
                            case .fillBlank:
                                interactiveFillBlankSection
                            }
                        }
                        .padding(16)
                        .settingsGlassSurface(cornerRadius: 18)

                        // Stats Summary Glass Box
                        VStack(alignment: .leading, spacing: 10) {
                            Text("CARD MEMORY STATS")
                                .font(.caption.bold())
                                .foregroundStyle(LearnAlertStyle.textSecondary)

                            HStack(spacing: 12) {
                                statPill(label: "Correct", value: "\(card.correctCount)", color: Color.green)
                                statPill(label: "Mistakes", value: "\(card.incorrectCount)", color: Color.red)
                                statPill(label: "Streak", value: "\(card.currentStreak)", color: LearnAlertStyle.indigo)
                                statPill(label: "Interval", value: "\(card.interval)d", color: LearnAlertStyle.aqua)
                            }
                        }
                        .padding(16)
                        .settingsGlassSurface(cornerRadius: 18)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Card Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(LearnAlertStyle.courseCanvas, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(LearnAlertStyle.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                        onEdit()
                    } label: {
                        Label("Edit", systemImage: "pencil")
                            .font(.custom("Poppins-SemiBold", size: 14))
                            .foregroundStyle(LearnAlertStyle.indigo)
                    }
                }
            }
        }
    }

    private func statPill(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.custom("Poppins-Regular", size: 10))
                .foregroundStyle(LearnAlertStyle.textSecondary)
            Text(value)
                .font(.custom("Poppins-SemiBold", size: 15))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Multiple Choice interactive preview
    private var interactiveQuizSection: some View {
        VStack(spacing: 10) {
            ForEach(card.options, id: \.self) { option in
                quizOptionButton(option: option)
            }
        }
    }

    private func quizOptionButton(option: String) -> some View {
        let isSelected = selectedAnswer == option
        let isCorrect = option == card.correctAnswer

        return Button {
            withAnimation(.snappy) { selectedAnswer = option }
        } label: {
            HStack {
                Text(option)
                    .font(.custom("Poppins-Medium", size: 14))
                    .foregroundStyle(quizOptionTextColor(isSelected: isSelected, isCorrect: isCorrect))
                Spacer()
                if selectedAnswer != nil {
                    Image(systemName: isCorrect ? "checkmark.circle.fill" : (isSelected ? "xmark.circle.fill" : "circle"))
                        .foregroundStyle(isCorrect ? Color.green : (isSelected ? Color.red : Color.clear))
                }
            }
            .padding(14)
            .background(quizOptionBackground(isSelected: isSelected, isCorrect: isCorrect))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(quizOptionBorder(isSelected: isSelected, isCorrect: isCorrect), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func quizOptionTextColor(isSelected: Bool, isCorrect: Bool) -> Color {
        guard selectedAnswer != nil else { return LearnAlertStyle.textPrimary }
        if isCorrect { return Color.green }
        if isSelected { return Color.red }
        return LearnAlertStyle.textSecondary
    }

    private func quizOptionBackground(isSelected: Bool, isCorrect: Bool) -> Color {
        guard selectedAnswer != nil else { return Color.primary.opacity(0.04) }
        if isCorrect { return Color.green.opacity(0.12) }
        if isSelected { return Color.red.opacity(0.12) }
        return Color.primary.opacity(0.02)
    }

    private func quizOptionBorder(isSelected: Bool, isCorrect: Bool) -> Color {
        guard selectedAnswer != nil else { return LearnAlertStyle.hairline.opacity(0.3) }
        if isCorrect { return Color.green.opacity(0.4) }
        if isSelected { return Color.red.opacity(0.4) }
        return Color.clear
    }

    // MARK: - Tap Reveal interactive preview
    private var interactiveRevealSection: some View {
        VStack(spacing: 14) {
            if isRevealed {
                VStack(spacing: 8) {
                    Text("REVEALED ANSWER")
                        .font(.caption.bold())
                        .foregroundStyle(LearnAlertStyle.textSecondary)
                    Text(card.correctAnswer)
                        .font(.custom("Poppins-SemiBold", size: 18))
                        .foregroundStyle(LearnAlertStyle.textPrimary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(LearnAlertStyle.aqua.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(LearnAlertStyle.aqua.opacity(0.3), lineWidth: 1)
                )

                Button("Hide Answer") {
                    withAnimation(.snappy) { isRevealed = false }
                }
                .font(.custom("Poppins-Medium", size: 12))
                .foregroundStyle(LearnAlertStyle.textSecondary)
            } else {
                Button {
                    withAnimation(.snappy) { isRevealed = true }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "hand.tap.fill")
                        Text("Tap to Reveal Answer")
                    }
                    .font(.custom("Poppins-SemiBold", size: 14))
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .foregroundStyle(LearnAlertStyle.aqua)
                    .background(LearnAlertStyle.aqua.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(LearnAlertStyle.aqua.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Matching interactive preview with tap-to-match
    private var interactiveMatchingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Tap a left item, then tap its right match:")
                .font(.custom("Poppins-Regular", size: 12))
                .foregroundStyle(LearnAlertStyle.textSecondary)

            let lefts = card.matchingLeftItems
            let rights = card.matchingRightItems

            HStack(alignment: .top, spacing: 12) {
                // Left Items Column
                VStack(spacing: 8) {
                    ForEach(lefts, id: \.self) { item in
                        matchingLeftCell(item: item)
                    }
                }

                // Right Items Column
                VStack(spacing: 8) {
                    ForEach(rights, id: \.self) { target in
                        matchingRightCell(target: target, lefts: lefts, rights: rights)
                    }
                }
            }

            if !matchingSelections.isEmpty {
                Button("Reset Matches") {
                    withAnimation(.snappy) { matchingSelections = [:] }
                }
                .font(.custom("Poppins-Medium", size: 11))
                .foregroundStyle(LearnAlertStyle.textSecondary)
            }
        }
    }

    private func matchingLeftCell(item: String) -> some View {
        let isSelected = selectedMatchingLeft == item
        let isPaired = matchingSelections.values.contains(item)
        let strokeColor: Color = isSelected ? LearnAlertStyle.indigo : (isPaired ? Color.green.opacity(0.5) : LearnAlertStyle.hairline.opacity(0.3))

        return Button {
            withAnimation(.snappy) {
                selectedMatchingLeft = (selectedMatchingLeft == item ? nil : item)
            }
        } label: {
            Text(item)
                .font(.custom("Poppins-Medium", size: 13))
                .foregroundStyle(LearnAlertStyle.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.horizontal, 8)
                .background(isSelected ? LearnAlertStyle.indigo.opacity(0.2) : Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(strokeColor, lineWidth: isSelected ? 2 : 1))
                .opacity(isPaired && !isSelected ? 0.45 : 1)
        }
        .buttonStyle(.plain)
    }

    private func matchingRightCell(target: String, lefts: [String], rights: [String]) -> some View {
        let pairedLeft = matchingSelections[target]
        let isCorrect = pairedLeft != nil && lefts.firstIndex(of: pairedLeft!) == rights.firstIndex(of: target)
        let bg = pairedLeft != nil ? (isCorrect ? Color.green.opacity(0.12) : Color.orange.opacity(0.12)) : Color.primary.opacity(0.04)
        let border = pairedLeft != nil ? (isCorrect ? Color.green : Color.orange) : LearnAlertStyle.hairline.opacity(0.3)

        return Button {
            withAnimation(.snappy) {
                if let selected = selectedMatchingLeft {
                    matchingSelections = matchingSelections.filter { $0.value != selected }
                    matchingSelections[target] = selected
                    selectedMatchingLeft = nil
                } else if matchingSelections[target] != nil {
                    matchingSelections.removeValue(forKey: target)
                }
            }
        } label: {
            VStack(spacing: 2) {
                Text(target)
                    .font(.custom("Poppins-Medium", size: 13))
                    .foregroundStyle(LearnAlertStyle.textPrimary)
                if let paired = pairedLeft {
                    Text(paired)
                        .font(.custom("Poppins-SemiBold", size: 10))
                        .foregroundStyle(isCorrect ? Color.green : Color.orange)
                } else {
                    Text("Drop / Tap here")
                        .font(.custom("Poppins-Regular", size: 9))
                        .foregroundStyle(LearnAlertStyle.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 8)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Fill in the Blank interactive preview
    private var fillBlankBorderColor: Color {
        guard fillBlankChecked else { return LearnAlertStyle.hairline.opacity(0.3) }
        let cleanInput = fillBlankInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let isCorrect = cleanInput.localizedCaseInsensitiveCompare(card.correctAnswer) == .orderedSame
        return isCorrect ? Color.green : Color.red
    }

    private var interactiveFillBlankSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Type your answer here...", text: $fillBlankInput)
                .font(.custom("Poppins-Medium", size: 14))
                .foregroundStyle(LearnAlertStyle.textPrimary)
                .padding(12)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(fillBlankBorderColor, lineWidth: 1)
                )

            if fillBlankChecked {
                let isCorrect = fillBlankInput.trimmingCharacters(in: .whitespacesAndNewlines).localizedCaseInsensitiveCompare(card.correctAnswer) == .orderedSame
                HStack(spacing: 6) {
                    Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(isCorrect ? Color.green : Color.red)
                    Text(isCorrect ? "Correct!" : "Expected: \(card.correctAnswer)")
                        .font(.custom("Poppins-SemiBold", size: 13))
                        .foregroundStyle(isCorrect ? Color.green : Color.red)
                }
            } else {
                Button("Check Answer") {
                    withAnimation(.snappy) { fillBlankChecked = true }
                }
                .font(.custom("Poppins-SemiBold", size: 13))
                .foregroundStyle(LearnAlertStyle.indigo)
            }
        }
    }
}

// MARK: - StatBox
struct StatBox: View {
    let title: String
    let value: String
    let color: Color
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.custom("Poppins-SemiBold", size: 10))
                    .foregroundStyle(LearnAlertStyle.textSecondary)
            }
            Text(value)
                .font(.custom("Poppins-SemiBold", size: 20))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .settingsGlassSurface(cornerRadius: 16)
    }
}

// MARK: - CreateCategoryView
private struct CreateCategoryView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let deck: Deck

    @State private var name = ""
    @State private var colorHex = "#5B78C7"

    private let colors = ["#5B78C7", "#4D8B88", "#758D54", "#A66F78", "#A47D52", "#75689B"]

    var body: some View {
        NavigationStack {
            ZStack {
                LearnAlertStyle.courseCanvas
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("CATEGORY NAME")
                            .font(.caption.bold())
                            .foregroundStyle(LearnAlertStyle.textSecondary)

                        TextField("e.g. Verbs, Formulas, Chapter 1", text: $name)
                            .font(.custom("Poppins-Medium", size: 15))
                            .foregroundStyle(LearnAlertStyle.textPrimary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color.primary.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(LearnAlertStyle.hairline.opacity(0.3), lineWidth: 0.75)
                            )
                    }
                    .padding(18)
                    .settingsGlassSurface(cornerRadius: 18)

                    VStack(alignment: .leading, spacing: 14) {
                        Text("ACCENT COLOR")
                            .font(.caption.bold())
                            .foregroundStyle(LearnAlertStyle.textSecondary)

                        HStack(spacing: 12) {
                            ForEach(colors, id: \.self) { hex in
                                Button {
                                    colorHex = hex
                                } label: {
                                    Circle()
                                        .fill(Color(hex: hex))
                                        .frame(width: 36, height: 36)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: colorHex == hex ? 3 : 0)
                                        )
                                        .shadow(color: colorHex == hex ? Color(hex: hex).opacity(0.4) : Color.clear, radius: 4)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(18)
                    .settingsGlassSurface(cornerRadius: 18)

                    Spacer()

                    Button {
                        let section = DeckSection(
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            colorHex: colorHex,
                            orderIndex: deck.sections.count
                        )
                        deck.sections.append(section)
                        try? context.save()
                        dismiss()
                    } label: {
                        Label("Add Category", systemImage: "folder.badge.plus")
                            .font(.custom("Poppins-SemiBold", size: 15))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                    .foregroundStyle(.white)
                    .background(
                        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? AnyShapeStyle(Color.gray.opacity(0.35))
                            : AnyShapeStyle(Color(hex: colorHex))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(20)
            }
            .navigationTitle("New Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(LearnAlertStyle.courseCanvas, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(LearnAlertStyle.textSecondary)
                }
            }
        }
    }
}
