import Foundation
import Observation

/// App chrome only. Learning material, card templates, and saved identities are
/// deliberately independent of this preference.
nonisolated enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system
    case english = "en"
    case spanish = "es"
    case brazilianPortuguese = "pt-BR"
    case french = "fr"
    case german = "de"
    case japanese = "ja"
    case korean = "ko"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: AppLocalization.string("System default")
        case .english: "English"
        case .spanish: "Español"
        case .brazilianPortuguese: "Português (Brasil)"
        case .french: "Français"
        case .german: "Deutsch"
        case .japanese: "日本語"
        case .korean: "한국어"
        }
    }

    var locale: Locale {
        self == .system ? .autoupdatingCurrent : Locale(identifier: rawValue)
    }
}

/// Foundation strings need the same explicit locale as SwiftUI's environment.
/// Keep this independent of the main-actor UI store so background imports and
/// the notification extension can also resolve strings using the saved choice.
nonisolated enum AppLocalization {
    static let storageKey = "app_language"
    static let sharedSuiteName = "group.com.learnalert.shared"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: sharedSuiteName) ?? .standard
    }

    static var language: AppLanguage {
        SharedAppLanguage.shared.language
    }

    static var locale: Locale { language.locale }

    static func language(in defaults: UserDefaults) -> AppLanguage {
        AppLanguage(rawValue: defaults.string(forKey: storageKey) ?? "") ?? .system
    }

    static func save(_ language: AppLanguage, in defaults: UserDefaults? = nil) {
        (defaults ?? self.defaults).set(language.rawValue, forKey: storageKey)
        reload()
    }

    static func reload() {
        SharedAppLanguage.shared.reload(from: language(in: defaults))
    }

    static func systemLocaleDidChange() {
        SharedAppLanguage.shared.systemLocaleDidChange()
    }

    /// The typed resource preserves catalog extraction, interpolation, plural
    /// rules, table, and bundle. Its construction-time locale must be replaced
    /// when the person changes language without restarting the app.
    static func string(_ resource: LocalizedStringResource, comment: StaticString? = nil) -> String {
        var localized = resource
        localized.locale = locale
        return String(localized: localized)
    }

    static func date(_ value: Date, date: Date.FormatStyle.DateStyle = .abbreviated,
                     time: Date.FormatStyle.TimeStyle = .shortened) -> String {
        value.formatted(Date.FormatStyle(date: date, time: time, locale: locale))
    }
}

/// SwiftUI tracks registrar reads made by Foundation localization calls inside
/// a view body, even when that view doesn't directly read Environment.locale.
/// Locking protects the snapshot for callers on background import/model actors.
private nonisolated final class SharedAppLanguage: Observable, @unchecked Sendable {
    static let shared = SharedAppLanguage()

    private let registrar = ObservationRegistrar()
    private let lock = NSLock()
    private var saved: AppLanguage

    private init() {
        let defaults = UserDefaults(suiteName: AppLocalization.sharedSuiteName) ?? .standard
        saved = AppLocalization.language(in: defaults)
    }

    var language: AppLanguage {
        registrar.access(self, keyPath: \.language)
        return lock.withLock { saved }
    }

    func reload(from language: AppLanguage) {
        guard lock.withLock({ saved != language }) else { return }
        registrar.withMutation(of: self, keyPath: \.language) {
            lock.withLock { saved = language }
        }
    }

    func systemLocaleDidChange() {
        guard lock.withLock({ saved == .system }) else { return }
        registrar.withMutation(of: self, keyPath: \.language) { }
    }
}
