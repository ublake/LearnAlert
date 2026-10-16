import SwiftUI
import Charts

struct CommunityLikesActivityView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var session = CommunitySession.shared
    @State private var likes: [CommunityReceivedLike] = []
    @State private var deckCounts: [CommunityDeckLikeCount] = []
    @State private var totalCount = 0
    @State private var nextOffset: Int?
    @State private var loading = false
    @State private var loadingMore = false
    @State private var requestID = UUID()
    @State private var loadedToken: String?
    @State private var failedToLoadMore = false
    @State private var error: String?
    @State private var selectedAuthor: LikesAuthorTarget?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if session.isSignedIn && loadedToken == session.token {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Image(systemName: "heart.fill").foregroundStyle(.pink)
                            Text(totalCount.formatted()).font(.largeTitle.weight(.bold)).monospacedDigit()
                            Text(totalCount == 1 ? "heart received" : "hearts received")
                                .font(.subheadline).foregroundStyle(LearnAlertStyle.textSecondary)
                        }
                        if !deckCounts.isEmpty { CommunityHeartsChart(counts: deckCounts) }
                        if !likes.isEmpty {
                            Text("From the community").font(.headline)
                            LazyVStack(spacing: 0) {
                                ForEach(Array(likes.enumerated()), id: \.element.id) { index, like in
                                    likeRow(like)
                                        .onAppear {
                                            if index >= likes.count - 3, error == nil { Task { await loadMore() } }
                                        }
                                    Divider().overlay(LearnAlertStyle.hairline.opacity(0.3))
                                }
                            }
                        } else if !loading && error == nil {
                            ContentUnavailableView("A little appreciation", systemImage: "heart",
                                description: Text("Hearts from the community will appear here."))
                        }
                        if loading || loadingMore { ProgressView().frame(maxWidth: .infinity, minHeight: 60) }
                        if let error {
                            Text(error).font(.subheadline).foregroundStyle(LearnAlertStyle.textSecondary)
                            Button("Try again") { Task { if failedToLoadMore { await loadMore() } else { await load() } } }.frame(minHeight: 44)
                        } else if nextOffset != nil && !loadingMore {
                            Button("Load more") { Task { await loadMore() } }.frame(maxWidth: .infinity, minHeight: 44)
                        }
                    } else if session.isSignedIn {
                        if let error {
                            Text(error).font(.subheadline).foregroundStyle(LearnAlertStyle.textSecondary)
                            Button("Try again") { Task { await load() } }.frame(minHeight: 44)
                        } else { ProgressView().frame(maxWidth: .infinity, minHeight: 180) }
                    } else {
                        ContentUnavailableView("Sign in to see your hearts", systemImage: "heart")
                    }
                }
                .padding(22).frame(maxWidth: 560).frame(maxWidth: .infinity)
            }
            .background(LearnAlertStyle.courseCanvas.ignoresSafeArea())
            .foregroundStyle(LearnAlertStyle.textPrimary)
            .navigationTitle("Community hearts").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .task(id: session.token) { await load(clear: true) }
            .onChange(of: session.token) { _, _ in selectedAuthor = nil }
            .onReceive(NotificationCenter.default.publisher(for: .communityLibraryChanged)) { _ in
                selectedAuthor = nil; loadedToken = nil; likes = []; deckCounts = []; totalCount = 0
                Task { await load(clear: true) }
            }
            .refreshable { await load() }
            .sheet(item: $selectedAuthor) { CommunityPublicProfileView(authorID: $0.id) }
        }
        .tint(LearnAlertStyle.appAccentForeground)
    }

    private func likeRow(_ like: CommunityReceivedLike) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Button { selectedAuthor = LikesAuthorTarget(id: like.authorID) } label: {
                CommunityAvatarView(avatar: like.avatar).frame(width: 42, height: 42)
            }
            .buttonStyle(.plain).accessibilityLabel("View \(like.handle)’s profile")
            VStack(alignment: .leading, spacing: 4) {
                Button { selectedAuthor = LikesAuthorTarget(id: like.authorID) } label: {
                    Text(like.handle).font(.subheadline.weight(.semibold)).underline()
                }.buttonStyle(.plain)
                Text(like.deckName).font(.subheadline).foregroundStyle(LearnAlertStyle.textSecondary).lineLimit(2)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 6) {
                Image(systemName: "heart.fill").font(.caption).foregroundStyle(.pink)
                Text(Date(timeIntervalSince1970: TimeInterval(like.createdAt)), style: .date)
                    .font(.caption2).foregroundStyle(LearnAlertStyle.textSecondary)
            }
        }.padding(.vertical, 14)
    }

    @MainActor private func load(clear: Bool = false) async {
        let id = UUID(); requestID = id
        if clear { likes = []; deckCounts = []; totalCount = 0; nextOffset = nil; error = nil; loadedToken = nil }
        guard let token = session.token else { return }
        loading = true; error = nil; failedToLoadMore = false
        defer { if requestID == id { loading = false } }
        do {
            let page = try await CommunityAPI().receivedLikes(token: token)
            guard requestID == id, session.token == token, !Task.isCancelled else { return }
            likes = page.likes; deckCounts = page.deckCounts; totalCount = page.totalCount; nextOffset = page.nextOffset; loadedToken = token
        } catch {
            guard requestID == id, session.token == token, !Task.isCancelled else { return }
            failedToLoadMore = false
            session.handle(error); self.error = error.localizedDescription
        }
    }

    @MainActor private func loadMore() async {
        guard !loading, !loadingMore, let offset = nextOffset, let token = session.token else { return }
        let id = requestID
        loadingMore = true
        defer { loadingMore = false }
        do {
            let page = try await CommunityAPI().receivedLikes(offset: offset, token: token)
            guard requestID == id, session.token == token, !Task.isCancelled else { return }
            let known = Set(likes.map(\.id))
            likes.append(contentsOf: page.likes.filter { !known.contains($0.id) })
            deckCounts = page.deckCounts; totalCount = page.totalCount
            nextOffset = page.nextOffset.flatMap { $0 > offset ? $0 : nil }; error = nil
        } catch {
            guard requestID == id, session.token == token, !Task.isCancelled else { return }
            failedToLoadMore = true
            session.handle(error); self.error = error.localizedDescription
        }
    }
}

private struct LikesAuthorTarget: Identifiable { let id: String }

private struct CommunityHeartsChart: View {
    let counts: [CommunityDeckLikeCount]
    private var topDecks: [CommunityDeckLikeCount] { Array(counts.sorted { $0.likeCount > $1.likeCount }.prefix(8)) }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Hearts by deck").font(.headline)
            Chart(topDecks) { item in
                BarMark(x: .value("Hearts", item.likeCount), y: .value("Deck", item.deckID))
                    .foregroundStyle(Color.pink.gradient).cornerRadius(4)
                    .annotation(position: .trailing) { Text(item.likeCount.formatted()).font(.caption.weight(.semibold)) }
            }
            .chartXAxis { AxisMarks(values: .automatic(desiredCount: 3)) }
            .chartYAxis {
                AxisMarks(values: topDecks.map(\.deckID)) { value in
                    AxisValueLabel {
                        if let id = value.as(String.self), let item = topDecks.first(where: { $0.deckID == id }) {
                            Text(item.deckName).font(.caption).lineLimit(1).frame(maxWidth: 100, alignment: .trailing)
                        }
                    }
                }
            }
            .chartXScale(domain: 0...max(1, (topDecks.map(\.likeCount).max() ?? 1) + 1))
            .frame(height: CGFloat(max(1, topDecks.count)) * 38 + 24)
            .accessibilityLabel("Hearts by deck")
        }.padding(16).appCardSurface(cornerRadius: 18)
    }
}
