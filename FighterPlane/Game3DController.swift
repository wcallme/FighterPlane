import SceneKit
import SpriteKit

class Game3DController: NSObject, SCNSceneRendererDelegate {

    let scene = SCNScene()
    let hud: GameHUD3D

    // Camera – fixed side view (negative X so +Z = right on screen)
    private let cameraNode = SCNNode()
    private let cameraSideX: Float = -35.0
    private let cameraYOffset: Float = 3.0
    private var smoothCamY: Float = 12.0
    private var smoothCamZ: Float = 0

    // Lighting
    private let sunNode = SCNNode()

    // Player – moves in Y-Z plane only (X is always 0)
    private let playerNode: SCNNode
    private var playerY: Float = 12.0       // altitude
    private var playerZ: Float = 0          // position along the strip
    private var playerAngle: Float = 0      // flight angle: 0=level, +ve=climb, -ve=dive
    private var playerHealth: Int
    private let playerMaxHealth: Int
    private let playerSpeed: Float = 14.0
    private let minAltitude: Float = 2.0
    private let maxAltitude: Float = 98.0
    private var smoothFlipY: Float = 0    // smoothed Y euler for flip animation
    private var isInvincible = false
    private var canShoot = true
    private var canBomb = true

    // Water
    private let waterNode: SCNNode

    // Terrain – Z-strip chunks (slot-based for bidirectional generation)
    private var terrainChunks: [Int: SCNNode] = [:]       // slot → terrain node
    private var treeChunks: [Int: [SCNNode]] = [:]        // slot → tree nodes
    private let chunkDepth: Float = 100
    private let stripXStart: Float = -50
    private let chunksAhead: Int = 3
    private let chunksBehind: Int = 1

    // Enemies
    private var enemies: [Enemy3D] = []
    private var lastGroundSpawn: TimeInterval = 0
    private var lastAirSpawn: TimeInterval = 0
    private var spawnTimersInitialized = false

    // Bullets
    private var playerBullets: [Bullet3D] = []
    private var enemyBullets: [Bullet3D] = []

    // Bombs
    private var activeBombs: [Bomb3D] = []

    // SAM Missiles
    private var activeSAMs: [SAMMissile3D] = []

    // Game state
    private var gameState: GameState = .playing
    private var lastUpdateTime: TimeInterval = 0
    private var invincibilityTimer: TimeInterval = 0

    // Equipped weapon cache
    private let equippedGun: WeaponInfo
    private let equippedBomb: WeaponInfo

    // MARK: - Data Structs

    struct Enemy3D {
        let node: SCNNode
        let type: EnemyType
        var health: Int
        var lastFireTime: TimeInterval
        let isAir: Bool
    }

    struct Bullet3D {
        let node: SCNNode
        let velocity: SCNVector3
        let damage: Int
    }

    struct Bomb3D {
        let node: SCNNode
        let shadowNode: SCNNode
        var fallSpeed: Float
        let groundY: Float
        let damage: Int
        let blastRadius: Float
    }

    struct SAMMissile3D {
        let node: SCNNode
        var velocity: SCNVector3
        let damage: Int
        var lifetime: Float
        let turnRate: Float
    }

    // MARK: - Init

    override init() {
        let data = PlayerData.shared
        playerMaxHealth = data.maxHealth
        playerHealth = playerMaxHealth
        equippedGun = data.equippedGun
        equippedBomb = data.equippedBomb

        // HUD
        let hudSize = UIScreen.main.bounds.size
        hud = GameHUD3D(size: hudSize)
        hud.scaleMode = .resizeFill

        // Player model
        playerNode = ModelGenerator3D.playerPlane()

        // Water – large flat plane
        waterNode = ModelGenerator3D.waterPlane(width: 200, length: 600)

        super.init()

        setupScene()
        GameManager.shared.resetSession()
    }

    // MARK: - Scene Setup

    private func setupScene() {
        scene.background.contents = UIColor(red: 0.55, green: 0.78, blue: 0.95, alpha: 1.0)

        scene.fogStartDistance = 80
        scene.fogEndDistance = 180
        scene.fogColor = UIColor(red: 0.55, green: 0.78, blue: 0.95, alpha: 1.0)

        setupCamera()
        setupLighting()
        setupWater()
        setupPlayer()
        generateInitialTerrain()
    }

    private func setupCamera() {
        let camera = SCNCamera()
        camera.fieldOfView = 55
        camera.zNear = 0.5
        camera.zFar = 200
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(cameraSideX, playerY + cameraYOffset, playerZ)
        cameraNode.look(at: SCNVector3(0, playerY, playerZ + 12))
        scene.rootNode.addChildNode(cameraNode)
    }

    private func setupLighting() {
        // Sun (directional)
        let sun = SCNLight()
        sun.type = .directional
        sun.color = UIColor(white: 1.0, alpha: 1.0)
        sun.intensity = 1000
        sun.castsShadow = true
        sun.shadowRadius = 3
        sun.shadowSampleCount = 4
        sun.shadowMapSize = CGSize(width: 2048, height: 2048)
        sunNode.light = sun
        sunNode.eulerAngles = SCNVector3(-0.6, 0.3, 0)
        scene.rootNode.addChildNode(sunNode)

        // Ambient
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.color = UIColor(red: 0.4, green: 0.45, blue: 0.55, alpha: 1.0)
        ambient.intensity = 400
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)
    }

    private func setupWater() {
        waterNode.position = SCNVector3(0, -0.2, 0)
        scene.rootNode.addChildNode(waterNode)
    }

    private func setupPlayer() {
        playerNode.position = SCNVector3(0, playerY, playerZ)
        scene.rootNode.addChildNode(playerNode)
    }

    private func generateInitialTerrain() {
        manageTerrain()
    }

    // MARK: - Terrain Management (Z-Strip, Bidirectional)

    private func slotForZ(_ z: Float) -> Int {
        return Int(floor(z / chunkDepth))
    }

    private func manageTerrain() {
        let currentSlot = slotForZ(playerZ)
        let minSlot = currentSlot - chunksBehind
        let maxSlot = currentSlot + chunksAhead

        // Remove distant chunks
        for slot in Array(terrainChunks.keys) {
            if slot < minSlot || slot > maxSlot {
                terrainChunks[slot]?.removeFromParentNode()
                terrainChunks.removeValue(forKey: slot)
                if let trees = treeChunks[slot] {
                    for t in trees { t.removeFromParentNode() }
                    treeChunks.removeValue(forKey: slot)
                }
            }
        }

        // Generate missing chunks
        for slot in minSlot...maxSlot where terrainChunks[slot] == nil {
            let zStart = Float(slot) * chunkDepth

            let chunk = ModelGenerator3D.createTerrainChunk(
                xStart: stripXStart, zStart: zStart, chunkSize: chunkDepth
            )
            scene.rootNode.addChildNode(chunk)
            terrainChunks[slot] = chunk

            let trees = ModelGenerator3D.scatterTrees(
                xStart: stripXStart, zStart: zStart, chunkSize: chunkDepth
            )
            for tree in trees { scene.rootNode.addChildNode(tree) }
            treeChunks[slot] = trees
        }
    }

    // MARK: - Game Loop

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        guard gameState == .playing else {
            if hud.shouldRestart {
                hud.shouldRestart = false
                DispatchQueue.main.async {
                    NavigationManager.shared.isInGame = false
                }
            }
            return
        }

        let dt = lastUpdateTime == 0 ? 0 : time - lastUpdateTime
        lastUpdateTime = time
        guard dt > 0 && dt < 1.0 else { return }

        if !spawnTimersInitialized {
            lastGroundSpawn = time
            lastAirSpawn = time
            spawnTimersInitialized = true
        }

        let floatDt = Float(dt)

        GameManager.shared.update(deltaTime: dt)

        // Update player from joystick angle
        updatePlayer(dt: floatDt)

        // Update camera to track player from the side
        updateCamera(dt: floatDt)

        // Move water to follow player along Z
        waterNode.position = SCNVector3(0, -0.2, playerZ)

        // Terrain management
        manageTerrain()

        // Spawn enemies
        spawnEnemies(time: time)

        // Auto-fire (always shooting)
        fireGun()

        // Drop bomb
        if hud.shouldDropBomb {
            hud.shouldDropBomb = false
            dropBomb()
        }

        // Update bullets
        updateBullets(dt: floatDt)

        // Update bombs
        updateBombs(dt: floatDt)

        // Update SAM missiles
        updateSAMMissiles(dt: floatDt)

        // Update enemies
        updateEnemies(dt: floatDt, time: time)

        // Collision detection
        checkCollisions()

        // Invincibility timer
        if isInvincible {
            invincibilityTimer -= dt
            if invincibilityTimer <= 0 {
                isInvincible = false
                playerNode.opacity = 1.0
            }
        }

        // Update HUD
        hud.updateHealth(current: playerHealth, maximum: playerMaxHealth)

        // Check game over
        if playerHealth <= 0 {
            gameOver()
        }
    }

    // MARK: - Player

    private func updatePlayer(dt: Float) {
        let speedMult = Float(PlayerData.shared.speedMultiplier)

        // Joystick controls flight angle (full 360°)
        if hud.hasSteeringInput {
            let targetAngle = Float(hud.steeringAngle)

            // Shortest-path angle difference (handles wrap-around)
            var diff = targetAngle - playerAngle
            while diff > .pi { diff -= 2 * .pi }
            while diff < -.pi { diff += 2 * .pi }

            let turnSpeed: Float = 4.0
            playerAngle += diff * min(1.0, turnSpeed * dt)

            // Normalize
            while playerAngle > .pi { playerAngle -= 2 * .pi }
            while playerAngle < -.pi { playerAngle += 2 * .pi }
        } else {
            // No input → keep current angle (no reset)
        }

        // Move in the direction the plane is facing
        let speed = playerSpeed * speedMult
        playerZ += cos(playerAngle) * speed * dt
        playerY += sin(playerAngle) * speed * dt

        // Altitude clamping
        let groundH = ModelGenerator3D.terrainHeight(x: 0, z: playerZ)
        let groundMin = max(minAltitude, groundH + 1.5)
        if playerY < groundMin {
            playerY = groundMin
            if playerAngle < -0.1 { playerAngle = 0.1 }
        }
        playerY = min(maxAltitude, playerY)

        // Update node position
        playerNode.position = SCNVector3(0, playerY, playerZ)

        // Visual rotation: smooth flip when changing direction
        let facingRight = cos(playerAngle) >= 0
        let targetFlipY: Float = facingRight ? 0 : .pi

        // Smooth the Y rotation for a nice flip animation
        var flipDiff = targetFlipY - smoothFlipY
        // Shortest path through the angle
        while flipDiff > .pi { flipDiff -= 2 * .pi }
        while flipDiff < -.pi { flipDiff += 2 * .pi }
        smoothFlipY += flipDiff * min(1.0, 5.0 * dt)
        // Normalize
        while smoothFlipY > .pi { smoothFlipY -= 2 * .pi }
        while smoothFlipY < -.pi { smoothFlipY += 2 * .pi }

        playerNode.eulerAngles.y = smoothFlipY

        // Pitch based on current facing
        if facingRight {
            playerNode.eulerAngles.x = -playerAngle
        } else {
            let localAngle = atan2(sin(playerAngle), -cos(playerAngle))
            playerNode.eulerAngles.x = -localAngle
        }
    }

    private var smoothLeadZ: Float = 15.0

    private func updateCamera(dt: Float) {
        let targetY = playerY + cameraYOffset
        let targetZ = playerZ

        // Slow, smooth camera follow
        let followSpeed: Float = 1.8
        let t = min(1.0, followSpeed * dt)
        smoothCamY += (targetY - smoothCamY) * t
        smoothCamZ += (targetZ - smoothCamZ) * t

        cameraNode.position = SCNVector3(cameraSideX, smoothCamY, smoothCamZ)

        // Smoothly interpolate the look-ahead so direction changes aren't jarring
        let targetLeadZ = cos(playerAngle) * 15
        smoothLeadZ += (targetLeadZ - smoothLeadZ) * min(1.0, 1.2 * dt)
        cameraNode.look(at: SCNVector3(0, smoothCamY - 2, smoothCamZ + smoothLeadZ))

        // Sun follows along Z
        sunNode.position = SCNVector3(0, 50, playerZ + 20)
    }

    // MARK: - Shooting

    private func fireGun() {
        guard canShoot else { return }
        canShoot = false

        GameManager.shared.shotsFired += 1

        let bulletCount = equippedGun.bulletCount
        let spread = equippedGun.bulletSpread
        // Bullet speed = 3x the plane's current speed
        let speedMult = Float(PlayerData.shared.speedMultiplier)
        let speed = playerSpeed * speedMult * 3.0

        for i in 0..<bulletCount {
            let bullet = ModelGenerator3D.playerBullet()
            bullet.position = playerNode.position

            // Bullets fire in the direction the plane faces (playerAngle in Y-Z plane)
            var angle = playerAngle
            if bulletCount > 1 {
                let offset = Float(i) - Float(bulletCount - 1) / 2.0
                angle += offset * Float(spread)
            } else if spread > 0 {
                angle += Float.random(in: -Float(spread)...Float(spread))
            }

            let vz = cos(angle) * speed
            let vy = sin(angle) * speed

            // Tilt the stick to match flight direction
            bullet.eulerAngles.x = (.pi / 2) - angle

            scene.rootNode.addChildNode(bullet)
            playerBullets.append(Bullet3D(
                node: bullet,
                velocity: SCNVector3(0, vy, vz),
                damage: equippedGun.damage
            ))
        }

        // Cooldown
        DispatchQueue.main.asyncAfter(deadline: .now() + equippedGun.fireRate) { [weak self] in
            self?.canShoot = true
        }
    }

    // MARK: - Bombing

    private func dropBomb() {
        guard canBomb else { return }
        canBomb = false

        GameManager.shared.bombsDropped += 1

        let bombCount = equippedBomb.bulletCount
        for i in 0..<bombCount {
            let bomb = ModelGenerator3D.bomb3D()
            bomb.position = playerNode.position

            if bombCount > 1 {
                bomb.position.z += Float(i - bombCount / 2) * 2.5
            }

            let shadow = ModelGenerator3D.bombShadow3D()
            let shadowZ = bomb.position.z + 8
            let groundY = ModelGenerator3D.terrainHeight(x: 0, z: shadowZ)
            shadow.position = SCNVector3(0, max(0.1, groundY + 0.1), shadowZ)
            shadow.scale = SCNVector3(0.3, 0.3, 0.3)

            scene.rootNode.addChildNode(bomb)
            scene.rootNode.addChildNode(shadow)

            activeBombs.append(Bomb3D(
                node: bomb,
                shadowNode: shadow,
                fallSpeed: 0.5,
                groundY: max(0.1, groundY),
                damage: equippedBomb.damage,
                blastRadius: Float(equippedBomb.blastRadius) * 0.15
            ))
        }

        // Cooldown
        DispatchQueue.main.asyncAfter(deadline: .now() + equippedBomb.fireRate) { [weak self] in
            self?.canBomb = true
        }
    }

    // MARK: - Update Systems

    private func updateBullets(dt: Float) {
        // Player bullets
        playerBullets.removeAll { bullet in
            bullet.node.position.x += bullet.velocity.x * dt * 60
            bullet.node.position.y += bullet.velocity.y * dt * 60
            bullet.node.position.z += bullet.velocity.z * dt * 60

            let dz = bullet.node.position.z - playerZ
            if dz > 150 || dz < -30 {
                bullet.node.removeFromParentNode()
                return true
            }
            return false
        }

        // Enemy bullets
        enemyBullets.removeAll { bullet in
            bullet.node.position.x += bullet.velocity.x * dt * 60
            bullet.node.position.y += bullet.velocity.y * dt * 60
            bullet.node.position.z += bullet.velocity.z * dt * 60

            let dz = bullet.node.position.z - playerZ
            if abs(dz) > 100 || bullet.node.position.y < -1 || bullet.node.position.y > 30 {
                bullet.node.removeFromParentNode()
                return true
            }
            return false
        }
    }

    private func updateBombs(dt: Float) {
        for i in activeBombs.indices {
            activeBombs[i].fallSpeed += 15.0 * dt
            activeBombs[i].node.position.y -= activeBombs[i].fallSpeed * dt
            // Drift forward slightly with momentum
            activeBombs[i].node.position.z += playerSpeed * dt * 0.3

            let progress = 1.0 - (activeBombs[i].node.position.y - activeBombs[i].groundY) / (playerY - activeBombs[i].groundY)
            let shadowScale = 0.3 + max(0, min(1, progress)) * 0.7
            activeBombs[i].shadowNode.scale = SCNVector3(shadowScale, shadowScale, shadowScale)
            activeBombs[i].shadowNode.opacity = CGFloat(0.3 + max(0, min(1, progress)) * 0.4)

            if activeBombs[i].node.position.y <= activeBombs[i].groundY + 0.3 {
                handleBombImpact(bomb: activeBombs[i])
                activeBombs[i].node.removeFromParentNode()
                activeBombs[i].shadowNode.removeFromParentNode()
            }
        }
        activeBombs.removeAll { $0.node.parent == nil }
    }

    private func handleBombImpact(bomb: Bomb3D) {
        let pos = bomb.node.position
        let explosion = ModelGenerator3D.explosion(radius: bomb.blastRadius)
        explosion.position = SCNVector3(pos.x, bomb.groundY + 0.5, pos.z)
        scene.rootNode.addChildNode(explosion)

        // Damage nearby ground enemies
        for i in enemies.indices {
            guard enemies[i].type.isGround && enemies[i].node.parent != nil else { continue }
            let ex = enemies[i].node.position
            let dist = sqrt(pow(ex.x - pos.x, 2) + pow(ex.z - pos.z, 2))
            if dist <= bomb.blastRadius * 1.5 {
                enemies[i].health -= bomb.damage
                if enemies[i].health <= 0 {
                    destroyEnemy(at: i)
                }
            }
        }
    }

    // MARK: - Enemies

    private func spawnEnemies(time: TimeInterval) {
        let manager = GameManager.shared

        // Ground enemies
        if time - lastGroundSpawn >= manager.groundSpawnInterval {
            lastGroundSpawn = time
            spawnGroundEnemy()
        }

        // Air enemies (after difficulty 2)
        if manager.difficultyLevel >= 2 && time - lastAirSpawn >= manager.airSpawnInterval {
            lastAirSpawn = time
            spawnAirEnemy()
        }
    }

    private func spawnGroundEnemy() {
        // SAM launchers appear after difficulty 3
        let types: [EnemyType]
        if GameManager.shared.difficultyLevel >= 3 {
            types = [.tank, .tank, .aaGun, .aaGun, .building, .samLauncher]
        } else {
            types = [.tank, .tank, .aaGun, .building]
        }
        let type = types.randomElement()!

        let node: SCNNode
        switch type {
        case .tank: node = ModelGenerator3D.tank()
        case .aaGun: node = ModelGenerator3D.aaGun()
        case .building: node = ModelGenerator3D.building()
        case .samLauncher: node = ModelGenerator3D.samLauncher()
        default: return
        }

        // Place on terrain ahead of player, near center X for visibility
        let x = Float.random(in: -12...12)
        let z = playerZ + 80 + Float.random(in: 0...40)
        let h = ModelGenerator3D.terrainHeight(x: x, z: z)

        // Only place on land
        guard h > 0.5 else { return }

        node.position = SCNVector3(x, h, z)
        scene.rootNode.addChildNode(node)

        let bonus = GameManager.shared.enemyHealthBonus
        enemies.append(Enemy3D(
            node: node,
            type: type,
            health: type.health + bonus,
            lastFireTime: -1,
            isAir: false
        ))
    }

    private func spawnAirEnemy() {
        let node = ModelGenerator3D.enemyPlane()
        let x = Float.random(in: -5...5)
        let z = playerZ + 90 + Float.random(in: 0...30)

        node.position = SCNVector3(x, playerY + Float.random(in: -3...3), z)
        scene.rootNode.addChildNode(node)

        enemies.append(Enemy3D(
            node: node,
            type: .fighter,
            health: EnemyType.fighter.health,
            lastFireTime: -1,
            isAir: true
        ))
    }

    private func updateEnemies(dt: Float, time: TimeInterval) {
        let removeThreshold = playerZ - 40

        for i in enemies.indices.reversed() {
            guard enemies[i].node.parent != nil else {
                enemies.remove(at: i)
                continue
            }

            // Remove enemies that have scrolled past
            if enemies[i].node.position.z < removeThreshold {
                enemies[i].node.removeFromParentNode()
                enemies.remove(at: i)
                continue
            }

            // Air enemies: fly toward player
            if enemies[i].isAir {
                enemies[i].node.position.z -= 8 * dt
                let sineOffset = sin(Float(time) * 2.0 + Float(i)) * 5 * dt
                enemies[i].node.position.y += sineOffset
            }

            // Fire at player — range-limited
            if enemies[i].lastFireTime < 0 {
                enemies[i].lastFireTime = time
            }

            // Distance check for firing range
            let dist = distance3D(enemies[i].node.position, playerNode.position)
            let range = enemies[i].type.fireRange
            guard range > 0 && dist <= range else { continue }

            // Fire intervals per type
            let fireInterval: TimeInterval
            switch enemies[i].type {
            case .tank:        fireInterval = 3.0
            case .aaGun:       fireInterval = 1.5
            case .samLauncher: fireInterval = 5.0
            case .fighter:     fireInterval = 2.5
            case .building:    continue
            }

            if time - enemies[i].lastFireTime >= fireInterval {
                enemies[i].lastFireTime = time
                if enemies[i].type == .samLauncher {
                    fireSAMMissile(from: enemies[i])
                } else {
                    fireEnemyBullet(from: enemies[i])
                }
            }
        }
    }

    private func fireEnemyBullet(from enemy: Enemy3D) {
        // Tanks, AA guns, and fighters fire bullets
        guard enemy.type == .tank || enemy.type == .aaGun || enemy.type == .fighter else { return }

        let bullet = ModelGenerator3D.enemyBullet()
        bullet.position = enemy.node.position

        // Aim at player with slight inaccuracy for fairness
        let jitterY = Float.random(in: -1.0...1.0)
        let jitterZ = Float.random(in: -0.5...0.5)

        let targetX = playerNode.position.x
        let targetY = playerNode.position.y + jitterY
        let targetZ = playerNode.position.z + jitterZ

        let dx = targetX - bullet.position.x
        let dy = targetY - bullet.position.y
        let dz = targetZ - bullet.position.z
        let dist = sqrt(dx * dx + dy * dy + dz * dz)
        guard dist > 1 else { return }

        // Tanks shoot slower, heavier shells; AA guns shoot faster
        let speed: Float = enemy.type == .tank ? 0.3 : 0.4

        let vx = (dx / dist) * speed
        let vy = (dy / dist) * speed
        let vz = (dz / dist) * speed

        scene.rootNode.addChildNode(bullet)
        enemyBullets.append(Bullet3D(node: bullet, velocity: SCNVector3(vx, vy, vz), damage: GameConfig.enemyBulletDamage))
    }

    private func fireSAMMissile(from enemy: Enemy3D) {
        let missile = ModelGenerator3D.samMissile()
        missile.position = enemy.node.position
        missile.position.y += 1.0 // launch from top of launcher

        // Initial velocity: upward at ~60° angle toward the player's Z direction
        let toPlayerZ = playerNode.position.z - enemy.node.position.z
        let launchAngle: Float = .pi / 3  // 60° upward
        let initialSpeed: Float = 0.35
        let vz = (toPlayerZ > 0 ? 1.0 : -1.0) * cos(launchAngle) * initialSpeed
        let vy = sin(launchAngle) * initialSpeed

        scene.rootNode.addChildNode(missile)
        activeSAMs.append(SAMMissile3D(
            node: missile,
            velocity: SCNVector3(0, vy, vz),
            damage: GameConfig.samMissileDamage,
            lifetime: 5.0,
            turnRate: 2.5
        ))
    }

    private func updateSAMMissiles(dt: Float) {
        for i in activeSAMs.indices.reversed() {
            activeSAMs[i].lifetime -= dt

            // Expired or hit the ground
            if activeSAMs[i].lifetime <= 0 || activeSAMs[i].node.position.y < 0 {
                let explosion = ModelGenerator3D.explosion(radius: 0.8)
                explosion.position = activeSAMs[i].node.position
                scene.rootNode.addChildNode(explosion)
                activeSAMs[i].node.removeFromParentNode()
                activeSAMs.remove(at: i)
                continue
            }

            // Too far from player — remove silently
            let dz = activeSAMs[i].node.position.z - playerZ
            if abs(dz) > 120 {
                activeSAMs[i].node.removeFromParentNode()
                activeSAMs.remove(at: i)
                continue
            }

            // Homing: steer toward player
            let target = playerNode.position
            let pos = activeSAMs[i].node.position
            let dx = target.x - pos.x
            let dy = target.y - pos.y
            let dzToTarget = target.z - pos.z
            let distToTarget = sqrt(dx * dx + dy * dy + dzToTarget * dzToTarget)

            if distToTarget > 0.5 {
                let speed: Float = 0.35
                let desiredX = dx / distToTarget * speed
                let desiredY = dy / distToTarget * speed
                let desiredZ = dzToTarget / distToTarget * speed

                let t = min(1.0, activeSAMs[i].turnRate * dt)
                activeSAMs[i].velocity.x += (desiredX - activeSAMs[i].velocity.x) * t
                activeSAMs[i].velocity.y += (desiredY - activeSAMs[i].velocity.y) * t
                activeSAMs[i].velocity.z += (desiredZ - activeSAMs[i].velocity.z) * t

                // Normalize to maintain constant speed
                let vx = activeSAMs[i].velocity.x
                let vy = activeSAMs[i].velocity.y
                let vz2 = activeSAMs[i].velocity.z
                let curSpeed = sqrt(vx * vx + vy * vy + vz2 * vz2)
                if curSpeed > 0.01 {
                    activeSAMs[i].velocity.x = vx / curSpeed * speed
                    activeSAMs[i].velocity.y = vy / curSpeed * speed
                    activeSAMs[i].velocity.z = vz2 / curSpeed * speed
                }
            }

            // Move
            activeSAMs[i].node.position.x += activeSAMs[i].velocity.x * dt * 60
            activeSAMs[i].node.position.y += activeSAMs[i].velocity.y * dt * 60
            activeSAMs[i].node.position.z += activeSAMs[i].velocity.z * dt * 60

            // Orient missile in direction of travel
            let vx = activeSAMs[i].velocity.x
            let vy = activeSAMs[i].velocity.y
            let vz2 = activeSAMs[i].velocity.z
            let hLen = sqrt(vx * vx + vz2 * vz2)
            activeSAMs[i].node.eulerAngles = SCNVector3(
                -atan2(vy, hLen),
                atan2(vx, vz2),
                0
            )
        }
    }

    private func destroyEnemy(at index: Int) {
        guard index < enemies.count else { return }
        let enemy = enemies[index]

        GameManager.shared.addScore(enemy.type.score)
        GameManager.shared.enemiesDestroyed += 1
        hud.updateScore(GameManager.shared.currentScore)

        let explosion = ModelGenerator3D.explosion(radius: 1.5)
        explosion.position = enemy.node.position
        scene.rootNode.addChildNode(explosion)

        enemy.node.removeFromParentNode()
    }

    // MARK: - Collisions

    private func checkCollisions() {
        // Player bullets vs enemies
        for bi in playerBullets.indices.reversed() {
            guard playerBullets[bi].node.parent != nil else { continue }
            for ei in enemies.indices.reversed() {
                guard enemies[ei].node.parent != nil else { continue }
                let dist = distance3D(playerBullets[bi].node.position, enemies[ei].node.position)
                let hitRadius: Float = enemies[ei].isAir ? 2.5 : 2.0
                if dist < hitRadius {
                    enemies[ei].health -= playerBullets[bi].damage
                    playerBullets[bi].node.removeFromParentNode()

                    let hit = ModelGenerator3D.explosion(radius: 0.5)
                    hit.position = enemies[ei].node.position
                    scene.rootNode.addChildNode(hit)

                    if enemies[ei].health <= 0 {
                        destroyEnemy(at: ei)
                    }
                    break
                }
            }
        }

        // Player bullets vs SAM missiles (shootable!)
        for bi in playerBullets.indices.reversed() {
            guard playerBullets[bi].node.parent != nil else { continue }
            for si in activeSAMs.indices.reversed() {
                let dist = distance3D(playerBullets[bi].node.position, activeSAMs[si].node.position)
                if dist < 1.5 {
                    let explosion = ModelGenerator3D.explosion(radius: 0.8)
                    explosion.position = activeSAMs[si].node.position
                    scene.rootNode.addChildNode(explosion)
                    playerBullets[bi].node.removeFromParentNode()
                    activeSAMs[si].node.removeFromParentNode()
                    activeSAMs.remove(at: si)
                    break
                }
            }
        }
        playerBullets.removeAll { $0.node.parent == nil }

        // Enemy bullets vs player
        if !isInvincible {
            for bi in enemyBullets.indices.reversed() {
                guard enemyBullets[bi].node.parent != nil else { continue }
                let dist = distance3D(enemyBullets[bi].node.position, playerNode.position)
                if dist < 2.5 {
                    playerHealth -= enemyBullets[bi].damage
                    enemyBullets[bi].node.removeFromParentNode()
                    takeDamageEffect()
                    break
                }
            }
        }
        enemyBullets.removeAll { $0.node.parent == nil }

        // SAM missiles vs player
        if !isInvincible {
            for si in activeSAMs.indices.reversed() {
                let dist = distance3D(activeSAMs[si].node.position, playerNode.position)
                if dist < 2.5 {
                    playerHealth -= activeSAMs[si].damage
                    let explosion = ModelGenerator3D.explosion(radius: 1.5)
                    explosion.position = activeSAMs[si].node.position
                    scene.rootNode.addChildNode(explosion)
                    activeSAMs[si].node.removeFromParentNode()
                    activeSAMs.remove(at: si)
                    takeDamageEffect()
                    break
                }
            }
        }

        // Enemy planes vs player
        if !isInvincible {
            for ei in enemies.indices.reversed() {
                guard enemies[ei].isAir && enemies[ei].node.parent != nil else { continue }
                let dist = distance3D(enemies[ei].node.position, playerNode.position)
                if dist < 3.0 {
                    playerHealth -= GameConfig.collisionDamage
                    enemies[ei].health = 0
                    destroyEnemy(at: ei)
                    takeDamageEffect()
                    break
                }
            }
        }
        enemies.removeAll { $0.node.parent == nil }
    }

    private func takeDamageEffect() {
        isInvincible = true
        invincibilityTimer = 0.6

        let flash = SCNAction.sequence([
            .fadeOpacity(to: 0.3, duration: 0.05),
            .fadeOpacity(to: 1.0, duration: 0.05)
        ])
        playerNode.runAction(.repeat(flash, count: 6))
    }

    private func distance3D(_ a: SCNVector3, _ b: SCNVector3) -> Float {
        let dx = a.x - b.x
        let dy = a.y - b.y
        let dz = a.z - b.z
        return sqrt(dx * dx + dy * dy + dz * dz)
    }

    // MARK: - Game Over

    private func gameOver() {
        guard gameState == .playing else { return }
        gameState = .gameOver

        GameManager.shared.endGame()

        let explosion = ModelGenerator3D.explosion(radius: 3.0)
        explosion.position = playerNode.position
        scene.rootNode.addChildNode(explosion)
        playerNode.removeFromParentNode()

        let manager = GameManager.shared
        let earnedGems = manager.currentScore / 100
        hud.showGameOver(
            score: manager.currentScore,
            highScore: manager.highScore,
            coins: manager.currentCoins,
            gems: earnedGems
        )
    }
}
