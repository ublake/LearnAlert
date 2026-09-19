import SwiftUI
import SwiftData

struct CreateDeckView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var decks: [Deck]

    @State private var deckName = ""
    @State private var selectedColorHex = ""
    @FocusState private var isNameFocused: Bool

    private let availableColors = [
        "#3B82C4", // Ocean Blue
        "#5B70E0", // Indigo
        "#2A9D8F", // Emerald Teal
        "#39D0BC", // Aqua
        "#C05A78", // Rose
        "#B8793E", // Warm Amber
        "#7654A8", // Purple
        "#3D8A59"  // Forest Green
    ]

    private let nameSuggestions = [
        "Spanish", "Biology", "History", "Medical", "Formulas", "Vocabulary"
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                LearnAlertStyle.courseCanvas
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        // 1. Deck Name & Quick Suggestions
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("DECK NAME")
                                    .font(.caption.bold())
                                Spacer()
                                Text("\(deckName.count)/40")
                                    .font(.caption2.monospacedDigit())
                            }
                            .foregroundStyle(LearnAlertStyle.textSecondary)

                            HStack(spacing: 8) {
                                TextField("e.g. Spanish · Module 1", text: $deckName)
                                    .font(.custom("Poppins-SemiBold", size: 17, relativeTo: .body))
                                    .foregroundStyle(LearnAlertStyle.textPrimary)
                                    .focused($isNameFocused)
                                    .onChange(of: deckName) { _, value in
                                        if value.count > 40 { deckName = String(value.prefix(40)) }
                                    }

                                if !deckName.isEmpty {
                                    Button {
                                        deckName = ""
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(LearnAlertStyle.textSecondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color.primary.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(LearnAlertStyle.hairline.opacity(0.3), lineWidth: 0.75)
                            )

                            // Quick Ideas Chips
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(nameSuggestions, id: \.self) { suggestion in
                                        Button {
                                            deckName = suggestion
                                            HapticFeedback.warning()
                                        } label: {
                                            Text(suggestion)
                                                .font(.custom("Poppins-Medium", size: 12, relativeTo: .caption))
                                                .foregroundStyle(deckName == suggestion ? Color.white : LearnAlertStyle.textSecondary)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(
                                                    deckName == suggestion
                                                        ? Color(hex: effectiveColorHex)
                                                        : Color.primary.opacity(0.05)
                                                )
                                                .clipShape(Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        .padding(18)
                        .settingsGlassSurface(cornerRadius: 18)

                        // 2. Deck Accent Color Selection
                        VStack(alignment: .leading, spacing: 14) {
                            Text("ACCENT COLOR")
                                .font(.caption.bold())
                                .foregroundStyle(LearnAlertStyle.textSecondary)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 14) {
                                    ForEach(availableColors, id: \.self) { hex in
                                        Button {
                                            selectedColorHex = hex
                                            InteractionSoundPlayer.shared.play(.selection)
                                        } label: {
                                            ZStack {
                                                Circle()
                                                    .fill(Color(hex: hex))
                                                    .frame(width: 38, height: 38)
                                                    .shadow(
                                                        color: effectiveColorHex == hex ? Color(hex: hex).opacity(0.4) : .clear,
                                                        radius: 6,
                                                        y: 3
                                                    )

                                                if effectiveColorHex == hex {
                                                    Image(systemName: "checkmark")
                                                        .font(.system(size: 13, weight: .bold))
                                                        .foregroundStyle(.white)

                                                    Circle()
                                                        .stroke(Color.white, lineWidth: 2)
                                                        .frame(width: 38, height: 38)
                                                }
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(18)
                        .settingsGlassSurface(cornerRadius: 18)

                        // 3. Study Alerts Information Card
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 10) {
                                Image(systemName: "bell.badge.fill")
                                    .font(.title3)
                                    .foregroundStyle(Color(hex: effectiveColorHex))

                                Text("Ready for Study Alerts")
                                    .font(.custom("Poppins-SemiBold", size: 15, relativeTo: .headline))
                                    .foregroundStyle(LearnAlertStyle.textPrimary)
                            }

                            Text("Once created, you can add flashcards or import notes with AI. LearnAlert will automatically schedule lock-screen alerts so you study effortlessly on repeat.")
                                .font(.custom("Poppins-Regular", size: 12, relativeTo: .subheadline))
                                .foregroundStyle(LearnAlertStyle.textSecondary)
                                .lineSpacing(2)
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .settingsGlassSurface(cornerRadius: 18)

                        // 4. Primary Rounded Create Button
                        Button(action: saveDeck) {
                            HStack(spacing: 10) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 18, weight: .bold))
                                Text("Create Deck")
                                    .font(.custom("Poppins-SemiBold", size: 16, relativeTo: .headline))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                LinearGradient(
                                    colors: trimmedName.isEmpty
                                        ? [Color.gray.opacity(0.35), Color.gray.opacity(0.25)]
                                        : [Color(hex: effectiveColorHex), Color(hex: effectiveColorHex).opacity(0.85)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                            .shadow(
                                color: trimmedName.isEmpty ? .clear : Color(hex: effectiveColorHex).opacity(0.38),
                                radius: 12,
                                y: 5
                            )
                        }
                        .buttonStyle(CreateDeckActionButtonStyle())
                        .disabled(trimmedName.isEmpty)
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
                        .font(.custom("Poppins-Regular", size: 15, relativeTo: .body))
                        .foregroundStyle(LearnAlertStyle.indigo)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Create") { saveDeck() }
                        .font(.custom("Poppins-SemiBold", size: 15, relativeTo: .body))
                        .foregroundStyle(trimmedName.isEmpty ? Color.gray.opacity(0.45) : Color(hex: effectiveColorHex))
                        .disabled(trimmedName.isEmpty)
                }
            }
            .toolbarBackground(LearnAlertStyle.courseCanvas, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .onAppear {
                if selectedColorHex.isEmpty {
                    selectedColorHex = DeckColorPalette.suggestedColor(existingColors: decks.map(\.colorHex))
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    isNameFocused = true
                }
            }
        }
    }

    private var effectiveColorHex: String {
        selectedColorHex.isEmpty ? (availableColors.first ?? "#5B70E0") : selectedColorHex
    }

    private var trimmedName: String {
        deckName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func saveDeck() {
        guard !trimmedName.isEmpty else { return }
        HapticFeedback.success()
        let deck = Deck(name: trimmedName, colorHex: effectiveColorHex, deckType: "Quiz")
        context.insert(deck)
        try? context.save()
        InteractionSoundPlayer.shared.play(.addDeck)
        dismiss()
    }
}

private struct CreateDeckActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.88 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
