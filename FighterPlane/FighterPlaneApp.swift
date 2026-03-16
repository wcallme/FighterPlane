import SwiftUI

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return [.landscapeLeft, .landscapeRight]
    }

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Pre-warm audio so it doesn't block the main thread when the menu first loads
        _ = MenuMusicManager.shared
        return true
    }
}

@main
struct FighterPlaneApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .ignoresSafeArea()
                .statusBarHidden()
                .background(Color.black)
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase != .active {
                GunSoundManager.shared.stopFiringImmediate()
            }
        }
    }
}
