import SwiftUI
import UIKit

struct AIDiagnosticReport: Codable, Identifiable, Sendable, Equatable {
    var id: UUID = UUID()
    var timestamp: Date = Date()
    var endpoint: String
    var requestMethod: String = "POST"
    var httpStatusCode: Int?
    var httpStatusText: String?
    var errorCode: String?
    var userFriendlySummary: String
    var technicalError: String
    var decodingPath: String?
    var decodingExpectedType: String?
    var rawPayloadSnippet: String?
    var requestPayloadSnippet: String?
    var modelUsed: String = "LearnAlert AI Engine"
    var suggestedFix: String?
    var clientAppVersion: String = "1.0 (2026.1)"
    var deviceOS: String = "iOS"
    var requestId: String?
    var errorDetails: String?

    var isSuccessStatusWithDecodingError: Bool {
        if let code = httpStatusCode, (200...299).contains(code) {
            return true
        }
        return false
    }

    var prettyPrintedPayload: String {
        guard let rawPayloadSnippet, !rawPayloadSnippet.isEmpty else {
            return "(No server response payload captured)"
        }
        guard let data = rawPayloadSnippet.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data),
              let prettyData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
              let prettyStr = String(data: prettyData, encoding: .utf8) else {
            return rawPayloadSnippet
        }
        return prettyStr
    }

    func formattedReport() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss 'UTC'"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        let dateStr = formatter.string(from: timestamp)

        var lines: [String] = []
        lines.append("### 🚨 LearnAlert AI Diagnostic Report")
        lines.append("- **Timestamp**: \(dateStr)")
        lines.append("- **Endpoint**: \(requestMethod) \(endpoint)")
        if let httpStatusCode {
            lines.append("- **HTTP Status**: \(httpStatusCode) \(httpStatusText ?? "")")
        }
        if let errorCode {
            lines.append("- **Error Code**: `\(errorCode)`")
        }
        if let requestId {
            lines.append("- **Request ID**: `\(requestId)`")
        }
        if let errorDetails, !errorDetails.isEmpty {
            lines.append("- **Error Details**: `\(errorDetails)`")
        }
        lines.append("- **AI Model**: \(modelUsed)")
        if let decodingPath {
            lines.append("- **Failed Schema Path**: `\(decodingPath)`")
        }
        if let decodingExpectedType {
            lines.append("- **Expected Type/Key**: `\(decodingExpectedType)`")
        }
        lines.append("- **Client OS**: \(deviceOS)")
        lines.append("- **App Version**: \(clientAppVersion)")
        lines.append("")
        lines.append("#### 📝 Summary")
        lines.append(userFriendlySummary)
        lines.append("")
        lines.append("#### 🔍 Technical Error")
        lines.append("```")
        lines.append(technicalError)
        lines.append("```")
        if let suggestedFix {
            lines.append("")
            lines.append("#### 💡 Suggested Resolution")
            lines.append(suggestedFix)
        }
        if let rawPayloadSnippet, !rawPayloadSnippet.isEmpty {
            lines.append("")
            lines.append("#### 📦 Raw Server Response Payload")
            lines.append("```json")
            lines.append(prettyPrintedPayload)
            lines.append("```")
        }
        return lines.joined(separator: "\n")
    }

    static func fallbackReport(for messageContent: String) -> AIDiagnosticReport {
        let isDecodeIssue = messageContent.localizedCaseInsensitiveContains("couldn’t be read") ||
            messageContent.localizedCaseInsensitiveContains("couldn't be read")
        return AIDiagnosticReport(
            endpoint: "/v1/decks/refine",
            requestMethod: "POST",
            httpStatusCode: isDecodeIssue ? 200 : 500,
            httpStatusText: isDecodeIssue ? "OK (Decoding Failure)" : "Internal Error",
            errorCode: isDecodeIssue ? "SCHEMA_DECODING_FAILURE" : "SERVER_ERROR",
            userFriendlySummary: isDecodeIssue
                ? "The AI server returned a 200 OK response, but the JSON format differed slightly from the expected card structure (e.g. unexpected key type or missing optional field)."
                : "The AI request could not be completed at this time.",
            technicalError: messageContent,
            decodingPath: isDecodeIssue ? "source.mimeType / cards" : nil,
            decodingExpectedType: nil,
            rawPayloadSnippet: nil,
            requestPayloadSnippet: nil,
            modelUsed: "LearnAlert AI Engine",
            suggestedFix: isDecodeIssue
                ? "The app's resilient decoder now auto-adapts to this response. Rephrase your request or tap retry to re-run generation."
                : "Check your internet connection and retry with a more specific instruction."
        )
    }
}

struct AIDiagnosticInspectorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let report: AIDiagnosticReport

    @State private var hasCopied = false
    @State private var showingRawJSON = false
    @State private var selectedTab: DiagnosticTab = .overview

    enum DiagnosticTab: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case technical = "Technical"
        case payload = "Raw JSON"

        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.09, blue: 0.16),
                        Color(red: 0.05, green: 0.06, blue: 0.11)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        statusHeroBanner

                        Picker("Section", selection: $selectedTab) {
                            ForEach(DiagnosticTab.allCases) { tab in
                                Text(tab.rawValue).tag(tab)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 4)

                        switch selectedTab {
                        case .overview:
                            overviewSection
                        case .technical:
                            technicalSection
                        case .payload:
                            payloadSection
                        }

                        actionButtonsSection
                    }
                    .padding(18)
                }
            }
            .navigationTitle("Error Diagnostics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(red: 0.08, green: 0.09, blue: 0.16), for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.custom("Poppins-SemiBold", size: 15))
                    .foregroundStyle(Color.white)
                }
            }
        }
    }

    // MARK: - Hero Banner
    private var statusHeroBanner: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(statusAccentColor.opacity(0.20))
                        .frame(width: 44, height: 44)
                    Image(systemName: report.isSuccessStatusWithDecodingError ? "exclamationmark.triangle.fill" : "bolt.horizontal.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(statusAccentColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(statusTitle)
                            .font(.custom("Poppins-SemiBold", size: 15))
                            .foregroundStyle(Color.white)
                        if let code = report.httpStatusCode {
                            Text("HTTP \(code)")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(statusAccentColor)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(statusAccentColor.opacity(0.18), in: Capsule())
                        }
                    }

                    Text(formattedTimestamp(report.timestamp))
                        .font(.custom("Poppins-Regular", size: 12))
                        .foregroundStyle(Color.white.opacity(0.60))
                }

                Spacer()
            }

            if report.isSuccessStatusWithDecodingError {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(LearnAlertStyle.aqua)
                    Text("Server returned 200 OK • Client decoding mismatch detected")
                        .font(.custom("Poppins-Medium", size: 11))
                        .foregroundStyle(LearnAlertStyle.aqua)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(LearnAlertStyle.aqua.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(statusAccentColor.opacity(0.35), lineWidth: 1)
        )
    }

    private var statusAccentColor: Color {
        if report.isSuccessStatusWithDecodingError {
            return Color.orange
        } else if let code = report.httpStatusCode, code >= 500 {
            return Color.red
        } else {
            return Color.orange
        }
    }

    private var statusTitle: String {
        if report.isSuccessStatusWithDecodingError {
            return "Payload Schema Mismatch"
        } else if let code = report.httpStatusCode {
            return "Server Error (\(code))"
        } else {
            return "Request Diagnostics"
        }
    }

    // MARK: - Overview Section
    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            diagnosticCard(
                title: "What Happened",
                icon: "info.circle.fill",
                accent: LearnAlertStyle.indigo
            ) {
                Text(report.userFriendlySummary)
                    .font(.custom("Poppins-Regular", size: 13))
                    .foregroundStyle(Color.white.opacity(0.90))
                    .lineSpacing(3)
            }

            if let suggestedFix = report.suggestedFix {
                diagnosticCard(
                    title: "Recommended Solution",
                    icon: "lightbulb.fill",
                    accent: LearnAlertStyle.aqua
                ) {
                    Text(suggestedFix)
                        .font(.custom("Poppins-Regular", size: 13))
                        .foregroundStyle(Color.white.opacity(0.90))
                        .lineSpacing(3)
                }
            }

            diagnosticCard(
                title: "Endpoint & AI Model",
                icon: "network",
                accent: LearnAlertStyle.blue
            ) {
                VStack(spacing: 8) {
                    keyValueRow(label: "Endpoint", value: "\(report.requestMethod) \(report.endpoint)")
                    keyValueRow(label: "Model", value: report.modelUsed)
                    if let code = report.httpStatusCode {
                        keyValueRow(label: "Status", value: "\(code) \(report.httpStatusText ?? "")")
                    }
                    if let reqId = report.requestId {
                        keyValueRow(label: "Request ID", value: reqId)
                    }
                }
            }
        }
    }

    // MARK: - Technical Section
    private var technicalSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            diagnosticCard(
                title: "Error Stack & Diagnostics",
                icon: "wrench.and.screwdriver.fill",
                accent: Color.orange
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    if let path = report.decodingPath {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Failed Key / Path:")
                                .font(.custom("Poppins-Medium", size: 11))
                                .foregroundStyle(Color.white.opacity(0.60))
                            Text(path)
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Color.orange)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.14), in: RoundedRectangle(cornerRadius: 6))
                        }
                    }

                    if let details = report.errorDetails, !details.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Server Error Details (error.details):")
                                .font(.custom("Poppins-Medium", size: 11))
                                .foregroundStyle(Color.orange.opacity(0.85))
                            Text(details)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(Color.orange.opacity(0.95))
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.black.opacity(0.40), in: RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.orange.opacity(0.35), lineWidth: 1)
                                )
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Technical Detail:")
                            .font(.custom("Poppins-Medium", size: 11))
                            .foregroundStyle(Color.white.opacity(0.60))
                        Text(report.technicalError)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.92))
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }

            diagnosticCard(
                title: "Environment Metadata",
                icon: "laptopcomputer.and.iphone",
                accent: LearnAlertStyle.periwinkle
            ) {
                VStack(spacing: 8) {
                    keyValueRow(label: "App Version", value: report.clientAppVersion)
                    keyValueRow(label: "Platform", value: report.deviceOS)
                    if let code = report.errorCode {
                        keyValueRow(label: "Internal Code", value: code)
                    }
                }
            }
        }
    }

    // MARK: - Payload Section
    private var payloadSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Response JSON", systemImage: "curlybraces")
                    .font(.custom("Poppins-SemiBold", size: 14))
                    .foregroundStyle(Color.white)
                Spacer()
                Button {
                    UIPasteboard.general.string = report.prettyPrintedPayload
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    withAnimation { hasCopied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        hasCopied = false
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: hasCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 11, weight: .bold))
                        Text(hasCopied ? "Copied" : "Copy JSON")
                            .font(.custom("Poppins-Medium", size: 11))
                    }
                    .foregroundStyle(hasCopied ? LearnAlertStyle.aqua : Color.white.opacity(0.80))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.10), in: Capsule())
                }
            }

            ScrollView(.horizontal, showsIndicators: true) {
                Text(report.prettyPrintedPayload)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.90))
                    .padding(14)
            }
            .frame(maxWidth: .infinity, minHeight: 180, maxHeight: 340, alignment: .topLeading)
            .background(Color(red: 0.04, green: 0.05, blue: 0.09))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
        }
        .padding(16)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Actions Section
    private var actionButtonsSection: some View {
        VStack(spacing: 10) {
            Button {
                UIPasteboard.general.string = report.formattedReport()
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation { hasCopied = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    hasCopied = false
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: hasCopied ? "checkmark.circle.fill" : "doc.on.clipboard")
                        .font(.system(size: 15, weight: .semibold))
                    Text(hasCopied ? "Copied Diagnostic Report!" : "Copy Full Diagnostic Report")
                        .font(.custom("Poppins-SemiBold", size: 14))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(hasCopied ? LearnAlertStyle.aqua : LearnAlertStyle.indigo)
                )
                .shadow(color: LearnAlertStyle.indigo.opacity(0.35), radius: 8, y: 3)
            }
            .buttonStyle(.plain)

            ShareLink(item: report.formattedReport()) {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Share Diagnostic Report")
                        .font(.custom("Poppins-Medium", size: 13))
                }
                .foregroundStyle(Color.white.opacity(0.85))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                )
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Helper Views
    private func diagnosticCard<Content: View>(
        title: String,
        icon: String,
        accent: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(accent)
                Text(title)
                    .font(.custom("Poppins-SemiBold", size: 13))
                    .foregroundStyle(Color.white)
            }

            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private func keyValueRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.custom("Poppins-Regular", size: 12))
                .foregroundStyle(Color.white.opacity(0.60))
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.92))
                .lineLimit(1)
        }
    }

    private func formattedTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}
