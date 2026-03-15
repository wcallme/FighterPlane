import SpriteKit

class EnemyNode: SKNode {

    let type: EnemyType
    var health: Int
    var isDestroyed = false
    private let bodySprite: SKSpriteNode
    private let shadowSprite: SKSpriteNode?
    private var lastFireTime: TimeInterval = -1  // -1 signals "not yet initialized"
    private let fireInterval: TimeInterval

    init(type: EnemyType) {
        self.type = type
        self.health = type.health

        switch type {
        case .tank:
            bodySprite = SKSpriteNode(texture: SpriteGenerator.tank())
            shadowSprite = nil
            fireInterval = 0 // tanks don't shoot in this version
        case .aaGun:
            bodySprite = SKSpriteNode(texture: SpriteGenerator.aaGun())
            shadowSprite = nil
            fireInterval = 2.0
        case .building:
            bodySprite = SKSpriteNode(texture: SpriteGenerator.building())
            shadowSprite = nil
            fireInterval = 0
        case .fighter:
            bodySprite = SKSpriteNode(texture: SpriteGenerator.enemyPlane())
            shadowSprite = SKSpriteNode(texture: SpriteGenerator.enemyShadow())
            fireInterval = 3.0
        case .samLauncher:
            bodySprite = SKSpriteNode(texture: SpriteGenerator.aaGun()) // reuse AA gun sprite for 2D
            shadowSprite = nil
            fireInterval = 5.0
        case .truck:
            bodySprite = SKSpriteNode(texture: SpriteGenerator.tank()) // reuse tank sprite for 2D
            shadowSprite = nil
            fireInterval = 0
        case .radioTower:
            bodySprite = SKSpriteNode(texture: SpriteGenerator.building()) // reuse building sprite for 2D
            shadowSprite = nil
            fireInterval = 0
        }

        super.init()

        setupNodes()
        setupPhysics()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    private func setupNodes() {
        name = "enemy"

        if type.isGround {
            // Ground enemies
            bodySprite.zPosition = ZLayer.groundEnemies.rawValue
            addChild(bodySprite)
        } else {
            // Air enemies have shadows
            if let shadow = shadowSprite {
                shadow.position = CGPoint(x: 18, y: -22)
                shadow.zPosition = ZLayer.shadows.rawValue
                shadow.alpha = 0.5
                addChild(shadow)
            }

            bodySprite.zPosition = ZLayer.airEnemies.rawValue
            // Flip enemy planes to face downward (toward player)
            bodySprite.yScale = -1
            addChild(bodySprite)
        }
    }

    private func setupPhysics() {
        let category: UInt32 = type.isGround ? PhysicsCategory.groundTarget : PhysicsCategory.enemy
        let contactWith: UInt32 = type.isGround
            ? (PhysicsCategory.bomb | PhysicsCategory.playerBullet)
            : (PhysicsCategory.player | PhysicsCategory.playerBullet)

        let bodySize = CGSize(width: bodySprite.size.width * 0.8,
                              height: bodySprite.size.height * 0.8)
        let body = SKPhysicsBody(rectangleOf: bodySize)
        body.categoryBitMask = category
        body.contactTestBitMask = contactWith
        body.collisionBitMask = PhysicsCategory.none
        body.isDynamic = type.isGround ? false : true
        body.affectedByGravity = false
        physicsBody = body
    }

    // MARK: - Update

    func update(deltaTime: TimeInterval, currentTime: TimeInterval, playerPosition: CGPoint, sceneSize: CGSize) -> SKNode? {
        if type.isGround {
            // Ground enemies scroll with terrain
            position.y -= GameConfig.scrollSpeed * CGFloat(deltaTime)
        } else {
            // Air enemies: simple sine-wave movement toward bottom
            position.y -= GameConfig.scrollSpeed * 1.2 * CGFloat(deltaTime)
            position.x += sin(currentTime * 2 + Double(position.y) * 0.01) * CGFloat(deltaTime) * 60
            // Clamp to screen bounds
            let margin: CGFloat = 30
            position.x = Swift.max(margin, Swift.min(sceneSize.width - margin, position.x))
        }

        // Remove if off-screen
        if position.y < -60 || position.y > sceneSize.height + 100 {
            removeFromParent()
            return nil
        }

        // Initialize fire timer on first update so enemies don't shoot instantly
        if lastFireTime < 0 {
            lastFireTime = currentTime
        }

        // Shooting logic
        if fireInterval > 0 && currentTime - lastFireTime >= fireInterval {
            lastFireTime = currentTime
            return fireAtPlayer(playerPosition: playerPosition)
        }

        return nil
    }

    private func fireAtPlayer(playerPosition: CGPoint) -> SKNode? {
        guard type == .aaGun || type == .fighter || type == .samLauncher else { return nil }

        let bullet = SKSpriteNode(texture: SpriteGenerator.enemyBullet())
        bullet.position = position
        bullet.zPosition = ZLayer.bullets.rawValue
        bullet.name = "enemyBullet"

        let body = SKPhysicsBody(circleOfRadius: 3)
        body.categoryBitMask = PhysicsCategory.enemyBullet
        body.contactTestBitMask = PhysicsCategory.player
        body.collisionBitMask = PhysicsCategory.none
        body.isDynamic = true
        body.affectedByGravity = false
        bullet.physicsBody = body

        // Aim at player
        let direction = CGVector(
            dx: playerPosition.x - position.x,
            dy: playerPosition.y - position.y
        )
        let length = sqrt(direction.dx * direction.dx + direction.dy * direction.dy)
        guard length > 0 else { return nil }

        let speed = GameConfig.enemyBulletSpeed
        let velocity = CGVector(dx: direction.dx / length * speed,
                                dy: direction.dy / length * speed)
        bullet.physicsBody?.velocity = velocity

        // Auto-remove after 3 seconds
        bullet.run(.sequence([.wait(forDuration: 3.0), .removeFromParent()]))

        return bullet
    }

    // MARK: - Damage

    func takeDamage(_ amount: Int) -> Bool {
        health -= amount

        // Flash white
        let flash = SKAction.sequence([
            .colorize(with: .white, colorBlendFactor: 0.8, duration: 0.05),
            .colorize(withColorBlendFactor: 0.0, duration: 0.05)
        ])
        bodySprite.run(flash)

        return health <= 0
    }

    func destroyAnimation() {
        // Scale down and fade
        let destroy = SKAction.group([
            .scale(to: 0.2, duration: 0.3),
            .fadeOut(withDuration: 0.3)
        ])
        run(.sequence([destroy, .removeFromParent()]))
    }
}
