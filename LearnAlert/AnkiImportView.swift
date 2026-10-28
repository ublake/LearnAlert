import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import AnkiArchive

extension UTType {
    static let ankiPackage = UTType(importedAs: "net.ankiweb.apkg", conformingTo: .data)
}

struct AnkiImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var session = AnkiImportSession()
    @State private var showingFilePicker = false
    @State private var showingSample = false
    @State private var showingDeckNames = false
    @State private var openedInitialURL = false
    @FocusState private var focusedDeckName: String?
    let initialURL: URL?
    let onFinish: () -> Void

    init(initialURL: URL? = nil, onFinish: @escaping () -> Void = { }) {
        self.initialURL = initialURL; self.onFinish = onFinish
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LearnAlertStyle.courseCanvas.ignoresSafeArea()
                Group {
                    switch session.phase {
                    case .chooseFile, .failed: chooseFile
                    case .converting, .saving: converting
                    case .review: review
                    case .complete: complete
                    }
                }
                .transition(session.phase == .saving ? .identity : .opacity.combined(with: .offset(y: reduceMotion ? 0 : 12)))
            }
            .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.86), value: session.phase)
            .navigationTitle(session.isBusy ? "" : "Import Anki")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(session.phase == .complete ? "Done" : "Close") { session.cancel(); dismiss() }
                        .disabled(session.phase == .saving)
                }
            }
            .interactiveDismissDisabled(session.isBusy)
            .fileImporter(isPresented: $showingFilePicker, allowedContentTypes: [.ankiPackage]) { result in
                switch result {
                case .success(let url): session.open(url)
                case .failure(let error): session.error = error.localizedDescription
                }
            }
            .sheet(isPresented: $showingSample) {
                if let package = session.package {
                    AnkiPreviewView(cards: package.cards.filter { session.selectedDecks.contains($0.deckID) }, mediaDirectory: package.mediaDirectory)
                }
            }
            .sheet(isPresented: $showingDeckNames) { deckNameEditor }
            .alert("Import couldn't finish", isPresented: Binding(get: { session.error != nil }, set: { if !$0 { session.error = nil } })) {
                Button("OK") { session.error = nil }
            } message: { Text(session.error ?? "") }
            .onAppear {
                if let initialURL, !openedInitialURL { openedInitialURL = true; session.open(initialURL) }
            }
            .onChange(of: initialURL) { _, url in
                guard let url else { return }
                guard session.phase != .saving else {
                    session.error = "Finish saving this deck before opening another Anki file."
                    return
                }
                openedInitialURL = true
                session.open(url)
            }
            .onChange(of: session.phase) { _, phase in
                if phase == .review, !session.hasConfirmedDeckNames { showingDeckNames = true }
            }
            .onDisappear { if session.phase != .saving { session.cancel() } }
        }
        .tint(LearnAlertStyle.appAccentForeground)
    }

    private var chooseFile: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 20)
            AnkiConversionArtwork(progress: 0, active: false)
                .frame(height: 230)
            VStack(spacing: 8) {
                Text("Bring your decks along")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(LearnAlertStyle.textPrimary)
                Text("Cards, pictures, audio. All in one .apkg.")
                    .font(.subheadline)
                    .foregroundStyle(LearnAlertStyle.textSecondary)
                    .multilineTextAlignment(.center)
            }
            Button { showingFilePicker = true } label: {
                Label("Choose Anki file", systemImage: "folder")
                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 17)
                    .foregroundStyle(LearnAlertStyle.appAccentInk)
            }
            .buttonStyle(.borderedProminent).buttonBorderShape(.roundedRectangle(radius: 20))
            HStack(spacing: 6) {
                Image(systemName: "iphone")
                Text("Converted on your device")
            }
            .font(.caption).foregroundStyle(LearnAlertStyle.textSecondary)
            Spacer(minLength: 40)
        }
        .padding(.horizontal, 28)
    }

    private var converting: some View {
        VStack(spacing: 24) {
            AnkiConversionArtwork(progress: min(0.99, session.progress.fraction), active: true)
                .frame(height: 230)
            VStack(spacing: 12) {
                if let completed = session.completedFiles, let total = session.totalFiles {
                    Text("\(completed.formatted()) / \(total.formatted()) files")
                } else {
                    Text("— / — files")
                }
                Text(session.filePercentage.map { "\($0)%" } ?? "—%")
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(LearnAlertStyle.textPrimary)
            }
            .accessibilityElement(children: .combine)
        }
        .font(.title3.monospacedDigit())
        .foregroundStyle(LearnAlertStyle.textSecondary)
        .multilineTextAlignment(.center)
        .contentTransition(.numericText())
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
        .onAppear { session.savingViewDidAppear() }
    }

    private var review: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let package = session.package {
                    HStack {
                        Text(package.decks.count == 1 ? "Your deck" : "Your decks")
                            .font(.headline).foregroundStyle(LearnAlertStyle.textPrimary)
                        Spacer()
                        Button { showingDeckNames = true } label: {
                            Label("Edit names", systemImage: "pencil")
                                .font(.subheadline.weight(.medium))
                        }
                    }
                    HStack(spacing: 10) {
                        summary("\(session.selectedCardCount)", label: "cards", icon: "rectangle.on.rectangle")
                        summary("\(package.mediaCount)", label: "media", icon: "photo.on.rectangle")
                        summary(ByteCountFormatter.string(fromByteCount: Int64(package.mediaBytes), countStyle: .file), label: "media size", icon: "internaldrive")
                    }
                    VStack(spacing: 0) {
                        ForEach(package.decks) { deck in
                            Button {
                                if session.selectedDecks.contains(deck.id) { session.selectedDecks.remove(deck.id) }
                                else { session.selectedDecks.insert(deck.id) }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: session.selectedDecks.contains(deck.id) ? "checkmark.circle.fill" : "circle")
                                        .font(.title3).foregroundStyle(LearnAlertStyle.appAccentForeground)
                                    Text(session.deckNames[deck.id] ?? deck.name).font(.subheadline.weight(.medium)).foregroundStyle(LearnAlertStyle.textPrimary).multilineTextAlignment(.leading)
                                    Spacer(minLength: 4)
                                    Text("\(deck.cardCount)").font(.subheadline.monospacedDigit()).foregroundStyle(LearnAlertStyle.textSecondary)
                                }.padding(16).contentShape(Rectangle())
                            }.buttonStyle(.plain)
                            if deck.id != package.decks.last?.id { Divider().padding(.leading, 48) }
                        }
                    }.appCardSurface(cornerRadius: 20)

                    Button { showingSample = true } label: {
                        HStack {
                            Label("Preview cards", systemImage: "rectangle.on.rectangle.angled")
                            Spacer(); Image(systemName: "arrow.up.right")
                        }.font(.subheadline.weight(.semibold)).padding(17)
                    }
                    .buttonStyle(.plain).appCardSurface(cornerRadius: 18)
                    .disabled(session.selectedDecks.isEmpty)

                    if !package.warnings.isEmpty {
                        if package.skippedCards > 0 {
                            Label("\(package.skippedCards) cards couldn't be converted", systemImage: "exclamationmark.triangle")
                                .font(.footnote.weight(.medium)).foregroundStyle(.orange)
                        }
                        DisclosureGroup {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(package.warnings, id: \.self) { warning in
                                    Text(warning).font(.footnote).foregroundStyle(LearnAlertStyle.textSecondary)
                                }
                            }.padding(.top, 10)
                        } label: {
                            Label("\(package.warnings.count) compatibility notes", systemImage: "info.circle")
                                .font(.subheadline.weight(.medium))
                        }.padding(16).appCardSurface(cornerRadius: 18)
                    }
                }
            }.padding(20)
        }
        .safeAreaInset(edge: .bottom) {
            Button { session.save(container: context.container) } label: {
                Text("Import \(session.selectedCardCount) cards").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 17)
                    .foregroundStyle(LearnAlertStyle.appAccentInk)
            }
            .buttonStyle(.borderedProminent).buttonBorderShape(.roundedRectangle(radius: 18))
            .disabled(session.selectedDecks.isEmpty || !session.hasConfirmedDeckNames || !session.canConfirmDeckNames)
            .padding(.horizontal, 20).padding(.vertical, 12)
            .background(LearnAlertStyle.courseCanvas)
        }
    }

    private var deckNameEditor: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Give \(session.selectedDecks.count == 1 ? "your deck a name" : "your decks names") before adding \(session.selectedDecks.count == 1 ? "it" : "them") to your library.")
                        .font(.subheadline).foregroundStyle(LearnAlertStyle.textSecondary)
                    if let package = session.package {
                        ForEach(package.decks.filter { session.selectedDecks.contains($0.id) }) { deck in
                            VStack(alignment: .leading, spacing: 7) {
                                if session.selectedDecks.count > 1 {
                                    Text("\(deck.cardCount.formatted()) cards")
                                        .font(.caption).foregroundStyle(LearnAlertStyle.textSecondary)
                                }
                                TextField("Deck name", text: Binding(
                                    get: { session.deckNames[deck.id] ?? "" },
                                    set: { session.setDeckName($0, for: deck.id) }
                                ))
                                .font(.title3.weight(.semibold))
                                .textInputAutocapitalization(.sentences)
                                .submitLabel(.done)
                                .focused($focusedDeckName, equals: deck.id)
                                .padding(16)
                                .appCardSurface(cornerRadius: 16)
                            }
                        }
                    }
                }.padding(20)
            }
            .background(LearnAlertStyle.courseCanvas.ignoresSafeArea())
            .navigationTitle(session.selectedDecks.count == 1 ? "Name your deck" : "Name your decks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel import") {
                        showingDeckNames = false
                        session.cancel()
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    session.confirmDeckNames()
                    showingDeckNames = false
                } label: {
                    Text("Continue").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 15)
                        .foregroundStyle(LearnAlertStyle.appAccentInk)
                }
                .buttonStyle(.borderedProminent).buttonBorderShape(.roundedRectangle(radius: 18))
                .disabled(!session.canConfirmDeckNames)
                .padding(20).background(LearnAlertStyle.courseCanvas)
            }
            .task {
                focusedDeckName = session.package?.decks.first(where: { session.selectedDecks.contains($0.id) })?.id
            }
        }
        .tint(LearnAlertStyle.appAccentForeground)
        .interactiveDismissDisabled(!session.hasConfirmedDeckNames)
    }

    private func summary(_ value: String, label: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(LearnAlertStyle.appAccentForeground)
            Text(value).font(.headline).lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.caption).foregroundStyle(LearnAlertStyle.textSecondary)
        }.frame(maxWidth: .infinity).padding(.vertical, 16).appCardSurface(cornerRadius: 18)
    }

    private var complete: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: "checkmark.rectangle.stack.fill")
                .font(.system(size: 70, weight: .light)).foregroundStyle(LearnAlertStyle.appAccentForeground)
                .symbolEffect(.bounce, value: session.phase == .complete)
            Text("Added to your library")
                .font(.title.weight(.bold))
            if let result = session.result {
                Text(result.added > 0 ? "\(result.added.formatted()) cards added" : "These cards are already in your library.")
                    .font(.subheadline).foregroundStyle(LearnAlertStyle.textSecondary).multilineTextAlignment(.center)
            }
            Button("Go to library") { onFinish(); dismiss() }
                .font(.headline).foregroundStyle(LearnAlertStyle.appAccentInk).buttonStyle(.borderedProminent).controlSize(.large)
            Spacer(); Spacer().frame(height: 40)
        }.padding(28)
    }
}

private struct AnkiConversionArtwork: View {
    let progress: Double
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !active || reduceMotion)) { timeline in
            let time = active && !reduceMotion ? timeline.date.timeIntervalSinceReferenceDate : 0
            ZStack {
                Circle().fill(LearnAlertStyle.appAccent.opacity(0.09)).frame(width: 230, height: 230)
                ForEach(0..<3) { index in
                    let offset = Double(index - 1)
                    RoundedRectangle(cornerRadius: 24)
                        .fill(LearnAlertStyle.courseSurface)
                        .overlay { RoundedRectangle(cornerRadius: 24).stroke(LearnAlertStyle.appAccent.opacity(0.28), lineWidth: 1.5) }
                        .frame(width: 120, height: 156)
                        .rotationEffect(.degrees(offset * 16 + sin(time * 1.4 + Double(index)) * (active ? 3 : 0)))
                        .offset(x: offset * 34, y: abs(offset) * 9 + sin(time * 1.8 + Double(index)) * (active ? 5 : 0))
                }
                RoundedRectangle(cornerRadius: 24)
                    .fill(LearnAlertStyle.courseSurface)
                    .overlay(alignment: .bottom) {
                        AnkiLiquidShape(level: active ? 0.12 + min(1, progress) * 0.88 : 0.12, phase: time * 1.8)
                            .fill(LinearGradient(colors: [LearnAlertStyle.appAccent.opacity(0.35), LearnAlertStyle.appAccent.opacity(0.85)], startPoint: .top, endPoint: .bottom))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay { RoundedRectangle(cornerRadius: 24).stroke(LearnAlertStyle.appAccent.opacity(0.5), lineWidth: 1.5) }
                    .overlay {
                        Image(systemName: progress >= 1 ? "checkmark" : "square.and.arrow.down")
                            .font(.system(size: 35, weight: .light)).foregroundStyle(LearnAlertStyle.appAccentForeground)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .frame(width: 120, height: 156)
                    .shadow(color: LearnAlertStyle.appAccent.opacity(0.12), radius: 20, y: 12)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.4), value: progress)
                if active {
                    Image(systemName: "photo.fill").font(.title3)
                        .foregroundStyle(LearnAlertStyle.appAccentForeground.opacity(0.7))
                        .offset(x: -96, y: sin(time * 1.3) * 9 - 46)
                    Image(systemName: "waveform").font(.title3)
                        .foregroundStyle(LearnAlertStyle.appAccentForeground.opacity(0.7))
                        .offset(x: 98, y: cos(time * 1.3) * 9 + 28)
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }.accessibilityHidden(true)
    }
}

private struct AnkiLiquidShape: Shape {
    var level: Double
    var phase: Double
    var animatableData: Double { get { level } set { level = newValue } }
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let baseline = rect.height * (1 - level)
        path.move(to: CGPoint(x: 0, y: baseline))
        for x in stride(from: 0.0, through: rect.width, by: 2) {
            path.addLine(to: CGPoint(x: x, y: baseline + sin(x / rect.width * .pi * 2 + phase) * 5))
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY)); path.addLine(to: CGPoint(x: 0, y: rect.maxY)); path.closeSubpath()
        return path
    }
}

private struct AnkiPreviewView: View {
    let cards: [AnkiImportedCard]
    let mediaDirectory: URL
    @State private var index = 0
    @State private var showingBack = false
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if cards.indices.contains(index) {
                    let card = cards[index]
                    Picker("Side", selection: $showingBack) { Text("Front").tag(false); Text("Back").tag(true) }
                        .pickerStyle(.segmented).padding(.horizontal, 20)
                    AnkiCardView(content: AnkiCardContent(frontHTML: card.front, backHTML: card.back, css: card.css, mediaFolder: "", templateOrdinal: card.templateOrdinal, noteType: card.noteType, tags: card.tags), showingBack: showingBack, mediaDirectory: mediaDirectory)
                        .clipShape(RoundedRectangle(cornerRadius: 20)).padding(.horizontal, 20)
                    HStack {
                        Button { index -= 1; showingBack = false } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }.disabled(index == 0)
                        Spacer(); Text("\(index + 1) / \(cards.count)").font(.subheadline.monospacedDigit()); Spacer()
                        Button { index += 1; showingBack = false } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }.disabled(index + 1 >= cards.count)
                    }.padding(.horizontal, 20)
                }
            }.background(LearnAlertStyle.courseCanvas)
                .navigationTitle("Preview").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
}
