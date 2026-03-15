import Foundation

enum GameMode {
    case infiniteBattle
    case mission(MissionData)
}

@MainActor
class NavigationManager: ObservableObject {
    static let shared = NavigationManager()
    @Published var isInGame = false
    var gameMode: GameMode = .infiniteBattle
    private init() {}
}
