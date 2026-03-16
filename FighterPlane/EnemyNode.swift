import SpriteKit

class EnemyNode: SKNode {

    let type: EnemyType
    var health: Int
    var isDestroyed = false
    private let bodySprite: SKSpriteNode
    private let shadowSprite: SKSpriteNode?
    private var lastFireTime: TimeInterval = -1  // -1 signals "not yet initialized"
    private let fireInterval: TimeInterval

    // AI Fighter tracking state
    private var heading: CGFloat = -.pi / 2  // default pointing downward
    private var aiActivated = false           // dormant until player approaches


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
            fireInterval = 2.0
        case .aiFighter:
            bodySprite = SKSpriteNode(texture: SpriteGenerator.aiFighterPlane())
            shadowSprite = SKSpriteNode(texture: SpriteGenerator.enemyShadow())
            fireInterval = GameConfig.aiFighterFireRate
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

        // AI fighters start facing away from player — they U-turn before becoming visible
        if type == .aiFighter {
            heading = .pi / 2
        }

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
        } else if type == .aiFighter {
            updateAIFighter(deltaTime: deltaTime, playerPosition: playerPosition, sceneSize: sceneSize)
        } else {
            // Basic fighters: pursue the player's X position while descending
            let dt = CGFloat(deltaTime)
            let dx = playerPosition.x - position.x
            let chaseSpeed: CGFloat = 130.0 * dt
            position.x += max(-chaseSpeed, min(chaseSpeed, dx))
            position.y -= GameConfig.scrollSpeed * 1.3 * dt
            // Clamp to screen bounds
            let margin: CGFloat = 30
            position.x = Swift.max(margin, Swift.min(sceneSize.width - margin, position.x))
            // Bank sprite toward player direction
            let tilt = max(-0.4, min(0.4, dx / 150.0))
            bodySprite.zRotation = .pi - tilt
        }

        // Off-screen removal — activated AI fighters are IMPERVIOUS to despawning
        if !(type == .aiFighter && aiActivated) {
            // Dormant AI fighters get a tall top margin (they spawn far above screen)
            let offMargin: CGFloat = 60
            let topMargin: CGFloat = type == .aiFighter ? 1200 : 100
            if position.y < -offMargin || position.y > sceneSize.height + topMargin
                || position.x < -offMargin || position.x > sceneSize.width + offMargin {
                removeFromParent()
                return nil
            }
        }

        // Initialize fire timer on first update so enemies don't shoot instantly
        if lastFireTime < 0 {
            lastFireTime = currentTime
        }

        // Shooting logic — AI fighters only shoot when activated
        if type == .aiFighter {
            guard aiActivated else { return nil }
            if currentTime - lastFireTime >= fireInterval {
                let angleToPlayer = atan2(playerPosition.y - position.y,
                                          playerPosition.x - position.x)
                let angleDiff = normalizeAngle(angleToPlayer - heading)
                if abs(angleDiff) <= GameConfig.aiFighterFiringCone {
                    lastFireTime = currentTime
                    return fireAIMachineGun(playerPosition: playerPosition)
                }
            }
        } else if fireInterval > 0 && currentTime - lastFireTime >= fireInterval {
            lastFireTime = currentTime
            return fireAtPlayer(playerPosition: playerPosition)
        }

        return nil
    }

    // MARK: - AI Fighter: Seeking-Missile Dogfight

    private func updateAIFighter(deltaTime: TimeInterval, playerPosition: CGPoint, sceneSize: CGSize) {
        let dt = CGFloat(deltaTime)

        // --- DORMANT PHASE: scroll with terrain until approaching visible screen ---
        if !aiActivated {
            position.y -= GameConfig.scrollSpeed * dt

            // Activate just above the visible screen so U-turn completes off-screen
            if position.y < sceneSize.height + 100 {
                aiActivated = true
            }

            // Show facing direction while dormant
            let visualAngle = heading - .pi / 2
            bodySprite.zRotation = -visualAngle
            if let shadow = shadowSprite {
                shadow.position = CGPoint(x: 18 + cos(heading) * 5, y: -22 + sin(heading) * 5)
            }
            return
        }

        // --- ACTIVE PHASE: chase player like a seeking missile ---
        let dx = playerPosition.x - position.x
        let dy = playerPosition.y - position.y
        let dist = hypot(dx, dy)

        // Default target: always the player (seeking missile behavior)
        var targetAngle = atan2(dy, dx)

        // Break into a steep climb when dangerously close to avoid collision
        if dist < 120 && position.y < playerPosition.y + 100 {
            let side: CGFloat = position.x < playerPosition.x ? -1.0 : 1.0
            // ~78° steep climb with slight lateral offset
            targetAngle = atan2(CGFloat(1.0), side * CGFloat(0.2))
        }

        // Steer toward target — seeking missile style
        let angleDiff = normalizeAngle(targetAngle - heading)
        let maxTurn = GameConfig.aiFighterTurnSpeed * dt
        let actualTurn: CGFloat
        if abs(angleDiff) <= maxTurn {
            actualTurn = abs(angleDiff)
            heading = targetAngle
        } else {
            actualTurn = maxTurn
            heading += angleDiff > 0 ? maxTurn : -maxTurn
        }

        // Gentle edge avoidance
        let edgePush: CGFloat = 3.0 * dt
        if position.x < 20 { heading += edgePush }
        else if position.x > sceneSize.width - 20 { heading -= edgePush }

        // Move — no scroll drift, this is an active combat plane
        let speed = GameConfig.aiFighterMoveSpeed * dt
        position.x += cos(heading) * speed
        position.y += sin(heading) * speed

        // Sprite rotation (heading direction)
        let visualAngle = heading - .pi / 2
        bodySprite.zRotation = -visualAngle

        // Bank/roll animation: xScale narrows when turning hard (like player banking)
        let turnRatio = maxTurn > 0 ? actualTurn / maxTurn : 0
        let bankScale: CGFloat = 1.0 - turnRatio * 0.4 // 1.0 straight → 0.6 max bank
        let currentXScale = bodySprite.xScale
        bodySprite.xScale = currentXScale + (bankScale - currentXScale) * min(1.0, dt * 8.0)

        // Shadow
        if let shadow = shadowSprite {
            shadow.position = CGPoint(x: 18 + cos(heading) * 5, y: -22 + sin(heading) * 5)
        }
    }

    // MARK: - Firing

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

    /// AI machine gun: small yellow tracer rounds, rapid fire, low damage
    private func fireAIMachineGun(playerPosition: CGPoint) -> SKNode? {
        let bullet = SKSpriteNode(texture: SpriteGenerator.aiFighterBullet())
        // Spawn bullet slightly ahead of the AI plane along its heading
        bullet.position = CGPoint(
            x: position.x + cos(heading) * 20,
            y: position.y + sin(heading) * 20
        )
        bullet.zPosition = ZLayer.bullets.rawValue
        bullet.name = "enemyBullet"

        let body = SKPhysicsBody(circleOfRadius: 3)
        body.categoryBitMask = PhysicsCategory.enemyBullet
        body.contactTestBitMask = PhysicsCategory.player
        body.collisionBitMask = PhysicsCategory.none
        body.isDynamic = true
        body.affectedByGravity = false
        bullet.physicsBody = body

        // Fire along the AI's current heading with slight random spread
        let spread = CGFloat.random(in: -0.08...0.08) // slight inaccuracy
        let fireAngle = heading + spread
        let speed = GameConfig.aiFighterBulletSpeed
        bullet.physicsBody?.velocity = CGVector(dx: cos(fireAngle) * speed,
                                                dy: sin(fireAngle) * speed)

        // Store damage in userData so collision handler can read it
        bullet.userData = NSMutableDictionary()
        bullet.userData?["damage"] = GameConfig.aiFighterBulletDamage

        // Auto-remove after 2.5 seconds
        bullet.run(.sequence([.wait(forDuration: 2.5), .removeFromParent()]))

        return bullet
    }

    // MARK: - Helpers

    private func normalizeAngle(_ angle: CGFloat) -> CGFloat {
        var a = angle
        while a > .pi { a -= 2 * .pi }
        while a < -.pi { a += 2 * .pi }
        return a
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
