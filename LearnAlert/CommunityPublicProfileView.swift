import SwiftUI
import SwiftData

struct CommunityPublicProfileView: View {
    let authorID: String
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var session = CommunitySession.shared
    @Query private var libraryDecks: [Deck]
    @State private var profile: CommunityPublicProfile?
    @State private var decks: [CommunityDeckPayload] = []
    @State private var nextOffset: Int?
    @State private var totalCount = 0
    @State private var loading = false
    @State private var loadingMore = false
    @State private var requestID = UUID()
    @State private var displayScope: String?
    @State private var error: String?
    @State private var showingEditor = false
    @State private var showingMyDecks = false
    @State private var showingBlockedAuthors = false
    @State private var confirmingBlock = false
    @State private var savingPrivacy = false
    @State private var privacyDraft = false
    @State private var blocking = false
    @State private var selectedDeck: CommunityDeckPayload?

    private var isOwner: Bool { session.isSignedIn && session.profile.authorID == authorID }
    private var scope: String { "\(authorID):\(session.token ?? "anonymous")" }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    if let profile, displayScope == scope {
                        profileHeader(profile)
                        if let stats = profile.stats { CommunityProfileStatsGrid(stats: stats) }
                        else if profile.hideStatsPublicly {
                            Label("Stats are private", systemImage: "lock")
                                .font(.subheadline).foregroundStyle(LearnAlertStyle.textSecondary)
                        }
                        if isOwner { ownerControls(profile) }
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Published decks").font(.headline)
                                Spacer()
                                if !profile.hideStatsPublicly || isOwner {
                                    Text(totalCount.formatted()).font(.subheadline).monospacedDigit()
                                        .foregroundStyle(LearnAlertStyle.textSecondary)
                                }
                            }
                            LazyVStack(spacing: 0) {
                                ForEach(decks) { deck in
                                    CommunityDeckCard(deck: deck, open: { selectedDeck = deck })
                                    Divider().overlay(LearnAlertStyle.hairline.opacity(0.3))
                                }
                                if decks.isEmpty && !loading { Text("No published decks yet").font(.subheadline).foregroundStyle(LearnAlertStyle.textSecondary).padding(.vertical, 24) }
                                if nextOffset != nil {
                                    if loadingMore { ProgressView().padding(14) }
                                    else { Button("Load more") { Task { await loadMore() } }.frame(minHeight: 44) }
                                }
                            }
                        }
                    } else if loading || displayScope != scope { ProgressView().frame(maxWidth: .infinity, minHeight: 220) }
                    if let error {
                        VStack(spacing: 8) {
                            Text(error).font(.subheadline).foregroundStyle(LearnAlertStyle.textSecondary)
                            Button("Try again") { Task { await load() } }.frame(minHeight: 44)
                        }.frame(maxWidth: .infinity)
                    }
                }
                .padding(22).frame(maxWidth: 560).frame(maxWidth: .infinity)
            }
            .background(LearnAlertStyle.courseCanvas.ignoresSafeArea())
            .foregroundStyle(LearnAlertStyle.textPrimary)
            .navigationTitle(isOwner ? "Your profile" : "Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    if isOwner {
                        Menu {
                            Button("Edit profile", systemImage: "pencil") { showingEditor = true }
                            Button("My community decks", systemImage: "rectangle.stack") { showingMyDecks = true }
                            Button("Blocked authors", systemImage: "person.slash") { showingBlockedAuthors = true }
                            Button("Sign out", systemImage: "rectangle.portrait.and.arrow.right") { session.signOut(); dismiss() }
                        } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }
                        .accessibilityLabel("Profile options")
                    } else if profile != nil {
                        Menu {
                            Button("Block author", systemImage: "person.slash", role: .destructive) { confirmingBlock = true }
                                .disabled(!session.isSignedIn || session.isRestricted)
                        } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }
                        .accessibilityLabel("Profile options")
                    }
                }
            }
            .task(id: scope) { await load(clear: true) }
            .onChange(of: session.token) { _, _ in
                showingEditor = false; showingMyDecks = false; showingBlockedAuthors = false; selectedDeck = nil
            }
            .refreshable { await load() }
            .onReceive(NotificationCenter.default.publisher(for: .communityLibraryChanged)) { _ in
                selectedDeck = nil
                Task { await load() }
            }
            .sheet(isPresented: $showingEditor, onDismiss: { Task { await load() } }) { CommunityProfileSheet() }
            .sheet(isPresented: $showingMyDecks) { MySharedDecksSheet(libraryDecks: libraryDecks) }
            .sheet(isPresented: $showingBlockedAuthors) { CommunityBlockedAuthorsSheet() }
            .sheet(item: $selectedDeck, onDismiss: { Task { await load() } }) { CommunityProfileDeckPreview(deck: $0) }
            .confirmationDialog("Block \(profile?.handle ?? "this author")?", isPresented: $confirmingBlock, titleVisibility: .visible) {
                Button("Block author", role: .destructive) { Task { await block() } }
            } message: { Text("Hides their profile and community decks. Copies in your library stay.") }
            .interactiveDismissDisabled(blocking || savingPrivacy)
        }
        .tint(LearnAlertStyle.appAccentForeground)
    }

    private func profileHeader(_ profile: CommunityPublicProfile) -> some View {
        VStack(spacing: 12) {
            CommunityAvatarView(avatar: profile.avatar).frame(width: 116, height: 116)
            Text(profile.handle).font(.title2.weight(.bold))
            if let created = profile.profileCreatedAt ?? profile.stats?.profileCreatedAt {
                Text(CommunityProfileAge.label(since: created)).font(.subheadline)
                    .foregroundStyle(LearnAlertStyle.textSecondary)
            }
        }.frame(maxWidth: .infinity).padding(.vertical, 12)
    }

    private func ownerControls(_ profile: CommunityPublicProfile) -> some View {
        VStack(spacing: 0) {
            Button { showingEditor = true } label: {
                HStack { Label("Edit profile", systemImage: "pencil"); Spacer(); Image(systemName: "chevron.right").font(.caption.weight(.semibold)) }
                    .frame(minHeight: 48)
            }
            .buttonStyle(.plain)
            Divider()
            Toggle("Hide stats publicly", isOn: Binding(get: { privacyDraft }, set: { value in
                privacyDraft = value
                Task { await savePrivacy(value) }
            }))
            .font(.subheadline).tint(LearnAlertStyle.appAccentForeground).frame(minHeight: 54)
            .disabled(savingPrivacy || session.isRestricted)
            if savingPrivacy { ProgressView().padding(.bottom, 10) }
        }
        .padding(.horizontal, 16).appCardSurface(cornerRadius: 18)
    }

    @MainActor private func load(clear: Bool = false) async {
        let id = UUID(); requestID = id
        let token = session.token
        if clear || displayScope != scope { profile = nil; decks = []; nextOffset = nil; totalCount = 0 }
        displayScope = scope
        loading = true; error = nil
        defer { if requestID == id { loading = false } }
        do {
            let page = try await CommunityAPI().publicProfile(authorID: authorID, token: token)
            guard requestID == id, session.token == token, !Task.isCancelled else { return }
            profile = page.profile; privacyDraft = page.profile.hideStatsPublicly
            decks = page.decks; nextOffset = page.nextOffset; totalCount = page.totalCount
        } catch {
            guard requestID == id, session.token == token, !Task.isCancelled else { return }
            self.error = error.localizedDescription
            session.handle(error)
            if let failure = error as? CommunityAPIError, [403, 404].contains(failure.status) { profile = nil; decks = []; nextOffset = nil }
        }
    }

    @MainActor private func loadMore() async {
        guard !loadingMore, !loading, let offset = nextOffset else { return }
        let id = requestID; let token = session.token
        loadingMore = true
        defer { loadingMore = false }
        do {
            let page = try await CommunityAPI().publicProfile(authorID: authorID, offset: offset, token: token)
            guard requestID == id, session.token == token, !Task.isCancelled else { return }
            let known = Set(decks.map(\.id))
            decks.append(contentsOf: page.decks.filter { !known.contains($0.id) })
            nextOffset = page.nextOffset.flatMap { $0 > offset ? $0 : nil }
            totalCount = page.totalCount; error = nil
        } catch { if requestID == id, session.token == token, !Task.isCancelled { self.error = error.localizedDescription } }
    }

    @MainActor private func savePrivacy(_ hidden: Bool) async {
        guard !savingPrivacy else { return }
        let token = session.token
        savingPrivacy = true
        defer { savingPrivacy = false }
        do { try await session.saveProfilePrivacy(hideStatsPublicly: hidden); await load() }
        catch {
            guard session.token == token else { return }
            privacyDraft = profile?.hideStatsPublicly ?? false
            if !Task.isCancelled { self.error = error.localizedDescription }
        }
    }

    @MainActor private func block() async {
        guard !blocking, let token = session.token, !isOwner else { return }
        blocking = true
        defer { blocking = false }
        do {
            try await CommunityAPI().block(authorID: authorID, token: token)
            guard session.token == token else { return }
            NotificationCenter.default.post(name: .communityLibraryChanged, object: nil)
            dismiss()
        } catch {
            guard session.token == token else { return }
            session.handle(error); self.error = error.localizedDescription
        }
    }
}

enum CommunityProfileAge {
    static func label(since timestamp: Int, now: Date = Date(), calendar: Calendar = .current) -> String {
        let date = min(now, Date(timeIntervalSince1970: TimeInterval(timestamp)))
        let age = calendar.dateComponents([.year, .month, .day], from: date, to: now)
        if let years = age.year, years > 0 { return "\(years) \(years == 1 ? "year" : "years") on LearnAlert" }
        if let months = age.month, months > 0 { return "\(months) \(months == 1 ? "month" : "months") on LearnAlert" }
        if let days = age.day, days > 0 { return "\(days) \(days == 1 ? "day" : "days") on LearnAlert" }
        return "Joined today"
    }
}

struct CommunityProfileStatsGrid: View {
    let stats: CommunityProfileStats
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            stat("Created", value: stats.createdDeckCount, icon: "rectangle.stack")
            stat("Published", value: stats.publishedDeckCount, icon: "square.and.arrow.up")
            stat("Downloads", value: stats.downloadCount, icon: "arrow.down")
            stat("Hearts", value: stats.receivedLikeCount, icon: "heart.fill")
        }
    }
    private func stat(_ title: String, value: Int, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.subheadline.weight(.semibold)).foregroundStyle(title == "Hearts" ? Color.pink : LearnAlertStyle.appAccentForeground)
            VStack(alignment: .leading, spacing: 2) {
                Text(value.formatted()).font(.title3.weight(.bold)).monospacedDigit()
                Text(title).font(.caption).foregroundStyle(LearnAlertStyle.textSecondary)
            }
            Spacer(minLength: 0)
        }.padding(14).appCardSurface(cornerRadius: 16)
    }
}

struct CommunityProfileDeckPreview: View {
    let deck: CommunityDeckPayload
    @Environment(\.modelContext) private var context
    @Query private var libraryDecks: [Deck]
    @ObservedObject private var session = CommunitySession.shared
    @State private var downloading = false
    @State private var progress = ""
    @State private var error: String?
    private var isAdded: Bool { libraryDecks.contains { $0.sourceCommunityID == deck.id || $0.publishedCommunityID == deck.id } }
    var body: some View {
        CommunityDeckPreviewSheet(deck: deck, isAdded: isAdded, isDownloading: downloading,
                                  progress: progress, download: { Task { await download() } })
            .alert("Community deck", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK", role: .cancel) { }
            } message: { Text(error ?? "") }
    }
    @MainActor private func download() async {
        guard !downloading, !isAdded else { return }
        downloading = true
        defer { downloading = false }
        let token = session.token
        do {
            let source = try await CommunityDeckTransfer.download(deck, token: token) { progress = $0 }
            var committed = false
            defer { if !committed { removeDownloadedMedia(source) } }
            guard session.token == token, !Task.isCancelled, !isAdded else { return }
            let imported = Deck(name: source.name, colorHex: source.colorHex, deckType: source.deckType, orderIndex: libraryDecks.count)
            imported.sourceCommunityID = source.communitySourceID
            for (index, item) in source.cards.enumerated() {
                let card = Flashcard(question: item.question, options: item.options, correctAnswer: item.correctAnswer,
                                    hint: item.hint, deck: imported, cardType: item.cardType,
                                    matchingLeftItems: item.matchingLeftItems, matchingRightItems: item.matchingRightItems,
                                    promptImageName: item.promptImageName, answerImageName: item.answerImageName,
                                    optionImageNames: item.optionImageNames)
                card.orderIndex = index; card.promptAudioName = item.promptAudioName
                imported.cards.append(card)
                imported.assignCardToSection(card: card, suggestedCategory: item.sectionName)
            }
            context.insert(imported)
            do { try context.save() }
            catch { context.delete(imported); throw error }
            committed = true
            HapticFeedback.success()
            NotificationCenter.default.post(name: .communityLibraryChanged, object: nil)
        } catch {
            guard session.token == token, !Task.isCancelled else { return }
            session.handle(error); self.error = error.localizedDescription
        }
    }

    private func removeDownloadedMedia(_ source: PremadeDeck) {
        let images = source.cards.flatMap { [$0.promptImageName, $0.answerImageName].compactMap { $0 } + $0.optionImageNames }
        Set(images.filter { !$0.isEmpty }).forEach { CardImageStore.deleteImage(named: $0) }
        Set(source.cards.compactMap(\.promptAudioName)).forEach { CardAudioStore.delete(named: $0) }
    }
}
