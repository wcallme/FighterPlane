import SwiftUI
import SceneKit

struct Game3DView: UIViewRepresentable {

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        let controller = Game3DController()

        scnView.scene = controller.scene
        scnView.delegate = controller
        scnView.overlaySKScene = controller.hud
        scnView.isPlaying = true
        scnView.showsStatistics = false
        scnView.backgroundColor = UIColor(red: 0.55, green: 0.78, blue: 0.95, alpha: 1.0)
        scnView.antialiasingMode = .multisampling2X
        scnView.preferredFramesPerSecond = 60

        // Keep strong reference
        context.coordinator.controller = controller

        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}

    class Coordinator {
        var controller: Game3DController?
    }
}
