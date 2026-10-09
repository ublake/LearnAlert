import Foundation

struct KoreanWordEntry {
    let dictionaryForm: String
    let meaning: String
    let usage: String
}

enum KoreanLexicon {
    private static let nouns: [String: String] = [
        "학생": "student",
        "선생님": "teacher",
        "친구": "friend",
        "사람": "person",
        "물": "water",
        "책": "book",
        "커피": "coffee",
        "밥": "meal; cooked rice",
        "한국어": "Korean language",
        "가방": "bag",
        "이름": "name",
        "집": "home; house",
        "날씨": "weather",
        "음식": "food",
        "아침": "morning; breakfast",
        "밤": "night",
        "음악": "music",
        "학교": "school",
        "도서관": "library",
        "식당": "restaurant",
        "역": "station",
        "지하철": "subway",
        "시간": "time",
        "분": "minute",
        "시": "hour; o’clock",
        "개": "general counter",
        "명": "counter for people",
        "잔": "counter for cups",
        "권": "counter for books",
        "영화": "film",
        "운동": "exercise",
        "창문": "window",
        "문": "door",
        "회의": "meeting",
        "계획": "plan",
        "결과": "result",
        "과정": "process",
        "비용": "cost",
        "상황": "situation",
        "기회": "opportunity",
        "실수": "mistake",
        "연습": "practice",
        "자신감": "confidence",
        "경험": "experience",
        "의견": "opinion",
        "문제": "problem",
        "이유": "reason",
        "돈": "money",
        "주말": "weekend",
        "날": "day",
        "년": "year",
        "한국": "Korea",
        "서울": "Seoul",
        "사과": "apple",
        "의사": "doctor",
        "의자": "chair",
    ]
    private static let forms: [String: KoreanWordEntry] = [
        "먹어요": KoreanWordEntry(dictionaryForm: "먹다", meaning: "to eat", usage: "Polite present form."),
        "마셔요": KoreanWordEntry(dictionaryForm: "마시다", meaning: "to drink", usage: "Polite present form with vowel contraction."),
        "공부해요": KoreanWordEntry(dictionaryForm: "공부하다", meaning: "to study", usage: "하다 becomes 해요 in the polite present."),
        "가요": KoreanWordEntry(dictionaryForm: "가다", meaning: "to go", usage: "Polite present form."),
        "와요": KoreanWordEntry(dictionaryForm: "오다", meaning: "to come", usage: "오다 contracts to 와요."),
        "있어요": KoreanWordEntry(dictionaryForm: "있다", meaning: "to exist; to be present", usage: "Polite present form."),
        "없어요": KoreanWordEntry(dictionaryForm: "없다", meaning: "not to exist; not to have", usage: "Polite present form."),
        "아니에요": KoreanWordEntry(dictionaryForm: "아니다", meaning: "not to be", usage: "Polite negative copula."),
        "좋아요": KoreanWordEntry(dictionaryForm: "좋다", meaning: "to be good", usage: "Descriptive verb in the polite present."),
        "작아요": KoreanWordEntry(dictionaryForm: "작다", meaning: "to be small", usage: "Descriptive verb in the polite present."),
        "커요": KoreanWordEntry(dictionaryForm: "크다", meaning: "to be big", usage: "으 drops before 어요."),
        "추워요": KoreanWordEntry(dictionaryForm: "춥다", meaning: "to be cold", usage: "ㅂ changes to 우 before 어요."),
        "들어요": KoreanWordEntry(dictionaryForm: "듣다", meaning: "to listen", usage: "ㄷ changes to ㄹ before 어요."),
        "읽어요": KoreanWordEntry(dictionaryForm: "읽다", meaning: "to read", usage: "Polite present form."),
        "배워요": KoreanWordEntry(dictionaryForm: "배우다", meaning: "to learn", usage: "우 + 어 contracts to 워."),
        "쉬어요": KoreanWordEntry(dictionaryForm: "쉬다", meaning: "to rest", usage: "Polite present form."),
        "일어나요": KoreanWordEntry(dictionaryForm: "일어나다", meaning: "to get up", usage: "Polite present form."),
        "자요": KoreanWordEntry(dictionaryForm: "자다", meaning: "to sleep", usage: "Polite present form."),
        "했어요": KoreanWordEntry(dictionaryForm: "하다", meaning: "to do", usage: "Polite past form."),
        "갔어요": KoreanWordEntry(dictionaryForm: "가다", meaning: "to go", usage: "Polite past form."),
        "봤어요": KoreanWordEntry(dictionaryForm: "보다", meaning: "to see; to watch", usage: "보았어요 contracts to 봤어요."),
        "주세요": KoreanWordEntry(dictionaryForm: "주다", meaning: "please give", usage: "A polite request form with honorific 시."),
        "하세요": KoreanWordEntry(dictionaryForm: "하다", meaning: "to do", usage: "Polite honorific form; can also be a request."),
        "드세요": KoreanWordEntry(dictionaryForm: "드시다", meaning: "to eat; to drink (respectful)", usage: "Polite form of the respectful verb."),
        "계세요": KoreanWordEntry(dictionaryForm: "계시다", meaning: "to be present (respectful)", usage: "Respectful counterpart of 있다 for a person."),
        "됩니다": KoreanWordEntry(dictionaryForm: "되다", meaning: "to become; to work", usage: "Formal polite present form."),
        "했습니다": KoreanWordEntry(dictionaryForm: "하다", meaning: "to do", usage: "Formal polite past form."),
        "중요합니다": KoreanWordEntry(dictionaryForm: "중요하다", meaning: "to be important", usage: "Formal polite descriptive form."),
        "달라집니다": KoreanWordEntry(dictionaryForm: "달라지다", meaning: "to change; to vary", usage: "Formal polite present form."),
        "줄었습니다": KoreanWordEntry(dictionaryForm: "줄다", meaning: "to decrease", usage: "Formal polite past form."),
        "확인했습니다": KoreanWordEntry(dictionaryForm: "확인하다", meaning: "to confirm", usage: "Formal polite past form."),
        "취소할": KoreanWordEntry(dictionaryForm: "취소하다", meaning: "to cancel", usage: "Future/anticipated noun-modifying form."),
        "기다릴": KoreanWordEntry(dictionaryForm: "기다리다", meaning: "to wait", usage: "Future/anticipated noun-modifying form."),
        "알았더라면": KoreanWordEntry(dictionaryForm: "알다", meaning: "to know", usage: "Past contrary-to-fact condition: if one had known."),
        "연습할수록": KoreanWordEntry(dictionaryForm: "연습하다", meaning: "to practice", usage: "(으)ㄹ수록 means the more one does something."),
        "저는": KoreanWordEntry(dictionaryForm: "저", meaning: "I (humble)", usage: "는 marks the topic."),
        "제가": KoreanWordEntry(dictionaryForm: "저", meaning: "I (humble)", usage: "저 + 가 changes to 제가."),
        "제": KoreanWordEntry(dictionaryForm: "저", meaning: "my (humble)", usage: "Contraction of 저의."),
        "오늘": KoreanWordEntry(dictionaryForm: "오늘", meaning: "today", usage: "Time expression."),
        "내일": KoreanWordEntry(dictionaryForm: "내일", meaning: "tomorrow", usage: "Time expression."),
        "어제": KoreanWordEntry(dictionaryForm: "어제", meaning: "yesterday", usage: "Time expression."),
        "지금": KoreanWordEntry(dictionaryForm: "지금", meaning: "now", usage: "Time expression."),
        "같이": KoreanWordEntry(dictionaryForm: "같이", meaning: "together", usage: "Adverb."),
        "이미": KoreanWordEntry(dictionaryForm: "이미", meaning: "already", usage: "Adverb."),
        "다시": KoreanWordEntry(dictionaryForm: "다시", meaning: "again", usage: "Adverb."),
        "미리": KoreanWordEntry(dictionaryForm: "미리", meaning: "in advance", usage: "Adverb."),
        "정말": KoreanWordEntry(dictionaryForm: "정말", meaning: "really", usage: "Adverb."),
        "조금": KoreanWordEntry(dictionaryForm: "조금", meaning: "a little", usage: "Amount or degree."),
        "반면에": KoreanWordEntry(dictionaryForm: "반면", meaning: "on the other hand", usage: "Introduces a contrasting side."),
        "때문에": KoreanWordEntry(dictionaryForm: "때문", meaning: "because of", usage: "Follows a noun or a nominalized clause."),
        "덕분에": KoreanWordEntry(dictionaryForm: "덕분", meaning: "thanks to", usage: "Usually introduces a beneficial cause."),
        "그리고": KoreanWordEntry(dictionaryForm: "그리고", meaning: "and; then", usage: "Connective adverb."),
        "아무리": KoreanWordEntry(dictionaryForm: "아무리", meaning: "no matter how much", usage: "Often pairs with 아/어도."),
        "또한": KoreanWordEntry(dictionaryForm: "또한", meaning: "also; furthermore", usage: "Connective adverb, common in formal writing."),
    ]
    private static let particles: [(String, String)] = [
        ("에서", "Place of action."), ("으로", "Direction or means."), ("에게", "Recipient."),
        ("부터", "Starting point."), ("까지", "End point."), ("은", "Topic; contrast."),
        ("는", "Topic; contrast."), ("이", "Subject."), ("가", "Subject."),
        ("을", "Object."), ("를", "Object."), ("에", "Location, destination, or time."),
        ("의", "Possession."), ("도", "Also; too."), ("로", "Direction or means."),
        ("와", "And; with."), ("과", "And; with.")
    ]
    static func lookup(_ surface: String) -> KoreanWordEntry? {
        let word = surface.trimmingCharacters(in: .punctuationCharacters)
        if let entry = forms[word] { return entry }
        if let meaning = nouns[word] { return KoreanWordEntry(dictionaryForm: word, meaning: meaning, usage: "Noun.") }
        // Strip only authored particles from a known noun, never guess verb lemmas.
        for (particle, usage) in particles where word.hasSuffix(particle) {
            let base = String(word.dropLast(particle.count))
            if let meaning = nouns[base] {
                return KoreanWordEntry(dictionaryForm: base, meaning: meaning, usage: "\(base) + \(particle). \(usage)")
            }
        }
        return nil
    }
}
