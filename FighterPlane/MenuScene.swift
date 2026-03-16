import SpriteKit

class MenuScene: SKScene {

    private var parallax: ParallaxBackground?
    private var lastUpdateTime: TimeInterval = 0

    static func create(size: CGSize) -> MenuScene {
        let scene = MenuScene(size: size)
        scene.scaleMode = .resizeFill
        return scene
    }

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.36, green: 0.50, blue: 0.28, alpha: 1.0)

        setupBackground()
        setupTitle()
        setupButtons()
        setupStats()
    }

    private func setupBackground() {
        parallax = ParallaxBackground(scene: self)

        // Scatter some decorative enemy sprites
        for _ in 0..<4 {
            let plane = SKSpriteNode(texture: SpriteGenerator.enemyPlane())
            plane.position = CGPoint(
                x: CGFloat.random(in: 50...(size.width - 50)),
                y: CGFloat.random(in: (size.height * 0.3)...(size.height * 0.7))
            )
            plane.zPosition = ZLayer.groundEnemies.rawValue
            plane.alpha = 0.4
            plane.setScale(0.8)
            addChild(plane)
        }
    }

    private func setupTitle() {
        // Title shadow
        let shadow = SKLabelNode(fontNamed: "Menlo-Bold")
        shadow.text = "FIGHTER PLANE"
        shadow.fontSize = 42
        shadow.fontColor = SKColor(white: 0, alpha: 0.4)
        shadow.position = CGPoint(x: size.width / 2 + 2, y: size.height * 0.72 - 2)
        shadow.zPosition = ZLayer.hud.rawValue
        addChild(shadow)

        // Title
        let title = SKLabelNode(fontNamed: "Menlo-Bold")
        title.text = "FIGHTER PLANE"
        title.fontSize = 42
        title.fontColor = .white
        title.position = CGPoint(x: size.width / 2, y: size.height * 0.72)
        title.zPosition = ZLayer.hud.rawValue + 1
        addChild(title)

        // Subtitle
        let subtitle = SKLabelNode(fontNamed: "Menlo")
        subtitle.text = "BOMBER ACE"
        subtitle.fontSize = 16
        subtitle.fontColor = SKColor(red: 0.9, green: 0.8, blue: 0.4, alpha: 0.9)
        subtitle.position = CGPoint(x: size.width / 2, y: size.height * 0.72 - 30)
        subtitle.zPosition = ZLayer.hud.rawValue + 1
        addChild(subtitle)
    }

    private func setupButtons() {
        // Play button
        let playBg = SKShapeNode(rectOf: CGSize(width: 180, height: 55), cornerRadius: 12)
        playBg.fillColor = SKColor(red: 0.2, green: 0.6, blue: 0.2, alpha: 0.9)
        playBg.strokeColor = SKColor(white: 1.0, alpha: 0.6)
        playBg.lineWidth = 2
        playBg.position = CGPoint(x: size.width / 2, y: size.height * 0.45)
        playBg.zPosition = ZLayer.hud.rawValue + 1
        playBg.name = "playButton"
        addChild(playBg)

        let playLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        playLabel.text = "PLAY"
        playLabel.fontSize = 26
        playLabel.fontColor = .white
        playLabel.verticalAlignmentMode = .center
        playLabel.position = .zero
        playLabel.name = "playButton"
        playBg.addChild(playLabel)

        // Pulse animation
        let pulse = SKAction.sequence([
            .scale(to: 1.05, duration: 0.8),
            .scale(to: 1.0, duration: 0.8)
        ])
        playBg.run(.repeatForever(pulse))

        // Decorative plane
        let playerPlane = SKSpriteNode(texture: SpriteGenerator.playerPlane())
        playerPlane.position = CGPoint(x: size.width / 2, y: size.height * 0.25)
        playerPlane.zPosition = ZLayer.hud.rawValue
        playerPlane.setScale(1.5)
        addChild(playerPlane)

        // Animate the plane floating
        let hover = SKAction.sequence([
            .moveBy(x: 0, y: 8, duration: 1.2),
            .moveBy(x: 0, y: -8, duration: 1.2)
        ])
        playerPlane.run(.repeatForever(hover))
    }

    private func setupStats() {
        let manager = GameManager.shared

        if manager.highScore > 0 {
            let highScore = SKLabelNode(fontNamed: "Menlo")
            highScore.text = "Best: \(manager.highScore)"
            highScore.fontSize = 14
            highScore.fontColor = SKColor(white: 0.8, alpha: 0.8)
            highScore.position = CGPoint(x: size.width / 2, y: size.height * 0.12)
            highScore.zPosition = ZLayer.hud.rawValue
            addChild(highScore)
        }

        if manager.gamesPlayed > 0 {
            let games = SKLabelNode(fontNamed: "Menlo")
            games.text = "Games: \(manager.gamesPlayed)"
            games.fontSize = 12
            games.fontColor = SKColor(white: 0.6, alpha: 0.7)
            games.position = CGPoint(x: size.width / 2, y: size.height * 0.07)
            games.zPosition = ZLayer.hud.rawValue
            addChild(games)
        }
    }

    override func update(_ currentTime: TimeInterval) {
        let dt = lastUpdateTime == 0 ? 0 : currentTime - lastUpdateTime
        lastUpdateTime = currentTime
        guard dt > 0 && dt < 1.0 else { return }
        parallax?.update(deltaTime: dt)
    }

    // MARK: - Touch

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let location = touch.location(in: self)
            let nodesAtPoint = nodes(at: location)

            if nodesAtPoint.contains(where: { $0.name == "playButton" }) {
                startGame()
            }
        }
    }

    private func startGame() {
        let hangar = HangarScene(size: size)
        hangar.scaleMode = .resizeFill
        view?.presentScene(hangar, transition: .fade(withDuration: 0.5))
    }
}
