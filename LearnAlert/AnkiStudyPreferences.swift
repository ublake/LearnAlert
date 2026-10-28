import Foundation

/// Shared by in-app study and the expanded notification; existing users keep reveal below.
public nonisolated enum AnkiStudyPresentation: String, CaseIterable, Identifiable, Sendable {
    case revealBelow = "revealBelow"
    case tapToFlip = "tapToFlip"

    public static let storageKey = "ankiStudyPresentation"
    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .revealBelow: "Reveal below"
        case .tapToFlip: "Tap to flip"
        }
    }

    public static func saved(in defaults: UserDefaults? = UserDefaults(suiteName: "group.com.learnalert.shared")) -> Self {
        defaults?.string(forKey: storageKey).flatMap(Self.init(rawValue:)) ?? .revealBelow
    }
}
