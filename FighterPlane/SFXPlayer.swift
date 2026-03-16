import AVFoundation

/// Lightweight one-shot sound-effect player with a small pool
/// so overlapping plays don't cut each other off.
final class SFXPlayer {

    static let shared = SFXPlayer()

    private var pools: [String: [AVAudioPlayer]] = [:]
    private let poolSize = 4  // max simultaneous plays per sound

    /// Throttle: minimum interval between plays of the same sound (prevents audio spam)
    private var lastPlayTime: [String: TimeInterval] = [:]
    private let minPlayInterval: TimeInterval = 0.06  // ~16 plays/sec max per sound

    private init() {}

    /// Pre-load a sound into the pool so first play is instant.
    func preload(_ name: String, ext: String = "wav") {
        guard pools[name] == nil,
              let url = Bundle.main.url(forResource: name, withExtension: ext) else { return }
        var players: [AVAudioPlayer] = []
        for _ in 0..<poolSize {
            if let p = try? AVAudioPlayer(contentsOf: url) {
                p.prepareToPlay()
                players.append(p)
            }
        }
        pools[name] = players
    }

    /// Play a one-shot sound. Auto-preloads on first call if needed.
    /// Automatically throttled so the same sound won't fire more than ~16x/sec.
    func play(_ name: String, ext: String = "wav", volume: Float = 1.0) {
        // Global per-sound throttle to prevent audio system overload
        let now = CACurrentMediaTime()
        if let last = lastPlayTime[name], now - last < minPlayInterval {
            return
        }
        lastPlayTime[name] = now

        if pools[name] == nil { preload(name, ext: ext) }
        guard let pool = pools[name] else { return }

        // Find a player that isn't currently playing
        if let player = pool.first(where: { !$0.isPlaying }) {
            player.volume = volume
            player.currentTime = 0
            player.play()
        }
        // If all players busy, steal the one closest to finishing
        else if let oldest = pool.min(by: { $0.currentTime > $1.currentTime }) {
            oldest.volume = volume
            oldest.currentTime = 0
            oldest.play()
        }
    }
}
