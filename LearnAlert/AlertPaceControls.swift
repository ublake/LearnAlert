import SwiftUI

/// A mode is an explicit choice, independent of whether its count matches a preset.
struct AlertPaceControls: View {
    @Binding var settings: DeckAlertSettings
    var automaticCount = 10
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var editingCount: Bool
    @State private var countText = ""
    private let presets = [1, 3, 5, 7, 10, 15]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Alert pace").font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(settings.resolvedDailyCount(automaticCount: automaticCount))/day")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(LearnAlertStyle.textSecondary)
            }
            HStack(spacing: 4) {
                ForEach(AlertPaceMode.allCases) { mode in
                    Button {
                        editingCount = false
                        settings.paceMode = mode
                        HapticFeedback.selection()
                    } label: {
                        Text(mode.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(settings.paceMode == mode ? LearnAlertStyle.appAccentInk : LearnAlertStyle.textSecondary)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(settings.paceMode == mode ? LearnAlertStyle.appAccent : .clear,
                                in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(mode.title) alert pace")
                    .accessibilityAddTraits(settings.paceMode == mode ? .isSelected : [])
                }
            }
            .padding(4)
            .background(LearnAlertStyle.insetSurface, in: RoundedRectangle(cornerRadius: 16))

            if settings.paceMode == .custom {
                VStack(spacing: 12) {
                    HStack(spacing: 4) {
                        ForEach(presets, id: \.self) { count in
                            Button {
                                editingCount = false
                                settings.dailyCount = count
                                countText = String(count)
                                HapticFeedback.selection()
                            } label: {
                                Text("\(count)")
                                    .font(.subheadline.weight(.semibold).monospacedDigit())
                                    .foregroundStyle(settings.dailyCount == count ? LearnAlertStyle.appAccentInk : LearnAlertStyle.textPrimary)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .background(settings.dailyCount == count ? LearnAlertStyle.appAccent : LearnAlertStyle.insetSurface,
                                        in: RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(count == 1 ? "1 alert per day" : "\(count) alerts per day")
                            .accessibilityAddTraits(settings.dailyCount == count ? .isSelected : [])
                        }
                    }
                    HStack {
                        Text("Alerts per day").font(.subheadline)
                        Spacer()
                        TextField("10", text: $countText)
                            .font(.headline.monospacedDigit())
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .focused($editingCount)
                            .frame(width: 72, height: 44)
                            .background(LearnAlertStyle.insetSurface, in: RoundedRectangle(cornerRadius: 12))
                            .accessibilityLabel("Custom alerts per day")
                            .onChange(of: countText) { _, text in
                                guard let count = Int(text), count > 0 else { return }
                                settings.dailyCount = min(50, count)
                                if count > 50 { countText = "50" }
                            }
                            .onChange(of: editingCount) { _, editing in
                                if !editing { countText = String(settings.dailyCount) }
                            }
                    }
                }
                .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            }
        }
        .foregroundStyle(LearnAlertStyle.textPrimary)
        .animation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.38, dampingFraction: 0.85), value: settings.paceMode)
        .onAppear { countText = String(settings.dailyCount) }
        .onChange(of: settings.dailyCount) { _, count in
            if !editingCount { countText = String(count) }
        }
        .toolbar {
            if editingCount {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { editingCount = false }
                }
            }
        }
    }
}
