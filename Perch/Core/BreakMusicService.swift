import AVFoundation
import Foundation

/// Plays a lofi loop while a break timer runs, a different track every break.
/// Tracks come from a small on-disk pool composed by LofiComposer; each break
/// picks one at random and renders a fresh replacement in the background, so
/// the pool keeps evolving. Bundled "BreakMusic" audio files, when present,
/// take priority over the generated pool.
@MainActor
final class BreakMusicService {

    private let prefs: PreferencesStore
    private var player: AVAudioPlayer?
    private var startTask: Task<Void, Never>?
    private var stopTask: Task<Void, Never>?

    private static let targetVolume: Float = 0.45
    private static let fadeInSeconds: TimeInterval = 2.0
    private static let fadeOutSeconds: TimeInterval = 0.9

    init(prefs: PreferencesStore) {
        self.prefs = prefs
    }

    func start() {
        guard prefs.breakMusicEnabled, !prefs.isQuietHours() else { return }
        stopTask?.cancel()
        startTask?.cancel()
        startTask = Task { [weak self] in
            guard let url = await BreakMusicLibrary.randomTrackURL() else { return }
            guard let self, !Task.isCancelled else { return }
            self.play(url: url)
        }
    }

    func stop() {
        startTask?.cancel()
        guard let player, player.isPlaying else { return }
        player.setVolume(0, fadeDuration: Self.fadeOutSeconds)
        stopTask?.cancel()
        stopTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64((Self.fadeOutSeconds + 0.1) * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.player?.stop()
            self?.player = nil
        }
    }

    private func play(url: URL) {
        guard let fresh = try? AVAudioPlayer(contentsOf: url) else { return }
        player?.stop()
        fresh.numberOfLoops = -1
        fresh.volume = 0
        fresh.play()
        fresh.setVolume(Self.targetVolume, fadeDuration: Self.fadeInSeconds)
        player = fresh
    }
}

// MARK: - Track pool

/// Keeps a rotating pool of generated lofi tracks on disk.
enum BreakMusicLibrary {

    private static let poolSize = 6

    /// A random track: bundled files win, otherwise the generated pool.
    /// Picking a track also queues a fresh composition and prunes the oldest
    /// ones, so every break draws from an ever-changing set.
    static func randomTrackURL() async -> URL? {
        if let bundled = bundledTracks().randomElement() {
            return bundled
        }
        let directory = poolDirectory()
        let existing = trackURLs(in: directory)
        if let pick = existing.randomElement() {
            renderReplacement(in: directory)
            return pick
        }
        let first = directory.appendingPathComponent(newTrackName())
        let rendered = await Task.detached(priority: .userInitiated) {
            LofiComposer.render(to: first)
        }.value
        if rendered {
            renderReplacement(in: directory)
        }
        return rendered ? first : nil
    }

    private static func bundledTracks() -> [URL] {
        var found: [URL] = []
        for suffix in [""] + (1...9).map(String.init) {
            for ext in ["m4a", "mp3", "wav", "caf", "aiff"] {
                if let url = Bundle.main.url(forResource: "BreakMusic\(suffix)", withExtension: ext) {
                    found.append(url)
                }
            }
        }
        return found
    }

    private static func poolDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let perchDir = base.appendingPathComponent("Perch", isDirectory: true)
        
        try? FileManager.default.removeItem(at: perchDir.appendingPathComponent("break_music.caf"))
        let dir = perchDir.appendingPathComponent("BreakMusic", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func trackURLs(in directory: URL) -> [URL] {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.creationDateKey]
        )) ?? []
        return contents.filter { $0.pathExtension == "caf" }
    }

    private static func newTrackName() -> String {
        "lofi_\(UUID().uuidString.prefix(8)).caf"
    }

    private static func renderReplacement(in directory: URL) {
        Task.detached(priority: .utility) {
            let url = directory.appendingPathComponent(newTrackName())
            guard LofiComposer.render(to: url) else { return }
            pruneOldest(in: directory)
        }
    }

    private static func pruneOldest(in directory: URL) {
        let tracks = trackURLs(in: directory)
        guard tracks.count > poolSize else { return }
        let dated = tracks.map { url -> (URL, Date) in
            let date = (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
            return (url, date)
        }
        let excess = dated.sorted { $0.1 < $1.1 }.prefix(tracks.count - poolSize)
        for (url, _) in excess {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
