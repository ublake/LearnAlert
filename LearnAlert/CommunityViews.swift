import SwiftUI
import SwiftData
import AuthenticationServices

extension Notification.Name {
    static let communityLibraryChanged = Notification.Name("communityLibraryChanged")
}

struct AllCommunityDecksView: View {
    let libraryDecks: [Deck]
    let onAddDeck: (PremadeDeck) -> Void
    let onOpenShareModal: () -> Void
    @ObservedObject private var session = CommunitySession.shared
    @State private var search = ""
    @State private var category = "All"
    @State private var decks: [CommunityDeckPayload] = []
    @State private var nextOffset: Int?
    @State private var isLoading = false
    @State private var downloadingID: String?
    @State private var downloadProgress = ""
    @State private var errorMessage: String?
    @State private var reportMessage: String?
    private let categories = ["All", "General", "Medical", "Coding", "Languages", "Law", "Science", "Math", "History", "Exam Prep"]

    init(libraryDecks: [Deck], initialSearch: String = "", onAddDeck: @escaping (PremadeDeck) -> Void, onOpenShareModal: @escaping () -> Void) {
        self.libraryDecks = libraryDecks
        self.onAddDeck = onAddDeck
        self.onOpenShareModal = onOpenShareModal
        _search = State(initialValue: initialSearch)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(StudyStudioStyle.secondary)
                    TextField("Search user-made decks", text: $search)
                        .textInputAutocapitalization(.never)
                        .submitLabel(.search)
                    if !search.isEmpty {
                        Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }
                            .frame(minWidth: 44, minHeight: 44)
                            .accessibilityLabel("Clear search")
                    }
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 48)
                .background(StudyStudioStyle.field, in: RoundedRectangle(cornerRadius: 12))

                Picker("Category", selection: $category) {
                    ForEach(categories, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)
                .tint(StudyStudioStyle.violet)

                if isLoading && decks.isEmpty {
                    ProgressView("Loading community decks…")
                        .frame(maxWidth: .infinity, minHeight: 160)
                } else if let errorMessage {
                    ContentUnavailableView {
                        Label("Library Unavailable", systemImage: "wifi.exclamationmark")
                    } description: { Text(errorMessage) } actions: {
                        Button("Try Again") { Task { await load() } }
                    }
                } else if decks.isEmpty {
                    ContentUnavailableView("No Shared Decks Yet", systemImage: "person.2", description: Text(search.isEmpty ? "Share a deck to help other learners get started." : "Try another title or category."))
                }

                LazyVStack(spacing: 16) {
                    ForEach(decks) { deck in
                        communityRow(deck)
                    }
                }
                if nextOffset != nil {
                    Button { Task { await load(more: true) } } label: {
                        if isLoading { ProgressView() }
                        else { Text("Load more decks") }
                    }
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .disabled(isLoading)
                }
            }
            .padding(16)
            .padding(.bottom, 32)
        }
        .background(StudyStudioStyle.canvas.ignoresSafeArea())
        .tint(StudyStudioStyle.violet)
        .navigationTitle("User-Made Decks")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onOpenShareModal) { Label("Share Deck", systemImage: "square.and.arrow.up") }
                    .tint(StudyStudioStyle.violet)
            }
        }
        .task(id: "\(category):\(search)") {
            do { try await Task.sleep(for: .milliseconds(300)) }
            catch { return }
            await load()
        }
        .refreshable { await load() }
        .onReceive(NotificationCenter.default.publisher(for: .communityLibraryChanged)) { _ in Task { await load() } }
        .alert("Community Library", isPresented: Binding(get: { reportMessage != nil }, set: { if !$0 { reportMessage = nil } })) {
            Button("OK", role: .cancel) { }
        } message: { Text(reportMessage ?? "") }
    }

    private func communityRow(_ deck: CommunityDeckPayload) -> some View {
        let added = libraryDecks.contains { $0.sourceCommunityID == deck.id }
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(deck.name).font(.headline).foregroundStyle(StudyStudioStyle.ink)
                    Text(deck.authorHandle).font(.subheadline).foregroundStyle(StudyStudioStyle.secondary)
                }
                Spacer(minLength: 0)
                Button { Task { await download(deck) } } label: {
                    if downloadingID == deck.id { ProgressView().frame(width: 44, height: 44) }
                    else { Image(systemName: added ? "checkmark" : "arrow.down.circle")
                        .font(.title2).frame(width: 44, height: 44) }
                }
                .disabled(added || downloadingID != nil)
                .tint(StudyStudioStyle.violet)
                .accessibilityLabel(added ? "\(deck.name) already in your library" : "Download \(deck.name)")
            }
            if !deck.description.isEmpty {
                Text(deck.description).font(.subheadline).foregroundStyle(StudyStudioStyle.secondary).lineLimit(3)
            }
            HStack(spacing: 16) {
                Text(deck.categoryTag)
                Text("\(deck.cardCount) cards")
                Label("\(deck.downloadCount)", systemImage: "arrow.down")
            }
            .font(.caption)
            .foregroundStyle(StudyStudioStyle.secondary)
            if downloadingID == deck.id {
                Text(downloadProgress).font(.caption).foregroundStyle(StudyStudioStyle.violet)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(StudyStudioStyle.field, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(StudyStudioStyle.hairline))
        .contextMenu {
            Button("Report deck", systemImage: "flag") { Task { await report(deck) } }
        }
    }

    @MainActor
    private func load(more: Bool = false) async {
        let query = search
        let selectedCategory = category
        isLoading = true
        errorMessage = nil
        defer { if search == query && category == selectedCategory { isLoading = false } }
        do {
            let page = try await CommunityAPI().list(search: query, category: selectedCategory, offset: more ? nextOffset ?? 0 : 0)
            guard !Task.isCancelled, search == query, category == selectedCategory else { return }
            if more {
                let existing = Set(decks.map(\.id))
                decks.append(contentsOf: page.decks.filter { !existing.contains($0.id) })
            } else { decks = page.decks }
            nextOffset = page.nextOffset
        } catch {
            guard !Task.isCancelled, search == query, category == selectedCategory else { return }
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func download(_ deck: CommunityDeckPayload) async {
        downloadingID = deck.id
        downloadProgress = "Downloading deck…"
        defer { downloadingID = nil }
        do {
            let downloaded = try await CommunityDeckTransfer.download(deck) { downloadProgress = $0 }
            onAddDeck(downloaded)
        } catch { reportMessage = error.localizedDescription }
    }

    @MainActor
    private func report(_ deck: CommunityDeckPayload) async {
        guard let token = session.token else {
            reportMessage = "Sign in with Apple using Share Deck before reporting a deck."
            return
        }
        do {
            try await CommunityAPI().report(deckID: deck.id, reason: "Reported by a learner for review.", token: token)
            reportMessage = "Your report has been saved for review."
        } catch { session.handle(error); reportMessage = error.localizedDescription }
    }
}

struct ShareDeckToCommunitySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let libraryDecks: [Deck]
    @ObservedObject private var session = CommunitySession.shared
    @State private var selectedDeckID: UUID?
    @State private var category = "General"
    @State private var deckDescription = ""
    @State private var nonce = ""
    @State private var isPublishing = false
    @State private var progress = ""
    @State private var isPublished = false
    @State private var confirmingRemove = false
    @State private var confirmingAccountDeletion = false
    @State private var publishError: String?
    private let categories = ["General", "Medical", "Coding", "Languages", "Law", "Science", "Math", "History", "Exam Prep"]
    private var selectedDeck: Deck? { libraryDecks.first { $0.id == selectedDeckID } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if session.isSignedIn {
                        Menu {
                            Button("Sign Out") { session.signOut() }
                            Button("Delete Community Account", role: .destructive) { confirmingAccountDeletion = true }
                        } label: {
                            Label(session.handle, systemImage: "person.crop.circle")
                                .font(.subheadline).foregroundStyle(StudyStudioStyle.secondary)
                                .frame(minHeight: 44)
                        }.disabled(isPublishing)
                    } else {
                        signInSection
                    }

                    if libraryDecks.isEmpty {
                        ContentUnavailableView("Create a Deck First", systemImage: "rectangle.stack", description: Text("Add cards, images, and audio to a deck in your library, then share it here."))
                    } else {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Choose a deck").font(.headline)
                            Picker("Deck", selection: $selectedDeckID) {
                                ForEach(libraryDecks) { deck in Text(deck.name).tag(Optional(deck.id)) }
                            }
                            .pickerStyle(.menu)
                            .tint(StudyStudioStyle.violet)
                            if let deck = selectedDeck {
                                let imageCount = deck.cards.reduce(0) { $0 + ($1.promptImageName == nil ? 0 : 1) + $1.optionImageNames.filter { !$0.isEmpty }.count }
                                let audioCount = deck.cards.filter { $0.promptAudioName != nil }.count
                                Text("\(deck.cards.count) cards · \(imageCount) images · \(audioCount) audio clips")
                                    .font(.subheadline).foregroundStyle(StudyStudioStyle.secondary)
                            }
                            Picker("Category", selection: $category) {
                                ForEach(categories, id: \.self) { Text($0).tag($0) }
                            }.pickerStyle(.menu).tint(StudyStudioStyle.violet)
                            TextField("Describe what this deck teaches", text: $deckDescription, axis: .vertical)
                                .lineLimit(3...6)
                                .padding(16)
                                .background(StudyStudioStyle.field, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(isPublishing)

                        Text("Publishing shares the cards, images, and audio with everyone. Your study history and source documents stay private.")
                            .font(.subheadline).foregroundStyle(StudyStudioStyle.secondary)

                        if let message = publishError ?? session.errorMessage {
                            Text(message).font(.subheadline).foregroundStyle(.red)
                        }

                        if isPublishing {
                            ProgressView(progress).frame(maxWidth: .infinity)
                        }
                        Button { Task { await publish() } } label: {
                            Label(isPublished ? "Published Successfully" : selectedDeck?.publishedCommunityID == nil ? "Publish Deck" : "Update Public Deck",
                                  systemImage: isPublished ? "checkmark.circle" : "square.and.arrow.up")
                                .font(.body.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 48)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(StudyStudioStyle.violet)
                        .disabled(!session.isSignedIn || selectedDeck == nil || selectedDeck?.cards.isEmpty == true || isPublishing || isPublished)

                        if selectedDeck?.publishedCommunityID != nil {
                            Button("Remove Public Deck", role: .destructive) { confirmingRemove = true }
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .disabled(isPublishing || !session.isSignedIn)
                        }
                    }
                }
                .padding(24)
            }
            .background(StudyStudioStyle.canvas.ignoresSafeArea())
            .navigationTitle("Share a Deck")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.disabled(isPublishing) } }
            .interactiveDismissDisabled(isPublishing)
            .onAppear { if selectedDeckID == nil { selectedDeckID = libraryDecks.first?.id } }
            .onChange(of: selectedDeckID) { _, _ in
                isPublished = false
                publishError = nil
                category = selectedDeck?.communityCategory ?? "General"
                deckDescription = selectedDeck?.communityDescription ?? ""
            }
            .onChange(of: category) { _, _ in isPublished = false }
            .onChange(of: deckDescription) { _, _ in isPublished = false }
            .confirmationDialog("Delete your community account?", isPresented: $confirmingAccountDeletion, titleVisibility: .visible) {
                Button("Delete Community Account", role: .destructive) { Task { await deleteAccount() } }
            } message: { Text("Removes your public decks and community sign-in data. Your personal library stays on this device.") }
            .confirmationDialog("Remove this deck from the public library?", isPresented: $confirmingRemove, titleVisibility: .visible) {
                Button("Remove Public Deck", role: .destructive) { Task { await remove() } }
            } message: { Text("Your personal deck and copies already downloaded by other learners will remain in their libraries.") }
        }
    }

    @MainActor
    private func deleteAccount() async {
        guard let token = session.token else { return }
        isPublishing = true
        defer { isPublishing = false }
        do {
            try await CommunityAPI().deleteAccount(token: token)
            session.signOut()
            for deck in libraryDecks { deck.publishedCommunityID = nil }
            try context.save()
            isPublished = false
            publishError = nil
        } catch { session.handle(error); publishError = error.localizedDescription }
    }

    private var signInSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sign in to share").font(.title2.weight(.semibold))
            Text("Use Sign in with Apple to publish and manage your public decks.")
                .font(.subheadline).foregroundStyle(StudyStudioStyle.secondary)
            SignInWithAppleButton(.signIn) { request in
                session.errorMessage = nil
                nonce = CommunitySession.makeNonce()
                request.nonce = CommunitySession.hashedNonce(nonce)
                request.requestedScopes = [.fullName]
            } onCompletion: { result in
                switch result {
                case .success(let authorization):
                    guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                          let tokenData = credential.identityToken, let token = String(data: tokenData, encoding: .utf8) else {
                        session.errorMessage = "Apple did not provide a sign-in token. Please try again."
                        return
                    }
                    let signInNonce = nonce
                    Task { await session.signIn(identityToken: token, nonce: signInNonce, givenName: credential.fullName?.givenName) }
                case .failure(let error):
                    if (error as? ASAuthorizationError)?.code != .canceled {
                        session.errorMessage = "Apple sign-in could not finish. Make sure you’re signed in to your Apple Account in Settings, then try again."
                    }
                }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 48)
            .disabled(session.isSigningIn)
            if session.isSigningIn { ProgressView("Signing in…") }
        }
    }

    @MainActor
    private func publish() async {
        guard let deck = selectedDeck, let token = session.token else { return }
        isPublishing = true
        publishError = nil
        defer { isPublishing = false }
        do {
            let id = try await CommunityDeckTransfer.publish(deck: deck, category: category, description: deckDescription, token: token) { progress = $0 }
            deck.publishedCommunityID = id
            deck.communityCategory = category
            deck.communityDescription = deckDescription
            try context.save()
            isPublished = true
            HapticFeedback.success()
            NotificationCenter.default.post(name: .communityLibraryChanged, object: nil)
        } catch { session.handle(error); publishError = error.localizedDescription }
    }

    @MainActor
    private func remove() async {
        guard let deck = selectedDeck, let id = deck.publishedCommunityID, let token = session.token else { return }
        isPublishing = true
        progress = "Removing public deck…"
        defer { isPublishing = false }
        do {
            try await CommunityAPI().remove(deckID: id, token: token)
            deck.publishedCommunityID = nil
            try context.save()
            isPublished = false
            NotificationCenter.default.post(name: .communityLibraryChanged, object: nil)
        } catch { session.handle(error); publishError = error.localizedDescription }
    }
}
