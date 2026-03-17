import AVFoundation

/// Manages gatling gun sound with spin-up intro + seamless fire loop.
///
/// Usage:
///   - Call `startFiring()` when the fire button is pressed.
///   - Call `stopFiring()` when the fire button is released.
///   - Call `updateFade(dt:)` every frame from the game loop.
///   - Each press plays the spin-up once, then loops steady fire.
final class GunSoundManager: NSObject, AVAudioPlayerDelegate {

    static let shared = GunSoundManager()

    private var spinUpPlayer: AVAudioPlayer?
    private var loopPlayer: AVAudioPlayer?
    private var isFiringSound = false

    /// Remaining fade-out time; driven by `updateFade(dt:)` from the game loop.
    private var fadeRemaining: TimeInterval = 0
    private let fadeDuration: TimeInterval = 1.0

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
            spinUpPlayer?.volume = 0.35
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

    private let maxVolume: Float = 0.35

    func startFiring() {
        // Cancel any fade-out in progress and restore volume
        fadeRemaining = 0
        loopPlayer?.volume = maxVolume

        guard !isFiringSound else { return }
        isFiringSound = true
        guard !AudioSettings.shared.isMuted else { return }

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

        let wasSpinningUp = spinUpPlayer?.isPlaying ?? false

        // Stop spin-up immediately
        spinUpPlayer?.stop()
        spinUpPlayer?.currentTime = 0
        spinUpPlayer?.prepareToPlay()

        // If still in spin-up phase, loop hasn't started audibly — kill it now
        if wasSpinningUp {
            fadeRemaining = 0
            resetLoop()
            return
        }

        // Fade out the loop over ~1 second, driven by updateFade(dt:)
        guard loopPlayer?.isPlaying == true else {
            resetLoop()
            return
        }
        fadeRemaining = fadeDuration
    }

    /// Drive the fade-out each frame — call from the game loop with the frame delta.
    func updateFade(dt: TimeInterval) {
        guard fadeRemaining > 0, let loop = loopPlayer else { return }
        fadeRemaining -= dt
        if fadeRemaining <= 0 {
            fadeRemaining = 0
            resetLoop()
        } else {
            loop.volume = Float(fadeRemaining / fadeDuration) * maxVolume
        }
    }

    /// Immediately stop and reset — used for game over, pause, backgrounding
    func stopFiringImmediate() {
        fadeRemaining = 0
        isFiringSound = false

        spinUpPlayer?.stop()
        spinUpPlayer?.currentTime = 0
        spinUpPlayer?.prepareToPlay()
        resetLoop()
    }

    private func resetLoop() {
        loopPlayer?.stop()
        loopPlayer?.volume = maxVolume
        loopPlayer?.currentTime = 0
        loopPlayer?.prepareToPlay()
    }

    // MARK: - AVAudioPlayerDelegate

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        // Spin-up finished naturally — loop is already scheduled via play(atTime:)
        // Nothing extra needed here.
    }
}
