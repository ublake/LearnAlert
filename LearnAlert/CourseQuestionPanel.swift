import SwiftUI
import UIKit

// Course views also compile in the notification extension, which has no app design system.
enum CourseSurfaceStyle {
    static let lightBorderColor = UIColor(red: 0.65, green: 0.73, blue: 0.82, alpha: 1)
    static let lightOutline = Color(uiColor: lightBorderColor)
}

/// Shared grading, with a spacious app presentation and compact notification presentation.
struct CourseQuestionPanel: View {
    let card: CourseLessonCard
    var immersive = false
    var checkpoint = false
    var allowAudio = true
    var prefersReading = false
    var allowTypedRecall = false
    var onReadingRequested: () -> Void = {}
    let onAnswer: (Bool) -> Void
    @State private var typed = ""
    @State private var writingAnswer = false
    @State private var optionIndices: [Int] = []
    private var choiceOrder: [Int] { optionIndices.isEmpty ? Array(card.options.indices) : optionIndices }
    @FocusState private var typing: Bool
    @Environment(\.colorScheme) private var colorScheme
    @State private var grade: Bool?
    @State private var selectedOption: String?
    @State private var revealed = false
    @State private var hint = false
    @State private var inspecting = false
    @State private var readingInstead = false
    @ObservedObject private var speech = KoreanSpeechManager.shared

    private var usesChoices: Bool {
        card.cardType == "multipleChoice" || card.cardType == "listening"
            || (card.usesTypedAnswer && !card.options.isEmpty && !writingAnswer)
    }
    private var canTryTyping: Bool { allowTypedRecall && !checkpoint && card.usesTypedAnswer && !card.options.isEmpty }
    private var listening: Bool { card.isListeningQuestion && allowAudio && !prefersReading && !readingInstead && speech.hasVoice }
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
            if listening, let text = card.speechText {
                HStack(spacing: 16) {
                    Button { speech.speak(text) } label: {
                        Label(speech.isSpeaking ? "Play again" : "Listen", systemImage: "speaker.wave.2.fill")
                            .font(.headline).frame(maxWidth: .infinity, minHeight: immersive ? 80 : 56)
                    }.buttonStyle(.borderedProminent)
                    Button { speech.speak(text, speed: .slow) } label: {
                        Image(systemName: "tortoise.fill").frame(width: 56, height: immersive ? 80 : 56)
                    }.buttonStyle(.bordered).accessibilityLabel("Listen slowly")
                }
                if grade == nil {
                    Button("I can’t listen right now") {
                        speech.stop(); readingInstead = true; onReadingRequested()
                    }.font(.subheadline).frame(minHeight: 44)
                }
            }
            if !checkpoint && (!listening || grade != nil) {
                HStack(spacing: 8) {
                    if let text = card.primaryKoreanText, allowAudio && speech.hasVoice && !prefersReading && !readingInstead && (!writingAnswer || grade != nil) {
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
            if usesChoices {
                if card.optionImageNames.count == card.options.count && !card.optionImageNames.isEmpty {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: immersive ? 16 : 8) {
                        ForEach(Array(choiceOrder.enumerated()), id: \.element) { position, index in
                            let option = card.options[index]
                            Button { selectedOption = option; submit(card.accepts(option)) } label: {
                                VStack(spacing: 8) {
                                    if let image = CardImageStore.loadImage(named: card.optionImageNames[index]) {
                                        Image(uiImage: image).resizable().scaledToFit()
                                            .frame(maxWidth: .infinity).frame(height: immersive ? 120 : 88)
                                            .clipShape(RoundedRectangle(cornerRadius: 16))
                                    } else { Text(card.practiceOptionText(option)).frame(minHeight: 88) }
                                    if grade != nil { Text(card.practiceOptionText(option)).font(.caption.weight(.medium)).foregroundStyle(.primary) }
                                }.padding(12).frame(maxWidth: .infinity)
                                    .background(optionColor(option), in: RoundedRectangle(cornerRadius: 20))
                                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(optionBorder(option), lineWidth: 2))
                            }.buttonStyle(.plain).disabled(grade != nil)
                                // VoiceOver may describe the image, but the visual exercise does not show a text answer.
                                .accessibilityLabel(option).accessibilityAddTraits(selectedOption == option ? .isSelected : [])
                        }
                    }
                } else {
                    ForEach(Array(choiceOrder.enumerated()), id: \.element) { position, index in
                        let option = card.options[index]
                        Button { selectedOption = option; submit(card.accepts(option)) } label: {
                            HStack(spacing: 16) {
                                if immersive {
                                    Text(String(position + 1)).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                                        .frame(width: 28, height: 28).background(Color.primary.opacity(0.05), in: Circle())
                                }
                                Text(card.practiceOptionText(option)).font(immersive ? .title3.weight(.medium) : .body)
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
            } else if card.usesTypedAnswer {
                TextField("Your answer", text: $typed, axis: .vertical).textFieldStyle(.roundedBorder)
                    .overlay {
                        if colorScheme == .light {
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(CourseSurfaceStyle.lightOutline, lineWidth: 1)
                                .allowsHitTesting(false)
                        }
                    }
                    .focused($typing).autocorrectionDisabled().textInputAutocapitalization(.never).disabled(grade != nil)
                    .onSubmit { if grade == nil { submit(card.accepts(typed)) } }
                if grade == nil { Button("Check") { submit(card.accepts(typed)) }.buttonStyle(.borderedProminent).disabled(typed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            } else if card.cardType == "matching" {
                CourseMatchingPanel(card: card, immersive: immersive, onAnswer: submit)
            } else if card.cardType == "vocabulary" {
                VStack(alignment: .leading, spacing: 16) {
                    Text(card.vocabularyItem?.contextualMeaning ?? card.correctAnswer).font(immersive ? .title3 : .body).fixedSize(horizontal: false, vertical: true)
                    if let note = card.grammarNote, note != card.correctAnswer { Text(note).font(.callout).foregroundStyle(.secondary) }
                    if grade == nil {
                        HStack(spacing: 16) {
                            Button("Review later") { submit(false) }.buttonStyle(.bordered)
                            Button("Got it") { submit(true) }.buttonStyle(.borderedProminent)
                        }.controlSize(.large)
                    }
                }.padding(immersive ? 24 : 16).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
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
            if (canTryTyping || writingAnswer) && grade == nil {
                Button {
                    typing = false
                    typed = ""
                    writingAnswer.toggle()
                } label: {
                    Label(writingAnswer ? "Use answer choices" : "Try typing",
                          systemImage: writingAnswer ? "list.bullet" : "keyboard")
                        .font(.subheadline.weight(.medium)).frame(minHeight: 44)
                }.buttonStyle(.borderless)
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
        .onAppear { if optionIndices.isEmpty { optionIndices = Array(card.options.indices).shuffled() } }
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
        return colorScheme == .light ? CourseSurfaceStyle.lightOutline : Color.primary.opacity(0.10)
    }
    private func optionColor(_ option: String) -> Color {
        if grade != nil && card.accepts(option) { return Color.green.opacity(0.14) }
        if grade != nil && option == selectedOption { return Color.orange.opacity(0.14) }
        return immersive ? Color(.secondarySystemGroupedBackground) : Color.primary.opacity(0.04)
    }
    private var questionText: AttributedString {
        let prompt = card.cardType == "vocabulary" ? (card.vocabularyItem?.surface ?? card.question) : card.practiceQuestionText(audioEnabled: listening, typedRecall: writingAnswer)
        var text = AttributedString(prompt)
        guard !checkpoint, let expression = try? NSRegularExpression(pattern: "[가-힣ㄱ-ㅎㅏ-ㅣ]+") else { return text }
        for match in expression.matches(in: prompt, range: NSRange(prompt.startIndex..., in: prompt)) {
            guard let range = Range(match.range, in: prompt) else { continue }
            let word = String(prompt[range])
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
