import AVFoundation

/// Plays a random bomb impact sound each time a bomb (or cluster bomblet) hits the ground.
/// Uses pre-loaded player pools on a dedicated audio queue so playback never
/// blocks the main/render thread — even during cluster bomb salvos.
final class BombSoundManager {

    static let shared = BombSoundManager()

    /// Dedicated serial queue for all audio playback — keeps main thread free for rendering
    private let audioQueue = DispatchQueue(label: "com.fighterplane.bombAudio", qos: .userInitiated)

    /// Pre-loaded player pools, one pool per sound variant
    private var playerPools: [[AVAudioPlayer]] = []

    /// Max concurrent bomb sounds
    private let maxConcurrent = 6
    private let poolPerVariant = 2

    /// Throttle: minimum interval between successive plays
    private let minInterval: TimeInterval = 0.03
    private var lastPlayTime: TimeInterval = 0

    private init() {
        for i in 1...3 {
            guard let url = Bundle.main.url(forResource: "bomb_impact\(i)", withExtension: "wav") else { continue }
            var pool: [AVAudioPlayer] = []
            for _ in 0..<poolPerVariant {
                if let p = try? AVAudioPlayer(contentsOf: url) {
                    p.prepareToPlay()
                    pool.append(p)
                }
            }
            playerPools.append(pool)
        }
    }

    /// Play a random bomb impact sound. Dispatched to a background audio queue
    /// so the main/render thread is never blocked by audio hardware calls.
    func playImpact() {
        audioQueue.async { [self] in
            guard !playerPools.isEmpty else { return }

            // Throttle rapid-fire calls (cluster bomblets hitting near-simultaneously)
            let now = CACurrentMediaTime()
            guard now - lastPlayTime >= minInterval else { return }
            lastPlayTime = now

            // Count currently playing sounds across all pools
            let playing = playerPools.flatMap { $0 }.filter { $0.isPlaying }.count
            guard playing < maxConcurrent else { return }

            // Pick a random variant pool
            let pool = playerPools[Int.random(in: 0..<playerPools.count)]

            // Find an idle player in that pool
            if let player = pool.first(where: { !$0.isPlaying }) {
                player.currentTime = 0
                player.play()
            }
            // All busy in chosen variant — try to steal the one closest to finishing
            else if let oldest = pool.min(by: { $0.currentTime > $1.currentTime }) {
                oldest.currentTime = 0
                oldest.play()
            }
        }
    }
}
