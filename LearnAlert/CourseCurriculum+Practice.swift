import Foundation

extension CourseCurriculumCatalog {
    /// Different tasks practice the same authored material; IDs remain stable across releases.
    static func variedKoreanCards(id: String, title: String, note: String, entries: [(String, String)]) -> [CourseLessonCard] {
        var cards = [CourseLessonCard(id: "\(id)-guide", question: title,
            correctAnswer: note, cardType: "vocabulary", conceptTag: title)]
        cards += entries.enumerated().flatMap { index, entry -> [CourseLessonCard] in
            let (korean, english) = entry
            let vocabulary = KoreanVocabularyItem(surface: korean, dictionaryForm: korean,
                romanization: "", partOfSpeech: korean.contains(" ") || korean.hasSuffix(".") || korean.hasSuffix("?") ? "Expression" : "Noun",
                contextualMeaning: english, breakdownNote: note, exampleKorean: korean, exampleEnglish: english)
            let meanings = choices(correct: english, among: entries.map { $0.1 }, offset: index)
            let spellings = choices(correct: korean, among: entries.map { $0.0 }, offset: index + 1)
            return [
                CourseLessonCard(id: "\(id)-\(index + 1)-read", question: "What does ‘\(korean)’ mean?",
                    options: meanings, correctAnswer: english, hint: note, vocabularyItem: vocabulary,
                    grammarNote: note, speechText: korean, conceptTag: title, explanation: "\(korean) — \(english)"),
                CourseLessonCard(id: "\(id)-\(index + 1)-write", question: "Write in Korean: \(english)",
                    correctAnswer: korean, hint: note, cardType: "fillBlank", vocabularyItem: vocabulary,
                    grammarNote: note, conceptTag: title, explanation: "\(korean) — \(english)"),
                CourseLessonCard(id: "\(id)-\(index + 1)-recognize", question: "Choose the Korean for: \(english)",
                    options: spellings, correctAnswer: korean, hint: note, grammarNote: note,
                    conceptTag: title, explanation: "\(korean) — \(english)"),
                CourseLessonCard(id: "\(id)-\(index + 1)-listen", question: "Listen. What does it mean?",
                    options: meanings, correctAnswer: english, cardType: "listening", vocabularyItem: vocabulary,
                    grammarNote: note, speechText: korean, conceptTag: title, explanation: "\(korean) — \(english)",
                    readingPrompt: "Read ‘\(korean)’. Choose its meaning."),
                CourseLessonCard(id: "\(id)-\(index + 1)-dictate", question: "Listen and write what you hear.",
                    correctAnswer: korean, hint: note, cardType: "listeningWrite", vocabularyItem: vocabulary,
                    grammarNote: note, speechText: korean, conceptTag: title, explanation: "\(korean) — \(english)",
                    readingPrompt: "Write in Korean: \(english)")
            ]
        }
        for start in stride(from: 0, to: entries.count, by: 3) {
            let group = Array(entries[start..<min(start + 3, entries.count)])
            cards.append(CourseLessonCard(id: "\(id)-match-\(start)", question: "Match the Korean to its meaning",
                correctAnswer: "Matches", cardType: "matching", matchingLeftItems: group.map { $0.0 },
                matchingRightItems: group.map { $0.1 }, grammarNote: note, conceptTag: title))
        }
        return cards
    }

    private static func choices(correct: String, among values: [String], offset: Int) -> [String] {
        var others = Array(values.filter { $0 != correct }.dropFirst(offset % max(1, values.count - 1)))
        others += values.filter { $0 != correct && !others.contains($0) }
        var options = Array(others.prefix(3))
        options.insert(correct, at: offset % (options.count + 1))
        return options
    }

    static func enhancingPractice(_ course: CourseDefinition) -> CourseDefinition {
        let foundations: [[(String, String)]] = [
            [("아", "the vowel sound a"), ("어", "the vowel sound eo"), ("오", "the vowel sound o"),
             ("우", "the vowel sound u"), ("으", "the vowel sound eu"), ("이", "the vowel sound i")],
            [("가", "the syllable ga"), ("나", "the syllable na"), ("다", "the syllable da"),
             ("라", "the syllable ra"), ("마", "the syllable ma"), ("바", "the syllable ba")],
            [("한", "the syllable han"), ("글", "the syllable geul"), ("물", "water"),
             ("문", "door"), ("산", "mountain"), ("집", "house")],
            [("안녕하세요", "hello (polite)"), ("감사합니다", "thank you (respectful)"), ("죄송합니다", "I am sorry (respectful)"),
             ("안녕히 가세요", "goodbye to someone leaving"), ("안녕히 계세요", "goodbye to someone staying"), ("만나서 반가워요", "nice to meet you")],
            [("아이", "child"), ("나무", "tree"), ("바다", "sea"), ("우유", "milk"), ("한국어", "Korean language"), ("학교", "school")]
        ]
        let readingNotes: [String: (String, String, String)] = [
            "kr-1-1-2": ("ㅣ", "The ‘ee’ sound in ‘see’. Put this vertical vowel to the right of the initial consonant: ㅇ + ㅣ = 이.", "이"),
            "kr-1-2-4": ("ㅇ", "Initial ㅇ is a silent placeholder. Final ㅇ is ng: 아 sounds a, while 앙 sounds ang.", "아, 앙"),
            "kr-1-3-4": ("한국어", "Korean language. It is written 한국어 and pronounced 한구거: the final ㄱ links into the vowel-starting 어.", "한국어"),
            "kr-1-4-5": ("안녕히 가세요", "Goodbye, said to someone leaving. 가세요 comes from 가다 (to go). Say 안녕히 계세요 when the other person is staying.", "안녕히 가세요"),
            "kr-1-5-5": ("만나서 반갑습니다", "Nice to meet you, in formal polite speech. 만나서 comes from 만나다 (to meet). The everyday polite form is 만나서 반가워요.", "만나서 반갑습니다")
        ]
        let units = course.units.map { unit in
            let lessons = unit.lessons.enumerated().map { index, lesson in
                var cards = lesson.cards.map { card in
                    guard card.cardType == "tapReveal" else { return card }
                    let vocabulary = readingNotes[card.id].map { note in
                        KoreanVocabularyItem(surface: note.0, dictionaryForm: note.0, romanization: "",
                            partOfSpeech: "Reading note", contextualMeaning: note.1, audioText: note.2)
                    } ?? card.vocabularyItem
                    return CourseLessonCard(id: card.id, question: card.question, options: card.options,
                        correctAnswer: card.correctAnswer, hint: card.hint, cardType: "vocabulary",
                        matchingLeftItems: card.matchingLeftItems, matchingRightItems: card.matchingRightItems,
                        promptImageName: card.promptImageName, optionImageNames: card.optionImageNames,
                        vocabularyItem: vocabulary, grammarNote: card.grammarNote, speechText: card.speechText,
                        conceptTag: card.conceptTag, explanation: card.explanation, acceptedAnswers: card.acceptedAnswers)
                }
                if course.language == "Korean", unit.unitNumber == 1, foundations.indices.contains(index) {
                    cards += variedKoreanCards(id: "\(lesson.id)-extra", title: lesson.title,
                        note: lesson.tipNote ?? "Read the initial, vowel, then final consonant.", entries: foundations[index])
                }
                return CourseLesson(id: lesson.id, lessonNumber: lesson.lessonNumber, title: lesson.title,
                    subtitle: lesson.subtitle, nodeType: lesson.nodeType,
                    estimatedMinutes: course.language == "Korean" ? 15 : lesson.estimatedMinutes,
                    tipNote: lesson.tipNote, cards: cards)
            }
            return CourseUnit(id: unit.id, unitNumber: unit.unitNumber, title: unit.title,
                subtitle: unit.subtitle, colorHex: unit.colorHex, badgeIcon: unit.badgeIcon,
                lessons: lessons, checkpointQuiz: unit.checkpointQuiz)
        }
        return CourseDefinition(id: course.id, title: course.title, language: course.language,
            flagEmoji: course.flagEmoji, levelTag: course.levelTag, colorHex: course.colorHex,
            summary: course.summary, estimatedHours: course.estimatedHours, outcomes: course.outcomes, units: units)
    }
}
