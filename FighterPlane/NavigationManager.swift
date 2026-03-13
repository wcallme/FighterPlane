import Foundation

class NavigationManager: ObservableObject {
    static let shared = NavigationManager()
    @Published var isInGame = false
    private init() {}
}
