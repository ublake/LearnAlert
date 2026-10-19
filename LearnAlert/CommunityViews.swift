import SwiftUI
import SwiftData
import AVFoundation
import Combine

extension Notification.Name {
    static let communityLibraryChanged = Notification.Name("communityLibraryChanged")
}

@MainActor
final class CommunityFeedStore: ObservableObject {
    static let pageSize = 20
    @Published var search = "" { didSet { if oldValue != search { invalidate() } } }
    @Published var category = "All" { didSet { if oldValue != category { invalidate() } } }
    @Published var sort: CommunityDeckSort = .popular { didSet { if oldValue != sort { invalidate() } } }
    @Published private(set) var decks: [CommunityDeckPayload] = []
    @Published private(set) var totalCount = 0
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var hasLoaded = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var loadMoreErrorMessage: String?
    private var requestID = UUID()
    private let api: CommunityAPI
    private var viewerToken: String?
    private var nextOffset: Int?
    private struct Query: Equatable {
        let search: String
        let category: String
        let sort: CommunityDeckSort
        let token: String?
    }
    private var loadedQuery: Query?
    private var query: Query { Query(search: search, category: category, sort: sort, token: viewerToken) }
    var hasMore: Bool { nextOffset != nil && loadedQuery == query }
    var canLoadMore: Bool { hasMore && !isLoading && !isLoadingMore }
    var paginationID: String { "\(requestID)-\(nextOffset ?? -1)" }

    init(api: CommunityAPI? = nil) { self.api = api ?? CommunityAPI() }

    func setViewer(token: String?) {
        guard viewerToken != token else { return }
        viewerToken = token
        invalidate()
    }

    private func invalidate() {
        requestID = UUID()
        decks = []; totalCount = 0; nextOffset = nil; loadedQuery = nil
        isLoading = false; isLoadingMore = false; hasLoaded = false
        errorMessage = nil; loadMoreErrorMessage = nil
    }

    func load() async {
        let id = UUID(); requestID = id
        let selectedQuery = query
        isLoading = true; isLoadingMore = false
        errorMessage = nil; loadMoreErrorMessage = nil
        defer { if requestID == id { isLoading = false } }
        do {
            let page = try await api.list(search: selectedQuery.search, category: selectedQuery.category,
                offset: 0, sort: selectedQuery.sort, limit: Self.pageSize, token: selectedQuery.token)
            guard !Task.isCancelled, requestID == id, query == selectedQuery else { return }
            try validateNextOffset(page.nextOffset, after: 0)
            decks = unique(page.decks)
            nextOffset = page.nextOffset
            totalCount = max(decks.count, page.totalCount ?? decks.count)
            loadedQuery = selectedQuery; hasLoaded = true
        } catch {
            guard !Task.isCancelled, requestID == id, query == selectedQuery else { return }
            errorMessage = error.localizedDescription
        }
    }

    func loadNextPage() async {
        guard canLoadMore, let offset = nextOffset else { return }
        let id = requestID
        let selectedQuery = query
        isLoadingMore = true; loadMoreErrorMessage = nil
        defer { if requestID == id { isLoadingMore = false } }
        do {
            let page = try await api.list(search: selectedQuery.search, category: selectedQuery.category,
                offset: offset, sort: selectedQuery.sort, limit: Self.pageSize, token: selectedQuery.token)
            guard !Task.isCancelled, requestID == id, query == selectedQuery else { return }
            try validateNextOffset(page.nextOffset, after: offset)
            decks = unique(decks + page.decks)
            nextOffset = page.nextOffset
            totalCount = max(decks.count, page.totalCount ?? totalCount)
        } catch {
            guard !Task.isCancelled, requestID == id, query == selectedQuery else { return }
            loadMoreErrorMessage = error.localizedDescription
        }
    }

    private func unique(_ values: [CommunityDeckPayload]) -> [CommunityDeckPayload] {
        var seen = Set<String>()
        return values.filter { seen.insert($0.id).inserted }
    }

    private func validateNextOffset(_ next: Int?, after offset: Int) throws {
        if let next, next <= offset { throw URLError(.cannotParseResponse) }
    }
}

@MainActor
final class CommunityOwnedDeckStore: ObservableObject {
    @Published private(set) var decks: [CommunityDeckPayload] = []
    @Published private(set) var isLoading = true
    @Published private(set) var errorMessage: String?
    private var requestID = UUID()
    private var ownerToken: String?
    private let api: CommunityAPI

    init(api: CommunityAPI? = nil) { self.api = api ?? CommunityAPI() }

    func clear() {
        requestID = UUID(); ownerToken = nil
        decks = []; isLoading = false; errorMessage = nil
    }

    func load(token: String, onError: ((Error) -> Void)? = nil) async {
        if ownerToken != token { clear(); ownerToken = token }
        let id = UUID(); requestID = id
        isLoading = decks.isEmpty
        defer { if requestID == id { isLoading = false } }
        do {
            let page = try await api.myDecks(token: token)
            guard !Task.isCancelled, requestID == id else { return }
            decks = page.decks; errorMessage = nil
        } catch {
            guard !Task.isCancelled, requestID == id else { return }
            errorMessage = error.localizedDescription
            onError?(error)
        }
    }

    func remove(id: String) {
        // Invalidate an older refresh so it cannot reinsert a dismissed notice.
        requestID = UUID(); isLoading = false
        decks.removeAll { $0.id == id }
    }
}

struct CommunityFeedView: View {
    @ObservedObject var store: CommunityFeedStore
    let libraryDecks: [Deck]
    let onAddDeck: (PremadeDeck) -> Void
    let onShare: () -> Void
    var showsSearchField = true
    var showsTitle = true
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
            if (store.isLoading || !store.hasLoaded) && store.decks.isEmpty && store.errorMessage == nil {
                ProgressView("Loading decks…").frame(maxWidth: .infinity, minHeight: 120)
            } else if store.decks.isEmpty, let error = store.errorMessage {
                VStack(spacing: 8) {
                    Text(error).font(.subheadline).foregroundStyle(LearnAlertStyle.textSecondary).multilineTextAlignment(.center)
                    Button("Try again") { Task { await store.load() } }.frame(minHeight: 44)
                }.frame(maxWidth: .infinity).padding(.vertical, 20)
            } else if store.hasLoaded && store.decks.isEmpty {
                VStack(spacing: 8) {
                    Text(store.search.isEmpty && store.category == "All" ? "No community decks yet" : "No matching decks").font(.headline)
                    if !store.search.isEmpty || store.category != "All" {
                        Button("Clear filters") { store.search = ""; store.category = "All" }.frame(minHeight: 44)
                    }
                }.frame(maxWidth: .infinity).padding(.vertical, 24)
            }
            LazyVStack(spacing: 0) {
                ForEach(Array(store.decks.enumerated()), id: \.element.id) { index, deck in
                    CommunityDeckCard(deck: deck, open: { selectedPreview = deck })
                        .contextMenu {
                            Button("Report deck", systemImage: "flag") { Task { await report(deck) } }
                        }
                        .onAppear {
                            if index >= store.decks.count - 4 && store.loadMoreErrorMessage == nil {
                                Task { await store.loadNextPage() }
                            }
                        }
                    if index < store.decks.count - 1 { Divider().overlay(LearnAlertStyle.hairline.opacity(0.35)) }
                }
                paginationStatus
            }

        }
        .foregroundStyle(LearnAlertStyle.textPrimary).tint(LearnAlertStyle.appAccentForeground)
        .task(id: "\(store.sort.rawValue):\(store.category):\(store.search):\(session.token ?? "anonymous")") {
            store.setViewer(token: session.token)
            do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
            await store.load()
        }
        .onReceive(NotificationCenter.default.publisher(for: .communityLibraryChanged)) { _ in
            selectedPreview = nil
            store.setViewer(token: session.token)
            Task { await store.load() }
        }
        .sheet(item: $selectedPreview) { deck in
            CommunityDeckPreviewSheet(deck: deck, isAdded: isAdded(deck), isDownloading: downloadingID == deck.id,
                progress: downloadProgress, download: { Task { await download(deck) } })
        }
        .alert("Community decks", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
    }

    @ViewBuilder private var paginationStatus: some View {
        if !store.decks.isEmpty {
            if let error = store.loadMoreErrorMessage ?? store.errorMessage {
                VStack(spacing: 4) {
                    Text(error).font(.caption).foregroundStyle(LearnAlertStyle.textSecondary).multilineTextAlignment(.center)
                    Button("Try again") {
                        Task {
                            if store.loadMoreErrorMessage != nil { await store.loadNextPage() }
                            else { await store.load() }
                        }
                    }.frame(minHeight: 44)
                }.padding(.top, 12).frame(maxWidth: .infinity)
            } else if store.isLoadingMore || store.isLoading {
                ProgressView().frame(maxWidth: .infinity, minHeight: 52)
            } else if store.hasMore {
                Color.clear.frame(height: 1)
                    .task(id: store.paginationID) { await store.loadNextPage() }
            } else if store.hasLoaded {
                Text("You’re all caught up")
                    .font(.caption).foregroundStyle(LearnAlertStyle.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 44).padding(.top, 6)
            }
        }
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
            let downloaded = try await CommunityDeckTransfer.download(deck, token: session.token) { downloadProgress = $0 }
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

struct CommunityDeckCard: View {
    let deck: CommunityDeckPayload
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text(deck.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LearnAlertStyle.textPrimary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("\(deck.cardCount) cards")
                    .font(.caption).monospacedDigit()
                    .foregroundStyle(LearnAlertStyle.textSecondary)
                    .fixedSize()
            }
            .frame(minHeight: 44)
            .padding(.vertical, 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Preview this deck")
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var session = CommunitySession.shared
    @State private var preview: CommunityDeckPayload?
    @State private var error: String?
    @State private var actionMessage: String?
    @State private var authorProfile: AuthorTarget?
    @State private var likeCount = 0
    @State private var viewerHasLiked = false
    @State private var isSavingLike = false
    @State private var hasLoaded = false
    @State private var likeAnimationID = 0
    private struct AuthorTarget: Identifiable { let id: String }
    private var visibleDeck: CommunityDeckPayload { preview ?? deck }
    private var isOwnDeck: Bool {
        guard let authorID = visibleDeck.authorID else { return false }
        return authorID == session.profile.authorID
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 12) {
                        CommunityAvatarView(avatar: visibleDeck.authorAvatar ?? .init()).frame(width: 48, height: 48)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(visibleDeck.name).font(.title2.weight(.bold))
                            if let authorID = visibleDeck.authorID {
                                Button { authorProfile = AuthorTarget(id: authorID) } label: {
                                    Text(visibleDeck.authorHandle).underline()
                                        .font(.subheadline).foregroundStyle(LearnAlertStyle.textSecondary)
                                        .frame(minHeight: 32, alignment: .leading)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityHint("View creator profile")
                            } else {
                                Text(visibleDeck.authorHandle).font(.subheadline).foregroundStyle(LearnAlertStyle.textSecondary)
                            }
                        }
                    }
                    if !visibleDeck.description.isEmpty { Text(visibleDeck.description).font(.body) }
                    HStack(spacing: 12) {
                        Text("\(visibleDeck.cardCount) cards · \(visibleDeck.downloadCount.formatted()) downloads")
                            .font(.subheadline).foregroundStyle(LearnAlertStyle.textSecondary)
                        Spacer(minLength: 4)
                        if !isOwnDeck { likeButton }
                    }
                    if let error {
                        Text(error).foregroundStyle(LearnAlertStyle.destructiveRed)
                        Button("Try again") { Task { await load() } }.frame(minHeight: 44)
                    } else if let cards = preview?.cards {
                        ForEach(cards) { CommunitySampleCardView(card: $0) }
                    } else { ProgressView().frame(maxWidth: .infinity, minHeight: 100) }
                }.padding(24).frame(maxWidth: 560).frame(maxWidth: .infinity)
            }
            .background(LearnAlertStyle.courseCanvas.ignoresSafeArea()).foregroundStyle(LearnAlertStyle.textPrimary)
            .navigationTitle("Deck preview").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .topBarLeading) {
                    Menu { Button("Report deck", systemImage: "flag") { Task { await report() } } }
                        label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }
                        .accessibilityLabel("Deck options")
                }
            }
            .alert("Community decks", isPresented: Binding(get: { actionMessage != nil }, set: { if !$0 { actionMessage = nil } })) {
                Button("OK", role: .cancel) { actionMessage = nil }
            } message: { Text(actionMessage ?? "") }
            .sheet(item: $authorProfile) { author in CommunityPublicProfileView(authorID: author.id) }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    if isDownloading { ProgressView(progress).font(.caption) }
                    Button(action: download) { Label(isAdded ? "In your library" : "Add to library", systemImage: isAdded ? "checkmark" : "arrow.down").frame(maxWidth: .infinity, minHeight: 48) }
                        .buttonStyle(.borderedProminent).tint(LearnAlertStyle.appAccent).foregroundStyle(LearnAlertStyle.appAccentInk).disabled(isAdded || isDownloading)
                }.padding(16).background(LearnAlertStyle.courseSurface)
            }
            .task(id: session.token) { await load() }
        }
    }

    private var likeButton: some View {
        Button { Task { await toggleLike() } } label: {
            HStack(spacing: 6) {
                Image(systemName: viewerHasLiked ? "heart.fill" : "heart")
                    .font(.system(size: 21, weight: .medium))
                    .symbolEffect(.bounce, value: reduceMotion ? 0 : likeAnimationID)
                    .overlay {
                        if likeAnimationID > 0 && !reduceMotion {
                            CommunityHeartBurst().id(likeAnimationID).allowsHitTesting(false)
                        }
                    }
                if isSavingLike { ProgressView().controlSize(.mini).frame(width: 20) }
                else { Text(likeCount.formatted()).font(.subheadline.weight(.medium)).monospacedDigit() }
            }
            .foregroundStyle(viewerHasLiked ? Color.pink : LearnAlertStyle.textSecondary)
            .frame(minWidth: 64, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!session.isSignedIn || !hasLoaded || isSavingLike)
        .accessibilityLabel(viewerHasLiked ? "Unlike deck" : "Like deck")
        .accessibilityValue("\(likeCount) likes")
        .accessibilityHint(session.isSignedIn ? "" : "Sign in with Apple in Settings to like community decks")
    }

    @MainActor private func load() async {
        let token = session.token
        error = nil; hasLoaded = false
        likeCount = max(0, deck.likeCount ?? 0)
        viewerHasLiked = false
        do {
            let loaded = try await CommunityAPI().preview(deckID: deck.id, token: token)
            guard !Task.isCancelled, session.token == token else { return }
            preview = loaded
            likeCount = max(0, loaded.likeCount ?? 0)
            viewerHasLiked = token != nil && (loaded.viewerHasLiked ?? false)
            hasLoaded = true
        } catch {
            guard !Task.isCancelled, session.token == token else { return }
            self.error = error.localizedDescription
        }
    }

    @MainActor private func toggleLike() async {
        guard let token = session.token, hasLoaded, !isOwnDeck, !isSavingLike else { return }
        isSavingLike = true
        defer { isSavingLike = false }
        let wasLiked = viewerHasLiked
        do {
            let result = try await CommunityAPI().setLike(deckID: deck.id, liked: !wasLiked, token: token)
            guard !Task.isCancelled, session.token == token else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                likeCount = max(0, result.likeCount)
                viewerHasLiked = result.viewerHasLiked
                if !wasLiked && result.viewerHasLiked { likeAnimationID += 1 }
            }
        } catch {
            guard !Task.isCancelled, session.token == token else { return }
            session.handle(error); actionMessage = error.localizedDescription
        }
    }

    @MainActor private func report() async {
        guard let token = session.token else { actionMessage = "Sign in with Apple in Settings before reporting a deck."; return }
        do {
            try await CommunityAPI().report(deckID: deck.id, reason: "Reported by a learner for review.", token: token)
            actionMessage = "Your report has been saved for review."
        } catch { session.handle(error); actionMessage = error.localizedDescription }
    }
}

private struct CommunityHeartBurst: View {
    @State private var expanded = false
    var body: some View {
        ZStack {
            ForEach(0..<7, id: \.self) { index in
                let angle = Double(index) * .pi * 2 / 7
                Circle().fill(Color.pink.opacity(0.7))
                    .frame(width: 4, height: 4)
                    .offset(x: CGFloat(cos(angle)) * (expanded ? 26 : 8), y: CGFloat(sin(angle)) * (expanded ? 26 : 8))
                    .scaleEffect(expanded ? 0.15 : 1)
                    .opacity(expanded ? 0 : 1)
            }
        }
        .frame(width: 44, height: 44)
        .accessibilityHidden(true)
        .onAppear { withAnimation(.easeOut(duration: 0.55)) { expanded = true } }
    }
}

private struct CommunityRemoteImage: View {
    let id: String
    var maximumHeight: CGFloat = 160
    @ObservedObject private var session = CommunitySession.shared
    @State private var image: UIImage?
    var body: some View {
        Group {
            if let image { Image(uiImage: image).resizable().scaledToFit() }
            else { Image(systemName: "photo").font(.largeTitle).foregroundStyle(LearnAlertStyle.textSecondary).frame(maxWidth: .infinity, minHeight: 64) }
        }
        .frame(maxHeight: maximumHeight).clipShape(RoundedRectangle(cornerRadius: 12))
        .task(id: "\(id):\(session.token ?? "anonymous")") {
            image = nil
            if let data = try? await CommunityAPI().media(id: id, maximumBytes: 10 * 1024 * 1024, token: session.token), !Task.isCancelled { image = UIImage(data: data) }
        }
    }
}

private struct CommunityPreviewAudio: View {
    var mediaID: String? = nil
    var localName: String? = nil
    @ObservedObject private var session = CommunitySession.shared
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
                        if let mediaID { data = try await CommunityAPI().media(id: mediaID, maximumBytes: CardAudioStore.maximumBytes, token: session.token) }
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
    @State private var showingImageBack = false
    private var isImageCard: Bool { card.cardType == "images" }
    private var hasImageBack: Bool { localCard?.answerImageName?.isEmpty == false || card.answerImageID != nil }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !isImageCard && !card.question.isEmpty { Text(card.question).font(.body.weight(.medium)) }
            if isImageCard {
                Group {
                    if hasImageBack {
                        ImageCardFlipView(isShowingBack: $showingImageBack) {
                            imageFace(localName: localCard?.promptImageName, remoteID: card.promptImageID)
                        } back: {
                            imageFace(localName: localCard?.answerImageName, remoteID: card.answerImageID)
                        }
                    } else {
                        imageFace(localName: localCard?.promptImageName, remoteID: card.promptImageID)
                    }
                }
                .frame(maxWidth: .infinity).frame(height: 340)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else if let localCard, let image = CardImageStore.loadImage(named: localCard.promptImageName) { Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 160).frame(maxWidth: .infinity).clipShape(RoundedRectangle(cornerRadius: 12)) }
            else if let id = card.promptImageID { CommunityRemoteImage(id: id) }
            if !isImageCard {
                if let name = localCard?.promptAudioName { CommunityPreviewAudio(localName: name) }
                else if let id = card.promptAudioID { CommunityPreviewAudio(mediaID: id) }
                ForEach(Array(card.options.enumerated()), id: \.offset) { index, option in
                    fieldPreview("option:\(index)", text: option)
                }
                DisclosureGroup("Show answer") {
                    if card.cardType == "matching" {
                        ForEach(Array(card.matchingLeftItems.enumerated()), id: \.offset) { index, item in
                            HStack { fieldPreview("left:\(index)", text: item); Image(systemName: "arrow.right"); fieldPreview("right:\(index)", text: card.matchingRightItems.indices.contains(index) ? card.matchingRightItems[index] : "") }
                        }
                    } else if card.cardType == "multiple_choice" {
                        if let index = card.correctOptionIndex ?? card.options.firstIndex(of: card.correctAnswer), card.options.indices.contains(index) { fieldPreview("option:\(index)", text: card.options[index]) }
                    } else { fieldPreview("answer", text: card.correctAnswer) }
                }.font(.subheadline).tint(LearnAlertStyle.appAccentForeground)
                if !card.hint.isEmpty || card.fieldMedia?["hint"] != nil {
                    DisclosureGroup("Hint") { fieldPreview("hint", text: card.hint) }.font(.subheadline)
                }
            }
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading).appCardSurface(cornerRadius: 20)
    }

    private func fieldPreview(_ key: String, text: String) -> some View {
        let remote = card.fieldMedia?[key]
        let local = localCard?.fieldMedia[key]
        return VStack(alignment: .leading, spacing: 6) {
            if !text.isEmpty { Text(text).font(.subheadline) }
            if let name = local?.image, let image = CardImageStore.loadImage(named: name) { Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 120) }
            else if let id = remote?.imageID { CommunityRemoteImage(id: id, maximumHeight: 120) }
            else if key.hasPrefix("option:"), let index = Int(key.dropFirst(7)), card.optionImageIDs.indices.contains(index), let id = card.optionImageIDs[index] { CommunityRemoteImage(id: id, maximumHeight: 120) }
            if let name = local?.audio { CommunityPreviewAudio(localName: name) }
            else if let id = remote?.audioID { CommunityPreviewAudio(mediaID: id) }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private func imageFace(localName: String?, remoteID: String?) -> some View {
        if let image = CardImageStore.loadImage(named: localName) {
            Image(uiImage: image).resizable().scaledToFit()
        } else if let remoteID {
            CommunityRemoteImage(id: remoteID, maximumHeight: 340)
        } else {
            Label("Image unavailable", systemImage: "photo").foregroundStyle(LearnAlertStyle.textSecondary)
        }
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
    @State private var isSubmitted = false
    @State private var publishError: String?
    @State private var showingProfile = false
    @State private var showingPreview = false
    @State private var publisherHandle = ""
    private var availableDecks: [Deck] { libraryDecks.filter(\.canPresentCommunitySharing) }
    private var selectedDeck: Deck? { availableDecks.first { $0.id == selectedDeckID } }
    private var canPublishSelected: Bool {
        guard let deck = selectedDeck else { return false }
        return deck.sharingRestriction(allowAnkiUploads: session.canUploadAnki) == nil
    }
    private var listingCategories: [String] { CommunityFeedView.categories.filter { $0 != "All" } }

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
                            if let reason = deck.sharingRestriction(allowAnkiUploads: session.canUploadAnki) {
                                Text(reason).font(.subheadline).foregroundStyle(LearnAlertStyle.textSecondary)
                            }
                            if session.isDeveloper {
                                TextField("Creator name (optional)", text: $publisherHandle)
                                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                                    .padding(14).appCardSurface(cornerRadius: 16)
                                    .disabled(isPublishing)
                            }
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Category").font(.subheadline.weight(.medium)); Spacer()
                                    Picker("Category", selection: $category) { ForEach(listingCategories, id: \.self) { Text($0).tag($0) } }.pickerStyle(.menu)
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
            .navigationTitle(isSubmitted ? "Submitted for review" : "Share a deck").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.disabled(isPublishing) } }
            .safeAreaInset(edge: .bottom) {
                if canPublishSelected {
                    VStack(spacing: 10) {
                        if isPublishing { ProgressView(progress).font(.caption) }
                        if selectedDeck?.publishedCommunityID != nil && !isSubmitted {
                            Text("Updates make the community copy private until approved.").font(.caption).foregroundStyle(LearnAlertStyle.textSecondary).multilineTextAlignment(.center)
                        }
                        Text("Review can take up to 3 days. Cards and media stay private until approved. Study history stays private.").font(.caption).foregroundStyle(LearnAlertStyle.textSecondary).multilineTextAlignment(.center)
                        Button { beginPublish() } label: {
                            Label(isSubmitted ? "Awaiting review" : selectedDeck?.publishedCommunityID == nil ? "Submit for review" : "Submit update for review", systemImage: isSubmitted ? "clock.fill" : "square.and.arrow.up")
                                .font(.body.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 48)
                        }.buttonStyle(.borderedProminent).tint(LearnAlertStyle.appAccent).foregroundStyle(LearnAlertStyle.appAccentInk)
                            .disabled(isPublishing || isSubmitted || selectedDeck?.cards.isEmpty == true || (selectedDeck?.cards.count ?? 0) > 500)
                    }.padding(16).background(LearnAlertStyle.courseSurface)
                }
            }
            .interactiveDismissDisabled(isPublishing)
            .task(id: selectedDeckID) {
                await session.refreshProfile()
                let selectedID = selectedDeckID
                if session.isDeveloper, let id = selectedDeck?.publishedCommunityID, let token = session.token,
                   let owned = try? await CommunityAPI().myDecks(token: token),
                   selectedDeckID == selectedID, publisherHandle.isEmpty,
                   let listing = owned.decks.first(where: { $0.id == id }), listing.authorHandle != session.handle {
                    publisherHandle = listing.authorHandle
                }
            }
            .onAppear { if selectedDeckID == nil { selectedDeckID = availableDecks.first(where: { $0.id == initialDeckID })?.id ?? availableDecks.first?.id; loadMetadata() } }
            .onChange(of: selectedDeckID) { _, _ in loadMetadata() }
            .onChange(of: category) { _, _ in isSubmitted = false }
            .onChange(of: deckDescription) { _, _ in isSubmitted = false }
            .onChange(of: publisherHandle) { _, _ in isSubmitted = false }
            .sheet(isPresented: $showingProfile) {
                CommunityProfileSheet(saveTitle: "Save & submit", onSave: { showingProfile = false; Task { await publish() } })
            }
            .sheet(isPresented: $showingPreview) { if let deck = selectedDeck { LocalCommunityPreviewSheet(deck: deck) } }
        }
    }

    private func listingPreview(_ deck: Deck) -> some View {
        let images = deck.cards.reduce(0) { $0 + $1.fieldMedia.values.filter { $0.image != nil }.count }
        let audio = deck.cards.reduce(0) { $0 + $1.fieldMedia.values.filter { $0.audio != nil }.count }
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                if session.isSignedIn && session.profile.isComplete { CommunityAvatarView(avatar: session.profile.avatar).frame(width: 32, height: 32) }
                Text(session.isDeveloper && !publisherHandle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? publisherHandle : session.isSignedIn ? session.handle : "Your community preview").font(.subheadline).foregroundStyle(LearnAlertStyle.textSecondary)
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
        isSubmitted = false; publishError = nil; publisherHandle = ""
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
            let id = try await CommunityDeckTransfer.publish(deck: deck, category: category, description: deckDescription, token: token,
                publisherHandle: session.isDeveloper ? publisherHandle.trimmingCharacters(in: .whitespacesAndNewlines) : nil) { progress = $0 }
            deck.publishedCommunityID = id; deck.communityCategory = category; deck.communityDescription = deckDescription
            try context.save(); isSubmitted = true; HapticFeedback.success()
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
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var session = CommunitySession.shared
    @StateObject private var store = CommunityOwnedDeckStore()
    @State private var message: String?
    @State private var editingDeck: Deck?
    @State private var removingDeck: CommunityDeckPayload?
    @State private var isRemoving = false
    private var refreshID: String { "\(scenePhase)-\(session.token ?? "signed-out")" }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if store.isLoading { ProgressView("Loading your decks…").frame(minHeight: 120) }
                    else if store.decks.isEmpty && store.errorMessage == nil { ContentUnavailableView("No submissions yet", systemImage: "rectangle.stack") }
                    ForEach(store.decks) { deck in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(deck.name).font(.headline)
                            if !deck.isRemoved {
                                Text("\(deck.cardCount) cards · \(deck.downloadCount.formatted()) downloads").font(.subheadline).foregroundStyle(LearnAlertStyle.textSecondary)
                            }
                            if deck.isRemoved {
                                Label("Removed by admin", systemImage: "trash").font(.subheadline.weight(.medium)).foregroundStyle(LearnAlertStyle.destructiveRed)
                            } else if deck.isHidden == true {
                                Label("Hidden by admin", systemImage: "eye.slash").font(.subheadline.weight(.medium)).foregroundStyle(LearnAlertStyle.destructiveRed)
                            } else if deck.reviewStatus == "pending" {
                                Label("Pending review", systemImage: "clock").font(.subheadline.weight(.medium)).foregroundStyle(LearnAlertStyle.appAccentForeground)
                                Text("Review can take up to 3 days.").font(.caption).foregroundStyle(LearnAlertStyle.textSecondary)
                            } else if deck.reviewStatus == "rejected" {
                                Label("Needs changes", systemImage: "exclamationmark.bubble").font(.subheadline.weight(.medium)).foregroundStyle(LearnAlertStyle.destructiveRed)
                                if let note = deck.reviewMessage, !note.isEmpty {
                                    Text(note).font(.subheadline).foregroundStyle(LearnAlertStyle.textSecondary)
                                }
                            } else if deck.reviewStatus == "approved" {
                                Label("Approved", systemImage: "checkmark.circle").font(.subheadline.weight(.medium)).foregroundStyle(LearnAlertStyle.appAccentForeground)
                            }
                            if let note = deck.adminNote, !note.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Admin note").font(.caption.weight(.semibold)).foregroundStyle(LearnAlertStyle.textSecondary)
                                    Text(note).font(.subheadline)
                                }
                            } else if deck.adminAction == "edited" {
                                Label("Updated by admin", systemImage: "pencil").font(.caption).foregroundStyle(LearnAlertStyle.textSecondary)
                            }
                            HStack {
                                if !deck.isRemoved, let local = libraryDecks.first(where: { $0.publishedCommunityID == deck.id && $0.sharingRestriction(allowAnkiUploads: session.canUploadAnki) == nil }) { Button(deck.reviewStatus == "rejected" ? "Edit & resubmit" : "Edit", systemImage: "pencil") { editingDeck = local }.frame(minHeight: 44) }
                                Spacer()
                                Button(deck.isRemoved ? "Dismiss notice" : "Remove", systemImage: deck.isRemoved ? "xmark" : "trash", role: deck.isRemoved ? nil : .destructive) {
                                    if deck.isRemoved { Task { await remove(deck) } } else { removingDeck = deck }
                                }.frame(minHeight: 44)
                            }.disabled(isRemoving)
                        }.padding(16).frame(maxWidth: .infinity, alignment: .leading).appCardSurface(cornerRadius: 20)
                    }
                    if let error = message ?? store.errorMessage { Text(error).font(.subheadline).foregroundStyle(LearnAlertStyle.destructiveRed); Button("Try again") { Task { await load() } }.frame(minHeight: 44) }
                }.padding(20)
            }.background(LearnAlertStyle.courseCanvas.ignoresSafeArea()).foregroundStyle(LearnAlertStyle.textPrimary).tint(LearnAlertStyle.appAccentForeground)
                .navigationTitle("My community decks").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.disabled(isRemoving) } }
                .task(id: refreshID) {
                    guard session.token != nil else { store.clear(); return }
                    guard scenePhase == .active else { return }
                    await load()
                    while !Task.isCancelled {
                        do { try await Task.sleep(for: .seconds(30)) } catch { return }
                        if !isRemoving && editingDeck == nil { await load() }
                    }
                }.refreshable { await load() }
                .onReceive(NotificationCenter.default.publisher(for: .communityLibraryChanged)) { _ in Task { await load() } }
                .sheet(item: $editingDeck) { ShareDeckToCommunitySheet(libraryDecks: libraryDecks, initialDeckID: $0.id) }
                .confirmationDialog("Remove this community deck?", isPresented: Binding(get: { removingDeck != nil }, set: { if !$0 { removingDeck = nil } }), titleVisibility: .visible) {
                    Button("Remove community deck", role: .destructive) { if let deck = removingDeck { Task { await remove(deck) } } }
                } message: { Text("Your personal deck and copies already downloaded by other learners remain in their libraries.") }
                .interactiveDismissDisabled(isRemoving)
        }
    }
    @MainActor private func load() async {
        guard let token = session.token else { store.clear(); message = "Sign in with Apple to see your community decks."; return }
        message = nil
        await store.load(token: token) { error in
            if session.token == token { session.handle(error) }
        }
    }
    @MainActor private func remove(_ deck: CommunityDeckPayload) async {
        guard let token = session.token, !isRemoving else { return }
        isRemoving = true; message = nil
        defer { isRemoving = false; removingDeck = nil }
        do {
            try await CommunityAPI().remove(deckID: deck.id, token: token)
            guard session.token == token else { return }
            for local in libraryDecks where local.publishedCommunityID == deck.id { local.publishedCommunityID = nil }
            try context.save(); store.remove(id: deck.id)
            NotificationCenter.default.post(name: .communityLibraryChanged, object: nil)
        } catch { session.handle(error); message = error.localizedDescription }
    }
}
