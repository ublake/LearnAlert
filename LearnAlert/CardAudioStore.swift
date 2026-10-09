import Foundation
import AVFoundation
import SwiftUI
import Combine

enum CardAudioStore {
    static let maximumBytes = 20 * 1024 * 1024
    static var directory: URL {
        let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: CardImageStore.appGroupIdentifier)
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent("CardAudio", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func url(named name: String) -> URL { directory.appendingPathComponent(URL(fileURLWithPath: name).lastPathComponent) }

    static func contentType(for name: String) throws -> String {
        switch URL(fileURLWithPath: name).pathExtension.lowercased() {
        case "mp3": return "audio/mpeg"
        case "m4a": return "audio/mp4"
        case "wav": return "audio/wav"
        default: throw CommunityAPIError(status: 415, message: "Choose an MP3, M4A, or WAV audio file.")
        }
    }

    static func importFile(_ source: URL) throws -> String {
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
        _ = try contentType(for: source.lastPathComponent)
        let size = try source.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size > 0, size <= maximumBytes else { throw CommunityAPIError(status: 413, message: "Choose an audio clip under 20 MB.") }
        let data = try Data(contentsOf: source)
        return try save(data, extension: source.pathExtension.lowercased())
    }

    static func saveDownloaded(_ data: Data) throws -> String {
        let bytes = [UInt8](data.prefix(12))
        let ext: String
        if bytes.count >= 12, String(bytes: bytes[4..<8], encoding: .ascii) == "ftyp" { ext = "m4a" }
        else if bytes.count >= 12, String(bytes: bytes[0..<4], encoding: .ascii) == "RIFF" { ext = "wav" }
        else { ext = "mp3" }
        return try save(data, extension: ext)
    }

    private static func save(_ data: Data, extension ext: String) throws -> String {
        guard !data.isEmpty, data.count <= maximumBytes else { throw CommunityAPIError(status: 413, message: "Choose an audio clip under 20 MB.") }
        // Reject corrupt files before attaching them to a card.
        let player = try AVAudioPlayer(data: data)
        guard player.duration > 0 else { throw CommunityAPIError(status: 400, message: "This audio file could not be played.") }
        let name = "\(UUID().uuidString).\(ext)"
        try data.write(to: url(named: name), options: .atomic)
        return name
    }

    static func delete(named name: String) { try? FileManager.default.removeItem(at: url(named: name)) }
}

@MainActor
final class CardAudioPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var isPlaying = false
    @Published var errorMessage: String?
    private var player: AVAudioPlayer?

    func toggle(name: String) {
        if isPlaying { stop(); return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            let player = try AVAudioPlayer(contentsOf: CardAudioStore.url(named: name))
            player.delegate = self
            player.prepareToPlay()
            self.player = player
            isPlaying = player.play()
            if !isPlaying { errorMessage = "This audio clip could not be played." }
        } catch { errorMessage = "This audio clip could not be played. Try attaching it again." }
    }

    func stop() { player?.stop(); player = nil; isPlaying = false }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.isPlaying = false }
    }
}

struct CardAudioPlaybackButton: View {
    let name: String
    @StateObject private var player = CardAudioPlayer()

    var body: some View {
        Button { player.toggle(name: name) } label: {
            Label(player.isPlaying ? "Stop audio" : "Play audio", systemImage: player.isPlaying ? "stop.fill" : "play.fill")
                .font(.body.weight(.medium))
                .frame(minHeight: 44)
        }
        .tint(LearnAlertStyle.indigo)
        .onDisappear { player.stop() }
        .onChange(of: name) { _, _ in player.stop() }
        .alert("Audio Unavailable", isPresented: Binding(get: { player.errorMessage != nil }, set: { if !$0 { player.errorMessage = nil } })) {
            Button("OK", role: .cancel) { }
        } message: { Text(player.errorMessage ?? "") }
    }
}
