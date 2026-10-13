import SwiftUI
import SwiftData
import AVFoundation
import Combine

extension Notification.Name {
    static let communityLibraryChanged = Notification.Name("communityLibraryChanged")
}

@MainActor
final class CommunityFeedStore: ObservableObject {
    static let pageSize = 6
    @Published var search = ""
    @Published var category = "All"
    @Published var sort: CommunityDeckSort = .popular
    @Published private(set) var decks: [CommunityDeckPayload] = []
    @Published private(set) var currentPage = 1
    @Published private(set) var totalCount = 0
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    private var requestID = UUID()
    private let api: CommunityAPI
    private struct Query: Equatable {
        let search: String
        let category: String
        let sort: CommunityDeckSort
    }
    private var loadedQuery: Query?
    private var query: Query { Query(search: search, category: category, sort: sort) }
    var pageCount: Int { max(1, (totalCount + Self.pageSize - 1) / Self.pageSize) }
    var canChangePage: Bool { !isLoading && loadedQuery == query }

    init(api: CommunityAPI = CommunityAPI()) { self.api = api }

    func load(page requestedPage: Int = 1) async {
        let id = UUID(); requestID = id
        let selectedQuery = query
        let target = max(1, requestedPage)
        isLoading = true; errorMessage = nil
        defer { if requestID == id { isLoading = false } }
        do {
            let page = try await api.list(search: selectedQuery.search, category: selectedQuery.category,
                offset: (target - 1) * Self.pageSize, sort: selectedQuery.sort, limit: Self.pageSize)
            guard !Task.isCancelled, requestID == id, query == selectedQuery else { return }
            let count = max(0, page.totalCount ?? ((target - 1) * Self.pageSize + page.decks.count + (page.nextOffset == nil ? 0 : 1)))
            let lastPage = max(1, (count + Self.pageSize - 1) / Self.pageSize)
            // A removal can shrink the last page while it is being viewed.
            if target > lastPage { await load(page: lastPage); return }
            decks = page.decks
            currentPage = target; totalCount = count; loadedQuery = selectedQuery
        } catch {
            guard !Task.isCancelled, requestID == id, query == selectedQuery else { return }
            errorMessage = error.localizedDescription
        }
    }
}

struct CommunityFeedView: View {
    @ObservedObject var store: CommunityFeedStore
    let libraryDecks: [Deck]
    let onAddDeck: (PremadeDeck) -> Void
    let onShare: () -> Void
    var showsSearchField = true
    var showsTitle = true
    var showsPageSelector = true
    @Namespace private var sortNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var session = CommunitySession.shared
    @State private var selectedPreview: CommunityDeckPayload?
    @State private var downloadingID: String?
    @State private var downloadProgress = ""
    @State private var message: String?
    static let categories = ["All", "General", "Medical", "Coding", "Languages", "Law", "Science", "Math", "History", "Exam Prep"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                if showsTitle { Text("Community decks").font(.title3.weight(.semibold)) }
                else { sortSelector }
                Spacer(minLength: 4)
                categoryFilter
            }
            if showsTitle { sortSelector }
            if showsSearchField {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(LearnAlertStyle.textSecondary)
                    TextField("Search decks", text: $store.search).textInputAutocapitalization(.never).autocorrectionDisabled().submitLabel(.search)
                    if !store.search.isEmpty {
                        Button { store.search = "" } label: { Image(systemName: "xmark.circle.fill").frame(width: 44, height: 44) }.accessibilityLabel("Clear search")
                    }
                }
                .font(.subheadline).padding(.horizontal, 12).frame(minHeight: 48)
                .background(LearnAlertStyle.insetSurface, in: RoundedRectangle(cornerRadius: 14))
            }
            if store.isLoading && store.decks.isEmpty {
                ProgressView("Loading decks…").frame(maxWidth: .infinity, minHeight: 140)
            } else if let error = store.errorMessage {
                VStack(spacing: 12) {
                    Text(error).font(.subheadline).foregroundStyle(LearnAlertStyle.textSecondary).multilineTextAlignment(.center)
                    Button("Try again") { Task { await store.load() } }.frame(minHeight: 44)
                }.frame(maxWidth: .infinity).padding(20).appCardSurface(cornerRadius: 20)
            } else if store.decks.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "rectangle.stack").font(.system(size: 30)).foregroundStyle(LearnAlertStyle.appAccentForeground)
                    Text(store.search.isEmpty && store.category == "All" ? "No community decks yet" : "No matching decks").font(.headline)
                    if !store.search.isEmpty || store.category != "All" {
                        Button("Clear filters") { store.search = ""; store.category = "All" }.frame(minHeight: 44)
                    }
                }.frame(maxWidth: .infinity).padding(24).appCardSurface(cornerRadius: 20)
            }
            VStack(spacing: 4) {
                LazyVStack(spacing: 12) {
                    ForEach(store.decks) { deck in
                        CommunityDeckCard(deck: deck, isAdded: isAdded(deck), isDownloading: downloadingID == deck.id,
                            progress: downloadingID == deck.id ? downloadProgress : "",
                            open: { selectedPreview = deck }, download: { Task { await download(deck) } })
                            .contextMenu { Button("Report deck", systemImage: "flag") { Task { await report(deck) } } }
                    }
                }
                if showsPageSelector && store.totalCount > 0 { CommunityDeckPageSelector(store: store) }
            }
        }
        .foregroundStyle(LearnAlertStyle.textPrimary).tint(LearnAlertStyle.appAccentForeground)
        .task(id: "\(store.sort.rawValue):\(store.category):\(store.search)") {
            do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
            await store.load()
        }
        .onReceive(NotificationCenter.default.publisher(for: .communityLibraryChanged)) { _ in Task { await store.load() } }
        .sheet(item: $selectedPreview) { deck in
            CommunityDeckPreviewSheet(deck: deck, isAdded: isAdded(deck), isDownloading: downloadingID == deck.id,
                progress: downloadProgress, download: { Task { await download(deck) } })
        }
        .alert("Community decks", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
    }

    private var sortSelector: some View {
        HStack(spacing: 16) {
            ForEach(CommunityDeckSort.allCases, id: \.rawValue) { sort in
                let selected = store.sort == sort
                Button {
                    guard !selected else { return }
                    HapticFeedback.impact(.light)
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { store.sort = sort }
                } label: {
                    Text(sort.title).font(.subheadline.weight(selected ? .semibold : .medium))
                        .foregroundStyle(selected ? LearnAlertStyle.appAccentForeground : LearnAlertStyle.textSecondary)
                        .frame(minHeight: 44)
                        .overlay(alignment: .bottom) {
                            if selected {
                                Capsule().fill(LearnAlertStyle.appAccentForeground).frame(height: 3)
                                    .matchedGeometryEffect(id: "sort", in: sortNamespace)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(sort.title) community decks")
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    private var categoryFilter: some View {
        Menu {
            Picker("Category", selection: $store.category) {
                ForEach(Self.categories, id: \.self) { Text($0).tag($0) }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "line.3.horizontal.decrease")
                if store.category != "All" { Text(store.category).lineLimit(1) }
                Image(systemName: "chevron.down").font(.caption2.weight(.semibold))
            }
            .font(.subheadline.weight(.medium)).padding(.horizontal, 12).frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Filter community decks").accessibilityValue(store.category)
    }

    private func isAdded(_ deck: CommunityDeckPayload) -> Bool { libraryDecks.contains { $0.sourceCommunityID == deck.id } }
    @MainActor private func download(_ deck: CommunityDeckPayload) async {
        guard downloadingID == nil, !isAdded(deck) else { return }
        downloadingID = deck.id; downloadProgress = "Downloading deck…"
        defer { downloadingID = nil }
        do {
            let downloaded = try await CommunityDeckTransfer.download(deck) { downloadProgress = $0 }
            selectedPreview = nil; onAddDeck(downloaded)
        } catch { message = error.localizedDescription }
    }
    @MainActor private func report(_ deck: CommunityDeckPayload) async {
        guard let token = session.token else { message = "Sign in with Apple in Settings before reporting a deck."; return }
        do {
            try await CommunityAPI().report(deckID: deck.id, reason: "Reported by a learner for review.", token: token)
            message = "Your report has been saved for review."
        } catch { session.handle(error); message = error.localizedDescription }
    }
}

/// A shared compact pager, used inline or in Discover's persistent footer.
struct CommunityDeckPageSelector: View {
    @ObservedObject var store: CommunityFeedStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var pageItems: [Int] {
        let count = store.pageCount
        let current = store.currentPage
        if count <= 5 { return Array(1...count) }
        if current <= 3 { return [1, 2, 3, -1, count] }
        if current >= count - 2 { return [1, -1, count - 2, count - 1, count] }
        return [1, -1, current, -2, count]
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 0) {
                pageArrow(forward: false)
                ForEach(pageItems, id: \.self) { page in
                    if page < 0 {
                        Text("…").font(.caption).foregroundStyle(LearnAlertStyle.textSecondary)
                            .frame(width: 16).accessibilityHidden(true)
                    } else {
                        Button { changePage(page) } label: {
                            Text("\(page)").font(.caption.weight(.semibold)).monospacedDigit()
                                .foregroundStyle(page == store.currentPage ? LearnAlertStyle.appAccentInk : LearnAlertStyle.textSecondary)
                                .frame(width: 32, height: 32)
                                .background {
                                    if page == store.currentPage {
                                        RoundedRectangle(cornerRadius: 6).fill(LearnAlertStyle.appAccent)
                                            .frame(width: 24, height: 20)
                                    }
                                }
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Page \(page) of \(store.pageCount)")
                        .accessibilityAddTraits(page == store.currentPage ? .isSelected : [])
                    }
                }
                pageArrow(forward: true)
            }
            .fixedSize(horizontal: true, vertical: false)
            HStack(spacing: 8) {
                pageArrow(forward: false)
                Text("\(store.currentPage) / \(store.pageCount)").font(.caption.weight(.semibold)).monospacedDigit()
                pageArrow(forward: true)
            }
        }
        .disabled(!store.canChangePage)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Community deck pages")
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: store.currentPage)
    }

    private func pageArrow(forward: Bool) -> some View {
        Button { changePage(store.currentPage + (forward ? 1 : -1)) } label: {
            Image(systemName: forward ? "chevron.right" : "chevron.left")
                .font(.system(size: 11, weight: .semibold)).frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(forward ? store.currentPage >= store.pageCount : store.currentPage <= 1)
        .accessibilityLabel(forward ? "Next page" : "Previous page")
    }

    private func changePage(_ page: Int) {
        guard store.canChangePage, page != store.currentPage, (1...store.pageCount).contains(page) else { return }
        HapticFeedback.impact(.light)
        Task { await store.load(page: page) }
    }

}

struct CommunityDeckCard: View {
    let deck: CommunityDeckPayload
    var isAdded = false
    var isDownloading = false
    var progress = ""
    let open: () -> Void
    let download: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: open) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "rectangle.stack.fill").font(.system(size: 18))
                        .foregroundStyle(Color(hex: deck.colorHex)).frame(width: 36, height: 40)
                        .background(Color(hex: deck.colorHex).opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 8) {
                        Text(deck.name).font(.headline).multilineTextAlignment(.leading)
                        Text(deck.authorHandle).font(.caption).lineLimit(1)
                            .foregroundStyle(LearnAlertStyle.textSecondary)
                        if !deck.description.isEmpty { Text(deck.description).font(.subheadline).foregroundStyle(LearnAlertStyle.textSecondary).lineLimit(2).multilineTextAlignment(.leading) }
                        Text("\(deck.cardCount) cards").font(.caption).foregroundStyle(LearnAlertStyle.textSecondary)
                        if !progress.isEmpty { Text(progress).font(.caption).foregroundStyle(LearnAlertStyle.appAccentForeground) }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                .foregroundStyle(LearnAlertStyle.textPrimary).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityHint("Preview this deck")
            VStack(alignment: .trailing, spacing: 8) {
                Button(action: download) {
                    if isDownloading { ProgressView().frame(width: 44, height: 44) }
                    else { Image(systemName: isAdded ? "checkmark.circle.fill" : "arrow.down.circle.fill").font(.system(size: 25)).frame(width: 44, height: 44) }
                }
                .buttonStyle(.plain).tint(LearnAlertStyle.appAccentForeground)
                .disabled(isAdded || isDownloading).accessibilityLabel(isAdded ? "Already in your library" : "Add \(deck.name) to your library")
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down").font(.system(size: 10, weight: .semibold))
                    Text(deck.downloadCount.formatted()).monospacedDigit()
                }
                .font(.caption).foregroundStyle(LearnAlertStyle.textSecondary)
                .fixedSize()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(deck.downloadCount) downloads")
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).appCardSurface(cornerRadius: 20)
    }
}

struct AllCommunityDecksView: View {
    let libraryDecks: [Deck]
    var initialSearch = ""
    let onAddDeck: (PremadeDeck) -> Void
    let onOpenShareModal: () -> Void
    @StateObject private var store = CommunityFeedStore()
    var body: some View {
        ScrollView { CommunityFeedView(store: store, libraryDecks: libraryDecks, onAddDeck: onAddDeck, onShare: onOpenShareModal).padding(20).padding(.bottom, 100) }
            .background(LearnAlertStyle.courseCanvas.ignoresSafeArea()).navigationTitle("Community decks")
            .navigationBarTitleDisplayMode(.inline).onAppear { store.search = initialSearch }
            .refreshable { await store.load() }
    }
}

struct CommunityDeckPreviewSheet: View {
    let deck: CommunityDeckPayload
    var isAdded = false
    var isDownloading = false
    var progress = ""
    let download: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var preview: CommunityDeckPayload?
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 12) {
                        CommunityAvatarView(avatar: deck.authorAvatar ?? .init()).frame(width: 48, height: 48)
                        VStack(alignment: .leading, spacing: 4) { Text(deck.name).font(.title2.weight(.bold)); Text(deck.authorHandle).font(.subheadline).foregroundStyle(LearnAlertStyle.textSecondary) }
                    }
                    if !deck.description.isEmpty { Text(deck.description).font(.body) }
                    Text("\(deck.cardCount) cards · \(deck.downloadCount.formatted()) downloads").font(.subheadline).foregroundStyle(LearnAlertStyle.textSecondary)
                    if let error { Text(error).foregroundStyle(LearnAlertStyle.destructiveRed); Button("Try again") { Task { await load() } }.frame(minHeight: 44) }
                    else if let cards = preview?.cards {
                        ForEach(cards) { CommunitySampleCardView(card: $0) }
                    } else { ProgressView().frame(maxWidth: .infinity, minHeight: 100) }
                }.padding(24).frame(maxWidth: 560).frame(maxWidth: .infinity)
            }
            .background(LearnAlertStyle.courseCanvas.ignoresSafeArea()).foregroundStyle(LearnAlertStyle.textPrimary)
            .navigationTitle("Deck preview").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    if isDownloading { ProgressView(progress).font(.caption) }
                    Button(action: download) { Label(isAdded ? "In your library" : "Add to library", systemImage: isAdded ? "checkmark" : "arrow.down").frame(maxWidth: .infinity, minHeight: 48) }
                        .buttonStyle(.borderedProminent).tint(LearnAlertStyle.appAccent).foregroundStyle(LearnAlertStyle.appAccentInk).disabled(isAdded || isDownloading)
                }.padding(16).background(LearnAlertStyle.courseSurface)
            }
            .task { await load() }
        }
    }
    @MainActor private func load() async {
        error = nil
        do { preview = try await CommunityAPI().preview(deckID: deck.id) }
        catch { if !Task.isCancelled { self.error = error.localizedDescription } }
    }
}

private struct CommunityRemoteImage: View {
    let id: String
    @State private var image: UIImage?
    var body: some View {
        Group {
            if let image { Image(uiImage: image).resizable().scaledToFit() }
            else { Image(systemName: "photo").font(.largeTitle).foregroundStyle(LearnAlertStyle.textSecondary).frame(maxWidth: .infinity, minHeight: 64) }
        }
        .frame(maxHeight: 160).clipShape(RoundedRectangle(cornerRadius: 12))
        .task(id: id) { if let data = try? await CommunityAPI().media(id: id, maximumBytes: 10 * 1024 * 1024), !Task.isCancelled { image = UIImage(data: data) } }
    }
}

private struct CommunityPreviewAudio: View {
    var mediaID: String? = nil
    var localName: String? = nil
    @State private var player: AVAudioPlayer?
    @State private var task: Task<Void, Never>?
    @State private var isLoading = false
    @State private var error: String?
    var body: some View {
        VStack(alignment: .leading) {
            Button {
                task?.cancel(); player?.stop(); isLoading = true; error = nil
                task = Task {
                    defer { isLoading = false }
                    do {
                        let data: Data
                        if let mediaID { data = try await CommunityAPI().media(id: mediaID, maximumBytes: CardAudioStore.maximumBytes) }
                        else if let localName { data = try Data(contentsOf: CardAudioStore.url(named: localName)) }
                        else { return }
                        try Task.checkCancellation()
                        player = try AVAudioPlayer(data: data); player?.play()
                    } catch { if !Task.isCancelled { self.error = "Audio could not play." } }
                }
            } label: { HStack { if isLoading { ProgressView() }; Label("Listen", systemImage: "speaker.wave.2.fill") }.frame(minHeight: 44) }
            .disabled(isLoading).tint(LearnAlertStyle.appAccentForeground)
            if let error { Text(error).font(.caption).foregroundStyle(LearnAlertStyle.destructiveRed) }
        }.onDisappear { task?.cancel(); player?.stop() }
    }
}

struct CommunitySampleCardView: View {
    let card: CommunityCardPayload
    var localCard: Flashcard? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(card.question).font(.body.weight(.medium))
            if let localCard, let image = CardImageStore.loadImage(named: localCard.promptImageName) { Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 160).clipShape(RoundedRectangle(cornerRadius: 12)) }
            else if let id = card.promptImageID { CommunityRemoteImage(id: id) }
            if let name = localCard?.promptAudioName { CommunityPreviewAudio(localName: name) }
            else if let id = card.promptAudioID { CommunityPreviewAudio(mediaID: id) }
            ForEach(Array(card.options.enumerated()), id: \.offset) { index, option in
                HStack(spacing: 12) {
                    if let localCard, localCard.optionImageNames.indices.contains(index), let image = CardImageStore.loadImage(named: localCard.optionImageNames[index]) { Image(uiImage: image).resizable().scaledToFit().frame(width: 54, height: 54) }
                    else if card.optionImageIDs.indices.contains(index), let id = card.optionImageIDs[index] { CommunityRemoteImage(id: id).frame(width: 54, height: 54) }
                    Text(option).font(.subheadline)
                }
            }
            DisclosureGroup("Show answer") {
                if card.cardType == "matching" {
                    ForEach(Array(card.matchingLeftItems.enumerated()), id: \.offset) { index, item in
                        if card.matchingRightItems.indices.contains(index) { Text("\(item) → \(card.matchingRightItems[index])").frame(maxWidth: .infinity, alignment: .leading) }
                    }
                } else { Text(card.correctAnswer).frame(maxWidth: .infinity, alignment: .leading) }
            }.font(.subheadline).tint(LearnAlertStyle.appAccentForeground)
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading).appCardSurface(cornerRadius: 20)
    }
}

struct ShareDeckToCommunitySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let libraryDecks: [Deck]
    var initialDeckID: UUID? = nil
    @ObservedObject private var session = CommunitySession.shared
    @State private var selectedDeckID: UUID?
    @State private var category = "General"
    @State private var deckDescription = ""
    @State private var isPublishing = false
    @State private var progress = ""
    @State private var isPublished = false
    @State private var publishError: String?
    @State private var showingProfile = false
    @State private var showingPreview = false
    private var availableDecks: [Deck] { libraryDecks.filter(\.canShareToCommunity) }
    private var selectedDeck: Deck? { availableDecks.first { $0.id == selectedDeckID } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if availableDecks.isEmpty {
                        ContentUnavailableView("Create a deck first", systemImage: "rectangle.stack", description: Text("Share a deck you created. Built-in and downloaded community decks can’t be republished."))
                    } else {
                        Menu {
                            ForEach(availableDecks) { deck in Button(deck.name) { selectedDeckID = deck.id } }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "rectangle.stack.fill").font(.title2).foregroundStyle(selectedDeck.map { Color(hex: $0.colorHex) } ?? LearnAlertStyle.appAccentForeground)
                                VStack(alignment: .leading, spacing: 3) { Text(selectedDeck?.name ?? "Choose a deck").font(.headline); Text("From your library").font(.caption).foregroundStyle(LearnAlertStyle.textSecondary) }
                                Spacer(); Image(systemName: "chevron.up.chevron.down").font(.caption.weight(.semibold))
                            }.foregroundStyle(LearnAlertStyle.textPrimary).padding(16).appCardSurface(cornerRadius: 20)
                        }.disabled(isPublishing)
                        if let deck = selectedDeck {
                            listingPreview(deck)
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Category").font(.subheadline.weight(.medium)); Spacer()
                                    Picker("Category", selection: $category) { ForEach(CommunityFeedView.categories.filter { $0 != "All" }, id: \.self) { Text($0).tag($0) } }.pickerStyle(.menu)
                                }
                                Divider()
                                TextField("A short description", text: $deckDescription, axis: .vertical).lineLimit(2...4)
                                    .font(.body).textInputAutocapitalization(.sentences)
                            }.padding(16).appCardSurface(cornerRadius: 20).disabled(isPublishing)
                            if deck.cards.count > 500 { Text("Share up to 500 cards in one deck.").font(.caption).foregroundStyle(LearnAlertStyle.destructiveRed) }
                        }
                    }
                    if let error = publishError { Text(error).font(.subheadline).foregroundStyle(LearnAlertStyle.destructiveRed) }
                }.padding(20).frame(maxWidth: 560).frame(maxWidth: .infinity)
            }
            .background(LearnAlertStyle.courseCanvas.ignoresSafeArea()).foregroundStyle(LearnAlertStyle.textPrimary).tint(LearnAlertStyle.appAccentForeground)
            .navigationTitle(isPublished ? "Deck shared" : "Share a deck").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.disabled(isPublishing) } }
            .safeAreaInset(edge: .bottom) {
                if selectedDeck != nil {
                    VStack(spacing: 10) {
                        if isPublishing { ProgressView(progress).font(.caption) }
                        Text("Cards and media are public. Study history stays private.").font(.caption).foregroundStyle(LearnAlertStyle.textSecondary).multilineTextAlignment(.center)
                        Button { beginPublish() } label: {
                            Label(isPublished ? "Published" : selectedDeck?.publishedCommunityID == nil ? "Publish deck" : "Update public deck", systemImage: isPublished ? "checkmark.circle.fill" : "square.and.arrow.up")
                                .font(.body.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 48)
                        }.buttonStyle(.borderedProminent).tint(LearnAlertStyle.appAccent).foregroundStyle(LearnAlertStyle.appAccentInk)
                            .disabled(isPublishing || isPublished || selectedDeck?.cards.isEmpty == true || (selectedDeck?.cards.count ?? 0) > 500)
                    }.padding(16).background(LearnAlertStyle.courseSurface)
                }
            }
            .interactiveDismissDisabled(isPublishing)
            .onAppear { if selectedDeckID == nil { selectedDeckID = availableDecks.first(where: { $0.id == initialDeckID })?.id ?? availableDecks.first?.id; loadMetadata() } }
            .onChange(of: selectedDeckID) { _, _ in loadMetadata() }
            .onChange(of: category) { _, _ in isPublished = false }
            .onChange(of: deckDescription) { _, _ in isPublished = false }
            .sheet(isPresented: $showingProfile) {
                CommunityProfileSheet(saveTitle: "Save & publish", onSave: { showingProfile = false; Task { await publish() } })
            }
            .sheet(isPresented: $showingPreview) { if let deck = selectedDeck { LocalCommunityPreviewSheet(deck: deck) } }
        }
    }

    private func listingPreview(_ deck: Deck) -> some View {
        let images = deck.cards.reduce(0) { $0 + ($1.promptImageName == nil ? 0 : 1) + $1.optionImageNames.filter { !$0.isEmpty }.count }
        let audio = deck.cards.filter { $0.promptAudioName != nil }.count
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                if session.isSignedIn && session.profile.isComplete { CommunityAvatarView(avatar: session.profile.avatar).frame(width: 32, height: 32) }
                Text(session.isSignedIn ? session.handle : "Your public preview").font(.subheadline).foregroundStyle(LearnAlertStyle.textSecondary)
            }
            Text(deck.name).font(.title3.weight(.semibold))
            if !deckDescription.isEmpty { Text(deckDescription).font(.subheadline).foregroundStyle(LearnAlertStyle.textSecondary) }
            HStack(spacing: 12) {
                Label("\(deck.cards.count)", systemImage: "rectangle.stack")
                if images > 0 { Label("\(images)", systemImage: "photo") }
                if audio > 0 { Label("\(audio)", systemImage: "speaker.wave.2") }
            }.font(.caption).foregroundStyle(LearnAlertStyle.textSecondary)
            Button { showingPreview = true } label: { Label("Preview cards", systemImage: "eye").font(.subheadline.weight(.medium)).frame(minHeight: 44) }
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading).appCardSurface(cornerRadius: 20)
    }
    private func loadMetadata() {
        category = selectedDeck?.communityCategory ?? "General"; deckDescription = selectedDeck?.communityDescription ?? ""
        isPublished = false; publishError = nil
    }
    private func beginPublish() {
        if !session.isSignedIn || session.needsProfileSetup { showingProfile = true }
        else { Task { await publish() } }
    }
    @MainActor private func publish() async {
        guard let deck = selectedDeck, let token = session.token, !isPublishing else { return }
        isPublishing = true; publishError = nil
        defer { isPublishing = false }
        do {
            let id = try await CommunityDeckTransfer.publish(deck: deck, category: category, description: deckDescription, token: token) { progress = $0 }
            deck.publishedCommunityID = id; deck.communityCategory = category; deck.communityDescription = deckDescription
            try context.save(); isPublished = true; HapticFeedback.success()
            NotificationCenter.default.post(name: .communityLibraryChanged, object: nil)
        } catch { session.handle(error); publishError = error.localizedDescription }
    }
}

private struct LocalCommunityPreviewSheet: View {
    let deck: Deck
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(Array(deck.cards.sorted { $0.orderIndex < $1.orderIndex }.prefix(5))) { card in
                        CommunitySampleCardView(card: CommunityCardPayload(id: card.id.uuidString, question: card.question, correctAnswer: card.correctAnswer,
                            options: card.options, hint: card.hint, cardType: card.cardType.rawValue, matchingLeftItems: card.matchingLeftItems,
                            matchingRightItems: card.matchingRightItems, sectionName: card.section?.name ?? "", optionImageIDs: []), localCard: card)
                    }
                }.padding(20)
            }.background(LearnAlertStyle.courseCanvas.ignoresSafeArea()).foregroundStyle(LearnAlertStyle.textPrimary)
                .navigationTitle("Card preview").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

struct MySharedDecksSheet: View {
    let libraryDecks: [Deck]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @ObservedObject private var session = CommunitySession.shared
    @State private var decks: [CommunityDeckPayload] = []
    @State private var isLoading = true
    @State private var message: String?
    @State private var editingDeck: Deck?
    @State private var removingDeck: CommunityDeckPayload?
    @State private var isRemoving = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if isLoading { ProgressView("Loading your decks…").frame(minHeight: 120) }
                    else if decks.isEmpty { ContentUnavailableView("No shared decks yet", systemImage: "rectangle.stack") }
                    ForEach(decks) { deck in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(deck.name).font(.headline); Text("\(deck.cardCount) cards · \(deck.downloadCount.formatted()) downloads").font(.subheadline).foregroundStyle(LearnAlertStyle.textSecondary)
                            HStack {
                                if let local = libraryDecks.first(where: { $0.publishedCommunityID == deck.id && $0.canShareToCommunity }) { Button("Edit", systemImage: "pencil") { editingDeck = local }.frame(minHeight: 44) }
                                Spacer()
                                Button("Remove", systemImage: "trash", role: .destructive) { removingDeck = deck }.frame(minHeight: 44)
                            }.disabled(isRemoving)
                        }.padding(16).frame(maxWidth: .infinity, alignment: .leading).appCardSurface(cornerRadius: 20)
                    }
                    if let message { Text(message).font(.subheadline).foregroundStyle(LearnAlertStyle.destructiveRed); Button("Try again") { Task { await load() } }.frame(minHeight: 44) }
                }.padding(20)
            }.background(LearnAlertStyle.courseCanvas.ignoresSafeArea()).foregroundStyle(LearnAlertStyle.textPrimary).tint(LearnAlertStyle.appAccentForeground)
                .navigationTitle("My shared decks").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.disabled(isRemoving) } }
                .task { await load() }.refreshable { await load() }
                .onReceive(NotificationCenter.default.publisher(for: .communityLibraryChanged)) { _ in Task { await load() } }
                .sheet(item: $editingDeck) { ShareDeckToCommunitySheet(libraryDecks: libraryDecks, initialDeckID: $0.id) }
                .confirmationDialog("Remove this public deck?", isPresented: Binding(get: { removingDeck != nil }, set: { if !$0 { removingDeck = nil } }), titleVisibility: .visible) {
                    Button("Remove public deck", role: .destructive) { if let deck = removingDeck { Task { await remove(deck) } } }
                } message: { Text("Your personal deck and copies already downloaded by other learners remain in their libraries.") }
                .interactiveDismissDisabled(isRemoving)
        }
    }
    @MainActor private func load() async {
        guard let token = session.token else { isLoading = false; message = "Sign in with Apple to see your shared decks."; return }
        isLoading = true; message = nil
        defer { isLoading = false }
        do {
            let page = try await CommunityAPI().myDecks(token: token)
            guard session.token == token else { return }
            decks = page.decks
        }
        catch { session.handle(error); message = error.localizedDescription }
    }
    @MainActor private func remove(_ deck: CommunityDeckPayload) async {
        guard let token = session.token, !isRemoving else { return }
        isRemoving = true; message = nil
        defer { isRemoving = false; removingDeck = nil }
        do {
            try await CommunityAPI().remove(deckID: deck.id, token: token)
            for local in libraryDecks where local.publishedCommunityID == deck.id { local.publishedCommunityID = nil }
            try context.save(); decks.removeAll { $0.id == deck.id }
            NotificationCenter.default.post(name: .communityLibraryChanged, object: nil)
        } catch { session.handle(error); message = error.localizedDescription }
    }
}
