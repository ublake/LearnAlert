import SwiftUI

/// Shared grading, with a spacious app presentation and compact notification presentation.
struct CourseQuestionPanel: View {
    let card: CourseLessonCard
    var immersive = false
    var checkpoint = false
    var allowAudio = true
    let onAnswer: (Bool) -> Void
    @State private var typed = ""
    @FocusState private var typing: Bool
    @State private var grade: Bool?
    @State private var selectedOption: String?
    @State private var revealed = false
    @State private var hint = false
    @State private var inspecting = false
    @State private var leftIndex: Int?
    @State private var matches: [Int: Int] = [:]
    @State private var selectedWord: String?

    var body: some View {
        VStack(spacing: 16) {
            Text(questionText).font(immersive ? .title.weight(.bold) : .title3.weight(.semibold)).multilineTextAlignment(.center)
                .frame(maxWidth: .infinity).padding(immersive ? 0 : 16)
                .background(immersive ? Color.clear : Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16))
                .environment(\.openURL, OpenURLAction { url in
                    guard url.scheme == "learnalert-word" else { return .systemAction }
                    selectedWord = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "word" })?.value
                    inspecting = true
                    return .handled
                })
            if let image = CardImageStore.loadImage(named: card.promptImageName) {
                Image(uiImage: image).resizable().scaledToFit()
                    .frame(maxWidth: immersive ? 224 : 160, maxHeight: immersive ? 224 : 160)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .accessibilityLabel("Vocabulary picture")
            }
            if !checkpoint {
                HStack(spacing: 8) {
                    if let text = card.primaryKoreanText, allowAudio {
                        Button { KoreanSpeechManager.shared.speak(text) } label: { Image(systemName: "speaker.wave.2.fill").frame(width: 44, height: 44) }
                            .accessibilityLabel("Pronounce in Korean")
                        Button { KoreanSpeechManager.shared.speak(text, speed: .slow) } label: { Image(systemName: "tortoise.fill").frame(width: 44, height: 44) }
                            .accessibilityLabel("Pronounce slowly")
                    }
                    if card.vocabularyItem != nil || card.grammarNote != nil {
                        Button { inspecting = true } label: { Image(systemName: "book.closed").frame(width: 44, height: 44) }.accessibilityLabel("Word and grammar details")
                    }
                    if !card.hint.isEmpty { Button { hint.toggle() } label: { Image(systemName: "lightbulb").frame(width: 44, height: 44) }.accessibilityLabel("Hint") }
                }.buttonStyle(.borderless)
                if hint { Text(card.hint).font(.callout).foregroundStyle(.secondary) }
            }
            if card.cardType == "multipleChoice" {
                if card.optionImageNames.count == card.options.count && !card.optionImageNames.isEmpty {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: immersive ? 16 : 8) {
                        ForEach(card.options.indices, id: \.self) { index in
                            let option = card.options[index]
                            Button { selectedOption = option; submit(card.accepts(option)) } label: {
                                VStack(spacing: 8) {
                                    if let image = CardImageStore.loadImage(named: card.optionImageNames[index]) {
                                        Image(uiImage: image).resizable().scaledToFit()
                                            .frame(maxWidth: .infinity).frame(height: immersive ? 120 : 88)
                                            .clipShape(RoundedRectangle(cornerRadius: 16))
                                    } else { Text(option).frame(minHeight: 88) }
                                    if grade != nil { Text(option).font(.caption.weight(.medium)).foregroundStyle(.primary) }
                                }.padding(12).frame(maxWidth: .infinity)
                                    .background(optionColor(option), in: RoundedRectangle(cornerRadius: 20))
                                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(optionBorder(option), lineWidth: 2))
                            }.buttonStyle(.plain).disabled(grade != nil)
                                // VoiceOver may describe the image, but the visual exercise does not show a text answer.
                                .accessibilityLabel(option).accessibilityAddTraits(selectedOption == option ? .isSelected : [])
                        }
                    }
                } else {
                    ForEach(card.options.indices, id: \.self) { index in
                        let option = card.options[index]
                        Button { selectedOption = option; submit(card.accepts(option)) } label: {
                            HStack(spacing: 16) {
                                if immersive {
                                    Text(String(index + 1)).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                                        .frame(width: 28, height: 28).background(Color.primary.opacity(0.05), in: Circle())
                                }
                                Text(option).font(immersive ? .title3.weight(.medium) : .body)
                                    .multilineTextAlignment(immersive ? .leading : .center).frame(maxWidth: .infinity, alignment: immersive ? .leading : .center)
                                if grade != nil && (card.accepts(option) || option == selectedOption) {
                                    Image(systemName: card.accepts(option) ? "checkmark.circle.fill" : "xmark.circle.fill")
                                }
                            }.foregroundStyle(.primary).padding(immersive ? 16 : 12)
                                .frame(minHeight: immersive ? 64 : 44)
                                .background(optionColor(option), in: RoundedRectangle(cornerRadius: immersive ? 20 : 12))
                                .overlay(RoundedRectangle(cornerRadius: immersive ? 20 : 12).stroke(optionBorder(option), lineWidth: immersive ? 2 : 1))
                        }.buttonStyle(.plain).disabled(grade != nil)
                    }
                }
            } else if card.cardType == "fillBlank" {
                TextField("Your answer", text: $typed, axis: .vertical).textFieldStyle(.roundedBorder)
                    .focused($typing).autocorrectionDisabled().textInputAutocapitalization(.never).disabled(grade != nil)
                    .onSubmit { if grade == nil { submit(card.accepts(typed)) } }
                if grade == nil { Button("Check") { submit(card.accepts(typed)) }.buttonStyle(.borderedProminent).disabled(typed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            } else if card.cardType == "matching" {
                HStack(alignment: .top, spacing: 12) {
                    VStack {
                        ForEach(card.matchingLeftItems.indices, id: \.self) { index in
                            Button(card.matchingLeftItems[index]) { leftIndex = index }
                                .buttonStyle(.bordered).tint(leftIndex == index ? .blue : .gray)
                                .disabled(grade != nil || matches.values.contains(index))
                        }
                    }
                    VStack {
                        ForEach(Array(card.matchingRightItems.indices.reversed()), id: \.self) { index in
                            Button(card.matchingRightItems[index]) {
                                guard let leftIndex else { return }
                                matches[index] = leftIndex; self.leftIndex = nil
                                if matches.count == card.matchingRightItems.count { submit(matches.allSatisfy { $0.key == $0.value }) }
                            }.buttonStyle(.bordered).disabled(grade != nil || leftIndex == nil || matches[index] != nil)
                        }
                    }
                }
            } else {
                if revealed {
                    Text(card.correctAnswer).font(.title3)
                    if grade == nil {
                        HStack {
                            Button("Review later") { submit(false) }.buttonStyle(.bordered)
                            Button("I knew it") { submit(true) }.buttonStyle(.borderedProminent)
                        }
                    }
                } else { Button("Reveal") { revealed = true }.buttonStyle(.borderedProminent) }
            }
            if let grade, !immersive {
                Label(grade ? "Correct" : "Review later", systemImage: grade ? "checkmark.circle.fill" : "arrow.counterclockwise")
                    .foregroundStyle(grade ? Color.green : Color.orange)
                if !grade {
                    if card.cardType == "matching" {
                        ForEach(card.matchingLeftItems.indices, id: \.self) { index in
                            if card.matchingRightItems.indices.contains(index) {
                                Text("\(card.matchingLeftItems[index]) → \(card.matchingRightItems[index])").font(.callout)
                            }
                        }
                    } else { Text(card.correctAnswer).font(.headline).multilineTextAlignment(.center) }
                }
                if !checkpoint, let explanation = card.explanation { Text(explanation).font(.callout).foregroundStyle(.secondary) }
            }
        }
        .sheet(isPresented: $inspecting) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let item = card.vocabularyItem {
                            Text(item.surface).font(.title2.bold())
                            Text(item.contextualMeaning)
                            if item.partOfSpeech != "Expression" {
                                Text("\(item.dictionaryForm) · \(item.partOfSpeech)").foregroundStyle(.secondary)
                            }
                            if !item.romanization.isEmpty { Text(item.romanization).foregroundStyle(.secondary) }
                            // Tokens open a contextual dictionary; unknown tokens link to the official dictionary.
                            let words = Array(Set(item.surface.components(separatedBy: .whitespaces).filter { !$0.isEmpty })).sorted()
                            FlowWordList(words: words) { selectedWord = $0 }
                        }
                        if let selectedWord { CourseWordDefinition(word: selectedWord, context: card.vocabularyItem, allowAudio: allowAudio) }
                        if let note = card.grammarNote ?? card.vocabularyItem?.breakdownNote { Text(note) }
                    }.padding(20)
                }.navigationTitle("Details").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { inspecting = false } } }
            }.presentationDetents([.medium, .large])
        }
    }
    private func optionBorder(_ option: String) -> Color {
        if grade != nil && card.accepts(option) { return Color.green.opacity(0.6) }
        if grade != nil && option == selectedOption { return Color.orange.opacity(0.6) }
        return Color.primary.opacity(0.10)
    }
    private func optionColor(_ option: String) -> Color {
        if grade != nil && card.accepts(option) { return Color.green.opacity(0.14) }
        if grade != nil && option == selectedOption { return Color.orange.opacity(0.14) }
        return immersive ? Color(.secondarySystemGroupedBackground) : Color.primary.opacity(0.04)
    }
    private var questionText: AttributedString {
        var text = AttributedString(card.question)
        guard !checkpoint, let expression = try? NSRegularExpression(pattern: "[가-힣ㄱ-ㅎㅏ-ㅣ]+") else { return text }
        for match in expression.matches(in: card.question, range: NSRange(card.question.startIndex..., in: card.question)) {
            guard let range = Range(match.range, in: card.question) else { continue }
            let word = String(card.question[range])
            guard let attributedRange = text.range(of: word) else { continue }
            var components = URLComponents(); components.scheme = "learnalert-word"; components.host = "lookup"
            components.queryItems = [URLQueryItem(name: "word", value: word)]
            text[attributedRange].link = components.url
        }
        return text
    }
    private func submit(_ correct: Bool) { guard grade == nil else { return }; typing = false; grade = correct; onAnswer(correct) }
}

private struct FlowWordList: View {
    let words: [String]
    let select: (String) -> Void
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 8) {
            ForEach(words, id: \.self) { word in Button(word) { select(word) }.buttonStyle(.bordered) }
        }
    }
}

private struct CourseWordDefinition: View {
    let word: String
    let context: KoreanVocabularyItem?
    var allowAudio = true
    private var entry: KoreanWordEntry? { KoreanLexicon.lookup(word) }
    private var lookup: String { entry?.dictionaryForm ?? word }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let entry {
                Text(entry.dictionaryForm).font(.headline)
                Text(entry.meaning).font(.callout)
                Text(entry.usage).font(.callout).foregroundStyle(.secondary)
            }
            if let example = context?.exampleKorean { Text(example).font(.callout) }
            if let meaning = context?.exampleEnglish { Text(meaning).font(.callout).foregroundStyle(.secondary) }
            if allowAudio {
                HStack {
                    Button { KoreanSpeechManager.shared.speak(word) } label: {
                        Image(systemName: "speaker.wave.2").frame(width: 44, height: 44)
                    }.accessibilityLabel("Pronounce word")
                    Button { KoreanSpeechManager.shared.speak(word, speed: .slow) } label: {
                        Image(systemName: "tortoise").frame(width: 44, height: 44)
                    }.accessibilityLabel("Pronounce word slowly")
                }
            }
            if let url = URL(string: "https://krdict.korean.go.kr/eng/dicSearch/search?mainSearchWord=\(lookup.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&nation=eng") {
                Link("Look up \(lookup)", destination: url).font(.callout)
            }
        }
    }
}
