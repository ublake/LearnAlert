//
//  CourseCurriculum.swift
//  LearnAlert
//
//  Created by Blake Miller on 2/20/26.
//

import Foundation

public enum CourseCurriculumCatalog {

    // MARK: - Spanish Beginner Course
    public static let spanishCourse = addingVisualVocabulary(to: CourseDefinition(
        id: "spanish-course",
        title: "Spanish Foundations",
        language: "Spanish",
        flagEmoji: "🇪🇸",
        levelTag: "Beginner A1",
        colorHex: "#E05A47",
        summary: "Master natural Spanish pronunciation, polite essentials, core verbs 'ser' vs 'estar', and daily conversational phrases from day one.",
        estimatedHours: 12,
        outcomes: [
            "Pronounce Spanish vowels, consonants, and rolling 'r' accurately",
            "Introduce yourself, greet people warmly, and express polite gratitude",
            "Understand the fundamental difference between 'Ser' and 'Estar'",
            "Ask and answer common daily questions with confidence",
            "Build an active recall memory foundation through timed lock screen alerts"
        ],
        units: [
            CourseUnit(
                id: "es-unit-1",
                unitNumber: 1,
                title: "Unit 1: Pronunciation & First Words",
                subtitle: "Vowels, greetings, core polite expressions, and everyday introductions.",
                colorHex: "#E05A47",
                badgeIcon: "sparkles",
                lessons: [
                    CourseLesson(
                        id: "es-1-1",
                        lessonNumber: 1,
                        title: "Vowel Sounds & Pure Phonetics",
                        subtitle: "Spanish vowels are clean and consistent: A, E, I, O, U.",
                        nodeType: .lesson,
                        estimatedMinutes: 5,
                        tipNote: "Unlike English vowels which often glide, Spanish vowels are always short, crisp, and pure. 'H' is always silent!",
                        cards: [
                            CourseLessonCard(
                                id: "es-1-1-1",
                                question: "How is the letter 'H' pronounced in Spanish words like 'Hola' or 'Hablo'?",
                                options: ["It is completely silent", "Like an English 'H'", "Like a hard 'K'", "Like a soft 'W'"],
                                correctAnswer: "It is completely silent",
                                hint: "Think of 'Hola' sounding like 'Oh-la'",
                                cardType: "multipleChoice"
                            ),
                            CourseLessonCard(
                                id: "es-1-1-2",
                                question: "Spanish vowel 'I' sounds like the 'ee' in English 'see'.",
                                options: [],
                                correctAnswer: "True. 'I' is pronounced like 'ee' in beet/see (e.g., 'sí', 'amigo').",
                                hint: "Pure vowel sound",
                                cardType: "tapReveal"
                            ),
                            CourseLessonCard(
                                id: "es-1-1-3",
                                question: "Match Spanish vowel sounds to English phonetic equivalents",
                                options: [],
                                correctAnswer: "Matches",
                                hint: "Crisp vowel pairs",
                                cardType: "matching",
                                matchingLeftItems: ["A (as in casa)", "E (as in mesa)", "O (as in solo)", "U (as in uno)"],
                                matchingRightItems: ["'ah' like father", "'eh' like pet", "'oh' like boat", "'oo' like moon"]
                            ),
                            CourseLessonCard(
                                id: "es-1-1-4",
                                question: "In Spanish, the letter 'J' (like in 'jamón' or 'rojo') makes a ___ sound.",
                                options: [],
                                correctAnswer: "raspy 'H' (similar to Scottish 'loch' or English 'h')",
                                hint: "A guttural breathy H",
                                cardType: "fillBlank"
                            ),
                            CourseLessonCard(
                                id: "es-1-1-5",
                                question: "¿Cómo se pronuncia 'Gracias'?",
                                options: ["GRAH-see-ahs (or GRAH-thee-ahs in Spain)", "GRAY-see-as", "GRAH-ky-as", "GRASS-ee-ahs"],
                                correctAnswer: "GRAH-see-ahs (or GRAH-thee-ahs in Spain)",
                                hint: "Soft 'c' before 'i'",
                                cardType: "multipleChoice"
                            )
                        ]
                    ),
                    CourseLesson(
                        id: "es-1-2",
                        lessonNumber: 2,
                        title: "Essential Polite Greetings",
                        subtitle: "Morning to evening greetings, 'please', and 'thank you'.",
                        nodeType: .lesson,
                        estimatedMinutes: 6,
                        tipNote: "Use 'Buenos días' until noon, 'Buenas tardes' from afternoon until sunset, and 'Buenas noches' at night.",
                        cards: [
                            CourseLessonCard(
                                id: "es-1-2-1",
                                question: "¿Cómo se dice 'Hello' en español?",
                                options: ["Hola", "Adiós", "Gracias", "Por favor"],
                                correctAnswer: "Hola",
                                hint: "Universal Spanish greeting",
                                cardType: "multipleChoice"
                            ),
                            CourseLessonCard(
                                id: "es-1-2-2",
                                question: "'Thank you very much' in Spanish is 'Muchas ___'.",
                                options: [],
                                correctAnswer: "gracias",
                                hint: "Muchas ...",
                                cardType: "fillBlank"
                            ),
                            CourseLessonCard(
                                id: "es-1-2-3",
                                question: "Por favor",
                                options: [],
                                correctAnswer: "Please",
                                hint: "Polite request",
                                cardType: "vocabulary"
                            ),
                            CourseLessonCard(
                                id: "es-1-2-4",
                                question: "Match Spanish times-of-day greetings",
                                options: [],
                                correctAnswer: "Matches",
                                hint: "Connect daily greetings",
                                cardType: "matching",
                                matchingLeftItems: ["Buenos días", "Buenas tardes", "Buenas noches", "Hasta luego"],
                                matchingRightItems: ["Good morning", "Good afternoon", "Good night / evening", "See you later"]
                            ),
                            CourseLessonCard(
                                id: "es-1-2-5",
                                question: "What is the polite way to say 'You're welcome' in Spanish?",
                                options: ["De nada", "Mucho gusto", "Lo siento", "Disculpe"],
                                correctAnswer: "De nada",
                                hint: "Literally 'of nothing'",
                                cardType: "multipleChoice"
                            )
                        ]
                    ),
                    CourseLesson(
                        id: "es-1-3",
                        lessonNumber: 3,
                        title: "Core Verbs: 'Ser' vs 'Estar'",
                        subtitle: "The two verbs for 'to be': permanent identity vs temporary states.",
                        nodeType: .lesson,
                        estimatedMinutes: 6,
                        tipNote: "Remember the acronym PLACE for Estar: Position, Location, Action, Condition, Emotion. Use Ser for identity, origin, and characteristics (DOCTOR).",
                        cards: [
                            CourseLessonCard(
                                id: "es-1-3-1",
                                question: "Which verb is used for permanent characteristics, profession, and origin?",
                                options: ["Ser", "Estar", "Hacer", "Tener"],
                                correctAnswer: "Ser",
                                hint: "Yo soy estudiante, Ella es doctora",
                                cardType: "multipleChoice"
                            ),
                            CourseLessonCard(
                                id: "es-1-3-2",
                                question: "Yo ___ cansado (I am tired - temporary physical condition).",
                                options: [],
                                correctAnswer: "estoy",
                                hint: "Form of 'estar' for 'yo'",
                                cardType: "fillBlank"
                            ),
                            CourseLessonCard(
                                id: "es-1-3-3",
                                question: "Match subject pronouns with the present tense of 'Ser'",
                                options: [],
                                correctAnswer: "Matches",
                                hint: "Conjugations of Ser",
                                cardType: "matching",
                                matchingLeftItems: ["Yo", "Tú", "Él / Ella", "Nosotros"],
                                matchingRightItems: ["soy (I am)", "eres (you are)", "es (he/she is)", "somos (we are)"]
                            ),
                            CourseLessonCard(
                                id: "es-1-3-4",
                                question: "Why do we say 'Madrid está en España' instead of 'es en España'?",
                                options: [],
                                correctAnswer: "Because 'Estar' is always used for geographical location (Position & Location in PLACE).",
                                hint: "Location rule",
                                cardType: "tapReveal"
                            ),
                            CourseLessonCard(
                                id: "es-1-3-5",
                                question: "¿Cómo se dice 'Where are you from?' en español?",
                                options: ["¿De dónde eres?", "¿Cómo estás?", "¿Qué hora es?", "¿Dónde vives?"],
                                correctAnswer: "¿De dónde eres?",
                                hint: "Asking origin with 'ser'",
                                cardType: "multipleChoice"
                            )
                        ]
                    ),
                    CourseLesson(
                        id: "es-1-4",
                        lessonNumber: 4,
                        title: "Introductions & Everyday Questions",
                        subtitle: "Ask names, introduce friends, and state where you live.",
                        nodeType: .lesson,
                        estimatedMinutes: 6,
                        tipNote: "'Mucho gusto' means 'Nice to meet you'. You can also reply with 'Igualmente' (Likewise / Same to you).",
                        cards: [
                            CourseLessonCard(
                                id: "es-1-4-1",
                                question: "¿Cómo te llamas? translates to:",
                                options: ["What is your name?", "How are you?", "Where do you work?", "How old are you?"],
                                correctAnswer: "What is your name?",
                                hint: "Literally 'How do you call yourself?'",
                                cardType: "multipleChoice"
                            ),
                            CourseLessonCard(
                                id: "es-1-4-2",
                                question: "My name is Carlos = 'Me ___ Carlos'.",
                                options: [],
                                correctAnswer: "llamo",
                                hint: "Me llamo ...",
                                cardType: "fillBlank"
                            ),
                            CourseLessonCard(
                                id: "es-1-4-3",
                                question: "Mucho gusto",
                                options: [],
                                correctAnswer: "Nice to meet you / Pleasure to meet you",
                                hint: "Introduction phrase",
                                cardType: "vocabulary"
                            ),
                            CourseLessonCard(
                                id: "es-1-4-4",
                                question: "Match questions with their natural answers",
                                options: [],
                                correctAnswer: "Matches",
                                hint: "Match conversational replies",
                                cardType: "matching",
                                matchingLeftItems: ["¿Cómo estás?", "¿De dónde eres?", "¿Hablas inglés?", "¿Mucho gusto!"],
                                matchingRightItems: ["Muy bien, gracias", "Soy de México", "Sí, un poco", "¡Igualmente! (Likewise)"]
                            ),
                            CourseLessonCard(
                                id: "es-1-4-5",
                                question: "How do you politely ask for someone's attention in a store or restaurant?",
                                options: ["¡Disculpe! / ¡Perdón!", "¡Adiós!", "¡Mucho gusto!", "¡De nada!"],
                                correctAnswer: "¡Disculpe! / ¡Perdón!",
                                hint: "Excuse me / Pardon me",
                                cardType: "multipleChoice"
                            )
                        ]
                    ),
                    CourseLesson(
                        id: "es-1-5",
                        lessonNumber: 5,
                        title: "Unit 1 Mastery Checkpoint",
                        subtitle: "Comprehensive review quiz covering pronunciation, greetings, and verbs.",
                        nodeType: .checkpoint,
                        estimatedMinutes: 7,
                        tipNote: "Complete this milestone quiz to solidify your Spanish foundations and unlock Unit 2!",
                        cards: [
                            CourseLessonCard(
                                id: "es-1-5-1",
                                question: "¿Qué significa 'Hasta mañana'?",
                                options: ["See you tomorrow", "See you later", "Good morning", "Have a safe trip"],
                                correctAnswer: "See you tomorrow",
                                hint: "Mañana = tomorrow",
                                cardType: "multipleChoice"
                            ),
                            CourseLessonCard(
                                id: "es-1-5-2",
                                question: "Nosotros ___ en la biblioteca (We are in the library - location).",
                                options: [],
                                correctAnswer: "estamos",
                                hint: "Conjugation of estar for nosotros",
                                cardType: "fillBlank"
                            ),
                            CourseLessonCard(
                                id: "es-1-5-3",
                                question: "Match Spanish vocabulary from Unit 1",
                                options: [],
                                correctAnswer: "Matches",
                                hint: "Unit 1 essentials",
                                cardType: "matching",
                                matchingLeftItems: ["Por favor", "Gracias", "Lo siento", "Disculpe"],
                                matchingRightItems: ["Please", "Thank you", "I'm sorry", "Excuse me"]
                            ),
                            CourseLessonCard(
                                id: "es-1-5-4",
                                question: "Which sentence is grammatically correct for stating your nationality?",
                                options: ["Yo soy estadounidense / español", "Yo estoy estadounidense", "Yo tengo estadounidense", "Yo hago estadounidense"],
                                correctAnswer: "Yo soy estadounidense / español",
                                hint: "Origin and nationality use Ser",
                                cardType: "multipleChoice"
                            ),
                            CourseLessonCard(
                                id: "es-1-5-5",
                                question: "What is the customary reply when someone says 'Mucho gusto' (Nice to meet you)?",
                                options: [],
                                correctAnswer: "¡Igualmente! (Likewise / The pleasure is mine)",
                                hint: "Friendly reciprocal response",
                                cardType: "tapReveal"
                            )
                        ]
                    )
                ]
            )
        ]
    ))

    // MARK: - Korean Beginner Course
    public static let koreanCourse = addingVisualVocabulary(to: CourseDefinition(
        id: "korean-course",
        title: "Korean",
        language: "Korean",
        flagEmoji: "🇰🇷",
        levelTag: "Foundations → Advanced Grammar",
        colorHex: "#3E74C4",
        summary: "Build from Hangul to conversations, reported speech, formal writing, and advanced grammar, with section checkpoints and spaced review.",
        estimatedHours: 60,
        outcomes: [
            "Read and pronounce all basic Hangul vowels (ㅏ, ㅓ, ㅗ, ㅜ, ㅡ, ㅣ)",
            "Master the foundational Korean consonants (ㄱ, ㄴ, ㄷ, ㄹ, ㅁ, ㅂ, ㅅ, ㅇ, ㅈ, ㅎ)",
            "Combine letters into 2-letter and 3-letter syllable blocks with batchim (final consonants)",
            "Greet people politely (안녕하세요, 감사합니다, 죄송합니다) with correct respectful intonation",
            "Effortlessly recognize Hangul characters via lock screen flashcard notifications"
        ],
        units: [
            CourseUnit(
                id: "kr-unit-1",
                unitNumber: 1,
                title: "Unit 1: Hangul Foundations & Polite Speech",
                subtitle: "Vowels, consonants, syllable blocks, and everyday polite phrases.",
                colorHex: "#3E74C4",
                badgeIcon: "character.book.closed.fill",
                lessons: [
                    CourseLesson(
                        id: "kr-1-1",
                        lessonNumber: 1,
                        title: "Hangul Core Vowels (모음)",
                        subtitle: "The 6 core building block vowels: ㅏ, ㅓ, ㅗ, ㅜ, ㅡ, ㅣ.",
                        nodeType: .lesson,
                        estimatedMinutes: 5,
                        tipNote: "Hangul was created by King Sejong the Great in 1443 to be so logical that a wise person could learn it in a morning! Vowels with a vertical line (ㅏ, ㅓ, ㅣ) are placed to the right of the consonant; horizontal vowels (ㅗ, ㅜ, ㅡ) are placed below.",
                        cards: [
                            CourseLessonCard(
                                id: "kr-1-1-1",
                                question: "What sound does the Hangul vowel 'ㅏ' make?",
                                options: ["'ah' (as in father)", "'oh' (as in boat)", "'oo' (as in moon)", "'ee' (as in tree)"],
                                correctAnswer: "'ah' (as in father)",
                                hint: "Sticks pointing outward/right = bright vowel 'ah'",
                                cardType: "multipleChoice"
                            ),
                            CourseLessonCard(
                                id: "kr-1-1-2",
                                question: "The Hangul vowel 'ㅣ' is pronounced like the 'ee' in English 'see'.",
                                options: [],
                                correctAnswer: "True. 'ㅣ' is a single vertical line sounding like 'ee'.",
                                hint: "Single vertical bar",
                                cardType: "tapReveal"
                            ),
                            CourseLessonCard(
                                id: "kr-1-1-3",
                                question: "Match Hangul basic vowels to pronunciation",
                                options: [],
                                correctAnswer: "Matches",
                                hint: "Connect Hangul vowels",
                                cardType: "matching",
                                matchingLeftItems: ["ㅏ", "ㅓ", "ㅗ", "ㅜ"],
                                matchingRightItems: ["'ah' (father)", "'eo' (short 'uh')", "'oh' (round lips)", "'oo' (boot)"]
                            ),
                            CourseLessonCard(
                                id: "kr-1-1-4",
                                question: "When a vowel stands alone as a syllable (e.g., '아' or '오'), the silent placeholder consonant is ___.",
                                options: [],
                                correctAnswer: "ㅇ",
                                hint: "The circular consonant",
                                cardType: "fillBlank"
                            ),
                            CourseLessonCard(
                                id: "kr-1-1-5",
                                question: "What does the word '아이' (아 + 이) mean in Korean?",
                                options: ["Child / Kid", "Ice", "Sun", "Water"],
                                correctAnswer: "Child / Kid",
                                hint: "Pronounced 'Ah-ee'",
                                cardType: "multipleChoice"
                            )
                        ]
                    ),
                    CourseLesson(
                        id: "kr-1-2",
                        lessonNumber: 2,
                        title: "Hangul Basic Consonants (자음)",
                        subtitle: "Learn the shape of speech: ㄱ, ㄴ, ㄷ, ㄹ, ㅁ, ㅂ, ㅅ, ㅇ, ㅈ, ㅎ.",
                        nodeType: .lesson,
                        estimatedMinutes: 6,
                        tipNote: "Hangul consonants are designed after the anatomical shape of the mouth, tongue, and throat making the sound! E.g. ㄱ looks like the tongue touching the soft palate.",
                        cards: [
                            CourseLessonCard(
                                id: "kr-1-2-1",
                                question: "Which Hangul consonant makes the 'N' sound (shaped like the tongue touching the roof of the mouth)?",
                                options: ["ㄴ", "ㄱ", "ㄷ", "ㅁ"],
                                correctAnswer: "ㄴ",
                                hint: "Looks like an 'L' in English, but represents 'N'",
                                cardType: "multipleChoice"
                            ),
                            CourseLessonCard(
                                id: "kr-1-2-2",
                                question: "The box-shaped consonant 'ㅁ' makes the ___ sound.",
                                options: [],
                                correctAnswer: "M",
                                hint: "Mouth closed shape",
                                cardType: "fillBlank"
                            ),
                            CourseLessonCard(
                                id: "kr-1-2-3",
                                question: "Match Hangul consonants with their sounds",
                                options: [],
                                correctAnswer: "Matches",
                                hint: "Connect consonants",
                                cardType: "matching",
                                matchingLeftItems: ["ㄱ", "ㄷ", "ㅂ", "ㅅ"],
                                matchingRightItems: ["G / K", "D / T", "B / P", "S"]
                            ),
                            CourseLessonCard(
                                id: "kr-1-2-4",
                                question: "How is the circle consonant 'ㅇ' pronounced at the BEGINNING vs END of a syllable?",
                                options: [],
                                correctAnswer: "At the beginning (initial): completely silent placeholder (아 = 'ah'). At the end (batchim): makes the 'NG' sound (앙 = 'ang').",
                                hint: "Silent initially, 'ng' as batchim",
                                cardType: "tapReveal"
                            ),
                            CourseLessonCard(
                                id: "kr-1-2-5",
                                question: "Read this word: '나무' (ㄴ + ㅏ + ㅁ + ㅜ)",
                                options: ["Tree / Wood ('Na-mu')", "Mother ('Eo-ma')", "Water ('Mul')", "Friend ('Chin-gu')"],
                                correctAnswer: "Tree / Wood ('Na-mu')",
                                hint: "Na + Mu",
                                cardType: "multipleChoice"
                            )
                        ]
                    ),
                    CourseLesson(
                        id: "kr-1-3",
                        lessonNumber: 3,
                        title: "Syllable Blocks & Batchim Basics",
                        subtitle: "Stacking letters into syllabic squares (Initial + Medial + Final).",
                        nodeType: .lesson,
                        estimatedMinutes: 6,
                        tipNote: "Every Korean word is written in neat square syllable blocks. A block always has an Initial consonant + a Vowel + optional Bottom consonant (Batchim 받침). E.g. ㅎ + ㅏ + ㄴ = 한 (Han).",
                        cards: [
                            CourseLessonCard(
                                id: "kr-1-3-1",
                                question: "What three letters combine to make the syllable '한' (as in 한국 / Korea)?",
                                options: ["ㅎ + ㅏ + ㄴ", "ㄱ + ㅏ + ㄴ", "ㅎ + ㅓ + ㅇ", "ㅎ + ㅗ + ㅁ"],
                                correctAnswer: "ㅎ + ㅏ + ㄴ",
                                hint: "H + A + N",
                                cardType: "multipleChoice"
                            ),
                            CourseLessonCard(
                                id: "kr-1-3-2",
                                question: "What is a bottom/final consonant called in Korean?",
                                options: [],
                                correctAnswer: "받침",
                                hint: "Literally 'support' or 'prop'",
                                cardType: "fillBlank"
                            ),
                            CourseLessonCard(
                                id: "kr-1-3-3",
                                question: "Match syllable blocks with their English readings",
                                options: [],
                                correctAnswer: "Matches",
                                hint: "Connect blocks",
                                cardType: "matching",
                                matchingLeftItems: ["한 (ㅎ+ㅏ+ㄴ)", "글 (ㄱ+ㅡ+ㄹ)", "안 (ㅇ+ㅏ+ㄴ)", "녕 (ㄴ+ㅕ+ㅇ)"],
                                matchingRightItems: ["Han", "Geul (Hangul)", "An (Annyeong)", "Nyeong"]
                            ),
                            CourseLessonCard(
                                id: "kr-1-3-4",
                                question: "How do you read '한국어' (Han-guk-eo)?",
                                options: [],
                                correctAnswer: "The Korean Language ('Han-guk-eo' - pronounced smoothly as 'Han-gu-geo' due to consonant linking).",
                                hint: "Hanguk = Korea, eo = language",
                                cardType: "tapReveal"
                            ),
                            CourseLessonCard(
                                id: "kr-1-3-5",
                                question: "Read this word: '물' (ㅁ + ㅜ + ㄹ)",
                                options: ["Water ('Mul')", "Door ('Mun')", "Fire ('Bul')", "Mountain ('San')"],
                                correctAnswer: "Water ('Mul')",
                                hint: "M + U + L",
                                cardType: "multipleChoice"
                            )
                        ]
                    ),
                    CourseLesson(
                        id: "kr-1-4",
                        lessonNumber: 4,
                        title: "Essential Polite Korean Greetings",
                        subtitle: "Polite speech levels, bowing, introductions, and everyday respect.",
                        nodeType: .lesson,
                        estimatedMinutes: 6,
                        tipNote: "Korean has polite endings like -요 (-yo) and formal endings like -습니다 (-seumnida). Always use polite or formal speech with people you don't know well or who are older!",
                        cards: [
                            CourseLessonCard(
                                id: "kr-1-4-1",
                                question: "How do you say 'Hello' politely in Korean?",
                                options: ["안녕하세요 (Annyeonghaseyo)", "감사합니다 (Gamsahamnida)", "죄송합니다 (Joesonghamnida)", "잘 가요 (Jalgayo)"],
                                correctAnswer: "안녕하세요 (Annyeonghaseyo)",
                                hint: "Standard respectful greeting",
                                cardType: "multipleChoice"
                            ),
                            CourseLessonCard(
                                id: "kr-1-4-2",
                                question: "'Thank you' in polite Korean is '___'.",
                                options: [],
                                correctAnswer: "감사합니다",
                                hint: "Gamsahamnida",
                                cardType: "fillBlank"
                            ),
                            CourseLessonCard(
                                id: "kr-1-4-3",
                                question: "죄송합니다 (Joesonghamnida)",
                                options: [],
                                correctAnswer: "I am sorry / Excuse me (polite & formal)",
                                hint: "Polite apology",
                                cardType: "vocabulary"
                            ),
                            CourseLessonCard(
                                id: "kr-1-4-4",
                                question: "Match Korean greetings with English meanings",
                                options: [],
                                correctAnswer: "Matches",
                                hint: "Connect phrases",
                                cardType: "matching",
                                matchingLeftItems: ["안녕하세요", "안녕히 가세요", "안녕히 계세요", "만나서 반갑습니다"],
                                matchingRightItems: ["Hello", "Goodbye (to person leaving)", "Goodbye (to person staying)", "Nice to meet you"]
                            ),
                            CourseLessonCard(
                                id: "kr-1-4-5",
                                question: "Why is '안녕히 가세요' said to someone leaving rather than someone staying?",
                                options: [],
                                correctAnswer: "Because '가세요' comes from the verb '가다' (to go), literally wishing them 'Go in peace'. '계세요' comes from '계시다' (honorific to stay).",
                                hint: "Gada = to go",
                                cardType: "tapReveal"
                            )
                        ]
                    ),
                    CourseLesson(
                        id: "kr-1-5",
                        lessonNumber: 5,
                        title: "Unit 1 Hangul Mastery Checkpoint",
                        subtitle: "Comprehensive review quiz testing Hangul reading, syllables, and greetings.",
                        nodeType: .practice,
                        estimatedMinutes: 7,
                        tipNote: "Practice the foundations before taking the section checkpoint.",
                        cards: [
                            CourseLessonCard(
                                id: "kr-1-5-1",
                                question: "What does '안녕하세요' mean?",
                                options: ["Hello / Good day (literally: Are you in peace?)", "Thank you very much", "I'm sorry", "Nice to meet you"],
                                correctAnswer: "Hello / Good day (literally: Are you in peace?)",
                                hint: "Polite greeting",
                                cardType: "multipleChoice"
                            ),
                            CourseLessonCard(
                                id: "kr-1-5-2",
                                question: "Spell 'Hangul' in Korean: ___",
                                options: [],
                                correctAnswer: "한글",
                                hint: "Han + Geul",
                                cardType: "fillBlank"
                            ),
                            CourseLessonCard(
                                id: "kr-1-5-3",
                                question: "Match Korean words with their meanings",
                                options: [],
                                correctAnswer: "Matches",
                                hint: "Unit 1 vocabulary",
                                cardType: "matching",
                                matchingLeftItems: ["물 (mul)", "나무 (namu)", "아이 (ai)", "사람 (saram)"],
                                matchingRightItems: ["Water", "Tree", "Child", "Person / Human"]
                            ),
                            CourseLessonCard(
                                id: "kr-1-5-4",
                                question: "Which vowel is written as a horizontal line and pronounced 'eu' with unrounded lips?",
                                options: ["ㅡ", "ㅣ", "ㅗ", "ㅓ"],
                                correctAnswer: "ㅡ",
                                hint: "Flat horizontal line",
                                cardType: "multipleChoice"
                            ),
                            CourseLessonCard(
                                id: "kr-1-5-5",
                                question: "What is the polite phrase for 'Nice to meet you' in Korean?",
                                options: [],
                                correctAnswer: "만나서 반갑습니다 (Mannaseo bangapseumnida)",
                                hint: "Meeting someone",
                                cardType: "tapReveal"
                            )
                        ]
                    )
                ],
                checkpointQuiz: koreanCheckpoint1
            )
        ] + expandedKoreanUnits
    ))

    // MARK: - All Active Courses
    public static let courses: [CourseDefinition] = [
        spanishCourse,
        koreanCourse
    ]

    public static func course(for id: String) -> CourseDefinition? {
        courses.first(where: { $0.id == id })
    }

    // MARK: - Coming Soon Languages
    public struct ComingSoonLanguage: Identifiable {
        public let id: String
        public let name: String
        public let flag: String
        public let tagline: String
        public let levelInfo: String
        public let colorHex: String
    }

    public static let comingSoonLanguages: [ComingSoonLanguage] = [
        ComingSoonLanguage(
            id: "japanese",
            name: "Japanese",
            flag: "🇯🇵",
            tagline: "Hiragana, Katakana & Survival Tokyo Japanese",
            levelInfo: "JLPT N5 Pathway",
            colorHex: "#D64545"
        ),
        ComingSoonLanguage(
            id: "french",
            name: "French",
            flag: "🇫🇷",
            tagline: "Pronunciation, Parisian Manners & Daily Essentials",
            levelInfo: "CEFR A1 Pathway",
            colorHex: "#3566AF"
        ),
        ComingSoonLanguage(
            id: "mandarin",
            name: "Mandarin Chinese",
            flag: "🇨🇳",
            tagline: "Pinyin Tones & Foundational Hanzi Characters",
            levelInfo: "HSK 1-2 Pathway",
            colorHex: "#C93B2B"
        ),
        ComingSoonLanguage(
            id: "german",
            name: "German",
            flag: "🇩🇪",
            tagline: "Phonetics, Compound Nouns & Conversational Fluency",
            levelInfo: "CEFR A1-A2 Pathway",
            colorHex: "#D19B26"
        ),
        ComingSoonLanguage(
            id: "italian",
            name: "Italian",
            flag: "🇮🇹",
            tagline: "Melodic Pronunciation, Food & Travel Italian",
            levelInfo: "CEFR A1 Pathway",
            colorHex: "#2E8B57"
        ),
        ComingSoonLanguage(
            id: "portuguese",
            name: "Portuguese",
            flag: "🇧🇷",
            tagline: "Brazilian Rhythm, Everyday Verbs & Warm Greetings",
            levelInfo: "CEFR A1 Pathway",
            colorHex: "#2E7D32"
        )
    ]
}
