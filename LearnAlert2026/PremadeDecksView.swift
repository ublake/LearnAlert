import SwiftData
import SwiftUI

struct PremadeCard: Identifiable {
    let id: String
    let question: String
    let options: [String]
    let correctAnswer: String
    let hint: String
}

struct PremadeDeck: Identifiable {
    let id: String
    let name: String
    let category: String
    let subcategory: String
    let description: String
    let colorHex: String
    let deckType: String
    let cards: [PremadeCard]
}

enum PremadeDeckCatalog {
    static let mainCategories = ["All", "Languages", "Math", "Science", "History", "Computing", "Exam Prep"]

    static let subcategoriesByCategory: [String: [String]] = [
        "Languages": ["All", "Spanish", "Korean", "Chinese", "French", "Japanese", "German", "Italian"],
        "Math": ["All", "Arithmetic", "Algebra", "Geometry", "Fractions"],
        "Science": ["All", "Biology", "Chemistry", "Physics", "Astronomy"],
        "History": ["All", "Ancient History", "US History", "World History"],
        "Computing": ["All", "Swift", "Programming", "Cybersecurity"],
        "Exam Prep": ["All", "SAT", "Study Skills"]
    ]

    static let decks: [PremadeDeck] = [
        languageDeck(id: "spanish-basics", name: "Spanish Basics", language: "Spanish", description: "Everyday beginner vocabulary and greetings.", color: "#D76C82", pairs: [("Hola", "Hello"), ("Gracias", "Thank you"), ("Por favor", "Please"), ("Adiós", "Goodbye"), ("Buenos días", "Good morning")]),
        languageDeck(id: "spanish-travel", name: "Spanish for Travel", language: "Spanish", description: "Useful phrases for navigating, dining, and hotels.", color: "#C45D72", pairs: [("¿Dónde está...?", "Where is...?"), ("La cuenta, por favor", "The check, please"), ("Una habitación", "A room"), ("El aeropuerto", "The airport"), ("¿Cuánto cuesta?", "How much does it cost?")]),
        languageDeck(id: "korean-basics", name: "Korean Basics", language: "Korean", description: "Start with polite greetings and common words.", color: "#6A83C5", pairs: [("안녕하세요", "Hello"), ("감사합니다", "Thank you"), ("네", "Yes"), ("아니요", "No"), ("안녕히 가세요", "Goodbye")]),
        languageDeck(id: "chinese-basics", name: "Chinese Basics", language: "Chinese", description: "Essential Mandarin words with simple meanings.", color: "#D95B4F", pairs: [("你好", "Hello"), ("谢谢", "Thank you"), ("请", "Please"), ("再见", "Goodbye"), ("朋友", "Friend")]),
        languageDeck(id: "french-basics", name: "French Basics", language: "French", description: "Core French vocabulary for daily conversation.", color: "#668CC8", pairs: [("Bonjour", "Hello"), ("Merci", "Thank you"), ("S’il vous plaît", "Please"), ("Au revoir", "Goodbye"), ("Comment ça va?", "How are you?")]),
        languageDeck(id: "japanese-basics", name: "Japanese Basics", language: "Japanese", description: "Polite expressions for beginning Japanese learners.", color: "#C76A77", pairs: [("こんにちは", "Hello"), ("ありがとう", "Thank you"), ("はい", "Yes"), ("いいえ", "No"), ("さようなら", "Goodbye")]),
        languageDeck(id: "german-basics", name: "German Basics", language: "German", description: "Common German greetings and useful words.", color: "#9C7A43", pairs: [("Hallo", "Hello"), ("Danke", "Thank you"), ("Bitte", "Please"), ("Auf Wiedersehen", "Goodbye"), ("Freund", "Friend")]),
        languageDeck(id: "italian-basics", name: "Italian Basics", language: "Italian", description: "Friendly phrases for everyday Italian.", color: "#4B9B74", pairs: [("Ciao", "Hello"), ("Grazie", "Thank you"), ("Per favore", "Please"), ("Arrivederci", "Goodbye"), ("Amico", "Friend")]),

        quizDeck(id: "mental-math", name: "Mental Math", category: "Math", subcategory: "Arithmetic", description: "Quick arithmetic for faster recall.", color: "#A27B55", cards: [("What is 15 + 27?", ["32", "40", "42", "52"], "42", "Add 20, then 7."), ("What is 9 × 8?", ["63", "72", "81", "89"], "72", "Ten eights minus eight."), ("What is half of 86?", ["38", "43", "46", "48"], "43", "Half 80, then half 6."), ("What is 100 − 37?", ["53", "63", "67", "73"], "63", "Subtract 40, then add 3."), ("What is 25% of 80?", ["15", "20", "25", "40"], "20", "One quarter of 80.")]),
        quizDeck(id: "algebra-basics", name: "Algebra Basics", category: "Math", subcategory: "Algebra", description: "Equations, variables, and expressions.", color: "#4C89A8", cards: [("Solve: x + 5 = 12", ["5", "7", "12", "17"], "7", "Subtract 5."), ("Solve: 3x = 18", ["3", "6", "9", "15"], "6", "Divide by 3."), ("Simplify: 2x + 3x", ["5", "5x", "6x", "x"], "5x", "Combine like terms."), ("If y = 3, what is 2y + 1?", ["5", "6", "7", "8"], "7", "Substitute 3."), ("Solve: x − 4 = 9", ["5", "9", "13", "36"], "13", "Add 4.")]),
        quizDeck(id: "geometry-essentials", name: "Geometry Essentials", category: "Math", subcategory: "Geometry", description: "Shapes, angles, area, and perimeter.", color: "#527FB5", cards: [("How many degrees are in a right angle?", ["45", "90", "180", "360"], "90", "Think of a square corner."), ("Area of a 4 × 6 rectangle?", ["10", "20", "24", "48"], "24", "Length times width."), ("A triangle has how many sides?", ["2", "3", "4", "5"], "3", "Tri means three."), ("Circumference uses which constant?", ["e", "π", "φ", "i"], "π", "About 3.14."), ("Opposite sides of a rectangle are...", ["unequal", "curved", "parallel", "diagonal"], "parallel", "They never meet.")]),
        quizDeck(id: "fractions", name: "Fraction Fundamentals", category: "Math", subcategory: "Fractions", description: "Equivalent fractions and basic operations.", color: "#728B5B", cards: [("Which equals 1/2?", ["2/3", "2/4", "3/4", "1/3"], "2/4", "Multiply top and bottom by 2."), ("1/4 + 1/4 = ?", ["1/8", "1/2", "2/3", "1"], "1/2", "Add like denominators."), ("Which is largest?", ["1/4", "1/3", "1/2", "1/5"], "1/2", "Compare equal wholes."), ("3/4 − 1/4 = ?", ["1/4", "1/2", "2/4", "1"], "1/2", "Subtract numerators, then simplify."), ("Reciprocal of 2/3?", ["2/3", "3/2", "1/3", "3"], "3/2", "Flip numerator and denominator.")]),

        quizDeck(id: "cell-biology", name: "Cell Biology", category: "Science", subcategory: "Biology", description: "Organelles and the fundamentals of living cells.", color: "#4D9B79", cards: [("Which organelle contains DNA?", ["Nucleus", "Ribosome", "Vacuole", "Cell wall"], "Nucleus", "The cell’s control center."), ("Where is ATP mainly produced?", ["Golgi", "Mitochondria", "Nucleus", "Lysosome"], "Mitochondria", "The powerhouse."), ("Plants perform photosynthesis in...", ["chloroplasts", "ribosomes", "lysosomes", "centrioles"], "chloroplasts", "They contain chlorophyll."), ("The cell membrane is...", ["fully rigid", "selectively permeable", "made of DNA", "only in plants"], "selectively permeable", "It controls transport."), ("Ribosomes build...", ["lipids", "proteins", "DNA", "glucose"], "proteins", "They translate mRNA.")]),
        quizDeck(id: "chemistry-atoms", name: "Atoms & Elements", category: "Science", subcategory: "Chemistry", description: "Atomic structure and periodic-table essentials.", color: "#8B6CC1", cards: [("A proton has what charge?", ["positive", "negative", "neutral", "variable"], "positive", "It sits in the nucleus."), ("Atomic number counts...", ["neutrons", "protons", "shells", "bonds"], "protons", "It identifies the element."), ("H is the symbol for...", ["Helium", "Hydrogen", "Hafnium", "Holmium"], "Hydrogen", "The lightest element."), ("Electrons occupy...", ["the nucleus only", "energy levels", "proton chains", "molecules only"], "energy levels", "Often called shells."), ("A neutral atom has equal protons and...", ["neutrons", "electrons", "isotopes", "ions"], "electrons", "Opposite charges balance.")]),
        quizDeck(id: "physics-motion", name: "Motion & Forces", category: "Science", subcategory: "Physics", description: "Speed, acceleration, force, and Newton’s laws.", color: "#477FA3", cards: [("Speed equals distance divided by...", ["mass", "time", "force", "volume"], "time", "s = d/t."), ("SI unit of force?", ["joule", "watt", "newton", "pascal"], "newton", "Named after Isaac Newton."), ("Acceleration measures change in...", ["mass", "velocity", "distance", "energy"], "velocity", "Per unit time."), ("An object at rest stays at rest describes...", ["first law", "second law", "third law", "gravity"], "first law", "The law of inertia."), ("For every action there is...", ["friction", "equal opposite reaction", "more mass", "less energy"], "equal opposite reaction", "Newton’s third law.")]),
        quizDeck(id: "astronomy", name: "Solar System", category: "Science", subcategory: "Astronomy", description: "Planets, moons, and our place in space.", color: "#5D61A8", cards: [("Closest planet to the Sun?", ["Venus", "Earth", "Mercury", "Mars"], "Mercury", "The innermost planet."), ("Largest planet?", ["Earth", "Saturn", "Jupiter", "Neptune"], "Jupiter", "A gas giant."), ("Earth’s natural satellite?", ["Moon", "Sun", "Mars", "Titan"], "Moon", "Visible at night."), ("The Sun is a...", ["planet", "star", "moon", "comet"], "star", "It produces its own light."), ("Which planet is known for rings?", ["Mars", "Mercury", "Saturn", "Venus"], "Saturn", "Its ring system is prominent.")]),

        quizDeck(id: "ancient-civilizations", name: "Ancient Civilizations", category: "History", subcategory: "Ancient History", description: "Foundations of Egypt, Greece, Rome, and Mesopotamia.", color: "#A47A49", cards: [("Pyramids are strongly associated with...", ["Egypt", "Rome", "China", "Maya only"], "Egypt", "Pharaohs used them as tombs."), ("Democracy developed notably in...", ["Sparta", "Athens", "Babylon", "Carthage"], "Athens", "A Greek city-state."), ("Roman roads helped expand...", ["isolation", "trade and armies", "deserts", "oceans"], "trade and armies", "They connected the empire."), ("Cuneiform began in...", ["Mesopotamia", "Norway", "Japan", "Peru"], "Mesopotamia", "Written on clay tablets."), ("The Nile supported ancient...", ["Egypt", "Rome", "India", "Korea"], "Egypt", "Its floods enriched soil.")]),
        quizDeck(id: "us-history", name: "US History Milestones", category: "History", subcategory: "US History", description: "Key documents, events, and eras.", color: "#9B5E58", cards: [("Declaration of Independence was adopted in...", ["1492", "1776", "1789", "1865"], "1776", "July 4."), ("The Civil War ended in...", ["1776", "1812", "1865", "1918"], "1865", "The 13th Amendment followed."), ("The Constitution begins with...", ["Four score", "We the People", "I have a dream", "Give me liberty"], "We the People", "Its preamble."), ("The New Deal is linked to...", ["Lincoln", "F. D. Roosevelt", "Washington", "Kennedy"], "F. D. Roosevelt", "A response to the Great Depression."), ("The Louisiana Purchase occurred in...", ["1803", "1861", "1914", "1945"], "1803", "It doubled US territory.")]),
        quizDeck(id: "world-history", name: "World History Turning Points", category: "History", subcategory: "World History", description: "Influential global events across centuries.", color: "#7C735E", cards: [("The Renaissance began in...", ["Italy", "Canada", "Australia", "Brazil"], "Italy", "Think Florence."), ("The printing press is associated with...", ["Gutenberg", "Newton", "Darwin", "Edison"], "Gutenberg", "Movable type spread texts."), ("World War I began in...", ["1815", "1914", "1939", "1963"], "1914", "After Sarajevo."), ("The Berlin Wall fell in...", ["1945", "1961", "1989", "2001"], "1989", "Near the Cold War’s end."), ("The Industrial Revolution began in...", ["Britain", "Egypt", "Mexico", "Japan"], "Britain", "Textiles and steam drove it.")]),

        quizDeck(id: "swift-basics", name: "Swift Basics", category: "Computing", subcategory: "Swift", description: "Core Swift syntax, types, and safety.", color: "#E06C45", cards: [("Which keyword declares a constant?", ["var", "let", "func", "class"], "let", "Its value cannot be reassigned."), ("Swift optional values may contain...", ["only strings", "a value or nil", "two values", "only zero"], "a value or nil", "They represent absence safely."), ("Which defines a function?", ["func", "let", "case", "imported"], "func", "It precedes the function name."), ("Array elements are accessed using...", ["keys", "indices", "URLs", "selectors"], "indices", "They begin at zero."), ("A struct is a...", ["value type", "reference only", "loop", "protocol method"], "value type", "Copies have independent values.")]),
        quizDeck(id: "programming-concepts", name: "Programming Concepts", category: "Computing", subcategory: "Programming", description: "Language-independent programming foundations.", color: "#557AA8", cards: [("A loop is used to...", ["repeat work", "store one value", "draw only", "encrypt files"], "repeat work", "It iterates."), ("A Boolean has which values?", ["red/blue", "true/false", "0–9 only", "letters"], "true/false", "It represents a condition."), ("A function primarily groups...", ["reusable behavior", "screenshots", "hardware", "passwords"], "reusable behavior", "Call it when needed."), ("An algorithm is...", ["a step-by-step procedure", "a font", "a database row", "a cable"], "a step-by-step procedure", "It solves a problem."), ("A variable stores...", ["a value", "only code comments", "a monitor", "a network"], "a value", "Its contents can change.")]),
        quizDeck(id: "cybersecurity-basics", name: "Cybersecurity Basics", category: "Computing", subcategory: "Cybersecurity", description: "Safer passwords, phishing awareness, and account protection.", color: "#486C74", cards: [("A strong password should be...", ["unique and long", "your birthday", "password", "shared"], "unique and long", "Use a password manager."), ("Two-factor authentication adds...", ["a second verification step", "a public password", "less security", "automatic sharing"], "a second verification step", "Something beyond your password."), ("Phishing often tries to...", ["steal information", "improve Wi-Fi", "update hardware", "compress files"], "steal information", "It impersonates trust."), ("HTTPS primarily protects data...", ["in transit", "printed on paper", "after deletion", "from all mistakes"], "in transit", "Between client and server."), ("Software updates often include...", ["security fixes", "weaker passwords", "public keys only", "no changes"], "security fixes", "Patch known vulnerabilities.")]),

        quizDeck(id: "sat-vocabulary", name: "SAT Vocabulary", category: "Exam Prep", subcategory: "SAT", description: "High-utility words frequently seen in academic passages.", color: "#735FA8", cards: [("Pragmatic most nearly means...", ["practical", "careless", "ancient", "silent"], "practical", "Focused on workable results."), ("Ambiguous means...", ["unclear", "celebrated", "tiny", "complete"], "unclear", "Open to multiple meanings."), ("Corroborate means...", ["confirm", "deny", "hide", "shorten"], "confirm", "Support with evidence."), ("Meticulous means...", ["very careful", "very loud", "temporary", "ordinary"], "very careful", "Attentive to details."), ("Ubiquitous means...", ["found everywhere", "rare", "dangerous", "unfinished"], "found everywhere", "Seemingly present all around.")]),
        quizDeck(id: "sat-math", name: "SAT Math Warm-Up", category: "Exam Prep", subcategory: "SAT", description: "A quick mixed review of common SAT math skills.", color: "#4E83A5", cards: [("If 2x + 3 = 11, x = ?", ["2", "3", "4", "7"], "4", "Subtract 3, then divide by 2."), ("Slope through (0, 1) and (2, 5)?", ["1", "2", "3", "4"], "2", "Rise 4 over run 2."), ("20% of 150?", ["20", "25", "30", "35"], "30", "Multiply by 0.2."), ("Mean of 2, 4, and 9?", ["3", "4", "5", "6"], "5", "Sum then divide by 3."), ("x² = 49; positive x?", ["5", "6", "7", "8"], "7", "Take the positive square root.")]),
        quizDeck(id: "study-skills", name: "Effective Study Skills", category: "Exam Prep", subcategory: "Study Skills", description: "Evidence-aligned habits for stronger recall.", color: "#548B72", cards: [("Retrieval practice means...", ["recalling without looking", "rereading only", "copying notes", "highlighting everything"], "recalling without looking", "Test your memory."), ("Spacing study sessions helps...", ["long-term retention", "avoid all effort", "remove sleep", "replace practice"], "long-term retention", "Revisit over time."), ("Interleaving means...", ["mixing related problem types", "studying one item forever", "skipping feedback", "memorizing answers only"], "mixing related problem types", "Practice choosing methods."), ("Useful feedback should be...", ["timely and specific", "vague", "hidden", "unrelated"], "timely and specific", "It guides correction."), ("Sleep supports...", ["memory consolidation", "instant forgetting", "no learning", "only exercise"], "memory consolidation", "Rest helps stabilize learning.")])
    ]

    private static func languageDeck(id: String, name: String, language: String, description: String, color: String, pairs: [(String, String)]) -> PremadeDeck {
        PremadeDeck(id: id, name: name, category: "Languages", subcategory: language, description: description, colorHex: color, deckType: "Vocabulary", cards: pairs.enumerated().map { index, pair in
            PremadeCard(id: "\(id)-\(index)", question: pair.0, options: [], correctAnswer: pair.1, hint: "")
        })
    }

    private static func quizDeck(id: String, name: String, category: String, subcategory: String, description: String, color: String, cards: [(String, [String], String, String)]) -> PremadeDeck {
        PremadeDeck(id: id, name: name, category: category, subcategory: subcategory, description: description, colorHex: color, deckType: "Quiz", cards: cards.enumerated().map { index, card in
            PremadeCard(id: "\(id)-\(index)", question: card.0, options: card.1, correctAnswer: card.2, hint: card.3)
        })
    }
}

struct PremadeDecksView: View {
    @Environment(\.modelContext) private var context
    @Query private var libraryDecks: [Deck]
    @State private var searchText = ""
    @State private var selectedCategory = "All"
    @State private var selectedSubcategory = "All"
    @State private var addedDeckName: String?

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
            VStack(alignment: .leading, spacing: 18) {
                DiscoverHeader()
                DiscoverSearchField(searchText: $searchText)
                DiscoverFilterRow(categories: PremadeDeckCatalog.mainCategories, selection: $selectedCategory)

                if !availableSubcategories.isEmpty {
                    DiscoverFilterRow(categories: availableSubcategories, selection: $selectedSubcategory, compact: true)
                }

                PremadeDeckList(decks: filteredDecks, libraryDecks: libraryDecks, add: add)

                if filteredDecks.isEmpty {
                    ContentUnavailableView("No Decks Found", systemImage: "magnifyingglass", description: Text("Try another search or category."))
                        .foregroundStyle(LearnAlertStyle.textPrimary)
                }

                Spacer().frame(height: 120)
            }
            .padding(.top, 18)
        }
        .onChange(of: selectedCategory) { _, _ in selectedSubcategory = "All" }
        .alert("Added to Library", isPresented: Binding(get: { addedDeckName != nil }, set: { if !$0 { addedDeckName = nil } })) {
            Button("Done", role: .cancel) { }
        } message: {
            Text("\(addedDeckName ?? "This deck") is now editable in your library.")
        }
    }

    private func add(_ premadeDeck: PremadeDeck) {
        guard !libraryDecks.contains(where: { $0.name == premadeDeck.name }) else { return }
        let deck = Deck(name: premadeDeck.name, colorHex: premadeDeck.colorHex, deckType: premadeDeck.deckType, orderIndex: libraryDecks.count)
        for sourceCard in premadeDeck.cards {
            deck.cards.append(Flashcard(question: sourceCard.question, options: sourceCard.options, correctAnswer: sourceCard.correctAnswer, hint: sourceCard.hint))
        }
        context.insert(deck)
        try? context.save()
        addedDeckName = premadeDeck.name
    }
}

private struct DiscoverHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Discover")
                .font(.custom("Poppins-SemiBold", size: 28))
                .foregroundStyle(LearnAlertStyle.textPrimary)
            Text("Ready-made decks for languages, school, and skills.")
                .font(.custom("Poppins-Regular", size: 13))
                .foregroundStyle(LearnAlertStyle.textSecondary)
        }
        .padding(.horizontal, 20)
    }
}

private struct DiscoverSearchField: View {
    @Binding var searchText: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search templates", text: $searchText)
                .foregroundStyle(LearnAlertStyle.textPrimary)
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
        .nativeGlass(cornerRadius: 16)
        .padding(.horizontal)
    }
}

private struct DiscoverFilterRow: View {
    let categories: [String]
    @Binding var selection: String
    var compact = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                ForEach(categories, id: \.self) { category in
                    Button(category) { selection = category }
                        .font(compact ? .caption.bold() : .subheadline.bold())
                        .padding(.horizontal, compact ? 13 : 16)
                        .padding(.vertical, compact ? 7 : 9)
                        .foregroundStyle(selection == category ? LearnAlertStyle.indigoDeep : LearnAlertStyle.textPrimary)
                        .nativeGlass(cornerRadius: 18)
                        .overlay {
                            if selection == category { Capsule().stroke(LearnAlertStyle.indigo.opacity(0.7), lineWidth: 2) }
                        }
                }
            }
            .padding(.horizontal)
        }
    }
}

private struct PremadeDeckList: View {
    let decks: [PremadeDeck]
    let libraryDecks: [Deck]
    let add: (PremadeDeck) -> Void

    var body: some View {
        LazyVStack(spacing: 14) {
            ForEach(decks) { deck in
                NavigationLink(destination: PremadeDeckDetailView(deck: deck)) {
                    PremadeDeckRow(deck: deck, isAdded: libraryDecks.contains { $0.name == deck.name }, addAction: { add(deck) })
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
    }
}

private struct PremadeDeckRow: View {
    let deck: PremadeDeck
    let isAdded: Bool
    let addAction: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: categoryIcon)
                .font(.title2)
                .foregroundStyle(Color(hex: deck.colorHex))
                .frame(width: 48, height: 48)
                .background(Color(hex: deck.colorHex).opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 4) {
                Text(deck.name).font(.headline).foregroundStyle(LearnAlertStyle.textPrimary)
                Text("\(deck.subcategory) • \(deck.cards.count) cards").font(.caption).foregroundStyle(.secondary)
                Text(deck.description).font(.caption).foregroundStyle(LearnAlertStyle.textSecondary).lineLimit(2)
            }
            Spacer()
            Button(action: addAction) {
                Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle.fill")
                    .font(.title)
                    .foregroundStyle(isAdded ? .green : .cyan)
            }
            .disabled(isAdded)
            .accessibilityLabel(isAdded ? "Already in library" : "Add \(deck.name) to library")
        }
        .padding(14)
        .nativeGlass(cornerRadius: 18)
    }

    private var categoryIcon: String {
        switch deck.category {
        case "Languages": "character.book.closed.fill"
        case "Math": "function"
        case "Science": "atom"
        case "History": "building.columns.fill"
        case "Computing": "laptopcomputer"
        default: "graduationcap.fill"
        }
    }
}

struct PremadeDeckDetailView: View {
    @Environment(\.modelContext) private var context
    @Query private var libraryDecks: [Deck]
    let deck: PremadeDeck
    @State private var added = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(deck.description).foregroundStyle(.secondary)
                    Label("\(deck.cards.count) cards", systemImage: "rectangle.stack.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(Color(hex: deck.colorHex))
                }
                .padding(.vertical, 6)
            }
            Section("Preview") {
                ForEach(deck.cards) { card in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(card.question).font(.headline)
                        Text(card.correctAnswer).font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle(deck.name)
        .scrollContentBackground(.hidden)
        .safeAreaInset(edge: .bottom) {
            Button(action: addDeck) {
                Label(added ? "Added to Library" : "Add to Library", systemImage: added ? "checkmark" : "plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(added ? Color.green : LearnAlertStyle.indigo)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 11))
            }
            .disabled(added)
            .padding()
            .nativeGlass(cornerRadius: 0)
        }
        .onAppear { added = libraryDecks.contains { $0.name == deck.name } }
    }

    private func addDeck() {
        guard !libraryDecks.contains(where: { $0.name == deck.name }) else { return }
        let newDeck = Deck(name: deck.name, colorHex: deck.colorHex, deckType: deck.deckType, orderIndex: libraryDecks.count)
        for sourceCard in deck.cards {
            newDeck.cards.append(Flashcard(question: sourceCard.question, options: sourceCard.options, correctAnswer: sourceCard.correctAnswer, hint: sourceCard.hint))
        }
        context.insert(newDeck)
        try? context.save()
        added = true
    }
}
