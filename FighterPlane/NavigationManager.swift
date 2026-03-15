import Foundation

@MainActor
class NavigationManager: ObservableObject {
    static let shared = NavigationManager()
    @Published var isInGame = false
    // TODO: re-enable when MissionData is ready
    // @Published var activeMission: MissionData?
    private init() {}
}
