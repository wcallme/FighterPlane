import SwiftUI

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return [.landscapeLeft, .landscapeRight]
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
                GunSoundManager.shared.stopFiring()
            }
        }
    }
}
