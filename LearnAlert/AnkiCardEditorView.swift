import SwiftUI
import SwiftData
import AnkiArchive

struct AnkiCardEditorView: View {
    @Bindable var card: Flashcard
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var front = ""
    @State private var back = ""
    @State private var css = ""
    @State private var selection = 0
    @State private var preview = false
    @State private var error: String?
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Picker("Side", selection: $selection) {
                    Text("Front").tag(0); Text("Back").tag(1); Text("Style").tag(2)
                }.pickerStyle(.segmented)
                if preview, let original = card.ankiContent {
                    let content = AnkiCardContent(frontHTML: front, backHTML: back, css: css, mediaFolder: original.mediaFolder,
                        templateOrdinal: original.templateOrdinal, noteType: original.noteType, tags: original.tags)
                    AnkiCardView(content: content, showingBack: selection == 1)
                } else {
                    TextEditor(text: selection == 0 ? $front : selection == 1 ? $back : $css)
                        .font(.system(.body, design: .monospaced)).autocorrectionDisabled().textInputAutocapitalization(.never)
                }
            }.padding(20).background(LearnAlertStyle.courseCanvas)
                .navigationTitle("Anki card").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button { preview.toggle() } label: { Image(systemName: preview ? "chevron.left.forwardslash.chevron.right" : "eye") }.accessibilityLabel(preview ? "Edit HTML" : "Preview")
                        Button("Save") { save() }
                    }
                }
                .onAppear {
                    guard let content = card.ankiContent else { return }
                    front = content.frontHTML; back = content.backHTML; css = content.css
                }
                .alert("Couldn't save card", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                    Button("OK") { error = nil }
                } message: { Text(error ?? "") }
        }
    }
    private func save() {
        guard var content = card.ankiContent else { return }
        if content.frontHTML != front || content.backHTML != back { content.frontSideRanges = nil }
        content.frontHTML = front; content.backHTML = back; content.css = css
        let original = card.ankiContentData, question = card.question, answer = card.correctAnswer
        card.ankiContent = content
        card.question = String(AnkiTemplateRenderer.plainText(front).prefix(8_000))
        card.correctAnswer = String(AnkiTemplateRenderer.plainText(back).prefix(8_000))
        do { try context.save(); dismiss() }
        catch { card.ankiContentData = original; card.question = question; card.correctAnswer = answer; self.error = error.localizedDescription }
    }
}
