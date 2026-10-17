import SwiftUI
import UserNotifications

struct UpcomingAlertsTimeline: View {
    let scheduledDates: [Date]
    let deckID: String?
    @State private var entries: [AlertTimelineEntry] = []
    @State private var showingHistory = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { timeline in
            let rows = combinedEntries(now: timeline.date)
            let next = rows.first { $0.date > timeline.date && $0.status(at: timeline.date) == .upcoming }
            if !rows.isEmpty {
                Button { showingHistory = true } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "bell.badge.fill").font(.caption)
                            .foregroundStyle(LearnAlertStyle.appAccentForeground)
                            .symbolEffect(.pulse, options: .repeating, isActive: next != nil && !reduceMotion)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(next == nil ? "Recent" : "Next").font(.system(size: 9, weight: .medium))
                                .foregroundStyle(LearnAlertStyle.textSecondary)
                            if let next { Text(next.date, format: .dateTime.hour().minute()).font(.caption2.weight(.semibold)).monospacedDigit() }
                            else { Text("Alert trail").font(.caption2.weight(.semibold)) }
                        }.foregroundStyle(LearnAlertStyle.textPrimary).fixedSize()
                        AlertTimelineTrack(entries: AlertTimelineEntry.samples(rows, now: timeline.date), now: timeline.date)
                    }.padding(.horizontal, 10).padding(.vertical, 7)
                        .background(LearnAlertStyle.appAccent.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(LearnAlertStyle.appAccent.opacity(0.20), lineWidth: 0.75))
                }.buttonStyle(.plain)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(next.map { "Next notification at \($0.date.formatted(date: .omitted, time: .shortened)). View alert history" } ?? "View recent alert history")
            }
        }
        .task(id: deckID) {
            while !Task.isCancelled {
                if scenePhase == .active { await refresh() }
                do { try await Task.sleep(for: .seconds(30)) } catch { return }
            }
        }
        .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await refresh() } } }
        .sheet(isPresented: $showingHistory) {
            NavigationStack {
                List {
                    Section {
                        HStack(spacing: 14) {
                            legend(.answered); legend(.unanswered); legend(.upcoming)
                        }
                    }
                    Section {
                        ForEach(combinedEntries(now: .now)) { entry in
                            let status = entry.status(at: .now)
                            HStack(spacing: 12) {
                                Image(systemName: status == .answered ? "checkmark.circle.fill" : status == .unanswered ? "bell.slash.fill" : "circle.fill")
                                    .font(.caption).foregroundStyle(status.color)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(entry.date, format: .dateTime.weekday(.abbreviated).hour().minute()).font(.subheadline.weight(.medium))
                                    Text(status.title).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                            }.padding(.vertical, 2)
                        }
                    } footer: {
                        Text("Gray means the scheduled time passed without delivery confirmation. No answer yet means a delivered alert was dismissed or has waited at least 15 minutes. Opened in app is tracked separately from an answer.")
                    }
                }.navigationTitle("Alert trail").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showingHistory = false } } }
            }.presentationDetents([.medium, .large])
        }
    }
    private func legend(_ status: AlertTimelineStatus) -> some View {
        HStack(spacing: 4) { Circle().fill(status.color).frame(width: 6, height: 6); Text(status.title).font(.system(size: 10)) }
    }
    private func combinedEntries(now: Date) -> [AlertTimelineEntry] {
        var rows = entries
        for date in scheduledDates where date > now && !rows.contains(where: { abs($0.date.timeIntervalSince(date)) < 1 }) {
            rows.append(.init(id: "scheduled-\(date.timeIntervalSince1970)", deckID: deckID ?? "", date: date))
        }
        return rows.sorted { $0.date < $1.date }
    }
    @MainActor private func refresh() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let delivered = await center.deliveredNotifications()
        guard !Task.isCancelled else { return }
        AlertTimelineStore.shared.reconcile(pending: pending)
        for notification in delivered { AlertTimelineStore.shared.delivered(notification) }
        entries = deckID.map { AlertTimelineStore.shared.entries(deckID: $0) } ?? []
    }
}

private struct AlertTimelineTrack: View {
    let entries: [AlertTimelineEntry]
    let now: Date
    var body: some View {
        GeometryReader { geometry in
            let width = max(0, geometry.size.width - 10)
            let nextID = entries.first { $0.date > now && $0.status(at: now) == .upcoming }?.id
            ZStack(alignment: .leading) {
                Capsule().fill(LearnAlertStyle.appAccent.opacity(0.2)).frame(height: 2)
                    .padding(.horizontal, 5)
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    let next = entry.id == nextID
                    let position = entries.count <= 1 ? width / 2 : width * CGFloat(index) / CGFloat(entries.count - 1)
                    Circle().fill(entry.status(at: now).color)
                        .frame(width: next ? 7 : 5, height: next ? 7 : 5)
                        .overlay { if next { Circle().stroke(LearnAlertStyle.appAccent.opacity(0.23), lineWidth: 4) } }
                        .position(x: position + 5, y: geometry.size.height / 2)
                }
            }.frame(maxHeight: .infinity)
        }.frame(height: 18)
    }
}

private extension AlertTimelineStatus {
    var color: Color {
        switch self {
        case .answered: .green
        case .unanswered: .orange
        case .opened: .purple.opacity(0.7)
        case .elapsed: LearnAlertStyle.textSecondary.opacity(0.4)
        case .delivered: Color(red: 0.66, green: 0.65, blue: 0.90)
        case .upcoming: LearnAlertStyle.appAccent
        }
    }
}
