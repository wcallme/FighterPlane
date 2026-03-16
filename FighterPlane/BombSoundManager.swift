import AVFoundation

/// Plays a random bomb impact sound each time a bomb (or cluster bomblet) hits the ground.
/// Pre-loads three variations and maintains a pool so overlapping explosions all play.
final class BombSoundManager {

    static let shared = BombSoundManager()

    /// Source URLs for the three bomb impact variants
    private var soundURLs: [URL] = []

    /// Pool of active players that can overlap
    private var activePlayers: [AVAudioPlayer] = []

    private init() {
        for i in 1...3 {
            if let url = Bundle.main.url(forResource: "bomb_impact\(i)", withExtension: "wav") {
                soundURLs.append(url)
            }
        }
    }

    /// Play a random bomb impact sound. Supports overlapping playback for
    /// cluster bomblet salvos hitting in rapid succession.
    func playImpact() {
        guard !soundURLs.isEmpty else { return }
        let url = soundURLs[Int.random(in: 0..<soundURLs.count)]
        guard let player = try? AVAudioPlayer(contentsOf: url) else { return }
        player.play()

        // Track and clean up finished players
        activePlayers.removeAll { !$0.isPlaying }
        activePlayers.append(player)
    }
}
