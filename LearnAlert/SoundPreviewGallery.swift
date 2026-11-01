import AVFoundation
import Combine
import SwiftUI

struct PreviewSound: Decodable, Identifiable {
    let id: String
    let title: String
    let category: String
    let event: String
    let fileName: String
    let duration: Double
    let description: String
}

enum PreviewSoundCatalog {
    private struct Pack: Decodable { let sounds: [PreviewSound] }

    static let sounds: [PreviewSound] = {
        guard let url = Bundle.main.url(forResource: "learnalert-sound-pack", withExtension: "json")
            ?? Bundle.main.url(forResource: "learnalert-sound-pack", withExtension: "json", subdirectory: "Sounds/PreviewPack"),
              let data = try? Data(contentsOf: url),
              let pack = try? JSONDecoder().decode(Pack.self, from: data) else { return [] }
        return pack.sounds
    }()
}

@MainActor
private final class SoundGalleryPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var playingID: String?
    @Published private(set) var error: String?
    private var player: AVAudioPlayer?

    func toggle(_ sound: PreviewSound) {
        if playingID == sound.id { stop(); return }
        stop()
        error = nil
        guard let url = Bundle.main.url(forResource: sound.fileName, withExtension: nil)
            ?? Bundle.main.url(forResource: sound.fileName, withExtension: nil, subdirectory: "Sounds/PreviewPack") else {
            error = "This sound couldn’t be loaded."
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            let next = try AVAudioPlayer(contentsOf: url)
            next.delegate = self
            next.prepareToPlay()
            guard next.play() else { error = "This sound couldn’t be played."; return }
            player = next
            playingID = sound.id
        } catch {
            self.error = "This sound couldn’t be played. Try again."
        }
    }

    func stop() {
        player?.stop()
        player = nil
        playingID = nil
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let finishedPlayerID = ObjectIdentifier(player)
        Task { @MainActor [weak self] in
            guard let self, let current = self.player, ObjectIdentifier(current) == finishedPlayerID else { return }
            self.stop()
        }
    }
}

struct SoundPreviewGallery: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var player = SoundGalleryPlayer()
    @State private var category = "interface"

    private let categories = [("interface", "App sounds"), ("ringtone", "Ringtones"), ("celebration", "Fireworks")]
    private var sounds: [PreviewSound] { PreviewSoundCatalog.sounds.filter { $0.category == category } }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    Text("A little sound studio")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(LearnAlertStyle.textPrimary)
                    Text("30 app sounds · 10 ringtones · 10 schedule celebrations")
                        .font(.footnote)
                        .foregroundStyle(LearnAlertStyle.textSecondary)

                    Picker("Sound collection", selection: $category) {
                        ForEach(categories, id: \.0) { value, title in Text(title).tag(value) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 4)

                    if let error = player.error {
                        Text(error).font(.footnote).foregroundStyle(.red).accessibilityAddTraits(.updatesFrequently)
                    }
                    if PreviewSoundCatalog.sounds.isEmpty {
                        ContentUnavailableView("Sounds unavailable", systemImage: "speaker.slash", description: Text("Reopen this view after installing the latest build."))
                    }
                    ForEach(sounds) { sound in
                        Button { player.toggle(sound) } label: {
                            HStack(spacing: 12) {
                                Image(systemName: player.playingID == sound.id ? "stop.fill" : "play.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(LearnAlertStyle.appAccentForeground)
                                    .frame(width: 36, height: 36)
                                    .background(LearnAlertStyle.appAccentForeground.opacity(0.10), in: Circle())
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(sound.title).font(.subheadline.weight(.semibold)).foregroundStyle(LearnAlertStyle.textPrimary)
                                    Text(sound.description).font(.caption).foregroundStyle(LearnAlertStyle.textSecondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                Text(sound.duration.formatted(.number.precision(.fractionLength(1))) + "s")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(LearnAlertStyle.textSecondary)
                            }
                            .padding(12)
                            .settingsGlassSurface(cornerRadius: 14)
                            .contentShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(player.playingID == sound.id ? "Stop" : "Play") \(sound.title), \(sound.duration.formatted(.number.precision(.fractionLength(1)))) seconds")
                    }
                    Text("Tap to listen. These previews don’t change your current sounds. Silent mode and volume apply.")
                        .font(.footnote)
                        .foregroundStyle(LearnAlertStyle.textSecondary)
                        .padding(.top, 4)
                }
                .padding(20)
                .frame(maxWidth: 650)
                .frame(maxWidth: .infinity)
            }
            .background(LearnAlertStyle.courseCanvas.ignoresSafeArea())
            .navigationTitle("Sound Studio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .tint(LearnAlertStyle.appAccentForeground)
        .onChange(of: category) { _, _ in player.stop() }
        .onChange(of: scenePhase) { _, phase in if phase != .active { player.stop() } }
        .onDisappear { player.stop() }
    }
}
