import Foundation

/// Hosts may supply an interface language without changing the archive's
/// contents or the process-wide language. Task-local scope keeps simultaneous
/// imports independent and is inherited by structured child tasks.
public enum AnkiLocalization {
    @TaskLocal public static var localeIdentifier: String?

    static func string(_ resource: LocalizedStringResource) -> String {
        var localized = resource
        if let localeIdentifier {
            localized.locale = Locale(identifier: localeIdentifier)
        }
        return String(localized: localized)
    }
}
