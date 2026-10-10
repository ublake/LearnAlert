import Foundation

// Original, authored practice content. No textbook exercise or dictionary entry is copied.
// Levels describe the material covered, not a certified proficiency outcome.
extension CourseCurriculumCatalog {
    static var expandedKoreanUnits: [CourseUnit] {
        [
            koreanUnit(2, title: "People & Particles", lessons: [
                koreanLesson("kr-2-1", number: 1, title: "Introductions", note: "은/는 marks a topic. 이에요 follows a consonant; 예요 follows a vowel.", entries: [
                    ("학생", "student"),
                    ("선생님", "teacher"),
                    ("친구", "friend"),
                    ("저는 학생이에요.", "I am a student."),
                    ("이 사람은 제 친구예요.", "This person is my friend."),
                    ("저는 한국 사람이 아니에요.", "I am not Korean.")
                ]),
                koreanLesson("kr-2-2", number: 2, title: "Subjects & Objects", note: "이/가 marks a subject; 을/를 marks an object. Select the form based on the preceding final consonant.", entries: [
                    ("물이 있어요.", "There is water."),
                    ("책이 없어요.", "There is no book."),
                    ("커피를 마셔요.", "I drink coffee."),
                    ("밥을 먹어요.", "I eat a meal."),
                    ("친구가 와요.", "A friend comes."),
                    ("한국어를 공부해요.", "I study Korean.")
                ]),
                koreanLesson("kr-2-3", number: 3, title: "Questions & Demonstratives", note: "뭐 asks what; 누구 asks who. 이/그/저 modify a following noun; 이것/그것/저것 can stand alone.", entries: [
                    ("이것은 뭐예요?", "What is this?"),
                    ("그 사람은 누구예요?", "Who is that person?"),
                    ("저것은 제 가방이에요.", "That over there is my bag."),
                    ("이 책은 재미있어요.", "This book is interesting."),
                    ("어디에 있어요?", "Where is it?"),
                    ("제 이름은 민수예요.", "My name is Minsu.")
                ]),
                koreanLesson("kr-2-4", number: 4, title: "Possession & Description", note: "제 is the polite contraction of 저의. Korean descriptions use conjugated descriptive verbs.", entries: [
                    ("제 집은 작아요.", "My house is small."),
                    ("이 가방은 커요.", "This bag is big."),
                    ("오늘은 추워요.", "It is cold today."),
                    ("날씨가 좋아요.", "The weather is good."),
                    ("이 음식은 맛있어요.", "This food is delicious."),
                    ("친구의 이름은 지수예요.", "My friend's name is Jisu.")
                ]),
            ]),
            koreanUnit(3, title: "Everyday Life", lessons: [
                koreanLesson("kr-3-1", number: 1, title: "Daily Verbs", note: "Polite present endings are 아요/어요; 하다 becomes 해요. 배우다 becomes 배워요.", entries: [
                    ("아침에 일어나요.", "I get up in the morning."),
                    ("밤에 자요.", "I sleep at night."),
                    ("음악을 들어요.", "I listen to music."),
                    ("책을 읽어요.", "I read a book."),
                    ("한국어를 배워요.", "I learn Korean."),
                    ("집에서 쉬어요.", "I rest at home.")
                ]),
                koreanLesson("kr-3-2", number: 2, title: "Locations & Movement", note: "에 marks a destination or a static location. 에서 marks where an action happens.", entries: [
                    ("학교에 가요.", "I go to school."),
                    ("집에 있어요.", "I am at home."),
                    ("도서관에서 공부해요.", "I study at the library."),
                    ("식당에서 먹어요.", "I eat at a restaurant."),
                    ("회사에 다녀요.", "I go to work."),
                    ("은행이 어디에 있어요?", "Where is the bank?")
                ]),
                koreanLesson("kr-3-3", number: 3, title: "Time & Frequency", note: "에 marks a time point, but 오늘/내일/어제 normally need no 에. 자주 means often.", entries: [
                    ("오늘 공부해요.", "I study today."),
                    ("내일 만나요.", "Let's meet tomorrow."),
                    ("세 시에 시작해요.", "It starts at three o'clock."),
                    ("매일 운동해요.", "I exercise every day."),
                    ("주말에 쉬어요.", "I rest on the weekend."),
                    ("자주 요리해요.", "I cook often.")
                ]),
                koreanLesson("kr-3-4", number: 4, title: "Numbers in Context", note: "Use native Korean numbers for hours and many counters; Sino-Korean numbers for minutes and prices. 하나/둘/셋/넷 shorten before counters.", entries: [
                    ("사과 두 개 주세요.", "Please give me two apples."),
                    ("커피 한 잔 주세요.", "Please give me one cup of coffee."),
                    ("지금 세 시예요.", "It is three o'clock now."),
                    ("오 분 기다려요.", "I wait five minutes."),
                    ("학생이 세 명 있어요.", "There are three students."),
                    ("이것은 천 원이에요.", "This is one thousand won.")
                ]),
            ]),
            koreanUnit(4, title: "Tense & Negation", lessons: [
                koreanLesson("kr-4-1", number: 1, title: "Past Experiences", note: "Past polite forms use 았어요/었어요. 하다 becomes 했어요; 가다 becomes 갔어요.", entries: [
                    ("어제 영화를 봤어요.", "I watched a movie yesterday."),
                    ("친구를 만났어요.", "I met a friend."),
                    ("점심을 먹었어요.", "I ate lunch."),
                    ("한국에 갔어요.", "I went to Korea."),
                    ("숙제를 했어요.", "I did homework."),
                    ("정말 재미있었어요.", "It was really interesting.")
                ]),
                koreanLesson("kr-4-2", number: 2, title: "Plans & Intentions", note: "Verb stem + (으)ㄹ 거예요 expresses a plan or a prediction. 먹다 becomes 먹을 거예요; 가다 becomes 갈 거예요.", entries: [
                    ("내일 갈 거예요.", "I will go tomorrow."),
                    ("저녁에 공부할 거예요.", "I will study in the evening."),
                    ("집에서 쉴 거예요.", "I will rest at home."),
                    ("친구에게 전화할 거예요.", "I will call a friend."),
                    ("주말에 여행할 거예요.", "I will travel on the weekend."),
                    ("곧 비가 올 거예요.", "It will rain soon.")
                ]),
                koreanLesson("kr-4-3", number: 3, title: "Not & Cannot", note: "안 or 지 않다 expresses negation. 못 or 지 못하다 expresses inability. 없다 means not exist; 아니다 means not be.", entries: [
                    ("오늘 안 가요.", "I am not going today."),
                    ("고기를 먹지 않아요.", "I do not eat meat."),
                    ("수영을 못 해요.", "I cannot swim."),
                    ("시간이 없어요.", "I have no time."),
                    ("학생이 아니에요.", "I am not a student."),
                    ("어제 잠을 자지 못했어요.", "I could not sleep yesterday.")
                ]),
                koreanLesson("kr-4-4", number: 4, title: "Ongoing Actions & Experience", note: "고 있어요 describes an ongoing action. 아/어 본 적이 있어요 describes having had an experience.", entries: [
                    ("지금 공부하고 있어요.", "I am studying now."),
                    ("친구를 기다리고 있어요.", "I am waiting for a friend."),
                    ("비가 오고 있어요.", "It is raining."),
                    ("한국에 가 본 적이 있어요.", "I have been to Korea before."),
                    ("김치를 먹어 봤어요.", "I have tried kimchi."),
                    ("그 영화를 본 적이 없어요.", "I have never seen that movie.")
                ]),
            ]),
            koreanUnit(5, title: "Requests & Real Conversations", lessons: [
                koreanLesson("kr-5-1", number: 1, title: "Ordering & Shopping", note: "주세요 makes a polite request. 얼마 asks price. 좀 can soften a request rather than literally meaning a little.", entries: [
                    ("메뉴 좀 주세요.", "Please give me a menu."),
                    ("물 좀 주세요.", "Please give me some water."),
                    ("이거 얼마예요?", "How much is this?"),
                    ("좀 더 작은 거 있어요?", "Do you have a smaller one?"),
                    ("카드로 계산할게요.", "I will pay by card."),
                    ("포장해 주세요.", "Please pack it to go.")
                ]),
                koreanLesson("kr-5-2", number: 2, title: "Directions & Transport", note: "으로/로 marks a direction or means. After ㄹ or a vowel use 로; otherwise use 으로.", entries: [
                    ("오른쪽으로 가세요.", "Please go to the right."),
                    ("왼쪽으로 도세요.", "Please turn left."),
                    ("지하철로 가요.", "I go by subway."),
                    ("버스를 타요.", "I take a bus."),
                    ("다음 역에서 내려요.", "I get off at the next station."),
                    ("여기에서 얼마나 걸려요?", "How long does it take from here?")
                ]),
                koreanLesson("kr-5-3", number: 3, title: "Invitations & Wishes", note: "고 싶어요 expresses a wish. (으)ㄹ까요 proposes doing something or asks for an opinion. 같이 means together.", entries: [
                    ("한국에 가고 싶어요.", "I want to go to Korea."),
                    ("같이 밥 먹을까요?", "Shall we eat together?"),
                    ("커피 마실까요?", "Shall we drink coffee?"),
                    ("다시 만나고 싶어요.", "I want to meet again."),
                    ("잠깐 쉴까요?", "Shall we rest for a moment?"),
                    ("한국어를 잘하고 싶어요.", "I want to be good at Korean.")
                ]),
                koreanLesson("kr-5-4", number: 4, title: "Ability & Obligation", note: "(으)ㄹ 수 있다 expresses ability; 아/어야 하다 expresses obligation. 아/어도 되다 asks permission.", entries: [
                    ("한국어를 읽을 수 있어요.", "I can read Korean."),
                    ("오늘 일해야 해요.", "I have to work today."),
                    ("여기 앉아도 돼요?", "May I sit here?"),
                    ("사진을 찍어도 돼요?", "May I take a photo?"),
                    ("늦으면 안 돼요.", "You must not be late."),
                    ("지금 가야 해요.", "I have to go now.")
                ]),
            ]),
            koreanUnit(6, title: "Linking Ideas", lessons: [
                koreanLesson("kr-6-1", number: 1, title: "Reasons & Results", note: "아/어서 links a reason and result; (으)니까 also supplies a reason and can precede commands or suggestions.", entries: [
                    ("배가 고파서 먹었어요.", "I ate because I was hungry."),
                    ("비가 와서 집에 있었어요.", "I stayed home because it rained."),
                    ("피곤해서 일찍 잤어요.", "I went to bed early because I was tired."),
                    ("시간이 없으니까 빨리 가세요.", "Please go quickly because there is no time."),
                    ("추우니까 창문을 닫으세요.", "Please close the window because it is cold."),
                    ("길이 막혀서 늦었어요.", "I was late because traffic was heavy.")
                ]),
                koreanLesson("kr-6-2", number: 2, title: "Contrast & Addition", note: "지만 directly contrasts clauses. 은/는 can contrast topics. 도 means also or too.", entries: [
                    ("비싸지만 맛있어요.", "It is expensive but delicious."),
                    ("작지만 편해요.", "It is small but comfortable."),
                    ("저도 학생이에요.", "I am a student too."),
                    ("커피는 마시지만 차는 안 마셔요.", "I drink coffee but not tea."),
                    ("어제는 추웠지만 오늘은 따뜻해요.", "It was cold yesterday but warm today."),
                    ("공부하고 운동해요.", "I study and exercise.")
                ]),
                koreanLesson("kr-6-3", number: 3, title: "Conditions & Choices", note: "(으)면 means if or when. 거나 links alternative actions. (이)나 links alternative nouns.", entries: [
                    ("시간이 있으면 만나요.", "Let's meet if we have time."),
                    ("비가 오면 집에 있을 거예요.", "I will stay home if it rains."),
                    ("피곤하면 쉬세요.", "Please rest if you are tired."),
                    ("주말에 읽거나 쉬어요.", "I read or rest on the weekend."),
                    ("커피나 차를 마셔요.", "I drink coffee or tea."),
                    ("모르면 물어보세요.", "Please ask if you do not know.")
                ]),
                koreanLesson("kr-6-4", number: 4, title: "Sequence & Simultaneity", note: "기 전에 means before doing; (으)ㄴ 후에 means after doing; (으)면서 links simultaneous actions by the same subject.", entries: [
                    ("자기 전에 책을 읽어요.", "I read a book before sleeping."),
                    ("밥을 먹은 후에 공부해요.", "I study after eating."),
                    ("음악을 들으면서 걸어요.", "I walk while listening to music."),
                    ("집에 가서 쉬었어요.", "I went home and rested."),
                    ("운동하기 전에 물을 마셔요.", "I drink water before exercising."),
                    ("수업이 끝난 후에 만나요.", "Let's meet after class ends.")
                ]),
            ]),
            koreanUnit(7, title: "Respect & Natural Description", lessons: [
                koreanLesson("kr-7-1", number: 1, title: "Honorifics", note: "Honorific (으)시 raises the subject; 계시다 replaces 있다 and 드시다 replaces 먹다 for respected people. Politeness to the listener is a separate choice.", entries: [
                    ("선생님이 오세요.", "The teacher is coming."),
                    ("어머니는 집에 계세요.", "My mother is at home."),
                    ("할아버지가 식사하세요.", "My grandfather is having a meal."),
                    ("선생님께서 말씀하셨어요.", "The teacher spoke."),
                    ("아버지가 주무세요.", "My father is sleeping."),
                    ("어머니께 선물을 드렸어요.", "I gave a gift to my mother.")
                ]),
                koreanLesson("kr-7-2", number: 2, title: "Modifying Nouns", note: "Action verbs use 는 for present modifiers and (으)ㄴ for past modifiers; descriptive verbs commonly use (으)ㄴ.", entries: [
                    ("제가 읽는 책이에요.", "It is a book that I am reading."),
                    ("어제 만난 사람이에요.", "It is a person I met yesterday."),
                    ("내일 갈 곳이에요.", "It is a place I will go tomorrow."),
                    ("맛있는 음식을 좋아해요.", "I like delicious food."),
                    ("작은 가방을 샀어요.", "I bought a small bag."),
                    ("한국어를 배우는 학생이에요.", "It is a student who is learning Korean.")
                ]),
                koreanLesson("kr-7-3", number: 3, title: "Comparison & Degree", note: "보다 marks a comparison reference; 더 means more, 가장/제일 means most. 만큼 expresses an equal degree.", entries: [
                    ("오늘은 어제보다 더 추워요.", "Today is colder than yesterday."),
                    ("이게 제일 좋아요.", "This one is the best."),
                    ("생각보다 어려워요.", "It is harder than I thought."),
                    ("친구만큼 빨리 달려요.", "I run as fast as my friend."),
                    ("조금 더 천천히 말해 주세요.", "Please speak a little more slowly."),
                    ("한국어가 점점 재미있어져요.", "Korean is becoming more and more interesting.")
                ]),
                koreanLesson("kr-7-4", number: 4, title: "Indirect Questions", note: "는지/(으)ㄴ지 introduces an embedded question; whether-questions can use 는지. The ending depends on tense and predicate type.", entries: [
                    ("어디에 사는지 알아요?", "Do you know where they live?"),
                    ("언제 시작하는지 몰라요.", "I do not know when it starts."),
                    ("얼마인지 물어봤어요.", "I asked how much it is."),
                    ("왜 늦었는지 설명해 주세요.", "Please explain why you were late."),
                    ("누가 오는지 알아요?", "Do you know who is coming?"),
                    ("이게 맞는지 확인해 주세요.", "Please check whether this is right.")
                ]),
            ]),
            koreanUnit(8, title: "Reported Speech & Nuance", lessons: [
                koreanLesson("kr-8-1", number: 1, title: "Reporting Statements", note: "Plain statement quotation uses 다고 하다; nouns use (이)라고 하다. 했다고 reports a past action.", entries: [
                    ("친구가 내일 온다고 했어요.", "My friend said they are coming tomorrow."),
                    ("이 음식이 맛있다고 들었어요.", "I heard this food is delicious."),
                    ("그 사람은 학생이라고 해요.", "They say that person is a student."),
                    ("민수가 숙제를 했다고 했어요.", "Minsu said he did the homework."),
                    ("오늘 바쁘다고 했어요.", "They said they are busy today."),
                    ("내일 비가 올 거라고 해요.", "They say it will rain tomorrow.")
                ]),
                koreanLesson("kr-8-2", number: 2, title: "Reporting Questions & Requests", note: "냐고 reports questions; (으)라고 reports commands; 자고 reports suggestions. 달라고 asks another person to give something to the requester.", entries: [
                    ("친구가 어디에 가냐고 물었어요.", "My friend asked where I was going."),
                    ("선생님이 책을 읽으라고 하셨어요.", "The teacher told us to read the book."),
                    ("친구가 같이 가자고 했어요.", "My friend suggested going together."),
                    ("물을 달라고 했어요.", "I asked them to give me water."),
                    ("언제 오냐고 물어봤어요.", "I asked when they were coming."),
                    ("잠깐 기다리라고 했어요.", "They told me to wait a moment.")
                ]),
                koreanLesson("kr-8-3", number: 3, title: "Guessing & Evidence", note: "(으)ㄹ 것 같아요 expresses a guess. 나 봐요 suggests an inference from evidence; descriptive verbs can use (으)ㄴ가 봐요.", entries: [
                    ("비가 올 것 같아요.", "I think it will rain."),
                    ("좀 어려울 것 같아요.", "I think it will be a little difficult."),
                    ("밖에 비가 오나 봐요.", "It seems to be raining outside."),
                    ("많이 바쁜가 봐요.", "They seem to be very busy."),
                    ("그 사람이 이미 간 것 같아요.", "I think that person has already left."),
                    ("이게 더 좋을 것 같아요.", "I think this one will be better.")
                ]),
                koreanLesson("kr-8-4", number: 4, title: "Regret & Advice", note: "았/었어야 했다 expresses an unfulfilled obligation. (으)ㄹ 걸 그랬다 expresses regret. 는 게 좋겠다 offers advice.", entries: [
                    ("더 일찍 출발했어야 했어요.", "I should have left earlier."),
                    ("우산을 가져올 걸 그랬어요.", "I wish I had brought an umbrella."),
                    ("좀 쉬는 게 좋겠어요.", "It would be good to rest a little."),
                    ("미리 예약할 걸 그랬어요.", "I wish I had booked in advance."),
                    ("어제 공부했어야 했어요.", "I should have studied yesterday."),
                    ("병원에 가 보는 게 좋겠어요.", "It would be good to try going to a hospital.")
                ]),
            ]),
            koreanUnit(9, title: "Advanced Connections", lessons: [
                koreanLesson("kr-9-1", number: 1, title: "Concession & Limitations", note: "아/어도 means even if; (으)ㄹ 뿐이다 means only or merely. 아무리 ... 아/어도 means no matter how much.", entries: [
                    ("바빠도 운동해요.", "I exercise even when I am busy."),
                    ("비가 와도 갈 거예요.", "I will go even if it rains."),
                    ("아무리 읽어도 이해가 안 돼요.", "No matter how much I read, I cannot understand it."),
                    ("저는 도와주고 싶었을 뿐이에요.", "I only wanted to help."),
                    ("늦었는데도 기다려 줬어요.", "They waited for me even though I was late."),
                    ("노력해도 쉽지 않아요.", "It is not easy even if I try.")
                ]),
                koreanLesson("kr-9-2", number: 2, title: "Purpose & Change", note: "(으)려고 marks intention; 기 위해서 marks purpose; 게 되다 expresses coming to do something through circumstances.", entries: [
                    ("공부하려고 도서관에 갔어요.", "I went to the library to study."),
                    ("건강을 위해서 운동해요.", "I exercise for my health."),
                    ("한국에서 일하게 됐어요.", "I came to work in Korea."),
                    ("잊지 않으려고 적었어요.", "I wrote it down so I would not forget."),
                    ("친구를 만나기 위해서 왔어요.", "I came to meet a friend."),
                    ("한국어에 관심을 갖게 됐어요.", "I came to have an interest in Korean.")
                ]),
                koreanLesson("kr-9-3", number: 3, title: "Cause & Consequence", note: "는 바람에 commonly introduces an unexpected cause with a negative result. 덕분에 attributes a positive result; 때문에 can be neutral or negative.", entries: [
                    ("버스를 놓치는 바람에 늦었어요.", "I was late because I missed the bus."),
                    ("친구 덕분에 일을 끝냈어요.", "I finished the work thanks to my friend."),
                    ("비 때문에 경기가 취소됐어요.", "The game was canceled because of the rain."),
                    ("늦잠을 자는 바람에 수업에 못 갔어요.", "I could not go to class because I overslept."),
                    ("선생님 덕분에 많이 배웠어요.", "I learned a lot thanks to the teacher."),
                    ("소음 때문에 잠을 못 잤어요.", "I could not sleep because of the noise.")
                ]),
                koreanLesson("kr-9-4", number: 4, title: "Discoveries & Recollection", note: "더라고요 reports something personally experienced or noticed; 고 보니 introduces a realization after an action.", entries: [
                    ("직접 가 보니 생각보다 멀었어요.", "After going there myself, I realized it was farther than I thought."),
                    ("먹어 보니 정말 맛있더라고요.", "When I tried it, I found it really delicious."),
                    ("알고 보니 같은 학교에 다녔어요.", "It turned out we had attended the same school."),
                    ("그곳은 사람이 많더라고요.", "I noticed that place was crowded."),
                    ("다시 읽어 보니 이해가 됐어요.", "After reading it again, I understood it."),
                    ("끝내고 보니 시간이 많이 지났어요.", "After finishing, I realized a lot of time had passed.")
                ]),
            ]),
            koreanUnit(10, title: "Formal Korean & Discussion", lessons: [
                koreanLesson("kr-10-1", number: 1, title: "Formal Register", note: "Formal polite statements commonly end in 습니다/ㅂ니다; questions in 습니까/ㅂ니까. Written exposition often uses plain 다 endings.", entries: [
                    ("회의를 시작하겠습니다.", "I will begin the meeting."),
                    ("참석해 주셔서 감사합니다.", "Thank you for attending."),
                    ("질문이 있으십니까?", "Do you have any questions?"),
                    ("자료를 확인해 주시기 바랍니다.", "Please check the materials."),
                    ("이번 조사는 중요합니다.", "This survey is important."),
                    ("자세한 내용은 다음과 같습니다.", "The details are as follows.")
                ]),
                koreanLesson("kr-10-2", number: 2, title: "Opinions & Evidence", note: "다고 생각하다 states an opinion. 에 따르면 attributes information to a source. 반면에 contrasts aspects.", entries: [
                    ("저는 이 방법이 효과적이라고 생각합니다.", "I think this method is effective."),
                    ("조사에 따르면 관심이 높아졌습니다.", "According to the survey, interest has increased."),
                    ("장점이 있는 반면에 단점도 있습니다.", "There are advantages, while there are also disadvantages."),
                    ("제 의견은 조금 다릅니다.", "My opinion is a little different."),
                    ("이 문제에 대해 논의하고 싶습니다.", "I would like to discuss this issue."),
                    ("그 주장에 동의하기 어렵습니다.", "It is difficult to agree with that claim.")
                ]),
                koreanLesson("kr-10-3", number: 3, title: "Nominalization & Precision", note: "기 and (으)ㅁ nominalize predicates; whether they are interchangeable depends on the expression. 에 비해 introduces a comparison; 에 따라 means depending on or according to.", entries: [
                    ("한국어를 배우기가 쉽지 않습니다.", "Learning Korean is not easy."),
                    ("참여하기로 결정했습니다.", "We decided to participate."),
                    ("상황에 따라 결과가 달라집니다.", "The result varies depending on the situation."),
                    ("작년에 비해 비용이 줄었습니다.", "Costs have decreased compared with last year."),
                    ("사실임을 확인했습니다.", "We confirmed that it is a fact."),
                    ("계획을 변경할 필요가 있습니다.", "There is a need to change the plan.")
                ]),
                koreanLesson("kr-10-4", number: 4, title: "Hypotheticals & Evaluation", note: "았/었더라면 introduces a contrary-to-fact past condition. (으)ㄹ 수밖에 없다 expresses no alternative. 기 마련이다 expresses a typical tendency.", entries: [
                    ("미리 알았더라면 준비했을 텐데요.", "If I had known in advance, I would have prepared."),
                    ("시간이 없어서 취소할 수밖에 없었습니다.", "We had no choice but to cancel because there was no time."),
                    ("처음에는 실수하기 마련입니다.", "It is natural to make mistakes at first."),
                    ("연습할수록 자신감이 생깁니다.", "The more I practice, the more confident I become."),
                    ("다시 기회가 주어진다면 도전하겠습니다.", "If I am given another opportunity, I will try."),
                    ("결과뿐만 아니라 과정도 중요합니다.", "The process is important as well as the result.")
                ]),
            ]),
        ]
    }

    private static func koreanLesson(_ id: String, number: Int, title: String, note: String,
                                     entries: [(String, String)]) -> CourseLesson {
        let cards = variedKoreanCards(id: id, title: title, note: note, entries: entries)
        return CourseLesson(id: id, lessonNumber: number, title: title, subtitle: "",
            estimatedMinutes: 15, tipNote: note, cards: cards)
    }

    private static func koreanUnit(_ number: Int, title: String, lessons: [CourseLesson]) -> CourseUnit {
        let questions = koreanTransferQuestions(number)
        return CourseUnit(id: "kr-unit-\(number)", unitNumber: number,
            title: "Unit \(number): \(title)", subtitle: "", colorHex: "#3E74C4", badgeIcon: "book.closed.fill",
            lessons: lessons, checkpointQuiz: CourseCheckpointQuiz(id: "kr-checkpoint-\(number)",
                title: "\(title) Checkpoint", summary: "", questions: questions, keyConcepts: lessons.map(\.title)))
    }
}

// Checkpoints use new examples covering each section’s objectives.
private extension CourseCurriculumCatalog {
    static func koreanTransferQuestions(_ number: Int) -> [CourseLessonCard] {
        switch number {
        case 2: return [
            CourseLessonCard(id: "kr-transfer-2-1", question: "Complete the noun ending: 저는 의사___요.",
                options: ["예", "이에", "을", "가"], correctAnswer: "예", cardType: "multipleChoice", conceptTag: "Section 2", explanation: "예"),
            CourseLessonCard(id: "kr-transfer-2-2", question: "Which sentence means “There is a chair”?",
                options: ["의자가 있어요.", "의자를 마셔요.", "의자가 없어요.", "의자는 아니에요."], correctAnswer: "의자가 있어요.", cardType: "multipleChoice", conceptTag: "Section 2", explanation: "의자가 있어요."),
            CourseLessonCard(id: "kr-transfer-2-3", question: "Complete the object particle: 사과___ 먹어요.",
                options: ["를", "가", "는", "에"], correctAnswer: "를", cardType: "fillBlank", conceptTag: "Section 2", explanation: "를"),
            CourseLessonCard(id: "kr-transfer-2-4", question: "Write in Korean: This is my bag.",
                options: ["이것은 제 가방이에요.", "이것은 제 책이에요.", "저것은 제 가방이에요.", "이것은 제 가방이 아니에요."], correctAnswer: "이것은 제 가방이에요.", cardType: "fillBlank", conceptTag: "Section 2", explanation: "이것은 제 가방이에요."),
            CourseLessonCard(id: "kr-transfer-2-5", question: "In “제가 차를 마셔요,” what does 가 mark?",
                options: ["The subject", "The object", "A destination", "Possession"], correctAnswer: "The subject", cardType: "multipleChoice", conceptTag: "Section 2", explanation: "The subject"),
        ]
        case 3: return [
            CourseLessonCard(id: "kr-transfer-3-1", question: "Complete the place-of-action particle: 도서관___ 책을 읽어요.",
                options: ["에서", "에", "를", "의"], correctAnswer: "에서", cardType: "fillBlank", conceptTag: "Section 3", explanation: "에서"),
            CourseLessonCard(id: "kr-transfer-3-2", question: "Choose the sentence meaning “I go to the station.”",
                options: ["역에 가요.", "역에서 자요.", "역이 없어요.", "역은 먹어요."], correctAnswer: "역에 가요.", cardType: "multipleChoice", conceptTag: "Section 3", explanation: "역에 가요."),
            CourseLessonCard(id: "kr-transfer-3-3", question: "What does “책 세 권” mean?",
                options: ["Three books", "Three people", "Three cups", "Three hours"], correctAnswer: "Three books", cardType: "multipleChoice", conceptTag: "Section 3", explanation: "Three books"),
            CourseLessonCard(id: "kr-transfer-3-4", question: "Complete the verb: 저는 매일 운동을 ___.",
                options: ["해요", "가요", "먹어요", "자요"], correctAnswer: "해요", cardType: "fillBlank", conceptTag: "Section 3", explanation: "해요"),
            CourseLessonCard(id: "kr-transfer-3-5", question: "Which particle marks the place where someone is located?",
                options: ["에", "에서", "를", "도"], correctAnswer: "에", cardType: "multipleChoice", conceptTag: "Section 3", explanation: "에"),
        ]
        case 4: return [
            CourseLessonCard(id: "kr-transfer-4-1", question: "Complete the past tense: 어제 영화를 ___ (보다).",
                options: ["봤어요", "봐요", "볼 거예요", "보세요"], correctAnswer: "봤어요", cardType: "fillBlank", conceptTag: "Section 4", explanation: "봤어요"),
            CourseLessonCard(id: "kr-transfer-4-2", question: "Choose the sentence meaning “I cannot swim.”",
                options: ["수영을 못 해요.", "수영을 안 해요.", "수영을 했어요.", "수영을 하고 있어요."], correctAnswer: "수영을 못 해요.", cardType: "multipleChoice", conceptTag: "Section 4", explanation: "수영을 못 해요."),
            CourseLessonCard(id: "kr-transfer-4-3", question: "What does “지금 요리하고 있어요” describe?",
                options: ["Cooking in progress now", "A past cooking experience", "A cooking prohibition", "A plan for next year"], correctAnswer: "Cooking in progress now", cardType: "multipleChoice", conceptTag: "Section 4", explanation: "Cooking in progress now"),
            CourseLessonCard(id: "kr-transfer-4-4", question: "Complete the planned future: 내일 친구를 만날 ___.",
                options: ["거예요", "었어요", "고 있어요", "지 않아요"], correctAnswer: "거예요", cardType: "fillBlank", conceptTag: "Section 4", explanation: "거예요"),
            CourseLessonCard(id: "kr-transfer-4-5", question: "Choose the sentence meaning “I have tried Korean food.”",
                options: ["한국 음식을 먹어 본 적이 있어요.", "한국 음식을 먹어야 해요.", "한국 음식을 못 먹어요.", "한국 음식을 안 먹어요."], correctAnswer: "한국 음식을 먹어 본 적이 있어요.", cardType: "multipleChoice", conceptTag: "Section 4", explanation: "한국 음식을 먹어 본 적이 있어요."),
        ]
        case 5: return [
            CourseLessonCard(id: "kr-transfer-5-1", question: "At a café, which sentence politely requests two coffees?",
                options: ["커피 두 잔 주세요.", "커피 두 명 주세요.", "커피 두 권 주세요.", "커피 두 개가 아니에요."], correctAnswer: "커피 두 잔 주세요.", cardType: "multipleChoice", conceptTag: "Section 5", explanation: "커피 두 잔 주세요."),
            CourseLessonCard(id: "kr-transfer-5-2", question: "Complete the transport particle: 지하철___ 가요.",
                options: ["로", "에서", "를", "의"], correctAnswer: "로", cardType: "fillBlank", conceptTag: "Section 5", explanation: "로"),
            CourseLessonCard(id: "kr-transfer-5-3", question: "What does “창문을 열어도 돼요?” ask?",
                options: ["Permission to open the window", "An order to close the window", "Whether the window is broken", "The price of a window"], correctAnswer: "Permission to open the window", cardType: "multipleChoice", conceptTag: "Section 5", explanation: "Permission to open the window"),
            CourseLessonCard(id: "kr-transfer-5-4", question: "Complete the obligation: 내일 일찍 일어나___ 해요.",
                options: ["야", "고", "면", "지만"], correctAnswer: "야", cardType: "fillBlank", conceptTag: "Section 5", explanation: "야"),
            CourseLessonCard(id: "kr-transfer-5-5", question: "Which ending proposes an activity together?",
                options: ["(으)ㄹ까요?", "았/었어요", "지 못해요", "(으)ㄹ 수 없어요"], correctAnswer: "(으)ㄹ까요?", cardType: "multipleChoice", conceptTag: "Section 5", explanation: "(으)ㄹ까요?"),
        ]
        case 6: return [
            CourseLessonCard(id: "kr-transfer-6-1", question: "Complete the reason: 길이 막히___ 늦었어요.",
                options: ["어서", "지만", "거나", "고도"], correctAnswer: "어서", cardType: "fillBlank", conceptTag: "Section 6", explanation: "어서"),
            CourseLessonCard(id: "kr-transfer-6-2", question: "Choose a conditional meaning “If it is cold, close the window.”",
                options: ["추우면 창문을 닫으세요.", "춥지만 창문을 닫으세요.", "추워도 창문을 닫으세요.", "추운 후에 창문을 닫으세요."], correctAnswer: "추우면 창문을 닫으세요.", cardType: "multipleChoice", conceptTag: "Section 6", explanation: "추우면 창문을 닫으세요."),
            CourseLessonCard(id: "kr-transfer-6-3", question: "What relation does 지만 express?",
                options: ["Contrast", "A required action", "Indirect speech", "A final consonant"], correctAnswer: "Contrast", cardType: "multipleChoice", conceptTag: "Section 6", explanation: "Contrast"),
            CourseLessonCard(id: "kr-transfer-6-4", question: "Complete the sequence: 밥을 먹___ 이를 닦아요.",
                options: ["고", "지만", "거나", "으러"], correctAnswer: "고", cardType: "fillBlank", conceptTag: "Section 6", explanation: "고"),
            CourseLessonCard(id: "kr-transfer-6-5", question: "“책을 읽거나 음악을 들어요” describes what?",
                options: ["A choice between two activities", "Two simultaneous obligations", "A reason and result", "A prohibited activity"], correctAnswer: "A choice between two activities", cardType: "multipleChoice", conceptTag: "Section 6", explanation: "A choice between two activities"),
        ]
        case 7: return [
            CourseLessonCard(id: "kr-transfer-7-1", question: "Choose the noun phrase meaning “the book I read yesterday.”",
                options: ["어제 읽은 책", "어제 읽을 책", "내일 읽은 책", "지금 읽는 사람"], correctAnswer: "어제 읽은 책", cardType: "multipleChoice", conceptTag: "Section 7", explanation: "어제 읽은 책"),
            CourseLessonCard(id: "kr-transfer-7-2", question: "Complete the before-action form: 자기 ___ 이를 닦아요.",
                options: ["전에", "후에", "때문에", "대신에"], correctAnswer: "전에", cardType: "fillBlank", conceptTag: "Section 7", explanation: "전에"),
            CourseLessonCard(id: "kr-transfer-7-3", question: "What does “기다리는 동안” mean?",
                options: ["While waiting", "Before arriving", "Because it is late", "After leaving"], correctAnswer: "While waiting", cardType: "multipleChoice", conceptTag: "Section 7", explanation: "While waiting"),
            CourseLessonCard(id: "kr-transfer-7-4", question: "Choose the meaning of “집에 도착한 후에 전화했어요.”",
                options: ["I called after arriving home.", "I called before arriving home.", "I called instead of going home.", "I will call tomorrow."], correctAnswer: "I called after arriving home.", cardType: "multipleChoice", conceptTag: "Section 7", explanation: "I called after arriving home."),
            CourseLessonCard(id: "kr-transfer-7-5", question: "Complete the future noun modifier: 내일 만___ 사람 (만나다).",
                options: ["날", "난", "나는", "났던"], correctAnswer: "날", cardType: "fillBlank", conceptTag: "Section 7", explanation: "날"),
        ]
        case 8: return [
            CourseLessonCard(id: "kr-transfer-8-1", question: "Choose the respectful sentence for a teacher eating.",
                options: ["선생님이 식사를 하세요.", "선생님이 식사를 해.", "선생님이 밥을 먹니?", "선생님이 밥을 먹자."], correctAnswer: "선생님이 식사를 하세요.", cardType: "multipleChoice", conceptTag: "Section 8", explanation: "선생님이 식사를 하세요."),
            CourseLessonCard(id: "kr-transfer-8-2", question: "Complete a formal polite ending: 감사합니다. 만나서 반갑___.",
                options: ["습니다", "어요", "니", "자"], correctAnswer: "습니다", cardType: "fillBlank", conceptTag: "Section 8", explanation: "습니다"),
            CourseLessonCard(id: "kr-transfer-8-3", question: "Which verb is the respectful alternative to 먹다?",
                options: ["드시다", "자다", "듣다", "만나다"], correctAnswer: "드시다", cardType: "multipleChoice", conceptTag: "Section 8", explanation: "드시다"),
            CourseLessonCard(id: "kr-transfer-8-4", question: "A friend says “내일 바빠요.” Choose the indirect statement.",
                options: ["친구가 내일 바쁘다고 했어요.", "친구가 내일 바쁘냐고 했어요.", "친구가 내일 바쁘라고 했어요.", "친구가 내일 바쁘자고 했어요."], correctAnswer: "친구가 내일 바쁘다고 했어요.", cardType: "multipleChoice", conceptTag: "Section 8", explanation: "친구가 내일 바쁘다고 했어요."),
            CourseLessonCard(id: "kr-transfer-8-5", question: "Which form reports a suggestion to go together?",
                options: ["같이 가자고 했어요.", "같이 가라고 했어요.", "같이 가냐고 했어요.", "같이 간다고 했어요."], correctAnswer: "같이 가자고 했어요.", cardType: "multipleChoice", conceptTag: "Section 8", explanation: "같이 가자고 했어요."),
        ]
        case 9: return [
            CourseLessonCard(id: "kr-transfer-9-1", question: "What does “비가 올 것 같아요” express?",
                options: ["A prediction that it may rain", "A command to make rain", "A certainty that rain already stopped", "A request for an umbrella"], correctAnswer: "A prediction that it may rain", cardType: "multipleChoice", conceptTag: "Section 9", explanation: "A prediction that it may rain"),
            CourseLessonCard(id: "kr-transfer-9-2", question: "Complete the purpose: 한국어를 배우___ 한국에 왔어요.",
                options: ["려고", "지만", "거나", "면서"], correctAnswer: "려고", cardType: "fillBlank", conceptTag: "Section 9", explanation: "려고"),
            CourseLessonCard(id: "kr-transfer-9-3", question: "Choose the sentence meaning “It became easier to read.”",
                options: ["읽기가 쉬워졌어요.", "읽기가 어려워졌어요.", "읽지 못했어요.", "읽어야 해요."], correctAnswer: "읽기가 쉬워졌어요.", cardType: "multipleChoice", conceptTag: "Section 9", explanation: "읽기가 쉬워졌어요."),
            CourseLessonCard(id: "kr-transfer-9-4", question: "What does “말하려던 참이었어요” mean?",
                options: ["I was just about to speak.", "I had never spoken.", "I was told not to speak.", "I must speak every day."], correctAnswer: "I was just about to speak.", cardType: "multipleChoice", conceptTag: "Section 9", explanation: "I was just about to speak."),
            CourseLessonCard(id: "kr-transfer-9-5", question: "Complete the result of circumstances: 한국에서 일하___ 되었어요.",
                options: ["게", "려고", "지만", "거나"], correctAnswer: "게", cardType: "fillBlank", conceptTag: "Section 9", explanation: "게"),
        ]
        case 10: return [
            CourseLessonCard(id: "kr-transfer-10-1", question: "Choose the meaning of “알았더라면 알려 줬을 텐데요.”",
                options: ["If I had known, I would have told you.", "If I know tomorrow, I will ask.", "I must tell you even though I do not know.", "I have already told everyone."], correctAnswer: "If I had known, I would have told you.", cardType: "multipleChoice", conceptTag: "Section 10", explanation: "If I had known, I would have told you."),
            CourseLessonCard(id: "kr-transfer-10-2", question: "Complete the typical tendency: 누구나 실수하기 ___.",
                options: ["마련이다", "뿐이다", "적이 없다", "중이다"], correctAnswer: "마련이다", cardType: "fillBlank", conceptTag: "Section 10", explanation: "마련이다"),
            CourseLessonCard(id: "kr-transfer-10-3", question: "What does “반면에” signal in an argument?",
                options: ["A contrasting side", "A completed command", "A quoted suggestion", "A past regret"], correctAnswer: "A contrasting side", cardType: "multipleChoice", conceptTag: "Section 10", explanation: "A contrasting side"),
            CourseLessonCard(id: "kr-transfer-10-4", question: "Complete “There is no choice but to wait”: 기다릴 수___ 없다.",
                options: ["밖에", "만", "조차", "마다"], correctAnswer: "밖에", cardType: "fillBlank", conceptTag: "Section 10", explanation: "밖에"),
            CourseLessonCard(id: "kr-transfer-10-5", question: "Which connective adds another point in formal writing?",
                options: ["또한", "하지만", "반면에", "그럼에도 불구하고"], correctAnswer: "또한", cardType: "multipleChoice", conceptTag: "Section 10", explanation: "또한"),
        ]
        default: return []
        }
    }
}


extension CourseCurriculumCatalog {
    /// Stable, authored picture exercises are appended without changing existing card IDs.
    static func addingVisualVocabulary(to course: CourseDefinition) -> CourseDefinition {
        let groups: [[(String, String, String, String)]] = [
            [("apple", "사과", "manzana", "apple"), ("banana", "바나나", "plátano", "banana"),
             ("orange", "오렌지", "naranja", "orange"), ("grapes", "포도", "uvas", "grapes")],
            [("cat", "고양이", "gato", "cat"), ("dog", "개", "perro", "dog"),
             ("rabbit", "토끼", "conejo", "rabbit"), ("bird", "새", "pájaro", "bird")],
            [("coffee", "커피", "café", "coffee"), ("water", "물", "agua", "water"),
             ("rice", "밥", "arroz", "cooked rice"), ("milk", "우유", "leche", "milk")],
            [("book", "책", "libro", "book"), ("bag", "가방", "mochila", "bag / backpack"),
             ("chair", "의자", "silla", "chair"), ("clock", "시계", "reloj", "clock")]
        ]
        let korean = course.language == "Korean"
        let targetUnit = korean ? "kr-unit-2" : "es-unit-1"
        let units = course.units.map { unit in
            guard unit.id == targetUnit else { return unit }
            let lessons = unit.lessons.enumerated().map { index, lesson in
                guard groups.indices.contains(index) else { return lesson }
                let group = groups[index]
                let words = group.map { korean ? $0.1 : $0.2 }
                let names = group.map { $0.3 }
                let images = group.map { "course-vocab-" + $0.0 }
                let visualCards = group.enumerated().flatMap { offset, entry -> [CourseLessonCard] in
                    let word = korean ? entry.1 : entry.2
                    let vocab = korean ? KoreanVocabularyItem(surface: word, dictionaryForm: word,
                        romanization: "", partOfSpeech: "Noun", contextualMeaning: entry.3) : nil
                    // Rotate distractors so the correct choice does not occupy a fixed position.
                    let order = (0..<4).map { ($0 + offset * 2 + 1) % 4 }
                    return [
                        CourseLessonCard(id: "\(lesson.id)-picture-\(entry.0)", question: "What is this?",
                            options: order.map { words[$0] }, correctAnswer: word,
                            promptImageName: images[offset], vocabularyItem: vocab, conceptTag: "Visual vocabulary",
                            explanation: "\(word) means \(entry.3)."),
                        CourseLessonCard(id: "\(lesson.id)-image-choice-\(entry.0)", question: "Find ‘\(word)’",
                            options: order.map { names[$0] }, correctAnswer: entry.3,
                            optionImageNames: order.map { images[$0] }, vocabularyItem: vocab,
                            speechText: word, conceptTag: "Visual vocabulary", explanation: "\(word) means \(entry.3).")
                    ]
                }
                return CourseLesson(id: lesson.id, lessonNumber: lesson.lessonNumber, title: lesson.title,
                    subtitle: lesson.subtitle, nodeType: lesson.nodeType, estimatedMinutes: lesson.estimatedMinutes,
                    tipNote: lesson.tipNote, cards: lesson.cards + visualCards)
            }
            return CourseUnit(id: unit.id, unitNumber: unit.unitNumber, title: unit.title,
                subtitle: unit.subtitle, colorHex: unit.colorHex, badgeIcon: unit.badgeIcon,
                lessons: lessons, checkpointQuiz: unit.checkpointQuiz)
        }
        return enhancingPractice(CourseDefinition(id: course.id, title: course.title, language: course.language,
            flagEmoji: course.flagEmoji, levelTag: course.levelTag, colorHex: course.colorHex,
            summary: course.summary, estimatedHours: course.estimatedHours, outcomes: course.outcomes, units: units))
    }
}
