import SwiftUI
import SpriteKit
import SceneKit

struct ContentView: View {
    @ObservedObject private var nav = NavigationManager.shared
    @State private var showSplash = true

    var body: some View {
        ZStack {
            if nav.isInGame {
                Game3DView()
                    .ignoresSafeArea()
            } else {
                MenuSpriteView()
                    .ignoresSafeArea()
            }

            // Splash overlay that seamlessly continues the native launch screen
            // until the menu scene is fully rendered
            if showSplash && !nav.isInGame {
                SplashOverlay()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.5), value: showSplash)
        .onReceive(NotificationCenter.default.publisher(for: .menuSceneReady)) { _ in
            // Give one extra frame for SpriteKit to render before fading out
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                showSplash = false
            }
        }
    }
}

/// Matches the native launch screen (LaunchImage on black) so the transition is seamless.
private struct SplashOverlay: View {
    var body: some View {
        ZStack {
            Color.black
            Image("LaunchImage")
                .resizable()
                .scaledToFill()
        }
        .ignoresSafeArea()
    }
}

/// Hosts the SpriteKit menu scenes (HangarScene, ArmoryScene, etc.)
struct MenuSpriteView: UIViewRepresentable {
    func makeUIView(context: Context) -> MenuSKView {
        return MenuSKView()
    }

    func updateUIView(_ uiView: MenuSKView, context: Context) {}
}

/// Custom SKView that presents the menu scene with .resizeFill so the scene
/// automatically tracks the view's bounds — no cropping, no stale sizes.
class MenuSKView: SKView {
    private var scenePresented = false

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !scenePresented, bounds.size.width > 0, bounds.size.height > 0 else { return }
        scenePresented = true
        let scene = HangarScene(size: bounds.size)
        scene.scaleMode = .resizeFill
        presentScene(scene)
    }
}

extension Notification.Name {
    static let menuSceneReady = Notification.Name("menuSceneReady")
}
