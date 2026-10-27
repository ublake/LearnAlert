import SwiftUI
import SwiftData

struct DeckScheduleSettingsView: View {
    @Bindable var deck: Deck
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var useDeckSettings: Bool
    @State private var draft: DeckAlertSettings
    @State private var saving = false
    @State private var errorMessage: String?

    init(deck: Deck) {
        self.deck = deck
        _useDeckSettings = State(initialValue: deck.alertSettings != nil)
        _draft = State(initialValue: deck.alertSettings ?? StudyEngine.shared.globalSettings)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Add custom schedule settings for this deck", isOn: $useDeckSettings)
                } footer: {
                    Text("Remembers this deck’s pace and times. Alerts start when you schedule the deck.")
                }
                if useDeckSettings {
                    Section {
                        AlertPaceControls(settings: $draft,
                            automaticCount: DeckAlertSettings.automaticDailyCount(cardCount: deck.cards.count))
                    }
                    Section("Daily schedule") { DeckScheduleTimingFields(settings: $draft) }
                    Section {
                        Picker("Stop alerts", selection: $draft.stopCondition) {
                            Text("Until I say so").tag("Until I say so")
                            Text("Until deck learnt").tag("Until Deck Learnt")
                            Text("Until day ends").tag("Until Day Ends")
                        }
                        Picker("Card order", selection: $draft.smartSRS) {
                            Text("Smart review").tag(true)
                            Text("In deck order").tag(false)
                        }
                    }
                }
            }
            .navigationTitle("Custom schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(saving) }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).disabled(saving) }
            }
            .tint(LearnAlertStyle.appAccentForeground)
            .alert("Couldn’t update schedule", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: { Text(errorMessage ?? "Please try again.") }
        }
    }

    private func save() {
        let previous = deck.alertSettings
        deck.alertSettings = useDeckSettings ? draft : nil
        do { try context.save() }
        catch { deck.alertSettings = previous; errorMessage = error.localizedDescription; return }
        let engine = StudyEngine.shared
        guard engine.activeDeckId == deck.id, engine.isActive else { dismiss(); return }
        saving = true
        Task { @MainActor in
            defer { saving = false }
            do {
                let section = engine.activeSectionId.flatMap { id in deck.sections.first { $0.id == id } }
                try await engine.startAlerts(for: deck, section: section)
                dismiss()
            } catch { engine.stopAlerts(); errorMessage = error.localizedDescription }
        }
    }
}

struct DeckScheduleTimingFields: View {
    @Binding var settings: DeckAlertSettings

    private func time(hour: WritableKeyPath<DeckAlertSettings, Int>, minute: WritableKeyPath<DeckAlertSettings, Int>) -> Binding<Date> {
        Binding(get: {
            Calendar.current.date(bySettingHour: settings[keyPath: hour], minute: settings[keyPath: minute], second: 0, of: Date()) ?? Date()
        }, set: { date in
            settings[keyPath: hour] = Calendar.current.component(.hour, from: date)
            settings[keyPath: minute] = Calendar.current.component(.minute, from: date)
        })
    }

    var body: some View {
        VStack(spacing: 16) {
            if settings.isCustomDaily {
                Toggle("Set a specific time (optional)", isOn: $settings.useSpecificTime)
                    .font(.subheadline)
                if settings.useSpecificTime {
                    DatePicker("Daily at", selection: time(hour: \.specificHour, minute: \.specificMinute), displayedComponents: .hourAndMinute)
                }
            }
            if !settings.isCustomDaily || !settings.useSpecificTime {
                DatePicker("Starts daily", selection: time(hour: \.startHour, minute: \.startMinute), displayedComponents: .hourAndMinute)
                if !settings.isCustomDaily {
                    DatePicker("Finishes daily", selection: time(hour: \.endHour, minute: \.endMinute), displayedComponents: .hourAndMinute)
                }
            }
        }
        .font(.subheadline)
        .foregroundStyle(LearnAlertStyle.textPrimary)
        .tint(LearnAlertStyle.appAccentForeground)
        .animation(.snappy, value: settings.isCustomDaily)
        .animation(.snappy, value: settings.useSpecificTime)
    }
}
