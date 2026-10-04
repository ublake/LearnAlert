import SwiftUI
import SwiftData

struct DeckDetailView: View {
    @Bindable var deck: Deck
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage("homeTutorialStep") private var homeTutorialStep: Int = 0

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
                if homeTutorialStep == 2 {
                    HStack(spacing: 6) {
                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text("Step 2 of 3: Tap ‹ Back above to schedule alerts")
                            .font(.custom("Poppins-SemiBold", size: 11))
                        Image(systemName: "arrow.up.left")
                            .font(.system(size: 10, weight: .bold))
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

                // Search Bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(LearnAlertStyle.textSecondary)
                    TextField("Search cards...", text: $searchText)
                        .font(.custom("Poppins-Regular", size: 14))
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
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(LearnAlertStyle.courseSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(LearnAlertStyle.hairline.opacity(0.4), lineWidth: 1)
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                // Category / Section Filter Pills
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
                            }
                            .onDelete { offsets in
                                delete(offsets, from: filteredCards)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .navigationTitle(deck.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if homeTutorialStep == 2 {
                    Button {
                        withAnimation(.snappy) {
                            homeTutorialStep = 0
                        }
                    } label: {
                        Text("Skip Tour")
                            .font(.custom("Poppins-Medium", size: 14, relativeTo: .body))
                            .foregroundStyle(LearnAlertStyle.textSecondary)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 4)
                    }
                    .buttonStyle(.plain)
                } else {
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

                        Button {
                            withAnimation { isEditingDeck.toggle() }
                        } label: {
                            Label("Rename Deck", systemImage: "pencil")
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
        .onDisappear {
            if homeTutorialStep == 2 {
                homeTutorialStep = 3
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

    private func cardRow(_ card: Flashcard) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    if let section = card.section {
                        HStack(spacing: 3) {
                            Circle()
                                .fill(Color(hex: section.colorHex))
                                .frame(width: 6, height: 6)
                            Text(section.name)
                                .font(.custom("Poppins-Medium", size: 10))
                                .foregroundStyle(LearnAlertStyle.textSecondary)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.04), in: Capsule())
                    }

                    if card.interval >= 7 {
                        Label("Mastered", systemImage: "checkmark.seal.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(LearnAlertStyle.aqua)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(LearnAlertStyle.aqua.opacity(0.12), in: Capsule())
                    }

                    if card.promptImageName != nil || !card.optionImageNames.filter({ !$0.isEmpty }).isEmpty {
                        Image(systemName: "photo.fill")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(LearnAlertStyle.indigo)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(LearnAlertStyle.indigo.opacity(0.12), in: Capsule())
                    }
                }

                Text(card.question)
                    .font(.custom("Poppins-Medium", size: 14))
                    .foregroundStyle(LearnAlertStyle.textPrimary)
                    .lineLimit(3)

                Text("Answer: \(card.correctAnswer)")
                    .font(.custom("Poppins-Regular", size: 12))
                    .foregroundStyle(LearnAlertStyle.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            Button {
                cardToPreview = card
            } label: {
                Image(systemName: "eye")
                    .font(.system(size: 14))
                    .foregroundStyle(LearnAlertStyle.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(Color.primary.opacity(0.04), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Preview card")

            Button {
                cardToEdit = card
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 14))
                    .foregroundStyle(LearnAlertStyle.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(Color.primary.opacity(0.04), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit card")
        }
        .padding(.vertical, 6)
        .listRowBackground(Color.clear)
        .listRowSeparatorTint(LearnAlertStyle.hairline.opacity(0.35))
    }

    private func delete(_ offsets: IndexSet, from list: [Flashcard]) {
        for index in offsets {
            let card = list[index]
            if let idx = deck.cards.firstIndex(where: { $0.id == card.id }) {
                let removed = deck.cards.remove(at: idx)
                context.delete(removed)
            }
        }
        try? context.save()
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

private struct StatBox: View {
    let title: LocalizedStringKey
    let value: String
    let color: Color
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.custom("Poppins-SemiBold", size: 10))
                    .foregroundStyle(LearnAlertStyle.textSecondary)
            }
            Text(value)
                .font(.custom("Poppins-SemiBold", size: 18))
                .foregroundStyle(LearnAlertStyle.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(LearnAlertStyle.courseSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(LearnAlertStyle.glassStroke, lineWidth: 1)
        )
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

                            if let promptImg = card.promptImageName, !promptImg.isEmpty,
                               let uiImage = CardImageStore.loadImage(named: promptImg) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxHeight: 160)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(LearnAlertStyle.hairline.opacity(0.3), lineWidth: 1)
                                    )
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }

                            Text(card.question)
                                .font(.custom("Poppins-SemiBold", size: 18))
                                .foregroundStyle(LearnAlertStyle.textPrimary)

                            if !card.hint.isEmpty {
                                if showHint {
                                    Text("💡 \(card.hint)")
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
                            VStack(spacing: 10) {
                                ForEach(card.options, id: \.self) { option in
                                    Button {
                                        selectedAnswer = option
                                    } label: {
                                        HStack {
                                            Text(option)
                                                .font(.custom("Poppins-Medium", size: 14))
                                                .foregroundStyle(textColor(for: option))
                                            Spacer()
                                            if let selected = selectedAnswer {
                                                if option == card.correctAnswer {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .foregroundStyle(.green)
                                                } else if option == selected {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .foregroundStyle(.red)
                                                }
                                            }
                                        }
                                        .padding(14)
                                        .background(backgroundColor(for: option))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(borderColor(for: option), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        } else {
                            VStack(spacing: 12) {
                                if isRevealed {
                                    Text(card.correctAnswer)
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
