import SwiftUI

struct AnkiStudySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AnkiStudyPresentation.storageKey, store: UserDefaults(suiteName: "group.com.learnalert.shared"))
    private var presentationRaw = AnkiStudyPresentation.revealBelow.rawValue

    private var presentation: AnkiStudyPresentation {
        AnkiStudyPresentation(rawValue: presentationRaw) ?? .revealBelow
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Answer reveal")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(LearnAlertStyle.textSecondary)

                    VStack(spacing: 10) {
                        ForEach(AnkiStudyPresentation.allCases) { option in
                            choice(option)
                        }
                    }

                    Text("Applies in the app and expanded alerts. Audio controls and review ratings work the same.")
                        .font(.footnote)
                        .foregroundStyle(LearnAlertStyle.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
            .background(LearnAlertStyle.courseCanvas.ignoresSafeArea())
            .navigationTitle("Anki Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .tint(LearnAlertStyle.appAccentForeground)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func choice(_ option: AnkiStudyPresentation) -> some View {
        let selected = presentation == option
        return Button {
            presentationRaw = option.rawValue
            HapticFeedback.selection()
        } label: {
            HStack(alignment: .top, spacing: 13) {
                Image(systemName: option == .tapToFlip ? "rectangle.on.rectangle.angled" : "rectangle.expand.vertical")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(LearnAlertStyle.appAccentForeground)
                    .frame(width: 30, height: 30)
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 7) {
                        Text(option.title).font(.body.weight(.semibold))
                        if option == .revealBelow {
                            Text("Default")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(LearnAlertStyle.textSecondary)
                        }
                    }
                    Text(option == .tapToFlip
                        ? "Tap the card to turn it over. Only one side stays visible."
                        : "Use the reveal button to show the answer beneath the front.")
                        .font(.footnote)
                        .foregroundStyle(LearnAlertStyle.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? LearnAlertStyle.appAccentForeground : LearnAlertStyle.textSecondary)
                    .padding(.top, 4)
            }
            .foregroundStyle(LearnAlertStyle.textPrimary)
            .padding(16)
            .settingsGlassSurface(cornerRadius: 16)
            .overlay(RoundedRectangle(cornerRadius: 16)
                .strokeBorder(selected ? LearnAlertStyle.appAccentForeground : .clear, lineWidth: 1.5))
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
