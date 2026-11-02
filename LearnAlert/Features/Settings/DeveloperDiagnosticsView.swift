import SwiftData
import SwiftUI
import UIKit
import UserNotifications

/// A snapshot of aggregate diagnostics. No account identifiers or study content
/// are collected, and opening this sheet does not refresh the catalog or API.
struct DeveloperDiagnosticsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var communitySession = CommunitySession.shared
    @State private var sections: [DeveloperDiagnosticSection] = []
    @State private var isLoading = true
    @State private var hasCopied = false

    var body: some View {
        Group {
            if communitySession.isDeveloper {
                NavigationStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            if isLoading {
                                ProgressView("Loading diagnostics…")
                                    .frame(maxWidth: .infinity, minHeight: 80)
                            }
                            ForEach(sections) { section in
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(verbatim: section.title)
                                        .font(.headline)
                                    ForEach(section.rows) { row in
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(verbatim: row.title)
                                                .font(.subheadline.weight(.medium))
                                            Text(verbatim: row.value)
                                                .font(.footnote)
                                                .foregroundStyle(LearnAlertStyle.textSecondary)
                                                .textSelection(.enabled)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                                .padding(16)
                                .settingsGlassSurface(cornerRadius: 18)
                            }
                            Button(action: copyReport) {
                                Label(hasCopied ? "Report copied" : "Copy report",
                                    systemImage: hasCopied ? "checkmark" : "doc.on.doc")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(LearnAlertButtonStyle(kind: .outline, size: .medium,
                                color: LearnAlertStyle.indigo, expands: true))
                            .disabled(isLoading || sections.isEmpty)
                        }
                        .padding(20)
                    }
                    .background(LearnAlertStyle.courseCanvas)
                    .navigationTitle("Developer diagnostics")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { dismiss() }
                        }
                    }
                }
            } else {
                Color.clear
            }
        }
        .task(id: communitySession.isDeveloper) {
            guard communitySession.isDeveloper else { revokeAccess(); return }
            await loadSnapshot()
        }
        .onChange(of: communitySession.isDeveloper) { _, isDeveloper in
            if !isDeveloper { revokeAccess() }
        }
    }

    @MainActor
    private func loadSnapshot() async {
        guard communitySession.isDeveloper else { revokeAccess(); return }
        isLoading = true
        defer { isLoading = false }

        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard communitySession.isDeveloper, !Task.isCancelled else { return }
        let pending = await center.pendingNotificationRequests()
        guard communitySession.isDeveloper, !Task.isCancelled else { return }
        let delivered = await center.deliveredNotifications()
        guard communitySession.isDeveloper, !Task.isCancelled else { return }

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
        let language = AppLanguageSettings.shared.language
        let backendURL = CommunityAPI().baseURL
        let backendHost = backendURL.host ?? "Unavailable"
        let backendOrigin = "\(backendURL.scheme ?? "https")://\(backendHost)"
        let appGroupAvailable = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: SharedDatabase.appGroupIdentifier) != nil
        let storage = SharedDatabase.shared
        let catalog = ManagedCatalogStore.shared
        let courseCount = catalog.courses.count
        let examDeckCount = catalog.examDecks.count

        sections = [
            .init(title: "App environment", rows: [
                .init(title: "Version", value: "\(version) (\(build))"),
                .init(title: "Operating system", value: "iOS \(UIDevice.current.systemVersion)"),
                .init(title: "Language", value: "\(language.displayName) · \(AppLocalization.locale.identifier)"),
                .init(title: "Backend", value: backendOrigin)
            ]),
            .init(title: "Local storage", rows: [
                .init(title: "Library", value: librarySummary()),
                .init(title: "Persistence", value: storage.isUsingTemporaryStorage
                    ? "Temporary memory storage; changes may not survive closing the app."
                    : "Persistent local storage is available. iCloud sync completion is not verified here."),
                .init(title: "Storage warning", value: storage.storageErrorMessage == nil
                    ? "No storage warning reported" : "A storage warning was reported"),
                .init(title: "App Group", value: appGroupAvailable ? "Shared container available" : "Shared container unavailable")
            ]),
            .init(title: "Notifications", rows: [
                .init(title: "Authorization", value: authorizationSummary(settings.authorizationStatus)),
                .init(title: "Pending", value: "\(pending.count)"),
                .init(title: "Delivered", value: "\(delivered.count)"),
                .init(title: "Pending categories", value: categorySummary(pending.map { $0.content.categoryIdentifier })),
                .init(title: "Delivered categories", value: categorySummary(delivered.map { $0.request.content.categoryIdentifier })),
                .init(title: "Pending triggers", value: triggerSummary(pending))
            ]),
            .init(title: "Catalog", rows: [
                .init(title: "Revision", value: safeCatalogRevision(catalog.revision)),
                .init(title: "Available content", value: "\(courseCount) courses · \(examDeckCount) exam decks"),
                .init(title: "Refresh status", value: catalog.lastError == nil
                    ? "No catalog refresh error reported" : "A catalog refresh error was reported")
            ])
        ]
    }

    @MainActor
    private func librarySummary() -> String {
        do {
            let deckCount = try modelContext.fetchCount(FetchDescriptor<Deck>())
            let cardCount = try modelContext.fetchCount(FetchDescriptor<Flashcard>())
            return "\(deckCount) decks · \(cardCount) cards"
        } catch {
            return "Library counts unavailable"
        }
    }

    private func authorizationSummary(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .authorized: "Allowed"
        case .provisional: "Provisional"
        case .ephemeral: "Ephemeral"
        case .denied: "Denied"
        case .notDetermined: "Not requested"
        @unknown default: "Unknown"
        }
    }

    private func categorySummary(_ categories: [String]) -> String {
        guard !categories.isEmpty else { return "None" }
        let labels = categories.map { category in
            switch category {
            case "FLASHCARD_REVEAL": "Study"
            case "FLASHCARD_TEST": "Preview/test"
            case "": "No category"
            default: "Other"
            }
        }
        let counts = Dictionary(grouping: labels, by: { $0 }).mapValues(\.count)
        return counts.keys.sorted().map { "\($0): \(counts[$0] ?? 0)" }.joined(separator: " · ")
    }

    private func triggerSummary(_ requests: [UNNotificationRequest]) -> String {
        guard !requests.isEmpty else { return "None" }
        var calendarCount = 0
        var intervalCount = 0
        var otherCount = 0
        for request in requests {
            switch request.trigger {
            case is UNCalendarNotificationTrigger: calendarCount += 1
            case is UNTimeIntervalNotificationTrigger: intervalCount += 1
            default: otherCount += 1
            }
        }
        return "Calendar: \(calendarCount) · Interval: \(intervalCount) · Other: \(otherCount)"
    }

    private func safeCatalogRevision(_ revision: String?) -> String {
        guard let revision, !revision.isEmpty else { return "Bundled / no saved revision" }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        guard revision.count <= 100, revision.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            return "Saved revision available"
        }
        return revision
    }

    @MainActor
    private func copyReport() {
        guard communitySession.isDeveloper, !isLoading, !sections.isEmpty else { return }
        UIPasteboard.general.string = (["LearnAlert developer diagnostics"] + sections.flatMap { section in
            ["", section.title] + section.rows.map { "\($0.title): \($0.value)" }
        }).joined(separator: "\n")
        hasCopied = true
    }

    @MainActor
    private func revokeAccess() {
        sections = []
        hasCopied = false
        isLoading = false
        dismiss()
    }
}

private struct DeveloperDiagnosticSection: Identifiable {
    let title: String
    let rows: [DeveloperDiagnosticRow]
    var id: String { title }
}

private struct DeveloperDiagnosticRow: Identifiable {
    let title: String
    let value: String
    var id: String { title }
}
