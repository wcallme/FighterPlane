import SwiftUI
import SceneKit

struct Game3DView: View {
    @StateObject private var loader = GameLoader()

    var body: some View {
        ZStack {
            if let controller = loader.controller {
                Game3DSceneView(controller: controller)
                    .ignoresSafeArea()
            }

            // Loading overlay — visible until scene is ready
            if !loader.isReady {
                LoadingView()
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.4), value: loader.isReady)
        .onAppear { loader.load() }
    }
}

// MARK: - Loader

private class GameLoader: ObservableObject {
    @Published var controller: Game3DController?
    @Published var isReady = false

    func load() {
        // Controller must be created on main thread (SceneKit/SpriteKit + UIScreen access)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let ctrl = Game3DController(mode: NavigationManager.shared.gameMode)
            self.controller = ctrl
            // Give SceneKit one frame to render before hiding the loading screen
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                self?.isReady = true
            }
        }
    }
}

// MARK: - SceneKit Host

private struct Game3DSceneView: UIViewRepresentable {
    let controller: Game3DController

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()

        scnView.scene = controller.scene
        scnView.delegate = controller
        scnView.overlaySKScene = controller.hud
        scnView.isPlaying = true
        scnView.showsStatistics = false
        scnView.backgroundColor = UIColor(red: 0.55, green: 0.78, blue: 0.95, alpha: 1.0)
        #if targetEnvironment(simulator)
        scnView.antialiasingMode = .none
        scnView.preferredFramesPerSecond = 30
        #else
        scnView.antialiasingMode = .multisampling2X
        scnView.preferredFramesPerSecond = 60
        #endif

        // Keep strong reference and enable lifecycle observers
        context.coordinator.controller = controller
        context.coordinator.scnView = scnView
        context.coordinator.startObserving()

        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator {
        var controller: Game3DController?
        weak var scnView: SCNView?
        private var resignObserver: NSObjectProtocol?
        private var activeObserver: NSObjectProtocol?

        func startObserving() {
            guard resignObserver == nil else { return }
            resignObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.willResignActiveNotification,
                object: nil, queue: .main
            ) { [weak self] _ in
                self?.pauseRendering()
            }
            activeObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil, queue: .main
            ) { [weak self] _ in
                self?.resumeRendering()
            }
        }

        private func pauseRendering() {
            scnView?.isPlaying = false
            scnView?.scene?.isPaused = true
            GunSoundManager.shared.stopFiringImmediate()
            EngineSoundManager.shared.pause()
        }

        private func resumeRendering() {
            scnView?.scene?.isPaused = false
            scnView?.isPlaying = true
            EngineSoundManager.shared.resume()
        }

        deinit {
            if let obs = resignObserver { NotificationCenter.default.removeObserver(obs) }
            if let obs = activeObserver { NotificationCenter.default.removeObserver(obs) }
        }
    }
}

// MARK: - Loading Screen

private struct LoadingView: View {
    @State private var dotCount = 0
    private let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // Sky gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.35, green: 0.58, blue: 0.80),
                    Color(red: 0.55, green: 0.78, blue: 0.95),
                    Color(red: 0.70, green: 0.88, blue: 0.97)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 24) {
                // Plane silhouette
                Text("✈")
                    .font(.system(size: 64))
                    .rotationEffect(.degrees(-30))

                Text("FIGHTER PLANE")
                    .font(.system(size: 28, weight: .heavy, design: .monospaced))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 2, y: 2)

                Text("Loading" + String(repeating: ".", count: dotCount))
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 120, alignment: .leading)
                    .onReceive(timer) { _ in
                        dotCount = (dotCount + 1) % 4
                    }
            }
        }
        .ignoresSafeArea()
    }
}
