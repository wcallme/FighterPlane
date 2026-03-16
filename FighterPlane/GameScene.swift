import SpriteKit

class GameScene: SKScene, SKPhysicsContactDelegate {

    // Core nodes
    private var player: PlayerNode!
    private var hud: HUD!
    private var parallax: ParallaxBackground!
    private var cameraNode: SKCameraNode!

    // Game state
    private var gameState: GameState = .playing
    private var lastUpdateTime: TimeInterval = 0
    private var spawnTimersInitialized = false
    private var lastGroundSpawn: TimeInterval = 0
    private var lastAirSpawn: TimeInterval = 0
    private var canRestart = false

    // Active entities
    private var enemies: [EnemyNode] = []
    private var bombs: [BombNode] = []

    // Multi-bomb system
    private lazy var equippedBombs: [WeaponInfo] = PlayerData.shared.equippedBombs
    private lazy var bombSlotReady: [Bool] = Array(repeating: true, count: PlayerData.shared.equippedBombs.count)

    // Touch tracking
    private var activeTouches: [UITouch: String] = [:]

    // Camera rest position (for shake recovery)
    private var cameraRestPosition: CGPoint = .zero

    // MARK: - Scene Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.36, green: 0.50, blue: 0.28, alpha: 1.0)

        setupCamera()
        setupPhysics()
        setupParallax()
        setupPlayer()
        setupHUD()

        GameManager.shared.resetSession()
    }

    private func setupCamera() {
        cameraNode = SKCameraNode()
        cameraRestPosition = CGPoint(x: size.width / 2, y: size.height / 2)
        cameraNode.position = cameraRestPosition
        addChild(cameraNode)
        camera = cameraNode
    }

    private func setupPhysics() {
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self
    }

    private func setupParallax() {
        parallax = ParallaxBackground(scene: self)
    }

    private func setupPlayer() {
        player = PlayerNode()
        player.position = CGPoint(x: size.width / 2, y: 100)
        addChild(player)
    }

    private func setupHUD() {
        hud = HUD()
        hud.setup(sceneSize: size)
        cameraNode.addChild(hud)
        // Offset HUD so (0,0) of HUD = bottom-left of screen
        hud.position = CGPoint(x: -size.width / 2, y: -size.height / 2)
    }

    // MARK: - Game Loop

    override func update(_ currentTime: TimeInterval) {
        guard gameState == .playing else { return }

        let deltaTime = lastUpdateTime == 0 ? 0 : currentTime - lastUpdateTime
        lastUpdateTime = currentTime

        guard deltaTime > 0 && deltaTime < 1.0 else { return }

        // Initialize spawn timers on first real update frame
        if !spawnTimersInitialized {
            lastGroundSpawn = currentTime
            lastAirSpawn = currentTime
            spawnTimersInitialized = true
        }

        // Update systems
        GameManager.shared.update(deltaTime: deltaTime)
        parallax.update(deltaTime: deltaTime)
        player.update(deltaTime: deltaTime, sceneSize: size)

        // Update enemies
        updateEnemies(deltaTime: deltaTime, currentTime: currentTime)

        // Update bombs
        updateBombs(deltaTime: deltaTime)

        // Auto-fire machine gun when fire button held
        updateAutoFire()

        // Update HUD
        hud.updateHealth(current: player.health, maximum: player.maxHealth)

        // Check game over
        if player.isDead {
            gameOver()
        }
    }

    // MARK: - Enemy Management

    private func updateEnemies(deltaTime: TimeInterval, currentTime: TimeInterval) {
        let manager = GameManager.shared

        // Spawn ground enemies
        if currentTime - lastGroundSpawn >= manager.groundSpawnInterval {
            lastGroundSpawn = currentTime
            spawnGroundEnemy()
        }

        // Spawn air enemies (biome-aware progression)
        if manager.shouldSpawnEnemyPlanes && currentTime - lastAirSpawn >= manager.airSpawnInterval {
            lastAirSpawn = currentTime
            spawnAirEnemyWave()
        }

        // Update all enemies
        var toRemove: [Int] = []
        for (index, enemy) in enemies.enumerated() {
            if enemy.parent == nil {
                toRemove.append(index)
                continue
            }
            if let bullet = enemy.update(deltaTime: deltaTime,
                                          currentTime: currentTime,
                                          playerPosition: player.position,
                                          sceneSize: size) {
                addChild(bullet)
            }
        }

        // Clean up removed enemies
        for index in toRemove.reversed() {
            enemies.remove(at: index)
        }
    }

    private func spawnGroundEnemy() {
        let types: [EnemyType] = [.tank, .tank, .aaGun, .building]
        let type = types.randomElement()!

        let enemy = EnemyNode(type: type)
        let margin: CGFloat = 60
        enemy.position = CGPoint(
            x: CGFloat.random(in: margin...(size.width - margin)),
            y: size.height + 40
        )

        // Apply difficulty health bonus
        enemy.health += GameManager.shared.enemyHealthBonus

        addChild(enemy)
        enemies.append(enemy)
    }

    private func spawnAirEnemyWave() {
        let manager = GameManager.shared
        let count = manager.airSpawnGroupSize
        let margin: CGFloat = 80

        for i in 0..<count {
            // Decide type: after biome 4 all planes are AI; in desert+ mix AI with basic
            let type: EnemyType
            if manager.allPlanesAreAI {
                type = .aiFighter
            } else if manager.shouldSpawnAIFighters {
                // 60% chance each plane is AI dogfighter
                type = Int.random(in: 0...9) < 6 ? .aiFighter : .fighter
            } else {
                type = .fighter
            }

            let enemy = EnemyNode(type: type)
            // Spread group members across the top with slight horizontal offset
            let baseX = CGFloat.random(in: margin...(size.width - margin))
            let offsetX = CGFloat(i) * 50 - CGFloat(count - 1) * 25
            enemy.position = CGPoint(
                x: min(size.width - margin, max(margin, baseX + offsetX)),
                y: size.height + 60 + CGFloat(i) * 30
            )

            // Apply difficulty health bonus
            enemy.health += manager.enemyHealthBonus

            addChild(enemy)
            enemies.append(enemy)
        }
    }

    // MARK: - Bomb Management

    private func updateBombs(deltaTime: TimeInterval) {
        var toRemove: [Int] = []
        for (index, bomb) in bombs.enumerated() {
            if bomb.parent == nil {
                toRemove.append(index)
                continue
            }
            bomb.update(deltaTime: deltaTime, scrollSpeed: GameConfig.scrollSpeed)
        }
        for index in toRemove.reversed() {
            bombs.remove(at: index)
        }
    }

    private func dropBomb() {
        // Find first ready bomb slot
        guard let slotIndex = bombSlotReady.firstIndex(of: true) else { return }
        bombSlotReady[slotIndex] = false

        let bombWeapon = equippedBombs[slotIndex]
        GameManager.shared.bombsDropped += 1

        // Calculate player's horizontal velocity for momentum transfer
        let playerSpeed = GameConfig.playerSpeed * PlayerData.shared.speedMultiplier
        let playerVelocityX: CGFloat
        if player.isTouchingLeft {
            playerVelocityX = -playerSpeed
        } else if player.isTouchingRight {
            playerVelocityX = playerSpeed
        } else {
            playerVelocityX = 0
        }

        // Base shadow offset (momentum offsets added in BombNode)
        let groundOffset = CGPoint(x: 15, y: -20)

        // Always drop a single canister (cluster warheads split mid-air)
        let bomb = BombNode(startPosition: player.position, groundOffset: groundOffset,
                            weaponId: bombWeapon.id, playerVelocityX: playerVelocityX,
                            scrollSpeed: GameConfig.scrollSpeed)
        bomb.onImpact = { [weak self] impactPoint in
            self?.handleBombImpact(at: impactPoint, weapon: bombWeapon)
        }

        // Cluster warhead: on mid-air split, spawn 8 tiny bomblets that scatter and fall
        if bombWeapon.id == "cluster_warhead" {
            bomb.onClusterSplit = { [weak self] splitPos, scrollY, elapsed in
                self?.spawnClusterBomblets(at: splitPos, weapon: bombWeapon,
                                           playerVelocityX: playerVelocityX, scrollY: scrollY, elapsed: elapsed)
            }
        }

        addChild(bomb)
        bombs.append(bomb)

        // Per-slot cooldown
        let cooldown = bombWeapon.fireRate
        hud.showBombCooldown(duration: cooldown)
        run(.sequence([
            .wait(forDuration: cooldown),
            .run { [weak self] in self?.bombSlotReady[slotIndex] = true }
        ]))
    }

    private func handleBombImpact(at point: CGPoint, weapon: WeaponInfo) {
        // Create explosion
        let explosion = ExplosionNode(at: point, size: .large)
        addChild(explosion)
        ExplosionNode.shakeScreen(scene: self, intensity: 6, duration: 0.4)

        // Damage nearby ground enemies using weapon stats
        let blastRadius = weapon.blastRadius
        for enemy in enemies {
            guard enemy.type.isGround, enemy.parent != nil else { continue }
            let dist = hypot(enemy.position.x - point.x, enemy.position.y - point.y)
            if dist <= blastRadius {
                let killed = enemy.takeDamage(weapon.damage)
                if killed {
                    destroyEnemy(enemy)
                }
            }
        }
    }

    /// Spawns 8 tiny dot bomblets that scatter radially from the cluster warhead's
    /// mid-air split point, simulating a cluster munition canister opening.
    private func spawnClusterBomblets(at splitPos: CGPoint, weapon: WeaponInfo,
                                      playerVelocityX: CGFloat, scrollY: CGFloat, elapsed: CGFloat) {
        // Small visual puff at split point
        addChild(ExplosionNode(at: splitPos, size: .small))

        let count = weapon.bulletCount  // 8 bomblets
        for i in 0..<count {
            // Scatter radially like a real cluster munition spinning open
            let angle = CGFloat(i) / CGFloat(count) * .pi * 2.0
            let spreadX = cos(angle) * CGFloat.random(in: 15...35)
            let spreadY = sin(angle) * CGFloat.random(in: 10...25)

            let offset = CGPoint(x: spreadX, y: -20 + spreadY)

            let bomblet = BombNode(startPosition: splitPos, groundOffset: offset,
                                    weaponId: "bomb", playerVelocityX: playerVelocityX * 0.3,
                                    scrollSpeed: GameConfig.scrollSpeed)
            bomblet.onImpact = { [weak self] impactPoint in
                self?.handleBombImpact(at: impactPoint, weapon: weapon)
            }
            // Make bomblet visually tiny
            bomblet.setScale(0.4)
            addChild(bomblet)
            bombs.append(bomblet)
        }
    }

    // MARK: - Auto-fire

    private func updateAutoFire() {
        // Check if fire button is being held
        let isFiring = activeTouches.values.contains("fire")
        guard isFiring else { return }

        let bullets = player.fireBullets()
        for bullet in bullets {
            addChild(bullet)
            GameManager.shared.shotsFired += 1

            let speed = (bullet.userData?["speed"] as? CGFloat) ?? GameConfig.bulletSpeed
            let angle = (bullet.userData?["angle"] as? CGFloat) ?? (.pi / 2)

            let dx = cos(angle) * speed
            let dy = sin(angle) * speed
            let moveAction = SKAction.moveBy(x: dx, y: dy, duration: 1.0)
            bullet.run(.sequence([moveAction, .removeFromParent()]))
        }
    }

    // MARK: - Collision Detection

    func didBegin(_ contact: SKPhysicsContact) {
        guard gameState == .playing else { return }

        let collision = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask

        // Player hit by enemy bullet
        if collision == PhysicsCategory.player | PhysicsCategory.enemyBullet {
            let bulletNode = contact.bodyA.categoryBitMask == PhysicsCategory.enemyBullet
                ? contact.bodyA.node : contact.bodyB.node
            let pos = bulletNode?.position ?? player.position
            let damage = (bulletNode?.userData?["damage"] as? Int) ?? GameConfig.enemyBulletDamage
            bulletNode?.removeFromParent()
            player.takeDamage(damage)
            addChild(ExplosionNode(at: pos, size: .small))
        }

        // Player hit by enemy plane
        else if collision == PhysicsCategory.player | PhysicsCategory.enemy {
            player.takeDamage(GameConfig.collisionDamage)
            let enemyNode = contact.bodyA.categoryBitMask == PhysicsCategory.enemy
                ? contact.bodyA.node : contact.bodyB.node
            if let enemy = enemyNode as? EnemyNode {
                let killed = enemy.takeDamage(999)
                if killed { destroyEnemy(enemy) }
            }
        }

        // Player bullet hits ground target
        else if collision == PhysicsCategory.playerBullet | PhysicsCategory.groundTarget {
            let bulletNode = contact.bodyA.categoryBitMask == PhysicsCategory.playerBullet
                ? contact.bodyA.node : contact.bodyB.node
            let targetNode = contact.bodyA.categoryBitMask == PhysicsCategory.groundTarget
                ? contact.bodyA.node : contact.bodyB.node
            let bulletDamage = (bulletNode?.userData?["damage"] as? Int) ?? GameConfig.bulletDamage
            bulletNode?.removeFromParent()

            if let enemy = targetNode as? EnemyNode {
                let pos = enemy.position
                addChild(ExplosionNode(at: pos, size: .small))
                let killed = enemy.takeDamage(bulletDamage)
                if killed { destroyEnemy(enemy) }
            }
        }

        // Player bullet hits air enemy
        else if collision == PhysicsCategory.playerBullet | PhysicsCategory.enemy {
            let bulletNode = contact.bodyA.categoryBitMask == PhysicsCategory.playerBullet
                ? contact.bodyA.node : contact.bodyB.node
            let enemyNode = contact.bodyA.categoryBitMask == PhysicsCategory.enemy
                ? contact.bodyA.node : contact.bodyB.node
            let bulletDamage = (bulletNode?.userData?["damage"] as? Int) ?? GameConfig.bulletDamage
            bulletNode?.removeFromParent()

            if let enemy = enemyNode as? EnemyNode {
                let pos = enemy.position
                addChild(ExplosionNode(at: pos, size: .small))
                let killed = enemy.takeDamage(bulletDamage)
                if killed { destroyEnemy(enemy) }
            }
        }

        // Player collides with ground target
        else if collision == PhysicsCategory.player | PhysicsCategory.groundTarget {
            player.takeDamage(GameConfig.collisionDamage)
        }
    }

    private func destroyEnemy(_ enemy: EnemyNode) {
        // Guard against double-destroy (e.g. bomb + bullet same frame)
        guard !enemy.isDestroyed else { return }
        enemy.isDestroyed = true

        GameManager.shared.addScore(enemy.type.score)
        GameManager.shared.enemiesDestroyed += 1
        hud.updateScore(GameManager.shared.currentScore)

        let pos = enemy.position
        addChild(ExplosionNode(at: pos, size: .medium))
        enemy.destroyAnimation()
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if gameState == .gameOver {
            if canRestart {
                restartGame()
            }
            return
        }
        guard gameState == .playing else { return }

        for touch in touches {
            let location = touch.location(in: self)
            let hudLocation = touch.location(in: cameraNode)
            // Adjust for HUD offset
            let hudPoint = CGPoint(x: hudLocation.x + size.width / 2,
                                   y: hudLocation.y + size.height / 2)

            // Check HUD buttons first
            if let buttonName = detectButton(at: hudPoint) {
                activeTouches[touch] = buttonName
                if buttonName == "bomb" {
                    dropBomb()
                }
                continue
            }

            // Otherwise, steering
            if location.x < size.width / 2 {
                activeTouches[touch] = "left"
                player.isTouchingLeft = true
                player.bankLeft()
            } else {
                activeTouches[touch] = "right"
                player.isTouchingRight = true
                player.bankRight()
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Could add drag-to-steer here later
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if let action = activeTouches[touch] {
                if action == "left" { player.isTouchingLeft = false }
                if action == "right" { player.isTouchingRight = false }
                activeTouches.removeValue(forKey: touch)
            }
        }

        // Reset bank if no steering touches
        if !player.isTouchingLeft && !player.isTouchingRight {
            player.bankCenter()
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    private func detectButton(at point: CGPoint) -> String? {
        // Fire button zone (bottom-left)
        let fireRect = CGRect(x: 10, y: 10, width: 100, height: 80)
        if fireRect.contains(point) { return "fire" }

        // Bomb button zone (bottom-right)
        let bombRect = CGRect(x: size.width - 110, y: 10, width: 100, height: 80)
        if bombRect.contains(point) { return "bomb" }

        return nil
    }

    // MARK: - Game Over

    private func gameOver() {
        guard gameState == .playing else { return }
        gameState = .gameOver
        canRestart = false
        GameManager.shared.endGame()

        // Clear active touches so steering doesn't persist
        activeTouches.removeAll()
        player.isTouchingLeft = false
        player.isTouchingRight = false

        // Player death animation
        let explosion = ExplosionNode(at: player.position, size: .large)
        addChild(explosion)
        ExplosionNode.shakeScreen(scene: self, intensity: 10, duration: 0.6)
        player.removeFromParent()

        // Show game over overlay
        showGameOverScreen()
    }

    private func showGameOverScreen() {
        let manager = GameManager.shared

        let overlay = SKShapeNode(rectOf: size)
        overlay.fillColor = SKColor(white: 0, alpha: 0.6)
        overlay.strokeColor = .clear
        overlay.zPosition = ZLayer.hud.rawValue + 10
        cameraNode.addChild(overlay)

        let gameOverLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        gameOverLabel.text = "GAME OVER"
        gameOverLabel.fontSize = 40
        gameOverLabel.fontColor = .white
        gameOverLabel.zPosition = ZLayer.hud.rawValue + 11
        gameOverLabel.position = CGPoint(x: 0, y: 50)
        cameraNode.addChild(gameOverLabel)

        let scoreLabel = SKLabelNode(fontNamed: "Menlo")
        scoreLabel.text = "Score: \(manager.currentScore)"
        scoreLabel.fontSize = 22
        scoreLabel.fontColor = SKColor(white: 0.9, alpha: 1.0)
        scoreLabel.zPosition = ZLayer.hud.rawValue + 11
        scoreLabel.position = CGPoint(x: 0, y: 15)
        cameraNode.addChild(scoreLabel)

        let highScoreLabel = SKLabelNode(fontNamed: "Menlo")
        highScoreLabel.text = "Best: \(manager.highScore)"
        highScoreLabel.fontSize = 16
        highScoreLabel.fontColor = SKColor(white: 0.7, alpha: 1.0)
        highScoreLabel.zPosition = ZLayer.hud.rawValue + 11
        highScoreLabel.position = CGPoint(x: 0, y: -10)
        cameraNode.addChild(highScoreLabel)

        // Show earned rewards
        let earnedCoins = manager.currentCoins
        let earnedGems = manager.currentScore / 100 // 1 gem per 100 score
        let rewardsLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        rewardsLabel.text = "+\(earnedCoins) coins  +\(earnedGems) gems"
        rewardsLabel.fontSize = 14
        rewardsLabel.fontColor = SKColor(red: 0.9, green: 0.8, blue: 0.2, alpha: 1)
        rewardsLabel.zPosition = ZLayer.hud.rawValue + 11
        rewardsLabel.position = CGPoint(x: 0, y: -35)
        cameraNode.addChild(rewardsLabel)

        let restartLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        restartLabel.text = "Tap to Continue"
        restartLabel.fontSize = 18
        restartLabel.fontColor = SKColor(white: 0.8, alpha: 1.0)
        restartLabel.zPosition = ZLayer.hud.rawValue + 11
        restartLabel.position = CGPoint(x: 0, y: -70)
        restartLabel.name = "restartButton"
        cameraNode.addChild(restartLabel)

        // Pulse restart text
        restartLabel.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.4, duration: 0.6),
            .fadeAlpha(to: 1.0, duration: 0.6)
        ])))

        // Allow restart after 1.5 second delay (prevents accidental taps)
        run(.sequence([
            .wait(forDuration: 1.5),
            .run { [weak self] in self?.canRestart = true }
        ]))
    }

    private func restartGame() {
        let hangar = HangarScene(size: size)
        hangar.scaleMode = scaleMode
        view?.presentScene(hangar, transition: .fade(withDuration: 0.5))
    }
}
