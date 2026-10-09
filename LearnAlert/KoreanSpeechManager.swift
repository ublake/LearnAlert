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
    private var activeUtteranceID: ObjectIdentifier?
    private var playbackRequestID: UUID?
    private let audioSessionQueue = DispatchQueue(label: "com.learnalert.korean-audio-session", qos: .default)
    private var koreanVoice: AVSpeechSynthesisVoice?
    var hasVoice: Bool { koreanVoice != nil }

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
        guard hasVoice, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let needsStop = activeUtteranceID != nil
        activeUtteranceID = nil
        let requestID = UUID()
        playbackRequestID = requestID
        if needsStop { synthesizer.stopSpeaking(at: .immediate) }
        currentSpeakingText = text
        isSpeaking = true
        let rate = Float(speed.rawValue)
        // Session activation is synchronous and can wait on the audio service.
        // Keep it off the main actor, then begin speech only if this request is current.
        audioSessionQueue.async { [weak self] in
            do {
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(.playback, mode: .spokenAudio, options: [.mixWithOthers, .duckOthers])
                try audioSession.setActive(true)
            } catch { print("Audio session configuration error: \(error)") }
            Task { @MainActor [weak self] in
                guard let self, self.playbackRequestID == requestID else { return }
                let utterance = AVSpeechUtterance(string: text)
                utterance.voice = self.koreanVoice
                utterance.rate = rate
                utterance.pitchMultiplier = 1.0
                utterance.volume = 1.0
                self.activeUtteranceID = ObjectIdentifier(utterance)
                self.synthesizer.speak(utterance)
            }
        }
    }

    func stop() {
        if activeUtteranceID != nil { synthesizer.stopSpeaking(at: .immediate) }
        activeUtteranceID = nil
        playbackRequestID = nil
        isSpeaking = false
        currentSpeakingText = nil
        releaseAudioSession()
    }

    private func releaseAudioSession() {
        audioSessionQueue.async {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    // MARK: - AVSpeechSynthesizerDelegate

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let identifier = ObjectIdentifier(utterance)
        Task { @MainActor in self.finishPlayback(identifier) }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let identifier = ObjectIdentifier(utterance)
        Task { @MainActor in self.finishPlayback(identifier) }
    }

    private func finishPlayback(_ identifier: ObjectIdentifier) {
        // A cancelled normal-speed utterance must not clear the new slow replay.
        guard activeUtteranceID == identifier else { return }
        activeUtteranceID = nil
        playbackRequestID = nil
        isSpeaking = false
        currentSpeakingText = nil
        releaseAudioSession()
    }
}
