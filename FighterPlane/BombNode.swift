import SpriteKit

class BombNode: SKNode {

    private let bombSprite: SKSpriteNode
    private let shadowSprite: SKSpriteNode
    private let fallDuration: TimeInterval
    private var elapsed: TimeInterval = 0
    private var hasExploded = false

    // Store the bomb's initial local offset so we can interpolate
    private let initialBombPos: CGPoint = .zero
    private let initialShadowPos: CGPoint

    /// Called when the bomb reaches the ground
    var onImpact: ((CGPoint) -> Void)?

    init(startPosition: CGPoint, groundOffset: CGPoint) {
        bombSprite = SKSpriteNode(texture: SpriteGenerator.bomb())
        shadowSprite = SKSpriteNode(texture: SpriteGenerator.bombShadow())
        initialShadowPos = groundOffset
        fallDuration = GameConfig.bombFallDuration

        super.init()

        name = "bomb"

        // Shadow starts small on the ground
        shadowSprite.position = groundOffset
        shadowSprite.zPosition = ZLayer.shadows.rawValue
        shadowSprite.setScale(0.4)
        shadowSprite.alpha = 0.3
        addChild(shadowSprite)

        // Bomb starts at plane position (local origin)
        bombSprite.position = .zero
        bombSprite.zPosition = ZLayer.bombs.rawValue
        addChild(bombSprite)

        position = startPosition
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    func update(deltaTime: TimeInterval, scrollSpeed: CGFloat) {
        guard !hasExploded else { return }

        elapsed += deltaTime

        // Shadow scrolls with the ground
        shadowSprite.position.y -= scrollSpeed * CGFloat(deltaTime)

        // Interpolate bomb position toward the current shadow position (easeIn curve)
        let t = Swift.min(elapsed / fallDuration, 1.0)
        let easedT = t * t // quadratic ease-in

        // Bomb lerps from its start (0,0) to current shadow position
        bombSprite.position = CGPoint(
            x: initialBombPos.x + (shadowSprite.position.x - initialBombPos.x) * easedT,
            y: initialBombPos.y + (shadowSprite.position.y - initialBombPos.y) * easedT
        )

        // Bomb shrinks as it "falls away" from camera
        bombSprite.setScale(1.0 - 0.4 * easedT)

        // Shadow grows and darkens as bomb approaches ground
        shadowSprite.setScale(0.4 + 0.6 * easedT)
        shadowSprite.alpha = 0.3 + 0.4 * easedT

        // Explode when bomb reaches ground
        if t >= 1.0 {
            explode()
        }
    }

    private func explode() {
        guard !hasExploded else { return }
        hasExploded = true

        let worldPos = CGPoint(
            x: position.x + shadowSprite.position.x,
            y: position.y + shadowSprite.position.y
        )
        onImpact?(worldPos)

        // Remove after brief delay for explosion to play
        run(.sequence([
            .wait(forDuration: 0.1),
            .removeFromParent()
        ]))
    }
}
