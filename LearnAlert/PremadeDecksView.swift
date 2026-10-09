import SwiftData
import SwiftUI
import AuthenticationServices

// MARK: - Models for Premade / Discover Decks

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
    var promptAudioName: String? = nil
    var sectionName: String = ""
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
    var communitySourceID: String? = nil
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

    static let decks: [PremadeDeck] = [
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

// MARK: - Main Discover Hub View (2-Column Category Grid)

struct PremadeDecksView: View {
    @Environment(\.modelContext) private var context
    @Query private var libraryDecks: [Deck]
    @ObservedObject private var progressManager = CourseProgressManager.shared

    @State private var addedDeckName: String?
    @State private var showingCourses = false
    @State private var showingAllCommunity = false
    @State private var showingAllPremade = false
    @State private var showingExamPrep = false
    @State private var showingShareSheet = false
    @State private var activeCourseForPath: CourseDefinition?
    @State private var searchedCourse: CourseDefinition?

    private var enrolledCourse: CourseDefinition? {
        guard let activeId = progressManager.activeCourseId else { return nil }
        return CourseCurriculumCatalog.course(for: activeId)
    }

    private var activeCompletionPercentage: Double {
        guard let course = enrolledCourse else { return 0 }
        return progressManager.completionPercentage(for: course)
    }

    // Preserved for future search restoration
    @State private var discoverSearch = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Discover")
                            .font(StudyStudioStyle.title(28))
                        Text("Your next little breakthrough.")
                            .font(StudyStudioStyle.body(13))
                            .foregroundStyle(StudyStudioStyle.secondary)
                    }
                    Spacer()
                    Button {
                        showingShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18, weight: .medium))
                            .frame(width: 44, height: 44)
                            .background(StudyStudioStyle.field, in: Circle())
                    }
                    .accessibilityLabel("Share a deck")
                }
                .foregroundStyle(StudyStudioStyle.ink)

                /*
                // Search bar (hidden temporarily as requested, search logic & helpers preserved below)
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass").font(.system(size: 20))
                    TextField("Search courses & decks", text: $discoverSearch)
                        .font(StudyStudioStyle.body(15))
                        .textInputAutocapitalization(.never)
                        .submitLabel(.search)
                    if !discoverSearch.isEmpty {
                        Button { discoverSearch = "" } label: {
                            Image(systemName: "xmark.circle.fill").frame(width: 44, height: 44)
                        }.accessibilityLabel("Clear search")
                    }
                }
                .foregroundStyle(StudyStudioStyle.secondary)
                .padding(.horizontal, 16).frame(minHeight: 56)
                .background(StudyStudioStyle.field, in: RoundedRectangle(cornerRadius: 20))
                */

                if discoverSearch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    if let course = enrolledCourse {
                        StudyDestinationCard(
                            eyebrow: "CONTINUE LEARNING",
                            title: course.title,
                            subtitle: progressManager.currentLesson(for: course)?.title ?? "Explore your learning path",
                            badge: "\(Int(activeCompletionPercentage * 100))% complete",
                            color: StudyStudioStyle.violet,
                            actionTitle: "Continue"
                        ) {
                            activeCourseForPath = course
                        }
                    }

                    HStack {
                        Text("Explore categories")
                            .font(StudyStudioStyle.heading(17))
                        Spacer()
                    }
                    .foregroundStyle(StudyStudioStyle.ink)

                    destinationCards
                } else {
                    searchResults
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 110)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .background(StudyStudioStyle.canvas.ignoresSafeArea())
        .tint(StudyStudioStyle.violet)
        .navigationDestination(isPresented: $showingCourses) {
            CoursesCatalogListView()
        }
        .navigationDestination(isPresented: $showingAllCommunity) {
            AllCommunityDecksView(
                libraryDecks: libraryDecks,
                initialSearch: discoverSearch,
                onAddDeck: { add($0) },
                onOpenShareModal: { showingShareSheet = true }
            )
        }
        .navigationDestination(isPresented: $showingAllPremade) {
            AllPremadeDecksView(libraryDecks: libraryDecks, onAddDeck: add)
        }
        .navigationDestination(isPresented: $showingExamPrep) {
            ExamPrepHubView(libraryDecks: libraryDecks, onAddDeck: add)
        }
        .navigationDestination(item: $activeCourseForPath) { course in
            CoursePathView(course: course)
        }
        .navigationDestination(item: $searchedCourse) { course in
            CourseOverviewView(course: course)
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareDeckToCommunitySheet(libraryDecks: libraryDecks)
        }
        .alert("Added to Library", isPresented: Binding(get: { addedDeckName != nil }, set: { if !$0 { addedDeckName = nil } })) {
            Button("Done", role: .cancel) { }
        } message: {
            Text("\(addedDeckName ?? "This deck") is now ready to study and editable in your library.")
        }
    }

    private var destinationCards: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ],
            spacing: 12
        ) {
            DiscoverCategoryTile(
                title: "Language courses",
                subtitle: "Spanish & Korean, one lesson at a time.",
                badge: "\(CourseCurriculumCatalog.courses.count) courses",
                symbol: "character.bubble.fill",
                color: StudyStudioStyle.blue,
                action: { showingCourses = true }
            )

            DiscoverCategoryTile(
                title: "Community decks",
                subtitle: "Fresh perspectives & shared decks.",
                badge: "Explore",
                symbol: "person.2.fill",
                color: StudyStudioStyle.teal,
                action: { showingAllCommunity = true }
            )

            DiscoverCategoryTile(
                title: "Curated subjects",
                subtitle: "Math, science, tech & history.",
                badge: "\(PremadeDeckCatalog.decks.count) decks",
                symbol: "books.vertical.fill",
                color: StudyStudioStyle.rose,
                action: { showingAllPremade = true }
            )

            DiscoverCategoryTile(
                title: "Exam & cert prep",
                subtitle: "MCAT, AWS, SAT & study skills.",
                badge: "Prep",
                symbol: "target",
                color: StudyStudioStyle.violet,
                action: { showingExamPrep = true }
            )
        }
    }

    private var searchResults: some View {
        let query = discoverSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        let courses = CourseCurriculumCatalog.courses.filter { $0.title.localizedCaseInsensitiveContains(query) }
        let decks = PremadeDeckCatalog.decks.filter {
            $0.name.localizedCaseInsensitiveContains(query) || $0.category.localizedCaseInsensitiveContains(query)
                || $0.subcategory.localizedCaseInsensitiveContains(query)
        }
        return VStack(alignment: .leading, spacing: 16) {
            Text("Search results").font(StudyStudioStyle.heading()).foregroundStyle(StudyStudioStyle.ink)
            ForEach(courses) { course in
                Button { searchedCourse = course } label: {
                    searchRow(title: course.title, subtitle: "Guided language course", symbol: "character.book.closed", action: "Open")
                }.buttonStyle(.plain)
            }
            ForEach(decks) { deck in
                let added = libraryDecks.contains { $0.name == deck.name }
                Button { add(deck) } label: {
                    searchRow(title: deck.name, subtitle: "\(deck.category) · \(deck.cards.count) cards", symbol: "rectangle.stack", action: added ? "Added" : "Add")
                }.buttonStyle(.plain).disabled(added)
            }
            if courses.isEmpty && decks.isEmpty {
                Text("No matching courses or curated decks. Try the community library below.")
                    .font(StudyStudioStyle.body()).foregroundStyle(StudyStudioStyle.secondary)
            }
            Button { showingAllCommunity = true } label: {
                Label("Search community decks", systemImage: "person.2")
                    .font(StudyStudioStyle.heading(14)).frame(maxWidth: .infinity, minHeight: 52)
                    .foregroundStyle(.white).background(StudyStudioStyle.violet, in: RoundedRectangle(cornerRadius: 16))
            }.buttonStyle(.plain)
        }
    }

    private func searchRow(title: String, subtitle: String, symbol: String, action: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: symbol).font(.system(size: 22)).foregroundStyle(StudyStudioStyle.violet)
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(StudyStudioStyle.heading(15)).foregroundStyle(StudyStudioStyle.ink)
                Text(subtitle).font(StudyStudioStyle.body(12)).foregroundStyle(StudyStudioStyle.secondary)
            }
            Spacer(minLength: 0)
            Text(action).font(StudyStudioStyle.heading(12)).foregroundStyle(StudyStudioStyle.violet)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(StudyStudioStyle.field, in: RoundedRectangle(cornerRadius: 20))
    }

    private func add(_ premadeDeck: PremadeDeck) {
        guard !libraryDecks.contains(where: { premadeDeck.communitySourceID != nil ? $0.sourceCommunityID == premadeDeck.communitySourceID : $0.name == premadeDeck.name }) else { return }
        let deck = Deck(name: premadeDeck.name, colorHex: premadeDeck.colorHex, deckType: premadeDeck.deckType, orderIndex: libraryDecks.count)
        deck.sourceCommunityID = premadeDeck.communitySourceID
        for (index, sourceCard) in premadeDeck.cards.enumerated() {
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
            card.orderIndex = index
            card.promptAudioName = sourceCard.promptAudioName
            deck.cards.append(card)
            deck.assignCardToSection(card: card, suggestedCategory: sourceCard.sectionName)
        }
        context.insert(deck)
        try? context.save()
        InteractionSoundPlayer.shared.play(.addDeck)
        HapticFeedback.success()
        addedDeckName = premadeDeck.name
    }
}

// MARK: - Dedicated Courses Catalog List View

private struct CoursesCatalogListView: View {
    @ObservedObject private var progressManager = CourseProgressManager.shared
    @State private var selectedCourse: CourseDefinition?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Language Courses")
                        .font(.custom("Poppins-Bold", size: 24))
                        .foregroundStyle(LearnAlertStyle.textPrimary)
                    Text("Structured tracks with spaced repetition & lock-screen alerts")
                        .font(.custom("Poppins-Regular", size: 12))
                        .foregroundStyle(LearnAlertStyle.textSecondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                VStack(spacing: 14) {
                    ForEach(CourseCurriculumCatalog.courses) { course in
                        LanguageCourseHeroCard(
                            course: course,
                            isEnrolled: progressManager.isEnrolled(in: course.id),
                            onSelect: { selectedCourse = course }
                        )
                    }
                }
                .padding(.horizontal, 20)

                Spacer().frame(height: 60)
            }
        }
        .background(LearnAlertStyle.courseCanvas.ignoresSafeArea())
        .navigationTitle("Courses")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedCourse) { course in
            CourseOverviewView(course: course)
        }
    }
}

// MARK: - Language Course Hero Card

private struct LanguageCourseHeroCard: View {
    let course: CourseDefinition
    let isEnrolled: Bool
    let onSelect: () -> Void

    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(alignment: .top, spacing: 14) {
                Text(course.flagEmoji)
                    .font(.system(size: 34))
                    .padding(8)
                    .background(Color(hex: course.colorHex).opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(course.title)
                            .font(.custom("Poppins-Bold", size: 15))
                            .foregroundStyle(LearnAlertStyle.textPrimary)

                        Spacer()

                        Text(course.levelTag)
                            .font(.custom("Poppins-SemiBold", size: 10))
                            .foregroundStyle(Color(hex: course.colorHex))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color(hex: course.colorHex).opacity(0.12), in: Capsule())
                    }

                    Text(course.summary)
                        .font(.custom("Poppins-Regular", size: 11))
                        .foregroundStyle(LearnAlertStyle.textSecondary)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        Text("\(course.totalLessonsCount) lessons • ~\(course.estimatedHours) hrs")
                            .font(.custom("Poppins-Medium", size: 10))
                            .foregroundStyle(LearnAlertStyle.textSecondary)

                        Spacer()

                        Text(isEnrolled ? "Continue" : "View Course")
                            .font(.custom("Poppins-SemiBold", size: 11))
                            .foregroundStyle(Color(hex: course.colorHex))
                    }
                    .padding(.top, 4)
                }
            }
            .padding(14)
            .background(LearnAlertStyle.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(LearnAlertStyle.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Dedicated Exam Prep Hub View (Placeholder / High-Yield Prep)

private struct ExamPrepHubView: View {
    let libraryDecks: [Deck]
    let onAddDeck: (PremadeDeck) -> Void

    @State private var searchText = ""
    @State private var selectedFilter = "All"

    private let examFilters = ["All", "Medical", "Tech", "College", "Law"]

    private var examDecks: [PremadeDeck] {
        var results: [PremadeDeck] = []

        // Pull Exam Prep decks from premade catalog
        for deck in PremadeDeckCatalog.decks where deck.category == "Exam Prep" {
            results.append(deck)
        }

        return results
    }

    private var filteredDecks: [PremadeDeck] {
        examDecks.filter { deck in
            let matchesFilter: Bool
            switch selectedFilter {
            case "Medical": matchesFilter = deck.subcategory.caseInsensitiveCompare("Medical") == .orderedSame
            case "Tech": matchesFilter = deck.subcategory.caseInsensitiveCompare("Coding") == .orderedSame || deck.subcategory.caseInsensitiveCompare("Computing") == .orderedSame
            case "College": matchesFilter = deck.subcategory.caseInsensitiveCompare("SAT") == .orderedSame || deck.subcategory.caseInsensitiveCompare("Study Skills") == .orderedSame || deck.subcategory.caseInsensitiveCompare("Exam Prep") == .orderedSame
            case "Law": matchesFilter = deck.subcategory.caseInsensitiveCompare("Law") == .orderedSame
            default: matchesFilter = true
            }

            let matchesSearch = searchText.isEmpty
                || deck.name.localizedCaseInsensitiveContains(searchText)
                || deck.description.localizedCaseInsensitiveContains(searchText)
                || deck.subcategory.localizedCaseInsensitiveContains(searchText)

            return matchesFilter && matchesSearch
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                DiscoverSearchField(searchText: $searchText, placeholder: "Search MCAT, SAT, AWS, USMLE, Law...")
                DiscoverFilterRow(categories: examFilters, selection: $selectedFilter, compact: true)

                if filteredDecks.isEmpty {
                    ContentUnavailableView("No Exam Decks Found", systemImage: "target", description: Text("Try adjusting your filter or search query."))
                        .padding(.vertical, 40)
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredDecks) { deck in
                            CleanDiscoverDeckCard(
                                title: deck.name,
                                subtitle: "\(deck.cards.count) cards • \(deck.subcategory)",
                                colorHex: deck.colorHex,
                                iconName: "graduationcap.fill",
                                isAdded: libraryDecks.contains(where: { $0.name == deck.name }),
                                onAdd: { onAddDeck(deck) }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }

                Spacer().frame(height: 60)
            }
            .padding(.top, 14)
        }
        .background(LearnAlertStyle.courseCanvas.ignoresSafeArea())
        .navigationTitle("Exam & Cert Drills")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Dedicated "See All Premade Decks" View

private struct AllPremadeDecksView: View {
    let libraryDecks: [Deck]
    let onAddDeck: (PremadeDeck) -> Void

    @State private var searchText = ""
    @State private var selectedCategory = "All"
    @State private var selectedSubcategory = "All"

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
            VStack(alignment: .leading, spacing: 14) {
                DiscoverSearchField(searchText: $searchText, placeholder: "Search all curated decks...")
                DiscoverFilterRow(categories: PremadeDeckCatalog.mainCategories, selection: $selectedCategory)

                if !availableSubcategories.isEmpty {
                    DiscoverFilterRow(categories: availableSubcategories, selection: $selectedSubcategory, compact: true)
                }

                if filteredDecks.isEmpty {
                    ContentUnavailableView("No Decks Found", systemImage: "magnifyingglass", description: Text("Try another search or category."))
                        .padding(.vertical, 40)
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredDecks) { deck in
                            CleanDiscoverDeckCard(
                                title: deck.name,
                                subtitle: "\(deck.cards.count) cards • \(deck.subcategory)",
                                colorHex: deck.colorHex,
                                iconName: "book.closed.fill",
                                isAdded: libraryDecks.contains(where: { $0.name == deck.name }),
                                onAdd: { onAddDeck(deck) }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }

                Spacer().frame(height: 60)
            }
            .padding(.top, 14)
        }
        .background(LearnAlertStyle.courseCanvas.ignoresSafeArea())
        .navigationTitle("Curated Subjects")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedCategory) { _, _ in selectedSubcategory = "All" }
    }
}

// MARK: - Clean Discover Deck Card (Title + Small Plus Button)

private struct CleanDiscoverDeckCard: View {
    let title: String
    let subtitle: String
    let colorHex: String
    let iconName: String
    let isAdded: Bool
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(hex: colorHex).opacity(0.18))
                    .frame(width: 38, height: 38)
                Image(systemName: iconName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(hex: colorHex))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.custom("Poppins-SemiBold", size: 14))
                    .foregroundStyle(LearnAlertStyle.textPrimary)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.custom("Poppins-Regular", size: 11))
                    .foregroundStyle(LearnAlertStyle.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Button {
                onAdd()
            } label: {
                Image(systemName: isAdded ? "checkmark" : "plus")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(isAdded ? LearnAlertStyle.textSecondary : Color.white)
                    .frame(width: 28, height: 28)
                    .background(isAdded ? Color.gray.opacity(0.15) : LearnAlertStyle.indigo)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(isAdded)
            .accessibilityLabel(isAdded ? "\(title) already added" : "Add \(title)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(LearnAlertStyle.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(LearnAlertStyle.hairline, lineWidth: 1)
        )
    }
}

// MARK: - Search Field Component

private struct DiscoverSearchField: View {
    @Binding var searchText: String
    var placeholder: String = "Search decks..."

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(LearnAlertStyle.textSecondary)
            TextField(placeholder, text: $searchText)
                .font(.custom("Poppins-Medium", size: 13))
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
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(LearnAlertStyle.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(LearnAlertStyle.hairline, lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }
}

// MARK: - Filter Row Component

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
                            .font(.custom(isSelected ? "Poppins-SemiBold" : "Poppins-Medium", size: compact ? 11 : 12))
                            .padding(.horizontal, compact ? 10 : 14)
                            .padding(.vertical, compact ? 5 : 7)
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
