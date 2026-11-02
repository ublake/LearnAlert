import SwiftUI

struct SettingsPreviewGroup: View {
    @AppStorage(DiscoverCategoryStyle.storageKey) private var categoryStyleRaw = DiscoverCategoryStyle.none.rawValue
    @State private var showingSounds = false

    private var categoryStyle: DiscoverCategoryStyle { DiscoverCategoryStyle(rawValue: categoryStyleRaw) ?? .none }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Temporary previews")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(LearnAlertStyle.textSecondary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                Menu {
                    Picker("Discover categories", selection: $categoryStyleRaw) {
                        ForEach(DiscoverCategoryStyle.allCases) { style in
                            Text(style.title).tag(style.rawValue)
                        }
                    }
                } label: {
                    previewRow("Discover categories", icon: "rectangle.topthird.inset.filled", value: categoryStyle.title, disclosure: "chevron.up.chevron.down")
                }
                .accessibilityLabel("Discover categories")
                .accessibilityValue(categoryStyle.title)

                Divider().overlay(LearnAlertStyle.cardBorder).padding(.leading, 58)

                Button { showingSounds = true } label: {
                    previewRow("Sound Studio", icon: "waveform", value: "50 sounds", disclosure: "chevron.right")
                }
            }
            .buttonStyle(.plain)
            .settingsGlassSurface(cornerRadius: 20)
        }
        .padding(.horizontal, 20)
        .sheet(isPresented: $showingSounds) { SoundPreviewGallery() }
    }

    private func previewRow(_ title: String, icon: String, value: String, disclosure: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(LearnAlertStyle.appAccentForeground)
                .frame(width: 30, height: 30)
            Text(title).font(.subheadline.weight(.medium)).foregroundStyle(LearnAlertStyle.textPrimary)
            Spacer(minLength: 8)
            Text(value).font(.caption).foregroundStyle(LearnAlertStyle.textSecondary)
            Image(systemName: disclosure).font(.system(size: 10, weight: .semibold)).foregroundStyle(LearnAlertStyle.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .contentShape(Rectangle())
    }
}
