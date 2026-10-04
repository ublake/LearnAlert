import SwiftData
import SwiftUI

struct ProgressDashboardView: View {
    @Query(sort: \Deck.creationDate) private var decks: [Deck]
    @ObservedObject private var engine = StudyEngine.shared
    @Environment(\.dismiss) private var dismiss

    private var cards: [Flashcard] { decks.flatMap(\.cards) }
    private var reviewCount: Int { cards.reduce(0) { $0 + $1.reviewCount } }
    private var correctCount: Int { cards.reduce(0) { $0 + $1.correctCount } }
    private var accuracy: Int { reviewCount == 0 ? 0 : Int((Double(correctCount) / Double(reviewCount) * 100).rounded()) }
    private var longestStreak: Int { cards.map(\.longestStreak).max() ?? 0 }
    private var studiedDeckCount: Int { decks.filter { $0.cards.contains { $0.reviewCount > 0 } }.count }
    private var firstStudyDate: Date? { cards.compactMap(\.lastReviewedDate).min() }

    private var masteredCount: Int { cards.filter { $0.masteryScore >= 3 }.count }
    private var learningCount: Int { cards.filter { $0.masteryScore > 0 && $0.masteryScore < 3 }.count }
    private var unlearnedCount: Int { cards.filter { $0.masteryScore == 0 }.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header Intro
                VStack(alignment: .leading, spacing: 4) {
                    Text("Study Analytics")
                        .font(.custom("Poppins-SemiBold", size: 20, relativeTo: .title2))
                        .foregroundStyle(LearnAlertStyle.textPrimary)
                    Text("Detailed overview of your alerts, accuracy, and streaks.")
                        .font(.custom("Poppins-Regular", size: 13, relativeTo: .subheadline))
                        .foregroundStyle(LearnAlertStyle.textSecondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                // 2x2 Core Metrics
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ProgressStatCard(
                        title: "Total Answers",
                        value: "\(reviewCount)",
                        icon: "checkmark.circle.fill",
                        color: LearnAlertStyle.sky
                    )
                    ProgressStatCard(
                        title: "Accuracy",
                        value: reviewCount == 0 ? "—" : "\(accuracy)%",
                        icon: "scope",
                        color: Color.green
                    )
                    ProgressStatCard(
                        title: "Best Streak",
                        value: "\(longestStreak)",
                        icon: "flame.fill",
                        color: Color.orange
                    )
                    ProgressStatCard(
                        title: "Decks Studied",
                        value: "\(studiedDeckCount)/\(decks.count)",
                        icon: "rectangle.stack.fill",
                        color: LearnAlertStyle.indigo
                    )
                }
                .padding(.horizontal, 20)

                // Mastery Breakdown
                VStack(alignment: .leading, spacing: 14) {
                    Text("MASTERY BREAKDOWN")
                        .font(.custom("Poppins-SemiBold", size: 11, relativeTo: .caption))
                        .tracking(1.1)
                        .foregroundStyle(LearnAlertStyle.textSecondary)

                    HStack(spacing: 12) {
                        MasteryChip(title: "Mastered", count: masteredCount, color: Color.green, icon: "checkmark.seal.fill")
                        MasteryChip(title: "Learning", count: learningCount, color: Color.blue, icon: "brain.head.profile")
                        MasteryChip(title: "New", count: unlearnedCount, color: Color.purple, icon: "sparkles")
                    }
                }
                .padding(18)
                .background(LearnAlertStyle.surface)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(LearnAlertStyle.hairline, lineWidth: 1)
                )
                .padding(.horizontal, 20)

                // Learning Journey Milestones
                VStack(alignment: .leading, spacing: 14) {
                    Text("LEARNING JOURNEY")
                        .font(.custom("Poppins-SemiBold", size: 11, relativeTo: .caption))
                        .tracking(1.1)
                        .foregroundStyle(LearnAlertStyle.textSecondary)

                    ProgressMilestone(
                        icon: "rectangle.stack.badge.plus",
                        title: "First Deck Created",
                        detail: decks.first?.creationDate.formatted(date: .abbreviated, time: .omitted) ?? "Not yet"
                    )
                    ProgressMilestone(
                        icon: "bell.badge.fill",
                        title: "Alert Learning Schedule",
                        detail: engine.isActive ? "Active · \(engine.activeDeckName)" : "No active schedule"
                    )
                    ProgressMilestone(
                        icon: "play.circle.fill",
                        title: "In-App Study Session",
                        detail: firstStudyDate?.formatted(date: .abbreviated, time: .shortened) ?? "No sessions yet"
                    )
                }
                .padding(18)
                .background(LearnAlertStyle.surface)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(LearnAlertStyle.hairline, lineWidth: 1)
                )
                .padding(.horizontal, 20)

                // Per-Deck Progress List
                if !decks.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("DECK PROGRESS")
                            .font(.custom("Poppins-SemiBold", size: 11, relativeTo: .caption))
                            .tracking(1.1)
                            .foregroundStyle(LearnAlertStyle.textSecondary)

                        VStack(spacing: 10) {
                            ForEach(decks) { deck in
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(deck.name)
                                            .font(.custom("Poppins-Medium", size: 14))
                                            .foregroundStyle(LearnAlertStyle.textPrimary)
                                        Text("\(deck.cards.count) cards · \(deck.cards.filter { $0.reviewCount > 0 }.count) reviewed")
                                            .font(.custom("Poppins-Regular", size: 11))
                                            .foregroundStyle(LearnAlertStyle.textSecondary)
                                    }

                                    Spacer()

                                    Text(deck.cycleProgress, format: .percent.precision(.fractionLength(0)))
                                        .font(.custom("Poppins-SemiBold", size: 14))
                                        .foregroundStyle(LearnAlertStyle.indigo)
                                }
                                .padding(12)
                                .background(Color.primary.opacity(0.04))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                        }
                    }
                    .padding(18)
                    .background(LearnAlertStyle.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(LearnAlertStyle.hairline, lineWidth: 1)
                    )
                    .padding(.horizontal, 20)
                }

                Spacer().frame(height: 80)
            }
            .padding(.top, 12)
        }
        .background(LearnAlertStyle.courseCanvas.ignoresSafeArea())
        .navigationTitle("Progress")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(LearnAlertStyle.courseCanvas, for: .navigationBar)
    }
}

private struct ProgressStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
                Spacer()
            }
            Text(value)
                .font(.custom("Poppins-SemiBold", size: 24, relativeTo: .title))
                .foregroundStyle(LearnAlertStyle.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(title)
                .font(.custom("Poppins-Regular", size: 11, relativeTo: .caption))
                .foregroundStyle(LearnAlertStyle.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(LearnAlertStyle.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(LearnAlertStyle.hairline, lineWidth: 1)
        )
    }
}

private struct MasteryChip: View {
    let title: String
    let count: Int
    let color: Color
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
            Text("\(count)")
                .font(.custom("Poppins-SemiBold", size: 16))
                .foregroundStyle(LearnAlertStyle.textPrimary)
            Text(title)
                .font(.custom("Poppins-Regular", size: 10))
                .foregroundStyle(LearnAlertStyle.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct ProgressMilestone: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(LearnAlertStyle.sky)
                .frame(width: 34, height: 34)
                .background(LearnAlertStyle.indigo.opacity(0.12))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.custom("Poppins-Medium", size: 13, relativeTo: .subheadline))
                    .foregroundStyle(LearnAlertStyle.textPrimary)
                Text(detail)
                    .font(.custom("Poppins-Regular", size: 11, relativeTo: .caption))
                    .foregroundStyle(LearnAlertStyle.textSecondary)
            }
            Spacer()
        }
    }
}
