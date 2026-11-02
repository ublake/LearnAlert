import SwiftUI

/// The daily count is a ceiling. Availability and spacing determine actual delivery.
struct AlertPaceControls: View {
    @Binding var settings: DeckAlertSettings
    var automaticCount = 20 // Compatibility for existing call sites; never selects a pace.
    @FocusState private var editingCount: Bool
    @State private var countText = ""
    private let presets = [1, 5, 10, 20, 30]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text("Daily alert limit").font(.subheadline.weight(.semibold))
                Spacer()
                dailyCountField
            }
            HStack(spacing: 4) {
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
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .background(settings.dailyCount == count ? LearnAlertStyle.appAccent : .clear,
                                in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Up to \(count) alerts per day")
                    .accessibilityAddTraits(settings.dailyCount == count ? .isSelected : [])
                }
            }
            .padding(4)
            .background(LearnAlertStyle.insetSurface, in: RoundedRectangle(cornerRadius: 12))

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Text("Questions per alert").font(.subheadline).accessibilityHidden(true)
                    Spacer(minLength: 8)
                    Picker("Questions per alert", selection: $settings.questionsPerAlert) {
                        ForEach(1...3, id: \.self) { Text("\($0)").tag($0) }
                    }
                    .pickerStyle(.menu).labelsHidden()
                    .font(.subheadline.weight(.medium))
                    .tint(LearnAlertStyle.textPrimary)
                }
                .frame(minHeight: 44)

                Divider().overlay(LearnAlertStyle.hairline.opacity(0.5))

                HStack(spacing: 12) {
                    Text("Minimum gap").font(.subheadline).accessibilityHidden(true)
                    Spacer(minLength: 8)
                    Picker("Minimum gap", selection: $settings.minimumSpacingMinutes) {
                        ForEach([60, 90, 120, 180], id: \.self) { minutes in
                            Text(minutes == 60 ? String(localized: "1 hour") : minutes % 60 == 0 ? String(localized: "\(minutes / 60) hours") : String(localized: "\(minutes) minutes")).tag(minutes)
                        }
                    }
                    .pickerStyle(.menu).labelsHidden()
                    .font(.subheadline.weight(.medium))
                    .tint(LearnAlertStyle.textPrimary)
                }
                .frame(minHeight: 44)
            }
            Text(settings.scheduleSummary)
                .font(.caption.weight(.medium)).foregroundStyle(LearnAlertStyle.textSecondary)
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

    private var dailyCountField: some View {
        HStack(spacing: 3) {
            TextField("20", text: $countText)
                .textFieldStyle(.plain)
                .font(.headline.monospacedDigit()).keyboardType(.numberPad)
                .multilineTextAlignment(.trailing).focused($editingCount)
                .frame(width: 34, height: 36)
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
            Text("/day").font(.caption).foregroundStyle(LearnAlertStyle.textSecondary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 10)
        .background(LearnAlertStyle.insetSurface, in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(editingCount ? LearnAlertStyle.appAccentForeground : LearnAlertStyle.hairline, lineWidth: 1)
        }
    }
}
