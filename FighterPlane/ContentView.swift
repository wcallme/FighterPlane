import SwiftUI
import SpriteKit
import SceneKit

struct ContentView: View {
    @ObservedObject private var nav = NavigationManager.shared

    var body: some View {
        ZStack {
            if nav.isInGame {
                Game3DView()
                    .ignoresSafeArea()
            } else {
                MenuSpriteView()
                    .ignoresSafeArea()
            }
        }
    }
}

/// Hosts the SpriteKit menu scenes (HangarScene, ArmoryScene, etc.)
struct MenuSpriteView: UIViewRepresentable {
    func makeUIView(context: Context) -> MenuSKView {
        return MenuSKView()
    }

    func updateUIView(_ uiView: MenuSKView, context: Context) {}
}

/// Custom SKView that presents the scene once layout provides valid bounds.
/// This avoids relying on UIScreen.main.bounds (which can return portrait
/// dimensions on iPad during early startup, causing a blank screen).
class MenuSKView: SKView {
    private var scenePresented = false

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !scenePresented, bounds.size.width > 0, bounds.size.height > 0 else { return }
        scenePresented = true
        let scene = HangarScene(size: bounds.size)
        scene.scaleMode = .aspectFill
        presentScene(scene)
    }
}

