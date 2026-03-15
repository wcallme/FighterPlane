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
    func makeUIView(context: Context) -> SKView {
        let view = SKView()
        view.presentScene(nil) // scene set in updateUIView once layout is known
        return view
    }

    func updateUIView(_ uiView: SKView, context: Context) {
        if uiView.scene == nil {
            let size = uiView.bounds.size.width > 0 ? uiView.bounds.size : UIScreen.main.bounds.size
            let scene = HangarScene(size: size)
            scene.scaleMode = .aspectFill
            uiView.presentScene(scene)
        }
    }
}

