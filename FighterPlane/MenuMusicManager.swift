import AVFoundation

/// Plays background music in menus/hangars. Stops when the player starts a game.
final class MenuMusicManager {

    static let shared = MenuMusicManager()

    private var player: AVAudioPlayer?
    private var isPlaying = false

    private init() {
        if let url = Bundle.main.url(forResource: "menusong", withExtension: "wav") {
            player = try? AVAudioPlayer(contentsOf: url)
            player?.numberOfLoops = -1  // loop forever
            player?.volume = 0.5
            player?.prepareToPlay()
        }
    }

    func play() {
        guard !isPlaying else { return }
        isPlaying = true
        guard !AudioSettings.shared.isMuted else { return }
        player?.currentTime = 0
        player?.play()
    }

    func stop() {
        guard isPlaying else { return }
        isPlaying = false
        player?.stop()
        player?.currentTime = 0
        player?.prepareToPlay()
    }
}
