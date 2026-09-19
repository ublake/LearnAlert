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

    private var orderedSections: [DeckSection] {
        deck.sections.sorted { $0.orderIndex < $1.orderIndex }
    }

    private var uncategorizedCards: [Flashcard] {
        deck.cards.filter { $0.section == nil }
    }

    private var cardsDueToday: Int {
        deck.cards.filter { $0.nextReviewDate <= Date() }.count
    }

    var body: some View {
        ZStack {
            LearnAlertBackground()

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    StatBox(title: "CARDS", value: "\(deck.cards.count)", color: LearnAlertStyle.indigo)
                    StatBox(title: "DUE", value: "\(cardsDueToday)", color: cardsDueToday > 0 ? .orange : .green)
                    StatBox(title: "CATEGORIES", value: "\(deck.sections.count)", color: Color(hex: deck.colorHex))
                }
                .padding(.horizontal)
                .padding(.bottom, 14)

                if isEditingDeck {
                    HStack {
                        TextField("Deck Name", text: $deck.name)
                            .foregroundStyle(.white)
                            .editorialField()
                        ColorPicker(
                            "",
                            selection: Binding(
                                get: { Color(hex: deck.colorHex) },
                                set: { deck.colorHex = $0.toHex() ?? deck.colorHex }
                            )
                        )
                        .labelsHidden()
                        Button("Done") {
                            withAnimation { isEditingDeck = false }
                            try? context.save()
                        }
                        .foregroundStyle(.white)
                    }
                    .padding()
                    .interactiveGlass(cornerRadius: 18, tint: LearnAlertStyle.indigoDeep.opacity(0.46))
                    .padding(.horizontal)
                }

                List {
                    ForEach(orderedSections) { section in
                        Section {
                            ForEach(section.cards) { card in
                                cardRow(card)
                            }
                            .onDelete { offsets in
                                delete(offsets, from: section.cards)
                            }
                        } header: {
                            CategoryHeader(section: section)
                                .contextMenu {
                                    Button("Delete Category", role: .destructive) {
                                        context.delete(section)
                                        try? context.save()
                                    }
                                }
                        }
                    }

                    if !uncategorizedCards.isEmpty || orderedSections.isEmpty {
                        Section {
                            if uncategorizedCards.isEmpty {
                                ContentUnavailableView(
                                    "No Cards Yet",
                                    systemImage: "rectangle.stack.badge.plus",
                                    description: Text("Add a card or create a category to get started.")
                                )
                            } else {
                                ForEach(uncategorizedCards) { card in
                                    cardRow(card)
                                }
                                .onDelete { offsets in
                                    delete(offsets, from: uncategorizedCards)
                                }
                            }
                        } header: {
                            Label("Uncategorized", systemImage: "tray")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .scrollContentBackground(.hidden)

                HStack(spacing: 10) {
                    NavigationLink(destination: DeckStudyView(deck: deck)) {
                        actionLabel("Study", icon: "play.fill", prominent: true)
                    }
                    .disabled(deck.cards.isEmpty)
                    .opacity(deck.cards.isEmpty ? 0.45 : 1)

                    Button { showingCreateCategory = true } label: {
                        actionLabel("Category", icon: "folder.badge.plus", prominent: false)
                    }

                    Button { showingCreateCard = true } label: {
                        actionLabel("Card", icon: "plus", prominent: false)
                    }
                }
                .padding()
            }
        }
        .navigationTitle(deck.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Edit Deck") { withAnimation { isEditingDeck = true } }
                    Button("Add Category") { showingCreateCategory = true }
                    Button("Delete Deck", role: .destructive) {
                        context.delete(deck)
                        dismiss()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
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
    }

    @ViewBuilder
    private func cardRow(_ card: Flashcard) -> some View {
        CardRowView(card: card)
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
            .listRowBackground(Color.white.opacity(0.58))
            .listRowSeparatorTint(LearnAlertStyle.hairline.opacity(0.35))
    }

    private func delete(_ offsets: IndexSet, from cards: [Flashcard]) {
        for index in offsets {
            context.delete(cards[index])
        }
        try? context.save()
    }

    private func actionLabel(_ title: String, icon: String, prominent: Bool) -> some View {
        Label(title, systemImage: icon)
            .font(.subheadline.bold())
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(.white)
            .background(prominent ? LearnAlertStyle.indigo : LearnAlertStyle.indigoDeep.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: 13))
    }
}

private struct CategoryHeader: View {
    let section: DeckSection

    var body: some View {
        HStack {
            Circle()
                .fill(Color(hex: section.colorHex))
                .frame(width: 11, height: 11)
            Text(section.name)
                .font(.caption.bold())
            Spacer()
            Text("\(section.cards.count)")
                .font(.caption2.monospacedDigit())
        }
        .foregroundStyle(LearnAlertStyle.textSecondary)
    }
}

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
                LearnAlertBackground(emphasized: true)

                VStack(spacing: 22) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("CATEGORY NAME")
                            .font(.caption.bold())
                            .foregroundStyle(.white.opacity(0.62))
                        TextField("e.g. Verbs", text: $name)
                            .foregroundStyle(.white)
                            .editorialField()
                    }
                    .padding(18)
                    .interactiveGlass(cornerRadius: 18, tint: LearnAlertStyle.indigoDeep.opacity(0.42))

                    VStack(alignment: .leading, spacing: 14) {
                        Text("COLOR")
                            .font(.caption.bold())
                            .foregroundStyle(.white.opacity(0.62))
                        HStack {
                            ForEach(colors, id: \.self) { hex in
                                Button {
                                    colorHex = hex
                                } label: {
                                    Circle()
                                        .fill(Color(hex: hex))
                                        .frame(width: 36, height: 36)
                                        .overlay(Circle().stroke(.white, lineWidth: colorHex == hex ? 3 : 0))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(18)
                    .interactiveGlass(cornerRadius: 18, tint: LearnAlertStyle.indigoDeep.opacity(0.42))

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
                            .font(.headline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .foregroundStyle(.white)
                    .interactiveGlass(cornerRadius: 16, tint: Color(hex: colorHex).opacity(0.55))
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(20)
            }
            .navigationTitle("New Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .preferredColorScheme(.dark)
        }
    }
}

struct StatBox: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 5) {
            Text(title)
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.bold())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct CardRowView: View {
    let card: Flashcard

    private var mastery: (text: String, color: Color) {
        if card.isNew { return ("New", .cyan) }
        if card.interval == 0 { return ("Learning", .red) }
        if card.interval < 7 { return ("Reviewing", .yellow) }
        return ("Mastered", .green)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(card.question)
                .font(.headline)
                .foregroundStyle(LearnAlertStyle.textPrimary)

            HStack {
                Text("Ans: \(card.correctAnswer)")
                    .font(.subheadline)
                    .foregroundStyle(LearnAlertStyle.textSecondary)
                    .lineLimit(1)
                Spacer()
                Text(mastery.text)
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(mastery.color.opacity(0.2))
                    .foregroundStyle(mastery.color)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
    }
}

struct SquishyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.interpolatingSpring(stiffness: 300, damping: 15), value: configuration.isPressed)
    }
}
