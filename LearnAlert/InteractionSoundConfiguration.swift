import Foundation

struct InteractionSoundCue: Sendable {
    let filename: String
    let volume: Float
    let priority: Int
}

enum InteractionSoundConfiguration {
    static let effectsStorageKey = "interfaceSoundEffectsEnabled"

    static var effectsEnabled: Bool {
        UserDefaults(suiteName: "group.com.learnalert.shared")?.object(forKey: effectsStorageKey) as? Bool ?? true
    }

    static func answer(isCorrect: Bool) -> InteractionSoundCue {
        InteractionSoundCue(filename: isCorrect ? "la_ui_correct_bloom.wav" : "la_ui_incorrect_soft.wav",
                            volume: isCorrect ? 0.68 : 0.60, priority: 1)
    }
}
