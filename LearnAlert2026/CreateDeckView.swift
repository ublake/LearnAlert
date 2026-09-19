import SwiftUI
import SwiftData

struct CreateDeckView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var deckName = ""
    @State private var selectedColorHex = "#5568C9"

    private let colors = ["#5568C9", "#4C89A8", "#5B8C72", "#9A6C89", "#A27B55", "#6F6A9A"]

    var body: some View {
        NavigationStack {
            ZStack {
                LearnAlertBackground(emphasized: true)

                ScrollView {
                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("DECK NAME")
                                    .font(.caption.bold())
                                Spacer()
                                Text("\(deckName.count)/40")
                                    .font(.caption2.monospacedDigit())
                            }
                            .foregroundStyle(.white.opacity(0.62))

                            TextField("e.g. Spanish · Module 1", text: $deckName)
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(.white)
                                .editorialField()
                                .onChange(of: deckName) { _, value in
                                    if value.count > 40 { deckName = String(value.prefix(40)) }
                                }
                        }
                        .padding(18)
                        .interactiveGlass(cornerRadius: 20, tint: LearnAlertStyle.indigoDeep.opacity(0.42))

                        VStack(alignment: .leading, spacing: 14) {
                            Text("DECK COLOR")
                                .font(.caption.bold())
                                .foregroundStyle(.white.opacity(0.62))

                            HStack(spacing: 0) {
                                ForEach(colors, id: \.self) { hex in
                                    Button {
                                        withAnimation(.snappy) {
                                            selectedColorHex = hex
                                        }
                                    } label: {
                                        Circle()
                                            .fill(Color(hex: hex))
                                            .frame(width: 38, height: 38)
                                            .overlay(
                                                Circle()
                                                    .stroke(.white, lineWidth: selectedColorHex == hex ? 3 : 0)
                                            )
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(18)
                        .interactiveGlass(cornerRadius: 20, tint: LearnAlertStyle.indigoDeep.opacity(0.42))

                        VStack(alignment: .leading, spacing: 13) {
                            HStack {
                                Circle()
                                    .fill(Color(hex: selectedColorHex))
                                    .frame(width: 14, height: 14)
                                Text(deckName.isEmpty ? "Your new deck" : deckName)
                                    .font(.title3.bold())
                                Spacer()
                                Text("0 cards")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.58))
                            }

                            Text("After creating it, add color-coded categories such as Verbs, Nouns, or Chapter 1.")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .foregroundStyle(.white)
                        .padding(18)
                        .interactiveGlass(cornerRadius: 20, tint: Color(hex: selectedColorHex).opacity(0.22))

                        Button(action: saveDeck) {
                            Label("Create Deck", systemImage: "rectangle.stack.badge.plus")
                                .font(.headline.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        }
                        .foregroundStyle(.white)
                        .interactiveGlass(cornerRadius: 16, tint: LearnAlertStyle.indigo)
                        .disabled(trimmedName.isEmpty)
                        .opacity(trimmedName.isEmpty ? 0.45 : 1)
                    }
                    .padding(20)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .navigationTitle("New Deck")
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

    private var trimmedName: String {
        deckName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func saveDeck() {
        let deck = Deck(name: trimmedName, colorHex: selectedColorHex, deckType: "Quiz")
        context.insert(deck)
        try? context.save()
        dismiss()
    }
}
