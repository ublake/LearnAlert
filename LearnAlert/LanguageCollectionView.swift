import SwiftUI
import SwiftData

struct CoursePathView: View {
    let course: CourseDefinition
    var initialCheckpointSectionId: String? = nil
    var body: some View { LanguageCollectionView(originalCourse: course) }
}

struct LanguageCollectionView: View {
    let originalCourse: CourseDefinition
    @ObservedObject private var catalog = ManagedCatalogStore.shared
    @Environment(\.modelContext) private var context
    @Query private var decks: [Deck]
    @AppStorage("languageCollections") private var savedCollections = ""
    @State private var selected: Deck?
    @State private var failure: String?
    @State private var bundle: Deck?
    private var course: CourseDefinition { catalog.course(for: originalCourse.id) ?? originalCourse }
    private var topics: [LanguageDeckProjection.Topic] { LanguageDeckProjection.topics(course) }
    private var levels: [LanguageDeckProjection.Level] { LanguageDeckProjection.levels(course) }
    private var saved: Bool { savedCollections.split(separator: "|").contains(Substring(course.id)) || CourseProgressManager.shared.isEnrolled(in: course.id) }
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 14) {
                    Text(course.flagEmoji).font(.largeTitle)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(course.language).font(.title.bold())
                        Text("\(levels.count) levels · \(topics.count) topic decks").font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !saved { Button("Add") { addCollection() }.buttonStyle(.bordered) }
                }.padding(.bottom, 24)
                if let bundle {
                    BundleLevelPicker(deck: bundle, settings: Binding(get: { bundle.alertSettings ?? StudyEngine.shared.globalSettings }, set: { setLevel($0, for: bundle) }))
                        .padding(.bottom, 20)
                }
                ForEach(Array(levels.enumerated()), id: \.element.id) { index, level in
                    LanguageBundleLevelCard(
                        level: level,
                        number: index + 1,
                        isCurrent: bundle.map({ LanguageBundleStudy.activeLevel($0)?.sourceCourseUnitID == level.id }) == true
                    ) { topic in
                        do { selected = try LanguageTopicStore.open(course: course, topic: topic, context: context); addCollection() }
                        catch { failure = "This topic couldn’t be saved. Please try again." }
                    }
                    .padding(.bottom, 20)
                }
            }.padding(20).frame(maxWidth: 760).frame(maxWidth: .infinity)
        }.background(LearnAlertStyle.courseCanvas).navigationTitle(course.language).navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $selected) { DeckDetailView(deck: $0) }
            .task(id: course) {
                await Task.yield()
                do { bundle = try LanguageTopicStore.collection(course: course, context: context) }
                catch { failure = "Your bundle couldn’t be loaded. Please try again." }
            }
            .alert("Language deck", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) { Button("OK") { failure = nil } } message: { Text(failure ?? "") }
    }
    private func addCollection() {
        if !saved { savedCollections = (savedCollections.split(separator: "|").map(String.init) + [course.id]).joined(separator: "|") }
    }
    private func setLevel(_ settings: DeckAlertSettings, for deck: Deck) {
        let previous = deck.alertSettings
        deck.alertSettings = settings
        do { try context.save() }
        catch { deck.alertSettings = previous; failure = error.localizedDescription; return }
        let engine = StudyEngine.shared
        guard engine.isActive, engine.activeDeckId == deck.id else { return }
        Task { @MainActor in
            do { _ = try await engine.startAlerts(for: deck) }
            catch { failure = "The level was saved, but alerts couldn’t be updated. Please schedule the bundle again." }
        }
    }
}

private struct LanguageBundleLevelCard: View {
    let level: LanguageDeckProjection.Level
    let number: Int
    let isCurrent: Bool
    let openTopic: (LanguageDeckProjection.Topic) -> Void
    @Environment(\.colorScheme) private var colorScheme

    private var accent: Color {
        let light = ["#427DA5", "#377F76", "#7A68AB", "#A46C47"]
        let dark = ["#9DC9EA", "#89C7B6", "#B9A7E0", "#DDB18C"]
        return Color(hex: (colorScheme == .dark ? dark : light)[(number - 1) % light.count])
    }
    private var symbol: String {
        ["sparkles", "square.stack.3d.up.fill", "bubble.left.and.bubble.right.fill", "star.fill"][(number - 1) % 4]
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            VStack(spacing: 0) {
                ForEach(Array(level.topics.enumerated()), id: \.element.id) { index, topic in
                    if index > 0 {
                        Rectangle()
                            .fill(LearnAlertStyle.hairline.opacity(colorScheme == .dark ? 0.55 : 0.45))
                            .frame(height: 0.5)
                            .padding(.leading, 58)
                    }
                    Button { openTopic(topic) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "rectangle.stack.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(accent)
                                .frame(width: 32, height: 36)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(topic.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(LearnAlertStyle.textPrimary)
                                    .multilineTextAlignment(.leading)
                                Text("\(topic.cards.count) cards")
                                    .font(.caption)
                                    .foregroundStyle(LearnAlertStyle.textSecondary)
                            }
                            Spacer(minLength: 6)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(accent.opacity(0.8))
                        }
                        .padding(.horizontal, 15)
                        .padding(.vertical, 13)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityHint("Opens topic deck")
                }
            }
            .padding(.vertical, 3)
        }
        .background(LearnAlertStyle.courseSurface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(isCurrent ? accent.opacity(0.65) : LearnAlertStyle.cardBorder, lineWidth: isCurrent ? 1.25 : 1)
                .allowsHitTesting(false)
        }
        .shadow(color: LearnAlertStyle.cardShadow, radius: 6, x: 0, y: 3)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(spacing: 1) {
                Text("LEVEL")
                    .font(.system(size: 8, weight: .heavy, design: .rounded))
                    .tracking(1.1)
                Text(String(format: "%02d", number))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundStyle(accent)
            .frame(width: 50, height: 54)
            .background(LearnAlertStyle.courseSurface.opacity(0.88), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(accent.opacity(0.24), lineWidth: 1)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(level.title)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(LearnAlertStyle.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                HStack(spacing: 7) {
                    Text("\(level.topics.count) \(level.topics.count == 1 ? "deck" : "decks")")
                        .font(.caption)
                        .foregroundStyle(LearnAlertStyle.textSecondary)
                    if isCurrent {
                        HStack(spacing: 4) {
                            Circle().fill(accent).frame(width: 4, height: 4)
                            Text("Current").font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(accent)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(accent.opacity(0.12), in: Capsule())
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(accent.opacity(0.17), lineWidth: 1.5)
                    .frame(width: 34, height: 39)
                    .rotationEffect(.degrees(-14))
                    .offset(x: -3, y: 2)
                Image(systemName: symbol)
                    .font(.system(size: 23, weight: .medium))
                    .foregroundStyle(accent.opacity(0.55))
                    .rotationEffect(.degrees(9))
            }
            .frame(width: 40, height: 48)
            .accessibilityHidden(true)
        }
        .padding(16)
        .background {
            LinearGradient(colors: [accent.opacity(colorScheme == .dark ? 0.16 : 0.14), accent.opacity(0.035)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(accent.opacity(0.2)).frame(height: 1)
        }
    }
}

