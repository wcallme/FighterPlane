import SpriteKit

class PlayerNode: SKNode {

    var health: Int
    let maxHealth: Int
    var isInvincible = false
    var canShoot = true
    var canBomb = true
    var burstShotCount = 0

    private let bodySprite: SKSpriteNode
    let shadowSprite: SKSpriteNode
    private let propellerNode: SKNode

    // Movement
    var isTouchingLeft = false
    var isTouchingRight = false

    init(health: Int = PlayerData.shared.maxHealth) {
        self.health = health
        self.maxHealth = health

        bodySprite = SKSpriteNode(texture: SpriteGenerator.playerPlane())
        shadowSprite = SKSpriteNode(texture: SpriteGenerator.playerShadow())
        propellerNode = PlayerNode.makePropeller()

        super.init()

        setupNodes()
        setupPhysics()
        startAnimations()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    // MARK: - Setup

    private func setupNodes() {
        // Shadow (on ground, offset to simulate altitude)
        shadowSprite.position = CGPoint(x: 20, y: -25)
        shadowSprite.zPosition = ZLayer.playerShadow.rawValue
        shadowSprite.alpha = 0.6
        addChild(shadowSprite)

        // Main body
        bodySprite.zPosition = ZLayer.player.rawValue
        addChild(bodySprite)

        // Propeller
        propellerNode.position = CGPoint(x: 0, y: bodySprite.size.height / 2 - 2)
        propellerNode.zPosition = ZLayer.player.rawValue + 0.1
        bodySprite.addChild(propellerNode)
    }

    private func setupPhysics() {
        let body = SKPhysicsBody(rectangleOf: CGSize(width: 30, height: 40))
        body.categoryBitMask = PhysicsCategory.player
        body.contactTestBitMask = PhysicsCategory.enemy | PhysicsCategory.enemyBullet | PhysicsCategory.groundTarget
        body.collisionBitMask = PhysicsCategory.none
        body.isDynamic = true
        body.affectedByGravity = false
        physicsBody = body
    }

    private static func makePropeller() -> SKNode {
        let node = SKNode()
        let blade1 = SKShapeNode(rectOf: CGSize(width: 22, height: 3), cornerRadius: 1.5)
        blade1.fillColor = SKColor(white: 0.4, alpha: 0.8)
        blade1.strokeColor = .clear
        node.addChild(blade1)

        let blade2 = SKShapeNode(rectOf: CGSize(width: 3, height: 22), cornerRadius: 1.5)
        blade2.fillColor = SKColor(white: 0.4, alpha: 0.8)
        blade2.strokeColor = .clear
        node.addChild(blade2)
        return node
    }

    private func startAnimations() {
        let spin = SKAction.rotate(byAngle: .pi * 2, duration: 0.08)
        propellerNode.run(.repeatForever(spin))
    }

    // MARK: - Update

    func update(deltaTime: TimeInterval, sceneSize: CGSize) {
        let speed = GameConfig.playerSpeed * PlayerData.shared.speedMultiplier * CGFloat(deltaTime)

        if isTouchingLeft {
            position.x -= speed
        } else if isTouchingRight {
            position.x += speed
        }

        // Clamp to screen bounds
        let margin: CGFloat = 30
        position.x = max(margin, min(sceneSize.width - margin, position.x))

        // Update shadow position (parallax offset based on screen position)
        let centerX = sceneSize.width / 2
        let offsetX = (position.x - centerX) / centerX * 15
        shadowSprite.position = CGPoint(x: 20 + offsetX, y: -25)
    }

    // MARK: - Actions

    func bankLeft() {
        bodySprite.run(.rotate(toAngle: -0.25, duration: 0.12))
    }

    func bankRight() {
        bodySprite.run(.rotate(toAngle: 0.25, duration: 0.12))
    }

    func bankCenter() {
        bodySprite.run(.rotate(toAngle: 0, duration: 0.12))
    }

    func takeDamage(_ amount: Int) {
        guard !isInvincible else { return }
        health = max(0, health - amount)

        // Flash effect
        let flash = SKAction.sequence([
            .colorize(with: .red, colorBlendFactor: 0.8, duration: 0.05),
            .colorize(withColorBlendFactor: 0.0, duration: 0.05)
        ])
        bodySprite.run(.repeat(flash, count: 4))

        // Brief invincibility
        isInvincible = true
        run(.sequence([
            .wait(forDuration: 0.6),
            .run { [weak self] in self?.isInvincible = false }
        ]))
    }

    func fireBullets() -> [SKNode] {
        let guns = PlayerData.shared.equippedGuns
        guard canShoot, !guns.isEmpty else { return [] }
        canShoot = false
        burstShotCount += 1
        // Use the fastest fire rate among all equipped guns for cooldown
        let fastestFireRate = guns.map(\.fireRate).min() ?? 0.22

        // Cooldown based on fastest equipped weapon
        run(.sequence([
            .wait(forDuration: fastestFireRate),
            .run { [weak self] in self?.canShoot = true }
        ]))

        // Accuracy bloom: first 2 shots laser-accurate, then jitter ramps to a modest cap
        let accurateShots = 2
        let bloomPerShot: CGFloat = 0.5 * .pi / 180.0
        let maxBloom: CGFloat = 2.0 * .pi / 180.0
        let bloom = min(maxBloom, bloomPerShot * CGFloat(max(0, burstShotCount - accurateShots)))

        var bullets: [SKNode] = []

        // Each equipped gun fires its own bullets
        for (gunIndex, gun) in guns.enumerated() {
            let count = gun.bulletCount
            let spread = gun.bulletSpread

            // Slight X offset per gun to simulate multiple barrels
            let gunSpacing: CGFloat = guns.count > 1 ? 8 : 0
            let gunOffset = CGFloat(gunIndex) - CGFloat(guns.count - 1) / 2.0

            for i in 0..<count {
                let bullet = SKSpriteNode(texture: SpriteGenerator.bullet(weaponId: gun.id))
                bullet.position = CGPoint(
                    x: position.x + gunOffset * gunSpacing,
                    y: position.y + 30
                )
                bullet.zPosition = ZLayer.bullets.rawValue
                bullet.name = "playerBullet"

                let body = SKPhysicsBody(rectangleOf: bullet.size)
                body.categoryBitMask = PhysicsCategory.playerBullet
                body.contactTestBitMask = PhysicsCategory.enemy | PhysicsCategory.groundTarget
                body.collisionBitMask = PhysicsCategory.none
                body.isDynamic = true
                body.affectedByGravity = false
                bullet.physicsBody = body

                // Calculate spread angle for multi-bullet weapons
                var angle: CGFloat = .pi / 2 // straight up
                if count > 1 {
                    let offset = CGFloat(i) - CGFloat(count - 1) / 2.0
                    angle += offset * spread
                } else if spread > 0 {
                    angle += CGFloat.random(in: -spread...spread)
                }

                // Apply burst accuracy bloom
                angle += CGFloat.random(in: -bloom...bloom)

                let finalDamage = Int((Double(gun.damage) * PlayerData.shared.gunDamageMultiplier).rounded())

                bullet.userData = NSMutableDictionary()
                bullet.userData?["speed"] = gun.projectileSpeed
                bullet.userData?["angle"] = angle
                bullet.userData?["damage"] = finalDamage

                bullets.append(bullet)
            }
        }

        return bullets
    }

    var isDead: Bool { health <= 0 }
}
