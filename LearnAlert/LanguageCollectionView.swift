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
    @AppStorage("languageCollections") private var savedCollections = ""
    @State private var selected: Deck?
    @State private var failure: String?
    @State private var bundle: Deck?
    @State private var levelExpansion: [String: Bool] = [:]
    private var course: CourseDefinition { catalog.course(for: originalCourse.id) ?? originalCourse }
    private var topics: [LanguageDeckProjection.Topic] { LanguageDeckProjection.topics(course) }
    private var levels: [LanguageDeckProjection.Level] { LanguageDeckProjection.levels(course) }
    private var currentLevelID: String? { bundle.flatMap { LanguageBundleStudy.activeLevel($0)?.sourceCourseUnitID } ?? levels.first?.id }
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
                ForEach(Array(levels.enumerated()), id: \.element.id) { index, level in
                    LanguageBundleLevelCard(
                        courseID: course.id,
                        level: level,
                        number: index + 1,
                        isCurrent: currentLevelID == level.id,
                        isExpanded: Binding(
                            get: { levelExpansion[level.id] ?? (currentLevelID == level.id) },
                            set: { levelExpansion[level.id] = $0 }
                        )
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
}

private struct LanguageBundleLevelCard: View {
    let courseID: String
    let level: LanguageDeckProjection.Level
    let number: Int
    let isCurrent: Bool
    @Binding var isExpanded: Bool
    let openTopic: (LanguageDeckProjection.Topic) -> Void
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
            Button { isExpanded.toggle() } label: { header }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Level \(number), \(level.title), \(level.topics.count) decks\(isCurrent ? ", current level" : "")")
                .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
                .accessibilityHint(isExpanded ? "Hides topic decks" : "Shows topic decks")
                .accessibilityAddTraits(.isHeader)
            if isExpanded {
                topicRows
                    .transition(reduceMotion ? .identity : .opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(LearnAlertStyle.courseSurface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(isCurrent ? accent.opacity(0.65) : LearnAlertStyle.cardBorder, lineWidth: isCurrent ? 1.25 : 1)
                .allowsHitTesting(false)
        }
        .shadow(color: LearnAlertStyle.cardShadow, radius: 6, x: 0, y: 3)
        .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.9), value: isExpanded)
    }

    private var topicRows: some View {
        VStack(spacing: 0) {
                ForEach(Array(level.topics.enumerated()), id: \.element.id) { index, topic in
                    if index > 0 {
                        Rectangle()
                            .fill(LearnAlertStyle.hairline.opacity(colorScheme == .dark ? 0.55 : 0.45))
                            .frame(height: 0.5)
                            .padding(.leading, 58)
                    }
                    HStack(spacing: 6) {
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
                            .padding(.leading, 15)
                            .padding(.vertical, 13)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                        .accessibilityHint("Opens topic deck")
                        LanguageTopicImportanceMenu(courseID: courseID, topic: topic, accent: accent)
                            .padding(.trailing, 8)
                    }
                }
        }
        .padding(.vertical, 3)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(String(format: "%02d", number))
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .monospacedDigit()
            .foregroundStyle(accent)
            .frame(width: 50, height: 50)
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
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(accent)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .accessibilityHidden(true)
        }
        .padding(16)
        .background {
            LinearGradient(colors: [accent.opacity(colorScheme == .dark ? 0.16 : 0.14), accent.opacity(0.035)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        .overlay(alignment: .bottom) {
            if isExpanded { Rectangle().fill(accent.opacity(0.2)).frame(height: 1) }
        }
    }
}

private struct LanguageTopicImportanceMenu: View {
    let courseID: String
    let topic: LanguageDeckProjection.Topic
    let accent: Color
    @State private var selectedImportance: Int?

    private var importance: Int {
        selectedImportance ?? LanguageBundleStudy.importance(courseID: courseID, topicID: topic.id, authored: topic.importance)
    }

    var body: some View {
        Menu {
            Section("Importance · higher repeats more") {
                ForEach(1...10, id: \.self) { value in
                    Button { setImportance(value) } label: {
                        if value == importance {
                            Label("\(value)", systemImage: "checkmark")
                        } else {
                            Text("\(value)")
                        }
                    }
                }
            }
            Button("Reset to default (\(topic.importance))", systemImage: "arrow.counterclockwise") {
                setImportance(nil)
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "slider.horizontal.3").font(.system(size: 10, weight: .semibold))
                Text("\(importance)").font(.system(size: 11, weight: .semibold)).monospacedDigit()
            }
            .foregroundStyle(accent)
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(accent.opacity(0.08), in: Capsule())
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .accessibilityLabel("Importance for \(topic.title)")
        .accessibilityValue("\(importance) of 10")
        .accessibilityHint("Higher importance repeats this topic more often in bundle practice")
    }

    private func setImportance(_ value: Int?) {
        LanguageBundleStudy.setImportance(value, courseID: courseID, topicID: topic.id)
        selectedImportance = LanguageBundleStudy.importance(courseID: courseID, topicID: topic.id, authored: topic.importance)
    }
}

