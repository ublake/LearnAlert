//
//  KoreanSpeechManager.swift
//  LearnAlert
//
//  Created by Blake Miller on 2/20/26.
//

import Foundation
import AVFoundation
import Combine

@MainActor
final class KoreanSpeechManager: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    static let shared = KoreanSpeechManager()

    public enum PlaybackSpeed: Double {
        case normal = 0.48
        case slow = 0.32
    }

    @Published private(set) var isSpeaking = false
    @Published private(set) var currentSpeakingText: String?

    private let synthesizer = AVSpeechSynthesizer()
    private var koreanVoice: AVSpeechSynthesisVoice?

    private override init() {
        super.init()
        synthesizer.delegate = self
        setupVoice()
    }

    private func setupVoice() {
        // Preferred ko-KR voices
        if let voice = AVSpeechSynthesisVoice(language: "ko-KR") {
            self.koreanVoice = voice
        } else {
            // Fallback to first available Korean voice
            let allKorean = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("ko") }
            self.koreanVoice = allKorean.first
        }
    }

    /// Speaks Korean text with specified rate. Note: Never call automatically from notifications.
    func speak(_ text: String, speed: PlaybackSpeed = .normal) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        // Stop current speech if active
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        // Configure audio session safely
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .spokenAudio, options: [.mixWithOthers, .duckOthers])
            try audioSession.setActive(true)
        } catch {
            print("Audio session configuration error: \(error)")
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = koreanVoice ?? AVSpeechSynthesisVoice(language: "ko-KR")
        utterance.rate = Float(speed.rawValue)
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        currentSpeakingText = text
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
        currentSpeakingText = nil
    }

    // MARK: - AVSpeechSynthesizerDelegate

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            self.currentSpeakingText = nil
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            self.currentSpeakingText = nil
        }
    }
}
