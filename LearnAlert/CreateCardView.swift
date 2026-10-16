import PhotosUI
import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import Combine

struct CreateCardView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let deck: Deck
    var cardToEdit: Flashcard?
    @State private var selectedType: FlashcardType?
    @State private var question = ""
    @State private var answer = ""
    @State private var options = ["", "", "", ""]
    @State private var correctOptionIndex = 0
    @State private var visibleOptionCount = 4
    @State private var matchingLeft = Array(repeating: "", count: 20)
    @State private var matchingRight = Array(repeating: "", count: 20)
    @State private var visiblePairCount = 2
    @State private var hint = ""
    @State private var hintEnabled = false
    @State private var selectedSectionId = "NONE"
    @State private var fields: [String: CardFieldMedia] = [:]
    @State private var images: [String: UIImage] = [:]
    @State private var imageCardLayout = ImageCardLayout.single
    @State private var audioTarget: String?
    @State private var showingAudioImporter = false
    @State private var error: String?
    @State private var didSetUpData = false
    @State private var pendingImageCrop: CardImageCropRequest?
    @State private var imageLoadID = UUID()
    @State private var isLoadingImage = false
    @StateObject private var draftAudio = CardDraftAudioFiles()

    private func hasContent(_ key: String, _ text: String) -> Bool {
        images[key] != nil || (fields[key] ?? .init()).hasContent(text)
    }
    private var isFormValid: Bool {
        guard let selectedType, !isLoadingImage else { return false }
        switch selectedType {
        case .vocabulary, .tapReveal, .fillBlank, .anki:
            return hasContent("prompt", question) && hasContent("answer", answer)
        case .multipleChoice:
            return hasContent("prompt", question) && correctOptionIndex < visibleOptionCount &&
                (0..<visibleOptionCount).allSatisfy { hasContent("option:\($0)", options[$0]) }
        case .matching:
            return (0..<visiblePairCount).allSatisfy { hasContent("left:\($0)", matchingLeft[$0]) && hasContent("right:\($0)", matchingRight[$0]) }
        case .images:
            return (images["prompt"] != nil || fields["prompt"]?.image != nil) && (imageCardLayout == .single || images["answer"] != nil || fields["answer"]?.image != nil)
        }
    }
    var body: some View {
        NavigationStack {
            ZStack {
                LearnAlertStyle.courseCanvas.ignoresSafeArea()
                if selectedType == nil { typePicker } else { editor }
            }
            .navigationTitle(cardToEdit == nil ? "New Card" : "Edit Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { imageLoadID = UUID(); dismiss() } }
                if selectedType != nil && cardToEdit == nil {
                    ToolbarItem(placement: .topBarTrailing) { Button("Change Type") { withAnimation(.snappy) { selectedType = nil } }.font(.subheadline) }
                }
            }
            .tint(LearnAlertStyle.indigo)
            .toolbarBackground(LearnAlertStyle.courseCanvas, for: .navigationBar)
            .onAppear(perform: setupData)
            .fullScreenCover(item: $pendingImageCrop) { request in
                CardImageCropView(image: request.image, onCancel: { pendingImageCrop = nil }, onConfirm: { image in
                    images[request.key] = image; pendingImageCrop = nil
                })
            }
            .fileImporter(isPresented: $showingAudioImporter,
                allowedContentTypes: ["mp3", "m4a", "wav"].compactMap { UTType(filenameExtension: $0) }) { result in
                do {
                    let source = try result.get()
                    guard let audioTarget else { return }
                    let name = try CardAudioStore.importFile(source)
                    draftAudio.names.insert(name)
                    fields[audioTarget, default: .init()].audio = name
                } catch { if !(error is CancellationError) { self.error = error.localizedDescription } }
            }
            .alert("Card Attachment", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK", role: .cancel) { }
            } message: { Text(error ?? "") }
        }
    }

    private var typePicker: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(FlashcardType.allCases.filter { $0 != .anki }) { type in
                    Button { withAnimation(.snappy) { selectedType = type } } label: {
                        HStack(spacing: 14) {
                            Image(systemName: type.icon).font(.title3).foregroundStyle(LearnAlertStyle.indigo)
                                .frame(width: 42, height: 42).background(LearnAlertStyle.indigo.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(type.title).font(.headline).foregroundStyle(LearnAlertStyle.textPrimary)
                                Text(type.subtitle).font(.caption).foregroundStyle(LearnAlertStyle.textSecondary)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(LearnAlertStyle.textSecondary)
                        }.padding(14).editorSurface()
                    }.buttonStyle(.plain)
                }
            }.padding(16)
        }
    }

    private var editor: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let selectedType { Label(selectedType.title, systemImage: selectedType.icon).font(.caption.weight(.semibold)).foregroundStyle(LearnAlertStyle.indigo) }
                switch selectedType {
                case .images: imagesEditor
                case .multipleChoice: multipleChoiceEditor
                case .matching: matchingEditor
                default: frontBackEditor
                }
                if selectedType != .images {
                    Text("Swipe left on \(selectedType == .multipleChoice ? "answer choices" : "fields") to add images or audio files.")
                        .font(.caption).foregroundStyle(LearnAlertStyle.textSecondary)
                    VStack(alignment: .leading, spacing: 8) {
                        Button { withAnimation(.snappy) { hintEnabled.toggle() } } label: {
                            Label("Hint", systemImage: hintEnabled ? "checkmark.square.fill" : "square")
                                .font(.subheadline.weight(.medium)).frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
                        }.buttonStyle(.plain).foregroundStyle(hintEnabled ? LearnAlertStyle.indigo : LearnAlertStyle.textSecondary)
                            .accessibilityValue(hintEnabled ? "On" : "Off")
                        if hintEnabled { mediaField("hint", title: "", placeholder: "A small clue…", text: $hint) }
                    }.padding(.horizontal, 12).padding(.vertical, 6).editorSurface()
                }
                if !deck.sections.isEmpty {
                    HStack {
                        Text("Category").font(.subheadline).foregroundStyle(LearnAlertStyle.textSecondary)
                        Spacer()
                        Picker("Category", selection: $selectedSectionId) {
                            Text("None").tag("NONE")
                            ForEach(deck.sections) { Text($0.name).tag($0.id.uuidString) }
                        }.pickerStyle(.menu)
                    }.padding(.horizontal, 12).padding(.vertical, 4).editorSurface()
                }
                Button(action: saveCard) {
                    Label(cardToEdit == nil ? "Save Card" : "Update Card", systemImage: "checkmark.circle.fill")
                        .font(.headline).frame(maxWidth: .infinity, minHeight: 46)
                }.buttonStyle(.borderedProminent).disabled(!isFormValid)
            }.padding(16)
        }.scrollDismissesKeyboard(.interactively)
    }

    private var frontBackEditor: some View {
        VStack(spacing: 12) {
            if selectedType == .fillBlank {
                Button { if !question.contains("___") { question += question.isEmpty ? "___" : " ___" } } label: { Label("Insert blank", systemImage: "plus.square.dashed").font(.caption) }.frame(maxWidth: .infinity, alignment: .trailing)
            }
            mediaField("prompt", title: selectedType == .vocabulary ? "TERM" : selectedType == .fillBlank ? "SENTENCE" : "FRONT", placeholder: selectedType == .fillBlank ? "Sentence with a ___ blank" : "Text, image or audio", text: $question)
            mediaField("answer", title: selectedType == .vocabulary ? "DEFINITION" : "ANSWER", placeholder: "Text, image or audio", text: $answer)
        }.padding(12).editorSurface()
    }
    private var multipleChoiceEditor: some View {
        VStack(spacing: 12) {
            mediaField("prompt", title: "QUESTION", placeholder: "Text, image or audio", text: $question)
            HStack {
                Text("CHOICES").font(.caption.weight(.semibold)).foregroundStyle(LearnAlertStyle.textSecondary)
                Spacer()
                countSelector(value: $visibleOptionCount) { if correctOptionIndex >= visibleOptionCount { correctOptionIndex = 0 } }
            }
            ForEach(0..<visibleOptionCount, id: \.self) { index in
                HStack(alignment: .top, spacing: 8) {
                    Button { correctOptionIndex = index } label: {
                        Image(systemName: correctOptionIndex == index ? "checkmark.circle.fill" : "circle")
                            .font(.title3).foregroundStyle(correctOptionIndex == index ? .green : LearnAlertStyle.textSecondary)
                            .frame(width: 32, height: 44)
                    }.buttonStyle(.plain).accessibilityLabel("Choice \(index + 1) is correct").accessibilityAddTraits(correctOptionIndex == index ? .isSelected : [])
                    mediaField("option:\(index)", title: "", placeholder: "Choice \(index + 1)", text: $options[index])
                }
            }
        }.padding(12).editorSurface()
    }
    private var matchingEditor: some View {
        VStack(spacing: 12) {
            mediaField("prompt", title: "PROMPT", placeholder: "Match the pairs (optional)", text: $question)
            HStack { Text("PAIRS").font(.caption.weight(.semibold)); Spacer(); Picker("Pairs", selection: $visiblePairCount) { ForEach(2...20, id: \.self) { Text("\($0)").tag($0) } }.pickerStyle(.menu) }
            ForEach(0..<visiblePairCount, id: \.self) { index in
                HStack(alignment: .top, spacing: 8) {
                    mediaField("left:\(index)", title: "", placeholder: "Left \(index + 1)", text: $matchingLeft[index])
                    Image(systemName: "arrow.left.arrow.right").font(.caption).padding(.top, 16).foregroundStyle(LearnAlertStyle.indigo)
                    mediaField("right:\(index)", title: "", placeholder: "Match \(index + 1)", text: $matchingRight[index])
                }
            }
        }.padding(12).editorSurface()
    }
    private var imagesEditor: some View {
        VStack(spacing: 12) {
            Picker("Image layout", selection: $imageCardLayout) {
                Text("Single").tag(ImageCardLayout.single); Text("Front & back").tag(ImageCardLayout.frontAndBack)
            }.pickerStyle(.segmented)
            imageOnlyField("prompt", title: "Front")
            if imageCardLayout == .frontAndBack { imageOnlyField("answer", title: "Back") }
        }.padding(12).editorSurface().animation(.snappy, value: imageCardLayout)
    }
    private func imageOnlyField(_ key: String, title: String) -> some View {
        CardEditorMediaField(title: title, placeholder: "", text: .constant(""), image: images[key] ?? CardImageStore.loadImage(named: fields[key]?.image), audio: nil, imageOnly: true,
            onPhoto: { loadImage($0, key: key) }, onAudio: {}, onRemoveImage: { images[key] = nil; fields[key]?.image = nil }, onRemoveAudio: {},
            onCrop: { if let image = images[key] ?? CardImageStore.loadImage(named: fields[key]?.image) { pendingImageCrop = .init(image: image, key: key) } })
    }
    private func mediaField(_ key: String, title: String, placeholder: String, text: Binding<String>) -> some View {
        CardEditorMediaField(title: title, placeholder: placeholder, text: text,
            image: images[key] ?? CardImageStore.loadImage(named: fields[key]?.image), audio: fields[key]?.audio,
            onPhoto: { loadImage($0, key: key) }, onAudio: { audioTarget = key; showingAudioImporter = true },
            onRemoveImage: { images[key] = nil; fields[key]?.image = nil }, onRemoveAudio: { fields[key]?.audio = nil },
            onCrop: { if let image = images[key] ?? CardImageStore.loadImage(named: fields[key]?.image) { pendingImageCrop = .init(image: image, key: key) } })
    }
    private func countSelector(value: Binding<Int>, changed: @escaping () -> Void) -> some View {
        HStack(spacing: 4) {
            ForEach(2...4, id: \.self) { count in
                Button { withAnimation(.snappy) { value.wrappedValue = count; changed() } } label: {
                    Text("\(count)").font(.caption.bold()).frame(width: 28, height: 26)
                        .background(value.wrappedValue == count ? LearnAlertStyle.indigo.opacity(0.28) : Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
                }.buttonStyle(.plain)
            }
        }
    }
    private func loadImage(_ item: PhotosPickerItem, key: String) {
        let id = UUID(); imageLoadID = id; isLoadingImage = true
        Task { @MainActor in
            do {
                guard let data = try await item.loadTransferable(type: Data.self), let image = CardImageCropRenderer.preparedImage(from: data) else { throw CocoaError(.fileReadCorruptFile) }
                guard id == imageLoadID else { return }
                isLoadingImage = false; pendingImageCrop = .init(image: image, key: key)
            } catch {
                guard id == imageLoadID else { return }
                isLoadingImage = false; self.error = "This photo couldn’t be opened. Please choose another image."
            }
        }
    }
    private func setupData() {
        guard !didSetUpData else { return }; didSetUpData = true
        guard let card = cardToEdit else { return }
        selectedType = card.cardType; question = card.question; answer = card.correctAnswer; hint = card.hint
        fields = card.fieldMedia; hintEnabled = hasContent("hint", hint)
        selectedSectionId = card.section?.id.uuidString ?? "NONE"
        imageCardLayout = card.answerImageName == nil ? .single : .frontAndBack
        for (i, text) in card.options.prefix(4).enumerated() { options[i] = text }
        visibleOptionCount = min(4, max(2, card.options.count)); correctOptionIndex = card.resolvedCorrectOptionIndex ?? 0
        for (i, text) in card.matchingLeftItems.prefix(20).enumerated() { matchingLeft[i] = text }
        for (i, text) in card.matchingRightItems.prefix(20).enumerated() { matchingRight[i] = text }
        visiblePairCount = min(20, max(2, card.matchingLeftItems.count))
    }
    private func saveCard() {
        guard let type = selectedType, isFormValid else { return }
        var final = fields
        var savedImages: [String] = []
        let allowed = Set(["prompt"] + (type == .matching ? (0..<visiblePairCount).flatMap { ["left:\($0)", "right:\($0)"] } : type == .multipleChoice ? (0..<visibleOptionCount).map { "option:\($0)" } : type == .images && imageCardLayout == .single ? [] : ["answer"]) + (hintEnabled && type != .images ? ["hint"] : []))
        for (key, image) in images where allowed.contains(key) {
            guard let name = CardImageStore.saveImage(image) else {
                savedImages.forEach { CardImageStore.deleteImage(named: $0) }; error = "Your image couldn’t be saved. Please try again."; return
            }
            savedImages.append(name); final[key, default: .init()].image = name
        }
        final = final.filter { allowed.contains($0.key) && !$0.value.isEmpty }
        if type == .images { for key in final.keys { final[key]?.audio = nil } }
        func trim(_ value: String) -> String { value.trimmingCharacters(in: .whitespacesAndNewlines) }
        let card = cardToEdit ?? Flashcard(question: "", cardType: type)
        let old = (card.question, card.correctAnswer, card.options, card.hint, card.matchingLeftItems, card.matchingRightItems, card.fieldMedia, card.correctOptionIndex, card.section)
        card.question = type == .images ? "" : trim(question)
        card.options = type == .multipleChoice ? options.prefix(visibleOptionCount).map(trim) : []
        card.correctAnswer = type == .multipleChoice ? trim(options[correctOptionIndex]) : type == .matching || type == .images ? "" : trim(answer)
        card.correctOptionIndex = type == .multipleChoice ? correctOptionIndex : nil
        card.hint = hintEnabled && type != .images ? trim(hint) : ""
        card.matchingLeftItems = type == .matching ? matchingLeft.prefix(visiblePairCount).map(trim) : []
        card.matchingRightItems = type == .matching ? matchingRight.prefix(visiblePairCount).map(trim) : []
        card.fieldMedia = final
        card.section = deck.sections.first { $0.id.uuidString == selectedSectionId }
        if cardToEdit == nil { deck.cards.append(card) }
        do { try context.save() }
        catch {
            if cardToEdit == nil { deck.cards.removeAll { $0.id == card.id }; context.delete(card) }
            else {
                (card.question, card.correctAnswer, card.options, card.hint, card.matchingLeftItems, card.matchingRightItems, card.fieldMedia, card.correctOptionIndex, card.section) = old
            }
            savedImages.forEach { CardImageStore.deleteImage(named: $0) }; self.error = "Your card couldn’t be saved. Please try again."; return
        }
        draftAudio.names.subtract(final.values.compactMap(\.audio))
        CardAttachmentCleanup.removeUnreferenced(old.6, context: context)
        imageLoadID = UUID(); dismiss()
    }
}

private struct CardImageCropRequest: Identifiable { let id = UUID(); let image: UIImage; let key: String }
private enum ImageCardLayout { case single, frontAndBack }
private final class CardDraftAudioFiles: ObservableObject {
    var names = Set<String>()
    deinit { names.forEach { CardAudioStore.delete(named: $0) } }
}

private struct CardEditorMediaField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let image: UIImage?
    let audio: String?
    var imageOnly = false
    let onPhoto: (PhotosPickerItem) -> Void
    let onAudio: () -> Void
    let onRemoveImage: () -> Void
    let onRemoveAudio: () -> Void
    let onCrop: () -> Void
    @State private var photo: PhotosPickerItem?
    @State private var open = false
    @GestureState private var drag: CGFloat = 0
    private let reveal: CGFloat = 100
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !title.isEmpty { Text(title).font(.caption.weight(.semibold)).foregroundStyle(LearnAlertStyle.textSecondary) }
            if imageOnly {
                photoButton.frame(maxWidth: .infinity, minHeight: image == nil ? 100 : 36)
            } else {
                ZStack(alignment: .trailing) {
                    HStack(spacing: 4) { photoButton; Button(action: onAudio) { Image(systemName: "waveform.badge.plus").frame(width: 44, height: 44) }.accessibilityLabel("Attach audio") }
                        .foregroundStyle(LearnAlertStyle.indigo).frame(width: reveal).opacity(open || drag < -8 ? 1 : 0)
                        .accessibilityHidden(!open)
                    TextField(placeholder, text: $text, axis: .vertical).lineLimit(1...3)
                        .font(.subheadline).padding(.horizontal, 12).padding(.vertical, 11)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .background(LearnAlertStyle.courseCanvas, in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(LearnAlertStyle.hairline, lineWidth: 1))
                        .offset(x: max(-reveal, min(0, (open ? -reveal : 0) + drag)))
                        .simultaneousGesture(DragGesture(minimumDistance: 18).updating($drag) { value, state, _ in
                            if abs(value.translation.width) > abs(value.translation.height) * 1.4 { state = value.translation.width }
                        }.onEnded { value in
                            guard abs(value.translation.width) > abs(value.translation.height) * 1.4 else { return }
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { open = value.translation.width < -25 || (open && value.translation.width < 25) }
                        })
                        .accessibilityAction(named: "Show attachments") { withAnimation(.snappy) { open = true } }
                }.clipped()
            }
            if let image {
                HStack(spacing: 8) {
                    Button(action: onCrop) { Image(uiImage: image).resizable().scaledToFit().frame(maxWidth: imageOnly ? .infinity : 72, maxHeight: imageOnly ? 220 : 44).clipShape(RoundedRectangle(cornerRadius: 6)) }.buttonStyle(.plain).accessibilityLabel("Adjust image frame")
                    Spacer(minLength: 0)
                    Button(action: onRemoveImage) { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain).foregroundStyle(LearnAlertStyle.textSecondary).accessibilityLabel("Remove image")
                }
            }
            if let audio {
                HStack { CardAudioPlaybackButton(name: audio).font(.caption); Spacer(minLength: 0); Button(action: onRemoveAudio) { Image(systemName: "xmark.circle.fill") }.accessibilityLabel("Remove audio") }.buttonStyle(.plain)
            }
        }
        .onChange(of: photo) { _, item in if let item { onPhoto(item); photo = nil; withAnimation(.snappy) { open = false } } }
    }
    private var photoButton: some View {
        PhotosPicker(selection: $photo, matching: .images) {
            Group { if imageOnly { Label(image == nil ? "Upload image" : "Change image", systemImage: "photo.badge.plus") } else { Image(systemName: "photo.badge.plus").frame(width: 44, height: 44) } }
        }.accessibilityLabel("Attach image")
    }
}
private extension View {
    func editorSurface() -> some View {
        background(LearnAlertStyle.surface, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(LearnAlertStyle.hairline, lineWidth: 1))
    }
}
