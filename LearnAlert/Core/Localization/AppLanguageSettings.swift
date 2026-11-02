import Combine
import Foundation
import SwiftUI

@MainActor
final class AppLanguageSettings: ObservableObject {
    static let shared = AppLanguageSettings()

    @Published private(set) var language: AppLanguage

    private init() {
        language = AppLocalization.language
    }

    var locale: Locale { language.locale }

    func select(_ language: AppLanguage) {
        guard language != self.language else { return }
        // Persist first, so Foundation labels reevaluated by this publication
        // already see the new language.
        AppLocalization.save(language)
        self.language = language
    }

    func reload() {
        AppLocalization.reload()
        let saved = AppLocalization.language
        if language != saved { language = saved }
    }
}

/// Updates only the environment, preserving navigation, sheets, and practice
/// state. In particular, never attach a language-dependent `.id` to this root.
private struct AppLanguageEnvironment: ViewModifier {
    @ObservedObject private var settings = AppLanguageSettings.shared

    func body(content: Content) -> some View {
        content
            .environment(\.locale, settings.locale)
            .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification).receive(on: DispatchQueue.main)) { _ in
                settings.reload()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSLocale.currentLocaleDidChangeNotification).receive(on: DispatchQueue.main)) { _ in
                if settings.language == .system {
                    AppLocalization.systemLocaleDidChange()
                    settings.objectWillChange.send()
                }
            }
    }
}

extension View {
    func appLanguageEnvironment() -> some View {
        modifier(AppLanguageEnvironment())
    }
}
