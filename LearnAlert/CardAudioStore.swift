import Foundation
import AVFoundation
import SwiftUI
import Combine

struct CardAudioError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

enum CardAudioStore {
    static let maximumBytes = 20 * 1024 * 1024
    static var directory: URL {
        let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: CardImageStore.appGroupIdentifier)
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent("CardAudio", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func url(named name: String) -> URL {
        ManagedCatalogMedia.url(reference: name) ?? directory.appendingPathComponent(URL(fileURLWithPath: name).lastPathComponent)
    }

    /// Availability is local-only; checking a course card never downloads or
    /// opens an audio player just to decide whether to show its play control.
    static func isAvailable(named name: String) -> Bool {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              (try? contentType(for: name)) != nil else { return false }
        let url = url(named: name)
        guard FileManager.default.isReadableFile(atPath: url.path),
              let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
              values.isRegularFile == true, let size = values.fileSize else { return false }
        return size > 0
    }

    static func contentType(for name: String) throws -> String {
        if let type = ManagedCatalogMedia.contentType(reference: name), type.hasPrefix("audio/") { return type }
        switch URL(fileURLWithPath: name).pathExtension.lowercased() {
        case "mp3": return "audio/mpeg"
        case "m4a": return "audio/mp4"
        case "wav": return "audio/wav"
        default: throw CardAudioError(message: "Choose an MP3, M4A, or WAV audio file.")
        }
    }

    static func importFile(_ source: URL) throws -> String {
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
        _ = try contentType(for: source.lastPathComponent)
        let size = try source.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size > 0, size <= maximumBytes else { throw CardAudioError(message: "Choose an audio clip under 20 MB.") }
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
        guard !data.isEmpty, data.count <= maximumBytes else { throw CardAudioError(message: "Choose an audio clip under 20 MB.") }
        // Reject corrupt files before attaching them to a card.
        let player = try AVAudioPlayer(data: data)
        guard player.duration > 0 else { throw CardAudioError(message: "This audio file could not be played.") }
        let name = "\(UUID().uuidString).\(ext)"
        try data.write(to: url(named: name), options: .atomic)
        return name
    }

    static func delete(named name: String) {
        guard !name.hasPrefix("catalog:") else { return }
        try? FileManager.default.removeItem(at: url(named: name))
    }
}

@MainActor
final class CardAudioPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var isPlaying = false
    @Published var errorMessage: String?
    static let playbackChanges = PassthroughSubject<Bool, Never>()
    static var isAnyPlaying: Bool { active?.isPlaying == true }
    private static weak var active: CardAudioPlayer?
    private var player: AVAudioPlayer?

    static func stopActive() { active?.stop() }

    func toggle(name: String, localURL: URL? = nil) {
        if isPlaying { stop(); return }
        Self.active?.stop()
        Self.active = self
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            let source = localURL ?? CardAudioStore.url(named: name)
            guard source.isFileURL else { throw CardAudioError(message: "A stored recording is required.") }
            let player = try AVAudioPlayer(contentsOf: source)
            player.delegate = self
            player.prepareToPlay()
            self.player = player
            isPlaying = player.play()
            if isPlaying {
                Self.playbackChanges.send(true)
            } else {
                stop()
                errorMessage = "This audio clip could not be played."
            }
        } catch {
            stop()
            errorMessage = "This audio clip could not be played. Try attaching it again."
        }
    }

    func stop() {
        let wasActive = Self.active === self
        let wasPlaying = isPlaying
        player?.stop()
        player = nil
        isPlaying = false
        if wasActive { Self.active = nil }
        if wasActive || wasPlaying { Self.playbackChanges.send(Self.isAnyPlaying) }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let finishedPlayerID = ObjectIdentifier(player)
        Task { @MainActor in
            // A queued completion from a previous clip must not stop a newer one.
            guard let current = self.player, ObjectIdentifier(current) == finishedPlayerID else { return }
            self.stop()
        }
    }
}

struct CardAudioPlaybackButton: View {
    let name: String
    var compact = false
    var localURL: URL? = nil
    @StateObject private var player = CardAudioPlayer()

    var body: some View {
        Button { player.toggle(name: name, localURL: localURL) } label: {
            HStack(spacing: 5) {
                Image(systemName: player.isPlaying ? "stop.fill" : "play.fill")
                if !compact { Text(player.isPlaying ? "Stop audio" : "Play audio") }
                else { Image(systemName: "waveform").font(.caption2) }
            }.font(compact ? .caption.weight(.semibold) : .body.weight(.medium))
                .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(player.isPlaying ? "Stop audio" : "Play audio")

        .tint(Color.accentColor)
        .onDisappear { player.stop() }
        .onChange(of: name) { _, _ in player.stop() }
        .onChange(of: localURL) { _, _ in player.stop() }
        .alert("Audio Unavailable", isPresented: Binding(get: { player.errorMessage != nil }, set: { if !$0 { player.errorMessage = nil } })) {
            Button("OK", role: .cancel) { }
        } message: { Text(player.errorMessage ?? "") }
    }
}
