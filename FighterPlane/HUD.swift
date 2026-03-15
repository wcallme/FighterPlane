import SpriteKit

class HUD: SKNode {

    private let healthBarBackground: SKShapeNode
    private let healthBarFill: SKShapeNode
    private let scoreLabel: SKLabelNode
    private let bombCooldownOverlay: SKShapeNode

    // Control zones (for touch detection)
    private(set) var fireButton: SKSpriteNode!
    private(set) var bombButton: SKSpriteNode!

    var sceneSize: CGSize = .zero

    override init() {
        healthBarBackground = SKShapeNode(rectOf: CGSize(width: 120, height: 12), cornerRadius: 4)
        healthBarFill = SKShapeNode(rectOf: CGSize(width: 116, height: 8), cornerRadius: 3)
        scoreLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        bombCooldownOverlay = SKShapeNode(rectOf: CGSize(width: 40, height: 40), cornerRadius: 8)

        super.init()

        zPosition = ZLayer.hud.rawValue
        name = "hud"
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    func setup(sceneSize: CGSize) {
        self.sceneSize = sceneSize

        // Health bar - top left
        healthBarBackground.fillColor = SKColor(white: 0.2, alpha: 0.7)
        healthBarBackground.strokeColor = SKColor(white: 0.8, alpha: 0.8)
        healthBarBackground.lineWidth = 1.5
        healthBarBackground.position = CGPoint(x: 80, y: sceneSize.height - 30)
        addChild(healthBarBackground)

        healthBarFill.fillColor = SKColor(red: 0.2, green: 0.8, blue: 0.2, alpha: 1.0)
        healthBarFill.strokeColor = .clear
        healthBarFill.position = healthBarBackground.position
        addChild(healthBarFill)

        let healthIcon = SKLabelNode(fontNamed: "Menlo-Bold")
        healthIcon.text = "HP"
        healthIcon.fontSize = 10
        healthIcon.fontColor = .white
        healthIcon.position = CGPoint(x: 16, y: sceneSize.height - 34)
        addChild(healthIcon)

        // Score - top right
        scoreLabel.text = "0"
        scoreLabel.fontSize = 20
        scoreLabel.fontColor = .white
        scoreLabel.horizontalAlignmentMode = .right
        scoreLabel.position = CGPoint(x: sceneSize.width - 20, y: sceneSize.height - 35)
        addChild(scoreLabel)

        let scoreIcon = SKLabelNode(fontNamed: "Menlo-Bold")
        scoreIcon.text = "SCORE"
        scoreIcon.fontSize = 10
        scoreIcon.fontColor = SKColor(white: 0.8, alpha: 0.8)
        scoreIcon.horizontalAlignmentMode = .right
        scoreIcon.position = CGPoint(x: sceneSize.width - 20, y: sceneSize.height - 18)
        addChild(scoreIcon)

        // Fire button - bottom left
        fireButton = SKSpriteNode(
            texture: SpriteGenerator.buttonTexture(
                width: 70, height: 50,
                color: SKColor(red: 0.8, green: 0.4, blue: 0.1, alpha: 1.0),
                label: "FIRE"
            )
        )
        fireButton.position = CGPoint(x: 55, y: 45)
        fireButton.name = "fireButton"
        addChild(fireButton)

        // Bomb button - bottom right
        bombButton = SKSpriteNode(
            texture: SpriteGenerator.buttonTexture(
                width: 70, height: 50,
                color: SKColor(red: 0.7, green: 0.2, blue: 0.2, alpha: 1.0),
                label: "BOMB"
            )
        )
        bombButton.position = CGPoint(x: sceneSize.width - 55, y: 45)
        bombButton.name = "bombButton"
        addChild(bombButton)

        // Bomb cooldown overlay
        bombCooldownOverlay.fillColor = SKColor(white: 0, alpha: 0.5)
        bombCooldownOverlay.strokeColor = .clear
        bombCooldownOverlay.position = bombButton.position
        bombCooldownOverlay.isHidden = true
        addChild(bombCooldownOverlay)
    }

    // MARK: - Updates

    func updateHealth(current: Int, maximum: Int) {
        let ratio = CGFloat(current) / CGFloat(maximum)
        let clampedRatio = Swift.max(0, Swift.min(1, ratio))

        // Scale the fill bar
        healthBarFill.xScale = clampedRatio

        // Shift position to keep it left-aligned
        let fullWidth: CGFloat = 116
        let offset = (1 - clampedRatio) * fullWidth / 2
        healthBarFill.position.x = healthBarBackground.position.x - offset

        // Color based on health
        if ratio > 0.6 {
            healthBarFill.fillColor = SKColor(red: 0.2, green: 0.8, blue: 0.2, alpha: 1.0)
        } else if ratio > 0.3 {
            healthBarFill.fillColor = SKColor(red: 0.9, green: 0.7, blue: 0.1, alpha: 1.0)
        } else {
            healthBarFill.fillColor = SKColor(red: 0.9, green: 0.2, blue: 0.1, alpha: 1.0)
            // Pulse when critical
            if healthBarFill.action(forKey: "pulse") == nil {
                let pulse = SKAction.sequence([
                    .fadeAlpha(to: 0.5, duration: 0.3),
                    .fadeAlpha(to: 1.0, duration: 0.3)
                ])
                healthBarFill.run(.repeatForever(pulse), withKey: "pulse")
            }
        }

        if ratio > 0.3 {
            healthBarFill.removeAction(forKey: "pulse")
            healthBarFill.alpha = 1.0
        }
    }

    func updateScore(_ score: Int) {
        scoreLabel.text = "\(score)"

        // Pop animation — cancel previous to prevent pile-up (#22)
        scoreLabel.removeAction(forKey: "scorePop")
        scoreLabel.setScale(1.0)
        scoreLabel.run(.sequence([
            .scale(to: 1.2, duration: 0.1),
            .scale(to: 1.0, duration: 0.1)
        ]), withKey: "scorePop")
    }

    func showBombCooldown(duration: TimeInterval) {
        bombCooldownOverlay.isHidden = false
        bombCooldownOverlay.alpha = 0.6

        bombCooldownOverlay.run(.sequence([
            .fadeAlpha(to: 0, duration: duration),
            .run { [weak self] in self?.bombCooldownOverlay.isHidden = true }
        ]))
    }

}
