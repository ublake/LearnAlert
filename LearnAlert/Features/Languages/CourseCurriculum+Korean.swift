//
//  CourseCurriculum+Korean.swift
//  LearnAlert
//
//  Created by Blake Miller on 2/20/26.
//

import Foundation

extension CourseCurriculumCatalog {

    // MARK: - Section 1 Checkpoint Quiz
    public static let koreanCheckpoint1 = CourseCheckpointQuiz(
        id: "kr-cp-1",
        title: "Unit 1: Hangul Mastery Checkpoint",
        summary: "Comprehensive 10-question evaluation of Hangul reading, consonant shapes, batchim linking, and polite greetings.",
        passingScoreThreshold: 0.80,
        questions: [
            CourseLessonCard(
                id: "kr-cp-1-1",
                question: "What sound does the Hangul vowel \"ㅏ\" make?",
                options: ["\"ah\" (as in father)", "\"oh\" (as in boat)", "\"oo\" (as in moon)", "\"ee\" (as in tree)"],
                correctAnswer: "\"ah\" (as in father)",
                hint: "Bright vowel pointing right",
                cardType: "multipleChoice",
                speechText: "ㅏ",
                conceptTag: "Vowel Recognition",
                explanation: "The vowel ㅏ is formed with a vertical line and a short horizontal stroke pointing outward/right, representing the bright sound \"ah\"."
            ),
            CourseLessonCard(
                id: "kr-cp-1-2",
                question: "Which Hangul consonant makes the \"N\" sound, designed after the tongue touching the upper palate?",
                options: ["ㄴ", "ㄱ", "ㄷ", "ㅁ"],
                correctAnswer: "ㄴ",
                hint: "Looks like an \"L\" in English",
                cardType: "multipleChoice",
                speechText: "ㄴ",
                conceptTag: "Consonant Shapes",
                explanation: "The consonant ㄴ (nieun) mimics the physical shape of the tip of the tongue touching behind the upper front teeth."
            ),
            CourseLessonCard(
                id: "kr-cp-1-3",
                question: "What letters combine to make the syllable \"한\" (as in 한국 / Korea)?",
                options: ["ㅎ + ㅏ + ㄴ", "ㄱ + ㅏ + ㄴ", "ㅎ + ㅓ + ㅇ", "ㅎ + ㅗ + ㅁ"],
                correctAnswer: "ㅎ + ㅏ + ㄴ",
                hint: "H + A + N",
                cardType: "multipleChoice",
                speechText: "한",
                conceptTag: "Syllable Construction",
                explanation: "Korean syllables stack neatly: Initial consonant ㅎ (H) + Medial vowel ㅏ (A) + Final batchim consonant ㄴ (N) = 한 (Han)."
            ),
            CourseLessonCard(
                id: "kr-cp-1-4",
                question: "How is \"한국어\" (Korean language) pronounced when spoken naturally?",
                options: ["[한구거] (Han-gu-geo)", "[한국-어] (Han-guk-eo with hard stop)", "[한거어] (Han-geo-eo)", "[한곡어] (Han-gok-eo)"],
                correctAnswer: "[한구거] (Han-gu-geo)",
                hint: "Batchim ㄱ moves to silent ㅇ",
                cardType: "multipleChoice",
                speechText: "한국어",
                conceptTag: "Batchim Linking",
                explanation: "Under Korean consonant liaison (연음), when a batchim consonant is followed by a syllable starting with silent ㅇ, the consonant carries over: 한국어 -> [한구거]."
            ),
            CourseLessonCard(
                id: "kr-cp-1-5",
                question: "What does \"안녕하세요\" literally mean in Korean polite speech?",
                options: ["Are you in peace / wellness?", "I bow to you", "Have you eaten yet?", "Good sun to you"],
                correctAnswer: "Are you in peace / wellness?",
                hint: "안녕 means peace or wellness",
                cardType: "multipleChoice",
                speechText: "안녕하세요",
                conceptTag: "Polite Speech Levels",
                explanation: "안녕하세요 combines 안녕 (peace/good health) with the polite honorific verb ending -하세요, politely inquiring if the listener is at peace."
            ),
            CourseLessonCard(
                id: "kr-cp-1-6",
                question: "Choose the spelling for \"Hangul\":",
                options: ["한글", "한국", "한가", "한길"],
                correctAnswer: "한글",
                hint: "Han + Geul",
                cardType: "multipleChoice",
                speechText: "한글",
                conceptTag: "Syllable Spelling",
                explanation: "한 (Han: ㅎ+ㅏ+ㄴ) + 글 (Geul: ㄱ+ㅡ+ㄹ) spell 한글 (Hangul)."
            ),
            CourseLessonCard(
                id: "kr-cp-1-7",
                question: "When should you say \"안녕히 계세요\" instead of \"안녕히 가세요\"?",
                options: [
                    "When you are leaving and the other person is staying",
                    "When you are staying and the other person is leaving",
                    "Only when speaking to children",
                    "Only when entering a store"
                ],
                correctAnswer: "When you are leaving and the other person is staying",
                hint: "계시다 means to stay",
                cardType: "multipleChoice",
                speechText: "안녕히 계세요",
                conceptTag: "Polite Greetings",
                explanation: "안녕히 계세요 uses the honorific 계시다 (to stay), meaning \"Please stay in peace\". Speak this when you depart and the listener remains."
            ),
            CourseLessonCard(
                id: "kr-cp-1-8",
                question: "What is the English meaning of \"감사합니다\"?",
                options: ["Thank you", "I am sorry", "Excuse me", "Nice to meet you"],
                correctAnswer: "Thank you",
                hint: "Standard formal gratitude",
                cardType: "multipleChoice",
                speechText: "감사합니다",
                conceptTag: "Vocabulary",
                explanation: "감사합니다 (Gamsahamnida) is the formal polite expression for \"Thank you\"."
            ),
            CourseLessonCard(
                id: "kr-cp-1-9",
                question: "Which of the following vowels is flat and pronounced with a wide unrounded smile?",
                options: ["ㅡ (eu)", "ㅗ (oh)", "ㅜ (oo)", "ㅏ (ah)"],
                correctAnswer: "ㅡ (eu)",
                hint: "Flat horizontal line",
                cardType: "multipleChoice",
                speechText: "ㅡ",
                conceptTag: "Vowel Recognition",
                explanation: "ㅡ (eu) is written as a single flat horizontal line, representing earth, and pronounced with a high back tongue position and unrounded lips."
            ),
            CourseLessonCard(
                id: "kr-cp-1-10",
                question: "Match the Korean words with their correct English meanings",
                options: [],
                correctAnswer: "Matches",
                hint: "Unit 1 foundational vocabulary",
                cardType: "matching",
                matchingLeftItems: ["물 (mul)", "사람 (saram)", "나무 (namu)", "모자 (moja)"],
                matchingRightItems: ["Water", "Person / Human", "Tree", "Hat / Cap"],
                conceptTag: "Vocabulary Recall",
                explanation: "물 = Water, 사람 = Person, 나무 = Tree, 모자 = Hat."
            )
        ],
        keyConcepts: [
            "Vowel sounds and orientation",
            "Consonant articulation anatomy",
            "Syllable block stacking",
            "Batchim final consonants & linking rule",
            "Polite speech levels (-요 / -습니다)"
        ]
    )

    // MARK: - Section 2 Checkpoint Quiz
    public static let koreanCheckpoint2 = CourseCheckpointQuiz(
        id: "kr-cp-2",
        title: "Unit 2: Verbs & Particles Checkpoint",
        summary: "Evaluates topic particles (은/는), subject particles (이/가), polite present conjugation (-아요/어요), and existence (있어요/없어요).",
        passingScoreThreshold: 0.80,
        questions: [
            CourseLessonCard(
                id: "kr-cp-2-1",
                question: "Which particle marks the TOPIC or contrast of a sentence?",
                options: ["은 / 는", "이 / 가", "을 / 를", "에 / 에서"],
                correctAnswer: "은 / 는",
                hint: "Topic particle (consonant: 은, vowel: 는)",
                cardType: "multipleChoice",
                speechText: "은, 는",
                conceptTag: "Particles",
                explanation: "은/는 marks the topic or theme of a sentence or provides contrast: 저는 학생이에요 (As for me, I am a student)."
            ),
            CourseLessonCard(
                id: "kr-cp-2-2",
                question: "How do you conjugate \"가다\" (to go) into the polite present tense (-아요/어요)?",
                options: ["가요", "가어요", "가해요", "가세요"],
                correctAnswer: "가요",
                hint: "Stem 가 ends in ㅏ, combines with -아요 -> 가요",
                cardType: "multipleChoice",
                speechText: "가요",
                conceptTag: "Verb Conjugation",
                explanation: "The stem 가 ends in bright vowel ㅏ, so it takes -아요: 가 + 아요 contracts to 가요."
            ),
            CourseLessonCard(
                id: "kr-cp-2-3",
                question: "What does \"물 있어요\" mean in daily conversation?",
                options: ["There is water / I have water / Do you have water?", "Water is cold", "Please give me water", "I drank water"],
                correctAnswer: "There is water / I have water / Do you have water?",
                hint: "있어요 expresses existence or possession",
                cardType: "multipleChoice",
                speechText: "물 있어요",
                conceptTag: "Existence Verbs",
                explanation: "있어요 expresses existence (\"there is\") or possession (\"have\"). With a rising question intonation, it asks \"Is there water?\""
            ),
            CourseLessonCard(
                id: "kr-cp-2-4",
                question: "Which particle is used with \"있어요\" to indicate a static location where something exists?",
                options: ["-에 (e)", "-에서 (eseo)", "-로 (ro)", "-과 (gwa)"],
                correctAnswer: "-에 (e)",
                hint: "집에 있어요 (I am at home)",
                cardType: "multipleChoice",
                speechText: "-에",
                conceptTag: "Location Particles",
                explanation: "-에 marks static location with existence verbs (있다, 없다, 살다). Dynamic action takes -에서."
            ),
            CourseLessonCard(
                id: "kr-cp-2-5",
                question: "How do you count \"three items\" using Native Korean numbers and the general counter \"개\"?",
                options: ["세 개 (se gae)", "삼 개 (sam gae)", "셋 개 (set gae)", "넷 개 (net gae)"],
                correctAnswer: "세 개 (se gae)",
                hint: "하나->한, 둘->두, 셋->세 before counters",
                cardType: "multipleChoice",
                speechText: "세 개",
                conceptTag: "Counters & Numbers",
                explanation: "The native number 셋 (three) modifies to 세 before counters like 개 (items): 세 개 = three items."
            )
        ],
        keyConcepts: [
            "Topic particle 은/는 vs Subject particle 이/가",
            "Present tense -아요/어요 conjugation rules",
            "Existence with 있어요 and 없어요",
            "Static location particle -에 vs action particle -에서",
            "Native Korean numbers and counters"
        ]
    )

    // MARK: - Section 3 Checkpoint Quiz
    public static let koreanCheckpoint3 = CourseCheckpointQuiz(
        id: "kr-cp-3",
        title: "Unit 3: Daily Life & Past Tense Checkpoint",
        summary: "Evaluates object particles (-을/를), past tense (-았/었어요), reason particle (-아서/어서), and time expressions.",
        passingScoreThreshold: 0.80,
        questions: [
            CourseLessonCard(
                id: "kr-cp-3-1",
                question: "Which particle marks the direct object of an action verb?",
                options: ["을 / 를", "은 / 는", "이 / 가", "에 / 에서"],
                correctAnswer: "을 / 를",
                hint: "사과를 먹어요 (I eat an apple)",
                cardType: "multipleChoice",
                speechText: "을, 를",
                conceptTag: "Object Particle",
                explanation: "을 (after consonants) and 를 (after vowels) mark the direct object receiving the verb action."
            ),
            CourseLessonCard(
                id: "kr-cp-3-2",
                question: "What is the past tense polite form of \"먹다\" (to eat)?",
                options: ["먹었어요", "먹았어요", "먹했어요", "먹겠어요"],
                correctAnswer: "먹었어요",
                hint: "Stem vowel is ㅓ (dark vowel), takes -었어요",
                cardType: "multipleChoice",
                speechText: "먹었어요",
                conceptTag: "Past Tense",
                explanation: "먹다 stem has dark vowel ㅓ, so it takes -었어요: 먹었어요 (ate)."
            ),
            CourseLessonCard(
                id: "kr-cp-3-3",
                question: "What does \"바빠서 못 갔어요\" mean?",
                options: [
                    "I was busy, so I could not go",
                    "I went because I was not busy",
                    "I will go even though I am busy",
                    "Please do not go because it is busy"
                ],
                correctAnswer: "I was busy, so I could not go",
                hint: "-아서 means because, 못 means cannot",
                cardType: "multipleChoice",
                speechText: "바빠서 못 갔어요",
                conceptTag: "Reason & Inability",
                explanation: "바빠서 (because I was busy) + 못 갔어요 (could not go) expresses reason and inability."
            ),
            CourseLessonCard(
                id: "kr-cp-3-4",
                question: "Which Korean word means \"Sunday\"?",
                options: ["일요일 (Iryoil)", "월요일 (Woryoil)", "화요일 (Hwayoil)", "토요일 (Toyoil)"],
                correctAnswer: "일요일 (Iryoil)",
                hint: "일 (sun / day)",
                cardType: "multipleChoice",
                speechText: "일요일",
                conceptTag: "Days of Week",
                explanation: "일요일 is Sunday (일 = Sun, 요일 = day of week)."
            )
        ],
        keyConcepts: [
            "Object particles -을/를",
            "Past tense -았/었어요",
            "Expressing cause and reason with -아서/어서",
            "Negation with 안 (will not) vs 못 (cannot)"
        ]
    )

    // MARK: - Section 4 Checkpoint Quiz
    public static let koreanCheckpoint4 = CourseCheckpointQuiz(
        id: "kr-cp-4",
        title: "Unit 4: Intermediate Fluency Checkpoint",
        summary: "Evaluates future intentions (-(으)ㄹ 거예요), ability (-(으)ㄹ 수 있어요), honorific verbs, and sentence contrast (-지만).",
        passingScoreThreshold: 0.80,
        questions: [
            CourseLessonCard(
                id: "kr-cp-4-1",
                question: "How do you express future intention: \"I will study Korean tomorrow\"?",
                options: [
                    "내일 한국어를 공부할 거예요",
                    "내일 한국어를 공부했어요",
                    "내일 한국어를 공부해요",
                    "내일 한국어를 공부하고 싶어요"
                ],
                correctAnswer: "내일 한국어를 공부할 거예요",
                hint: "-(으)ㄹ 거예요 expresses future plan",
                cardType: "multipleChoice",
                speechText: "내일 한국어를 공부할 거예요",
                conceptTag: "Future Tense",
                explanation: "공부하다 takes -ㄹ 거예요 -> 공부할 거예요 (will study)."
            ),
            CourseLessonCard(
                id: "kr-cp-4-2",
                question: "What is the honorific form of the verb \"먹다\" (to eat) used when speaking respectfully of elders?",
                options: ["드시다 (deusida)", "먹으시다 (meogeusida)", "계시다 (gyesida)", "주무시다 (jumusida)"],
                correctAnswer: "드시다 (deusida)",
                hint: "Dedicated honorific verb for eating / drinking",
                cardType: "multipleChoice",
                speechText: "드시다",
                conceptTag: "Honorifics",
                explanation: "드시다 (or 잡수시다) is the dedicated honorific verb for 먹다 (to eat) and 마시다 (to drink)."
            ),
            CourseLessonCard(
                id: "kr-cp-4-3",
                question: "What does \"한국어가 어렵지만 재미있어요\" mean?",
                options: [
                    "Korean is difficult, but it is fun",
                    "Korean is easy and very fun",
                    "Because Korean is difficult, I do not study",
                    "Korean is neither difficult nor fun"
                ],
                correctAnswer: "Korean is difficult, but it is fun",
                hint: "-지만 connects contrasting clauses (\"but\")",
                cardType: "multipleChoice",
                speechText: "한국어가 어렵지만 재미있어요",
                conceptTag: "Conjunctions",
                explanation: "-지만 means \"but / however\": 어렵지만 (difficult, but) + 재미있어요 (is fun)."
            )
        ],
        keyConcepts: [
            "Future intention with -(으)ㄹ 거예요",
            "Ability with -(으)ㄹ 수 있다/없다",
            "Honorific verbs (드시다, 계시다, 주무시다)",
            "Contrasting ideas with -지만"
        ]
    )
}
