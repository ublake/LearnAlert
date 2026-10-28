import SwiftUI

/// The daily count is a ceiling. Availability and spacing determine actual delivery.
struct AlertPaceControls: View {
    @Binding var settings: DeckAlertSettings
    var automaticCount = 20 // Compatibility for existing call sites; never selects a pace.
    @FocusState private var editingCount: Bool
    @State private var countText = ""
    private let presets = [1, 5, 10, 20, 30]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Daily alert limit").font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(settings.resolvedDailyCount(automaticCount: 20))/day")
                    .font(.subheadline.monospacedDigit()).foregroundStyle(LearnAlertStyle.textSecondary)
            }
            HStack(spacing: 5) {
                ForEach(presets, id: \.self) { count in
                    Button {
                        editingCount = false
                        settings.paceMode = .custom
                        settings.dailyCount = count
                        countText = String(count)
                        HapticFeedback.selection()
                    } label: {
                        Text("\(count)").font(.subheadline.weight(.semibold).monospacedDigit())
                            .foregroundStyle(settings.dailyCount == count ? LearnAlertStyle.appAccentInk : LearnAlertStyle.textPrimary)
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(settings.dailyCount == count ? LearnAlertStyle.appAccent : LearnAlertStyle.insetSurface,
                                in: RoundedRectangle(cornerRadius: 11))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Up to \(count) alerts per day")
                    .accessibilityAddTraits(settings.dailyCount == count ? .isSelected : [])
                }
            }
            HStack {
                Text("Alerts per day").font(.subheadline)
                Spacer()
                TextField("20", text: $countText)
                    .font(.headline.monospacedDigit()).keyboardType(.numberPad)
                    .multilineTextAlignment(.center).focused($editingCount)
                    .frame(width: 64, height: 40)
                    .background(LearnAlertStyle.insetSurface, in: RoundedRectangle(cornerRadius: 11))
                    .accessibilityLabel("Daily alert limit, 1 to 30")
                    .onChange(of: countText) { _, text in
                        guard let count = Int(text), count > 0 else { return }
                        settings.paceMode = .custom
                        settings.dailyCount = min(30, count)
                        if count > 30 { countText = "30" }
                    }
                    .onChange(of: editingCount) { _, editing in
                        if !editing { countText = String(settings.resolvedDailyCount(automaticCount: 20)) }
                    }
            }
            Picker("Questions per alert", selection: $settings.questionsPerAlert) {
                ForEach(1...3, id: \.self) { Text("\($0)").tag($0) }
            }
            .font(.subheadline)
            Picker("Minimum gap", selection: $settings.minimumSpacingMinutes) {
                ForEach([60, 90, 120, 180], id: \.self) { minutes in
                    Text(minutes == 60 ? "1 hour" : minutes % 60 == 0 ? "\(minutes / 60) hours" : "\(minutes) minutes").tag(minutes)
                }
            }
            .font(.subheadline)
            Text(settings.scheduleSummary)
                .font(.caption.weight(.medium)).foregroundStyle(LearnAlertStyle.appAccentForeground)
                .fixedSize(horizontal: false, vertical: true)
            Text("One shared goal: 20 answered questions per day. Shorter windows send fewer alerts; the app never squeezes them closer together.")
                .font(.caption).foregroundStyle(LearnAlertStyle.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(LearnAlertStyle.textPrimary)
        .onAppear { countText = String(settings.resolvedDailyCount(automaticCount: 20)) }
        .onChange(of: settings.dailyCount) { _, count in if !editingCount { countText = String(count) } }
        .toolbar {
            if editingCount {
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { editingCount = false } }
            }
        }
    }
}
