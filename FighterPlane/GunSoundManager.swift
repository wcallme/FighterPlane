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
    private var fadeOutTimer: Timer?

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
        // Cancel any fade-out in progress and restore volume
        fadeOutTimer?.invalidate()
        fadeOutTimer = nil
        loopPlayer?.volume = 1.0

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

        // Stop spin-up immediately
        spinUpPlayer?.stop()
        spinUpPlayer?.currentTime = 0
        spinUpPlayer?.prepareToPlay()

        // Fade out the loop over 1 second
        guard let loop = loopPlayer, loop.isPlaying else {
            resetLoop()
            return
        }

        let fadeSteps = 20
        let fadeInterval = 1.0 / Double(fadeSteps)
        let volumeStep = loop.volume / Float(fadeSteps)
        var remaining = fadeSteps

        fadeOutTimer?.invalidate()
        fadeOutTimer = Timer.scheduledTimer(withTimeInterval: fadeInterval, repeats: true) { [weak self] timer in
            remaining -= 1
            loop.volume -= volumeStep
            if remaining <= 0 {
                timer.invalidate()
                self?.fadeOutTimer = nil
                self?.resetLoop()
            }
        }
    }

    /// Immediately stop and reset — used for game over, pause, backgrounding
    func stopFiringImmediate() {
        fadeOutTimer?.invalidate()
        fadeOutTimer = nil
        isFiringSound = false

        spinUpPlayer?.stop()
        spinUpPlayer?.currentTime = 0
        spinUpPlayer?.prepareToPlay()
        resetLoop()
    }

    private func resetLoop() {
        loopPlayer?.stop()
        loopPlayer?.volume = 1.0
        loopPlayer?.currentTime = 0
        loopPlayer?.prepareToPlay()
    }

    // MARK: - AVAudioPlayerDelegate

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        // Spin-up finished naturally — loop is already scheduled via play(atTime:)
        // Nothing extra needed here.
    }
}
