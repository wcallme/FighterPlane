import AVFoundation

/// Manages gatling gun sound with spin-up intro + seamless fire loop.
///
/// Usage:
///   - Call `startFiring()` when the fire button is pressed.
///   - Call `stopFiring()` when the fire button is released.
///   - Each press plays the spin-up once, then loops steady fire.
final class GunSoundManager: NSObject, AVAudioPlayerDelegate {

    static let shared = GunSoundManager()

    private var spinUpPlayer: AVAudioPlayer?
    private var loopPlayer: AVAudioPlayer?
    private var isFiringSound = false

    private override init() {
        super.init()
        prepareAudio()
    }

    // MARK: - Setup

    private func prepareAudio() {
        // Configure audio session for game mixing
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, options: .mixWithOthers)
        try? session.setActive(true)

        // Spin-up sound (plays once)
        if let url = Bundle.main.url(forResource: "minigun_spinup", withExtension: "wav") {
            spinUpPlayer = try? AVAudioPlayer(contentsOf: url)
            spinUpPlayer?.numberOfLoops = 0
            spinUpPlayer?.delegate = self
            spinUpPlayer?.prepareToPlay()
        }

        // Loop sound (infinite repeat)
        if let url = Bundle.main.url(forResource: "minigun_loop", withExtension: "wav") {
            loopPlayer = try? AVAudioPlayer(contentsOf: url)
            loopPlayer?.numberOfLoops = -1  // loop forever
            loopPlayer?.prepareToPlay()
        }
    }

    // MARK: - Public API

    func startFiring() {
        guard !isFiringSound else { return }
        isFiringSound = true

        // Stop any previous playback
        loopPlayer?.stop()
        loopPlayer?.currentTime = 0

        // Reset and play spin-up
        spinUpPlayer?.stop()
        spinUpPlayer?.currentTime = 0
        spinUpPlayer?.play()

        // Schedule loop to start exactly when spin-up ends (gapless)
        if let spinUp = spinUpPlayer, let loop = loopPlayer {
            let loopStartTime = spinUp.deviceCurrentTime + spinUp.duration
            loop.currentTime = 0
            loop.play(atTime: loopStartTime)
        }
    }

    func stopFiring() {
        guard isFiringSound else { return }
        isFiringSound = false

        spinUpPlayer?.stop()
        loopPlayer?.stop()

        // Reset positions for next trigger pull
        spinUpPlayer?.currentTime = 0
        loopPlayer?.currentTime = 0

        // Re-prepare for low-latency next play
        spinUpPlayer?.prepareToPlay()
        loopPlayer?.prepareToPlay()
    }

    // MARK: - AVAudioPlayerDelegate

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        // Spin-up finished naturally — loop is already scheduled via play(atTime:)
        // Nothing extra needed here.
    }
}
