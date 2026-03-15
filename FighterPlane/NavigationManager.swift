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

    /// Restart the current mission (tear down and recreate Game3DView)
    func retryMission() {
        // gameMode stays the same
        isInGame = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.isInGame = true
        }
    }

    /// Advance to the next mission and launch it
    func nextMission() {
        let missions = MissionLoader.loadAll()
        if case .mission(let current) = gameMode,
           let idx = missions.firstIndex(where: { $0.name == current.name }),
           idx + 1 < missions.count {
            gameMode = .mission(missions[idx + 1])
        }
        isInGame = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.isInGame = true
        }
    }
}
