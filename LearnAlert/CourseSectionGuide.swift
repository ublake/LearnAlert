import SwiftUI

struct CourseGuideTopic: Identifiable {
    var id: String { title }
    let title: String
    let rule: String
    let examples: [String]
}

/// Bundled, original teaching notes. No network connection is needed in an alert.
enum CourseSectionGuides {
    static func topics(course: CourseDefinition, unit: CourseUnit) -> [CourseGuideTopic] {
        func topic(_ title: String, _ rule: String, _ examples: [String]) -> CourseGuideTopic {
            CourseGuideTopic(title: title, rule: rule, examples: examples)
        }
        guard course.language == "Korean" else {
            return [
                topic("Read the sounds", "Spanish vowels have steady sounds: a, e, i, o, u. Avoid the English habit of gliding into a second vowel. H is silent; ñ is a different letter from n. Written accents show stress when a word does not follow the usual pattern.", ["hola → the h is silent", "niño → boy; the ñ sounds like ny", "café → stress the final syllable"]),
                topic("Choose ser or estar", "Use ser for identity, origin, and defining characteristics. Use estar for location and a person's current condition. ‘Permanent versus temporary’ is only a rough shortcut: an event's location uses ser, and some lasting conditions use estar.", ["Soy estudiante. → I am a student.", "Estoy en casa. → I am at home.", "Estoy bien. → I am well."]),
                topic("Introduce yourself politely", "Me llamo introduces your name. Soy de introduces where you are from. Tú is informal; usted is respectful and uses third-person verb forms. Match the greeting to the time of day, and use mucho gusto when meeting someone.", ["Me llamo Ana. → My name is Ana.", "¿Cómo está usted? → How are you? (respectful)", "Mucho gusto. → Nice to meet you."])
            ] + lessonNotes(unit)
        }
        let topics: [CourseGuideTopic]
        switch unit.unitNumber {
        case 1:
            topics = [
                topic("Build one syllable at a time", "Each Hangul block contains an initial consonant and a vowel, with an optional final consonant called 받침 (batchim). Read the initial, then the vowel, then the final. Read completed blocks from left to right. A vowel-only syllable still needs initial ㅇ, which is silent in that position.", ["ㄱ + ㅏ = 가 · ㅇ + ㅏ = 아", "ㅎ + ㅏ + ㄴ = 한 · ㄱ + ㅡ + ㄹ = 글", "한 + 글 = 한글 · two syllable blocks"]),
                topic("Put the vowel in the right place", "Vertical vowels such as ㅏ, ㅓ, and ㅣ sit to the right of the initial. Horizontal vowels such as ㅗ, ㅜ, and ㅡ sit underneath it. Compound vowels such as ㅘ use space underneath and to the right. Any batchim sits at the bottom of the entire block, below the initial and vowel.", ["가: ㄱ on the left, ㅏ on the right", "고: ㄱ above ㅗ", "관: ㄱ with ㅘ, then ㄴ underneath"]),
                topic("Read the vowels without English spelling", "The core vowels in this section are ㅏ a, ㅓ eo, ㅗ o, ㅜ u, ㅡ eu, and ㅣ i. Romanization is a reading aid, not an exact English sound guide. In particular, eo and eu each represent one Korean vowel. Adding a second short stroke creates the y-series: ㅑ, ㅕ, ㅛ, ㅠ.", ["아 · 어 · 오 · 우 · 으 · 이", "야 · 여 · 요 · 유", "아이 → a-i → child"]),
                topic("Consonants and the two jobs of ㅇ", "Initial ㅇ is silent, but final ㅇ is ng. Some consonants sound different at the start and end of a block. Plain ㄱ, ㄷ, ㅂ, aspirated ㅋ, ㅌ, ㅍ, and tense ㄲ, ㄸ, ㅃ are separate Korean sounds; English letters cannot show the whole distinction. Listen to whole syllables when practicing them.", ["아 → a · 앙 → ang", "가 · 카 · 까 → three different initial sounds", "나무 → na-mu → tree"]),
                topic("Batchim and linking", "At the end of a syllable, consonants reduce to seven basic final sounds: ㄱ, ㄴ, ㄷ, ㄹ, ㅁ, ㅂ, ㅇ. Final stops are not followed by an extra vowel. Before a vowel-starting ending or particle, a final consonant often links into the next syllable. Other sound changes depend on the following consonant; do not treat every spelling as a separate English sound.", ["물 → mul, without an extra vowel after ㄹ", "한국어 → pronounced 한구거", "밥이 → pronounced 바비"]),
                topic("Polite greetings are whole expressions", "Use 안녕하세요 as a polite greeting and 감사합니다 to thank someone. 죄송합니다 is a respectful apology. 안녕히 가세요 is said to someone leaving; 안녕히 계세요 is said to someone staying. Politeness toward your listener and honorific respect for the person discussed are related but different choices.", ["안녕하세요. → Hello.", "감사합니다. → Thank you.", "안녕히 계세요. → Goodbye. (you stay)"])
            ]
        case 2:
            topics = [
                topic("Topic, subject, and object", "Particles attach directly to nouns. 은/는 marks the topic or a contrast; 이/가 marks the subject; 을/를 marks the object of an action. After batchim use 은, 이, 을. After a vowel use 는, 가, 를. These particles have different jobs, so choosing a form requires both the noun's ending and the sentence's meaning.", ["저는 학생이에요. → As for me, I am a student.", "물이 있어요. → There is water.", "커피를 마셔요. → I drink coffee."]),
                topic("Say what something is", "Attach 이에요 to a noun ending in a consonant and 예요 to one ending in a vowel. These mean ‘is/am/are’ with a noun. To say something is not that noun, use 이/가 아니에요. Do not use 안 directly before 이에요 as the normal negative form.", ["학생이에요. → I am a student.", "친구예요. → It is a friend.", "학생이 아니에요. → I am not a student."]),
                topic("Point, ask, and possess", "이 means this near the speaker, 그 means that near the listener or already mentioned, and 저 means that over there. Add a noun after them, or use 이것/그것/저것 for a thing. 뭐 asks what and 누구 asks who. 의 marks possession; 제 is the humble shortened form of 저의.", ["이 책 → this book · 저것 → that thing over there", "이것은 뭐예요? → What is this?", "제 가방 → my bag"]),
                topic("Describe directly", "Korean descriptive verbs can finish a sentence without an extra ‘is.’ 크다 becomes 커요 and 작다 becomes 작아요. 있다 and 없다 describe existence or possession. Some forms are irregular, so learn their dictionary form alongside the practiced sentence.", ["집이 작아요. → The house is small.", "날씨가 좋아요. → The weather is good.", "책이 없어요. → There is no book."])
            ]
        case 3:
            topics = [
                topic("Make polite present forms", "Remove 다 to find the stem. Stems with a final vowel ㅏ or ㅗ generally take 아요; other stems take 어요. 하다 becomes 해요. Vowels often contract, and irregular verbs need their own pattern. Use the stem, rather than the last letter of 다, to choose an ending.", ["가다 → 가요 · 먹다 → 먹어요", "공부하다 → 공부해요", "배우다 → 배워요"]),
                topic("Location versus place of action", "에 marks a destination or the place where someone or something exists. 에서 marks where an action happens. The same place can take either particle depending on the verb. Use 에 with 있다/없다 for location and 에서 with actions such as studying or eating.", ["학교에 가요. → I go to school.", "학교에 있어요. → I am at school.", "학교에서 공부해요. → I study at school."]),
                topic("When and how often", "에 can mark a specific time. 오늘, 내일, and 어제 usually stand on their own without 에. Frequency words such as 매일, 자주, and 가끔 normally appear before the verb. Put the time near the beginning when you want to establish the situation.", ["세 시에 만나요. → We meet at three.", "내일 가요. → I go tomorrow.", "매일 운동해요. → I exercise every day."]),
                topic("Two number systems and counters", "Native Korean numbers are commonly used for hours and many counters. Sino-Korean numbers are used for minutes, dates, prices, and phone numbers. Before counters, 하나, 둘, 셋, 넷 shorten to 한, 두, 세, 네. Choose the counter for the thing being counted.", ["세 시 십 분 → 3:10", "책 세 권 → three books", "커피 두 잔 → two cups of coffee"])
            ]
        case 4:
            topics = [
                topic("Past and planned future", "Past polite endings are 았어요 after ㅏ/ㅗ, 었어요 after other vowels, and 했어요 for 하다. Future plans commonly use (으)ㄹ 거예요: 을 after a consonant, ㄹ after a vowel. A stem ending in ㄹ does not add a second ㄹ.", ["가다 → 갔어요 · 먹다 → 먹었어요", "하다 → 했어요", "내일 만날 거예요. → I will meet tomorrow."]),
                topic("Not doing versus cannot do", "안 or 지 않다 expresses a negative action or state. 못 or 지 못하다 commonly expresses inability or a situation preventing an action. With 하다 actions, 안/못 often comes before 해요 after the action noun. Use 없다 for not existing and 아니다 for not being a noun.", ["수영을 안 해요. → I do not swim.", "수영을 못 해요. → I cannot swim.", "시간이 없어요. → I do not have time."]),
                topic("An action in progress", "Attach 고 있어요 to an action stem to describe an ongoing activity. Time words such as 지금 make the current situation clear. Some verbs can also use this pattern for a continuing result or habitual activity; the meaning depends on the verb and context.", ["지금 공부하고 있어요. → I am studying now.", "친구를 기다리고 있어요. → I am waiting for a friend."]),
                topic("Past experience", "아/어 본 적이 있어요 says you have experienced trying or doing something. Use 없어요 if you have never done it. This describes experience, rather than merely saying an event happened at a specific time.", ["한국에 가 본 적이 있어요. → I have been to Korea.", "먹어 본 적이 없어요. → I have never tried eating it."])
            ]
        case 5:
            topics = [
                topic("Ask and request politely", "A noun plus 주세요 requests an item. A verb with 아/어 주세요 asks someone to do something for you. 좀 often softens a request. 얼마예요 asks the price. Be careful to request an action with its verb rather than using a noun-only pattern.", ["물 좀 주세요. → Please give me some water.", "천천히 말해 주세요. → Please speak slowly.", "얼마예요? → How much is it?"]),
                topic("Direction and means", "(으)로 can mark direction or a means such as transport. Use 으로 after most consonants and 로 after a vowel or ㄹ. 에 marks the destination itself; (으)로 can emphasize the direction of movement or how you travel.", ["오른쪽으로 가세요. → Go to the right.", "버스로 가요. → I go by bus.", "지하철로 가요. → I go by subway."]),
                topic("Wishes and suggestions", "고 싶어요 follows an action stem to express your own wish. (으)ㄹ까요 can suggest doing something together or ask for someone's opinion about a future action. Choose 을 after a consonant and ㄹ after a vowel, with the usual ㄹ-stem exception.", ["쉬고 싶어요. → I want to rest.", "같이 갈까요? → Shall we go together?"]),
                topic("Ability, obligation, permission", "(으)ㄹ 수 있어요/없어요 expresses ability or possibility. 아/어야 해요 expresses an obligation. 아/어도 돼요 grants permission; (으)면 안 돼요 expresses a prohibition. Permission and ability answer different questions.", ["읽을 수 있어요. → I can read.", "가야 해요. → I have to go.", "여기 앉아도 돼요. → You may sit here."])
            ]
        case 6:
            topics = [
                topic("Give a reason", "아/어서 links a reason to a result and usually avoids commands and suggestions in the following clause. (으)니까 can give a reason for a command or suggestion. Connect the stem to the ending; do not mechanically translate every English ‘because’ the same way.", ["피곤해서 쉬어요. → I rest because I am tired.", "추우니까 문을 닫으세요. → It is cold, so close the door."]),
                topic("Contrast and add information", "지만 means but/although and attaches to a stem. 은/는 can highlight a contrast between topics. 도 means also/too and can replace a topic, subject, or object particle. Pay attention to which element is being contrasted or added.", ["작지만 편해요. → It is small but comfortable.", "저도 가요. → I am going too."]),
                topic("Conditions and choices", "(으)면 introduces if/when: 으면 after a consonant and 면 after a vowel. 거나 connects alternative actions or descriptions. (이)나 connects alternative nouns: 이나 after a consonant and 나 after a vowel.", ["시간이 있으면 만나요. → Let's meet if there is time.", "책을 읽거나 쉬어요. → I read or rest.", "커피나 차 → coffee or tea"]),
                topic("Sequence and simultaneous actions", "기 전에 describes before doing something; (으)ㄴ 후에 describes after doing it. (으)면서 joins simultaneous actions and normally keeps the same subject for both actions. A time sequence and two actions happening together are different relationships.", ["먹기 전에 손을 씻어요. → Wash hands before eating.", "먹은 후에 쉬어요. → Rest after eating.", "음악을 들으면서 공부해요. → Study while listening to music."])
            ]
        case 7:
            topics = [
                topic("Respect the subject and the listener", "(으)시 honors the subject being discussed. Polite or formal sentence endings address your listener. These are separate decisions. Some verbs have special honorific forms: 계시다 for 있다, 드시다 for 먹다, and 주무시다 for 자다.", ["선생님이 오세요. → The teacher comes.", "할머니께서 주무세요. → Grandmother sleeps."]),
                topic("Describe a noun with a clause", "Present action verbs commonly use 는 before a noun. Past/completed actions use (으)ㄴ, and future or expected actions use (으)ㄹ. Descriptive verbs commonly use (으)ㄴ for present descriptions, with exceptions such as 있는/없는. The modifier goes before its noun.", ["읽는 책 → the book being read", "읽은 책 → the book that was read", "작은 집 → a small house"]),
                topic("Compare clearly", "보다 marks the comparison reference. 더 means more and 가장/제일 means most. 만큼 expresses as much as or to the extent of. Keep the reference next to 보다 so the reader knows what is being compared.", ["기차가 버스보다 빨라요. → The train is faster than the bus.", "이게 가장 좋아요. → This is the best."]),
                topic("Embed a question", "An embedded question uses an ending such as 는지 with an action verb or (으)ㄴ지 with a descriptive verb. Nouns use 인지. This clause can be followed by 알아요, 몰라요, or a related expression. A direct question ending does not simply stay unchanged inside the clause.", ["어디에 가는지 알아요? → Do you know where they are going?"]) 
            ]
        case 8:
            topics = [
                topic("Report statements", "Present action statements commonly use ㄴ/는다고, descriptive statements use 다고, and nouns use (이)라고. Past statements use 았/었다고. Follow the quotation with a reporting verb such as 해요 or 말했어요. Choose the form from the kind of predicate, not from the English wording.", ["친구가 간다고 했어요. → My friend said they are going.", "학생이라고 했어요. → They said they are a student."]),
                topic("Report questions, commands, and proposals", "냐고 reports a question. (으)라고 reports a command, and 자고 reports a proposal to do something together. 달라고 reports a request for something to be given to the requester. The reporting ending preserves the original sentence's purpose.", ["어디에 가냐고 물었어요. → They asked where I am going.", "같이 가자고 했어요. → They suggested going together."]),
                topic("Make a cautious guess", "(으)ㄹ 것 같아요 often expresses a tentative prediction. 나 봐요 and (으)ㄴ가 봐요 express an inference from evidence, with the form depending on the predicate. These are judgments, not statements that the speaker knows something for certain.", ["비가 올 것 같아요. → I think it will rain.", "바쁜가 봐요. → It looks like they are busy."]),
                topic("Regret and advice", "았/었어야 했어요 means should have done and commonly expresses an unmet past obligation. (으)ㄹ 걸 그랬어요 expresses regret about a different choice. 는 게 좋겠어요 offers advice. Keep past regret distinct from a suggestion about what to do now.", ["일찍 출발했어야 했어요. → I should have left early.", "쉬는 게 좋겠어요. → It would be good to rest."])
            ]
        case 9:
            topics = [
                topic("Concede without changing the result", "아/어도 means even if/although. 아무리 strengthens the idea of however much something happens. (으)ㄹ 뿐이에요 limits a statement to ‘only’ or ‘nothing more than.’ The first clause can be true while the main outcome stays the same.", ["비가 와도 갈 거예요. → I will go even if it rains.", "아무리 바빠도 쉬어야 해요. → However busy you are, you must rest."]),
                topic("Purpose and a resulting change", "(으)려고 introduces an intention or purpose with an action. 기 위해서 means in order to. 게 되다 describes coming to do something, often because circumstances changed. It does not always imply a deliberate decision.", ["배우려고 왔어요. → I came to learn.", "한국에서 일하게 됐어요. → I came to work in Korea."]),
                topic("Choose a cause with the right tone", "는 바람에 typically gives a cause for an unwanted or unexpected result. 덕분에 credits a helpful cause. 때문에 is a broader cause expression and can sound negative depending on context. These forms carry an attitude toward the result as well as a causal relationship.", ["늦는 바람에 버스를 놓쳤어요. → Because I was late, I missed the bus.", "친구 덕분에 끝냈어요. → I finished thanks to my friend."]),
                topic("Describe your own discovery", "더라고요 recalls something the speaker personally observed or experienced. 고 보니 describes a realization after doing something. These patterns signal how you came to know the information; they are not generic substitutes for every past-tense sentence.", ["생각보다 쉽더라고요. → I found it easier than expected.", "읽고 보니 이해됐어요. → After reading it, I understood."])
            ]
        default:
            topics = [
                topic("Formal speech and written style", "Formal polite statements end in 습니다 after a consonant and ㅂ니다 after a vowel, with ㄹ-stem changes where needed. Questions use 습니까/ㅂ니까. Written plain 다-style is a separate register often used in essays and reports. Use one suitable register consistently.", ["먹습니다. → I eat. (formal)", "갑니다. → I go. (formal)", "감사합니다. → Thank you."]),
                topic("Organize an argument", "다고 생각합니다 introduces an opinion. 에 따르면 attributes information to a source. 반면에 marks a contrast. Establish the claim, explain the reason or evidence, and connect the next sentence explicitly rather than repeating the same linking word for every relationship.", ["자료에 따르면 … → According to the data …", "반면에 … → On the other hand …"]),
                topic("Turn a clause into a noun", "기 and (으)ㅁ can turn predicates into noun-like expressions, but they are not interchangeable in every construction. Learn them in the phrases they occur in. 에 비해 compares with a reference; 에 따라 describes variation according to a factor.", ["읽기가 쉬워요. → Reading is easy.", "지역에 따라 달라요. → It varies by region."]),
                topic("Counterfactuals and unavoidable outcomes", "았/었더라면 imagines a past condition that did not happen and is often followed by a hypothetical result. (으)ㄹ 수밖에 없다 means there is no alternative but to act. 기 마련이다 describes a typical or expected tendency, rather than a rule without exceptions.", ["알았더라면 도왔을 거예요. → If I had known, I would have helped.", "기다릴 수밖에 없어요. → I have no choice but to wait."])
            ]
        }
        return topics + lessonNotes(unit)
    }

    private static func lessonNotes(_ unit: CourseUnit) -> [CourseGuideTopic] {
        unit.lessons.compactMap { lesson in
            guard let note = lesson.tipNote, !note.isEmpty else { return nil }
            let examples = lesson.cards.compactMap(\.vocabularyItem).reduce(into: [String]()) { result, item in
                let example = "\(item.surface) → \(item.contextualMeaning)"
                if result.count < 3 && !result.contains(example) { result.append(example) }
            }
            return CourseGuideTopic(title: "Lesson: \(lesson.title)", rule: note, examples: examples)
        }
    }
}

struct CourseGuideSheet: View {
    let course: CourseDefinition
    let unit: CourseUnit
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView { CourseGuideContent(course: course, unit: unit).padding(24) }
                .background(Color(.systemGroupedBackground))
                .navigationTitle("Section guide").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

struct CourseGuideContent: View {
    let course: CourseDefinition
    let unit: CourseUnit
    var compact = false
    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 24 : 32) {
            Text(unit.title).font(compact ? .title3.bold() : .title.bold())
            if course.language == "Korean" && unit.unitNumber == 1 { HangulStackingDiagram() }
            ForEach(CourseSectionGuides.topics(course: course, unit: unit)) { topic in
                VStack(alignment: .leading, spacing: 12) {
                    Text(topic.title).font(.headline)
                    Text(topic.rule).font(.body).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    ForEach(topic.examples, id: \.self) { example in
                        Text(example).font(.body.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            if course.language == "Korean" && unit.unitNumber == 1 {
                Link("More about Hangul · National Institute of Korean Language", destination: URL(string: "https://www.korean.go.kr/eng_hangeul/principle/001.html")!)
                    .font(.footnote).frame(minHeight: 44)
            }
        }
    }
}

private struct HangulStackingDiagram: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How the letters fit").font(.headline)
            HStack(alignment: .top, spacing: 12) {
                block("가", caption: "Vertical vowel") { HStack(spacing: 4) { letter("ㄱ", .teal); letter("ㅏ", .orange) } }
                block("고", caption: "Horizontal vowel") { VStack(spacing: 4) { letter("ㄱ", .teal); letter("ㅗ", .orange) } }
                block("한", caption: "With batchim") { VStack(spacing: 4) { HStack(spacing: 4) { letter("ㅎ", .teal); letter("ㅏ", .orange) }; letter("ㄴ", .indigo) } }
            }
            Text("Initial → vowel → final (if present)").font(.caption).foregroundStyle(.secondary)
        }.accessibilityElement(children: .combine)
    }
    private func letter(_ text: String, _ color: Color) -> some View {
        Text(text).font(.title2.bold()).frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(color.opacity(0.18), in: RoundedRectangle(cornerRadius: 8))
    }
    private func block<Content: View>(_ text: String, caption: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 8) {
            content().frame(height: 104)
            Text(text).font(.title2.bold())
            Text(caption).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity)
    }
}
