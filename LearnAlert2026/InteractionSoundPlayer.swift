import AVFoundation

@MainActor
final class InteractionSoundPlayer {
    static let shared = InteractionSoundPlayer()

    enum Sound: String {
        case click
        case selection
        case schedule
        case deleteDeck = "downbuild"
    }

    private var players: [Sound: AVAudioPlayer] = [:]

    private init() {}

    func play(_ sound: Sound) {
        let player: AVAudioPlayer
        if let cachedPlayer = players[sound] {
            player = cachedPlayer
        } else {
            guard let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "mp3"),
                  let newPlayer = try? AVAudioPlayer(contentsOf: url) else { return }
            newPlayer.prepareToPlay()
            players[sound] = newPlayer
            player = newPlayer
        }
        player.currentTime = 0
        player.play()
    }
}
