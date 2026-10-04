import SwiftUI
import SwiftData

struct StarterDeckTemplate: Identifiable {
    let id: String
    let name: String
    let category: String
    let description: String
    let colorHex: String
    let deckType: String
    let cards: [(question: String, options: [String], correctAnswer: String, hint: String)]
}

enum StarterDecksCatalog {
    static let starterDecks: [StarterDeckTemplate] = [
        StarterDeckTemplate(
            id: "mental-math",
            name: "Mental Math Speed Run",
            category: "Math",
            description: "Quick arithmetic, percentages, and practical number sense.",
            colorHex: "#5B78C7",
            deckType: "Quiz",
            cards: [
                ("What is 15 + 27?", ["32", "40", "42", "52"], "42", "Add 20 to 15 (35), then add 7."),
                ("What is 9 × 8?", ["63", "72", "81", "89"], "72", "Ten eights (80) minus eight = 72."),
                ("What is half of 86?", ["38", "43", "46", "48"], "43", "Half of 80 is 40, half of 6 is 3."),
                ("What is 100 − 37?", ["53", "63", "67", "73"], "63", "Subtract 40 (60), then add 3."),
                ("What is 25% of 80?", ["15", "20", "25", "40"], "20", "25% is one-quarter of 80."),
                ("What is 14 × 5?", ["60", "70", "75", "80"], "70", "Half of 14 is 7, then multiply by 10."),
                ("What is 15% of $60?", ["$6", "$8", "$9", "$12"], "$9", "10% is $6.00 and 5% is $3.00. 6 + 3 = 9."),
                ("What is 250 ÷ 5?", ["40", "45", "50", "55"], "50", "25 ÷ 5 = 5, then append the zero."),
                ("What is 12 × 12?", ["122", "134", "144", "154"], "144", "Standard 12 squared."),
                ("What is 300 − 128?", ["162", "172", "182", "192"], "172", "300 − 100 = 200, then subtract 28.")
            ]
        ),
        StarterDeckTemplate(
            id: "spanish-essentials",
            name: "Spanish Essentials",
            category: "Languages",
            description: "High-frequency conversational vocabulary and everyday phrases.",
            colorHex: "#D76C82",
            deckType: "Quiz",
            cards: [
                ("What does \"Hola, ¿cómo estás?\" mean?", ["Hello, how are you?", "Good morning, friend", "Where are you going?", "Nice to meet you"], "Hello, how are you?", "Common greeting asking how someone is doing."),
                ("What does \"Por favor\" mean?", ["Thank you", "Please", "You're welcome", "Excuse me"], "Please", "Polite request phrase in Spanish."),
                ("What does \"Gracias por todo\" mean?", ["Thanks for everything", "See you tomorrow", "Good luck", "Pleased to meet you"], "Thanks for everything", "Gracias = Thanks, por todo = for everything."),
                ("What does \"¿Dónde está el baño?\" mean?", ["Where is the restaurant?", "Where is the bathroom?", "Where is the station?", "How much is this?"], "Where is the bathroom?", "El baño translates to the bathroom."),
                ("What does \"Buenos días\" mean?", ["Good night", "Good afternoon", "Good morning", "Have a great day"], "Good morning", "Greeting used during the morning."),
                ("What does \"Mucho gusto\" mean?", ["Nice to meet you", "See you later", "No problem", "I am hungry"], "Nice to meet you", "Spoken when meeting someone for the first time."),
                ("What does \"¿Cuánto cuesta?\" mean?", ["What time is it?", "How much does it cost?", "Where is the exit?", "Can you help me?"], "How much does it cost?", "Used when asking for prices in shops."),
                ("What does \"Lo siento mucho\" mean?", ["I am very sorry", "I don't know", "I am happy", "I am tired"], "I am very sorry", "Expresses a sincere apology or sympathy."),
                ("What does \"Hasta luego\" mean?", ["See you later", "Welcome", "Good luck", "Goodbye forever"], "See you later", "Standard casual farewell phrase."),
                ("What does \"No hablo mucho español\" mean?", ["I don't speak much Spanish", "I speak fluent Spanish", "Do you speak English?", "I love Spanish"], "I don't speak much Spanish", "Hablo = I speak; no hablo = I do not speak.")
            ]
        ),
        StarterDeckTemplate(
            id: "human-biology",
            name: "Biology & Human Anatomy",
            category: "Science",
            description: "Cells, organs, physiology, and fundamental body systems.",
            colorHex: "#4D9B79",
            deckType: "Quiz",
            cards: [
                ("Which organ pumps oxygenated blood throughout the body?", ["Heart", "Lungs", "Liver", "Kidneys"], "Heart", "Muscular organ with four internal chambers."),
                ("Which organelle is known as the powerhouse of the cell?", ["Nucleus", "Mitochondria", "Ribosome", "Golgi apparatus"], "Mitochondria", "Generates chemical ATP energy for cellular functions."),
                ("Which blood vessels carry oxygenated blood away from the heart?", ["Arteries", "Veins", "Capillaries", "Venules"], "Arteries", "Remember: Arteries carry blood Away."),
                ("How many bones are in the adult human skeleton?", ["186", "206", "226", "256"], "206", "Infants start with more, which fuse into 206."),
                ("Which organ produces insulin to regulate blood glucose?", ["Pancreas", "Liver", "Spleen", "Gallbladder"], "Pancreas", "Gland located behind the stomach."),
                ("What is the largest organ of the human body?", ["Liver", "Skin", "Brain", "Lungs"], "Skin", "Part of the integumentary protective system."),
                ("Which part of the brain controls balance and coordination?", ["Cerebellum", "Cerebrum", "Brainstem", "Thalamus"], "Cerebellum", "Located at the lower back of the brain."),
                ("What type of blood cells fight infections and disease?", ["Red blood cells", "White blood cells", "Platelets", "Plasma"], "White blood cells", "Also known as leukocytes."),
                ("Which macromolecule carries genetic instructions?", ["Lipid", "Protein", "DNA", "Carbohydrate"], "DNA", "Double helix nucleic acid structure."),
                ("Which gas do human lungs extract from inhaled air?", ["Nitrogen", "Oxygen", "Carbon dioxide", "Helium"], "Oxygen", "Crucial gas required for cellular respiration.")
            ]
        ),
        StarterDeckTemplate(
            id: "swift-programming",
            name: "Swift & iOS Development",
            category: "Computing",
            description: "Core Swift syntax, SwiftUI fundamentals, and iOS app architecture.",
            colorHex: "#E06C45",
            deckType: "Quiz",
            cards: [
                ("Which keyword declares an immutable constant in Swift?", ["var", "let", "const", "final"], "let", "Values assigned with 'let' cannot be reassigned."),
                ("In Swift, what does a question mark after a type indicate (e.g. String?)?", ["Optional type", "Force unwrap", "Array", "Generic"], "Optional type", "Represents either an underlying value or nil."),
                ("Which Swift type is a value type passed by copy?", ["class", "struct", "actor", "closure"], "struct", "Structures and enumerations are value types in Swift."),
                ("Which property wrapper manages local, view-owned mutable state in SwiftUI?", ["@State", "@Binding", "@Environment", "@FetchRequest"], "@State", "Allocates and persists private state memory for a SwiftUI view."),
                ("What is the primary purpose of `guard` in Swift?", ["Early exit if condition fails", "Infinite loop", "Async dispatch", "Protocol check"], "Early exit if condition fails", "Requires an early return or throw in its else block."),
                ("Which collection type stores unique, unordered elements in Swift?", ["Array", "Set", "Dictionary", "Tuple"], "Set", "Ensures zero duplicate items with fast hash-based lookup."),
                ("Which framework is Apple's Swift-native persistence framework?", ["CoreData", "SwiftData", "SQLite", "Realm"], "SwiftData", "Uses @Model and Swift macros introduced in iOS 17."),
                ("Which attribute guarantees code executes on the main UI actor?", ["@MainActor", "@Sendable", "@StateObject", "@Published"], "@MainActor", "Global actor binding code to the main execution queue."),
                ("Which capture list modifier captures an object as an optional to avoid retain cycles?", ["[weak self]", "[unowned self]", "[self]", "[copy self]"], "[weak self]", "Captures self as an optional reference that becomes nil upon deallocation."),
                ("What does `defer` do in a Swift function?", ["Executes right before exiting current scope", "Runs in background", "Delays execution by 1s", "Cancels task"], "Executes right before exiting current scope", "Executes cleanup actions regardless of how scope is exited.")
            ]
        )
    ]
}

struct WelcomeOnboardingView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @AppStorage("homeTutorialStep") private var homeTutorialStep: Int = 0
    @AppStorage("targetDeckId") private var targetDeckId: String = "ALL"
    @AppStorage("tutorialDeckId") private var tutorialDeckId: String = ""

    let completion: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            Color(red: 0.08, green: 0.10, blue: 0.17)
                .ignoresSafeArea()

            CoursezyBackground()
                .ignoresSafeArea()

            StarterDeckSelectionPage(
                onSelectDeck: { template in
                    importStarterDeckAndBeginTour(template)
                },
                onSkip: {
                    homeTutorialStep = 0
                    completion()
                }
            )
            .padding(.top, 10)
        }
        .preferredColorScheme(.dark)
    }

    private func importStarterDeckAndBeginTour(_ template: StarterDeckTemplate) {
        InteractionSoundPlayer.shared.play(.addDeck)
        HapticFeedback.success()

        // Fetch all existing decks and shift their orderIndex up so the new starter deck is at orderIndex 0
        let descriptor = FetchDescriptor<Deck>()
        if let existingDecks = try? context.fetch(descriptor) {
            for existing in existingDecks {
                existing.orderIndex += 1
            }
        }

        // Create and insert the real deck into SwiftData
        let deck = Deck(
            name: template.name,
            colorHex: template.colorHex,
            deckType: template.deckType,
            orderIndex: 0
        )

        for cardData in template.cards {
            let card = Flashcard(
                question: cardData.question,
                options: cardData.options,
                correctAnswer: cardData.correctAnswer,
                hint: cardData.hint,
                cardType: .multipleChoice
            )
            card.deck = deck
            deck.cards.append(card)
        }

        context.insert(deck)
        try? context.save()

        // Pre-select the deck in targetDeckId
        targetDeckId = deck.id.uuidString
        tutorialDeckId = deck.id.uuidString
        UserDefaults(suiteName: "group.com.learnalert.shared")?.set(deck.id.uuidString, forKey: "targetDeckId")

        // Start guided tour at Step 1 (highlight newly created deck on home screen)
        homeTutorialStep = 1
        completion()
    }
}

// MARK: - Starter Deck Selection Page
private struct StarterDeckSelectionPage: View {
    let onSelectDeck: (StarterDeckTemplate) -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("Pick your first study deck")
                    .font(.custom("Poppins-SemiBold", size: 22))
                    .foregroundStyle(Color.white)
                    .multilineTextAlignment(.center)

                Text("Choose a starter deck to add to your library and start learning.")
                    .font(.custom("Poppins-Regular", size: 13))
                    .foregroundStyle(Color.white.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 10)
            }
            .padding(.top, 6)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach(StarterDecksCatalog.starterDecks) { template in
                        Button {
                            onSelectDeck(template)
                        } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: template.colorHex).opacity(0.25))
                                        .frame(width: 48, height: 48)

                                    Image(systemName: iconForCategory(template.category))
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundStyle(Color(hex: template.colorHex))
                                }

                                VStack(alignment: .leading, spacing: 3) {
                                    HStack {
                                        Text(template.name)
                                            .font(.custom("Poppins-SemiBold", size: 15))
                                            .foregroundStyle(Color.white)

                                        Spacer()

                                        Text("\(template.cards.count) cards")
                                            .font(.custom("Poppins-Medium", size: 11))
                                            .foregroundStyle(Color.white.opacity(0.6))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(Color.white.opacity(0.1), in: Capsule())
                                    }

                                    Text(template.description)
                                        .font(.custom("Poppins-Regular", size: 12))
                                        .foregroundStyle(Color.white.opacity(0.70))
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color(red: 0.12, green: 0.15, blue: 0.24).opacity(0.90))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.2), radius: 8, y: 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 6)
            }

            Button(action: onSkip) {
                Text("Start with an empty library")
                    .font(.custom("Poppins-Regular", size: 13))
                    .foregroundStyle(Color.white.opacity(0.65))
            }
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func iconForCategory(_ category: String) -> String {
        switch category {
        case "Math": return "plus.forwardslash.minus"
        case "Languages": return "character.bubble.fill"
        case "Science": return "atom"
        case "Computing": return "swift"
        default: return "rectangle.stack.fill"
        }
    }
}
