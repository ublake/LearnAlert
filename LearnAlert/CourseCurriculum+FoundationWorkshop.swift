import Foundation

extension CourseCurriculumCatalog {
    /// Only the first Korean unit uses the new workshop. Later units retain their authored content.
    static func foundationWorkshop(_ course: CourseDefinition) -> CourseDefinition {
        guard course.language == "Korean", let first = course.units.first else { return course }
        let unit = CourseUnit(id: first.id, unitNumber: 1, title: first.title,
            subtitle: "Hear it, trace it, build it, and use it.", colorHex: first.colorHex,
            badgeIcon: "character.book.closed.fill", lessons: foundationLessons,
            checkpointQuiz: foundationCheckpoint)
        return CourseDefinition(id: course.id, title: course.title, language: course.language,
            flagEmoji: course.flagEmoji, levelTag: course.levelTag, colorHex: course.colorHex,
            summary: course.summary, estimatedHours: course.estimatedHours, outcomes: course.outcomes,
            units: [unit] + course.units.dropFirst(), guides: course.guides, guidePresentation: course.guidePresentation, learning: course.learning)
    }

    private static var foundationLessons: [CourseLesson] {
        let vowelHints = ["ㅏ": "a · ah", "ㅓ": "eo", "ㅗ": "o · oh", "ㅜ": "u · oo", "ㅡ": "eu", "ㅣ": "i · ee"]
        let blockHints = ["아": "a · ah", "어": "eo", "오": "o · oh", "우": "u · oo", "으": "eu", "이": "i · ee"]
        var one = FoundationLesson(number: 1, title: "Six vowel sounds", subtitle: "One vowel at a time: listen, draw, and recognize.")
        one.teach("Vowels live inside blocks", "Hangul letters share a syllable block. Initial ㅇ is silent. A vertical vowel goes on the right; a horizontal vowel goes below.", "ㅇ + ㅏ = 아 · ㅇ + ㅗ = 오", speech: "아")
        for (key, symbol, block, rule) in [
            ("a", "ㅏ", "아", "ㅏ sounds like ah. The short line points right."),
            ("eo", "ㅓ", "어", "ㅓ is eo, one Korean vowel. Its short line points left. Compare the recording with ㅏ."),
            ("o", "ㅗ", "오", "ㅗ is o. Its short line points up."),
            ("u", "ㅜ", "우", "ㅜ is u, roughly oo. Its short line points down."),
            ("eu", "ㅡ", "으", "ㅡ is eu, one vowel. Keep your lips unrounded; use the recording as your model."),
            ("i", "ㅣ", "이", "ㅣ is i, roughly ee. Draw one line from top to bottom.")
        ] {
            let options = ["ㅏ", "ㅓ", "ㅗ", "ㅜ"].contains(symbol) ? ["ㅏ", "ㅓ", "ㅗ", "ㅜ"] : ["ㅡ", "ㅣ", "ㅗ", "ㅜ"]
            one.letter(key: "vowel-" + key, symbol: symbol, block: block, rule: rule,
                options: options, hints: vowelHints, blockHints: blockHints, cue: vowelHints[symbol] ?? "")
        }

        let consonantHints = ["ㄱ": "g / k", "ㄴ": "n", "ㄷ": "d / t", "ㄹ": "r / l", "ㅁ": "m", "ㅂ": "b / p", "ㅅ": "s", "ㅇ": "silent initially · ng finally", "ㅈ": "j", "ㅎ": "h"]
        var two = FoundationLesson(number: 2, title: "Meet the consonants", subtitle: "Stay with a consonant until its practice is complete.")
        two.teach("A consonant gives a block its start", "Combine the consonant and vowel inside one block. The recording models the letter; its sound can change with its position in a word.", "ㄱ + ㅏ = 가 · ㄴ + ㅏ = 나", speech: "ㄱ")
        for (key, symbol, block, rule) in [
            ("g", "ㄱ", "가", "ㄱ is a plain Korean consonant often written g or k. Follow the corner in one continuous stroke."),
            ("n", "ㄴ", "나", "ㄴ is n. Draw down, then across in one continuous stroke."),
            ("m", "ㅁ", "마", "ㅁ is m. Its strokes make a closed square."),
            ("ng", "ㅇ", "아", "ㅇ is silent at the start of a block. At the bottom it sounds ng, as in the recording. Position changes its job."),
            ("d", "ㄷ", "다", "ㄷ is a plain Korean consonant often written d or t. It has a top bar and a corner underneath."),
            ("r", "ㄹ", "라", "ㄹ is often written r or l. Listen to it, then practice its stepped shape."),
            ("b", "ㅂ", "바", "ㅂ is often written b or p. Compare its two upright strokes with ㅁ."),
            ("s", "ㅅ", "사", "ㅅ is s. Its two strokes branch down to the left and right."),
            ("j", "ㅈ", "자", "ㅈ is j. Compare its top bar with the simpler shape ㅅ."),
            ("h", "ㅎ", "하", "ㅎ is h. Two short bars sit above a loop.")
        ] {
            let options = [symbol] + ["ㄱ", "ㄴ", "ㅁ", "ㅇ", "ㄷ", "ㄹ", "ㅂ", "ㅅ", "ㅈ", "ㅎ"].filter { $0 != symbol }.prefix(3)
            two.letter(key: "consonant-" + key, symbol: symbol, block: block, rule: rule,
                options: options, hints: consonantHints, blockHints: [:], cue: consonantHints[symbol] ?? "")
        }

        var three = FoundationLesson(number: 3, title: "Syllable workshop", subtitle: "Place letters beside, below, and at the bottom.")
        three.teach("Build beside", "Vertical vowels such as ㅏ, ㅓ, and ㅣ go to the right of the first consonant.", "ㄴ + ㅏ = 나", speech: "나")
        three.build("나", pieces: ["ㄴ", "ㅏ"], layout: .beside, tokens: ["ㄴ", "ㅏ", "ㅗ", "ㅁ"], rule: "Place ㄴ on the left and ㅏ on the right.")
        three.build("마", pieces: ["ㅁ", "ㅏ"], layout: .beside, tokens: ["ㅏ", "ㄴ", "ㅁ", "ㅜ"], rule: "Put the consonant left and the vertical vowel right.")
        three.teach("Build below", "Horizontal vowels such as ㅗ, ㅜ, and ㅡ go below the first consonant.", "ㄴ + ㅗ = 노", speech: "노")
        three.build("노", pieces: ["ㄴ", "ㅗ"], layout: .below, tokens: ["ㄴ", "ㅗ", "ㅏ", "ㅁ"], rule: "Place ㄴ above ㅗ.")
        three.build("무", pieces: ["ㅁ", "ㅜ"], layout: .below, tokens: ["ㅗ", "ㅜ", "ㅁ", "ㄱ"], rule: "Place ㅁ above ㅜ.")
        three.build("그", pieces: ["ㄱ", "ㅡ"], layout: .below, tokens: ["ㄱ", "ㅡ", "ㅣ", "ㄴ"], rule: "ㅡ goes below the first consonant.")
        three.teach("Add a final consonant", "A final consonant, called 받침 (batchim), goes at the bottom of the whole block. Read the first consonant, vowel, then final.", "ㅁ + ㅜ + ㄴ = 문", speech: "문")
        three.build("문", pieces: ["ㅁ", "ㅜ", "ㄴ"], layout: .belowWithFinal, tokens: ["ㅁ", "ㅜ", "ㄴ", "ㅏ"], rule: "ㅁ above ㅜ; final ㄴ at the bottom.")
        three.build("산", pieces: ["ㅅ", "ㅏ", "ㄴ"], layout: .besideWithFinal, tokens: ["ㅅ", "ㅏ", "ㄴ", "ㅗ"], rule: "ㅅ and ㅏ sit beside each other; final ㄴ sits underneath both.")
        three.build("물", pieces: ["ㅁ", "ㅜ", "ㄹ"], layout: .belowWithFinal, tokens: ["ㅁ", "ㅜ", "ㄹ", "ㄴ"], rule: "Read ㅁ, then ㅜ, then final ㄹ. Do not add another vowel after the final consonant.")
        three.listen("문", options: ["문", "물", "무", "나"], hints: ["문": "mun · door", "물": "mul · water", "무": "mu", "나": "na"], cue: "Choose mun, the word for door.")

        var four = FoundationLesson(number: 4, title: "Your first words", subtitle: "Read words and connect them with pictures.")
        four.teach("Read one block at a time", "Read completed blocks from left to right. The spelling tells you how to build the word; recordings help you connect it to speech.", "나 + 무 = 나무 · tree", speech: "나무")
        let words = [("아이", "child", "a-i"), ("나무", "tree", "na-mu"), ("바다", "sea", "ba-da"), ("우유", "milk", "u-yu"), ("물", "water", "mul"), ("문", "door", "mun"), ("산", "mountain", "san"), ("집", "house", "jip")]
        four.teach("Two more reading clues", "ㅠ is yu: the extra short stroke adds a y sound to ㅜ. Final ㅂ is a closed p sound; do not release it with an extra vowel.", "우유 · milk     집 · house", speech: "우유, 집")
        for (index, word) in words.enumerated() {
            let group = (0..<4).map { words[(index + $0) % words.count] }
            four.introduceWord(word.0, meaning: word.1, romanization: word.2)
            four.word(word.0, meaning: word.1, romanization: word.2, choices: group.map { $0.0 }, hints: Dictionary(uniqueKeysWithValues: group.map { ($0.0, "\($0.2) · \($0.1)") }))
        }
        four.listen("나무", options: ["나무", "바다", "아이", "우유"], hints: Dictionary(uniqueKeysWithValues: words.map { ($0.0, "\($0.2) · \($0.1)") }), cue: "Find the word for tree.")
        four.listen("물", options: ["물", "문", "산", "집"], hints: Dictionary(uniqueKeysWithValues: words.map { ($0.0, "\($0.2) · \($0.1)") }), cue: "Find the word for water.")
        four.match(["물", "문", "산"], ["water", "door", "mountain"], rule: "Read the final consonant as part of the same block.")
        four.arrange("Build the word for tree", pieces: ["나", "무"], tokens: ["나", "무", "바", "다"], answer: "나무", rule: "Read the blocks from left to right: na-mu.")

        var five = FoundationLesson(number: 5, title: "Your first exchange", subtitle: "Use polite Korean in a real situation.")
        let greetings = ["안녕하세요": "annyeonghaseyo · hello", "감사합니다": "gamsahamnida · thank you", "죄송합니다": "joesonghamnida · sorry", "안녕히 가세요": "annyeonghi gaseyo · goodbye to someone leaving"]
        five.teach("Say hello politely", "Use 안녕하세요 as a polite greeting. Learn it as a useful whole expression; you will study its parts later.", "안녕하세요 · hello", speech: "안녕하세요")
        five.listen("안녕하세요", options: Array(greetings.keys).sorted(), hints: greetings, cue: "Choose the polite greeting hello.")
        five.teach("Thank someone or apologize", "감사합니다 is a respectful thank you. 죄송합니다 is a respectful apology. Listen to the whole expression before trying to repeat it.", "감사합니다 · thank you\n죄송합니다 · I am sorry", speech: "감사합니다. 죄송합니다.")
        five.listen("감사합니다", options: Array(greetings.keys).sorted(), hints: greetings, cue: "Choose thank you.")
        five.listen("죄송합니다", options: Array(greetings.keys).sorted(), hints: greetings, cue: "Choose the apology.")
        five.choice("Someone helps you. What do you say?", answer: "감사합니다", options: Array(greetings.keys).sorted(), hints: greetings, explanation: "감사합니다 thanks the person who helped you.")
        five.choice("You accidentally bump into someone.", answer: "죄송합니다", options: Array(greetings.keys).sorted(), hints: greetings, explanation: "죄송합니다 is a respectful apology.")
        five.teach("Who is leaving?", "Say 안녕히 가세요 to a person leaving. Say 안녕히 계세요 to a person staying. Choose by what the other person is doing.", "가세요 · you go\n계세요 · you stay", speech: "안녕히 가세요. 안녕히 계세요.")
        five.choice("You stay. Your guest leaves. Say goodbye.", answer: "안녕히 가세요", options: ["안녕히 가세요", "안녕히 계세요", "감사합니다", "죄송합니다"], hints: ["안녕히 가세요": "goodbye · the other person leaves", "안녕히 계세요": "goodbye · the other person stays", "감사합니다": "thank you", "죄송합니다": "sorry"], explanation: "Your guest is leaving, so say 안녕히 가세요.")
        five.choice("You leave. Your host stays. Say goodbye.", answer: "안녕히 계세요", options: ["안녕히 가세요", "안녕히 계세요", "안녕하세요", "감사합니다"], hints: ["안녕히 가세요": "the other person leaves", "안녕히 계세요": "the other person stays", "안녕하세요": "hello", "감사합니다": "thank you"], explanation: "Your host is staying, so say 안녕히 계세요.")
        five.arrange("Say goodbye to someone leaving", pieces: ["안녕히", "가세요"], tokens: ["안녕히", "가세요", "계세요", "감사합니다"], answer: "안녕히 가세요", rule: "The other person is going: use 가세요.")
        return [one.lesson, two.lesson, three.lesson, four.lesson, five.lesson]
    }

    private static var foundationCheckpoint: CourseCheckpointQuiz {
        var quiz = FoundationLesson(number: 0, title: "Checkpoint", subtitle: "")
        quiz.listen("오", options: ["아", "어", "오", "우"], hints: [:], cue: "Choose the block for o (oh).")
        quiz.choice("Which consonant starts 나?", answer: "ㄴ", options: ["ㄱ", "ㄴ", "ㅁ", "ㅇ"], explanation: "나 starts with ㄴ.")
        quiz.build("마", pieces: ["ㅁ", "ㅏ"], layout: .beside, tokens: ["ㅁ", "ㅏ", "ㅗ", "ㄴ"], rule: "")
        quiz.build("무", pieces: ["ㅁ", "ㅜ"], layout: .below, tokens: ["ㅁ", "ㅜ", "ㅏ", "ㄴ"], rule: "")
        quiz.build("문", pieces: ["ㅁ", "ㅜ", "ㄴ"], layout: .belowWithFinal, tokens: ["ㅁ", "ㅜ", "ㄴ", "ㄹ"], rule: "")
        quiz.listen("물", options: ["물", "문", "산", "집"], hints: [:], cue: "Choose the word for water.")
        quiz.choice("Find the word for tree.", answer: "나무", options: ["나무", "바다", "우유", "아이"], explanation: "나무 means tree.")
        quiz.choice("Someone helps you. What do you say?", answer: "감사합니다", options: ["안녕하세요", "감사합니다", "죄송합니다", "안녕히 계세요"], explanation: "감사합니다 means thank you.")
        quiz.choice("Your host stays as you leave. Say goodbye.", answer: "안녕히 계세요", options: ["안녕히 계세요", "안녕히 가세요", "안녕하세요", "죄송합니다"], explanation: "Use 계세요 for the person staying.")
        quiz.arrange("Build the word for tree", pieces: ["나", "무"], tokens: ["나", "무", "바", "다"], answer: "나무", rule: "")
        return CourseCheckpointQuiz(id: "kr-cp-1", title: "Your First Korean · Checkpoint",
            summary: "10 questions on vowel sounds, syllable positions, first words, and polite exchanges.",
            questions: quiz.cards, keyConcepts: ["Core vowel sounds", "Initial consonants", "Beside and below layouts", "Final consonants", "First words", "Polite exchanges"])
    }
}

private struct FoundationLesson {
    let number: Int
    let title: String
    let subtitle: String
    var cards: [CourseLessonCard] = []
    private var prefix: String { number == 0 ? "kr-cp-1-workshop" : "kr-1-\(number)-workshop" }
    private var nextId: String { "\(prefix)-\(cards.count + 1)" }
    private var sequence: Int { cards.count }
    var lesson: CourseLesson {
        CourseLesson(id: "kr-1-\(number)", lessonNumber: number, title: title, subtitle: subtitle,
            estimatedMinutes: 6, tipNote: "Practice one activity at a time. Hints are available until the checkpoint.", cards: cards)
    }
    mutating func letter(key: String, symbol: String, block: String, rule: String, options: [String], hints: [String: String], blockHints: [String: String], cue: String) {
        let group = "kr-1-\(number)-focus-\(key)"
        cards.append(CourseLessonCard(id: group + "-teach", question: "Meet \(symbol)", correctAnswer: rule,
            cardType: "vocabulary", speechText: symbol, conceptTag: key,
            activity: CourseActivity(kind: .teach, sequence: sequence, rule: rule, example: "\(symbol) → \(block)", practiceGroup: group)))
        cards.append(CourseLessonCard(id: group + "-listen", question: "Listen and choose", options: options,
            correctAnswer: symbol, cardType: "listening", speechText: symbol, conceptTag: key,
            explanation: "\(symbol) · \(cue)", readingPrompt: "Find the letter for \(cue).",
            activity: CourseActivity(kind: .listenChoose, sequence: sequence, optionHints: hints,
                readingCue: "Find the letter for \(cue).", practiceGroup: group)))
        cards.append(CourseLessonCard(id: group + "-trace", question: "Draw \(symbol)", options: options,
            correctAnswer: symbol, cardType: "hangulTrace", conceptTag: key, explanation: rule,
            activity: CourseActivity(kind: .trace, sequence: sequence, symbol: symbol, practiceGroup: group)))
        let vowel = !blockHints.isEmpty
        let quizOptions = vowel ? options.map { ["ㅏ": "아", "ㅓ": "어", "ㅗ": "오", "ㅜ": "우", "ㅡ": "으", "ㅣ": "이"][$0] ?? $0 } : options
        cards.append(CourseLessonCard(id: group + "-recognize", question: vowel ? "Which block contains \(symbol)?" : "Which letter starts \(block)?",
            options: quizOptions, correctAnswer: vowel ? block : symbol, cardType: "multipleChoice", conceptTag: key,
            explanation: "\(symbol) is the \(vowel ? "vowel" : "first consonant") in \(block).",
            activity: CourseActivity(kind: .situation, sequence: sequence, optionHints: vowel ? blockHints : hints, practiceGroup: group)))
    }

    mutating func teach(_ title: String, _ rule: String, _ example: String, speech: String? = nil) {
        cards.append(CourseLessonCard(id: nextId + (cards.isEmpty ? "-guide" : ""), question: title,
            correctAnswer: rule, cardType: "vocabulary", speechText: speech, conceptTag: self.title,
            activity: CourseActivity(kind: .teach, sequence: sequence, rule: rule, example: example)))
    }
    mutating func trace(_ symbol: String, rule: String) {
        let candidates = [symbol] + ["ㅏ", "ㅓ", "ㅗ", "ㅜ", "ㅡ", "ㅣ", "ㄱ", "ㄴ", "ㅁ", "ㅇ"].filter { $0 != symbol }.prefix(3)
        cards.append(CourseLessonCard(id: nextId, question: "Trace \(symbol)", options: candidates,
            correctAnswer: symbol, hint: rule, cardType: "hangulTrace", conceptTag: title, explanation: rule,
            activity: CourseActivity(kind: .trace, sequence: sequence, rule: rule, symbol: symbol)))
    }
    mutating func listen(_ answer: String, options: [String], hints: [String: String], cue: String, rule: String? = nil) {
        cards.append(CourseLessonCard(id: nextId, question: "Listen and choose", options: options, correctAnswer: answer,
            hint: rule ?? "Show a sound guide under each option.", cardType: "listening", speechText: answer,
            conceptTag: title, explanation: "\(answer) · \(hints[answer] ?? cue)", readingPrompt: cue,
            activity: CourseActivity(kind: .listenChoose, sequence: sequence, rule: rule, optionHints: hints, readingCue: cue)))
    }
    mutating func build(_ answer: String, pieces: [String], layout: CourseActivity.Layout, tokens: [String], rule: String) {
        let distractors = ["나", "마", "노", "무", "문", "물", "산", "그"].filter { $0 != answer }
        cards.append(CourseLessonCard(id: nextId, question: "Build \(answer)", options: [answer] + distractors.prefix(3),
            correctAnswer: answer, hint: rule, cardType: "hangulBuild", conceptTag: title,
            explanation: "\(pieces.joined(separator: " + ")) = \(answer)",
            activity: CourseActivity(kind: .buildBlock, sequence: sequence, rule: rule.isEmpty ? nil : rule, example: answer,
                layout: layout, tokens: tokens, slots: pieces,
                slotLabels: pieces.count == 3 ? ["First", "Vowel", "Final"] : ["First", "Vowel"])))
    }
    mutating func choice(_ prompt: String, answer: String, options: [String], hints: [String: String] = [:], explanation: String) {
        cards.append(CourseLessonCard(id: nextId, question: prompt, options: options, correctAnswer: answer,
            cardType: "multipleChoice", conceptTag: title, explanation: explanation,
            activity: CourseActivity(kind: .situation, sequence: sequence, optionHints: hints)))
    }
    mutating func word(_ korean: String, meaning: String, romanization: String, choices: [String], hints: [String: String]) {
        cards.append(CourseLessonCard(id: nextId, question: "Find ‘\(meaning)’", options: choices, correctAnswer: korean,
            cardType: "multipleChoice", promptImageName: "koreanimages/\(meaning).png",
            vocabularyItem: KoreanVocabularyItem(surface: korean, dictionaryForm: korean, romanization: romanization,
                partOfSpeech: "Noun", contextualMeaning: meaning), conceptTag: title, explanation: "\(korean) · \(meaning)",
            activity: CourseActivity(kind: .situation, sequence: sequence, optionHints: hints)))
    }
    mutating func introduceWord(_ korean: String, meaning: String, romanization: String) {
        cards.append(CourseLessonCard(id: nextId, question: korean, correctAnswer: meaning, cardType: "vocabulary",
            promptImageName: "koreanimages/\(meaning).png",
            vocabularyItem: KoreanVocabularyItem(surface: korean, dictionaryForm: korean, romanization: romanization,
                partOfSpeech: "Noun", contextualMeaning: meaning), speechText: korean, conceptTag: title,
            activity: CourseActivity(kind: .teach, sequence: sequence, rule: "\(korean) means \(meaning).", example: "\(korean) · \(romanization)")))
    }
    mutating func match(_ left: [String], _ right: [String], rule: String) {
        cards.append(CourseLessonCard(id: nextId, question: "Connect the pairs", correctAnswer: "Matches",
            hint: rule, cardType: "matching", matchingLeftItems: left, matchingRightItems: right, conceptTag: title,
            activity: CourseActivity(kind: .matchPairs, sequence: sequence, rule: rule)))
    }
    mutating func arrange(_ prompt: String, pieces: [String], tokens: [String], answer: String, rule: String) {
        cards.append(CourseLessonCard(id: nextId, question: prompt, options: [answer, "바다", "아이", "우유"].reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } },
            correctAnswer: answer, hint: rule, cardType: "tokenPlacement", conceptTag: title,
            explanation: pieces.joined(separator: " → "),
            activity: CourseActivity(kind: .placeTokens, sequence: sequence, rule: rule.isEmpty ? nil : rule, example: answer,
                tokens: tokens, slots: pieces, slotLabels: pieces.indices.map { "\($0 + 1)" })))
    }
}
