import SwiftUI
import SwiftData

/// Language discovery presents independently saved decks. Catalog documents are
/// reused as content sources; their former progression has no place in this UI.
struct LanguageDeckDiscoveryView: View {
    let originalCourse: CourseDefinition
    @ObservedObject private var catalog = ManagedCatalogStore.shared
    @Environment(\.modelContext) private var context
    @Environment(\.usesNativeStudyNavigation) private var usesNativeStudyNavigation
    @State private var addedDeckName: String?
    @State private var failure: String?

    init(course: CourseDefinition) { originalCourse = course }

    private var course: CourseDefinition { catalog.course(for: originalCourse.id) ?? originalCourse }
    private var topics: [LanguageDeckProjection.Topic] { LanguageDeckProjection.topics(course) }
    private var recommended: [LanguageDeckProjection.Topic] { Array(topics.prefix(4)) }

    private struct TopicGroup: Identifiable {
        let id: String
        let title: String
        let topics: [LanguageDeckProjection.Topic]
    }

    private var moreGroups: [TopicGroup] {
        let byID = Dictionary(topics.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var assigned = Set(recommended.map(\.id))
        var groups: [TopicGroup] = []
        for unit in course.units {
            let members = unit.lessons.compactMap { byID[$0.id] }.filter { !assigned.contains($0.id) }
            guard !members.isEmpty else { continue }
            assigned.formUnion(members.map(\.id))
            let title = unit.title.replacingOccurrences(of: #"^(?:Unit|Level)\s+\d+\s*[:·.—-]*\s*"#, with: "", options: [.regularExpression, .caseInsensitive])
            groups.append(TopicGroup(id: unit.id, title: title.localizedCaseInsensitiveContains("start here") ? "Introduction & basics" : title, topics: members))
        }
        let remaining = topics.filter { !assigned.contains($0.id) }
        if !remaining.isEmpty { groups.append(TopicGroup(id: "more", title: "More decks", topics: remaining)) }
        return groups
    }

    var body: some View {
        GeometryReader { geometry in
            let cardWidth = min(310, max(208, geometry.size.width - 66))
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    header
                    if topics.isEmpty {
                        ContentUnavailableView("No decks available", systemImage: "rectangle.stack", description: Text("Check back for new \(course.language) decks."))
                            .padding(.horizontal, 20)
                    } else {
                        deckRow(title: "Recommended decks", members: recommended, cardWidth: cardWidth)
                        if !moreGroups.isEmpty {
                            Text("More to explore")
                                .font(StudyStudioStyle.title(23))
                                .foregroundStyle(LearnAlertStyle.textPrimary)
                                .padding(.horizontal, 20)
                                .padding(.top, 4)
                            ForEach(moreGroups) { group in
                                deckRow(title: group.title, members: group.topics, cardWidth: cardWidth)
                            }
                        }
                    }
                }
                .padding(.top, 12)
                .padding(.bottom, usesNativeStudyNavigation ? 28 : 112)
                .frame(maxWidth: 980, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        }
        .background(StudyStudioStyle.canvas.ignoresSafeArea())
        .navigationTitle(course.language)
        .navigationBarTitleDisplayMode(.inline)
        .tint(LearnAlertStyle.appAccentForeground)
        .alert("Added to Library", isPresented: Binding(get: { addedDeckName != nil }, set: { if !$0 { addedDeckName = nil } })) {
            Button("Done", role: .cancel) { }
        } message: {
            Text("\(addedDeckName ?? "This deck") is ready to study in your library.")
        }
        .alert("Deck couldn’t be added", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(failure ?? "Please try again.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(course.language).font(StudyStudioStyle.title(34))
                Text(course.flagEmoji).font(.system(size: 31)).accessibilityHidden(true)
            }
            .foregroundStyle(LearnAlertStyle.textPrimary)
            Text("Vocabulary, grammar and everyday conversations. Pick a deck and learn at your own pace.")
                .font(StudyStudioStyle.body(15))
                .foregroundStyle(LearnAlertStyle.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 2)
    }

    private func deckRow(title: String, members: [LanguageDeckProjection.Topic], cardWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(StudyStudioStyle.heading(20))
                .foregroundStyle(LearnAlertStyle.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 20)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 14) {
                    ForEach(members) { topic in
                        LanguageDiscoveryDeckCard(topic: topic, palette: palette(for: topic)) { add(topic) }
                            .frame(width: cardWidth)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 20)
                .padding(.bottom, 7)
            }
            .scrollTargetBehavior(.viewAligned)
        }
    }

    private func palette(for topic: LanguageDeckProjection.Topic) -> LanguageDiscoveryPalette {
        let index = topics.firstIndex(where: { $0.id == topic.id }) ?? 0
        return LanguageDiscoveryPalette.all[index % LanguageDiscoveryPalette.all.count]
    }

    private func add(_ topic: LanguageDeckProjection.Topic) {
        do {
            _ = try LanguageTopicStore.open(course: course, topic: topic, context: context)
            InteractionSoundPlayer.shared.play(.addDeck)
            HapticFeedback.success()
            addedDeckName = topic.title
        } catch {
            failure = "This deck couldn’t be saved. Please try again."
        }
    }
}

private struct LanguageDiscoveryPalette {
    let color: Color
    let symbol: String

    static let all = [
        Self(color: Color(hex: "#E4A47B"), symbol: "character.book.closed.fill"),
        Self(color: Color(hex: "#AB8DE3"), symbol: "text.alignleft"),
        Self(color: Color(hex: "#76B88C"), symbol: "bubble.left.and.bubble.right.fill"),
        Self(color: Color(hex: "#80AFE0"), symbol: "rectangle.on.rectangle")
    ]
}

private struct LanguageDiscoveryDeckCard: View {
    let topic: LanguageDeckProjection.Topic
    let palette: LanguageDiscoveryPalette
    let add: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 7) {
                Text(topic.title)
                    .font(StudyStudioStyle.title(23))
                    .foregroundStyle(LearnAlertStyle.textPrimary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 3)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(topic.cards.count) cards")
                    .font(StudyStudioStyle.body(14))
                    .foregroundStyle(LearnAlertStyle.textSecondary)
            }
            .frame(maxWidth: .infinity, minHeight: 99, alignment: .topLeading)

            LanguageDiscoveryArtwork(color: palette.color, symbol: palette.symbol)
                .frame(height: 100)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)

            Button(action: add) {
                Text("Add to library")
                    .font(StudyStudioStyle.heading(15))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .foregroundStyle(LearnAlertStyle.appAccentInk)
                    .background(LearnAlertStyle.appAccent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add \(topic.title) to library")
            .accessibilityHint("Adds this independent \(topic.cards.count)-card deck")
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 23, style: .continuous)
                .fill(LearnAlertStyle.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 23, style: .continuous)
                        .fill(LinearGradient(colors: [palette.color.opacity(colorScheme == .dark ? 0.26 : 0.32), palette.color.opacity(colorScheme == .dark ? 0.13 : 0.19)], startPoint: .topLeading, endPoint: .bottomTrailing))
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 23, style: .continuous)
                .strokeBorder(palette.color.opacity(colorScheme == .dark ? 0.36 : 0.3), lineWidth: 1)
        }
        .shadow(color: LearnAlertStyle.cardShadow, radius: 6, y: 3)
    }
}

/// Decorative card artwork carries no invented vocabulary or preview content.
private struct LanguageDiscoveryArtwork: View {
    let color: Color
    let symbol: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(color.opacity(0.36))
                .frame(width: 126, height: 78)
                .rotationEffect(.degrees(13))
                .offset(x: 12, y: 8)
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(LearnAlertStyle.surface)
                .overlay {
                    HStack(spacing: 12) {
                        Image(systemName: symbol)
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(color)
                        VStack(alignment: .leading, spacing: 7) {
                            Capsule().frame(width: 38, height: 4)
                            Capsule().frame(width: 30, height: 4)
                            Capsule().frame(width: 20, height: 4)
                        }
                        .foregroundStyle(color.opacity(0.6))
                    }
                }
                .frame(width: 126, height: 78)
                .rotationEffect(.degrees(-9))
                .offset(x: -5, y: -3)
                .shadow(color: color.opacity(0.18), radius: 5, y: 5)
            Image(systemName: "sparkle")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
                .offset(x: 85, y: -35)
        }
        .accessibilityHidden(true)
    }
}
