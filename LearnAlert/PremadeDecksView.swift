import SwiftData
import SwiftUI

struct PremadeCard: Identifiable {
    let id: String
    let question: String
    var options: [String] = []
    let correctAnswer: String
    var hint: String = ""
    var cardType: FlashcardType = .multipleChoice
    var matchingLeftItems: [String] = []
    var matchingRightItems: [String] = []
    var promptImageName: String? = nil
    var optionImageNames: [String] = []
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

private struct LanguageTerm {
    let target: String
    let english: String
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

    static let decks: [PremadeDeck] = languageDecks + [
        // MARK: - Math Decks
        PremadeDeck(
            id: "mental-math",
            name: "Mental Math Mastery",
            category: "Math",
            subcategory: "Arithmetic",
            description: "Fast calculation strategies, fill-in blanks, and arithmetic drills.",
            colorHex: "#A27B55",
            deckType: "Mixed",
            cards: [
                PremadeCard(id: "mm-1", question: "What is 15 + 27?", options: ["32", "40", "42", "52"], correctAnswer: "42", hint: "Add 20, then 7.", cardType: .multipleChoice),
                PremadeCard(id: "mm-2", question: "9 × 8 = ___", correctAnswer: "72", hint: "Ten eights minus eight.", cardType: .fillBlank),
                PremadeCard(id: "mm-3", question: "Match multiplication facts", correctAnswer: "Matches", hint: "Connect products", cardType: .matching, matchingLeftItems: ["6 × 7", "8 × 8", "9 × 6", "12 × 5"], matchingRightItems: ["42", "64", "54", "60"]),
                PremadeCard(id: "mm-4", question: "Commutative Property", options: [], correctAnswer: "a + b = b + a (order does not affect sum or product)", hint: "Order invariance", cardType: .vocabulary),
                PremadeCard(id: "mm-5", question: "Calculate 25% of 80 in your head.", options: [], correctAnswer: "20 (One-fourth of 80)", hint: "Divide 80 by 4", cardType: .tapReveal),
                PremadeCard(id: "mm-6", question: "100 − 37 = ___", correctAnswer: "63", hint: "Subtract 40, then add back 3", cardType: .fillBlank)
            ]
        ),
        PremadeDeck(
            id: "algebra-basics",
            name: "Algebra Foundations",
            category: "Math",
            subcategory: "Algebra",
            description: "Equations, variable isolation, and algebraic laws.",
            colorHex: "#4C89A8",
            deckType: "Mixed",
            cards: [
                PremadeCard(id: "alg-1", question: "Solve for x: 3x = 18", options: ["3", "6", "9", "15"], correctAnswer: "6", hint: "Divide both sides by 3.", cardType: .multipleChoice),
                PremadeCard(id: "alg-2", question: "If 2x + 5 = 17, then x = ___", correctAnswer: "6", hint: "Subtract 5, then divide by 2", cardType: .fillBlank),
                PremadeCard(id: "alg-3", question: "Match algebraic terms to descriptions", correctAnswer: "Matches", hint: "Connect terms", cardType: .matching, matchingLeftItems: ["Variable", "Coefficient", "Constant", "Exponent"], matchingRightItems: ["A symbol for unknown value", "Number multiplied by variable", "A fixed number value", "Power to raise a number"]),
                PremadeCard(id: "alg-4", question: "Quadratic Formula", options: [], correctAnswer: "x = (-b ± √(b² - 4ac)) / (2a)", hint: "Solves ax² + bx + c = 0", cardType: .vocabulary),
                PremadeCard(id: "alg-5", question: "What is the slope-intercept form of a line?", options: [], correctAnswer: "y = mx + b (m is slope, b is y-intercept)", hint: "Relates x and y", cardType: .tapReveal)
            ]
        ),
        PremadeDeck(
            id: "geometry-essentials",
            name: "Geometry Essentials",
            category: "Math",
            subcategory: "Geometry",
            description: "Angles, area formulas, geometric theorems, and shapes.",
            colorHex: "#527FB5",
            deckType: "Mixed",
            cards: [
                PremadeCard(id: "geo-1", question: "A triangle has interior angles that always sum to ___ degrees.", correctAnswer: "180", hint: "Straight line angle sum", cardType: .fillBlank),
                PremadeCard(id: "geo-2", question: "How many degrees are in a right angle?", options: ["45°", "90°", "180°", "360°"], correctAnswer: "90°", hint: "Square corner angle", cardType: .multipleChoice),
                PremadeCard(id: "geo-3", question: "Match shapes to area formulas", correctAnswer: "Matches", hint: "Connect formulas", cardType: .matching, matchingLeftItems: ["Rectangle", "Triangle", "Circle", "Trapezoid"], matchingRightItems: ["width × height", "½ × base × height", "π × r²", "½(a + b) × h"]),
                PremadeCard(id: "geo-4", question: "Pythagorean Theorem", options: [], correctAnswer: "In a right triangle, a² + b² = c² (where c is the hypotenuse).", hint: "Right triangle relation", cardType: .vocabulary),
                PremadeCard(id: "geo-5", question: "What is the circumference formula for a circle with radius r?", options: [], correctAnswer: "C = 2πr (or πd)", hint: "Distance around the circle", cardType: .tapReveal)
            ]
        ),
        PremadeDeck(
            id: "fractions",
            name: "Fraction Fundamentals",
            category: "Math",
            subcategory: "Fractions",
            description: "Operations, reciprocals, and equivalent fractions.",
            colorHex: "#728B5B",
            deckType: "Mixed",
            cards: [
                PremadeCard(id: "frac-1", question: "Which fraction is equivalent to 1/2?", options: ["2/3", "2/4", "3/4", "1/3"], correctAnswer: "2/4", hint: "Multiply numerator and denominator by 2.", cardType: .multipleChoice),
                PremadeCard(id: "frac-2", question: "The reciprocal of 2/3 is ___.", correctAnswer: "3/2", hint: "Invert the fraction", cardType: .fillBlank),
                PremadeCard(id: "frac-3", question: "Match fractions to decimals", correctAnswer: "Matches", hint: "Connect pairs", cardType: .matching, matchingLeftItems: ["1/4", "1/2", "3/4", "1/5"], matchingRightItems: ["0.25", "0.50", "0.75", "0.20"]),
                PremadeCard(id: "frac-4", question: "Numerator vs Denominator", options: [], correctAnswer: "Numerator: top number (parts you have); Denominator: bottom number (total equal parts in whole).", hint: "Top vs bottom", cardType: .vocabulary),
                PremadeCard(id: "frac-5", question: "1/4 + 2/4 = ___", correctAnswer: "3/4", hint: "Add the numerators over the common denominator", cardType: .fillBlank)
            ]
        ),

        // MARK: - Science Decks
        PremadeDeck(
            id: "cell-biology",
            name: "Cell Biology & Organelles",
            category: "Science",
            subcategory: "Biology",
            description: "Cellular anatomy, organelle roles, and cellular respiration.",
            colorHex: "#4D9B79",
            deckType: "Mixed",
            cards: [
                PremadeCard(id: "bio-1", question: "Which organelle contains genomic DNA in eukaryotes?", options: ["Nucleus", "Ribosome", "Vacuole", "Cell Wall"], correctAnswer: "Nucleus", hint: "The control center", cardType: .multipleChoice),
                PremadeCard(id: "bio-2", question: "The primary organelle responsible for generating cellular ATP is the ___.", correctAnswer: "mitochondria", hint: "Powerhouse of the cell", cardType: .fillBlank),
                PremadeCard(id: "bio-3", question: "Match organelles to their main functions", correctAnswer: "Matches", hint: "Connect organelles", cardType: .matching, matchingLeftItems: ["Ribosome", "Chloroplast", "Lysosome", "Golgi Body"], matchingRightItems: ["Protein synthesis", "Photosynthesis", "Waste digestion", "Packaging & sorting"]),
                PremadeCard(id: "bio-4", question: "Osmosis", options: [], correctAnswer: "The passive movement of water molecules across a selectively permeable membrane from lower solute to higher solute concentration.", hint: "Water transport", cardType: .vocabulary),
                PremadeCard(id: "bio-5", question: "What pigment inside chloroplasts captures light energy for photosynthesis?", options: [], correctAnswer: "Chlorophyll", hint: "Gives plants green color", cardType: .tapReveal)
            ]
        ),
        PremadeDeck(
            id: "chemistry-atoms",
            name: "Atoms & Periodic Elements",
            category: "Science",
            subcategory: "Chemistry",
            description: "Subatomic particles, atomic numbers, valence electrons, and bonding.",
            colorHex: "#8B6CC1",
            deckType: "Mixed",
            cards: [
                PremadeCard(id: "chem-1", question: "A proton carries a ___ electrical charge.", correctAnswer: "positive", hint: "Opposite of an electron", cardType: .fillBlank),
                PremadeCard(id: "chem-2", question: "What identifies an element on the periodic table?", options: ["Neutron count", "Proton count (Atomic Number)", "Electron shell size", "Molecular mass"], correctAnswer: "Proton count (Atomic Number)", hint: "The atomic number", cardType: .multipleChoice),
                PremadeCard(id: "chem-3", question: "Match chemical symbols to elements", correctAnswer: "Matches", hint: "Connect elements", cardType: .matching, matchingLeftItems: ["Na", "Fe", "Au", "K"], matchingRightItems: ["Sodium", "Iron", "Gold", "Potassium"]),
                PremadeCard(id: "chem-4", question: "Covalent Bond", options: [], correctAnswer: "A chemical bond formed when two atoms share one or more pairs of valence electrons.", hint: "Electron sharing", cardType: .vocabulary),
                PremadeCard(id: "chem-5", question: "What are isotopes?", options: [], correctAnswer: "Atoms of the same element with the same number of protons but different numbers of neutrons.", hint: "Neutron variations", cardType: .tapReveal)
            ]
        ),
        PremadeDeck(
            id: "physics-motion",
            name: "Motion & Newton's Laws",
            category: "Science",
            subcategory: "Physics",
            description: "Velocity, acceleration, force, friction, and Newton's three laws.",
            colorHex: "#477FA3",
            deckType: "Mixed",
            cards: [
                PremadeCard(id: "phy-1", question: "The SI unit of force is the ___.", correctAnswer: "newton", hint: "Named after Isaac Newton (N)", cardType: .fillBlank),
                PremadeCard(id: "phy-2", question: "For every action, there is an equal and opposite reaction. This is Newton's ___ Law.", options: ["First", "Second", "Third", "Universal"], correctAnswer: "Third", hint: "Action-reaction pair", cardType: .multipleChoice),
                PremadeCard(id: "phy-3", question: "Match physics concepts to SI units", correctAnswer: "Matches", hint: "Connect units", cardType: .matching, matchingLeftItems: ["Velocity", "Acceleration", "Energy / Work", "Power"], matchingRightItems: ["m/s", "m/s²", "Joule (J)", "Watt (W)"]),
                PremadeCard(id: "phy-4", question: "Inertia", options: [], correctAnswer: "The tendency of an object to resist changes in its state of motion (Newton's First Law).", hint: "Resistance to acceleration", cardType: .vocabulary),
                PremadeCard(id: "phy-5", question: "What formula defines Newton's Second Law of Motion?", options: [], correctAnswer: "F = ma (Force equals mass times acceleration)", hint: "Force, mass, acceleration", cardType: .tapReveal)
            ]
        ),
        PremadeDeck(
            id: "astronomy",
            name: "Solar System & Cosmos",
            category: "Science",
            subcategory: "Astronomy",
            description: "Planets, gravity, star lifecycles, and cosmic phenomena.",
            colorHex: "#5D61A8",
            deckType: "Mixed",
            cards: [
                PremadeCard(id: "astro-1", question: "The largest planet in our solar system is ___.", correctAnswer: "Jupiter", hint: "The gas giant with the Great Red Spot", cardType: .fillBlank),
                PremadeCard(id: "astro-2", question: "Which planet is known as the Red Planet due to iron oxide on its surface?", options: ["Venus", "Mars", "Mercury", "Saturn"], correctAnswer: "Mars", hint: "Fourth planet from the Sun", cardType: .multipleChoice),
                PremadeCard(id: "astro-3", question: "Match celestial objects to classifications", correctAnswer: "Matches", hint: "Connect classes", cardType: .matching, matchingLeftItems: ["Sun", "Moon", "Pluto", "Titan"], matchingRightItems: ["Yellow Dwarf Star", "Earth's natural satellite", "Dwarf Planet", "Saturn's largest moon"]),
                PremadeCard(id: "astro-4", question: "Light-Year", options: [], correctAnswer: "The distance that light travels in a vacuum in one Julian year (approx. 9.46 trillion km or 5.88 trillion miles).", hint: "Cosmic distance unit", cardType: .vocabulary),
                PremadeCard(id: "astro-5", question: "What galaxy is our solar system located in?", options: [], correctAnswer: "Milky Way Galaxy", hint: "A barred spiral galaxy", cardType: .tapReveal)
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
        PremadeDeck(
            id: "world-history",
            name: "World History Turning Points",
            category: "History",
            subcategory: "World History",
            description: "Renaissance, Gutenberg press, world wars, and the Industrial Revolution.",
            colorHex: "#7C735E",
            deckType: "Mixed",
            cards: [
                PremadeCard(id: "wh-1", question: "The Industrial Revolution began in ___ in the late 18th century.", correctAnswer: "Great Britain", hint: "Country of steam and textiles", cardType: .fillBlank),
                PremadeCard(id: "wh-2", question: "In what year did the Berlin Wall fall, signaling the end of the Cold War?", options: ["1945", "1961", "1989", "1991"], correctAnswer: "1989", hint: "Late 1980s landmark", cardType: .multipleChoice),
                PremadeCard(id: "wh-3", question: "Match historical figures to achievements", correctAnswer: "Matches", hint: "Connect figures", cardType: .matching, matchingLeftItems: ["Johannes Gutenberg", "Leonardo da Vinci", "Alexander the Great", "Nelson Mandela"], matchingRightItems: ["Movable type printing", "Mona Lisa & Polymath", "Macedonian Empire", "Anti-apartheid leadership"]),
                PremadeCard(id: "wh-4", question: "The Renaissance", options: [], correctAnswer: "A fervent period of European cultural, artistic, political, and economic rebirth from the 14th to 17th centuries, starting in Italy.", hint: "Cultural rebirth", cardType: .vocabulary),
                PremadeCard(id: "wh-5", question: "What event triggered the outbreak of World War I in 1914?", options: [], correctAnswer: "The assassination of Archduke Franz Ferdinand of Austria in Sarajevo.", hint: "Sarajevo assassination", cardType: .tapReveal)
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
        PremadeDeck(
            id: "cybersecurity-basics",
            name: "Cybersecurity & InfoSec",
            category: "Computing",
            subcategory: "Cybersecurity",
            description: "Encryption, authentication, phishing defense, and network security.",
            colorHex: "#486C74",
            deckType: "Mixed",
            cards: [
                PremadeCard(id: "sec-1", question: "HTTPS encrypts data in transit using the ___ protocol.", correctAnswer: "TLS", hint: "Transport Layer Security (or SSL)", cardType: .fillBlank),
                PremadeCard(id: "sec-2", question: "What attack involves deceiving users into revealing passwords via fraudulent emails?", options: ["DDoS", "Phishing", "Buffer Overflow", "SQL Injection"], correctAnswer: "Phishing", hint: "Impersonating trusted entities", cardType: .multipleChoice),
                PremadeCard(id: "sec-3", question: "Match security terms to definitions", correctAnswer: "Matches", hint: "Connect terms", cardType: .matching, matchingLeftItems: ["2FA / MFA", "Public Key Cryptography", "Firewall", "Salting"], matchingRightItems: ["Secondary login verification", "Asymmetric encryption key pair", "Network traffic filter", "Adding random data to hashed passwords"]),
                PremadeCard(id: "sec-4", question: "Zero Trust Architecture", options: [], correctAnswer: "A security model requiring all users inside or outside the network to be authenticated, authorized, and continuously validated before access is granted.", hint: "Never trust, always verify", cardType: .vocabulary),
                PremadeCard(id: "sec-5", question: "What makes a password cryptographically resilient?", options: [], correctAnswer: "High entropy: sufficient length (16+ chars), randomness, and unique across every account (managed via password manager).", hint: "Length + Entropy", cardType: .tapReveal)
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
            id: "sat-math",
            name: "SAT Math Practice",
            category: "Exam Prep",
            subcategory: "SAT",
            description: "Slope, algebra, geometry, exponents, and probability drills.",
            colorHex: "#4E83A5",
            deckType: "Mixed",
            cards: [
                PremadeCard(id: "satm-1", question: "If 2x + 3 = 11, then x = ___", correctAnswer: "4", hint: "Subtract 3, then divide by 2", cardType: .fillBlank),
                PremadeCard(id: "satm-2", question: "What is the slope of the line passing through (0, 1) and (2, 5)?", options: ["1", "2", "3", "4"], correctAnswer: "2", hint: "Rise / Run = (5 - 1) / (2 - 0)", cardType: .multipleChoice),
                PremadeCard(id: "satm-3", question: "Match equations to properties", correctAnswer: "Matches", hint: "Connect types", cardType: .matching, matchingLeftItems: ["y = mx + b", "y = ax² + bx + c", "x² + y² = r²", "a / b = c / d"], matchingRightItems: ["Linear function", "Parabola / Quadratic", "Circle centered at origin", "Proportion cross-multiplication"]),
                PremadeCard(id: "satm-4", question: "Discriminant (b² - 4ac)", options: [], correctAnswer: "If > 0: two distinct real roots. If = 0: exactly one real root. If < 0: two complex/imaginary roots.", hint: "Quadratic root predictor", cardType: .vocabulary),
                PremadeCard(id: "satm-5", question: "What is 20% of 150?", options: [], correctAnswer: "30 (0.20 × 150 = 30)", hint: "10% is 15, double it", cardType: .tapReveal)
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

    private static let languageDecks: [PremadeDeck] =
        languageSeries(language: "Spanish", slug: "spanish", color: "#D76C82", terms: terms(from: spanishTerms))
        + languageSeries(language: "Korean", slug: "korean", color: "#6A83C5", terms: terms(from: koreanTerms))
        + languageSeries(language: "Chinese", slug: "chinese", color: "#D95B4F", terms: terms(from: chineseTerms))
        + languageSeries(language: "French", slug: "french", color: "#668CC8", terms: terms(from: frenchTerms))
        + languageSeries(language: "Japanese", slug: "japanese", color: "#C76A77", terms: terms(from: japaneseTerms))
        + languageSeries(language: "German", slug: "german", color: "#9C7A43", terms: terms(from: germanTerms))
        + languageSeries(language: "Italian", slug: "italian", color: "#4B9B74", terms: terms(from: italianTerms))

    private static func languageSeries(
        language: String,
        slug: String,
        color: String,
        terms: [LanguageTerm]
    ) -> [PremadeDeck] {
        let deck1 = PremadeDeck(
            id: "\(slug)-essentials",
            name: "\(language) Essentials & Vocab",
            category: "Languages",
            subcategory: language,
            description: "Core vocabulary cards, definitions, and essential phrase matching.",
            colorHex: color,
            deckType: "Mixed",
            cards: buildLanguageMixedCards(id: "\(slug)-essentials", language: language, terms: Array(terms.prefix(15)))
        )

        let deck2 = PremadeDeck(
            id: "\(slug)-quiz",
            name: "\(language) Interactive Quiz",
            category: "Languages",
            subcategory: language,
            description: "Multiple-choice recognition challenges and translation options.",
            colorHex: color,
            deckType: "Quiz",
            cards: buildLanguageQuizCards(id: "\(slug)-quiz", language: language, terms: Array(terms.prefix(15)))
        )

        let deck3 = PremadeDeck(
            id: "\(slug)-matching",
            name: "\(language) Match Pairs & Recall",
            category: "Languages",
            subcategory: language,
            description: "Connect words with instant visual feedback and fill-in blanks.",
            colorHex: color,
            deckType: "Mixed",
            cards: buildLanguageMatchingAndBlanks(id: "\(slug)-matching", language: language, terms: Array(terms.prefix(15)))
        )

        return [deck1, deck2, deck3]
    }

    private static func buildLanguageMixedCards(id: String, language: String, terms: [LanguageTerm]) -> [PremadeCard] {
        var cards: [PremadeCard] = []
        for (idx, term) in terms.prefix(6).enumerated() {
            if idx % 2 == 0 {
                cards.append(PremadeCard(
                    id: "\(id)-voc-\(idx)",
                    question: term.target,
                    options: [],
                    correctAnswer: term.english,
                    hint: "\(language) word meaning",
                    cardType: .vocabulary
                ))
            } else {
                cards.append(PremadeCard(
                    id: "\(id)-rev-\(idx)",
                    question: "How do you say \"\(term.english)\" in \(language)?",
                    options: [],
                    correctAnswer: term.target,
                    hint: "Think of \(language) phrase",
                    cardType: .tapReveal
                ))
            }
        }
        if terms.count >= 4 {
            let left = Array(terms.prefix(4).map { $0.target })
            let right = Array(terms.prefix(4).map { $0.english })
            cards.append(PremadeCard(
                id: "\(id)-match-1",
                question: "Match \(language) words to English",
                options: [],
                correctAnswer: "Matches",
                hint: "Tap matching pairs",
                cardType: .matching,
                matchingLeftItems: left,
                matchingRightItems: right
            ))
        }
        return cards
    }

    private static func buildLanguageQuizCards(id: String, language: String, terms: [LanguageTerm]) -> [PremadeCard] {
        terms.enumerated().map { index, term in
            let candidates = (0..<4).map { terms[(index + $0) % terms.count].english }
            let rotation = index % candidates.count
            let options = Array(candidates[rotation...] + candidates[..<rotation])
            return PremadeCard(
                id: "\(id)-mc-\(index)",
                question: "What does \"\(term.target)\" mean?",
                options: options,
                correctAnswer: term.english,
                hint: "Common \(language) expression",
                cardType: .multipleChoice
            )
        }
    }

    private static func buildLanguageMatchingAndBlanks(id: String, language: String, terms: [LanguageTerm]) -> [PremadeCard] {
        var cards: [PremadeCard] = []
        for (idx, term) in terms.prefix(4).enumerated() {
            cards.append(PremadeCard(
                id: "\(id)-blank-\(idx)",
                question: "Translate \"\(term.english)\" into \(language): ___",
                options: [],
                correctAnswer: term.target,
                hint: "Type the exact \(language) word",
                cardType: .fillBlank
            ))
        }
        if terms.count >= 8 {
            let left1 = Array(terms[0..<4].map { $0.target })
            let right1 = Array(terms[0..<4].map { $0.english })
            cards.append(PremadeCard(
                id: "\(id)-match-1",
                question: "Match \(language) vocabulary (Part 1)",
                options: [],
                correctAnswer: "Matches",
                hint: "Connect pairs",
                cardType: .matching,
                matchingLeftItems: left1,
                matchingRightItems: right1
            ))
            let left2 = Array(terms[4..<8].map { $0.target })
            let right2 = Array(terms[4..<8].map { $0.english })
            cards.append(PremadeCard(
                id: "\(id)-match-2",
                question: "Match \(language) vocabulary (Part 2)",
                options: [],
                correctAnswer: "Matches",
                hint: "Connect pairs",
                cardType: .matching,
                matchingLeftItems: left2,
                matchingRightItems: right2
            ))
        }
        return cards
    }

    private static func terms(from source: String) -> [LanguageTerm] {
        source.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: "|", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { return nil }
            return LanguageTerm(target: parts[0], english: parts[1])
        }
    }

    private static let spanishTerms = """
Hola|Hello
Adiós|Goodbye
Por favor|Please
Gracias|Thank you
Sí|Yes
No|No
Disculpe|Excuse me
Lo siento|Sorry
Ayuda|Help
Agua|Water
Comida|Food
Casa|House
Familia|Family
Amigo|Friend
Madre|Mother
Padre|Father
Día|Day
Noche|Night
Hoy|Today
Mañana|Tomorrow
"""

    private static let koreanTerms = """
안녕하세요|Hello
안녕히 가세요|Goodbye
주세요|Please
감사합니다|Thank you
네|Yes
아니요|No
실례합니다|Excuse me
죄송합니다|Sorry
도와주세요|Help
물|Water
음식|Food
집|House
가족|Family
친구|Friend
어머니|Mother
아버지|Father
하루|Day
밤|Night
오늘|Today
내일|Tomorrow
"""

    private static let chineseTerms = """
你好|Hello
再见|Goodbye
请|Please
谢谢|Thank you
是|Yes
不|No
不好意思|Excuse me
对不起|Sorry
救命|Help
水|Water
食物|Food
家|House
家庭|Family
朋友|Friend
母亲|Mother
父亲|Father
天|Day
晚上|Night
今天|Today
明天|Tomorrow
"""

    private static let frenchTerms = """
Bonjour|Hello
Au revoir|Goodbye
S’il vous plaît|Please
Merci|Thank you
Oui|Yes
Non|No
Excusez-moi|Excuse me
Pardon|Sorry
Aide|Help
Eau|Water
Nourriture|Food
Maison|House
Famille|Family
Ami|Friend
Mère|Mother
Père|Father
Jour|Day
Nuit|Night
Aujourd’hui|Today
Demain|Tomorrow
"""

    private static let japaneseTerms = """
こんにちは|Hello
さようなら|Goodbye
お願いします|Please
ありがとう|Thank you
はい|Yes
いいえ|No
すみません|Excuse me
ごめんなさい|Sorry
助けて|Help
水|Water
食べ物|Food
家|House
家族|Family
友達|Friend
母|Mother
父|Father
日|Day
夜|Night
今日|Today
明日|Tomorrow
"""

    private static let germanTerms = """
Hallo|Hello
Auf Wiedersehen|Goodbye
Bitte|Please
Danke|Thank you
Ja|Yes
Nein|No
Entschuldigung|Excuse me
Es tut mir leid|Sorry
Hilfe|Help
Wasser|Water
Essen|Food
Haus|House
Familie|Family
Freund|Friend
Mutter|Mother
Vater|Father
Tag|Day
Nacht|Night
Heute|Today
Morgen|Tomorrow
"""

    private static let italianTerms = """
Ciao|Hello
Arrivederci|Goodbye
Per favore|Please
Grazie|Thank you
Sì|Yes
No|No
Mi scusi|Excuse me
Mi dispiace|Sorry
Aiuto|Help
Acqua|Water
Cibo|Food
Casa|House
Famiglia|Family
Amico|Friend
Madre|Mother
Padre|Father
Giorno|Day
Notte|Night
Oggi|Today
Domani|Tomorrow
"""
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
                Text("Discover")
                    .font(.custom("Poppins-Bold", size: 30, relativeTo: .largeTitle))
                    .foregroundStyle(LearnAlertStyle.textPrimary)
                    .padding(.horizontal, 20)

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
            .padding(.top, 22)
        }
        .background(LearnAlertStyle.courseCanvas.ignoresSafeArea())
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
            let card = Flashcard(
                question: sourceCard.question,
                options: sourceCard.options,
                correctAnswer: sourceCard.correctAnswer,
                hint: sourceCard.hint,
                cardType: sourceCard.cardType,
                matchingLeftItems: sourceCard.matchingLeftItems,
                matchingRightItems: sourceCard.matchingRightItems,
                promptImageName: sourceCard.promptImageName,
                optionImageNames: sourceCard.optionImageNames
            )
            deck.cards.append(card)
        }
        context.insert(deck)
        try? context.save()
        InteractionSoundPlayer.shared.play(.addDeck)
        addedDeckName = premadeDeck.name
    }
}

private struct DiscoverSearchField: View {
    @Binding var searchText: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(LearnAlertStyle.textSecondary)
            TextField("Search discover decks...", text: $searchText)
                .font(.custom("Poppins-Medium", size: 14))
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
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(LearnAlertStyle.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(LearnAlertStyle.hairline, lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }
}

private struct DiscoverFilterRow: View {
    let categories: [String]
    @Binding var selection: String
    var compact: Bool = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories, id: \.self) { category in
                    let isSelected = selection == category
                    Button {
                        withAnimation(.snappy) { selection = category }
                    } label: {
                        Text(category)
                            .font(.custom(isSelected ? "Poppins-SemiBold" : "Poppins-Medium", size: compact ? 12 : 13))
                            .padding(.horizontal, compact ? 12 : 16)
                            .padding(.vertical, compact ? 6 : 8)
                            .background(isSelected ? LearnAlertStyle.indigo : LearnAlertStyle.surface)
                            .foregroundStyle(isSelected ? Color.white : LearnAlertStyle.textPrimary)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(isSelected ? Color.clear : LearnAlertStyle.hairline, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
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
                PremadeDeckCard(deck: deck, isAdded: libraryDecks.contains(where: { $0.name == deck.name }), onAdd: { add(deck) })
            }
        }
        .padding(.horizontal, 20)
    }
}

private struct PremadeDeckCard: View {
    let deck: PremadeDeck
    let isAdded: Bool
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(hex: deck.colorHex).opacity(0.18))
                    .frame(width: 44, height: 44)
                Image(systemName: categoryIcon(deck.category))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color(hex: deck.colorHex))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(deck.name)
                        .font(.custom("Poppins-SemiBold", size: 15))
                        .foregroundStyle(LearnAlertStyle.textPrimary)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    Text("\(deck.cards.count) cards")
                        .font(.custom("Poppins-Medium", size: 11))
                        .foregroundStyle(LearnAlertStyle.textSecondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.04), in: Capsule())
                }

                // Card type pill badges
                HStack(spacing: 4) {
                    let types = Array(Set(deck.cards.map { $0.cardType }))
                    ForEach(types, id: \.self) { type in
                        HStack(spacing: 3) {
                            Image(systemName: type.icon)
                                .font(.system(size: 8))
                            Text(type.title)
                                .font(.custom("Poppins-Medium", size: 9))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.05), in: Capsule())
                        .foregroundStyle(LearnAlertStyle.textSecondary)
                    }
                }
            }

            Button {
                onAdd()
            } label: {
                Image(systemName: isAdded ? "checkmark" : "plus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(isAdded ? LearnAlertStyle.textSecondary : Color.white)
                    .frame(width: 36, height: 36)
                    .background(isAdded ? Color.gray.opacity(0.15) : LearnAlertStyle.indigo)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(isAdded)
            .accessibilityLabel(isAdded ? "\(deck.name) already added" : "Add \(deck.name)")
        }
        .padding(12)
        .background(LearnAlertStyle.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(LearnAlertStyle.hairline, lineWidth: 1)
        )
    }

    private func categoryIcon(_ category: String) -> String {
        switch category {
        case "Languages": "globe.americas.fill"
        case "Math": "function"
        case "Science": "atom"
        case "History": "scroll.fill"
        case "Computing": "laptopcomputer"
        case "Exam Prep": "graduationcap.fill"
        default: "folder.fill"
        }
    }
}
