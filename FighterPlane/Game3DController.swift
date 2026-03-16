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
    private var burstShotCount = 0   // consecutive shots fired in current burst (for accuracy bloom)
    private var gunSoundLingerTimer: TimeInterval = 0  // keep gun sound playing briefly after release
    private let gunSoundLingerDuration: TimeInterval = 0.3

    // Water
    private let waterNode: SCNNode

    // Terrain – Z-strip chunks (slot-based for bidirectional generation)
    private var terrainChunks: [Int: SCNNode] = [:]       // slot → terrain node
    private var treeChunks: [Int: [SCNNode]] = [:]        // slot → tree nodes
    private var buildingChunks: [Int: [SCNNode]] = [:]   // slot → building nodes
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

    // AIM Rockets state
    private var hasAIM = false
    private let aimMissileCount = 2
    private var aimReady: [Bool] = [true, true]
    private var aimCooldownTimers: [TimeInterval] = [0, 0]
    private let aimReloadTime: TimeInterval = 17.0
    private var activeAIMRockets: [AIMRocket3D] = []

    // Game state
    private var gameState: GameState = .playing
    private var lastUpdateTime: TimeInterval = 0
    private var invincibilityTimer: TimeInterval = 0

    // Equipped weapon cache
    private let equippedGun: WeaponInfo?
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
    private var biomeBordersCrossed: Int = 0  // counts biome transitions starting from desert

    // MARK: - Data Structs

    struct Enemy3D {
        let node: SCNNode
        let type: EnemyType
        var health: Int
        let maxHealth: Int
        var lastFireTime: TimeInterval  // stagger at spawn to desync firing
        let isAir: Bool
        let healthBarNode: SCNNode
        // AI fighter chase fields (Y-Z plane: 0 = +Z forward, π/2 = +Y up)
        var aiHeading: Float = .pi   // initially flying toward -Z (toward the player)
        var aiSpeed: Float = 0
        var aiActivated: Bool = false
        var aiEvading: Bool = false          // true while in evasion maneuver
        var aiEvadeHeading: Float = 0        // direction to flee during evasion
        var aiEvadeTimer: Float = 0          // seconds remaining in current evasion
        var aiNextEvadeAt: Float = 0         // time (seconds since activation) to start next evasion
        var aiActiveTime: Float = 0          // seconds since activation
        var shotCount: Int = 0               // for audio throttling (play sound every other shot)
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

    struct AIMRocket3D {
        let node: SCNNode
        var velocity: SCNVector3
        let damage: Int
        var lifetime: Float
        let turnRate: Float
        let baseSpeed: Float           // 1.0x plane speed (per-frame unit)
        var speed: Float               // current speed (ramps from 1.0x to 1.5x)
        var flightTime: Float = 0      // seconds since launch (for acceleration)
        var targetNode: SCNNode?       // current homing target (enemy plane)
        var launchTimer: Float = 0.2   // time remaining attached under the plane
        var launched: Bool = false      // true once the 0.2s hold is over
        let blastRadius: Float = 6.0   // ground detonation radius (small bomb)
        var smokeTimer: Float = 0      // timer for spawning smoke trail puffs
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

        // Check if player has AIM Rockets equipped
        hasAIM = data.equippedSpecials.contains { $0.id == "aim_rockets" }

        super.init()

        setupScene()
        GameManager.shared.resetSession()

        // Pre-load sound effects
        SFXPlayer.shared.preload("aa_fire")
        SFXPlayer.shared.preload("sam_launch")
        SFXPlayer.shared.preload("aim_fire")
        EngineSoundManager.shared.startEngines()

        // Show ECM button if equipped
        if hasECM {
            hud.setupECMButton()
        }

        // Show AIM button if equipped
        if hasAIM {
            hud.setupAIMButton()
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
                if let blds = buildingChunks[slot] {
                    for b in blds { b.removeFromParentNode() }
                    buildingChunks.removeValue(forKey: slot)
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

            // Place editor-placed buildings in this chunk
            if let buildings = mission.objects.buildings {
                let blds = ModelGenerator3D.placeMissionBuildings(
                    buildings: buildings, terrainData: mission.terrain,
                    zStart: zStart, chunkSize: chunkDepth
                )
                for b in blds { scene.rootNode.addChildNode(b) }
                buildingChunks[slot] = blds
            }
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
            let previousBiome = currentBiome
            currentBiome = resolvedBiome
            // Permanently raise ceiling by 12.5% on first desert entry
            if resolvedBiome == .desert && !desertHeightBoostApplied {
                desertHeightBoostApplied = true
                maxAltitude *= 1.125
            }
            updateAtmosphere(biome: currentBiome)
            // Force regeneration of chunks ahead so new biome appears
            regenerateChunksAhead()

            // Spawn AI fighter escort at biome borders (desert onward, caps at 4)
            if previousBiome == .temperate || biomeBordersCrossed > 0 {
                biomeBordersCrossed += 1
                let count = min(biomeBordersCrossed, 4)
                spawnBorderAIFighters(count: count)
            }
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

        // Tint via multiply so the procedural water texture is preserved
        SCNTransaction.begin()
        SCNTransaction.animationDuration = duration
        material.multiply.contents = biome.waterColor
        SCNTransaction.commit()
    }

    // MARK: - Game Loop

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        // Consume all HUD input atomically to avoid races (#5, #32)
        let input = hud.consumeInputState()

        // Handle exit to menu (from pause menu or game over)
        if input.shouldExitToMenu {
            GunSoundManager.shared.stopFiringImmediate()
            EngineSoundManager.shared.stopAll()
            wasFiring = false
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
                EngineSoundManager.shared.pause()
                wasFiring = false
                }
            lastUpdateTime = 0 // Reset so dt doesn't spike on resume
            return
        } else if scene.isPaused {
            scene.isPaused = false
            EngineSoundManager.shared.resume()
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

        // Fire when button is held (only if a gun is equipped)
        if input.isFiring && !equippedGuns.isEmpty {
            if !wasFiring {
                GunSoundManager.shared.startFiring()
                wasFiring = true
            }
            gunSoundLingerTimer = gunSoundLingerDuration
            fireGun()
        } else if wasFiring {
            burstShotCount = 0
            gunSoundLingerTimer -= dt
            if gunSoundLingerTimer <= 0 {
                GunSoundManager.shared.stopFiring()
                wasFiring = false
            }
        }
        GunSoundManager.shared.updateFade(dt: dt)

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

        // AIM Rockets firing
        if input.shouldFireAIM && hasAIM {
            fireAIMRocket()
        }

        // Update ECM state
        updateECM(dt: dt)

        // Update bullets
        updateBullets(dt: floatDt)

        // Update bombs
        updateBombs(dt: floatDt)

        // Update SAM missiles
        updateSAMMissiles(dt: floatDt)

        // Update AIM rockets
        updateAIMRockets(dt: floatDt)

        // Update enemies
        updateEnemies(dt: floatDt, time: time)

        // Update off-screen enemy indicators (mission mode)
        updateOffscreenIndicators()

        // Update engine sounds (fade-in + enemy proximity volume)
        let closestFighterDist = enemies
            .filter { $0.isAir && $0.node.parent != nil }
            .map { distanceYZ($0.node.position, playerNode.position) }
            .min() ?? 999
        EngineSoundManager.shared.update(dt: floatDt, closestFighterDist: closestFighterDist)

        // Auto-complete mission when player flies past terrain into water zone
        if isMissionMode && gameState == .playing,
           case .mission(let mission) = gameMode {
            let terrainEndZ = mission.terrain.originZ + mission.terrain.lengthZ
            if playerZ > terrainEndZ {
                missionComplete()
            }
        }

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

        // AIM Rockets cooldown timers
        if hasAIM {
            for i in aimCooldownTimers.indices {
                if aimCooldownTimers[i] > 0 {
                    aimCooldownTimers[i] -= dt
                    if aimCooldownTimers[i] <= 0 {
                        aimCooldownTimers[i] = 0
                        aimReady[i] = true
                    }
                }
            }
            let readyCount = aimReady.filter({ $0 }).count
            hud.updateAIMButton(ready: readyCount, total: aimMissileCount)
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
    private var pendingGunFires: [(gun: WeaponInfo, gunIndex: Int, fireAt: TimeInterval, burstShot: Int)] = []

    private func fireGun() {
        guard shootCooldownTimer <= 0 else { return }

        GameManager.shared.shotsFired += 1
        burstShotCount += 1

        // Queue staggered fires on the render thread (no DispatchQueue.main needed)
        for (gunIndex, gun) in equippedGuns.enumerated() {
            let fireAt = lastUpdateTime + Double(gunIndex) * 0.1
            pendingGunFires.append((gun: gun, gunIndex: gunIndex, fireAt: fireAt, burstShot: burstShotCount))
        }

        // Use fastest fire rate among equipped guns
        let fastestFireRate = equippedGuns.map(\.fireRate).min() ?? equippedGun?.fireRate ?? 0.22
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
                // Accuracy bloom: first 2 shots are laser-accurate, then jitter ramps to a modest cap
                let accurateShots = 2
                let bloomPerShotDeg: Float = 0.5
                let maxBloomDeg: Float = 2.0
                let bloomDeg = min(maxBloomDeg, bloomPerShotDeg * Float(max(0, entry.burstShot - accurateShots)))
                let jitterDeg = Float.random(in: -bloomDeg...bloomDeg)
                angle += jitterDeg * .pi / 180.0

                let vz = cos(angle) * speed
                let vy = sin(angle) * speed

                bullet.eulerAngles.x = (.pi / 2) - angle

                let finalDamage = Int((Double(gun.damage) * PlayerData.shared.gunDamageMultiplier).rounded())

                scene.rootNode.addChildNode(bullet)
                playerBullets.append(Bullet3D(
                    node: bullet,
                    velocity: SCNVector3(0, vy, vz),
                    damage: finalDamage
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
            // Terrain collision — skip expensive groundHeight() for high-altitude bullets
            if bullet.node.position.y < 8 {
                let terrainY = groundHeight(x: 0, z: bullet.node.position.z)
                if bullet.node.position.y <= terrainY {
                    bullet.node.removeFromParentNode()
                    return true
                }
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
            // Terrain collision — skip expensive groundHeight() for high-altitude bullets
            if bullet.node.position.y < 8 {
                let terrainY = groundHeight(x: 0, z: bullet.node.position.z)
                if bullet.node.position.y <= terrainY {
                    bullet.node.removeFromParentNode()
                    return true
                }
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

    /// Water surface Y level — bombs hitting below this produce splash, not explosion.
    private let waterSurfaceY: Float = -0.2

    private func handleBombImpact(bomb: Bomb3D) {
        let pos = bomb.node.position
        let rawGroundH = groundHeight(x: pos.x, z: pos.z)

        // Water hit: terrain is below water surface → splash, no explosion, no damage
        if rawGroundH < waterSurfaceY + 0.1 {
            let splash = ModelGenerator3D.waterSplash(radius: bomb.blastRadius)
            splash.position = SCNVector3(pos.x, waterSurfaceY, pos.z)
            scene.rootNode.addChildNode(splash)
            return
        }

        let groundY = max(Float(0.1), rawGroundH)

        let explosion = ModelGenerator3D.explosion(radius: bomb.blastRadius)
        explosion.position = SCNVector3(pos.x, groundY + 0.5, pos.z)
        scene.rootNode.addChildNode(explosion)

        BombSoundManager.shared.playImpact()

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

            var enemy = Enemy3D(
                node: node,
                type: type,
                health: type.health,
                maxHealth: type.health,
                lastFireTime: CACurrentMediaTime() + Double.random(in: 0...0.5),
                isAir: !type.isGround,
                healthBarNode: healthBar
            )
            if type == .aiFighter {
                enemy.aiSpeed = 8.0
            }
            enemies.append(enemy)
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

                var enemy = Enemy3D(
                    node: node,
                    type: type,
                    health: hp,
                    maxHealth: hp,
                    lastFireTime: CACurrentMediaTime() + Double.random(in: 0...0.5),
                    isAir: true,
                    healthBarNode: healthBar
                )
                if type == .aiFighter {
                    enemy.aiSpeed = 8.0
                }
                enemies.append(enemy)
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

        // Place on terrain ahead of player, near center X so player can target them
        let x = Float.random(in: -6...6)
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
            lastFireTime: CACurrentMediaTime() + Double.random(in: 0...0.5),
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
            lastFireTime: CACurrentMediaTime() + Double.random(in: 0...0.5),
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

            var enemy = Enemy3D(
                node: node,
                type: type,
                health: hp,
                maxHealth: hp,
                lastFireTime: CACurrentMediaTime() + Double.random(in: 0...0.5),
                isAir: true,
                healthBarNode: healthBar
            )
            if type == .aiFighter {
                enemy.aiSpeed = 8.0  // faster than player (14.0)
            }
            enemies.append(enemy)
        }
    }

    /// Spawn AI fighters at a biome border. They appear spread across the player's path ahead.
    private func spawnBorderAIFighters(count: Int) {
        let bonus = GameManager.shared.enemyHealthBonus
        let spread: Float = 4.0  // horizontal spacing between planes

        for i in 0..<count {
            let node = modelForEnemyType(.aiFighter)
            // Spread evenly across the X axis, centered on the player
            let offsetX = Float(i) * spread - Float(count - 1) * spread / 2
            let x = playerNode.position.x + offsetX + Float.random(in: -1...1)
            let z = playerZ + 100 + Float(i) * 8
            let terrainH = groundHeight(x: x, z: z)
            let y = max(playerY + Float.random(in: -2...2), terrainH + 5)
            node.position = SCNVector3(x, y, z)
            scene.rootNode.addChildNode(node)

            let hp = EnemyType.aiFighter.health + bonus
            let healthBar = ModelGenerator3D.healthBar()
            healthBar.position = SCNVector3(0, 1.2, 0)
            node.addChildNode(healthBar)

            var enemy = Enemy3D(
                node: node,
                type: .aiFighter,
                health: hp,
                maxHealth: hp,
                lastFireTime: CACurrentMediaTime() + Double.random(in: 0...0.5),
                isAir: true,
                healthBarNode: healthBar
            )
            enemy.aiSpeed = 8.0
            enemies.append(enemy)
        }
    }

    private func updateEnemies(dt: Float, time: TimeInterval) {
        let removeThreshold = playerZ - 40

        for i in enemies.indices.reversed() {
            guard enemies[i].node.parent != nil else {
                enemies.remove(at: i)
                continue
            }

            // Remove enemies that have scrolled past — but activated AI fighters are immune
            if enemies[i].node.position.z < removeThreshold {
                if enemies[i].type == .aiFighter && enemies[i].aiActivated {
                    // AI fighter is chasing — don't remove. But despawn if way too far behind.
                    if enemies[i].node.position.z < playerZ - 150 {
                        enemies[i].node.removeFromParentNode()
                        enemies.remove(at: i)
                        continue
                    }
                } else if isMissionMode && enemies[i].type.isGround {
                    // Mission mode: keep ground enemies alive so player can backtrack.
                    // Only despawn if extremely far behind (200 units).
                    if enemies[i].node.position.z < playerZ - 200 {
                        enemies[i].node.removeFromParentNode()
                        enemies.remove(at: i)
                        continue
                    }
                    // Skip further processing (no firing from off-screen)
                    continue
                } else {
                    enemies[i].node.removeFromParentNode()
                    enemies.remove(at: i)
                    continue
                }
            }

            // --- AI fighter pursuit behavior ---
            if enemies[i].type == .aiFighter && enemies[i].isAir {
                updateAIFighter3D(index: i, dt: dt, time: time)
            } else if enemies[i].isAir {
                // Basic fighters: fly straight toward player
                enemies[i].node.position.z -= 8 * dt
                let sineOffset = sin(Float(time) * 2.0 + Float(i)) * 5 * dt
                enemies[i].node.position.y += sineOffset
                // Prevent flying through terrain
                let terrainH = groundHeight(x: enemies[i].node.position.x, z: enemies[i].node.position.z)
                if enemies[i].node.position.y < terrainH + 4 {
                    enemies[i].node.position.y = terrainH + 4
                }
            }

            // Fire at player — range-limited, skip if bullet cap reached
            guard enemyBullets.count < 40 else { continue }

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

    // MARK: - Off-Screen Enemy Indicators

    private func updateOffscreenIndicators() {
        guard isMissionMode else { return }

        // Camera geometry: side-view at X=-35, FOV 55°, landscape
        // Visible Z center ≈ where camera looks: smoothCamZ + smoothLeadZ
        // Visible half-width at X=0 ≈ 35 * tan(horizontalHalfFOV)
        // For 55° vertical FOV, ~2.16 aspect: horizontal half ≈ 46°, half-width ≈ 37
        let lookCenterZ = smoothCamZ + smoothLeadZ
        let visibleHalfZ: Float = 37
        let visibleMinZ = lookCenterZ - visibleHalfZ

        // Visible Y range: 35 * tan(27.5°) * 2 ≈ 36 units
        let visibleHalfY: Float = 18
        let camLookY = smoothCamY - 2  // camera looks at smoothCamY - 2
        let hudHeight = hud.size.height

        var indicators: [GameHUD3D.OffscreenIndicator] = []

        for enemy in enemies {
            // Only ground enemies, skip air
            guard enemy.type.isGround, enemy.node.parent != nil else { continue }

            let ez = enemy.node.position.z
            let ey = enemy.node.position.y

            // Only show indicator if enemy is off-screen to the left (behind camera view)
            guard ez < visibleMinZ else { continue }

            // Map enemy Y to screen Y
            let normalizedY = (ey - (camLookY - visibleHalfY)) / (visibleHalfY * 2)
            let screenY = CGFloat(normalizedY) * hudHeight

            // Compute angle from indicator toward enemy
            let deltaZ = ez - (smoothCamZ - visibleHalfZ) // always negative (behind)
            let deltaY = ey - (camLookY)
            let angle = CGFloat(atan2(deltaY, deltaZ))

            indicators.append(GameHUD3D.OffscreenIndicator(
                type: enemy.type,
                screenY: screenY,
                angle: angle
            ))
        }

        hud.updateOffscreenIndicators(indicators)
    }

    // MARK: - AI Fighter 3D Pursuit

    private func updateAIFighter3D(index i: Int, dt: Float, time: TimeInterval) {
        let pos = enemies[i].node.position
        let dy = playerY - pos.y
        let dz = playerZ - pos.z
        let dist = sqrt(dy * dy + dz * dz)

        // Activate when within 50 units or the fighter has passed the player
        if !enemies[i].aiActivated {
            if dist < 50 || pos.z < playerZ + 5 {
                enemies[i].aiActivated = true
                enemies[i].aiHeading = atan2(dy, dz)
                // Schedule first evasion 4-7 seconds after activation
                enemies[i].aiNextEvadeAt = Float.random(in: 4...7)
            } else {
                // Dormant: fly straight toward player (decreasing Z)
                enemies[i].node.position.z -= 8 * dt
                let sineOffset = sin(Float(time) * 2.0 + Float(i)) * 3 * dt
                enemies[i].node.position.y += sineOffset
                let terrainH = groundHeight(x: pos.x, z: enemies[i].node.position.z)
                if enemies[i].node.position.y < terrainH + 4 {
                    enemies[i].node.position.y = terrainH + 4
                }
                return
            }
        }

        enemies[i].aiActiveTime += dt

        // --- Evasion state machine ---
        if enemies[i].aiEvading {
            // Count down evasion timer
            enemies[i].aiEvadeTimer -= dt
            if enemies[i].aiEvadeTimer <= 0 {
                // Evasion over — re-engage
                enemies[i].aiEvading = false
                // Schedule next evasion 5-9 seconds from now
                enemies[i].aiNextEvadeAt = enemies[i].aiActiveTime + Float.random(in: 5...9)
            }
        } else if enemies[i].aiActiveTime >= enemies[i].aiNextEvadeAt && dist < 60 {
            // Start an evasion: pick a direction away from the player with some randomness
            enemies[i].aiEvading = true
            enemies[i].aiEvadeTimer = Float.random(in: 2.0...3.5)
            // Flee roughly away from the player, with random vertical offset
            let awayAngle = atan2(-dy, -dz) // opposite direction from player
            enemies[i].aiEvadeHeading = awayAngle + Float.random(in: -0.6...0.6)
        }

        // --- Steering ---
        let targetHeading: Float
        let turnSpeed: Float

        if enemies[i].aiEvading {
            // During evasion: steer toward escape heading, slightly faster turn to break away
            targetHeading = enemies[i].aiEvadeHeading
            turnSpeed = 2.0
        } else {
            // Normal pursuit: steer toward player with wider turn radius
            targetHeading = atan2(dy, dz)
            turnSpeed = 2.2  // rad/s
        }

        var diff = targetHeading - enemies[i].aiHeading
        while diff > .pi { diff -= 2 * .pi }
        while diff < -.pi { diff += 2 * .pi }
        let maxTurn = turnSpeed * dt
        if abs(diff) < maxTurn {
            enemies[i].aiHeading = targetHeading
        } else {
            enemies[i].aiHeading += diff > 0 ? maxTurn : -maxTurn
        }
        // Normalize
        while enemies[i].aiHeading > .pi { enemies[i].aiHeading -= 2 * .pi }
        while enemies[i].aiHeading < -.pi { enemies[i].aiHeading += 2 * .pi }

        // Move along heading
        let speed = enemies[i].aiSpeed
        enemies[i].node.position.z += cos(enemies[i].aiHeading) * speed * dt
        enemies[i].node.position.y += sin(enemies[i].aiHeading) * speed * dt

        // Converge X toward 0 (gameplay plane) so bullets can hit
        enemies[i].node.position.x *= (1.0 - 2.0 * dt)

        // Terrain avoidance: if dangerously close to ground, pull up
        let terrainH = groundHeight(x: enemies[i].node.position.x, z: enemies[i].node.position.z)
        let minClearance: Float = 4.0
        if enemies[i].node.position.y < terrainH + minClearance {
            enemies[i].node.position.y = terrainH + minClearance
            if enemies[i].aiHeading < 0 {
                enemies[i].aiHeading = max(enemies[i].aiHeading, 0.3)
            }
        }

        // Altitude ceiling
        enemies[i].node.position.y = min(enemies[i].node.position.y, maxAltitude - 2)

        // --- Visual orientation ---
        let vz = cos(enemies[i].aiHeading)
        let vy = sin(enemies[i].aiHeading)
        if vz >= 0 {
            let pitch = -atan2(vy, vz)
            enemies[i].node.eulerAngles = SCNVector3(pitch, 0, 0)
        } else {
            let backPitch = -atan2(vy, -vz)
            enemies[i].node.eulerAngles = SCNVector3(backPitch, Float.pi, 0)
        }

        // --- Machine gun firing (only when attacking, not evading) ---
        guard !enemies[i].aiEvading else { return }

        let fireDist = distanceYZ(enemies[i].node.position, playerNode.position)
        let fireRange: Float = 40.0
        guard fireDist <= fireRange else { return }

        // Check firing cone: only fire when roughly aimed at the player
        let firingCone: Float = 0.55  // ~31°
        let angleToPlayer = atan2(dy, dz)
        var aimDiff = angleToPlayer - enemies[i].aiHeading
        while aimDiff > .pi { aimDiff -= 2 * .pi }
        while aimDiff < -.pi { aimDiff += 2 * .pi }
        guard abs(aimDiff) < firingCone else { return }

        // Fire rate — cap total enemy bullets to prevent scene node explosion
        let maxEnemyBullets = 40
        guard enemyBullets.count < maxEnemyBullets else { return }

        let fireInterval = TimeInterval(Float(GameConfig.aiFighterFireRate) * GameManager.shared.fireRateMultiplier)
        if time - enemies[i].lastFireTime >= fireInterval {
            enemies[i].lastFireTime = time
            enemies[i].shotCount += 1
            fireAIFighterBullet(from: enemies[i])
        }
    }

    private func fireAIFighterBullet(from enemy: Enemy3D) {
        let bullet = ModelGenerator3D.aiFighterBullet()
        // Spawn at X=0 (gameplay plane), at enemy's Y-Z position
        bullet.position = SCNVector3(0, enemy.node.position.y, enemy.node.position.z)

        // Fire along the AI's heading with slight random spread
        let spread: Float = 0.08
        let fireAngle = enemy.aiHeading + Float.random(in: -spread...spread)

        let bulletSpeed: Float = 0.6  // units per frame-step (matches existing bullet velocity scale)
        let vy = sin(fireAngle) * bulletSpeed
        let vz = cos(fireAngle) * bulletSpeed

        // Orient tracer along its velocity direction in the Y-Z plane
        bullet.eulerAngles = SCNVector3(atan2(vz, vy), 0, 0)

        scene.rootNode.addChildNode(bullet)
        enemyBullets.append(Bullet3D(node: bullet, velocity: SCNVector3(0, vy, vz), damage: GameConfig.aiFighterBulletDamage))

        // Machine gun sound — play every other shot to reduce audio overhead
        if enemy.shotCount % 2 == 0 {
            let distToPlayer = distanceYZ(enemy.node.position, playerNode.position)
            let maxHearDist: Float = 80
            if distToPlayer < maxHearDist {
                let vol = Float(1.0 - distToPlayer / maxHearDist)
                SFXPlayer.shared.play("aa_fire", volume: vol * 0.15)
            }
        }
    }

    private func fireEnemyBullet(from enemy: Enemy3D) {
        // Tanks, AA guns, and fighters fire bullets
        guard enemy.type == .tank || enemy.type == .aaGun || enemy.type == .fighter else { return }

        // AA fire sound — volume falls off with distance, skip if far away
        let distToPlayer = abs(enemy.node.position.z - playerZ)
        let maxHearDist: Float = 50
        if distToPlayer < maxHearDist {
            let vol = Float(1.0 - distToPlayer / maxHearDist)
            SFXPlayer.shared.play("aa_fire", volume: vol * 0.25)
        }

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

        // Missile launch sound — volume falls off with distance
        let distToPlayer = abs(enemy.node.position.z - playerZ)
        let maxHearDist: Float = 100
        if distToPlayer < maxHearDist {
            let vol = Float(1.0 - distToPlayer / maxHearDist)
            SFXPlayer.shared.play("sam_launch", volume: vol * 0.3)
        }

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
        EngineSoundManager.shared.stopAll()
        wasFiring = false
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

    // MARK: - AIM Smoke Trail

    private func spawnAIMSmokeTrail(at position: SCNVector3, velocity: SCNVector3) {
        let mag = sqrt(velocity.y * velocity.y + velocity.z * velocity.z)
        guard mag > 0 else { return }

        // Tail offset: opposite to direction of travel, ~1.2 units behind
        let tailY = -velocity.y / mag * 1.2
        let tailZ = -velocity.z / mag * 1.2

        // Spawn 2 puffs per call for denser trail
        for _ in 0..<2 {
            let jitter = SCNVector3(
                Float.random(in: -0.3...0.3),
                Float.random(in: -0.3...0.3) + tailY,
                Float.random(in: -0.3...0.3) + tailZ
            )
            let radius = CGFloat(Float.random(in: 0.15...0.35))
            let sphere = SCNSphere(radius: radius)
            let mat = SCNMaterial()
            // Warm gray smoke with strong opacity
            let shade = CGFloat(Float.random(in: 0.55...0.72))
            mat.diffuse.contents = UIColor(red: shade, green: shade * 0.95, blue: shade * 0.88, alpha: 0.8)
            mat.emission.contents = UIColor(red: shade * 0.3, green: shade * 0.25, blue: shade * 0.2, alpha: 0.3)
            mat.lightingModel = .constant
            mat.isDoubleSided = true
            mat.writesToDepthBuffer = false
            mat.transparencyMode = .aOne
            mat.blendMode = .alpha
            sphere.firstMaterial = mat

            let node = SCNNode(geometry: sphere)
            node.position = SCNVector3(
                position.x + jitter.x,
                position.y + jitter.y,
                position.z + jitter.z
            )
            scene.rootNode.addChildNode(node)

            // Grow slightly and fade out
            let grow = SCNAction.scale(to: 1.6, duration: 0.35)
            let fadeOut = SCNAction.fadeOut(duration: 0.35)
            let group = SCNAction.group([grow, fadeOut])
            let remove = SCNAction.removeFromParentNode()
            node.runAction(.sequence([group, remove]))
        }
    }

    // MARK: - AIM Rockets

    private func fireAIMRocket() {
        // Find a ready missile slot
        guard let slotIndex = aimReady.firstIndex(where: { $0 }) else { return }

        // Find target enemy planes on screen
        let airEnemies = enemies.filter { $0.isAir && $0.node.parent != nil }

        // Separate AI fighters and regular fighters, prefer AI fighters
        let aiTargets = airEnemies.filter { $0.type == .aiFighter }
        let regularTargets = airEnemies.filter { $0.type == .fighter }

        // Build sorted target list: AI planes first, then regular planes, sorted by distance
        let sortedTargets = (aiTargets.sorted { distanceYZ($0.node.position, playerNode.position) < distanceYZ($1.node.position, playerNode.position) }
            + regularTargets.sorted { distanceYZ($0.node.position, playerNode.position) < distanceYZ($1.node.position, playerNode.position) })

        // Pick a target — try to avoid duplicating targets already being tracked
        var targetNode: SCNNode? = nil
        let alreadyTargeted = Set(activeAIMRockets.compactMap { $0.targetNode })
        for target in sortedTargets {
            if !alreadyTargeted.contains(target.node) {
                targetNode = target.node
                break
            }
        }
        // If all targets are already being tracked, just pick the closest
        if targetNode == nil && !sortedTargets.isEmpty {
            targetNode = sortedTargets[0].node
        }

        // Spawn the missile UNDER the plane, mirroring plane's pitch
        let missileNode = ModelGenerator3D.aimRocket()
        missileNode.position = SCNVector3(0, playerY - 1.5, playerZ)
        missileNode.eulerAngles = SCNVector3(-playerAngle, 0, 0)
        scene.rootNode.addChildNode(missileNode)

        // Base speed = plane speed; accelerates to 1.5x over 0.5s after launch
        let speedMult = Float(PlayerData.shared.speedMultiplier)
        let planeSpeed = playerSpeed * speedMult / 60.0  // per-frame unit

        let rocket = AIMRocket3D(
            node: missileNode,
            velocity: SCNVector3(0, 0, 0),  // set on launch after 0.2s hold
            damage: 7,
            lifetime: 8.0,
            turnRate: 3.5,
            baseSpeed: planeSpeed,
            speed: planeSpeed,
            targetNode: targetNode,
            launchTimer: 0.2,
            launched: false
        )
        activeAIMRockets.append(rocket)

        // Play launch sound
        SFXPlayer.shared.play("aim_fire", volume: 1.0)

        // Mark slot as reloading
        aimReady[slotIndex] = false
        aimCooldownTimers[slotIndex] = aimReloadTime
    }

    private func updateAIMRockets(dt: Float) {
        guard !activeAIMRockets.isEmpty else { return }

        for i in activeAIMRockets.indices.reversed() {
            // --- Pre-launch phase: attached under the plane for 0.2s ---
            if !activeAIMRockets[i].launched {
                activeAIMRockets[i].launchTimer -= dt
                // Follow the plane, stay underneath mirroring pitch
                activeAIMRockets[i].node.position = SCNVector3(0, playerY - 1.5, playerZ)
                activeAIMRockets[i].node.eulerAngles = SCNVector3(-.pi / 2 - playerAngle, 0, 0)

                if activeAIMRockets[i].launchTimer <= 0 {
                    // Launch! Set velocity based on plane's current pitch
                    activeAIMRockets[i].launched = true
                    let spd = activeAIMRockets[i].speed
                    let vy = sin(playerAngle) * spd
                    let vz = cos(playerAngle) * spd
                    activeAIMRockets[i].velocity = SCNVector3(0, vy, vz)
                }
                continue
            }

            // --- Post-launch phase ---
            activeAIMRockets[i].lifetime -= dt
            activeAIMRockets[i].flightTime += dt

            // Accelerate from 1.0x to 1.5x plane speed over 0.5s
            let accelProgress = min(activeAIMRockets[i].flightTime / 0.5, 1.0)
            activeAIMRockets[i].speed = activeAIMRockets[i].baseSpeed * (1.0 + 0.5 * accelProgress)

            // Remove expired or far-out-of-range rockets
            if activeAIMRockets[i].lifetime <= 0 ||
               abs(activeAIMRockets[i].node.position.z - playerZ) > 150 {
                activeAIMRockets[i].node.removeFromParentNode()
                activeAIMRockets.remove(at: i)
                continue
            }

            // Ground hit: detonate like a small bomb
            let rocketPos = activeAIMRockets[i].node.position
            let groundH = groundHeight(x: rocketPos.x, z: rocketPos.z)
            if rocketPos.y <= max(groundH, Float(0.1)) {
                let blastR = activeAIMRockets[i].blastRadius
                let explosion = ModelGenerator3D.explosion(radius: blastR)
                explosion.position = SCNVector3(rocketPos.x, max(groundH, Float(0.1)) + 0.5, rocketPos.z)
                scene.rootNode.addChildNode(explosion)

                // Damage nearby enemies within blast radius
                for ei in enemies.indices {
                    guard enemies[ei].node.parent != nil else { continue }
                    let dist = distanceYZ(enemies[ei].node.position, rocketPos)
                    if dist <= blastR * 1.5 {
                        enemies[ei].health -= activeAIMRockets[i].damage
                        updateHealthBar(for: enemies[ei])
                        if enemies[ei].health <= 0 {
                            destroyEnemy(at: ei)
                        }
                    }
                }

                activeAIMRockets[i].node.removeFromParentNode()
                activeAIMRockets.remove(at: i)
                continue
            }

            // Check if target was destroyed — explode at its last position
            if let target = activeAIMRockets[i].targetNode, target.parent == nil {
                let explosion = ModelGenerator3D.explosion(radius: 1.2)
                explosion.position = activeAIMRockets[i].node.position
                scene.rootNode.addChildNode(explosion)
                activeAIMRockets[i].node.removeFromParentNode()
                activeAIMRockets.remove(at: i)
                continue
            }

            // Homing toward target
            if let target = activeAIMRockets[i].targetNode {
                let pos = activeAIMRockets[i].node.position
                let tgt = target.position
                let dy = tgt.y - pos.y
                let dz = tgt.z - pos.z

                let distToTarget = sqrt(dy * dy + dz * dz)
                if distToTarget > 0.1 {
                    let spd = activeAIMRockets[i].speed
                    let desiredVY = dy / distToTarget * spd
                    let desiredVZ = dz / distToTarget * spd

                    let rate = activeAIMRockets[i].turnRate * dt
                    var vy = activeAIMRockets[i].velocity.y + (desiredVY - activeAIMRockets[i].velocity.y) * rate
                    var vz = activeAIMRockets[i].velocity.z + (desiredVZ - activeAIMRockets[i].velocity.z) * rate

                    let mag = sqrt(vy * vy + vz * vz)
                    if mag > 0 {
                        vy = vy / mag * spd
                        vz = vz / mag * spd
                    }
                    activeAIMRockets[i].velocity = SCNVector3(0, vy, vz)
                }
            }
            // If no target, re-normalize velocity to current (accelerating) speed
            if activeAIMRockets[i].targetNode == nil {
                let curV = activeAIMRockets[i].velocity
                let mag = sqrt(curV.y * curV.y + curV.z * curV.z)
                if mag > 0 {
                    let spd = activeAIMRockets[i].speed
                    activeAIMRockets[i].velocity = SCNVector3(0, curV.y / mag * spd, curV.z / mag * spd)
                }
            }

            // Move
            let v = activeAIMRockets[i].velocity
            activeAIMRockets[i].node.position.y += v.y * dt * 60
            activeAIMRockets[i].node.position.z += v.z * dt * 60

            // Orient missile to face direction of travel (rotated 90° to be parallel nose-to-tail)
            let pitch = atan2(v.y, v.z)
            activeAIMRockets[i].node.eulerAngles = SCNVector3(-.pi / 2 - pitch, 0, 0)

            // Spawn smoke trail puffs
            activeAIMRockets[i].smokeTimer -= dt
            if activeAIMRockets[i].smokeTimer <= 0 {
                activeAIMRockets[i].smokeTimer = 0.06
                spawnAIMSmokeTrail(at: activeAIMRockets[i].node.position, velocity: v)
            }
        }
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

        // AIM rockets vs enemies (air targets)
        for ri in activeAIMRockets.indices.reversed() {
            guard activeAIMRockets[ri].node.parent != nil else { continue }
            for ei in enemies.indices.reversed() {
                guard enemies[ei].node.parent != nil else { continue }
                let dist = distanceYZ(activeAIMRockets[ri].node.position, enemies[ei].node.position)
                let hitRadius: Float = enemies[ei].isAir ? 2.5 : 3.0
                if dist < hitRadius {
                    enemies[ei].health -= activeAIMRockets[ri].damage
                    updateHealthBar(for: enemies[ei])

                    let explosion = ModelGenerator3D.explosion(radius: 1.2)
                    explosion.position = enemies[ei].node.position
                    scene.rootNode.addChildNode(explosion)

                    activeAIMRockets[ri].node.removeFromParentNode()
                    activeAIMRockets.remove(at: ri)

                    if enemies[ei].health <= 0 {
                        destroyEnemy(at: ei)
                    }
                    break
                }
            }
        }
        activeAIMRockets.removeAll { $0.node.parent == nil }

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
        EngineSoundManager.shared.stopAll()
        wasFiring = false

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
