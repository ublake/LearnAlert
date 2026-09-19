import AVFoundation

final class InteractionSoundPlayer: @unchecked Sendable {
    static let shared = InteractionSoundPlayer()

    enum Sound: String, Sendable {
        case click
        case selection
        case scheduledAlerts = "scheduledalerts"
        case addDeck = "addadeck"
        case deleteDeck = "downbuild"
        case correct
        case incorrect
        case skip
        case sentTo = "sentto"
        case receiveFrom = "receivefrom"
    }

    private let audioQueue = DispatchQueue(label: "com.learnalert.audio", qos: .userInteractive)
    private var players: [Sound: AVAudioPlayer] = [:]
    private var previewPlayer: AVAudioPlayer?
    private var isSessionConfigured = false

    private init() {
        audioQueue.async { [weak self] in
            self?.configureAudioSession()
        }
    }

    private func configureAudioSession() {
        guard !isSessionConfigured else { return }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            isSessionConfigured = true
        } catch {
            // Audio session failed to activate
        }
    }

    func play(_ sound: Sound) {
        audioQueue.async { [weak self] in
            guard let self else { return }
            self.configureAudioSession()

            let player: AVAudioPlayer
            if let cachedPlayer = self.players[sound] {
                player = cachedPlayer
            } else {
                guard let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "mp3"),
                      let newPlayer = try? AVAudioPlayer(contentsOf: url) else { return }
                newPlayer.prepareToPlay()
                self.players[sound] = newPlayer
                player = newPlayer
            }
            player.currentTime = 0
            player.play()
        }
    }

    func previewSound(named soundName: String) {
        audioQueue.async { [weak self] in
            guard let self else { return }
            self.configureAudioSession()

            self.previewPlayer?.stop()
            guard let soundURL = Bundle.main.url(forResource: soundName, withExtension: nil),
                  let player = try? AVAudioPlayer(contentsOf: soundURL) else { return }
            player.prepareToPlay()
            self.previewPlayer = player
            player.play()
        }
    }

    func stopPreview() {
        audioQueue.async { [weak self] in
            self?.previewPlayer?.stop()
            self?.previewPlayer = nil
        }
    }
}
