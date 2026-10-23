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
                    HStack {
                        Text("Level \(index + 1)").font(.caption.weight(.bold)).foregroundStyle(Color(hex: course.colorHex))
                        Text(level.title).font(.subheadline.weight(.semibold))
                        Spacer()
                        if bundle.map({ LanguageBundleStudy.activeLevel($0)?.sourceCourseUnitID == level.id }) == true {
                            Image(systemName: "play.circle.fill").foregroundStyle(Color(hex: course.colorHex))
                        }
                    }.padding(.top, index == 0 ? 0 : 24).padding(.bottom, 4)
                    ForEach(level.topics) { topic in
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

