import Foundation

/// Global audio settings persisted via UserDefaults.
final class AudioSettings {

    static let shared = AudioSettings()

    private let muteKey = "audioMuted"

    var isMuted: Bool {
        get { UserDefaults.standard.bool(forKey: muteKey) }
        set { UserDefaults.standard.set(newValue, forKey: muteKey) }
    }

    private init() {}
}
