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
    private var maxAltitude: Float = 48.75
    private var desertHeightBoostApplied = false
    private var currentFlipRoll: Float = 0      // child roll offset, decays toward 0
    private var smoothPitch: Float = 0            // smoothed pitch euler
    private let playerRollNode = SCNNode()        // child node for roll
    private var lastFacingRight = true
    private var isInvincible = false
    private var shootCooldownTimer: TimeInterval = 0
    private var bombCooldownTimers: [TimeInterval] = []
    private var wasFiring = false   // track fire-button transitions for sound
    private var gunSpinUpTimer: TimeInterval = 0  // must hold fire 0.9s before bullets fly
    private let gunSpinUpDelay: TimeInterval = 0.9

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
    private let trajectoryNode = SCNNode()
    private let trajectorySamples = 18
    private let bombGravity: Float = 15.0

    // Cached trajectory material (avoid per-frame allocation)
    private let trajectoryMaterial: SCNMaterial = {
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor.white
        mat.emission.contents = UIColor(white: 1.0, alpha: 0.15)
        mat.lightingModel = .constant
        mat.isDoubleSided = true
        mat.writesToDepthBuffer = false
        mat.readsFromDepthBuffer = true
        mat.transparencyMode = .aOne
        mat.blendMode = .alpha
        return mat
    }()

    // SAM Missiles
    private var activeSAMs: [SAMMissile3D] = []

    // ECM Jammer state
    private var hasECM = false
    private var ecmActive = false
    private var ecmActiveTimer: TimeInterval = 0
    private let ecmDuration: TimeInterval = 5.5
    private var ecmCooldownTimer: TimeInterval = 0
    private let ecmCooldown: TimeInterval = 37.0
    private var ecmFlashTimer: TimeInterval = 0

    // Game state
    private var gameState: GameState = .playing
    private var lastUpdateTime: TimeInterval = 0
    private var invincibilityTimer: TimeInterval = 0

    // Equipped weapon cache
    private let equippedGun: WeaponInfo
    private let equippedGuns: [WeaponInfo]
    private let equippedBombs: [WeaponInfo]
    private var bombReady: [Bool]

    // Game mode
    let gameMode: GameMode
    private var isMissionMode: Bool {
        if case .mission = gameMode { return true }
        return false
    }
    private var missionEnemiesDestroyed: Int = 0
    private var missionEnemyTotal: Int = 0
    private var spawnedMissionIndices: Set<Int> = []
    private var triggeredPlaneIndices: Set<Int> = []
    private var missionVictoryTimer: Float = 0

    // Biome cycling (endless mode)
    private var currentBiome: TerrainBiome = .temperate
    private var biomeElapsedTime: TimeInterval = 0
    private var chunkBiomes: [Int: TerrainBiome] = [:]   // slot → biome it was generated with
    /// Biome schedule: (cumulativeTime, biome). After the fixed sequence, random biomes every 120s.
    private let biomeSchedule: [(TimeInterval, TerrainBiome)] = [
        (0,   .temperate),
        (90,  .desert),
        (190, .arctic),
        (310, .volcanic)
    ]
    private let randomBiomeInterval: TimeInterval = 120
    private let randomBiomeStartTime: TimeInterval = 430  // 310 + 120
    private var nextRandomBiome: TerrainBiome? = nil
    private var biomeTransitionAlpha: Float = 1.0  // 1.0 = fully transitioned

    // MARK: - Data Structs

    struct Enemy3D {
        let node: SCNNode
        let type: EnemyType
        var health: Int
        let maxHealth: Int
        var lastFireTime: TimeInterval
        let isAir: Bool
        let healthBarNode: SCNNode
    }

    struct Bullet3D {
        let node: SCNNode
        let velocity: SCNVector3
        let damage: Int
    }

    struct Bomb3D {
        let node: SCNNode
        let shadowNode: SCNNode
        var velocityY: Float   // full Y velocity (inherited + gravity)
        var velocityZ: Float   // Z velocity (inherited from plane)
        let damage: Int
        let blastRadius: Float
        var clusterCount: Int = 0  // >0 means this bomb splits into sub-bomblets mid-air
        var timeAlive: Float = 0   // elapsed time since drop (used for cluster split timing)
    }

    struct SAMMissile3D {
        let node: SCNNode
        var velocity: SCNVector3
        let damage: Int
        var lifetime: Float
        let turnRate: Float
        let speed: Float
        let tracking: Bool  // false = flies straight (B2 stealth evasion)
    }

    // MARK: - Init

    init(mode: GameMode = .infiniteBattle) {
        self.gameMode = mode
        if case .mission = mode { maxAltitude = 65.0 }

        let data = PlayerData.shared
        playerMaxHealth = data.maxHealth
        playerHealth = playerMaxHealth
        equippedGun = data.equippedGun
        equippedGuns = data.equippedGuns
        equippedBombs = data.equippedBombs
        bombReady = Array(repeating: true, count: data.equippedBombs.count)
        bombCooldownTimers = Array(repeating: 0, count: data.equippedBombs.count)

        // HUD
        let hudSize = UIScreen.main.bounds.size
        hud = GameHUD3D(size: hudSize)
        hud.scaleMode = .resizeFill

        // Player model (uses selected plane from hangar)
        playerNode = ModelGenerator3D.selectedPlayerPlane()

        // Water – large flat plane
        waterNode = ModelGenerator3D.waterPlane(width: 200, length: 600)

        // Check if player has ECM Jammer equipped
        hasECM = data.equippedSpecials.contains { $0.id == "ecm_jammer" }

        super.init()

        setupScene()
        GameManager.shared.resetSession()

        // Show ECM button if equipped
        if hasECM {
            hud.setupECMButton()
        }

        // Mission mode: set enemy total for win condition and setup mission HUD
        if case .mission(let mission) = mode {
            missionEnemyTotal = mission.enemies.count
            let allMissions = MissionLoader.loadAll()
            let currentIdx = allMissions.firstIndex(where: { $0.name == mission.name })
            let hasNext = currentIdx != nil && currentIdx! + 1 < allMissions.count
            hud.setupMissionHUD(missionName: mission.name, enemyTotal: missionEnemyTotal, hasNext: hasNext)
        }
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
        setupTrajectory()
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

        #if targetEnvironment(simulator)
        sun.castsShadow = false
        #else
        sun.castsShadow = true
        sun.shadowRadius = 3
        sun.shadowSampleCount = 4
        sun.shadowMapSize = CGSize(width: 2048, height: 2048)
        #endif

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

        // Environment lighting for PBR materials (USDZ models)
        scene.lightingEnvironment.contents = UIColor(red: 0.55, green: 0.78, blue: 0.95, alpha: 1.0)
        scene.lightingEnvironment.intensity = 1.5
    }

    private func setupWater() {
        let waterY: Float = -0.2
        waterNode.position = SCNVector3(0, waterY, 0)
        scene.rootNode.addChildNode(waterNode)
    }

    private func setupPlayer() {
        // Wrap model geometry in a roll node so barrel roll rotates
        // around the model's forward axis (Z), independent of heading/pitch
        for child in playerNode.childNodes {
            child.removeFromParentNode()
            playerRollNode.addChildNode(child)
        }
        playerNode.addChildNode(playerRollNode)

        playerNode.position = SCNVector3(0, playerY, playerZ)
        scene.rootNode.addChildNode(playerNode)
    }

    private func setupTrajectory() {
        trajectoryNode.renderingOrder = 100
        scene.rootNode.addChildNode(trajectoryNode)
    }

    private func updateTrajectory() {
        // Hide when plane is pointing more than 45° nose up
        let pitchUp = sin(playerAngle)
        let fadeStart = sin(Float(35.0) * .pi / 180.0)  // begin fade at 35°
        let fadeEnd = sin(Float(50.0) * .pi / 180.0)    // fully hidden at 50°
        let guideFade: Float
        if pitchUp <= fadeStart {
            guideFade = 1.0
        } else if pitchUp >= fadeEnd {
            guideFade = 0.0
        } else {
            guideFade = 1.0 - (pitchUp - fadeStart) / (fadeEnd - fadeStart)
        }
        trajectoryNode.opacity = CGFloat(guideFade * 0.2)

        if guideFade <= 0.001 {
            trajectoryNode.geometry = nil
            return
        }

        let speedMult = Float(PlayerData.shared.speedMultiplier)
        let fwdSpeed = playerSpeed * speedMult

        // Bomb inherits plane velocity, then gravity pulls it down
        let vz = cos(playerAngle) * fwdSpeed
        var simVY = sin(playerAngle) * fwdSpeed

        // Start the guide ahead of the plane nose, not at the center
        let noseOffset: Float = 4.0
        var simY = playerY + sin(playerAngle) * noseOffset
        var simZ = playerZ + cos(playerAngle) * noseOffset
        let simDt: Float = 1.0 / 30.0
        var simTime: Float = 0

        var points: [SCNVector3] = [SCNVector3(0, simY, simZ)]

        for _ in 0..<trajectorySamples {
            for _ in 0..<2 {
                simTime += simDt
                simVY -= bombGravity * simDt   // gravity pulls bomb down
                simY += simVY * simDt
                simZ += vz * simDt
            }

            let groundH = groundHeight(x: 0, z: simZ)
            let groundLevel = max(Float(0.1), groundH)

            if simY <= groundLevel {
                points.append(SCNVector3(0, groundLevel + 0.05, simZ))
                break
            }
            points.append(SCNVector3(0, simY, simZ))
        }

        trajectoryNode.geometry = buildTrajectoryRibbon(points: points)
    }

    private func buildTrajectoryRibbon(points: [SCNVector3]) -> SCNGeometry? {
        guard points.count >= 2 else { return nil }

        var vertices: [SCNVector3] = []
        var colors: [Float] = []
        var indices: [Int32] = []

        let maxWidth: Float = 0.21

        for i in 0..<points.count {
            let t = Float(i) / Float(points.count - 1)

            // Tangent direction (in Y-Z plane)
            let tanY: Float
            let tanZ: Float
            if i == 0 {
                tanY = points[1].y - points[0].y
                tanZ = points[1].z - points[0].z
            } else if i == points.count - 1 {
                tanY = points[i].y - points[i - 1].y
                tanZ = points[i].z - points[i - 1].z
            } else {
                tanY = points[i + 1].y - points[i - 1].y
                tanZ = points[i + 1].z - points[i - 1].z
            }

            let tanLen = sqrt(tanY * tanY + tanZ * tanZ)
            let normY: Float
            let normZ: Float
            if tanLen > 0.001 {
                // Perpendicular in Y-Z plane
                normY = -tanZ / tanLen
                normZ = tanY / tanLen
            } else {
                normY = 1; normZ = 0
            }

            // Taper: full width at start, narrow at end
            let width = maxWidth * (1.0 - t * 0.8)

            let p = points[i]
            vertices.append(SCNVector3(p.x, p.y + normY * width, p.z + normZ * width))
            vertices.append(SCNVector3(p.x, p.y - normY * width, p.z - normZ * width))

            // Vertex color: 0% at both ends (near plane & ground), peaks at middle
            let alpha = 0.15 * sin(t * .pi)
            colors.append(contentsOf: [1, 1, 1, alpha])
            colors.append(contentsOf: [1, 1, 1, alpha])
        }

        // Triangle strip as indexed triangles
        for i in 0..<(points.count - 1) {
            let base = Int32(i * 2)
            indices.append(contentsOf: [base, base + 1, base + 2, base + 2, base + 1, base + 3])
        }

        let vertexSource = SCNGeometrySource(vertices: vertices)
        let colorData = Data(bytes: colors, count: colors.count * MemoryLayout<Float>.size)
        let colorSource = SCNGeometrySource(
            data: colorData,
            semantic: .color,
            vectorCount: vertices.count,
            usesFloatComponents: true,
            componentsPerVector: 4,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<Float>.size * 4
        )

        let indexData = Data(bytes: indices, count: indices.count * MemoryLayout<Int32>.size)
        let element = SCNGeometryElement(
            data: indexData,
            primitiveType: .triangles,
            primitiveCount: indices.count / 3,
            bytesPerIndex: MemoryLayout<Int32>.size
        )

        let geometry = SCNGeometry(sources: [vertexSource, colorSource], elements: [element])
        geometry.materials = [trajectoryMaterial]

        return geometry
    }

    private func generateInitialTerrain() {
        manageTerrain()
    }

    // MARK: - Terrain Height Helper

    private func groundHeight(x: Float, z: Float) -> Float {
        if case .mission(let mission) = gameMode {
            return ModelGenerator3D.missionTerrainHeight(terrainData: mission.terrain, x: x, z: z)
        }
        return ModelGenerator3D.terrainHeight(x: x, z: z)
    }

    // MARK: - Terrain Management (Z-Strip, Bidirectional)

    private func slotForZ(_ z: Float) -> Int {
        return Int(floor(z / chunkDepth))
    }

    private func manageTerrain() {
        if case .mission(let mission) = gameMode {
            manageMissionTerrain(mission: mission)
            return
        }

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
                chunkBiomes.removeValue(forKey: slot)
            }
        }

        // Generate missing chunks with current biome
        for slot in minSlot...maxSlot where terrainChunks[slot] == nil {
            let zStart = Float(slot) * chunkDepth

            let chunk = ModelGenerator3D.createTerrainChunk(
                xStart: stripXStart, zStart: zStart, chunkSize: chunkDepth,
                biome: currentBiome
            )
            scene.rootNode.addChildNode(chunk)
            terrainChunks[slot] = chunk
            chunkBiomes[slot] = currentBiome

            let trees = ModelGenerator3D.scatterTrees(
                xStart: stripXStart, zStart: zStart, chunkSize: chunkDepth,
                biome: currentBiome
            )
            for tree in trees { scene.rootNode.addChildNode(tree) }
            treeChunks[slot] = trees
        }
    }

    private func manageMissionTerrain(mission: MissionData) {
        let currentSlot = slotForZ(playerZ)
        // Extend range so water chunks render before/after map
        let minSlot = currentSlot - chunksBehind - 10
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

        // Generate missing chunks — uses mission heightmap (water outside bounds)
        for slot in minSlot...maxSlot where terrainChunks[slot] == nil {
            let zStart = Float(slot) * chunkDepth

            let chunk = ModelGenerator3D.createMissionTerrainChunk(
                terrainData: mission.terrain, waterLevel: mission.waterLevel,
                xStart: stripXStart, zStart: zStart, chunkSize: chunkDepth
            )
            scene.rootNode.addChildNode(chunk)
            terrainChunks[slot] = chunk

            let trees = ModelGenerator3D.scatterMissionTrees(
                terrainData: mission.terrain,
                xStart: stripXStart, zStart: zStart, chunkSize: chunkDepth
            )
            for tree in trees { scene.rootNode.addChildNode(tree) }
            treeChunks[slot] = trees
        }
    }

    // MARK: - Biome Cycling (Endless Mode)

    private func biomeForTime(_ t: TimeInterval) -> TerrainBiome {
        // Fixed sequence: temperate → desert → arctic → volcanic
        if t < randomBiomeStartTime {
            var result: TerrainBiome = .temperate
            for (threshold, biome) in biomeSchedule {
                if t >= threshold { result = biome }
            }
            return result
        }
        // After fixed sequence: random biome every 120s
        // Use the elapsed time to determine which random slot we're in
        if let next = nextRandomBiome { return next }
        return .temperate
    }

    private func updateBiome(dt: TimeInterval) {
        guard case .infiniteBattle = gameMode else { return }

        biomeElapsedTime += dt
        let newBiome = biomeForTime(biomeElapsedTime)

        // Handle random biome cycling after the fixed schedule
        if biomeElapsedTime >= randomBiomeStartTime {
            let timeSinceRandom = biomeElapsedTime - randomBiomeStartTime
            let cycleIndex = Int(timeSinceRandom / randomBiomeInterval)
            // Check if we need to pick a new random biome
            let slotStart = randomBiomeStartTime + Double(cycleIndex) * randomBiomeInterval
            if nextRandomBiome == nil || (biomeElapsedTime >= slotStart && biomeElapsedTime < slotStart + dt * 2) {
                // Pick a new random biome (seed from cycle index for determinism)
                if nextRandomBiome == nil {
                    pickNextRandomBiome(cycleIndex: cycleIndex)
                }
                // Check if we moved to a new cycle
                let prevCycleIndex = Int((biomeElapsedTime - dt - randomBiomeStartTime) / randomBiomeInterval)
                if cycleIndex != prevCycleIndex && cycleIndex > 0 {
                    pickNextRandomBiome(cycleIndex: cycleIndex)
                }
            }
        }

        let resolvedBiome: TerrainBiome
        if biomeElapsedTime >= randomBiomeStartTime, let next = nextRandomBiome {
            resolvedBiome = next
        } else {
            resolvedBiome = newBiome
        }

        if resolvedBiome != currentBiome {
            currentBiome = resolvedBiome
            // Permanently raise ceiling by 12.5% on first desert entry
            if resolvedBiome == .desert && !desertHeightBoostApplied {
                desertHeightBoostApplied = true
                maxAltitude *= 1.125
            }
            updateAtmosphere(biome: currentBiome)
            // Force regeneration of chunks ahead so new biome appears
            regenerateChunksAhead()
        }
    }

    private func pickNextRandomBiome(cycleIndex: Int) {
        let allBiomes = TerrainBiome.allCases
        // Use cycle index as seed for deterministic randomness
        let idx = (cycleIndex * 7 + 3) % allBiomes.count
        var pick = allBiomes[idx]
        // Avoid repeating the same biome twice in a row
        if pick == currentBiome {
            pick = allBiomes[(idx + 1) % allBiomes.count]
        }
        nextRandomBiome = pick
    }

    private func regenerateChunksAhead() {
        let currentSlot = slotForZ(playerZ)
        let maxSlot = currentSlot + chunksAhead
        for slot in (currentSlot + 1)...maxSlot {
            // Remove and regenerate chunks ahead with new biome
            if let existing = terrainChunks[slot] {
                existing.removeFromParentNode()
                terrainChunks.removeValue(forKey: slot)
            }
            if let trees = treeChunks[slot] {
                for t in trees { t.removeFromParentNode() }
                treeChunks.removeValue(forKey: slot)
            }
            chunkBiomes.removeValue(forKey: slot)
        }
    }

    private func updateAtmosphere(biome: TerrainBiome) {
        let duration: TimeInterval = 3.0 // smooth 3-second transition

        SCNTransaction.begin()
        SCNTransaction.animationDuration = duration

        // Sky color
        scene.background.contents = biome.skyColor

        // Fog color
        scene.fogColor = biome.fogColor

        // Sun color
        sunNode.light?.color = biome.sunColor

        // Ambient light
        if let ambientNode = scene.rootNode.childNodes.first(where: { $0.light?.type == .ambient }) {
            ambientNode.light?.color = biome.ambientColor
        }

        // Environment lighting
        scene.lightingEnvironment.contents = biome.skyColor

        SCNTransaction.commit()

        // Water color transition
        updateWaterColor(biome: biome, duration: duration)
    }

    private func updateWaterColor(biome: TerrainBiome, duration: TimeInterval) {
        guard let material = waterNode.geometry?.firstMaterial else { return }

        SCNTransaction.begin()
        SCNTransaction.animationDuration = duration
        material.diffuse.contents = biome.waterColor
        SCNTransaction.commit()
    }

    // MARK: - Game Loop

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        // Consume all HUD input atomically to avoid races (#5, #32)
        let input = hud.consumeInputState()

        // Handle exit to menu (from pause menu or game over)
        if input.shouldExitToMenu {
            GunSoundManager.shared.stopFiringImmediate()
            wasFiring = false
            gunSpinUpTimer = 0
            DispatchQueue.main.async {
                NavigationManager.shared.isInGame = false
            }
            return
        }

        // Handle pause — also pause SCNActions so animations freeze
        if input.isGamePaused {
            if !scene.isPaused {
                scene.isPaused = true
                GunSoundManager.shared.stopFiringImmediate()
                wasFiring = false
                gunSpinUpTimer = 0
            }
            lastUpdateTime = 0 // Reset so dt doesn't spike on resume
            return
        } else if scene.isPaused {
            scene.isPaused = false
        }

        guard gameState == .playing || gameState == .missionVictory else {
            if input.shouldRestart {
                DispatchQueue.main.async {
                    NavigationManager.shared.isInGame = false
                }
            }
            if input.shouldRetryMission {
                DispatchQueue.main.async {
                    NavigationManager.shared.retryMission()
                }
            }
            if input.shouldNextMission {
                DispatchQueue.main.async {
                    NavigationManager.shared.nextMission()
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
            hud.updateBombIndicator(ready: equippedBombs.count, total: equippedBombs.count)
        }

        let floatDt = Float(dt)

        let isVictoryCruise = gameState == .missionVictory

        GameManager.shared.update(deltaTime: dt)

        // Update biome cycling (endless mode)
        updateBiome(dt: dt)

        // Update player — auto-fly straight during victory cruise
        if isVictoryCruise {
            updatePlayerAutoCruise(dt: floatDt)
        } else {
            updatePlayer(dt: floatDt)
        }

        // Update trajectory indicator
        if !isVictoryCruise {
            updateTrajectory()
        }

        // Update camera to track player from the side
        updateCamera(dt: floatDt)

        // Move water to follow player along Z
        waterNode.position = SCNVector3(0, -0.2, playerZ)

        // Terrain management
        manageTerrain()

        // Victory cruise — count down then show results
        if isVictoryCruise {
            missionVictoryTimer -= floatDt
            if missionVictoryTimer <= 0 {
                showMissionVictoryScreen()
            }
            return
        }

        // Spawn enemies
        spawnEnemies(time: time)

        // Fire when button is held (0.9s spin-up before bullets fly)
        if input.isFiring {
            if !wasFiring {
                GunSoundManager.shared.startFiring()
                wasFiring = true
                gunSpinUpTimer = 0
            }
            gunSpinUpTimer += dt
            if gunSpinUpTimer >= gunSpinUpDelay {
                fireGun()
            }
        } else if wasFiring {
            GunSoundManager.shared.stopFiring()
            wasFiring = false
            gunSpinUpTimer = 0
        }

        // Process staggered bullet spawns on the render thread (#1)
        processPendingBullets(time: time)

        // Drop bomb (already consumed from input snapshot, no race)
        if input.shouldDropBomb {
            dropBomb()
        }

        // ECM Jammer activation
        if input.shouldActivateECM && hasECM && !ecmActive && ecmCooldownTimer <= 0 {
            activateECM()
        }

        // Update ECM state
        updateECM(dt: dt)

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

        // Weapon cooldown timers
        if shootCooldownTimer > 0 {
            shootCooldownTimer -= dt
        }
        for si in bombCooldownTimers.indices {
            if bombCooldownTimers[si] > 0 {
                bombCooldownTimers[si] -= dt
                if bombCooldownTimers[si] <= 0 {
                    bombCooldownTimers[si] = 0
                    bombReady[si] = true
                    let readyCount = bombReady.filter({ $0 }).count
                    hud.updateBombIndicator(ready: readyCount, total: equippedBombs.count)
                }
            }
        }

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
        let groundH = groundHeight(x: 0, z: playerZ)
        let groundMin = max(minAltitude, groundH + 1.5)
        if playerY < groundMin {
            playerY = groundMin
            if playerAngle < -0.1 { playerAngle = 0.1 }
        }
        playerY = min(maxAltitude, playerY)

        // Update node position
        playerNode.position = SCNVector3(0, playerY, playerZ)

        // --- Visual rotation: 180° half-roll on direction change ---
        //
        // At the crossing point (90°/270°), heading=0+roll=0 and heading=π+roll=π
        // produce the IDENTICAL orientation. So on every direction change we:
        //   1. Snap heading to the new value immediately
        //   2. Add π to currentFlipRoll to compensate (snap is invisible)
        //   3. Smoothly decay currentFlipRoll toward 0 — this IS the visible roll
        //
        let facingRight = cos(playerAngle) >= 0

        if facingRight != lastFacingRight {
            lastFacingRight = facingRight
            // Compensating roll: pick the sign that minimizes remaining animation
            if abs(currentFlipRoll) < 0.01 {
                currentFlipRoll = .pi           // fresh flip
            } else if currentFlipRoll > 0 {
                currentFlipRoll -= .pi          // partially rolled +ve → bring closer to 0
            } else {
                currentFlipRoll += .pi          // partially rolled -ve → bring closer to 0
            }
        }

        // Smoothly decay roll toward 0
        currentFlipRoll *= max(0, 1.0 - 7.0 * dt)
        if abs(currentFlipRoll) < 0.001 { currentFlipRoll = 0 }

        // Pitch: smoothly interpolate
        let targetPitch: Float
        if facingRight {
            targetPitch = -playerAngle
        } else {
            targetPitch = -atan2(sin(playerAngle), -cos(playerAngle))
        }
        do {
            var diff = targetPitch - smoothPitch
            while diff > .pi  { diff -= 2 * .pi }
            while diff < -.pi { diff += 2 * .pi }
            smoothPitch += diff * min(1.0, 8.0 * dt)
        }

        // Apply: heading set directly each frame, roll on child node
        let headingY: Float = facingRight ? 0 : .pi
        playerNode.eulerAngles = SCNVector3(smoothPitch, headingY, 0)
        playerRollNode.eulerAngles = SCNVector3(0, 0, currentFlipRoll)
    }

    /// Auto-fly the plane straight ahead during victory cruise (no player input).
    /// Gently levels out toward horizontal if diving/climbing.
    private func updatePlayerAutoCruise(dt: Float) {
        let speedMult = Float(PlayerData.shared.speedMultiplier)

        // Gently level out toward 0° (horizontal flight)
        let levelRate: Float = 1.5
        var diff = -playerAngle  // target is 0
        while diff > .pi { diff -= 2 * .pi }
        while diff < -.pi { diff += 2 * .pi }
        playerAngle += diff * min(1.0, levelRate * dt)

        // Move forward
        let speed = playerSpeed * speedMult
        playerZ += cos(playerAngle) * speed * dt
        playerY += sin(playerAngle) * speed * dt

        // Altitude clamping (same as normal play)
        let groundH = groundHeight(x: 0, z: playerZ)
        let groundMin = max(minAltitude, groundH + 1.5)
        if playerY < groundMin {
            playerY = groundMin
            if playerAngle < -0.1 { playerAngle = 0.1 }
        }
        playerY = min(maxAltitude, playerY)

        playerNode.position = SCNVector3(0, playerY, playerZ)

        // Reuse existing visual rotation logic
        let facingRight = cos(playerAngle) >= 0
        if facingRight != lastFacingRight {
            lastFacingRight = facingRight
            if abs(currentFlipRoll) < 0.01 {
                currentFlipRoll = .pi
            } else if currentFlipRoll > 0 {
                currentFlipRoll -= .pi
            } else {
                currentFlipRoll += .pi
            }
        }
        currentFlipRoll *= max(0, 1.0 - 7.0 * dt)
        if abs(currentFlipRoll) < 0.001 { currentFlipRoll = 0 }

        let targetPitch: Float
        if facingRight {
            targetPitch = -playerAngle
        } else {
            targetPitch = -atan2(sin(playerAngle), -cos(playerAngle))
        }
        do {
            var pdiff = targetPitch - smoothPitch
            while pdiff > .pi  { pdiff -= 2 * .pi }
            while pdiff < -.pi { pdiff += 2 * .pi }
            smoothPitch += pdiff * min(1.0, 8.0 * dt)
        }
        let headingY: Float = facingRight ? 0 : .pi
        playerNode.eulerAngles = SCNVector3(smoothPitch, headingY, 0)
        playerRollNode.eulerAngles = SCNVector3(0, 0, currentFlipRoll)
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

    // Pending staggered gun fires (render-thread safe)
    private var pendingGunFires: [(gun: WeaponInfo, gunIndex: Int, fireAt: TimeInterval)] = []

    private func fireGun() {
        guard shootCooldownTimer <= 0 else { return }

        GameManager.shared.shotsFired += 1

        // Queue staggered fires on the render thread (no DispatchQueue.main needed)
        for (gunIndex, gun) in equippedGuns.enumerated() {
            let fireAt = lastUpdateTime + Double(gunIndex) * 0.1
            pendingGunFires.append((gun: gun, gunIndex: gunIndex, fireAt: fireAt))
        }

        // Use fastest fire rate among equipped guns
        let fastestFireRate = equippedGuns.map(\.fireRate).min() ?? equippedGun.fireRate
        shootCooldownTimer = fastestFireRate
    }

    /// Called from the render loop to process staggered bullet spawns on the render thread
    private func processPendingBullets(time: TimeInterval) {
        guard !pendingGunFires.isEmpty else { return }

        let speedMult = Float(PlayerData.shared.speedMultiplier)

        pendingGunFires.removeAll { entry in
            guard time >= entry.fireAt else { return false }

            let gun = entry.gun
            let gunIndex = entry.gunIndex
            let bulletCount = gun.bulletCount
            let spread = gun.bulletSpread
            let speed = Float(gun.projectileSpeed) / 60.0 * speedMult * 0.60

            let gunSpacing: Float = equippedGuns.count > 1 ? 0.8 : 0
            let xOffset = (Float(gunIndex) - Float(equippedGuns.count - 1) / 2.0) * gunSpacing

            for i in 0..<bulletCount {
                let bullet = ModelGenerator3D.playerBullet(weaponId: gun.id)

                let spawnOffset: Float = 1.5
                bullet.position = SCNVector3(
                    xOffset,
                    playerY + sin(playerAngle) * spawnOffset,
                    playerZ + cos(playerAngle) * spawnOffset
                )

                var angle = playerAngle
                if bulletCount > 1 {
                    let offset = Float(i) - Float(bulletCount - 1) / 2.0
                    angle += offset * Float(spread)
                } else if spread > 0 {
                    angle += Float.random(in: -Float(spread)...Float(spread))
                }
                let jitterDeg = Float.random(in: -3.0...3.0)
                angle += jitterDeg * .pi / 180.0

                let vz = cos(angle) * speed
                let vy = sin(angle) * speed

                bullet.eulerAngles.x = (.pi / 2) - angle

                scene.rootNode.addChildNode(bullet)
                playerBullets.append(Bullet3D(
                    node: bullet,
                    velocity: SCNVector3(0, vy, vz),
                    damage: gun.damage
                ))
            }

            return true // Remove processed entry
        }
    }

    // MARK: - Bombing

    private func dropBomb() {
        // Find first ready bomb slot
        guard let slotIndex = bombReady.firstIndex(of: true) else { return }
        bombReady[slotIndex] = false

        let bombWeapon = equippedBombs[slotIndex]

        GameManager.shared.bombsDropped += 1

        // Bomb inherits the plane's forward velocity
        let speedMult = Float(PlayerData.shared.speedMultiplier)
        let fwdSpeed = playerSpeed * speedMult
        let dropVZ = cos(playerAngle) * fwdSpeed

        // Bomb inherits the plane's full velocity vector, including upward
        // momentum when climbing. Real physics: a released object keeps moving
        // in the direction it was traveling — if the plane is climbing, the bomb
        // arcs upward before gravity curves it back down (parabolic trajectory).
        let dropVY = sin(playerAngle) * fwdSpeed

        let bomb = ModelGenerator3D.bomb3D(weaponId: bombWeapon.id)
        bomb.position = playerNode.position

        let shadow = ModelGenerator3D.bombShadow3D()
        let shadowZ = bomb.position.z
        let groundY = groundHeight(x: 0, z: shadowZ)
        shadow.position = SCNVector3(0, max(0.1, groundY + 0.1), shadowZ)
        shadow.scale = SCNVector3(0.3, 0.3, 0.3)

        // Orient bomb nose along velocity (-Y axis is nose)
        bomb.eulerAngles.x = atan2(-dropVZ, -dropVY)

        scene.rootNode.addChildNode(bomb)
        scene.rootNode.addChildNode(shadow)

        let clusterCount = bombWeapon.bulletCount > 1 ? bombWeapon.bulletCount : 0

        activeBombs.append(Bomb3D(
            node: bomb,
            shadowNode: shadow,
            velocityY: dropVY,
            velocityZ: dropVZ,
            damage: bombWeapon.damage,
            blastRadius: Float(bombWeapon.blastRadius) * 0.15,
            clusterCount: clusterCount
        ))

        // Per-slot cooldown (timer-based, updated on render thread)
        bombCooldownTimers[slotIndex] = bombWeapon.fireRate
        let readyCount = bombReady.filter({ $0 }).count
        hud.updateBombIndicator(ready: readyCount, total: equippedBombs.count)
    }

    // MARK: - Update Systems

    private func updateBullets(dt: Float) {
        // Player bullets
        playerBullets.removeAll { bullet in
            bullet.node.position.x += bullet.velocity.x * dt * 60
            bullet.node.position.y += bullet.velocity.y * dt * 60
            bullet.node.position.z += bullet.velocity.z * dt * 60

            let dz = bullet.node.position.z - playerZ
            if abs(dz) > 150 {
                bullet.node.removeFromParentNode()
                return true
            }
            // Terrain collision — bullets can't pass through ground
            let terrainY = groundHeight(x: 0, z: bullet.node.position.z)
            if bullet.node.position.y <= terrainY {
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
            if abs(dz) > 100 || bullet.node.position.y > 30 {
                bullet.node.removeFromParentNode()
                return true
            }
            // Terrain collision — enemy bullets also blocked by ground
            let terrainY = groundHeight(x: 0, z: bullet.node.position.z)
            if bullet.node.position.y <= terrainY {
                bullet.node.removeFromParentNode()
                return true
            }
            return false
        }
    }

    private func updateBombs(dt: Float) {
        var newBomblets: [Bomb3D] = []

        for i in activeBombs.indices {
            // Track time alive for cluster split timing
            activeBombs[i].timeAlive += dt

            // Apply gravity to vertical velocity
            activeBombs[i].velocityY -= bombGravity * dt

            // Full momentum inheritance — bomb keeps the plane's velocity vector
            // and gravity naturally curves it into a parabolic arc
            activeBombs[i].node.position.y += activeBombs[i].velocityY * dt
            activeBombs[i].node.position.z += activeBombs[i].velocityZ * dt

            // Rotate bomb nose to follow velocity direction
            activeBombs[i].node.eulerAngles.x = atan2(-activeBombs[i].velocityZ, -activeBombs[i].velocityY)

            // Update shadow to track directly below the bomb
            let bombPos = activeBombs[i].node.position
            let groundH = groundHeight(x: 0, z: bombPos.z)
            let groundLevel = max(Float(0.1), groundH)
            activeBombs[i].shadowNode.position = SCNVector3(0, groundLevel + 0.1, bombPos.z)

            let heightAbove = bombPos.y - groundLevel
            let totalDrop = max(Float(1.0), playerY - groundLevel)
            let progress = 1.0 - heightAbove / totalDrop
            let clamped = max(Float(0), min(Float(1), progress))
            let shadowScale: Float = 0.3 + clamped * 0.7
            activeBombs[i].shadowNode.scale = SCNVector3(shadowScale, shadowScale, shadowScale)
            activeBombs[i].shadowNode.opacity = CGFloat(0.3 + clamped * 0.4)

            // Cluster warhead: split mid-air after 1.4s OR just before ground impact
            let isCluster = activeBombs[i].clusterCount > 0
            let clusterTimerFired = isCluster && activeBombs[i].timeAlive >= 1.0
            let clusterAboutToHitGround = isCluster && bombPos.y <= groundLevel + 2.0
            if clusterTimerFired || clusterAboutToHitGround {
                let bomblets = spawnClusterBomblets(from: activeBombs[i])
                newBomblets.append(contentsOf: bomblets)
                activeBombs[i].node.removeFromParentNode()
                activeBombs[i].shadowNode.removeFromParentNode()
                continue
            }

            // Remove on ground hit or if too far from player
            let dz = bombPos.z - playerZ
            if bombPos.y <= groundLevel + 0.3 {
                handleBombImpact(bomb: activeBombs[i])
                activeBombs[i].node.removeFromParentNode()
                activeBombs[i].shadowNode.removeFromParentNode()
            } else if abs(dz) > 150 || bombPos.y > maxAltitude + 20 {
                activeBombs[i].node.removeFromParentNode()
                activeBombs[i].shadowNode.removeFromParentNode()
            }
        }
        activeBombs.removeAll { $0.node.parent == nil }
        activeBombs.append(contentsOf: newBomblets)
    }

    /// Splits a cluster warhead into 8 tiny dot bomblets scattered radially,
    /// simulating a real cluster munition canister opening mid-air.
    private func spawnClusterBomblets(from bomb: Bomb3D) -> [Bomb3D] {
        let pos = bomb.node.position
        let groundY = max(Float(0.1), groundHeight(x: 0, z: pos.z))
        var bomblets: [Bomb3D] = []

        // Small puff at split point
        let puff = ModelGenerator3D.explosion(radius: bomb.blastRadius * 0.3)
        puff.position = pos
        scene.rootNode.addChildNode(puff)

        let count = bomb.clusterCount
        for i in 0..<count {
            // Scatter radially in a full circle (like canister spinning open)
            let angle = Float(i) / Float(count) * Float.pi * 2.0
            let spreadZ = sin(angle) * Float.random(in: 4.0...7.0)
            let spreadX = cos(angle) * Float.random(in: 0.5...1.5) // slight lateral for visual variety
            // Bomblets inherit parent's downward velocity + small random scatter upward
            let popY = bomb.velocityY * 0.3 + Float.random(in: -1.0...2.0)

            let bomblet = ModelGenerator3D.clusterBomblet3D()
            bomblet.position = SCNVector3(pos.x + spreadX * 0.2, pos.y, pos.z)

            let shadow = ModelGenerator3D.bombShadow3D()
            shadow.position = SCNVector3(0, groundY + 0.1, pos.z)
            shadow.scale = SCNVector3(0.15, 0.15, 0.15)

            scene.rootNode.addChildNode(bomblet)
            scene.rootNode.addChildNode(shadow)

            bomblets.append(Bomb3D(
                node: bomblet,
                shadowNode: shadow,
                velocityY: popY,
                velocityZ: bomb.velocityZ * 0.5 + spreadZ,
                damage: bomb.damage,
                blastRadius: bomb.blastRadius * 0.5
            ))
        }
        return bomblets
    }

    private func handleBombImpact(bomb: Bomb3D) {
        let pos = bomb.node.position
        let groundY = max(Float(0.1), groundHeight(x: pos.x, z: pos.z))

        let explosion = ModelGenerator3D.explosion(radius: bomb.blastRadius)
        explosion.position = SCNVector3(pos.x, groundY + 0.5, pos.z)
        scene.rootNode.addChildNode(explosion)

        // Damage all nearby enemies (ground and air) – use Y-Z distance
        for i in enemies.indices {
            guard enemies[i].node.parent != nil else { continue }
            let dist = distanceYZ(enemies[i].node.position, pos)
            if dist <= bomb.blastRadius * 1.5 {
                enemies[i].health -= bomb.damage
                updateHealthBar(for: enemies[i])
                if enemies[i].health <= 0 {
                    destroyEnemy(at: i)
                }
            }
        }
    }

    // MARK: - Enemies

    private func spawnEnemies(time: TimeInterval) {
        if isMissionMode {
            spawnMissionEnemies()
            spawnMissionPlaneTriggers()
            return
        }

        let manager = GameManager.shared

        // Ground enemies — spawn count scales with difficulty
        if time - lastGroundSpawn >= manager.groundSpawnInterval {
            lastGroundSpawn = time
            for _ in 0..<manager.groundSpawnCount {
                spawnGroundEnemy()
            }
        }

        // Air enemies — biome-aware spawning
        if manager.shouldSpawnEnemyPlanes && time - lastAirSpawn >= manager.airSpawnInterval {
            lastAirSpawn = time
            spawnAirEnemyWave3D()
        }
    }

    private func spawnMissionEnemies() {
        guard case .mission(let mission) = gameMode else { return }
        let spawnAhead: Float = 90 // spawn enemies when player is this far away

        for (i, placement) in mission.enemies.enumerated() {
            guard !spawnedMissionIndices.contains(i) else { continue }
            // Spawn when player approaches
            guard placement.z - playerZ < spawnAhead else { continue }
            spawnedMissionIndices.insert(i)

            guard let type = EnemyType(rawValue: placement.type) else { continue }
            let node = modelForEnemyType(type)

            let y: Float
            if type.isGround {
                // Small offset to prevent clipping on slopes
                y = groundHeight(x: placement.x, z: placement.z) + 0.2
            } else {
                // Ensure air enemies stay above terrain
                let terrainH = groundHeight(x: placement.x, z: placement.z)
                y = max(placement.altitude ?? 15, terrainH + 5)
            }
            node.position = SCNVector3(placement.x, y, placement.z)
            scene.rootNode.addChildNode(node)

            let healthBar = ModelGenerator3D.healthBar()
            let barHeight: Float = type == .building ? 2.8 : (type == .radioTower ? 4.5 : 1.5)
            healthBar.position = SCNVector3(0, barHeight, 0)
            node.addChildNode(healthBar)

            enemies.append(Enemy3D(
                node: node,
                type: type,
                health: type.health,
                maxHealth: type.health,
                lastFireTime: -1,
                isAir: !type.isGround,
                healthBarNode: healthBar
            ))
        }
    }

    /// Spawn enemy planes when player reaches a trigger point placed in the map editor.
    /// Planes always appear off-screen ahead of the player at high altitude.
    private func spawnMissionPlaneTriggers() {
        guard case .mission(let mission) = gameMode,
              let triggers = mission.planeTriggers else { return }

        for (i, trigger) in triggers.enumerated() {
            guard !triggeredPlaneIndices.contains(i) else { continue }
            // Fire trigger when player reaches or passes the trigger Z
            guard playerZ >= trigger.z else { continue }
            triggeredPlaneIndices.insert(i)

            let type = EnemyType(rawValue: trigger.type) ?? .fighter
            let count = max(1, trigger.count)

            for j in 0..<count {
                let node = modelForEnemyType(type)

                // Spawn well ahead of the player (off-screen) with horizontal spread
                let spawnZ = playerZ + 100 + Float(j) * 15
                // Use trigger X as a hint for horizontal position, with some spread per group member
                let spawnX = trigger.x + Float(j) * 4 - Float(count - 1) * 2
                // Altitude: near player altitude, clamped above terrain
                let rawY = playerY + Float.random(in: -2...2)
                let terrainH = groundHeight(x: spawnX, z: spawnZ)
                let spawnY = max(rawY, terrainH + 5)

                node.position = SCNVector3(spawnX, spawnY, spawnZ)
                scene.rootNode.addChildNode(node)

                let hp = type.health
                let healthBar = ModelGenerator3D.healthBar()
                healthBar.position = SCNVector3(0, 1.2, 0)
                node.addChildNode(healthBar)

                enemies.append(Enemy3D(
                    node: node,
                    type: type,
                    health: hp,
                    maxHealth: hp,
                    lastFireTime: -1,
                    isAir: true,
                    healthBarNode: healthBar
                ))
            }
        }
    }

    private func modelForEnemyType(_ type: EnemyType) -> SCNNode {
        switch type {
        case .tank: return ModelGenerator3D.tank()
        case .aaGun: return ModelGenerator3D.aaGun()
        case .building: return ModelGenerator3D.building()
        case .samLauncher: return ModelGenerator3D.samLauncher()
        case .fighter: return ModelGenerator3D.enemyPlane()
        case .aiFighter: return ModelGenerator3D.enemyPlane() // reuse model, AI behavior in update
        case .truck: return ModelGenerator3D.truck()
        case .radioTower: return ModelGenerator3D.radioTower()
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

        let node = modelForEnemyType(type)

        // Place on terrain ahead of player, near center X for visibility
        let x = Float.random(in: -12...12)
        let z = playerZ + 80 + Float.random(in: 0...40)
        let h = groundHeight(x: x, z: z)

        // Only place on land
        guard h > 0.5 else { return }

        // Small offset above terrain to prevent clipping on slopes
        node.position = SCNVector3(x, h + 0.2, z)
        scene.rootNode.addChildNode(node)

        // Detection range ring for AA guns and SAM launchers
        if type == .aaGun || type == .samLauncher {
            let range = effectiveFireRange(for: type)
            let ring = SCNTorus(ringRadius: CGFloat(range), pipeRadius: 0.12)
            let mat = SCNMaterial()
            let color = type == .samLauncher
                ? UIColor(red: 1.0, green: 0.15, blue: 0.1, alpha: 1.0)
                : UIColor(red: 1.0, green: 0.6, blue: 0.1, alpha: 1.0)
            mat.diffuse.contents = color
            mat.emission.contents = color
            mat.lightingModel = .constant
            mat.isDoubleSided = true
            ring.firstMaterial = mat
            let ringNode = SCNNode(geometry: ring)
            // Stand the ring upright in the Y-Z plane (rotate 90° around Z)
            // so it shows the vertical detection sphere around the enemy
            ringNode.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
            ringNode.opacity = 0.07
            node.addChildNode(ringNode)
        }

        let bonus = GameManager.shared.enemyHealthBonus
        let totalHealth = type.health + bonus

        let healthBar = ModelGenerator3D.healthBar()
        // Position above the enemy (height varies by type)
        let barHeight: Float = type == .building ? 2.8 : 1.5
        healthBar.position = SCNVector3(0, barHeight, 0)
        node.addChildNode(healthBar)

        enemies.append(Enemy3D(
            node: node,
            type: type,
            health: totalHealth,
            maxHealth: totalHealth,
            lastFireTime: -1,
            isAir: false,
            healthBarNode: healthBar
        ))
    }

    private func spawnAirEnemy() {
        let node = ModelGenerator3D.enemyPlane()
        let x = Float.random(in: -5...5)
        let z = playerZ + 90 + Float.random(in: 0...30)

        // Ensure air enemies never spawn below terrain
        let rawY = playerY + Float.random(in: -3...3)
        let terrainH = groundHeight(x: x, z: z)
        let y = max(rawY, terrainH + 5)
        node.position = SCNVector3(x, y, z)
        scene.rootNode.addChildNode(node)

        let bonus = GameManager.shared.enemyHealthBonus
        let hp = EnemyType.fighter.health + bonus
        let healthBar = ModelGenerator3D.healthBar()
        healthBar.position = SCNVector3(0, 1.2, 0)
        node.addChildNode(healthBar)

        enemies.append(Enemy3D(
            node: node,
            type: .fighter,
            health: hp,
            maxHealth: hp,
            lastFireTime: -1,
            isAir: true,
            healthBarNode: healthBar
        ))
    }

    private func spawnAirEnemyWave3D() {
        let manager = GameManager.shared
        let count = manager.airSpawnGroupSize
        let bonus = manager.enemyHealthBonus

        for i in 0..<count {
            let type: EnemyType
            if manager.allPlanesAreAI {
                type = .aiFighter
            } else if manager.shouldSpawnAIFighters {
                type = Int.random(in: 0...9) < 4 ? .aiFighter : .fighter
            } else {
                type = .fighter
            }

            let node = modelForEnemyType(type)
            let x = Float.random(in: -5...5) + Float(i) * 3 - Float(count - 1) * 1.5
            let z = playerZ + 90 + Float.random(in: 0...30) + Float(i) * 10

            let rawY = playerY + Float.random(in: -3...3)
            let terrainH = groundHeight(x: x, z: z)
            let y = max(rawY, terrainH + 5)
            node.position = SCNVector3(x, y, z)
            scene.rootNode.addChildNode(node)

            let hp = type.health + bonus
            let healthBar = ModelGenerator3D.healthBar()
            healthBar.position = SCNVector3(0, 1.2, 0)
            node.addChildNode(healthBar)

            enemies.append(Enemy3D(
                node: node,
                type: type,
                health: hp,
                maxHealth: hp,
                lastFireTime: -1,
                isAir: true,
                healthBarNode: healthBar
            ))
        }
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
                // Prevent flying through terrain
                let terrainH = groundHeight(x: enemies[i].node.position.x, z: enemies[i].node.position.z)
                if enemies[i].node.position.y < terrainH + 4 {
                    enemies[i].node.position.y = terrainH + 4
                }
            }

            // Fire at player — range-limited
            if enemies[i].lastFireTime < 0 {
                enemies[i].lastFireTime = time
            }

            // Distance check for firing range (use Y-Z; X is visual depth only)
            let dist = distanceYZ(enemies[i].node.position, playerNode.position)
            let range = effectiveFireRange(for: enemies[i].type)
            guard range > 0 && dist <= range else { continue }

            // Fire intervals per type, scaled by difficulty
            let baseFireInterval = enemies[i].type.fireRate
            guard baseFireInterval > 0 else { continue }
            let fireInterval = TimeInterval(Float(baseFireInterval) * GameManager.shared.fireRateMultiplier)

            if time - enemies[i].lastFireTime >= fireInterval {
                enemies[i].lastFireTime = time
                if enemies[i].type == .samLauncher {
                    // ECM active → block all new SAM missile launches
                    if !ecmActive {
                        fireSAMMissile(from: enemies[i])
                    }
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
        // Spawn at X=0 so bullet stays in the Y-Z gameplay plane
        // (enemies have visual X spread for the side camera but gameplay is Y-Z)
        bullet.position = SCNVector3(0, enemy.node.position.y, enemy.node.position.z)

        // Aim at player in Y-Z only — accuracy tightens with difficulty
        let mgr = GameManager.shared
        let jitterY = Float.random(in: -mgr.aaJitterY...mgr.aaJitterY)
        let jitterZ = Float.random(in: -mgr.aaJitterZ...mgr.aaJitterZ)

        let targetY = playerNode.position.y + jitterY
        let targetZ = playerNode.position.z + jitterZ

        let dy = targetY - bullet.position.y
        let dz = targetZ - bullet.position.z
        let dist = sqrt(dy * dy + dz * dz)
        guard dist > 1 else { return }

        // Base speed per type, scaled up with difficulty
        let baseSpeed: Float
        switch enemy.type {
        case .tank: baseSpeed = 0.3
        case .fighter: baseSpeed = 0.4 * 0.75
        default: baseSpeed = 0.4
        }
        let speed = baseSpeed * mgr.enemyBulletSpeedMultiplier

        let vy = (dy / dist) * speed
        let vz = (dz / dist) * speed

        // Orient tracer along its velocity direction in the Y-Z plane
        // SCNCylinder default axis is +Y, so rotate X by atan2(vz, vy)
        bullet.eulerAngles = SCNVector3(atan2(vz, vy), 0, 0)

        scene.rootNode.addChildNode(bullet)
        enemyBullets.append(Bullet3D(node: bullet, velocity: SCNVector3(0, vy, vz), damage: GameConfig.enemyBulletDamage))
    }

    private func fireSAMMissile(from enemy: Enemy3D) {
        let missile = ModelGenerator3D.samMissile()
        // Spawn at X=0 so missile stays in the Y-Z gameplay plane
        missile.position = SCNVector3(0, enemy.node.position.y + 1.0, enemy.node.position.z)

        // Initial velocity: upward at ~60° angle toward the player's Z direction
        let toPlayerZ = playerNode.position.z - enemy.node.position.z
        let launchAngle: Float = .pi / 3  // 60° upward

        // Endless mode: missiles get faster & more agile as difficulty climbs
        // Mission mode: static nerfed values
        let samSpeed: Float
        let samTurnRate: Float
        if case .infiniteBattle = gameMode {
            let diff = Float(GameManager.shared.difficultyLevel)
            // difficulty 3 (first SAMs): speed 0.14, turnRate 1.0
            // ramps up to max at ~difficulty 12+: speed 0.32, turnRate 2.8
            let t = min(1.0, (diff - 3.0) / 9.0)  // 0→1 over difficulties 3–12
            samSpeed = 0.14 + t * 0.18
            samTurnRate = 1.0 + t * 1.8
        } else {
            samSpeed = 0.14
            samTurnRate = 1.2
        }

        let vz = (toPlayerZ > 0 ? 1.0 : -1.0) * cos(launchAngle) * samSpeed
        let vy = sin(launchAngle) * samSpeed

        // B2 stealth: 60% chance SAM fires without tracking (linear trajectory)
        let isTracking: Bool
        if PlayerData.shared.selectedPlaneId == "B2" {
            isTracking = Float.random(in: 0...1) > 0.6
        } else {
            isTracking = true
        }

        scene.rootNode.addChildNode(missile)
        activeSAMs.append(SAMMissile3D(
            node: missile,
            velocity: SCNVector3(0, vy, vz),
            damage: GameConfig.samMissileDamage,
            lifetime: 6.0,
            turnRate: samTurnRate,
            speed: samSpeed,
            tracking: isTracking
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

            // Homing with lead-target prediction in Y-Z plane only (X=0 always)
            // ECM active or non-tracking (B2 stealth) → missiles fly straight (no homing)
            let pos = activeSAMs[i].node.position
            let speed = activeSAMs[i].speed

            if !ecmActive && activeSAMs[i].tracking {
                let missileSpeed = speed * 60.0  // world-units per second

                // Estimate player velocity from angle & speed
                let pVelY = sin(playerAngle) * playerSpeed
                let pVelZ = cos(playerAngle) * playerSpeed

                // Predict where player will be when missile arrives
                let rawDy = playerNode.position.y - pos.y
                let rawDz = playerNode.position.z - pos.z
                let rawDist = sqrt(rawDy * rawDy + rawDz * rawDz)
                let timeToIntercept = min(rawDist / max(missileSpeed, 1.0), 1.5)

                let predictedY = playerNode.position.y + pVelY * timeToIntercept
                let predictedZ = playerNode.position.z + pVelZ * timeToIntercept

                let dy = predictedY - pos.y
                let dzToTarget = predictedZ - pos.z
                let distToTarget = sqrt(dy * dy + dzToTarget * dzToTarget)

                if distToTarget > 0.5 {
                    let desiredY = dy / distToTarget * speed
                    let desiredZ = dzToTarget / distToTarget * speed

                    let t = min(1.0, activeSAMs[i].turnRate * dt)
                    activeSAMs[i].velocity.x = 0
                    activeSAMs[i].velocity.y += (desiredY - activeSAMs[i].velocity.y) * t
                    activeSAMs[i].velocity.z += (desiredZ - activeSAMs[i].velocity.z) * t

                    // Normalize to maintain constant speed
                    let vy = activeSAMs[i].velocity.y
                    let vz2 = activeSAMs[i].velocity.z
                    let curSpeed = sqrt(vy * vy + vz2 * vz2)
                    if curSpeed > 0.01 {
                        activeSAMs[i].velocity.x = 0
                        activeSAMs[i].velocity.y = vy / curSpeed * speed
                        activeSAMs[i].velocity.z = vz2 / curSpeed * speed
                    }
                }
            }

            // Move in Y-Z plane only
            activeSAMs[i].node.position.y += activeSAMs[i].velocity.y * dt * 60
            activeSAMs[i].node.position.z += activeSAMs[i].velocity.z * dt * 60

            // Orient missile to face direction of travel (pitch only, in Y-Z plane)
            // SCNCapsule default axis is +Y (nose at top), so rotate X by atan2(vz, vy)
            let vy = activeSAMs[i].velocity.y
            let vz2 = activeSAMs[i].velocity.z
            activeSAMs[i].node.eulerAngles = SCNVector3(atan2(vz2, vy), 0, 0)
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

        enemy.healthBarNode.removeFromParentNode()
        enemy.node.removeFromParentNode()

        if isMissionMode {
            missionEnemiesDestroyed += 1
            hud.updateEnemyCount(destroyed: missionEnemiesDestroyed, total: missionEnemyTotal)
            if missionEnemiesDestroyed >= missionEnemyTotal && missionEnemyTotal > 0 {
                missionComplete()
            }
        }
    }

    private func missionComplete() {
        guard gameState == .playing else { return }
        gameState = .missionVictory
        GunSoundManager.shared.stopFiringImmediate()
        wasFiring = false
        gunSpinUpTimer = 0
        missionVictoryTimer = 3.0

        // Record mission progress immediately
        let allMissions = MissionLoader.loadAll()
        if case .mission(let data) = gameMode,
           let idx = allMissions.firstIndex(where: { $0.name == data.name }) {
            MissionProgress.complete(levelIndex: idx)
        }

        // Hide combat HUD elements during cruise
        hud.hideControlsDuringVictory()
    }

    private func showMissionVictoryScreen() {
        gameState = .gameOver
        GameManager.shared.endGame()

        let manager = GameManager.shared
        hud.showMissionComplete(
            score: manager.currentScore,
            enemies: missionEnemiesDestroyed,
            coins: manager.currentCoins,
            gems: manager.currentScore / 100
        )
    }

    private func updateHealthBar(for enemy: Enemy3D) {
        let ratio = Float(enemy.health) / Float(max(1, enemy.maxHealth))
        let clamped = max(0, min(1, ratio))

        // Show on first damage
        if enemy.health < enemy.maxHealth {
            enemy.healthBarNode.isHidden = false
        }

        // Update fill bar scale and position
        if let fill = enemy.healthBarNode.childNode(withName: "healthBarFill", recursively: false) {
            fill.scale = SCNVector3(clamped, 1, 1)
            // Shift left so bar depletes from the right
            let barWidth: Float = 1.75
            fill.position = SCNVector3(-(1 - clamped) * barWidth / 2, 0, 0)

            // Color: green → yellow → red
            if let mat = (fill.geometry as? SCNPlane)?.firstMaterial {
                if ratio > 0.6 {
                    mat.diffuse.contents = UIColor(red: 0.2, green: 0.8, blue: 0.2, alpha: 1)
                } else if ratio > 0.3 {
                    mat.diffuse.contents = UIColor(red: 0.9, green: 0.7, blue: 0.1, alpha: 1)
                } else {
                    mat.diffuse.contents = UIColor(red: 0.9, green: 0.2, blue: 0.1, alpha: 1)
                }
            }
        }
    }

    // MARK: - ECM Jammer

    private func activateECM() {
        ecmActive = true
        ecmActiveTimer = ecmDuration
        ecmFlashTimer = 0
    }

    private func updateECM(dt: TimeInterval) {
        guard hasECM else { return }

        if ecmActive {
            ecmActiveTimer -= dt
            ecmFlashTimer -= dt

            // Spawn flashing white circles around the jet
            if ecmFlashTimer <= 0 {
                ecmFlashTimer = 0.12
                spawnECMFlash()
            }

            if ecmActiveTimer <= 0 {
                ecmActive = false
                ecmCooldownTimer = ecmCooldown
            }

            hud.updateECMButton(isActive: true, isReady: false, cooldownFraction: 0)
        } else if ecmCooldownTimer > 0 {
            ecmCooldownTimer -= dt
            if ecmCooldownTimer < 0 { ecmCooldownTimer = 0 }
            let fraction = CGFloat(1.0 - ecmCooldownTimer / ecmCooldown)
            hud.updateECMButton(isActive: false, isReady: false, cooldownFraction: fraction)
        } else {
            hud.updateECMButton(isActive: false, isReady: true, cooldownFraction: 1)
        }
    }

    private func spawnECMFlash() {
        let offset = SCNVector3(
            Float.random(in: -2.5...2.5),
            Float.random(in: -1.5...2.0),
            Float.random(in: -2.5...2.5)
        )
        let radius = CGFloat(Float.random(in: 0.6...1.4))
        let sphere = SCNSphere(radius: radius)
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor(white: 1.0, alpha: 0.5)
        mat.emission.contents = UIColor(white: 1.0, alpha: 0.5)
        mat.lightingModel = .constant
        mat.isDoubleSided = true
        mat.writesToDepthBuffer = false
        mat.transparencyMode = .aOne
        mat.blendMode = .add
        sphere.firstMaterial = mat

        let node = SCNNode(geometry: sphere)
        node.position = SCNVector3(
            playerNode.position.x + offset.x,
            playerNode.position.y + offset.y,
            playerNode.position.z + offset.z
        )
        scene.rootNode.addChildNode(node)

        // Fade out and remove
        let fadeOut = SCNAction.fadeOut(duration: 0.2)
        let remove = SCNAction.removeFromParentNode()
        node.runAction(.sequence([fadeOut, remove]))
    }

    // MARK: - Collisions

    private func checkCollisions() {
        // Player bullets vs enemies (use Y-Z distance; bullets travel at X=0
        // but enemies have visual X spread for the side-view camera)
        for bi in playerBullets.indices.reversed() {
            guard playerBullets[bi].node.parent != nil else { continue }
            for ei in enemies.indices.reversed() {
                guard enemies[ei].node.parent != nil else { continue }
                let dist = distanceYZ(playerBullets[bi].node.position, enemies[ei].node.position)
                let hitRadius: Float = enemies[ei].isAir ? 2.5 : 3.0
                if dist < hitRadius {
                    enemies[ei].health -= playerBullets[bi].damage
                    updateHealthBar(for: enemies[ei])
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
                let dist = distanceYZ(playerBullets[bi].node.position, activeSAMs[si].node.position)
                if dist < 2.5 {
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

        // Enemy bullets vs player (Y-Z distance since projectiles travel in gameplay plane)
        if !isInvincible {
            for bi in enemyBullets.indices.reversed() {
                guard enemyBullets[bi].node.parent != nil else { continue }
                let dist = distanceYZ(enemyBullets[bi].node.position, playerNode.position)
                if dist < 2.5 {
                    playerHealth -= enemyBullets[bi].damage
                    enemyBullets[bi].node.removeFromParentNode()
                    takeDamageEffect()
                    break
                }
            }
        }
        enemyBullets.removeAll { $0.node.parent == nil }

        // SAM missiles vs player (Y-Z distance since missiles travel in gameplay plane)
        if !isInvincible {
            for si in activeSAMs.indices.reversed() {
                let dist = distanceYZ(activeSAMs[si].node.position, playerNode.position)
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

    /// Fire range for an enemy, scaled up in endless mode based on distance traveled.
    /// At playerZ=0 the range is base; by playerZ=2000 it's +50% larger.
    private func effectiveFireRange(for type: EnemyType) -> Float {
        let base = type.fireRange
        guard case .infiniteBattle = gameMode else { return base }
        let progress = min(abs(playerZ) / 2000.0, 1.0)
        return base * (1.0 + progress * 0.5)
    }

    /// Distance ignoring X axis – used for hit detection in this side-view game
    /// where bullets travel in the Y-Z plane but enemies have visual X spread.
    private func distanceYZ(_ a: SCNVector3, _ b: SCNVector3) -> Float {
        let dy = a.y - b.y
        let dz = a.z - b.z
        return sqrt(dy * dy + dz * dz)
    }

    // MARK: - Game Over

    private func gameOver() {
        guard gameState == .playing else { return }
        gameState = .gameOver
        GunSoundManager.shared.stopFiringImmediate()
        wasFiring = false
        gunSpinUpTimer = 0

        GameManager.shared.endGame()

        let explosion = ModelGenerator3D.explosion(radius: 3.0)
        explosion.position = playerNode.position
        scene.rootNode.addChildNode(explosion)
        playerNode.removeFromParentNode()

        if isMissionMode {
            hud.showMissionFailed(
                score: GameManager.shared.currentScore,
                enemies: missionEnemiesDestroyed,
                total: missionEnemyTotal
            )
        } else {
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
}
