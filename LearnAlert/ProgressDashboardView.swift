import SwiftData
import SwiftUI

struct ProgressDashboardView: View {
    @Query(sort: \Deck.creationDate) private var decks: [Deck]
    @ObservedObject private var courseProgress = CourseProgressManager.shared
    @ObservedObject private var session = CommunitySession.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var profileDestination: ProgressProfileDestination?
    @State private var showingLikes = false
    @State private var refreshingProfile = false
    @State private var refreshID = UUID()

    private var likesUnlocked: Bool {
        session.isSignedIn && (session.profile.stats?.hasReceivedLikes == true || (session.profile.stats?.receivedLikeCount ?? 0) > 0)
    }

    var body: some View {
        let summary = StudyProgressSummary(decks: decks, courses: courseProgress.allEnrolledCourses,
                                           snapshot: courseProgress.learningSnapshot)
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                studyOverview(summary)
                if !summary.courses.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader("Courses", count: summary.courses.count)
                        ForEach(summary.courses) { course in courseRow(course) }
                    }
                }
                if !summary.decks.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader("Decks", count: summary.decks.count)
                        VStack(spacing: 0) {
                            ForEach(Array(summary.decks.enumerated()), id: \.element.id) { index, deck in
                                deckRow(deck)
                                if index + 1 < summary.decks.count {
                                    Divider().overlay(LearnAlertStyle.hairline.opacity(0.4)).padding(.horizontal, 16)
                                }
                            }
                        }
                        .appCardSurface(cornerRadius: 20)
                    }
                }
                if summary.courses.isEmpty && summary.decks.isEmpty {
                    ContentUnavailableView("No courses or decks yet", systemImage: "rectangle.stack",
                        description: Text("Add something to your library to start tracking progress."))
                        .frame(maxWidth: .infinity)
                }
                if session.isSignedIn { communitySection }
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .background(LearnAlertStyle.courseCanvas.ignoresSafeArea())
        .navigationTitle("Progress")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(LearnAlertStyle.courseCanvas, for: .navigationBar)
        .refreshable { await refresh() }
        .task(id: session.token) { await refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await refresh() } }
        }
        .onChange(of: session.token) { _, _ in
            profileDestination = nil
            showingLikes = false
        }
        .onReceive(NotificationCenter.default.publisher(for: .communityLibraryChanged)) { _ in Task { await refresh() } }
        .sheet(item: $profileDestination, onDismiss: { Task { await refresh() } }) { destination in CommunityPublicProfileView(authorID: destination.id) }
        .sheet(isPresented: $showingLikes, onDismiss: { Task { await refresh() } }) {
            if likesUnlocked { CommunityLikesActivityView() }
        }
        .tint(LearnAlertStyle.appAccentForeground)
    }

    private func studyOverview(_ summary: StudyProgressSummary) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Study").font(.title3.weight(.semibold)).foregroundStyle(LearnAlertStyle.textPrimary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ProgressMetric(title: "Reviews", value: summary.reviewCount.formatted(), icon: "arrow.clockwise")
                ProgressMetric(title: "Cards reviewed", value: summary.reviewedCardCount.formatted(), icon: "rectangle.stack")
                ProgressMetric(title: "Mastered", value: summary.masteredCardCount.formatted(), icon: "checkmark.seal")
                ProgressMetric(title: "Quiz accuracy", value: summary.quizAccuracy?.formatted(.percent.precision(.fractionLength(0))) ?? "—", icon: "scope")
                    .accessibilityHint("Multiple-choice, matching, and fill-in cards in your decks")
            }
            masteryStrip(summary)
        }
    }

    private func masteryStrip(_ summary: StudyProgressSummary) -> some View {
        VStack(spacing: 10) {
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    LearnAlertStyle.green.frame(width: geometry.size.width * Double(summary.masteredCardCount) / Double(max(1, summary.cardCount)))
                    LearnAlertStyle.appAccent.frame(width: geometry.size.width * Double(summary.learningCardCount) / Double(max(1, summary.cardCount)))
                    LearnAlertStyle.insetSurface
                }
            }
            .frame(height: 7).clipShape(Capsule()).accessibilityHidden(true)
            HStack(spacing: 12) {
                masteryLabel("Mastered", count: summary.masteredCardCount, color: LearnAlertStyle.green)
                Spacer(minLength: 0)
                masteryLabel("Learning", count: summary.learningCardCount, color: LearnAlertStyle.appAccentForeground)
                Spacer(minLength: 0)
                masteryLabel("New", count: summary.newCardCount, color: LearnAlertStyle.textSecondary)
            }
        }
        .padding(14).appCardSurface(cornerRadius: 16)
    }

    private func masteryLabel(_ title: String, count: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Circle().fill(color).frame(width: 5, height: 5).accessibilityHidden(true)
                Text(count.formatted()).font(.subheadline.weight(.semibold)).monospacedDigit().foregroundStyle(LearnAlertStyle.textPrimary)
            }
            Text(title).font(.caption).foregroundStyle(LearnAlertStyle.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title).font(.title3.weight(.semibold)).foregroundStyle(LearnAlertStyle.textPrimary)
            Spacer()
            Text(count.formatted()).font(.subheadline).monospacedDigit().foregroundStyle(LearnAlertStyle.textSecondary)
        }
    }

    private func courseRow(_ course: StudyProgressSummary.CourseProgress) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text(course.flagEmoji).font(.title2).accessibilityHidden(true)
                Text(course.title).font(.headline).foregroundStyle(LearnAlertStyle.textPrimary)
                Spacer(minLength: 8)
                Text(course.fraction, format: .percent.precision(.fractionLength(0)))
                    .font(.subheadline.weight(.semibold)).monospacedDigit().foregroundStyle(LearnAlertStyle.appAccentForeground)
            }
            ProgressView(value: course.fraction).tint(LearnAlertStyle.appAccentForeground).accessibilityLabel("Course completion")
            Text(course.currentStep).font(.subheadline).foregroundStyle(LearnAlertStyle.textSecondary).lineLimit(2)
            HStack(spacing: 14) {
                Label("\(course.completedLessonCount)/\(course.lessonCount) lessons", systemImage: "book.closed")
                if course.checkpointCount > 0 {
                    Label("\(course.passedCheckpointCount)/\(course.checkpointCount) checkpoints", systemImage: "checkmark.seal")
                }
            }
            .font(.caption).foregroundStyle(LearnAlertStyle.textSecondary)
        }
        .padding(16).appCardSurface(cornerRadius: 20)
    }

    private func deckRow(_ deck: StudyProgressSummary.DeckProgress) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: deck.isCommunity ? "person.2" : "rectangle.stack")
                    .font(.subheadline.weight(.medium)).foregroundStyle(Color(hex: deck.colorHex))
                    .frame(width: 32, height: 32)
                    .background(Color(hex: deck.colorHex).opacity(0.1), in: RoundedRectangle(cornerRadius: 9))
                    .accessibilityLabel(deck.isCommunity ? "Community deck" : "Deck")
                VStack(alignment: .leading, spacing: 3) {
                    Text(deck.name).font(.subheadline.weight(.semibold)).foregroundStyle(LearnAlertStyle.textPrimary).lineLimit(2)
                    Text("\(deck.reviewedCardCount) of \(deck.cardCount) cards reviewed").font(.caption).foregroundStyle(LearnAlertStyle.textSecondary)
                }
                Spacer(minLength: 8)
                Text(deck.masteryFraction, format: .percent.precision(.fractionLength(0)))
                    .font(.subheadline.weight(.semibold)).monospacedDigit().foregroundStyle(LearnAlertStyle.appAccentForeground)
                    .accessibilityLabel("\(Int((deck.masteryFraction * 100).rounded())) percent mastery")
            }
            ProgressView(value: deck.masteryFraction).tint(LearnAlertStyle.appAccentForeground).accessibilityLabel("Deck mastery")
        }
        .padding(16)
    }

    private var communitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Community").font(.title3.weight(.semibold)).foregroundStyle(LearnAlertStyle.textPrimary)
            if let authorID = session.profile.authorID {
                Button { profileDestination = ProgressProfileDestination(id: authorID) } label: {
                    HStack(spacing: 12) {
                        if session.profile.isComplete {
                            CommunityAvatarView(avatar: session.profile.avatar).frame(width: 42, height: 42)
                                .clipShape(RoundedRectangle(cornerRadius: 12)).accessibilityHidden(true)
                        }
                        Text(session.profile.handle).font(.headline).foregroundStyle(LearnAlertStyle.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(LearnAlertStyle.textSecondary)
                    }
                    .padding(14).appCardSurface(cornerRadius: 16)
                }
                .buttonStyle(.plain).accessibilityHint("View your community profile")
            }
            if let stats = session.profile.stats {
                CommunityProfileStatsGrid(stats: stats)
                if likesUnlocked {
                    Button { showingLikes = true } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "heart.fill").foregroundStyle(.pink)
                            Text("Likes received").font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(stats.receivedLikeCount.formatted()).font(.subheadline).monospacedDigit()
                            Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(LearnAlertStyle.textPrimary).padding(16).appCardSurface(cornerRadius: 16)
                    }
                    .buttonStyle(.plain)
                }
            } else if refreshingProfile {
                ProgressView().frame(maxWidth: .infinity, minHeight: 54)
            } else {
                Text("Community stats are unavailable. Pull down to try again.").font(.subheadline).foregroundStyle(LearnAlertStyle.textSecondary)
            }
        }
    }

    @MainActor private func refresh() async {
        courseProgress.reloadFromSharedDefaults()
        let id = UUID()
        let token = session.token
        refreshID = id
        refreshingProfile = token != nil
        guard token != nil else { refreshingProfile = false; return }
        await session.refreshProfile()
        guard refreshID == id, session.token == token else { return }
        refreshingProfile = false
    }
}

private struct ProgressProfileDestination: Identifiable { let id: String }

private struct ProgressMetric: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: icon).font(.system(size: 19, weight: .medium)).foregroundStyle(LearnAlertStyle.appAccentForeground)
                .frame(width: 24).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(value).font(.title2.weight(.semibold)).monospacedDigit().foregroundStyle(LearnAlertStyle.textPrimary)
                    .lineLimit(1).minimumScaleFactor(0.7)
                Text(title).font(.caption).foregroundStyle(LearnAlertStyle.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .padding(14).appCardSurface(cornerRadius: 16).accessibilityElement(children: .combine)
    }
}
