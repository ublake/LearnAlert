import AVFoundation
import Combine

@MainActor
final class InteractionSoundPlayer {
    static let shared = InteractionSoundPlayer()

    enum Sound {
        case click, selection, scheduledAlerts, addDeck, deleteDeck
        case correct, incorrect, skip, sentTo, receiveFrom, oneHourLater
        case importCompleted

        var cue: InteractionSoundCue? {
            switch self {
            case .scheduledAlerts:
                InteractionSoundCue(filename: "la_schedule_grand_little_finale.wav", volume: 0.85, priority: 3)
            case .addDeck:
                InteractionSoundCue(filename: "la_ui_deck_added.wav", volume: 0.70, priority: 2)
            case .deleteDeck:
                InteractionSoundCue(filename: "la_ui_deck_removed.wav", volume: 0.55, priority: 2)
            case .importCompleted:
                InteractionSoundCue(filename: "la_ui_import_done.wav", volume: 0.70, priority: 2)
            case .correct: InteractionSoundConfiguration.answer(isCorrect: true)
            case .incorrect: InteractionSoundConfiguration.answer(isCorrect: false)
            // These frequent actions already have visual or tactile feedback.
            case .click, .selection, .skip, .sentTo, .receiveFrom, .oneHourLater: nil
            }
        }
    }

    private var players: [String: AVAudioPlayer] = [:]
    private var effectPlayer: AVAudioPlayer?
    private var effectPriority = 0
    private var lastEffectTime: TimeInterval = -.infinity
    private var previewPlayer: AVAudioPlayer?
    private var playbackObservation: AnyCancellable?

    private init() {
        playbackObservation = CardAudioPlayer.playbackChanges.sink { [weak self] playing in
            guard playing else { return }
            Task { @MainActor [weak self] in
                self?.stopEffects()
                self?.stopPreview()
            }
        }
    }

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        // Card recordings can change this shared session to playback. Restore
        // ambient only after that audio finishes, so effects respect Silent mode.
        if session.category != .ambient {
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        }
        try session.setActive(true)
    }

    func play(_ sound: Sound) {
        guard InteractionSoundConfiguration.effectsEnabled, let cue = sound.cue,
              !CardAudioPlayer.isAnyPlaying, previewPlayer?.isPlaying != true else { return }
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastEffectTime >= 0.18 || cue.priority > effectPriority else { return }
        if effectPlayer?.isPlaying == true {
            guard cue.priority > effectPriority else { return }
        }
        do {
            let player: AVAudioPlayer
            if let cached = players[cue.filename] { player = cached }
            else {
                guard let url = soundURL(named: cue.filename) else { return }
                player = try AVAudioPlayer(contentsOf: url)
                player.prepareToPlay()
                players[cue.filename] = player
            }
            try configureAudioSession()
            effectPlayer?.stop()
            player.currentTime = 0
            player.volume = cue.volume
            effectPlayer = player
            effectPriority = cue.priority
            if player.play() { lastEffectTime = now }
        } catch {
            // Sound is optional feedback; keep the successful action intact.
        }
    }

    func stopEffects() {
        effectPlayer?.stop()
        effectPlayer = nil
    }

    func previewSound(named soundName: String) {
        stopPreview()
        guard !CardAudioPlayer.isAnyPlaying, let url = soundURL(named: soundName) else { return }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            try configureAudioSession()
            stopEffects()
            player.prepareToPlay()
            previewPlayer = player
            player.play()
        } catch {}
    }

    func stopPreview() {
        previewPlayer?.stop()
        previewPlayer = nil
    }

    private func soundURL(named filename: String) -> URL? {
        Bundle.main.url(forResource: filename, withExtension: nil)
            ?? Bundle.main.url(forResource: filename, withExtension: nil, subdirectory: "Sounds/PreviewPack")
    }
}
