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
    private var course: CourseDefinition { catalog.course(for: originalCourse.id) ?? originalCourse }
    private var topics: [LanguageDeckProjection.Topic] { LanguageDeckProjection.topics(course) }
    private var saved: Bool { savedCollections.split(separator: "|").contains(Substring(course.id)) || CourseProgressManager.shared.isEnrolled(in: course.id) }
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 14) {
                    Text(course.flagEmoji).font(.largeTitle)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(course.language).font(.title.bold())
                        Text("\(topics.count) topic decks").font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !saved { Button("Add") { addCollection() }.buttonStyle(.bordered) }
                }.padding(.bottom, 24)
                ForEach(topics) { topic in
                    Button {
                        do { selected = try LanguageTopicStore.open(course: course, topic: topic, context: context); addCollection() }
                        catch { failure = "This topic couldn’t be saved. Please try again." }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "rectangle.stack").font(.title3).foregroundStyle(Color(hex: course.colorHex))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(topic.title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                                Text("\(topic.cards.count) cards").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                        }.padding(.vertical, 16).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                    Divider()
                }
            }.padding(20).frame(maxWidth: 760).frame(maxWidth: .infinity)
        }.background(LearnAlertStyle.courseCanvas).navigationTitle(course.language).navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $selected) { DeckDetailView(deck: $0) }
            .alert("Language deck", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) { Button("OK") { failure = nil } } message: { Text(failure ?? "") }
    }
    private func addCollection() {
        if !saved { savedCollections = (savedCollections.split(separator: "|").map(String.init) + [course.id]).joined(separator: "|") }
    }
}

