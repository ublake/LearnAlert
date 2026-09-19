import SwiftData
import SwiftUI

struct HelpView: View {
    @Query private var decks: [Deck]
    @State private var selectedDeckId = "NONE"
    @State private var showingEmptyDeckAlert = false

    private var selectedDeck: Deck? {
        decks.first { $0.id.uuidString == selectedDeckId }
    }

    var body: some View {
        ZStack {
            CoursezyBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HelpIntro()
                    HelpQuestions()
                    HelpContact()
                    NotificationTestSection(
                        decks: decks,
                        selectedDeckId: $selectedDeckId,
                        testNotification: testNotification
                    )
                }
                .padding(20)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("Help")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Empty Deck", isPresented: $showingEmptyDeckAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Add at least one card to this deck before testing a notification.")
        }
    }

    private func testNotification() {
        guard let selectedDeck, let card = selectedDeck.cards.randomElement() else {
            showingEmptyDeckAlert = true
            return
        }
        NotificationManager.shared.scheduleRealCard(card, at: Date().addingTimeInterval(3), progress: "Test")
    }
}

private struct HelpIntro: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("How can we help?", systemImage: "questionmark.bubble.fill").font(.title2.bold())
            Text("Find quick answers below. If something still isn’t working, contact the developer and include what you were trying to do.")
                .foregroundStyle(LearnAlertStyle.textSecondary)
        }
        .coursezyCard()
    }
}

private struct HelpQuestions: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("COMMON QUESTIONS").font(.caption.bold()).foregroundStyle(.secondary)
            DisclosureGroup("Why didn’t I receive an alert?") {
                Text("Check that notifications are allowed in iOS Settings, LearnAlert scheduling is active, and your selected time range has not ended.")
            }
            Divider()
            DisclosureGroup("Why won’t a notification open fully?") {
                Text("Press and hold the notification to expand the interactive flashcard. A normal tap opens LearnAlert instead.")
            }
            Divider()
            DisclosureGroup("How does AI deck generation work?") {
                Text("Paste notes or attach a supported file in Generate Deck. Review and edit the temporary cards before tapping Add Deck.")
            }
            Divider()
            DisclosureGroup("Will deleting the app remove my decks?") {
                Text("On-device data may be removed when the app is deleted. Download your data first if you want a personal copy.")
            }
        }
        .coursezyCard()
    }
}

private struct HelpContact: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CONTACT").font(.caption.bold()).foregroundStyle(.secondary)
            Link(destination: URL(string: "mailto:learnalertapp@gmail.com")!) {
                Label("learnalertapp@gmail.com", systemImage: "envelope.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .coursezyCard()
    }
}

private struct NotificationTestSection: View {
    let decks: [Deck]
    @Binding var selectedDeckId: String
    let testNotification: () -> Void

    private var selectedDeckName: String {
        decks.first { $0.id.uuidString == selectedDeckId }?.name ?? "Select a Deck"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TRY A NOTIFICATION").font(.caption.bold()).foregroundStyle(.secondary)
            Text("Choose a deck and LearnAlert will send one test notification in about three seconds.")
                .font(.subheadline).foregroundStyle(LearnAlertStyle.textSecondary)
            Menu {
                Picker("Deck", selection: $selectedDeckId) {
                    Text("Select a Deck").tag("NONE")
                    ForEach(decks) { deck in Text(deck.name).tag(deck.id.uuidString) }
                }
            } label: {
                HStack {
                    Text(selectedDeckName)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                }
                .coursezyField()
            }
            Button(action: testNotification) {
                Label("Try Notification", systemImage: "bell.and.waves.left.and.right.fill")
                    .font(.headline.bold()).frame(maxWidth: .infinity).padding(.vertical, 14)
            }
            .foregroundStyle(.white)
            .background(selectedDeckId == "NONE" ? Color.gray : LearnAlertStyle.indigo)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .disabled(selectedDeckId == "NONE")
        }
        .coursezyCard()
    }
}
