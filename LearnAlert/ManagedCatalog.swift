import Foundation
import Combine
import CryptoKit
import Darwin

struct PremadeCard: Identifiable, Codable {
    let id: String
    let question: String
    var options: [String] = []
    let correctAnswer: String
    var hint: String = ""
    var cardType: FlashcardType = .multipleChoice
    var matchingLeftItems: [String] = []
    var matchingRightItems: [String] = []
    var promptImageName: String? = nil
    var answerImageName: String? = nil
    var optionImageNames: [String] = []
    var promptAudioName: String? = nil
    var fieldMedia: [String: CardFieldMedia] = [:]
    var correctOptionIndex: Int? = nil
    var sectionName: String = ""
    var ankiContent: AnkiCardContent? = nil

    var resolvedFieldMedia: [String: CardFieldMedia] {
        var fields = fieldMedia
        if let promptImageName { fields["prompt", default: .init()].image = promptImageName }
        if let promptAudioName { fields["prompt", default: .init()].audio = promptAudioName }
        if let answerImageName { fields["answer", default: .init()].image = answerImageName }
        for (index, image) in optionImageNames.enumerated() where !image.isEmpty {
            fields["option:\(index)", default: .init()].image = image
        }
        return fields.filter { !$0.value.isEmpty }
    }
}

struct PremadeDeck: Identifiable, Codable {
    let id: String
    let name: String
    let category: String
    let subcategory: String
    let description: String
    let colorHex: String
    let deckType: String
    let cards: [PremadeCard]
    var communitySourceID: String? = nil

    func isInLibrary(_ decks: [Deck]) -> Bool {
        if let communitySourceID { return decks.contains { $0.sourceCommunityID == communitySourceID } }
        return decks.contains { $0.sourcePremadeID == id }
    }
}

extension PremadeCard {
    private enum CodingKeys: String, CodingKey {
        case id, question, options, correctAnswer, hint, cardType, matchingLeftItems, matchingRightItems
        case promptImageName, answerImageName, optionImageNames, promptAudioName, fieldMedia, correctOptionIndex, sectionName, ankiContent
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(id: try c.decode(String.self, forKey: .id), question: try c.decode(String.self, forKey: .question),
            options: try c.decodeIfPresent([String].self, forKey: .options) ?? [], correctAnswer: try c.decode(String.self, forKey: .correctAnswer),
            hint: try c.decodeIfPresent(String.self, forKey: .hint) ?? "", cardType: try c.decode(FlashcardType.self, forKey: .cardType),
            matchingLeftItems: try c.decodeIfPresent([String].self, forKey: .matchingLeftItems) ?? [],
            matchingRightItems: try c.decodeIfPresent([String].self, forKey: .matchingRightItems) ?? [],
            promptImageName: try c.decodeIfPresent(String.self, forKey: .promptImageName),
            answerImageName: try c.decodeIfPresent(String.self, forKey: .answerImageName),
            optionImageNames: try c.decodeIfPresent([String].self, forKey: .optionImageNames) ?? [],
            promptAudioName: try c.decodeIfPresent(String.self, forKey: .promptAudioName),
            fieldMedia: try c.decodeIfPresent([String: CardFieldMedia].self, forKey: .fieldMedia) ?? [:],
            correctOptionIndex: try c.decodeIfPresent(Int.self, forKey: .correctOptionIndex),
            sectionName: try c.decodeIfPresent(String.self, forKey: .sectionName) ?? "", ankiContent: try c.decodeIfPresent(AnkiCardContent.self, forKey: .ankiContent))
    }
}

// MARK: - Curated Deck Catalog

enum PremadeDeckCatalog {
    static let mainCategories = ["All", "Languages", "Math", "Science", "History", "Computing", "Exam Prep"]

    static let subcategoriesByCategory: [String: [String]] = [
        "All": ["All"],
        "Languages": ["All", "Spanish", "Korean", "French", "Japanese", "German"],
        "Math": ["All", "Algebra", "Geometry", "Calculus", "Statistics"],
        "Science": ["All", "Biology", "Chemistry", "Physics", "Astronomy"],
        "History": ["All", "Ancient History", "US History", "World History", "European History"],
        "Computing": ["All", "Swift", "Programming", "Cybersecurity", "Data Structures"],
        "Exam Prep": ["All", "SAT", "MCAT", "Study Skills", "AP Prep"]
    ]

    @MainActor static var decks: [PremadeDeck] {
        bundledDecks.filter { $0.category != "Exam Prep" } + ManagedCatalogStore.shared.examDecks
    }

    static let bundledDecks: [PremadeDeck] = [
        // MARK: - Math Decks
        PremadeDeck(
            id: "algebra-basics",
            name: "Algebra Foundations & Formulas",
            category: "Math",
            subcategory: "Algebra",
            description: "Quadratic formula, exponent rules, factoring, and linear systems.",
            colorHex: "#4C89A8",
            deckType: "Mixed",
            cards: [
                PremadeCard(id: "alg-1", question: "Quadratic Formula", options: [], correctAnswer: "x = (-b ± √(b² - 4ac)) / (2a)", hint: "Solves ax² + bx + c = 0", cardType: .vocabulary),
                PremadeCard(id: "alg-2", question: "What is the product rule for exponents: xᵃ · xᵇ = ___?", options: ["xᵃ⁺ᵇ", "xᵃᵇ", "xᵃ⁻ᵇ", "(2x)ᵃ⁺ᵇ"], correctAnswer: "xᵃ⁺ᵇ", hint: "Add exponents when multiplying same base", cardType: .multipleChoice),
                PremadeCard(id: "alg-3", question: "Match algebraic laws to formulas", correctAnswer: "Matches", hint: "Connect properties", cardType: .matching, matchingLeftItems: ["Commutative Law", "Associative Law", "Distributive Law", "Difference of Squares"], matchingRightItems: ["a + b = b + a", "(a + b) + c = a + (b + c)", "a(b + c) = ab + ac", "a² - b² = (a-b)(a+b)"]),
                PremadeCard(id: "alg-4", question: "If 3x - 7 = 14, what is the value of x?", correctAnswer: "7", hint: "Add 7 then divide by 3", cardType: .fillBlank),
                PremadeCard(id: "alg-5", question: "What is the slope-intercept form of a linear equation?", options: [], correctAnswer: "y = mx + b (where m is slope and b is y-intercept)", hint: "Standard linear equation", cardType: .tapReveal)
            ]
        ),
        PremadeDeck(
            id: "geometry-essentials",
            name: "Geometry & Trigonometry",
            category: "Math",
            subcategory: "Geometry",
            description: "Pythagorean theorem, unit circle values, sine/cosine laws, and area formulas.",
            colorHex: "#5B70E0",
            deckType: "Mixed",
            cards: [
                PremadeCard(id: "geom-1", question: "What is the area of a circle with radius r?", options: ["πr²", "2πr", "πd", "4/3 πr³"], correctAnswer: "πr²", hint: "Pi times radius squared", cardType: .multipleChoice),
                PremadeCard(id: "geom-2", question: "In a right triangle, sin(θ) is defined as ___ over Hypotenuse.", correctAnswer: "Opposite", hint: "SOH in SOH CAH TOA", cardType: .fillBlank),
                PremadeCard(id: "geom-3", question: "Match trigonometric identities", correctAnswer: "Matches", hint: "Connect identities", cardType: .matching, matchingLeftItems: ["sin²(θ) + cos²(θ)", "tan(θ)", "Pythagorean Theorem", "Sum of triangle angles"], matchingRightItems: ["1", "sin(θ) / cos(θ)", "a² + b² = c²", "180° (π radians)"]),
                PremadeCard(id: "geom-4", question: "Euler's Formula for Polyhedra", options: [], correctAnswer: "V - E + F = 2 (Vertices - Edges + Faces = 2 for convex polyhedra)", hint: "Polyhedron formula", cardType: .vocabulary),
                PremadeCard(id: "geom-5", question: "What are the angles in a standard 30-60-90 special right triangle ratio?", options: [], correctAnswer: "Side lengths are in ratio 1 : √3 : 2 (opposite 30°, 60°, 90° respectively).", hint: "Special right triangle", cardType: .tapReveal)
            ]
        ),
        PremadeDeck(
            id: "calculus-derivatives",
            name: "Calculus Derivatives & Integrals",
            category: "Math",
            subcategory: "Calculus",
            description: "Power rule, chain rule, product rule, integration by parts, and fundamental theorem.",
            colorHex: "#3972B5",
            deckType: "Mixed",
            cards: [
                PremadeCard(id: "calc-1", question: "What is the derivative of f(x) = ln(x)?", options: ["1/x", "eˣ", "1/(2x)", "x ln(x)"], correctAnswer: "1/x", hint: "Reciprocal function", cardType: .multipleChoice),
                PremadeCard(id: "calc-2", question: "The derivative of sin(x) with respect to x is ___.", correctAnswer: "cos(x)", hint: "Standard trig derivative", cardType: .fillBlank),
                PremadeCard(id: "calc-3", question: "Match calculus rules to mathematical definitions", correctAnswer: "Matches", hint: "Connect rules", cardType: .matching, matchingLeftItems: ["Power Rule (d/dx xⁿ)", "Product Rule (d/dx uv)", "Quotient Rule (d/dx u/v)", "Chain Rule (d/dx f(g(x)))"], matchingRightItems: ["n · xⁿ⁻¹", "u'v + uv'", "(u'v - uv') / v²", "f'(g(x)) · g'(x)"]),
                PremadeCard(id: "calc-4", question: "Fundamental Theorem of Calculus (Part 1)", options: [], correctAnswer: "If F(x) = ∫[a to x] f(t) dt, then F'(x) = f(x). Differentiation and integration are inverse processes.", hint: "Core theorem of calculus", cardType: .vocabulary),
                PremadeCard(id: "calc-5", question: "What is the integral of e^(2x) dx?", options: [], correctAnswer: "(1/2) e^(2x) + C", hint: "Divide by the constant multiplier", cardType: .tapReveal)
            ]
        ),

        // MARK: - Science Decks
        PremadeDeck(
            id: "cell-biology",
            name: "Cell Biology & Genetics",
            category: "Science",
            subcategory: "Biology",
            description: "Organelles, DNA replication, transcription, translation, and mitosis/meiosis.",
            colorHex: "#38A169",
            deckType: "Mixed",
            cards: [
                PremadeCard(id: "bio-1", question: "Which cellular organelle is responsible for generating the majority of cellular ATP?", options: ["Mitochondria", "Ribosome", "Golgi Apparatus", "Endoplasmic Reticulum"], correctAnswer: "Mitochondria", hint: "Powerhouse of the cell", cardType: .multipleChoice),
                PremadeCard(id: "bio-2", question: "In DNA, Adenine pairs with ___ via two hydrogen bonds.", correctAnswer: "Thymine", hint: "A pairs with T in DNA", cardType: .fillBlank),
                PremadeCard(id: "bio-3", question: "Match organelles to functions", correctAnswer: "Matches", hint: "Connect functions", cardType: .matching, matchingLeftItems: ["Nucleus", "Ribosome", "Lysosome", "Chloroplast"], matchingRightItems: ["Houses genetic DNA", "Protein synthesis", "Digestive waste degradation", "Photosynthesis in plant cells"]),
                PremadeCard(id: "bio-4", question: "Mitosis vs Meiosis", options: [], correctAnswer: "Mitosis produces 2 genetically identical diploid (2n) daughter cells. Meiosis produces 4 genetically unique haploid (n) gametes.", hint: "Cell division comparison", cardType: .vocabulary),
                PremadeCard(id: "bio-5", question: "What enzyme unwinds the DNA double helix during replication?", options: [], correctAnswer: "DNA Helicase", hint: "Unzipping enzyme", cardType: .tapReveal)
            ]
        ),
        PremadeDeck(
            id: "general-chemistry",
            name: "General Chemistry & Periodic Table",
            category: "Science",
            subcategory: "Chemistry",
            description: "Stoichiometry, periodic trends, electronegativity, pH scale, and bonding.",
            colorHex: "#2B8A78",
            deckType: "Mixed",
            cards: [
                PremadeCard(id: "chem-1", question: "Which element has the highest electronegativity on the periodic table?", options: ["Fluorine (F)", "Oxygen (O)", "Chlorine (Cl)", "Francium (Fr)"], correctAnswer: "Fluorine (F)", hint: "Top right of periodic table (excluding noble gases)", cardType: .multipleChoice),
                PremadeCard(id: "chem-2", question: "A solution with a pH of 3 is classified as an ___.", correctAnswer: "acid", hint: "pH < 7 is acidic", cardType: .fillBlank),
                PremadeCard(id: "chem-3", question: "Match chemical bonds to descriptions", correctAnswer: "Matches", hint: "Connect bond types", cardType: .matching, matchingLeftItems: ["Covalent Bond", "Ionic Bond", "Hydrogen Bond", "Metallic Bond"], matchingRightItems: ["Sharing electron pairs", "Electrostatic transfer of electrons", "Dipole attraction with H-F/O/N", "Sea of delocalized electrons"]),
                PremadeCard(id: "chem-4", question: "Avogadro's Number", options: [], correctAnswer: "6.022 × 10²³ particles per mole. The number of atoms in exactly 12 grams of Carbon-12.", hint: "Mole constant", cardType: .vocabulary),
                PremadeCard(id: "chem-5", question: "What is Le Chatelier's Principle?", options: [], correctAnswer: "If a dynamic equilibrium is disturbed by changing conditions (temperature, pressure, concentration), the position of equilibrium shifts to counteract the change.", hint: "Equilibrium response", cardType: .tapReveal)
            ]
        ),
        PremadeDeck(
            id: "classical-physics",
            name: "Physics: Mechanics & Waves",
            category: "Science",
            subcategory: "Physics",
            description: "Newton's laws, energy conservation, momentum, Doppler effect, and electromagnetism.",
            colorHex: "#317496",
            deckType: "Mixed",
            cards: [
                PremadeCard(id: "phys-1", question: "What is Newton's Second Law of Motion formula?", options: ["F = ma", "E = mc²", "p = mv", "W = Fd"], correctAnswer: "F = ma", hint: "Force equals mass times acceleration", cardType: .multipleChoice),
                PremadeCard(id: "phys-2", question: "The SI unit of electrical resistance is the ___.", correctAnswer: "ohm", hint: "Represented by omega Ω", cardType: .fillBlank),
                PremadeCard(id: "phys-3", question: "Match physical quantities to SI units", correctAnswer: "Matches", hint: "Connect units", cardType: .matching, matchingLeftItems: ["Force", "Energy / Work", "Power", "Frequency"], matchingRightItems: ["Newton (N)", "Joule (J)", "Watt (W)", "Hertz (Hz)"]),
                PremadeCard(id: "phys-4", question: "Law of Conservation of Energy", options: [], correctAnswer: "Energy cannot be created or destroyed, only transformed from one form to another (e.g. potential to kinetic). Total energy in an isolated system remains constant.", hint: "Energy conservation", cardType: .vocabulary),
                PremadeCard(id: "phys-5", question: "What causes the Doppler Effect?", options: [], correctAnswer: "The observed change in frequency/wavelength of a wave in relation to an observer moving relative to the wave source.", hint: "Sound shift with motion", cardType: .tapReveal)
            ]
        ),

        // MARK: - History Decks
        PremadeDeck(
            id: "ancient-civilizations",
            name: "Ancient Civilizations",
            category: "History",
            subcategory: "Ancient History",
            description: "Egypt, Mesopotamia, Greece, Rome, and ancient governance.",
            colorHex: "#A47A49",
            deckType: "Mixed",
            cards: [
                PremadeCard(id: "anc-1", question: "The earliest known writing system, developed in Mesopotamia, was ___.", correctAnswer: "cuneiform", hint: "Wedge-shaped clay script", cardType: .fillBlank),
                PremadeCard(id: "anc-2", question: "Direct democracy was first notably developed in which Greek city-state?", options: ["Sparta", "Athens", "Corinth", "Thebes"], correctAnswer: "Athens", hint: "Home of the Parthenon", cardType: .multipleChoice),
                PremadeCard(id: "anc-3", question: "Match ancient wonders to civilizations", correctAnswer: "Matches", hint: "Connect wonders", cardType: .matching, matchingLeftItems: ["Great Pyramid", "Hanging Gardens", "Colosseum", "Parthenon"], matchingRightItems: ["Ancient Egypt", "Babylon", "Ancient Rome", "Classical Greece"]),
                PremadeCard(id: "anc-4", question: "Code of Hammurabi", options: [], correctAnswer: "One of the earliest and most complete written legal codes, proclaimed by the Babylonian king Hammurabi (eye for an eye).", hint: "Ancient legal doctrine", cardType: .vocabulary),
                PremadeCard(id: "anc-5", question: "What river was crucial to the agricultural survival of Ancient Egypt?", options: [], correctAnswer: "The Nile River (flooding deposited nutrient-rich silt)", hint: "Longest African river", cardType: .tapReveal)
            ]
        ),
        PremadeDeck(
            id: "us-history",
            name: "US History Milestones",
            category: "History",
            subcategory: "US History",
            description: "Founding documents, Civil War, Constitutional amendments, and modern eras.",
            colorHex: "#9B5E58",
            deckType: "Mixed",
            cards: [
                PremadeCard(id: "ush-1", question: "The United States Declaration of Independence was adopted in the year ___.", correctAnswer: "1776", hint: "July 4th founding year", cardType: .fillBlank),
                PremadeCard(id: "ush-2", question: "Which amendment to the US Constitution abolished slavery?", options: ["1st Amendment", "13th Amendment", "14th Amendment", "19th Amendment"], correctAnswer: "13th Amendment", hint: "Ratified in 1865", cardType: .multipleChoice),
                PremadeCard(id: "ush-3", question: "Match historic events to their years", correctAnswer: "Matches", hint: "Connect years", cardType: .matching, matchingLeftItems: ["Louisiana Purchase", "Civil War End", "Pearl Harbor Attack", "Moon Landing"], matchingRightItems: ["1803", "1865", "1941", "1969"]),
                PremadeCard(id: "ush-4", question: "Bill of Rights", options: [], correctAnswer: "The first ten amendments to the United States Constitution, guaranteeing individual liberties and legal protections.", hint: "First 10 amendments", cardType: .vocabulary),
                PremadeCard(id: "ush-5", question: "Who was the primary author of the Declaration of Independence?", options: [], correctAnswer: "Thomas Jefferson", hint: "3rd US President", cardType: .tapReveal)
            ]
        ),

        // MARK: - Computing Decks
        PremadeDeck(
            id: "swift-basics",
            name: "Swift & SwiftUI Foundations",
            category: "Computing",
            subcategory: "Swift",
            description: "Immutability, optionals, protocols, structs, and reactive UI states.",
            colorHex: "#E06C45",
            deckType: "Mixed",
            cards: [
                PremadeCard(id: "sw-1", question: "In Swift, declare an immutable constant using the ___ keyword.", correctAnswer: "let", hint: "Contrasts with var", cardType: .fillBlank),
                PremadeCard(id: "sw-2", question: "Which Swift type is a value type that copies on assignment?", options: ["Class", "Struct", "Actor", "Closure"], correctAnswer: "Struct", hint: "Contrasts with reference types", cardType: .multipleChoice),
                PremadeCard(id: "sw-3", question: "Match SwiftUI property wrappers to their roles", correctAnswer: "Matches", hint: "Connect state wrappers", cardType: .matching, matchingLeftItems: ["@State", "@Binding", "@Environment", "@Query"], matchingRightItems: ["Local view-owned state", "Two-way reference to parent state", "Read shared system/app environment", "Fetch SwiftData models dynamically"]),
                PremadeCard(id: "sw-4", question: "Optional unwrapping", options: [], correctAnswer: "Techniques (guard let, if let, nil-coalescing ??, optional chaining ?.) to safely extract a wrapped value from an Optional without runtime crashing.", hint: "Safe nil handling", cardType: .vocabulary),
                PremadeCard(id: "sw-5", question: "What keyword in Swift defines a protocol requirement or implementation contract?", options: [], correctAnswer: "protocol (e.g. protocol Identifiable { var id: ID { get } })", hint: "Interface definition", cardType: .tapReveal)
            ]
        ),
        PremadeDeck(
            id: "programming-concepts",
            name: "Core Computer Science",
            category: "Computing",
            subcategory: "Programming",
            description: "Algorithms, Big-O notation, data structures, and recursion.",
            colorHex: "#557AA8",
            deckType: "Mixed",
            cards: [
                PremadeCard(id: "cs-1", question: "A FIFO (First-In, First-Out) data structure is called a ___.", correctAnswer: "Queue", hint: "Waiting line structure", cardType: .fillBlank),
                PremadeCard(id: "cs-2", question: "What is the average time complexity of searching in a balanced Binary Search Tree (BST)?", options: ["O(1)", "O(log n)", "O(n)", "O(n²)"], correctAnswer: "O(log n)", hint: "Halving search space each step", cardType: .multipleChoice),
                PremadeCard(id: "cs-3", question: "Match data structures to properties", correctAnswer: "Matches", hint: "Connect structures", cardType: .matching, matchingLeftItems: ["Array", "Hash Table", "Stack", "Graph"], matchingRightItems: ["Contiguous indexed memory", "O(1) key-value lookup", "LIFO push/pop access", "Vertices connected by edges"]),
                PremadeCard(id: "cs-4", question: "Recursion", options: [], correctAnswer: "A programming method where a function calls itself to solve smaller instances of the same subproblem until reaching a base case.", hint: "Function self-invocation", cardType: .vocabulary),
                PremadeCard(id: "cs-5", question: "What is the difference between synchronous and asynchronous execution?", options: [], correctAnswer: "Synchronous blocks execution until task finishes; Asynchronous executes in background without blocking the main thread.", hint: "Blocking vs Non-blocking", cardType: .tapReveal)
            ]
        ),

        // MARK: - Exam Prep Decks
        PremadeDeck(
            id: "sat-vocabulary",
            name: "SAT Academic Vocabulary",
            category: "Exam Prep",
            subcategory: "SAT",
            description: "High-yield passage vocabulary with contextual fill-in blanks and definitions.",
            colorHex: "#735FA8",
            deckType: "Mixed",
            cards: [
                PremadeCard(id: "sat-1", question: "The scientist offered additional experiments to ___ (confirm / support) her initial hypothesis.", correctAnswer: "corroborate", hint: "Word starting with C meaning confirm with evidence", cardType: .fillBlank),
                PremadeCard(id: "sat-2", question: "What is the closest synonym for 'PRAGMATIC'?", options: ["Practical and realistic", "Theoretical and abstract", "Careless and hurried", "Arrogant and dismissive"], correctAnswer: "Practical and realistic", hint: "Focus on workable results", cardType: .multipleChoice),
                PremadeCard(id: "sat-3", question: "Match SAT words to definitions", correctAnswer: "Matches", hint: "Connect meanings", cardType: .matching, matchingLeftItems: ["Ubiquitous", "Ephemeral", "Meticulous", "Ambiguous"], matchingRightItems: ["Present everywhere", "Short-lived / fleeting", "Extremely precise & careful", "Open to multiple interpretations"]),
                PremadeCard(id: "sat-4", question: "Anachronistic", options: [], correctAnswer: "Belonging or appropriate to an earlier period, especially so as to seem conspicuously old-fashioned or out of chronological order.", hint: "Chronological mismatch", cardType: .vocabulary),
                PremadeCard(id: "sat-5", question: "Define 'LOQUACIOUS'.", options: [], correctAnswer: "Tending to talk a great deal; extremely talkative or wordy.", hint: "Talkative", cardType: .tapReveal)
            ]
        ),
        PremadeDeck(
            id: "study-skills",
            name: "Cognitive Learning & Study Skills",
            category: "Exam Prep",
            subcategory: "Study Skills",
            description: "Spaced repetition, retrieval practice, interleaving, and active recall.",
            colorHex: "#548B72",
            deckType: "Mixed",
            cards: [
                PremadeCard(id: "ss-1", question: "Testing memory without looking at answers is called ___ practice.", correctAnswer: "retrieval", hint: "Active recall technique", cardType: .fillBlank),
                PremadeCard(id: "ss-2", question: "Which practice involves spacing review sessions over expanding intervals of time?", options: ["Cramming", "Spaced Repetition", "Massed Practice", "Passive Highlighting"], correctAnswer: "Spaced Repetition", hint: "Fights the forgetting curve", cardType: .multipleChoice),
                PremadeCard(id: "ss-3", question: "Match learning science concepts", correctAnswer: "Matches", hint: "Connect concepts", cardType: .matching, matchingLeftItems: ["Interleaving", "Feynman Technique", "Dual Coding", "Pomodoro"], matchingRightItems: ["Mixing problem types", "Explaining simply to a novice", "Combining visual & verbal formats", "25min focus + 5min rest"]),
                PremadeCard(id: "ss-4", question: "Ebbinghaus Forgetting Curve", options: [], correctAnswer: "Hypothesis showing how memory decays exponentially over time without active reinforcement. Repetitions flatten the curve.", hint: "Memory decay model", cardType: .vocabulary),
                PremadeCard(id: "ss-5", question: "Why is sleep critical for effective long-term learning?", options: [], correctAnswer: "During deep sleep and REM cycles, the hippocampus transfers short-term memories to the neocortex for consolidation.", hint: "Memory consolidation", cardType: .tapReveal)
            ]
        )
    ]
}

// The manifest contains only published revisions. Draft edits never reach learners.
struct ManagedCatalogManifest: Codable {
    let schemaVersion: Int
    let revision: String
    let initialized: Bool
    let items: [ManagedCatalogItem]
    var deliveryProfile: String? = nil
}

struct ManagedCatalogItem: Codable {
    let id: String
    let kind: String
    let title: String
    let revision: Int
    let updatedAt: Double
    let contentURL: String
    var assets: [ManagedCatalogAsset]? = nil
    var deliveryProfile: String? = nil
    var requiredContracts: [String]? = nil
    var contentDigest: String? = nil
}

struct ManagedCatalogAsset: Codable {
    let id: String
    let reference: String
    let contentType: String
    let url: String
}

private struct ManagedCatalogDocument: Decodable {
    let id: String
    let kind: String
    let revision: Int
    let document: ManagedCatalogContent
    var deliveryProfile: String? = nil
    var requiredContracts: [String]? = nil
    var contentDigest: String? = nil

    enum CodingKeys: String, CodingKey { case id, kind, revision, document, schemaVersion, deliveryProfile, requiredContracts, contentDigest, payload }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        kind = try values.decode(String.self, forKey: .kind)
        revision = try values.decode(Int.self, forKey: .revision)
        deliveryProfile = try values.decodeIfPresent(String.self, forKey: .deliveryProfile)
        requiredContracts = try values.decodeIfPresent([String].self, forKey: .requiredContracts)
        contentDigest = try values.decodeIfPresent(String.self, forKey: .contentDigest)
        if let profile = deliveryProfile {
            guard CourseDeliveryContracts.modernProfiles.contains(profile), try values.decode(Int.self, forKey: .schemaVersion) == 2,
                  let requiredContracts, CourseDeliveryContracts.supports(requiredContracts), Set(requiredContracts).isSubset(of: CourseDeliveryContracts.required(for: profile)),
                  CourseDeliveryContracts.required(for: profile).isSubset(of: Set(requiredContracts)), let contentDigest else { throw CocoaError(.coderReadCorrupt) }
            let bytes = try values.decode(Data.self, forKey: .payload)
            guard SHA256.hash(data: bytes).map({ String(format: "%02x", $0) }).joined() == contentDigest else { throw CocoaError(.coderReadCorrupt) }
            switch kind {
            case "course": document = .course(try JSONDecoder().decode(CourseDefinition.self, from: bytes))
            case "exam": document = .exam(try JSONDecoder().decode(PremadeDeck.self, from: bytes))
            default: throw CocoaError(.coderReadCorrupt)
            }
            return
        }
        guard !values.contains(.payload), !values.contains(.schemaVersion), requiredContracts == nil, contentDigest == nil else { throw CocoaError(.coderReadCorrupt) }
        switch kind {
        case "course": document = .course(try values.decode(CourseDefinition.self, forKey: .document))
        case "exam": document = .exam(try values.decode(PremadeDeck.self, forKey: .document))
        default: throw CocoaError(.coderReadCorrupt)
        }
    }
}

private enum ManagedCatalogContent { case course(CourseDefinition), exam(PremadeDeck) }

private struct ManagedCatalogCache: Codable {
    let manifest: ManagedCatalogManifest
    let documents: [String: Data]
    var retainedCourses: [String: CourseDefinition]
}

/// App and notification extension read the same atomic last-good snapshot. No network is
/// required to study; a failed refresh never mixes old lessons with new checkpoint data.
@MainActor
final class ManagedCatalogStore: ObservableObject {
    static let shared = ManagedCatalogStore(profile: CourseDeliveryContracts.profile, replacementAllowed: { previous, candidate in
        let snapshot = CourseLearningStore.shared.snapshot()
        guard CourseLearningStore.shared.lastError == nil else { return false }
        return snapshot.permitsCourseReplacement(previous: previous, candidate: candidate)
    })
    static let legacyShared = ManagedCatalogStore()
    static let practiceV1Shared = ManagedCatalogStore(profile: "practice-v1")
    @Published private(set) var revision: String?
    @Published private(set) var lastError: String?
    private var cache: ManagedCatalogCache?
    private var decodedContents: [String: ManagedCatalogContent] = [:]
    private var fileDate: Date?
    private var fileSource: URL?
    private var lastAttempt: Date?
    private var refreshing = false
    private let cacheURL: URL
    private let defaults: UserDefaults?
    private let session: URLSession
    private let developmentPreview: Bool
    private let profile: String
    private let replacementAllowed: ((CourseDefinition, CourseDefinition) -> Bool)?

    init(directory: URL? = nil, defaults: UserDefaults? = UserDefaults(suiteName: "group.com.learnalert.shared"), session: URLSession = .shared, developmentPreview: Bool = false, profile: String = "legacy-v1", replacementAllowed: ((CourseDefinition, CourseDefinition) -> Bool)? = nil) {
        self.defaults = defaults
        self.session = session
        self.developmentPreview = developmentPreview
        self.profile = profile
        self.replacementAllowed = replacementAllowed
        let base = directory ?? ManagedCatalogMedia.directory.deletingLastPathComponent()
        cacheURL = base.appendingPathComponent(profile == "legacy-v1" ? "managed-catalog-v1.json" : CourseDeliveryContracts.modernProfiles.contains(profile) ? "managed-catalog-v2-\(profile).json" : "managed-catalog-unsupported.json")
        reloadFromDisk()
    }

    var courses: [CourseDefinition] {
        reloadFromDisk()
        guard let cache, cache.manifest.initialized else {
            return defaults?.bool(forKey: "managed_catalog_initialized") == true ? [] : CourseCurriculumCatalog.bundledCourses
        }
        return cache.manifest.items.compactMap { item in
            guard case .course(let course)? = document(item.id) else { return nil }
            return course
        }
    }

    var examDecks: [PremadeDeck] {
        reloadFromDisk()
        guard let cache, cache.manifest.initialized else {
            return defaults?.bool(forKey: "managed_catalog_initialized") == true ? [] : PremadeDeckCatalog.bundledDecks.filter { $0.category == "Exam Prep" }
        }
        return cache.manifest.items.compactMap { item in
            guard case .exam(let deck)? = document(item.id) else { return nil }
            return deck
        }
    }

    func course(for id: String) -> CourseDefinition? {
        if let course = courses.first(where: { $0.id == id }) { return course }
        // A retired course stays available only to its existing learner. It is not
        // reintroduced into Discover, and enrollment/SRS values are never deleted.
        guard enrolledIDs.contains(id) else { return nil }
        return cache?.retainedCourses[id]
    }

    private var enrolledIDs: Set<String> {
        var ids = Set(defaults?.stringArray(forKey: "course_enrolled_ids") ?? [])
        if let active = defaults?.string(forKey: "course_active_enrollment_id") { ids.insert(active) }
        return ids
    }

    private func document(_ id: String) -> ManagedCatalogContent? { decodedContents[id] }

    func reloadFromDisk() {
        // Validate the current namespace before any compatible upgrade source.
        // A backup has exactly the same integrity/admission rules as its primary;
        // reading an older namespace never rewrites it or changes route assignment.
        let base = cacheURL.deletingLastPathComponent()
        var sources: [(URL, String)] = [(cacheURL, profile)]
        if CourseDeliveryContracts.modernProfiles.contains(profile) {
            sources.append((cacheURL.appendingPathExtension("backup"), profile))
            if profile == CourseDeliveryContracts.profile, !FileManager.default.fileExists(atPath: cacheURL.path) {
                let v1 = base.appendingPathComponent("managed-catalog-v2-practice-v1.json")
                sources += [(v1, "practice-v1"), (v1.appendingPathExtension("backup"), "practice-v1")]
            }
            if !FileManager.default.fileExists(atPath: cacheURL.path), !FileManager.default.fileExists(atPath: cacheURL.appendingPathExtension("backup").path) {
                sources.append((base.appendingPathComponent("managed-catalog-v1.json"), "legacy-v1"))
            }
        }
        for (path, sourceProfile) in sources {
            guard let attributes = try? FileManager.default.attributesOfItem(atPath: path.path), let modified = attributes[.modificationDate] as? Date else { continue }
            if path == fileSource && modified == fileDate { return }
            guard let data = try? Data(contentsOf: path), let loaded = try? JSONDecoder().decode(ManagedCatalogCache.self, from: data),
                  let decoded = try? Self.decodeContents(loaded.manifest, documents: loaded.documents, profile: sourceProfile) else { continue }
            guard permitsSnapshot(decoded) else {
                if cache == nil { lastError = "A compatible saved course is needed to resume your assigned route." }
                continue
            }
            if cache == nil { lastError = nil }
            cache = loaded; decodedContents = decoded
            if loaded.manifest.initialized { defaults?.set(true, forKey: "managed_catalog_initialized") }
            fileDate = modified; fileSource = path; revision = loaded.manifest.revision
            return
        }
    }

    func refresh(force: Bool = false) async {
        guard !developmentPreview, !refreshing, force || lastAttempt.map({ Date().timeIntervalSince($0) >= 60 }) ?? true else { return }
        refreshing = true
        lastAttempt = Date()
        defer { refreshing = false }
        do {
            if CourseDeliveryContracts.modernProfiles.contains(profile),
               !FileManager.default.fileExists(atPath: cacheURL.deletingLastPathComponent().appendingPathComponent("managed-catalog-v1.json").path) {
                let compatible = ManagedCatalogStore(directory: cacheURL.deletingLastPathComponent(), defaults: defaults, session: session)
                await compatible.refresh(force: true)
                guard compatible.lastError == nil, compatible.cache != nil else { throw CocoaError(.fileReadUnknown) }
                if cache == nil && permitsSnapshot(compatible.decodedContents) { cache = compatible.cache; decodedContents = compatible.decodedContents; revision = compatible.revision }
            }
            let manifestData = try await fetch(profile == "legacy-v1" ? "https://api.learnalertapp.com/v1/catalog" : "https://api.learnalertapp.com/v1/catalog?profile=\(profile)", maximumBytes: 4 * 1024 * 1024)
            let manifest = try JSONDecoder().decode(ManagedCatalogManifest.self, from: manifestData)
            if CourseDeliveryContracts.modernProfiles.contains(profile) && manifest.schemaVersion == 1 {
                guard cache?.manifest.schemaVersion != 2 else { throw CocoaError(.coderReadCorrupt) }
                let compatible = ManagedCatalogStore(directory: cacheURL.deletingLastPathComponent(), defaults: defaults, session: session)
                await compatible.refresh(force: true)
                guard compatible.lastError == nil, permitsSnapshot(compatible.decodedContents) else { throw CocoaError(.fileReadUnknown) }
                cache = compatible.cache; decodedContents = compatible.decodedContents; revision = compatible.revision; lastError = nil
                return
            }
            guard Self.supportsManifest(manifest, profile: profile) else { throw CocoaError(.coderReadCorrupt) }
            // The server has not been initialized yet. Leave the bundled catalog intact.
            guard manifest.initialized else { lastError = nil; return }
            if cache?.manifest.revision == manifest.revision && cache?.manifest.schemaVersion == manifest.schemaVersion && cache?.manifest.deliveryProfile == manifest.deliveryProfile { lastError = nil; return }
            var documents: [String: Data] = [:]
            var requestedDocuments: [(String, String, Int)] = []
            for item in manifest.items {
                if let previous = cache?.manifest.items.first(where: { $0.id == item.id && $0.revision == item.revision && $0.kind == item.kind && $0.deliveryProfile == item.deliveryProfile && $0.contentDigest == item.contentDigest }),
                   let data = cache?.documents[previous.id] { documents[item.id] = data }
                else { requestedDocuments.append((item.id, item.contentURL, 32 * 1024 * 1024)) }
            }
            documents.merge(try await fetchMany(requestedDocuments)) { _, newest in newest }
            // Decode and validate each document once. The same prepared values
            // are installed after media arrives instead of parsing all cards again.
            let decoded = try Self.decodeContents(manifest, documents: documents, profile: profile)
            // Download immutable assets before publishing a snapshot to the UI/extension.
            var assets: [String: ManagedCatalogAsset] = [:]
            for asset in manifest.items.flatMap({ $0.assets ?? [] }) {
                guard let target = ManagedCatalogMedia.url(reference: asset.reference) else { throw CocoaError(.fileReadInvalidFileName) }
                if !FileManager.default.fileExists(atPath: target.path) { assets[asset.reference] = asset }
            }
            let requestedAssets = assets.values.map {
                ($0.reference, $0.url, $0.contentType.hasPrefix("audio/") ? CardAudioStore.maximumBytes : 12 * 1024 * 1024)
            }
            for start in stride(from: 0, to: requestedAssets.count, by: 3) {
                let batch = Array(requestedAssets[start..<min(start + 3, requestedAssets.count)])
                for (reference, data) in try await fetchMany(batch) {
                    if let asset = assets[reference] { try ManagedCatalogMedia.save(data, asset: asset) }
                }
            }
            try install(manifest, documents: documents, decoded: decoded)
            lastError = nil
        } catch { lastError = error.localizedDescription }
    }

    private func fetchMany(_ requests: [(String, String, Int)]) async throws -> [String: Data] {
        var result: [String: Data] = [:]
        for start in stride(from: 0, to: requests.count, by: 3) {
            let batch = Array(requests[start..<min(start + 3, requests.count)])
            let values = try await withThrowingTaskGroup(of: (String, Data).self) { group in
                for (id, url, maximumBytes) in batch {
                    group.addTask { (id, try await self.fetch(url, maximumBytes: maximumBytes)) }
                }
                var values: [String: Data] = [:]
                for try await (id, data) in group { values[id] = data }
                return values
            }
            result.merge(values) { _, latest in latest }
        }
        return result
    }

    private func fetch(_ rawURL: String, maximumBytes: Int) async throws -> Data {
        guard let url = URL(string: rawURL), url.scheme == "https", url.host == "api.learnalertapp.com" else { throw URLError(.badURL) }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 45)
        request.setValue("application/json, image/*, audio/*", forHTTPHeaderField: "Accept")
        if CourseDeliveryContracts.modernProfiles.contains(profile) { request.setValue(CourseDeliveryContracts.supported.sorted().joined(separator: ","), forHTTPHeaderField: "X-LearnAlert-Contracts") }
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse, response.statusCode == 200,
              response.url?.scheme == "https", response.url?.host == "api.learnalertapp.com",
              !data.isEmpty, data.count <= maximumBytes else { throw URLError(.badServerResponse) }
        return data
    }

    /// Separate from transport so replacement/deletion and offline behavior can be tested.
    func install(_ manifest: ManagedCatalogManifest, documents: [String: Data]) throws {
        let decoded = try Self.decodeContents(manifest, documents: documents, profile: profile)
        try install(manifest, documents: documents, decoded: decoded)
    }

    private func permitsSnapshot(_ decoded: [String: ManagedCatalogContent]) -> Bool {
        guard CourseDeliveryContracts.modernProfiles.contains(profile) else { return true }
        for content in decoded.values {
            if case .course(let candidate) = content, replacementAllowed?(candidate, candidate) == false { return false }
        }
        for (id, previousContent) in decodedContents {
            guard case .course(let previous) = previousContent, case .course(let candidate)? = decoded[id] else { continue }
            if previous.learning?.starter != nil {
                let oldIDs = Set(previous.units.flatMap(\.lessons).map(\.id)), newIDs = Set(candidate.units.flatMap(\.lessons).map(\.id))
                guard candidate.learning?.starter != nil, oldIDs.isSubset(of: newIDs) else { return false }
                guard newIDs.subtracting(oldIDs).isSubset(of: Set(candidate.learning?.starter?.lessonIDs ?? [])) else { return false }
                for unit in previous.units {
                    guard let next = candidate.units.first(where: { $0.id == unit.id }), unit.checkpointQuiz == next.checkpointQuiz else { return false }
                    if unit.checkpointQuiz != nil, Set(unit.lessons.map(\.id)) != Set(next.lessons.map(\.id)) { return false }
                    for lesson in unit.lessons {
                        guard let nextLesson = candidate.units.flatMap(\.lessons).first(where: { $0.id == lesson.id }), Set(lesson.cards.map(\.id)) == Set(nextLesson.cards.map(\.id)) else { return false }
                        for card in lesson.cards {
                            guard let nextCard = nextLesson.cards.first(where: { $0.id == card.id }), Set(card.activity?.exercise?.prerequisiteIDs ?? []) == Set(nextCard.activity?.exercise?.prerequisiteIDs ?? []) else { return false }
                        }
                    }
                }
            }
            guard replacementAllowed?(previous, candidate) ?? true else { return false }
        }
        return true
    }
    private func install(_ manifest: ManagedCatalogManifest, documents: [String: Data], decoded: [String: ManagedCatalogContent]) throws {
        try FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let descriptor = open(cacheURL.appendingPathExtension("lock").path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw CocoaError(.fileWriteUnknown) }
        defer { close(descriptor) }
        guard flock(descriptor, LOCK_EX) == 0 else { throw CocoaError(.fileWriteUnknown) }
        defer { flock(descriptor, LOCK_UN) }
        // Re-read inside the cross-process lock before deciding whether an app
        // or extension response can replace the installed snapshot.
        fileDate = nil; reloadFromDisk()
        guard manifest.initialized else { return }
        guard permitsSnapshot(decoded) else { throw CocoaError(.coderReadCorrupt) }
        var retained = cache?.retainedCourses ?? [:]
        for course in courses where enrolledIDs.contains(course.id) { retained[course.id] = course }
        for content in decoded.values {
            if case .course(let course) = content,
               enrolledIDs.contains(course.id) { retained[course.id] = course }
        }
        let replacement = ManagedCatalogCache(manifest: manifest, documents: documents, retainedCourses: retained)
        let data = try JSONEncoder().encode(replacement)
        try FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if CourseDeliveryContracts.modernProfiles.contains(profile) {
            // A complete, validated ready snapshot exists before replacing the
            // primary file. Either copy can recover an interrupted/corrupt read.
            try data.write(to: cacheURL.appendingPathExtension("backup"), options: .atomic)
        }
        try data.write(to: cacheURL, options: .atomic)
        cache = replacement
        decodedContents = decoded
        fileDate = (try? FileManager.default.attributesOfItem(atPath: cacheURL.path)[.modificationDate]) as? Date
        fileSource = cacheURL
        defaults?.set(true, forKey: "managed_catalog_initialized")
        defaults?.synchronize()
        revision = manifest.revision
    }

    private static func supportsManifest(_ manifest: ManagedCatalogManifest, profile: String) -> Bool {
        guard profile == "legacy-v1" || CourseDeliveryContracts.modernProfiles.contains(profile) else { return false }
        if manifest.schemaVersion == 1 { return profile == "legacy-v1" && manifest.deliveryProfile == nil && manifest.items.allSatisfy { $0.deliveryProfile == nil && $0.requiredContracts == nil && $0.contentDigest == nil } }
        guard CourseDeliveryContracts.modernProfiles.contains(profile), manifest.schemaVersion == 2, manifest.deliveryProfile == profile else { return false }
        return manifest.items.allSatisfy { item in
            if item.deliveryProfile == "legacy-v1" { return item.requiredContracts?.isEmpty == true && item.contentDigest == nil }
            guard let selected = item.deliveryProfile, selected == profile || (profile == "practice-v2" && selected == "practice-v1") else { return false }
            return item.requiredContracts.map { CourseDeliveryContracts.supports($0) && CourseDeliveryContracts.required(for: selected).isSubset(of: Set($0)) && Set($0).isSubset(of: CourseDeliveryContracts.required(for: profile)) } == true && item.contentDigest?.count == 64
        }
    }
    private static func decodeContents(_ manifest: ManagedCatalogManifest, documents: [String: Data], profile: String) throws -> [String: ManagedCatalogContent] {
        guard supportsManifest(manifest, profile: profile), !manifest.revision.isEmpty,
              Set(manifest.items.map(\.id)).count == manifest.items.count else { throw CocoaError(.coderReadCorrupt) }
        var contents: [String: ManagedCatalogContent] = [:]
        for item in manifest.items {
            guard let data = documents[item.id] else { throw CocoaError(.coderReadCorrupt) }
            let decoded = try JSONDecoder().decode(ManagedCatalogDocument.self, from: data)
            guard decoded.id == item.id, decoded.kind == item.kind, decoded.revision == item.revision,
                  decoded.deliveryProfile == (item.deliveryProfile == "legacy-v1" ? nil : item.deliveryProfile),
                  decoded.contentDigest == item.contentDigest,
                  Set(decoded.requiredContracts ?? []) == Set(item.requiredContracts ?? []) else { throw CocoaError(.coderReadCorrupt) }
            switch decoded.document {
            case .course(let course):
                guard course.id == item.id else { throw CocoaError(.coderReadCorrupt) }
                if item.deliveryProfile == "practice-v2", !CourseDeliveryContracts.validatesV2(course) { throw CocoaError(.coderReadCorrupt) }
                if item.deliveryProfile == "practice-v1", course.learning?.dialogues != nil || course.units.flatMap(\.lessons).flatMap(\.cards).contains(where: { $0.activity?.exercise?.format == "textMatching" || $0.activity?.exercise?.context != nil || $0.activity?.exercise?.models != nil || $0.activity?.exercise?.showsMeaningLabels != nil }) { throw CocoaError(.coderReadCorrupt) }
            case .exam(let deck): guard deck.id == item.id else { throw CocoaError(.coderReadCorrupt) }
            }
            contents[item.id] = decoded.document
        }
        return contents
    }
}

/// Immutable catalog media is intentionally separate from editable user attachments.
/// UUID validation prevents a public document from traversing the shared container.
enum ManagedCatalogMedia {
    static var directory: URL {
        let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.learnalert.shared")
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("ManagedCatalogMedia", isDirectory: true)
    }
    static func url(reference: String) -> URL? {
        guard reference.hasPrefix("catalog:"), UUID(uuidString: String(reference.dropFirst(8))) != nil else { return nil }
        return directory.appendingPathComponent(String(reference.dropFirst(8)).lowercased())
    }
    static func contentType(reference: String) -> String? {
        guard let url = url(reference: reference) else { return nil }
        return try? String(contentsOf: url.appendingPathExtension("mime"), encoding: .utf8)
    }
    static func save(_ data: Data, asset: ManagedCatalogAsset) throws {
        guard let url = url(reference: asset.reference), !data.isEmpty else { throw CocoaError(.fileReadCorruptFile) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        try asset.contentType.write(to: url.appendingPathExtension("mime"), atomically: true, encoding: .utf8)
    }
}


extension ManagedCatalogStore {
    /// Development-only isolated host calls this; production cache is never used.
    func installStarterPreview(baseCourse: CourseDefinition, componentData: Data) throws {
        guard developmentPreview, baseCourse.id == "spanish-course",
              let component = try JSONSerialization.jsonObject(with: componentData) as? [String: Any],
              let unit = component["unit"] as? [String: Any], let learning = component["learning"] as? [String: Any],
              var document = try JSONSerialization.jsonObject(with: JSONEncoder().encode(baseCourse)) as? [String: Any] else { throw CocoaError(.coderReadCorrupt) }
        var units = document["units"] as? [[String: Any]] ?? []
        if let index = units.firstIndex(where: { $0["id"] as? String == unit["id"] as? String }) { units[index] = unit }
        else { units.append(unit) }
        document["units"] = units
        var guides = document["guides"] as? [String: Any] ?? [:]
        if let id = unit["id"] as? String { guides[id] = (unit["lessons"] as? [[String: Any]] ?? []).compactMap { lesson -> [String: Any]? in guard let note = lesson["tipNote"] as? String, !note.isEmpty else { return nil }; return ["title": lesson["title"] as? String ?? "Guide", "rule": note, "examples": [String]()] } }; document["guides"] = guides
        var graph = document["learning"] as? [String: Any] ?? [:]
        for field in ["vocabulary", "concepts", "dialogues"] {
            if field == "dialogues", learning[field] as? [String: Any] == nil { continue }
            var entries = graph[field] as? [String: Any] ?? [:]
            entries.merge(learning[field] as? [String: Any] ?? [:]) { _, pilot in pilot }; graph[field] = entries
        }
        graph["starter"] = learning["starter"]; document["learning"] = graph
        if profile == "practice-v2" {
            let payload = try JSONSerialization.data(withJSONObject: document)
            let digest = SHA256.hash(data: payload).map { String(format: "%02x", $0) }.joined()
            let contracts = CourseDeliveryContracts.supported.sorted()
            let envelope: [String: Any] = ["schemaVersion": 2, "id": baseCourse.id, "kind": "course", "revision": 2, "deliveryProfile": "practice-v2", "requiredContracts": contracts, "contentDigest": digest, "payload": payload.base64EncodedString()]
            var item = ManagedCatalogItem(id: baseCourse.id, kind: "course", title: baseCourse.title, revision: 2, updatedAt: 0, contentURL: "development-preview:spanish-course")
            item.deliveryProfile = "practice-v2"; item.requiredContracts = contracts; item.contentDigest = digest
            try install(.init(schemaVersion: 2, revision: "development-preview-cafe-2", initialized: true, items: [item], deliveryProfile: "practice-v2"), documents: [baseCourse.id: JSONSerialization.data(withJSONObject: envelope)])
            return
        }
        let envelope: [String: Any] = ["id": baseCourse.id, "kind": "course", "revision": 1, "document": document]
        let data = try JSONSerialization.data(withJSONObject: envelope)
        let item = ManagedCatalogItem(id: baseCourse.id, kind: "course", title: baseCourse.title, revision: 1, updatedAt: 0, contentURL: "development-preview:spanish-course")
        try install(.init(schemaVersion: 1, revision: "development-preview-pilot-1", initialized: true, items: [item]), documents: [baseCourse.id: data])
    }
}
