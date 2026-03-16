import AVFoundation

/// Manages looping jet engine sounds for the player and nearby enemy fighters.
/// Player engine plays continuously at a base volume; enemy engine volume
/// scales with the nearest enemy fighter's distance.
final class EngineSoundManager {

    static let shared = EngineSoundManager()

    private var playerEngine: AVAudioPlayer?
    private var enemyEngine: AVAudioPlayer?

    private let playerBaseVolume: Float = 0.06
    private let enemyMaxVolume: Float = 0.05
    private let enemyHearRange: Float = 80  // world units

    private init() {
        if let url = Bundle.main.url(forResource: "jet_engine_player", withExtension: "wav") {
            playerEngine = try? AVAudioPlayer(contentsOf: url)
            playerEngine?.numberOfLoops = -1
            playerEngine?.volume = playerBaseVolume
            playerEngine?.prepareToPlay()
        }
        if let url = Bundle.main.url(forResource: "jet_engine_enemy", withExtension: "wav") {
            enemyEngine = try? AVAudioPlayer(contentsOf: url)
            enemyEngine?.numberOfLoops = -1
            enemyEngine?.volume = 0
            enemyEngine?.prepareToPlay()
        }
    }

    func startEngines() {
        playerEngine?.currentTime = 0
        playerEngine?.volume = playerBaseVolume
        playerEngine?.play()

        enemyEngine?.currentTime = 0
        enemyEngine?.volume = 0
        enemyEngine?.play()
    }

    /// Update enemy engine volume based on closest enemy fighter distance.
    func updateEnemyVolume(closestFighterDist: Float) {
        guard let enemy = enemyEngine else { return }
        if closestFighterDist < enemyHearRange {
            let t = 1.0 - closestFighterDist / enemyHearRange
            enemy.volume = t * enemyMaxVolume
        } else {
            enemy.volume = 0
        }
    }

    func pause() {
        playerEngine?.pause()
        enemyEngine?.pause()
    }

    func resume() {
        playerEngine?.play()
        enemyEngine?.play()
    }

    func stopAll() {
        playerEngine?.stop()
        playerEngine?.currentTime = 0
        playerEngine?.prepareToPlay()
        enemyEngine?.stop()
        enemyEngine?.currentTime = 0
        enemyEngine?.prepareToPlay()
    }
}
