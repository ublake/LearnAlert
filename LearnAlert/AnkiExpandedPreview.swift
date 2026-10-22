import SwiftUI
import Combine

nonisolated struct AnkiPreviewDocuments: Sendable {
    let front: String
    let back: String
    let mediaIndex: [String: String]

    static func prepare(_ content: AnkiCardContent, configuration: AnkiRenderConfiguration) throws -> Self {
        try Task.checkCancellation()
        let index = content.mediaURL.map { AnkiLibraryPreview.mediaIndex(in: $0) } ?? [:]
        let front = AnkiCardView.document(content: content, showingBack: false, configuration: configuration)
        try Task.checkCancellation()
        let back = AnkiCardView.document(content: content, showingBack: true, configuration: configuration)
        return .init(front: front, back: back, mediaIndex: index)
    }
}

/// Creating a collapsed row creates no WebKit objects. An expanded row starts
/// one side at a time after background preparation and releases both on collapse.
@MainActor
final class AnkiPreviewRenderController: ObservableObject {
    @Published private(set) var front: AnkiCardRenderer?
    @Published private(set) var back: AnkiCardRenderer?
    @Published private(set) var documents: AnkiPreviewDocuments?
    private var frontFinished: AnyCancellable?
    private var backTask: Task<Void, Never>?
    private var generation = UUID()

    func start(_ documents: AnkiPreviewDocuments, directory: URL?) {
        clear()
        self.documents = documents
        let run = generation
        let renderer = AnkiCardRenderer()
        frontFinished = renderer.$isLoading.filter { !$0 }.first().sink { [weak self] _ in
            // An error also settles the front. Its retry UI must not prevent the
            // user from seeing a valid back side.
            self?.backTask = Task { @MainActor [weak self] in
                await Task.yield()
                guard let self, !Task.isCancelled, self.generation == run else { return }
                let back = AnkiCardRenderer()
                back.load(documents.back, directory: directory, mediaIndex: documents.mediaIndex)
                self.back = back
            }
        }
        renderer.load(documents.front, directory: directory, mediaIndex: documents.mediaIndex)
        front = renderer
    }

    func clear() {
        generation = UUID()
        frontFinished?.cancel(); frontFinished = nil
        backTask?.cancel(); backTask = nil
        front?.discard(); back?.discard()
        front = nil; back = nil; documents = nil
    }
}

struct AnkiExpandedPreview: View {
    let content: AnkiCardContent
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var controller = AnkiPreviewRenderController()
    private struct Request: Equatable {
        let content: AnkiCardContent
        let configuration: AnkiRenderConfiguration
    }

    var body: some View {
        let configuration = AnkiRenderConfiguration(dark: colorScheme == .dark, compact: true,
            centered: false, animatedReveal: false, reduceMotion: reduceMotion)
        VStack(alignment: .leading, spacing: 7) {
            Text("Front").font(.caption2).foregroundStyle(LearnAlertStyle.textSecondary)
            side(controller.front, back: false)
            Text("Back").font(.caption2).foregroundStyle(LearnAlertStyle.textSecondary)
            side(controller.back, back: true)
        }
        .task(id: Request(content: content, configuration: configuration)) {
            controller.clear()
            let content = content
            let worker = Task.detached(priority: .userInitiated) {
                try AnkiPreviewDocuments.prepare(content, configuration: configuration)
            }
            do {
                let documents = try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
                try Task.checkCancellation()
                // Let SwiftUI lay out the expansion before starting a browser.
                await Task.yield()
                try Task.checkCancellation()
                controller.start(documents, directory: content.mediaURL)
            } catch { /* Collapsing or editing cancels this preview. */ }
        }
        .onDisappear { controller.clear() }
    }

    private func side(_ renderer: AnkiCardRenderer?, back: Bool) -> some View {
        Group {
            if let renderer, let documents = controller.documents {
                AnkiCardView(content: content, showingBack: back, compact: true, renderer: renderer,
                    preparedDocument: back ? documents.back : documents.front, preparedMediaIndex: documents.mediaIndex)
                    .id(ObjectIdentifier(renderer))
            } else { ProgressView("Loading card…").font(.caption).frame(maxWidth: .infinity, maxHeight: .infinity) }
        }.frame(height: 190).clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
