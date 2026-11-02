import SwiftUI

/// The role comes from the signed-in account; no local switch can grant it.
struct DeveloperSettingsSection: View {
    @ObservedObject private var session = CommunitySession.shared
    @State private var destination: Destination?
    @State private var pendingAnkiValue: Bool?
    @State private var isSaving = false
    @State private var isRefreshing = false
    @State private var message: String?

    private enum Destination: String, Identifiable {
        case systemCheck, soundStudio, diagnostics
        var id: String { rawValue }
    }

    var body: some View {
        if session.isDeveloper {
            VStack(alignment: .leading, spacing: 10) {
                Text("Developer")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(LearnAlertStyle.textSecondary)
                    .padding(.leading, 4)

                VStack(spacing: 0) {
                    Toggle(isOn: Binding(
                        get: { pendingAnkiValue ?? session.canUploadAnki },
                        set: { value in Task { await saveAnkiUploads(value) } }
                    )) {
                        HStack(spacing: 14) {
                            icon("rectangle.stack.badge.plus")
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Anki uploads").font(.body.weight(.medium))
                                Text("Allow imported Anki decks to be shared.")
                                    .font(.caption)
                                    .foregroundStyle(LearnAlertStyle.textSecondary)
                            }
                            if isSaving { ProgressView().controlSize(.small) }
                        }
                    }
                    .tint(LearnAlertStyle.appAccentForeground)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .disabled(isSaving || isRefreshing)

                    divider
                    Button { Task { await refreshAccess() } } label: {
                        row("Refresh access", icon: "arrow.clockwise", busy: isRefreshing)
                    }
                    .disabled(isSaving || isRefreshing)

                    divider
                    Button { destination = .systemCheck } label: {
                        row("System check", icon: "checkmark.shield")
                    }

                    divider
                    Button { destination = .soundStudio } label: {
                        row("Sound Studio", icon: "waveform")
                    }

                    divider
                    Button { destination = .diagnostics } label: {
                        row("Diagnostics", icon: "stethoscope")
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(LearnAlertStyle.textPrimary)
                .settingsGlassSurface(cornerRadius: 20)

                Text("You can also choose a custom creator name when sharing a deck.")
                    .font(.caption)
                    .foregroundStyle(LearnAlertStyle.textSecondary)
                    .padding(.horizontal, 4)

                if let message {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(LearnAlertStyle.textSecondary)
                        .padding(.horizontal, 4)
                        .accessibilityAddTraits(.updatesFrequently)
                }
            }
            .padding(.horizontal, 20)
            .sheet(item: $destination) { destination in
                if session.isDeveloper {
                    switch destination {
                    case .systemCheck: SystemCheckView()
                    case .soundStudio: DeveloperSoundStudioView()
                    case .diagnostics: DeveloperDiagnosticsView()
                    }
                }
            }
            .onChange(of: session.isDeveloper) { _, allowed in
                if !allowed { destination = nil; pendingAnkiValue = nil; message = nil }
            }
        }
    }

    private var divider: some View {
        Divider().overlay(LearnAlertStyle.cardBorder).padding(.leading, 64)
    }

    private func icon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(LearnAlertStyle.appAccentForeground)
            .frame(width: 30, height: 30)
    }

    private func row(_ title: LocalizedStringResource, icon name: String, busy: Bool = false) -> some View {
        HStack(spacing: 14) {
            icon(name)
            Text(AppLocalization.string(title))
                .font(.body.weight(.medium))
                .multilineTextAlignment(.leading)
            Spacer(minLength: 8)
            if busy { ProgressView().controlSize(.small) }
            else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(LearnAlertStyle.textSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .contentShape(Rectangle())
    }

    @MainActor private func saveAnkiUploads(_ value: Bool) async {
        guard session.isDeveloper, !isSaving, !isRefreshing else { return }
        isSaving = true; pendingAnkiValue = value; message = nil
        defer { isSaving = false; pendingAnkiValue = nil }
        do { try await session.saveDeveloperOptions(allowAnkiUploads: value) }
        catch { if session.isDeveloper { message = error.localizedDescription } }
    }

    @MainActor private func refreshAccess() async {
        guard session.isDeveloper, !isSaving, !isRefreshing else { return }
        isRefreshing = true; message = nil
        defer { isRefreshing = false }
        let refreshed = await session.refreshProfile()
        if session.isDeveloper {
            message = refreshed ? AppLocalization.string("Developer access is up to date.")
                : session.errorMessage ?? AppLocalization.string("Couldn’t refresh access. Try again.")
        }
    }
}

private struct DeveloperSoundStudioView: View {
    @ObservedObject private var session = CommunitySession.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if session.isDeveloper { SoundPreviewGallery() }
        }
        .onChange(of: session.isDeveloper) { _, allowed in
            if !allowed {
                InteractionSoundPlayer.shared.stopPreview()
                dismiss()
            }
        }
        .onDisappear { InteractionSoundPlayer.shared.stopPreview() }
    }
}
