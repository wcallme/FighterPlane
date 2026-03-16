import SceneKit
import UIKit

// MARK: - Terrain Biome

enum TerrainBiome: Int, CaseIterable {
    case temperate = 0
    case desert = 1
    case arctic = 2
    case volcanic = 3

    /// Sky background color for this biome
    var skyColor: UIColor {
        switch self {
        case .temperate: return UIColor(red: 0.55, green: 0.78, blue: 0.95, alpha: 1.0)
        case .desert:    return UIColor(red: 0.85, green: 0.78, blue: 0.60, alpha: 1.0)
        case .arctic:    return UIColor(red: 0.75, green: 0.82, blue: 0.88, alpha: 1.0)
        case .volcanic:  return UIColor(red: 0.35, green: 0.18, blue: 0.12, alpha: 1.0)
        }
    }

    /// Fog color (matches sky for seamless horizon)
    var fogColor: UIColor { skyColor }

    /// Water surface color
    var waterColor: UIColor {
        switch self {
        case .temperate: return UIColor(red: 0.15, green: 0.60, blue: 0.70, alpha: 0.90)
        case .desert:    return UIColor(red: 0.60, green: 0.52, blue: 0.35, alpha: 0.85)
        case .arctic:    return UIColor(red: 0.30, green: 0.50, blue: 0.65, alpha: 0.92)
        case .volcanic:  return UIColor(red: 0.70, green: 0.22, blue: 0.05, alpha: 0.95)
        }
    }

    /// Ambient light tint
    var ambientColor: UIColor {
        switch self {
        case .temperate: return UIColor(red: 0.40, green: 0.45, blue: 0.55, alpha: 1.0)
        case .desert:    return UIColor(red: 0.55, green: 0.50, blue: 0.40, alpha: 1.0)
        case .arctic:    return UIColor(red: 0.50, green: 0.55, blue: 0.65, alpha: 1.0)
        case .volcanic:  return UIColor(red: 0.45, green: 0.25, blue: 0.20, alpha: 1.0)
        }
    }

    /// Sun color tint
    var sunColor: UIColor {
        switch self {
        case .temperate: return UIColor(white: 1.0, alpha: 1.0)
        case .desert:    return UIColor(red: 1.0, green: 0.92, blue: 0.75, alpha: 1.0)
        case .arctic:    return UIColor(red: 0.85, green: 0.90, blue: 1.0, alpha: 1.0)
        case .volcanic:  return UIColor(red: 1.0, green: 0.55, blue: 0.30, alpha: 1.0)
        }
    }

    /// Tree/vegetation density (count per chunk)
    var vegetationCount: Int {
        switch self {
        case .temperate: return 25
        case .desert:    return 8
        case .arctic:    return 12
        case .volcanic:  return 5
        }
    }
}

enum ModelGenerator3D {

    // MARK: - Player Plane (Selection)

    static func selectedPlayerPlane() -> SCNNode {
        let planeId = PlayerData.shared.selectedPlaneId
        return loadUSDZPlane(named: planeId) ?? loadUSDZPlane(named: "F16") ?? fallbackPlayerPlane()
    }

    /// Load a plane model for hangar/UI display (no game orientation correction)
    static func hangarPlane(forId planeId: String) -> SCNNode {
        return loadHangarUSDZPlane(named: planeId) ?? loadHangarUSDZPlane(named: "F16") ?? fallbackHangarPlane()
    }

    /// Procedural fallback plane when USDZ files fail to load (e.g. simulator)
    private static func fallbackPlayerPlane() -> SCNNode {
        let root = SCNNode()
        root.name = "player"

        let container = SCNNode()

        // Fuselage
        let fuselage = SCNBox(width: 0.6, height: 0.25, length: 2.5, chamferRadius: 0.1)
        fuselage.firstMaterial?.diffuse.contents = UIColor(red: 0.6, green: 0.6, blue: 0.65, alpha: 1)
        container.addChildNode(SCNNode(geometry: fuselage))

        // Wings
        let wing = SCNBox(width: 5.0, height: 0.06, length: 1.0, chamferRadius: 0.02)
        wing.firstMaterial?.diffuse.contents = UIColor(red: 0.55, green: 0.55, blue: 0.60, alpha: 1)
        let wingNode = SCNNode(geometry: wing)
        wingNode.position = SCNVector3(0, 0, -0.2)
        container.addChildNode(wingNode)

        // Tail
        let tail = SCNBox(width: 1.8, height: 0.05, length: 0.4, chamferRadius: 0.02)
        tail.firstMaterial?.diffuse.contents = UIColor(red: 0.55, green: 0.55, blue: 0.60, alpha: 1)
        let tailNode = SCNNode(geometry: tail)
        tailNode.position = SCNVector3(0, 0.1, -1.2)
        container.addChildNode(tailNode)

        // Vertical stabilizer
        let vstab = SCNBox(width: 0.06, height: 0.6, length: 0.5, chamferRadius: 0.02)
        vstab.firstMaterial?.diffuse.contents = UIColor(red: 0.55, green: 0.55, blue: 0.60, alpha: 1)
        let vstabNode = SCNNode(geometry: vstab)
        vstabNode.position = SCNVector3(0, 0.35, -1.1)
        container.addChildNode(vstabNode)

        // Cockpit
        let cockpit = SCNSphere(radius: 0.18)
        cockpit.firstMaterial?.diffuse.contents = UIColor(red: 0.3, green: 0.5, blue: 0.8, alpha: 0.9)
        let cockpitNode = SCNNode(geometry: cockpit)
        cockpitNode.position = SCNVector3(0, 0.2, 0.4)
        container.addChildNode(cockpitNode)

        container.eulerAngles.y = .pi / 2

        let targetSize: Float = 5.5
        let (minB, maxB) = container.boundingBox
        let maxDim = max(maxB.x - minB.x, maxB.y - minB.y, maxB.z - minB.z)
        if maxDim > 0 {
            let s = targetSize / maxDim
            root.scale = SCNVector3(s, s, s)
        }

        root.addChildNode(container)

        let trail = afterburnerTrail(scale: 1.0)
        trail.position = SCNVector3(0, 0, -targetSize * 0.45)
        root.addChildNode(trail)

        return root
    }

    /// Procedural fallback for hangar display
    private static func fallbackHangarPlane() -> SCNNode {
        let root = SCNNode()
        root.name = "hangarModel"

        let fuselage = SCNBox(width: 0.6, height: 0.25, length: 2.5, chamferRadius: 0.1)
        fuselage.firstMaterial?.diffuse.contents = UIColor(red: 0.6, green: 0.6, blue: 0.65, alpha: 1)
        root.addChildNode(SCNNode(geometry: fuselage))

        let wing = SCNBox(width: 5.0, height: 0.06, length: 1.0, chamferRadius: 0.02)
        wing.firstMaterial?.diffuse.contents = UIColor(red: 0.55, green: 0.55, blue: 0.60, alpha: 1)
        let wingNode = SCNNode(geometry: wing)
        wingNode.position = SCNVector3(0, 0, -0.2)
        root.addChildNode(wingNode)

        let targetSize: Float = 4.0
        let (minB, maxB) = root.boundingBox
        let maxDim = max(maxB.x - minB.x, maxB.y - minB.y, maxB.z - minB.z)
        if maxDim > 0 {
            let s = targetSize / maxDim
            root.scale = SCNVector3(s, s, s)
        }

        return root
    }

    private static func loadHangarUSDZPlane(named name: String) -> SCNNode? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "usdz") else { return nil }
        guard let scene = try? SCNScene(url: url) else { return nil }

        let root = SCNNode()
        root.name = "hangarModel"

        for child in scene.rootNode.childNodes {
            root.addChildNode(child.clone())
        }

        // Ensure all materials are double-sided and disable subdivision
        root.enumerateChildNodes { node, _ in
            node.geometry?.materials.forEach { material in
                material.isDoubleSided = true
            }
            node.geometry?.subdivisionLevel = 0
        }

        // Compute bounding box
        let (minBound, maxBound) = root.boundingBox
        let maxDim = max(maxBound.x - minBound.x, maxBound.y - minBound.y, maxBound.z - minBound.z)
        guard maxDim > 0 else { return nil }

        // Center the model
        let centerX = (minBound.x + maxBound.x) / 2
        let centerY = (minBound.y + maxBound.y) / 2
        let centerZ = (minBound.z + maxBound.z) / 2
        root.pivot = SCNMatrix4MakeTranslation(centerX, centerY, centerZ)

        // Scale to a display-friendly size
        let targetSize: Float = 4.0
        let scaleFactor = targetSize / maxDim
        root.scale = SCNVector3(scaleFactor, scaleFactor, scaleFactor)

        return root
    }

    private static func loadUSDZPlane(named name: String) -> SCNNode? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "usdz") else { return nil }
        guard let scene = try? SCNScene(url: url) else { return nil }

        let root = SCNNode()
        root.name = "player"

        // Use a container so orientation correction stays separate from game transforms
        let container = SCNNode()
        for child in scene.rootNode.childNodes {
            container.addChildNode(child.clone())
        }

        // Ensure all materials are double-sided and disable subdivision (prevents OSD_MAX_VALENCE errors)
        container.enumerateChildNodes { node, _ in
            node.geometry?.materials.forEach { material in
                material.isDoubleSided = true
            }
            node.geometry?.subdivisionLevel = 0
        }

        // Compute bounding box of the loaded model
        let (minBound, maxBound) = container.boundingBox
        let modelWidth = maxBound.x - minBound.x
        let modelHeight = maxBound.y - minBound.y
        let modelLength = maxBound.z - minBound.z
        let maxDim = max(modelWidth, modelLength, modelHeight)
        guard maxDim > 0 else { return nil }

        // Center the model at origin
        let centerX = (minBound.x + maxBound.x) / 2
        let centerY = (minBound.y + maxBound.y) / 2
        let centerZ = (minBound.z + maxBound.z) / 2
        container.pivot = SCNMatrix4MakeTranslation(centerX, centerY, centerZ)

        // Rotate +90° around Y so nose faces right (+Z in game).
        container.eulerAngles.y = .pi / 2

        // Scale to match game size (default plane wingspan is 5.5 units)
        let targetSize: Float = 5.5
        let scaleFactor = targetSize / maxDim
        root.scale = SCNVector3(scaleFactor, scaleFactor, scaleFactor)

        root.addChildNode(container)

        // Afterburner trail at the rear of the jet
        // Model is scaled to ~5.5 units; tail is roughly half that behind center
        let trail = afterburnerTrail(scale: 1.0)
        trail.position = SCNVector3(0, 0, -targetSize * 0.45)
        root.addChildNode(trail)

        return root
    }


    // MARK: - Afterburner Trail

    /// Creates a subtle afterburner/exhaust particle trail node
    static func afterburnerTrail(scale: Float = 1.0) -> SCNNode {
        let emitter = SCNNode()

        let trail = SCNParticleSystem()
        trail.particleSize = CGFloat(0.12 * scale)
        trail.particleSizeVariation = CGFloat(0.04 * scale)
        trail.birthRate = CGFloat(25 * scale)
        trail.particleLifeSpan = 0.35
        trail.particleLifeSpanVariation = 0.1
        trail.emissionDuration = .greatestFiniteMagnitude
        trail.spreadingAngle = 8
        trail.particleColor = UIColor(red: 0.6, green: 0.75, blue: 1.0, alpha: 0.35)
        trail.particleColorVariation = SCNVector4(0.15, 0.1, 0, 0.1)
        trail.isAffectedByGravity = false
        trail.particleVelocity = CGFloat(0.3 * scale)
        trail.emitterShape = SCNSphere(radius: CGFloat(0.04 * scale))
        trail.blendMode = .additive
        trail.isLightingEnabled = false

        // Fade out over lifetime
        let opacityController = SCNParticlePropertyController(
            animation: {
                let anim = CAKeyframeAnimation()
                anim.values = [0.4, 0.2, 0.0]
                anim.keyTimes = [0, 0.5, 1.0]
                anim.duration = 1.0
                return anim
            }()
        )
        trail.propertyControllers = [.opacity: opacityController]

        // Shrink slightly over lifetime
        let sizeController = SCNParticlePropertyController(
            animation: {
                let anim = CAKeyframeAnimation()
                anim.values = [1.0, 1.4, 0.6]
                anim.keyTimes = [0, 0.3, 1.0]
                anim.duration = 1.0
                return anim
            }()
        )
        trail.propertyControllers?[.size] = sizeController

        emitter.addParticleSystem(trail)
        return emitter
    }

    // Enemy model template cache — clone instead of rebuilding geometry each spawn
    private static var enemyModelTemplates: [String: SCNNode] = [:]

    private static func cachedEnemy(_ key: String, builder: () -> SCNNode) -> SCNNode {
        if let template = enemyModelTemplates[key] { return template.clone() }
        let template = builder()
        enemyModelTemplates[key] = template
        return template.clone()
    }

    // MARK: - Enemy Plane

    static func enemyPlane() -> SCNNode { cachedEnemy("enemyPlane") {
        let root = SCNNode()
        root.name = "enemyPlane"

        let fuselage = SCNBox(width: 0.7, height: 0.3, length: 2.4, chamferRadius: 0.1)
        fuselage.firstMaterial?.diffuse.contents = UIColor(red: 0.45, green: 0.45, blue: 0.43, alpha: 1)
        root.addChildNode(SCNNode(geometry: fuselage))

        let wing = SCNBox(width: 4.5, height: 0.07, length: 0.9, chamferRadius: 0.02)
        wing.firstMaterial?.diffuse.contents = UIColor(red: 0.50, green: 0.50, blue: 0.48, alpha: 1)
        let wingNode = SCNNode(geometry: wing)
        wingNode.position = SCNVector3(0, 0.05, -0.1)
        root.addChildNode(wingNode)

        let tail = SCNBox(width: 1.8, height: 0.06, length: 0.45, chamferRadius: 0.02)
        tail.firstMaterial?.diffuse.contents = UIColor(red: 0.50, green: 0.50, blue: 0.48, alpha: 1)
        let tailNode = SCNNode(geometry: tail)
        tailNode.position = SCNVector3(0, 0.12, -1.1)
        root.addChildNode(tailNode)

        let cockpit = SCNSphere(radius: 0.2)
        cockpit.firstMaterial?.diffuse.contents = UIColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 0.9)
        let cockpitNode = SCNNode(geometry: cockpit)
        cockpitNode.position = SCNVector3(0, 0.25, 0.3)
        root.addChildNode(cockpitNode)

        // Cheap static exhaust glow (no particle system — much lighter than afterburnerTrail)
        let exhaust = SCNSphere(radius: 0.15)
        exhaust.firstMaterial?.diffuse.contents = UIColor(red: 0.5, green: 0.6, blue: 1.0, alpha: 0.25)
        exhaust.firstMaterial?.emission.contents = UIColor(red: 0.4, green: 0.55, blue: 1.0, alpha: 0.5)
        exhaust.firstMaterial?.lightingModel = .constant
        let exhaustNode = SCNNode(geometry: exhaust)
        exhaustNode.position = SCNVector3(0, 0, -1.2)
        root.addChildNode(exhaustNode)

        // Rotate to face -Z (toward player)
        root.eulerAngles.y = .pi

        return root
    }}

    // MARK: - Ground Enemies

    static func tank() -> SCNNode { cachedEnemy("tank") {
        let root = SCNNode()
        root.name = "tank"

        // Tracks
        for x: Float in [-0.55, 0.55] {
            let track = SCNBox(width: 0.3, height: 0.25, length: 1.4, chamferRadius: 0.05)
            track.firstMaterial?.diffuse.contents = UIColor(red: 0.28, green: 0.28, blue: 0.25, alpha: 1)
            let trackNode = SCNNode(geometry: track)
            trackNode.position = SCNVector3(x, 0.12, 0)
            root.addChildNode(trackNode)
        }

        // Body
        let body = SCNBox(width: 0.9, height: 0.3, length: 1.2, chamferRadius: 0.04)
        body.firstMaterial?.diffuse.contents = UIColor(red: 0.42, green: 0.44, blue: 0.36, alpha: 1)
        let bodyNode = SCNNode(geometry: body)
        bodyNode.position = SCNVector3(0, 0.35, 0)
        root.addChildNode(bodyNode)

        // Turret
        let turret = SCNCylinder(radius: 0.3, height: 0.2)
        turret.firstMaterial?.diffuse.contents = UIColor(red: 0.38, green: 0.40, blue: 0.32, alpha: 1)
        let turretNode = SCNNode(geometry: turret)
        turretNode.position = SCNVector3(0, 0.55, -0.1)
        root.addChildNode(turretNode)

        // Barrel
        let barrel = SCNCylinder(radius: 0.05, height: 0.8)
        barrel.firstMaterial?.diffuse.contents = UIColor(red: 0.30, green: 0.30, blue: 0.26, alpha: 1)
        let barrelNode = SCNNode(geometry: barrel)
        barrelNode.eulerAngles.x = .pi / 2
        barrelNode.position = SCNVector3(0, 0.55, 0.5)
        root.addChildNode(barrelNode)

        return root
    }}

    static func aaGun() -> SCNNode { cachedEnemy("aaGun") {
        let root = SCNNode()
        root.name = "aaGun"

        // Sandbag base
        let base = SCNCylinder(radius: 0.6, height: 0.3)
        base.firstMaterial?.diffuse.contents = UIColor(red: 0.55, green: 0.50, blue: 0.38, alpha: 1)
        let baseNode = SCNNode(geometry: base)
        baseNode.position = SCNVector3(0, 0.15, 0)
        root.addChildNode(baseNode)

        // Gun mount
        let mount = SCNCylinder(radius: 0.15, height: 0.4)
        mount.firstMaterial?.diffuse.contents = UIColor(red: 0.38, green: 0.38, blue: 0.34, alpha: 1)
        let mountNode = SCNNode(geometry: mount)
        mountNode.position = SCNVector3(0, 0.45, 0)
        root.addChildNode(mountNode)

        // Twin barrels (pointing up-forward)
        for x: Float in [-0.08, 0.08] {
            let barrel = SCNCylinder(radius: 0.03, height: 0.8)
            barrel.firstMaterial?.diffuse.contents = UIColor(red: 0.25, green: 0.25, blue: 0.22, alpha: 1)
            let barrelNode = SCNNode(geometry: barrel)
            barrelNode.eulerAngles.x = -.pi / 4 // angle upward
            barrelNode.position = SCNVector3(x, 0.7, 0.2)
            root.addChildNode(barrelNode)
        }

        return root
    }}

    static func building() -> SCNNode { cachedEnemy("building") {
        let root = SCNNode()
        root.name = "building"

        // Building body
        let body = SCNBox(width: 1.8, height: 1.5, length: 1.8, chamferRadius: 0.05)
        body.firstMaterial?.diffuse.contents = UIColor(red: 0.55, green: 0.50, blue: 0.45, alpha: 1)
        let bodyNode = SCNNode(geometry: body)
        bodyNode.position = SCNVector3(0, 0.75, 0)
        root.addChildNode(bodyNode)

        // Roof
        let roof = SCNPyramid(width: 2.0, height: 0.6, length: 2.0)
        roof.firstMaterial?.diffuse.contents = UIColor(red: 0.45, green: 0.30, blue: 0.25, alpha: 1)
        let roofNode = SCNNode(geometry: roof)
        roofNode.position = SCNVector3(0, 1.5, 0)
        root.addChildNode(roofNode)

        return root
    }}

    // MARK: - SAM Launcher

    static func samLauncher() -> SCNNode { cachedEnemy("samLauncher") {
        let root = SCNNode()
        root.name = "samLauncher"

        // Truck bed / platform
        let bed = SCNBox(width: 1.2, height: 0.25, length: 2.0, chamferRadius: 0.04)
        bed.firstMaterial?.diffuse.contents = UIColor(red: 0.35, green: 0.38, blue: 0.30, alpha: 1)
        let bedNode = SCNNode(geometry: bed)
        bedNode.position = SCNVector3(0, 0.2, 0)
        root.addChildNode(bedNode)

        // Wheels
        for (x, z): (Float, Float) in [(-0.55, -0.6), (0.55, -0.6), (-0.55, 0.6), (0.55, 0.6)] {
            let wheel = SCNCylinder(radius: 0.15, height: 0.1)
            wheel.firstMaterial?.diffuse.contents = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1)
            let wheelNode = SCNNode(geometry: wheel)
            wheelNode.eulerAngles.z = .pi / 2
            wheelNode.position = SCNVector3(x, 0.1, z)
            root.addChildNode(wheelNode)
        }

        // Launch rail (angled upward)
        let rail = SCNBox(width: 0.15, height: 0.08, length: 1.6, chamferRadius: 0.02)
        rail.firstMaterial?.diffuse.contents = UIColor(red: 0.30, green: 0.30, blue: 0.28, alpha: 1)
        let railNode = SCNNode(geometry: rail)
        railNode.eulerAngles.x = -.pi / 5  // angled up ~36°
        railNode.position = SCNVector3(0, 0.6, 0.3)
        root.addChildNode(railNode)

        // Missile on rail
        let missile = SCNCapsule(capRadius: 0.06, height: 0.7)
        missile.firstMaterial?.diffuse.contents = UIColor(red: 0.75, green: 0.75, blue: 0.72, alpha: 1)
        let missileNode = SCNNode(geometry: missile)
        missileNode.eulerAngles.x = -.pi / 5
        missileNode.position = SCNVector3(0, 0.65, 0.5)
        root.addChildNode(missileNode)

        // Missile nose (red tip)
        let noseTip = SCNSphere(radius: 0.065)
        noseTip.firstMaterial?.diffuse.contents = UIColor(red: 0.9, green: 0.2, blue: 0.15, alpha: 1)
        let noseNode = SCNNode(geometry: noseTip)
        noseNode.position = SCNVector3(0, 0.88, 0.72)
        root.addChildNode(noseNode)

        // Support strut
        let strut = SCNCylinder(radius: 0.04, height: 0.35)
        strut.firstMaterial?.diffuse.contents = UIColor(red: 0.30, green: 0.30, blue: 0.28, alpha: 1)
        let strutNode = SCNNode(geometry: strut)
        strutNode.position = SCNVector3(0, 0.45, -0.1)
        root.addChildNode(strutNode)

        root.scale = SCNVector3(2, 2, 2)
        return root
    }}

    static func samMissile() -> SCNNode { cachedEnemy("samMissile") {
        let root = SCNNode()
        root.name = "samMissile"

        // Missile body
        let body = SCNCapsule(capRadius: 0.08, height: 0.8)
        body.firstMaterial?.diffuse.contents = UIColor(red: 0.8, green: 0.8, blue: 0.78, alpha: 1)
        let bodyNode = SCNNode(geometry: body)
        root.addChildNode(bodyNode)

        // Nose cone (red)
        let nose = SCNCone(topRadius: 0, bottomRadius: 0.08, height: 0.2)
        nose.firstMaterial?.diffuse.contents = UIColor(red: 0.9, green: 0.15, blue: 0.1, alpha: 1)
        nose.firstMaterial?.emission.contents = UIColor(red: 0.5, green: 0.1, blue: 0.05, alpha: 0.3)
        let noseNode = SCNNode(geometry: nose)
        noseNode.eulerAngles.x = -.pi / 2
        noseNode.position = SCNVector3(0, 0.45, 0)
        root.addChildNode(noseNode)

        // Fins
        for angle: Float in [0, .pi / 2, .pi, .pi * 1.5] {
            let fin = SCNBox(width: 0.25, height: 0.02, length: 0.12, chamferRadius: 0.005)
            fin.firstMaterial?.diffuse.contents = UIColor(red: 0.5, green: 0.5, blue: 0.48, alpha: 1)
            let finNode = SCNNode(geometry: fin)
            finNode.position = SCNVector3(
                cos(angle) * 0.08,
                -0.3,
                sin(angle) * 0.08
            )
            finNode.eulerAngles.y = angle
            root.addChildNode(finNode)
        }

        // Exhaust glow
        let exhaust = SCNSphere(radius: 0.06)
        exhaust.firstMaterial?.diffuse.contents = UIColor(red: 1, green: 0.6, blue: 0.1, alpha: 1)
        exhaust.firstMaterial?.emission.contents = UIColor(red: 1, green: 0.5, blue: 0, alpha: 1)
        let exhaustNode = SCNNode(geometry: exhaust)
        exhaustNode.position = SCNVector3(0, -0.42, 0)
        root.addChildNode(exhaustNode)

        // Smoke trail particle system
        let trail = SCNParticleSystem()
        trail.particleSize = 0.12
        trail.particleSizeVariation = 0.06
        trail.birthRate = 50
        trail.particleLifeSpan = 0.6
        trail.particleLifeSpanVariation = 0.2
        trail.emissionDuration = .greatestFiniteMagnitude
        trail.spreadingAngle = 15
        trail.particleColor = UIColor(white: 0.7, alpha: 0.6)
        trail.particleColorVariation = SCNVector4(0, 0, 0.1, 0.2)
        trail.isAffectedByGravity = false
        trail.particleVelocity = 0.5
        trail.emitterShape = nil
        root.addParticleSystem(trail)

        root.scale = SCNVector3(2, 2, 2)
        return root
    }}

    // MARK: - AIM Rocket (player homing missile — gray body, red tip)

    static func aimRocket() -> SCNNode { cachedEnemy("aimRocket") {
        let root = SCNNode()
        root.name = "aimRocket"

        // Missile body (gray instead of white)
        let body = SCNCapsule(capRadius: 0.08, height: 0.8)
        body.firstMaterial?.diffuse.contents = UIColor(red: 0.45, green: 0.45, blue: 0.48, alpha: 1)
        let bodyNode = SCNNode(geometry: body)
        root.addChildNode(bodyNode)

        // Nose cone (red)
        let nose = SCNCone(topRadius: 0, bottomRadius: 0.08, height: 0.2)
        nose.firstMaterial?.diffuse.contents = UIColor(red: 0.9, green: 0.15, blue: 0.1, alpha: 1)
        nose.firstMaterial?.emission.contents = UIColor(red: 0.5, green: 0.1, blue: 0.05, alpha: 0.3)
        let noseNode = SCNNode(geometry: nose)
        noseNode.eulerAngles.x = -.pi / 2
        noseNode.position = SCNVector3(0, 0.45, 0)
        root.addChildNode(noseNode)

        // Fins
        for angle: Float in [0, .pi / 2, .pi, .pi * 1.5] {
            let fin = SCNBox(width: 0.25, height: 0.02, length: 0.12, chamferRadius: 0.005)
            fin.firstMaterial?.diffuse.contents = UIColor(red: 0.35, green: 0.35, blue: 0.37, alpha: 1)
            let finNode = SCNNode(geometry: fin)
            finNode.position = SCNVector3(
                cos(angle) * 0.08,
                -0.3,
                sin(angle) * 0.08
            )
            finNode.eulerAngles.y = angle
            root.addChildNode(finNode)
        }

        // Exhaust glow
        let exhaust = SCNSphere(radius: 0.06)
        exhaust.firstMaterial?.diffuse.contents = UIColor(red: 1, green: 0.6, blue: 0.1, alpha: 1)
        exhaust.firstMaterial?.emission.contents = UIColor(red: 1, green: 0.5, blue: 0, alpha: 1)
        let exhaustNode = SCNNode(geometry: exhaust)
        exhaustNode.position = SCNVector3(0, -0.42, 0)
        root.addChildNode(exhaustNode)

        root.scale = SCNVector3(2, 2, 2)
        return root
    }}

    // MARK: - Trees

    static func tree(height: Float = 2.5, variation: Int = 0) -> SCNNode {
        let root = SCNNode()
        root.name = "tree"

        let trunkH = height * 0.35
        let canopyH = height * 0.65
        let canopyR = height * 0.3

        // Trunk
        let trunk = SCNCylinder(radius: CGFloat(height * 0.06), height: CGFloat(trunkH))
        trunk.firstMaterial?.diffuse.contents = UIColor(red: 0.45, green: 0.32, blue: 0.18, alpha: 1)
        let trunkNode = SCNNode(geometry: trunk)
        trunkNode.position = SCNVector3(0, trunkH / 2, 0)
        root.addChildNode(trunkNode)

        // Foliage (stacked cones for fuller look)
        let greenShades: [UIColor] = [
            UIColor(red: 0.15, green: 0.45, blue: 0.12, alpha: 1),
            UIColor(red: 0.2, green: 0.5, blue: 0.15, alpha: 1),
            UIColor(red: 0.18, green: 0.42, blue: 0.13, alpha: 1),
            UIColor(red: 0.25, green: 0.55, blue: 0.18, alpha: 1)
        ]
        let color = greenShades[variation % greenShades.count]

        let cone1 = SCNCone(topRadius: 0, bottomRadius: CGFloat(canopyR), height: CGFloat(canopyH))
        cone1.firstMaterial?.diffuse.contents = color
        let cone1Node = SCNNode(geometry: cone1)
        cone1Node.position = SCNVector3(0, trunkH + canopyH * 0.35, 0)
        root.addChildNode(cone1Node)

        // Second smaller cone on top
        let cone2 = SCNCone(topRadius: 0, bottomRadius: CGFloat(canopyR * 0.7), height: CGFloat(canopyH * 0.7))
        cone2.firstMaterial?.diffuse.contents = color.withAlphaComponent(0.95)
        let cone2Node = SCNNode(geometry: cone2)
        cone2Node.position = SCNVector3(0, trunkH + canopyH * 0.65, 0)
        root.addChildNode(cone2Node)

        return root
    }

    // MARK: - Biome Vegetation

    /// Desert cactus — tall green cylinder with arms
    static func cactus(height: Float = 2.5, variation: Int = 0) -> SCNNode {
        let root = SCNNode()
        root.name = "cactus"

        let greenShades: [UIColor] = [
            UIColor(red: 0.20, green: 0.45, blue: 0.15, alpha: 1),
            UIColor(red: 0.25, green: 0.50, blue: 0.18, alpha: 1),
            UIColor(red: 0.18, green: 0.40, blue: 0.13, alpha: 1)
        ]
        let color = greenShades[variation % greenShades.count]

        // Main trunk
        let trunk = SCNCylinder(radius: CGFloat(height * 0.08), height: CGFloat(height))
        trunk.firstMaterial?.diffuse.contents = color
        let trunkNode = SCNNode(geometry: trunk)
        trunkNode.position = SCNVector3(0, height / 2, 0)
        root.addChildNode(trunkNode)

        // Top dome
        let top = SCNSphere(radius: CGFloat(height * 0.08))
        top.firstMaterial?.diffuse.contents = color
        let topNode = SCNNode(geometry: top)
        topNode.position = SCNVector3(0, height, 0)
        root.addChildNode(topNode)

        // Arm (for taller cacti)
        if height > 2.0 {
            let armH = height * 0.35
            let arm = SCNCylinder(radius: CGFloat(height * 0.06), height: CGFloat(armH))
            arm.firstMaterial?.diffuse.contents = color
            let armNode = SCNNode(geometry: arm)
            let armSide: Float = (variation % 2 == 0) ? 1 : -1
            armNode.position = SCNVector3(armSide * height * 0.15, height * 0.6, 0)

            // Horizontal elbow
            let elbow = SCNCylinder(radius: CGFloat(height * 0.06), height: CGFloat(height * 0.12))
            elbow.firstMaterial?.diffuse.contents = color
            let elbowNode = SCNNode(geometry: elbow)
            elbowNode.eulerAngles.z = .pi / 2
            elbowNode.position = SCNVector3(armSide * height * 0.09, armH / 2, 0)
            armNode.addChildNode(elbowNode)

            root.addChildNode(armNode)
        }

        return root
    }

    /// Arctic snow-covered pine — white-tipped cone tree
    static func snowPine(height: Float = 2.5, variation: Int = 0) -> SCNNode {
        let root = SCNNode()
        root.name = "snowPine"

        let trunkH = height * 0.30
        let canopyH = height * 0.70
        let canopyR = height * 0.25

        // Trunk
        let trunk = SCNCylinder(radius: CGFloat(height * 0.05), height: CGFloat(trunkH))
        trunk.firstMaterial?.diffuse.contents = UIColor(red: 0.35, green: 0.28, blue: 0.20, alpha: 1)
        let trunkNode = SCNNode(geometry: trunk)
        trunkNode.position = SCNVector3(0, trunkH / 2, 0)
        root.addChildNode(trunkNode)

        // Dark green foliage (bottom)
        let cone1 = SCNCone(topRadius: 0, bottomRadius: CGFloat(canopyR), height: CGFloat(canopyH))
        let darkGreen = UIColor(red: 0.10, green: 0.28, blue: 0.12, alpha: 1)
        cone1.firstMaterial?.diffuse.contents = darkGreen
        let cone1Node = SCNNode(geometry: cone1)
        cone1Node.position = SCNVector3(0, trunkH + canopyH * 0.35, 0)
        root.addChildNode(cone1Node)

        // Snow cap (smaller white cone on top)
        let snowH = canopyH * 0.45
        let cone2 = SCNCone(topRadius: 0, bottomRadius: CGFloat(canopyR * 0.6), height: CGFloat(snowH))
        cone2.firstMaterial?.diffuse.contents = UIColor(red: 0.90, green: 0.92, blue: 0.95, alpha: 0.95)
        let cone2Node = SCNNode(geometry: cone2)
        cone2Node.position = SCNVector3(0, trunkH + canopyH * 0.65, 0)
        root.addChildNode(cone2Node)

        return root
    }

    /// Volcanic dead tree — charred trunk, no leaves
    static func deadTree(height: Float = 2.5, variation: Int = 0) -> SCNNode {
        let root = SCNNode()
        root.name = "deadTree"

        let charColors: [UIColor] = [
            UIColor(red: 0.20, green: 0.15, blue: 0.10, alpha: 1),
            UIColor(red: 0.25, green: 0.18, blue: 0.12, alpha: 1),
            UIColor(red: 0.15, green: 0.12, blue: 0.08, alpha: 1)
        ]
        let color = charColors[variation % charColors.count]

        // Main trunk (thinner, charred)
        let trunk = SCNCylinder(radius: CGFloat(height * 0.05), height: CGFloat(height * 0.7))
        trunk.firstMaterial?.diffuse.contents = color
        let trunkNode = SCNNode(geometry: trunk)
        trunkNode.position = SCNVector3(0, height * 0.35, 0)
        // Slight lean
        trunkNode.eulerAngles.z = Float(variation % 3) * 0.08 - 0.08
        root.addChildNode(trunkNode)

        // A branch stub or two
        let branchLen = height * 0.25
        let branch = SCNCylinder(radius: CGFloat(height * 0.025), height: CGFloat(branchLen))
        branch.firstMaterial?.diffuse.contents = color
        let branchNode = SCNNode(geometry: branch)
        branchNode.position = SCNVector3(0, height * 0.55, 0)
        branchNode.eulerAngles.z = (variation % 2 == 0) ? Float.pi / 4 : -Float.pi / 4
        root.addChildNode(branchNode)

        return root
    }

    /// Volcanic rock boulder
    static func volcanicRock(size: Float = 1.0, variation: Int = 0) -> SCNNode {
        let root = SCNNode()
        root.name = "volcanicRock"

        let rockColors: [UIColor] = [
            UIColor(red: 0.22, green: 0.18, blue: 0.15, alpha: 1),
            UIColor(red: 0.30, green: 0.22, blue: 0.16, alpha: 1),
            UIColor(red: 0.18, green: 0.15, blue: 0.12, alpha: 1)
        ]
        let color = rockColors[variation % rockColors.count]

        let rock = SCNSphere(radius: CGFloat(size * 0.5))
        rock.segmentCount = 6 // low-poly look
        rock.firstMaterial?.diffuse.contents = color
        let rockNode = SCNNode(geometry: rock)
        rockNode.position = SCNVector3(0, size * 0.3, 0)
        rockNode.scale = SCNVector3(1.0, 0.6, 0.8) // squashed
        root.addChildNode(rockNode)

        return root
    }

    // MARK: - Projectiles

    // Bullet template cache — geometry is expensive, clone is cheap
    private static var bulletTemplates: [String: SCNNode] = [:]

    static func playerBullet(weaponId: String = "basic_gun") -> SCNNode {
        if let template = bulletTemplates[weaponId] {
            return template.clone()
        }
        let template: SCNNode
        switch weaponId {
        case "cannon": template = cannonBullet3D()
        case "machine_gun": template = machineGunBullet3D()
        case "autocannon": template = autocannonBullet3D()
        default: template = basicBullet3D()
        }
        bulletTemplates[weaponId] = template
        return template.clone()
    }

    /// Basic gun — dark tracer, slightly thicker than before
    /// Note: Child nodes have NO euler rotation — fireGun() sets root orientation.
    private static func basicBullet3D() -> SCNNode {
        let root = SCNNode()
        root.name = "playerBullet"

        let stick = SCNCylinder(radius: 0.06, height: 2.5)
        stick.firstMaterial?.diffuse.contents = UIColor(red: 0.10, green: 0.10, blue: 0.10, alpha: 1)
        stick.firstMaterial?.lightingModel = .constant
        let stickNode = SCNNode(geometry: stick)
        root.addChildNode(stickNode)

        // Subtle metallic edge highlight
        let highlight = SCNCylinder(radius: 0.072, height: 2.5)
        highlight.firstMaterial?.diffuse.contents = UIColor(white: 0.35, alpha: 0.3)
        highlight.firstMaterial?.lightingModel = .constant
        highlight.firstMaterial?.transparency = 0.3
        let hlNode = SCNNode(geometry: highlight)
        root.addChildNode(hlNode)

        return root
    }

    /// Heavy Cannon — big dark yellow slug
    private static func cannonBullet3D() -> SCNNode {
        let root = SCNNode()
        root.name = "playerBullet"

        // Dark yellow core — bigger than other bullets
        let stick = SCNCylinder(radius: 0.17, height: 3.2)
        stick.firstMaterial?.diffuse.contents = UIColor(red: 0.7, green: 0.55, blue: 0.0, alpha: 1)
        stick.firstMaterial?.emission.contents = UIColor(red: 0.5, green: 0.4, blue: 0.0, alpha: 0.4)
        stick.firstMaterial?.lightingModel = .constant
        let stickNode = SCNNode(geometry: stick)
        root.addChildNode(stickNode)

        // Dark golden glow halo
        let glow = SCNCylinder(radius: 0.25, height: 3.2)
        glow.firstMaterial?.diffuse.contents = UIColor(red: 0.8, green: 0.65, blue: 0.05, alpha: 0.2)
        glow.firstMaterial?.emission.contents = UIColor(red: 0.7, green: 0.55, blue: 0.0, alpha: 0.15)
        glow.firstMaterial?.lightingModel = .constant
        glow.firstMaterial?.transparency = 0.25
        let glowNode = SCNNode(geometry: glow)
        root.addChildNode(glowNode)

        return root
    }

    /// Machine gun — medium tracer with golden-amber glow trail
    private static func machineGunBullet3D() -> SCNNode {
        let root = SCNNode()
        root.name = "playerBullet"

        // Amber tracer core
        let stick = SCNCylinder(radius: 0.19, height: 2.4)
        stick.firstMaterial?.diffuse.contents = UIColor(red: 0.85, green: 0.65, blue: 0.1, alpha: 1)
        stick.firstMaterial?.emission.contents = UIColor(red: 0.6, green: 0.45, blue: 0.05, alpha: 0.5)
        stick.firstMaterial?.lightingModel = .constant
        let stickNode = SCNNode(geometry: stick)
        root.addChildNode(stickNode)

        // Golden glow envelope
        let glow = SCNCylinder(radius: 0.315, height: 2.4)
        glow.firstMaterial?.diffuse.contents = UIColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 0.15)
        glow.firstMaterial?.emission.contents = UIColor(red: 0.8, green: 0.65, blue: 0.1, alpha: 0.1)
        glow.firstMaterial?.lightingModel = .constant
        glow.firstMaterial?.transparency = 0.2
        let glowNode = SCNNode(geometry: glow)
        root.addChildNode(glowNode)

        return root
    }

    /// Autocannon — thick golden tracers, bright and aggressive
    private static func autocannonBullet3D() -> SCNNode {
        let root = SCNNode()
        root.name = "playerBullet"

        // Dark steel core
        let stick = SCNCylinder(radius: 0.095, height: 2.5)
        stick.firstMaterial?.diffuse.contents = UIColor(red: 0.15, green: 0.15, blue: 0.12, alpha: 1)
        stick.firstMaterial?.lightingModel = .constant
        let stickNode = SCNNode(geometry: stick)
        root.addChildNode(stickNode)

        // Bright golden glow
        let glow = SCNCylinder(radius: 0.158, height: 2.5)
        glow.firstMaterial?.diffuse.contents = UIColor(red: 1.0, green: 0.8, blue: 0.15, alpha: 0.25)
        glow.firstMaterial?.emission.contents = UIColor(red: 1.0, green: 0.75, blue: 0.1, alpha: 0.3)
        glow.firstMaterial?.lightingModel = .constant
        glow.firstMaterial?.transparency = 0.3
        let glowNode = SCNNode(geometry: glow)
        root.addChildNode(glowNode)

        // Dark yellow tip sphere — offset along Y (cylinder axis), fireGun rotates to match travel
        let tip = SCNSphere(radius: 0.126)
        tip.firstMaterial?.diffuse.contents = UIColor(red: 0.7, green: 0.55, blue: 0.0, alpha: 1)
        tip.firstMaterial?.emission.contents = UIColor(red: 0.5, green: 0.4, blue: 0.0, alpha: 0.6)
        tip.firstMaterial?.lightingModel = .constant
        let tipNode = SCNNode(geometry: tip)
        tipNode.position = SCNVector3(0, 1.25, 0) // at the leading edge along cylinder Y axis
        root.addChildNode(tipNode)

        return root
    }

    private static var enemyBulletTemplate: SCNNode?
    private static var aiFighterBulletTemplate: SCNNode?

    static func enemyBullet() -> SCNNode {
        if let template = enemyBulletTemplate {
            return template.clone()
        }
        // Dark-red tracer — thick and short
        let stick = SCNCylinder(radius: 0.063, height: 1.5)
        stick.firstMaterial?.diffuse.contents = UIColor(red: 0.7, green: 0.1, blue: 0.08, alpha: 1)
        stick.firstMaterial?.emission.contents = UIColor(red: 0.75, green: 0.1, blue: 0.05, alpha: 0.6)
        stick.firstMaterial?.lightingModel = .constant
        let node = SCNNode(geometry: stick)
        node.name = "enemyBullet"
        enemyBulletTemplate = node
        return node.clone()
    }

    /// Yellow/amber tracer round for AI fighter machine gun
    static func aiFighterBullet() -> SCNNode {
        if let template = aiFighterBulletTemplate {
            return template.clone()
        }
        let root = SCNNode()
        root.name = "enemyBullet"

        // Amber tracer core
        let stick = SCNCylinder(radius: 0.05, height: 1.2)
        stick.firstMaterial?.diffuse.contents = UIColor(red: 0.85, green: 0.65, blue: 0.1, alpha: 1)
        stick.firstMaterial?.emission.contents = UIColor(red: 0.9, green: 0.7, blue: 0.1, alpha: 0.7)
        stick.firstMaterial?.lightingModel = .constant
        root.addChildNode(SCNNode(geometry: stick))

        // Golden glow envelope
        let glow = SCNCylinder(radius: 0.1, height: 1.2)
        glow.firstMaterial?.diffuse.contents = UIColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 0.15)
        glow.firstMaterial?.emission.contents = UIColor(red: 0.8, green: 0.65, blue: 0.1, alpha: 0.1)
        glow.firstMaterial?.lightingModel = .constant
        root.addChildNode(SCNNode(geometry: glow))

        aiFighterBulletTemplate = root
        return root.clone()
    }

    static func bomb3D(weaponId: String = "bomb") -> SCNNode {
        switch weaponId {
        case "mining_bomb": return miningBomb3D()
        case "heavy_bomb": return heavyBomb3D()
        case "cluster_warhead": return clusterWarhead3D()
        default: return standardBomb3D()
        }
    }

    /// Classic iron bomb — bulbous pear body, rounded nose, dramatic 4-fin flared tail
    private static func standardBomb3D() -> SCNNode {
        let root = SCNNode()
        root.name = "bomb3D"

        // Bulbous pear body — sphere for the fat front + capsule for rear taper
        let bulb = SCNSphere(radius: 0.18)
        bulb.firstMaterial?.diffuse.contents = UIColor(red: 0.18, green: 0.18, blue: 0.18, alpha: 1)
        bulb.firstMaterial?.specular.contents = UIColor(white: 0.3, alpha: 1)
        let bulbNode = SCNNode(geometry: bulb)
        bulbNode.position = SCNVector3(0, -0.08, 0)
        root.addChildNode(bulbNode)

        // Rear taper
        let taper = SCNCapsule(capRadius: 0.12, height: 0.35)
        taper.firstMaterial?.diffuse.contents = UIColor(red: 0.18, green: 0.18, blue: 0.18, alpha: 1)
        taper.firstMaterial?.specular.contents = UIColor(white: 0.3, alpha: 1)
        let taperNode = SCNNode(geometry: taper)
        taperNode.position = SCNVector3(0, 0.10, 0)
        root.addChildNode(taperNode)

        // Rounded nose cap
        let noseCap = SCNSphere(radius: 0.10)
        noseCap.firstMaterial?.diffuse.contents = UIColor(red: 0.28, green: 0.26, blue: 0.24, alpha: 1)
        noseCap.firstMaterial?.specular.contents = UIColor(white: 0.4, alpha: 1)
        let noseNode = SCNNode(geometry: noseCap)
        noseNode.position = SCNVector3(0, -0.26, 0)
        root.addChildNode(noseNode)

        // Fuze nub
        let fuze = SCNCylinder(radius: 0.025, height: 0.05)
        fuze.firstMaterial?.diffuse.contents = UIColor(white: 0.42, alpha: 1)
        fuze.firstMaterial?.metalness.contents = 0.6
        let fuzeNode = SCNNode(geometry: fuze)
        fuzeNode.position = SCNVector3(0, -0.32, 0)
        root.addChildNode(fuzeNode)

        // Tail shroud — narrow neck before fins
        let shroud = SCNCylinder(radius: 0.08, height: 0.10)
        shroud.firstMaterial?.diffuse.contents = UIColor(red: 0.20, green: 0.20, blue: 0.20, alpha: 1)
        let shroudNode = SCNNode(geometry: shroud)
        shroudNode.position = SCNVector3(0, 0.30, 0)
        root.addChildNode(shroudNode)

        // 4 dramatic flared tail fins
        for angle: Float in [0, .pi / 2, .pi, .pi * 1.5] {
            let fin = SCNBox(width: 0.36, height: 0.02, length: 0.20, chamferRadius: 0.005)
            fin.firstMaterial?.diffuse.contents = UIColor(red: 0.25, green: 0.25, blue: 0.23, alpha: 1)
            let finNode = SCNNode(geometry: fin)
            finNode.position = SCNVector3(cos(angle) * 0.04, 0.38, sin(angle) * 0.04)
            finNode.eulerAngles.y = angle
            // Slight outward cant for flared look
            finNode.eulerAngles.z = 0.15
            root.addChildNode(finNode)
        }

        // Tail ring
        let ring = SCNTorus(ringRadius: 0.09, pipeRadius: 0.012)
        ring.firstMaterial?.diffuse.contents = UIColor(white: 0.32, alpha: 1)
        let ringNode = SCNNode(geometry: ring)
        ringNode.position = SCNVector3(0, 0.32, 0)
        root.addChildNode(ringNode)

        // 25% larger than base size
        root.scale = SCNVector3(1.25, 1.25, 1.25)

        return root
    }

    /// Mining bomb — bronze drill-tipped penetrator with pear body and flared fins
    private static func miningBomb3D() -> SCNNode {
        let root = SCNNode()
        root.name = "bomb3D"

        // Pear body — bronze
        let bulb = SCNSphere(radius: 0.16)
        bulb.firstMaterial?.diffuse.contents = UIColor(red: 0.55, green: 0.38, blue: 0.12, alpha: 1)
        bulb.firstMaterial?.specular.contents = UIColor(red: 0.8, green: 0.6, blue: 0.2, alpha: 1)
        bulb.firstMaterial?.metalness.contents = 0.6
        let bulbNode = SCNNode(geometry: bulb)
        bulbNode.position = SCNVector3(0, -0.02, 0)
        root.addChildNode(bulbNode)

        // Rear taper
        let taper = SCNCapsule(capRadius: 0.10, height: 0.30)
        taper.firstMaterial?.diffuse.contents = UIColor(red: 0.50, green: 0.35, blue: 0.12, alpha: 1)
        taper.firstMaterial?.specular.contents = UIColor(red: 0.7, green: 0.5, blue: 0.2, alpha: 1)
        let taperNode = SCNNode(geometry: taper)
        taperNode.position = SCNVector3(0, 0.12, 0)
        root.addChildNode(taperNode)

        // Drill tip — sharp cone
        let drillTip = SCNCone(topRadius: 0, bottomRadius: 0.12, height: 0.22)
        drillTip.firstMaterial?.diffuse.contents = UIColor(red: 0.70, green: 0.50, blue: 0.15, alpha: 1)
        drillTip.firstMaterial?.specular.contents = UIColor(red: 0.9, green: 0.7, blue: 0.3, alpha: 1)
        drillTip.firstMaterial?.metalness.contents = 0.8
        let tipNode = SCNNode(geometry: drillTip)
        tipNode.position = SCNVector3(0, -0.28, 0)
        root.addChildNode(tipNode)

        // Spiral groove rings
        for i in 0..<4 {
            let ring = SCNTorus(ringRadius: CGFloat(0.14 - Float(i) * 0.008), pipeRadius: 0.008)
            ring.firstMaterial?.diffuse.contents = UIColor(red: 0.40, green: 0.28, blue: 0.08, alpha: 1)
            let ringNode = SCNNode(geometry: ring)
            ringNode.position = SCNVector3(0, Float(i) * 0.08 - 0.10, 0)
            root.addChildNode(ringNode)
        }

        // Flared tail fins
        for angle: Float in [0, .pi / 2, .pi, .pi * 1.5] {
            let fin = SCNBox(width: 0.28, height: 0.015, length: 0.14, chamferRadius: 0.003)
            fin.firstMaterial?.diffuse.contents = UIColor(red: 0.45, green: 0.32, blue: 0.12, alpha: 1)
            let finNode = SCNNode(geometry: fin)
            finNode.position = SCNVector3(cos(angle) * 0.03, 0.30, sin(angle) * 0.03)
            finNode.eulerAngles.y = angle
            finNode.eulerAngles.z = 0.12
            root.addChildNode(finNode)
        }

        return root
    }

    /// Heavy bomb — massive fat pear body with red warning bands and huge flared fins
    private static func heavyBomb3D() -> SCNNode {
        let root = SCNNode()
        root.name = "bomb3D"

        // Big egg body — low-poly sphere scaled into an egg shape
        let egg = SCNSphere(radius: 0.38)
        egg.segmentCount = 12 // low poly
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor(red: 0.12, green: 0.12, blue: 0.13, alpha: 1)
        mat.specular.contents = UIColor(white: 0.2, alpha: 1)
        mat.roughness.contents = 0.7
        egg.materials = [mat]
        let eggNode = SCNNode(geometry: egg)
        // Stretch vertically into egg/oval shape
        eggNode.scale = SCNVector3(1.0, 1.4, 1.0)
        root.addChildNode(eggNode)

        // Subtle darker cap on nose end
        let noseCap = SCNSphere(radius: 0.22)
        noseCap.segmentCount = 10
        let noseMat = SCNMaterial()
        noseMat.diffuse.contents = UIColor(red: 0.08, green: 0.08, blue: 0.09, alpha: 1)
        noseMat.roughness.contents = 0.8
        noseCap.materials = [noseMat]
        let noseNode = SCNNode(geometry: noseCap)
        noseNode.position = SCNVector3(0, -0.42, 0)
        root.addChildNode(noseNode)

        // Small stub fins at the tail
        let finMat = SCNMaterial()
        finMat.diffuse.contents = UIColor(red: 0.18, green: 0.18, blue: 0.18, alpha: 1)
        for angle: Float in [0, .pi / 2, .pi, .pi * 1.5] {
            let fin = SCNBox(width: 0.28, height: 0.02, length: 0.14, chamferRadius: 0.003)
            fin.materials = [finMat]
            let finNode = SCNNode(geometry: fin)
            finNode.position = SCNVector3(cos(angle) * 0.03, 0.48, sin(angle) * 0.03)
            finNode.eulerAngles.y = angle
            finNode.eulerAngles.z = 0.12
            root.addChildNode(finNode)
        }

        return root
    }

    /// Cluster warhead — small stubby pear, olive green with yellow band and mini fins
    private static func clusterWarhead3D() -> SCNNode {
        let root = SCNNode()
        root.name = "bomb3D"
        root.scale = SCNVector3(4, 4, 4)

        // Pointed nose cone
        let nose = SCNCone(topRadius: 0.08, bottomRadius: 0, height: 0.18)
        nose.firstMaterial?.diffuse.contents = UIColor(red: 0.28, green: 0.34, blue: 0.18, alpha: 1)
        nose.firstMaterial?.specular.contents = UIColor(white: 0.3, alpha: 1)
        let noseNode = SCNNode(geometry: nose)
        noseNode.position = SCNVector3(0, -0.18, 0)
        root.addChildNode(noseNode)

        // Main body
        let bulb = SCNSphere(radius: 0.10)
        bulb.firstMaterial?.diffuse.contents = UIColor(red: 0.28, green: 0.34, blue: 0.18, alpha: 1)
        bulb.firstMaterial?.specular.contents = UIColor(white: 0.3, alpha: 1)
        let bulbNode = SCNNode(geometry: bulb)
        bulbNode.position = SCNVector3(0, -0.04, 0)
        root.addChildNode(bulbNode)

        // Rear taper
        let taper = SCNCone(topRadius: 0.08, bottomRadius: 0.04, height: 0.16)
        taper.firstMaterial?.diffuse.contents = UIColor(red: 0.26, green: 0.30, blue: 0.16, alpha: 1)
        let taperNode = SCNNode(geometry: taper)
        taperNode.position = SCNVector3(0, 0.10, 0)
        root.addChildNode(taperNode)

        // Yellow identification band
        let band = SCNTorus(ringRadius: 0.095, pipeRadius: 0.012)
        band.firstMaterial?.diffuse.contents = UIColor(red: 0.92, green: 0.82, blue: 0.18, alpha: 1)
        band.firstMaterial?.emission.contents = UIColor(red: 0.4, green: 0.35, blue: 0.05, alpha: 0.2)
        let bandNode = SCNNode(geometry: band)
        bandNode.position = SCNVector3(0, -0.04, 0)
        root.addChildNode(bandNode)

        // Small flared tail fins
        for angle: Float in [0, .pi / 2, .pi, .pi * 1.5] {
            let fin = SCNBox(width: 0.18, height: 0.012, length: 0.10, chamferRadius: 0.003)
            fin.firstMaterial?.diffuse.contents = UIColor(red: 0.22, green: 0.26, blue: 0.14, alpha: 1)
            let finNode = SCNNode(geometry: fin)
            finNode.position = SCNVector3(cos(angle) * 0.02, 0.16, sin(angle) * 0.02)
            finNode.eulerAngles.y = angle
            finNode.eulerAngles.z = 0.12
            root.addChildNode(finNode)
        }

        return root
    }

    /// Tiny bomblet for cluster warhead sub-munitions — teardrop with pointed nose
    static func clusterBomblet3D() -> SCNNode {
        let root = SCNNode()
        root.name = "bomb3D"
        root.scale = SCNVector3(1.3, 1.3, 1.3)

        // Pointed nose cone
        let nose = SCNCone(topRadius: 0, bottomRadius: 0.045, height: 0.10)
        nose.firstMaterial?.diffuse.contents = UIColor(red: 0.22, green: 0.28, blue: 0.14, alpha: 1)
        nose.firstMaterial?.specular.contents = UIColor(white: 0.3, alpha: 1)
        let noseNode = SCNNode(geometry: nose)
        noseNode.position = SCNVector3(0, -0.08, 0)
        root.addChildNode(noseNode)

        // Body
        let sphere = SCNSphere(radius: 0.06)
        sphere.firstMaterial?.diffuse.contents = UIColor(red: 0.22, green: 0.28, blue: 0.14, alpha: 1)
        sphere.firstMaterial?.specular.contents = UIColor(white: 0.3, alpha: 1)
        let sphereNode = SCNNode(geometry: sphere)
        root.addChildNode(sphereNode)

        // Tiny yellow dot marking
        let dot = SCNSphere(radius: 0.02)
        dot.firstMaterial?.diffuse.contents = UIColor(red: 0.92, green: 0.82, blue: 0.18, alpha: 1)
        dot.firstMaterial?.emission.contents = UIColor(red: 0.4, green: 0.35, blue: 0.05, alpha: 0.3)
        let dotNode = SCNNode(geometry: dot)
        dotNode.position = SCNVector3(0, -0.04, 0)
        root.addChildNode(dotNode)

        return root
    }

    static func bombShadow3D() -> SCNNode {
        let plane = SCNPlane(width: 1.0, height: 1.0)
        plane.firstMaterial?.diffuse.contents = UIColor(white: 0, alpha: 0.4)
        plane.firstMaterial?.isDoubleSided = true
        plane.firstMaterial?.writesToDepthBuffer = false
        let node = SCNNode(geometry: plane)
        node.eulerAngles.x = -.pi / 2 // lay flat
        node.name = "bombShadow"
        return node
    }

    // MARK: - Health Bar

    static func healthBar(width: Float = 1.8) -> SCNNode {
        let root = SCNNode()
        root.name = "healthBar"

        // Background (dark)
        let bgPlane = SCNPlane(width: CGFloat(width), height: 0.2)
        bgPlane.firstMaterial?.diffuse.contents = UIColor(white: 0.15, alpha: 0.8)
        bgPlane.firstMaterial?.lightingModel = .constant
        bgPlane.firstMaterial?.isDoubleSided = true
        let bgNode = SCNNode(geometry: bgPlane)
        bgNode.name = "healthBarBg"
        root.addChildNode(bgNode)

        // Fill (green)
        let fillPlane = SCNPlane(width: CGFloat(width - 0.05), height: 0.14)
        fillPlane.firstMaterial?.diffuse.contents = UIColor(red: 0.2, green: 0.8, blue: 0.2, alpha: 1)
        fillPlane.firstMaterial?.lightingModel = .constant
        fillPlane.firstMaterial?.isDoubleSided = true
        let fillNode = SCNNode(geometry: fillPlane)
        fillNode.name = "healthBarFill"
        root.addChildNode(fillNode)

        // Always face the camera
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .all
        root.constraints = [billboard]

        // Hidden until first damage
        root.isHidden = true

        return root
    }

    // MARK: - Explosion

    static func explosion(radius: Float) -> SCNNode {
        let root = SCNNode()
        root.name = "explosion"

        // Central flash
        let flash = SCNSphere(radius: CGFloat(radius * 0.5))
        flash.firstMaterial?.diffuse.contents = UIColor(red: 1, green: 0.9, blue: 0.5, alpha: 1)
        flash.firstMaterial?.emission.contents = UIColor(red: 1, green: 0.7, blue: 0.2, alpha: 1)
        let flashNode = SCNNode(geometry: flash)
        root.addChildNode(flashNode)

        // Outer fireball
        let fireball = SCNSphere(radius: CGFloat(radius))
        fireball.firstMaterial?.diffuse.contents = UIColor(red: 1, green: 0.4, blue: 0.1, alpha: 0.7)
        fireball.firstMaterial?.emission.contents = UIColor(red: 0.8, green: 0.3, blue: 0.1, alpha: 0.5)
        fireball.firstMaterial?.transparency = 0.7
        let fireNode = SCNNode(geometry: fireball)
        root.addChildNode(fireNode)

        // Animate: grow then fade
        let grow = SCNAction.scale(to: 2.0, duration: 0.3)
        let fade = SCNAction.fadeOut(duration: 0.4)
        let remove = SCNAction.removeFromParentNode()
        root.runAction(.sequence([grow, fade, remove]))

        return root
    }

    // MARK: - Water Splash

    /// Creates a small water splash effect: a short spray column + expanding ring.
    static func waterSplash(radius: Float) -> SCNNode {
        let root = SCNNode()
        root.name = "waterSplash"
        let r = radius * 0.35  // scale splash down significantly

        // Spray column — short thin cylinder shooting upward
        let sprayHeight = CGFloat(r * 2.5)
        let spray = SCNCylinder(radius: CGFloat(r * 0.2), height: sprayHeight)
        spray.radialSegmentCount = 6
        let sprayMat = SCNMaterial()
        sprayMat.diffuse.contents = UIColor(red: 0.7, green: 0.9, blue: 1.0, alpha: 0.6)
        sprayMat.emission.contents = UIColor(red: 0.5, green: 0.75, blue: 0.9, alpha: 0.2)
        sprayMat.transparency = 0.5
        sprayMat.lightingModel = .constant
        sprayMat.isDoubleSided = true
        spray.materials = [sprayMat]
        let sprayNode = SCNNode(geometry: spray)
        sprayNode.position.y = Float(sprayHeight) * 0.5
        root.addChildNode(sprayNode)

        // Splash ring — small torus expanding outward
        let ring = SCNTorus(ringRadius: CGFloat(r * 0.5), pipeRadius: CGFloat(r * 0.1))
        ring.ringSegmentCount = 12
        ring.pipeSegmentCount = 6
        let ringMat = SCNMaterial()
        ringMat.diffuse.contents = UIColor(red: 0.8, green: 0.95, blue: 1.0, alpha: 0.5)
        ringMat.transparency = 0.4
        ringMat.lightingModel = .constant
        ringMat.isDoubleSided = true
        ring.materials = [ringMat]
        let ringNode = SCNNode(geometry: ring)
        root.addChildNode(ringNode)

        // Animate spray: shoot up then fade
        let sprayUp = SCNAction.moveBy(x: 0, y: CGFloat(r * 1.0), z: 0, duration: 0.2)
        sprayUp.timingMode = .easeOut
        let sprayFade = SCNAction.fadeOut(duration: 0.25)
        sprayNode.runAction(.sequence([sprayUp, sprayFade]))

        // Animate ring: expand outward then fade
        let ringExpand = SCNAction.scale(to: 2.0, duration: 0.35)
        ringExpand.timingMode = .easeOut
        let ringFade = SCNAction.fadeOut(duration: 0.2)
        ringNode.runAction(.sequence([ringExpand, ringFade]))

        // Remove root after animations complete
        let wait = SCNAction.wait(duration: 0.65)
        let remove = SCNAction.removeFromParentNode()
        root.runAction(.sequence([wait, remove]))

        return root
    }

    // MARK: - Water

    /// Generate a procedural water texture with ripple/caustic patterns
    private static func waterTexture(size: Int = 256) -> UIImage {
        let s = CGFloat(size)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: s, height: s))
        return renderer.image { ctx in
            let c = ctx.cgContext

            // Base water color
            c.setFillColor(UIColor(red: 0.10, green: 0.50, blue: 0.62, alpha: 1.0).cgColor)
            c.fill(CGRect(x: 0, y: 0, width: s, height: s))

            // Layered ripple rings for caustic-like pattern
            for i in 0..<40 {
                let seed = Float(i) * 17.3 + 5.1
                let cx = CGFloat(sin(seed) * 0.5 + 0.5) * s
                let cy = CGFloat(cos(seed * 1.3) * 0.5 + 0.5) * s
                let radius = CGFloat(12 + (i % 5) * 8)
                let alpha: CGFloat = 0.06 + CGFloat(i % 3) * 0.02

                c.setStrokeColor(UIColor(red: 0.25, green: 0.70, blue: 0.80, alpha: alpha).cgColor)
                c.setLineWidth(1.5)
                c.strokeEllipse(in: CGRect(x: cx - radius, y: cy - radius, width: radius * 2, height: radius * 2))
            }

            // Bright caustic highlights
            for i in 0..<60 {
                let seed = Float(i) * 7.7 + 2.3
                let px = CGFloat(sin(seed * 3.1 + 1.0) * 0.5 + 0.5) * s
                let py = CGFloat(cos(seed * 2.7 + 4.0) * 0.5 + 0.5) * s
                let w = CGFloat(3 + (i % 4) * 2)
                let h = CGFloat(2 + (i % 3) * 2)

                c.setFillColor(UIColor(red: 0.30, green: 0.72, blue: 0.82, alpha: 0.12).cgColor)
                c.fillEllipse(in: CGRect(x: px, y: py, width: w, height: h))
            }

            // Dark depth patches
            for i in 0..<20 {
                let seed = Float(i) * 23.1 + 8.9
                let px = CGFloat(sin(seed) * 0.5 + 0.5) * s
                let py = CGFloat(cos(seed * 0.7) * 0.5 + 0.5) * s
                let r = CGFloat(8 + (i % 4) * 6)

                c.setFillColor(UIColor(red: 0.06, green: 0.38, blue: 0.50, alpha: 0.10).cgColor)
                c.fillEllipse(in: CGRect(x: px - r, y: py - r, width: r * 2, height: r * 2))
            }
        }
    }

    static func waterPlane(width: CGFloat, length: CGFloat) -> SCNNode {
        let plane = SCNPlane(width: width, height: length)
        let material = SCNMaterial()

        // Procedural tiling water texture
        let tex = waterTexture()
        material.diffuse.contents = tex
        material.diffuse.wrapS = .repeat
        material.diffuse.wrapT = .repeat
        // Tile the texture across the plane for visible detail
        let tileScale = Float(max(width, length) / 30.0)
        material.diffuse.contentsTransform = SCNMatrix4MakeScale(tileScale, tileScale, 1)

        material.specular.contents = UIColor(white: 0.8, alpha: 0.5)
        material.transparency = 0.88
        material.isDoubleSided = true
        material.lightingModel = .lambert
        plane.materials = [material]
        let node = SCNNode(geometry: plane)
        node.eulerAngles.x = -.pi / 2 // lay flat
        node.name = "water"

        // Gentle looping shimmer — slow transparency oscillation + X-axis texture drift
        let shimmer = SCNAction.customAction(duration: 6.0) { node, elapsed in
            let t = elapsed / 6.0
            let val = 0.85 + 0.10 * CGFloat(sin(Double(t) * .pi * 2)) // 0.85 → 0.95 → 0.85
            node.geometry?.firstMaterial?.transparency = val
            // Very slow texture drift along X axis only (direction-independent)
            let offset = Float(t) * 0.015
            let scale = tileScale
            node.geometry?.firstMaterial?.diffuse.contentsTransform = SCNMatrix4Translate(
                SCNMatrix4MakeScale(scale, scale, 1), offset, 0, 0)
        }
        node.runAction(.repeatForever(shimmer))

        return node
    }

    // MARK: - Terrain Noise

    /// Fast deterministic hash noise for per-vertex color variation
    private static func colorNoise(x: Float, z: Float, seed: Float = 0) -> Float {
        let px = x * 0.37 + seed
        let pz = z * 0.53 + seed * 1.7
        let n = sin(px * 12.9898 + pz * 78.233) * 43758.5453
        return n - Float(Int(n)) // fractional part, -1 to 1 range
    }

    /// Multi-octave color noise for richer texture
    private static func textureNoise(x: Float, z: Float) -> Float {
        let n1 = colorNoise(x: x, z: z, seed: 0) * 0.5
        let n2 = colorNoise(x: x * 2.3, z: z * 2.3, seed: 5.7) * 0.3
        let n3 = colorNoise(x: x * 5.1, z: z * 5.1, seed: 13.2) * 0.2
        return n1 + n2 + n3
    }

    // MARK: - Terrain Mesh

    static func terrainHeight(x: Float, z: Float) -> Float {
        // Layered sine waves for organic terrain
        var h: Float = 0
        h += sin(x * 0.055 + z * 0.04) * 5.5
        h += cos(x * 0.08 - z * 0.06 + 0.7) * 3.5
        h += sin(x * 0.13 + z * 0.1 + 2.3) * 2.2
        h += sin(x * 0.22 + z * 0.17 + 5.1) * 1.0

        // Island envelope - creates water channels
        let island = (sin(z * 0.025 + x * 0.015 + 1.0) + 0.8) * 0.6
        h *= max(0, island)

        // Bias up so there's decent land coverage
        h += 1.8

        // X edge fading - terrain fades to water at strip edges
        let stripHalfWidth: Float = 40
        let xFade = max(0, min(1, (stripHalfWidth - abs(x)) / 10.0))
        h = h * xFade + (1 - xFade) * (-1)

        return h
    }

    /// Blend between two color tuples by factor t (0=a, 1=b)
    private static func lerpColor(_ a: (Float, Float, Float), _ b: (Float, Float, Float), t: Float) -> (Float, Float, Float) {
        let ct = max(0, min(1, t))
        return (a.0 + (b.0 - a.0) * ct, a.1 + (b.1 - a.1) * ct, a.2 + (b.2 - a.2) * ct)
    }

    static func terrainColor(_ h: Float, biome: TerrainBiome = .temperate, x: Float = 0, z: Float = 0) -> (Float, Float, Float) {
        // Per-vertex noise for color variation
        let n = textureNoise(x: x, z: z)           // main variation
        let n2 = colorNoise(x: x * 3.7, z: z * 3.7, seed: 99) // secondary detail

        // Height with noise for band-edge breakup (makes borders jagged/organic)
        let hNoise = h + n * 0.4

        let base: (Float, Float, Float)

        switch biome {
        case .temperate:
            // Thresholds with smooth blending at borders
            if hNoise > 5.0 {
                base = (0.15, 0.38, 0.10)   // dark green hilltop
            } else if hNoise > 4.6 {
                base = lerpColor((0.22, 0.50, 0.16), (0.15, 0.38, 0.10), t: (hNoise - 4.6) / 0.4)
            } else if hNoise > 3.0 {
                base = (0.22, 0.50, 0.16)    // green
            } else if hNoise > 2.6 {
                base = lerpColor((0.32, 0.58, 0.22), (0.22, 0.50, 0.16), t: (hNoise - 2.6) / 0.4)
            } else if hNoise > 1.5 {
                base = (0.32, 0.58, 0.22)    // light green
            } else if hNoise > 1.1 {
                base = lerpColor((0.55, 0.58, 0.35), (0.32, 0.58, 0.22), t: (hNoise - 1.1) / 0.4)
            } else if hNoise > 0.5 {
                base = (0.55, 0.58, 0.35)    // yellow-green (low)
            } else if hNoise > 0.1 {
                base = lerpColor((0.72, 0.68, 0.48), (0.55, 0.58, 0.35), t: (hNoise - 0.1) / 0.4)
            } else if hNoise > 0.0 {
                base = (0.72, 0.68, 0.48)    // sandy beach
            } else {
                base = (0.55, 0.52, 0.40)    // underwater sand
            }

        case .desert:
            if hNoise > 5.0 {
                base = (0.65, 0.35, 0.20)
            } else if hNoise > 4.6 {
                base = lerpColor((0.72, 0.55, 0.32), (0.65, 0.35, 0.20), t: (hNoise - 4.6) / 0.4)
            } else if hNoise > 3.0 {
                base = (0.72, 0.55, 0.32)
            } else if hNoise > 2.6 {
                base = lerpColor((0.82, 0.70, 0.45), (0.72, 0.55, 0.32), t: (hNoise - 2.6) / 0.4)
            } else if hNoise > 1.5 {
                base = (0.82, 0.70, 0.45)    // golden sand
            } else if hNoise > 1.1 {
                base = lerpColor((0.88, 0.78, 0.55), (0.82, 0.70, 0.45), t: (hNoise - 1.1) / 0.4)
            } else if hNoise > 0.5 {
                base = (0.88, 0.78, 0.55)
            } else if hNoise > 0.1 {
                base = lerpColor((0.78, 0.72, 0.50), (0.88, 0.78, 0.55), t: (hNoise - 0.1) / 0.4)
            } else if hNoise > 0.0 {
                base = (0.78, 0.72, 0.50)
            } else {
                base = (0.60, 0.50, 0.35)
            }

        case .arctic:
            if hNoise > 5.0 {
                base = (0.92, 0.94, 0.96)
            } else if hNoise > 4.6 {
                base = lerpColor((0.82, 0.85, 0.88), (0.92, 0.94, 0.96), t: (hNoise - 4.6) / 0.4)
            } else if hNoise > 3.0 {
                base = (0.82, 0.85, 0.88)
            } else if hNoise > 2.6 {
                base = lerpColor((0.55, 0.58, 0.62), (0.82, 0.85, 0.88), t: (hNoise - 2.6) / 0.4)
            } else if hNoise > 1.5 {
                base = (0.55, 0.58, 0.62)
            } else if hNoise > 1.1 {
                base = lerpColor((0.70, 0.75, 0.80), (0.55, 0.58, 0.62), t: (hNoise - 1.1) / 0.4)
            } else if hNoise > 0.5 {
                base = (0.70, 0.75, 0.80)
            } else if hNoise > 0.1 {
                base = lerpColor((0.60, 0.65, 0.72), (0.70, 0.75, 0.80), t: (hNoise - 0.1) / 0.4)
            } else if hNoise > 0.0 {
                base = (0.60, 0.65, 0.72)
            } else {
                base = (0.45, 0.50, 0.58)
            }

        case .volcanic:
            if hNoise > 5.0 {
                base = (0.18, 0.15, 0.13)
            } else if hNoise > 4.6 {
                base = lerpColor((0.28, 0.22, 0.18), (0.18, 0.15, 0.13), t: (hNoise - 4.6) / 0.4)
            } else if hNoise > 3.0 {
                base = (0.28, 0.22, 0.18)
            } else if hNoise > 2.6 {
                base = lerpColor((0.38, 0.28, 0.20), (0.28, 0.22, 0.18), t: (hNoise - 2.6) / 0.4)
            } else if hNoise > 1.5 {
                base = (0.38, 0.28, 0.20)
            } else if hNoise > 1.1 {
                base = lerpColor((0.55, 0.30, 0.12), (0.38, 0.28, 0.20), t: (hNoise - 1.1) / 0.4)
            } else if hNoise > 0.5 {
                base = (0.55, 0.30, 0.12)
            } else if hNoise > 0.1 {
                base = lerpColor((0.72, 0.35, 0.10), (0.55, 0.30, 0.12), t: (hNoise - 0.1) / 0.4)
            } else if hNoise > 0.0 {
                base = (0.72, 0.35, 0.10)
            } else {
                base = (0.80, 0.25, 0.05)
            }
        }

        // Apply per-vertex color noise for micro-texture
        let intensity: Float = 0.06  // subtle variation
        let r = max(0, min(1, base.0 + n * intensity + n2 * 0.03))
        let g = max(0, min(1, base.1 + n * intensity * 0.8 + n2 * 0.025))
        let b = max(0, min(1, base.2 + n * intensity * 0.6 + n2 * 0.02))
        return (r, g, b)
    }

    static func createTerrainChunk(xStart: Float, zStart: Float, chunkSize: Float = 100, segments: Int = 40, biome: TerrainBiome = .temperate) -> SCNNode {
        let segW = chunkSize / Float(segments)
        let segD = chunkSize / Float(segments)
        let cols = segments + 1

        var vertices: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var colors: [Float] = []
        var indices: [Int32] = []

        // Generate vertices
        for iz in 0...segments {
            for ix in 0...segments {
                let x = xStart + Float(ix) * segW
                let z = zStart + Float(iz) * segD
                let h = terrainHeight(x: x, z: z)

                vertices.append(SCNVector3(x, h, z))

                // Compute normal from height gradient
                let hL = terrainHeight(x: x - 0.5, z: z)
                let hR = terrainHeight(x: x + 0.5, z: z)
                let hD = terrainHeight(x: x, z: z - 0.5)
                let hU = terrainHeight(x: x, z: z + 0.5)
                let nx = hL - hR
                let nz = hD - hU
                let len = sqrt(nx * nx + 1.0 + nz * nz)
                normals.append(SCNVector3(nx / len, 1.0 / len, nz / len))

                let (r, g, b) = terrainColor(h, biome: biome, x: x, z: z)
                colors.append(contentsOf: [r, g, b, 1.0])
            }
        }

        // Generate triangle indices
        for iz in 0..<segments {
            for ix in 0..<segments {
                let tl = Int32(iz * cols + ix)
                let tr = tl + 1
                let bl = tl + Int32(cols)
                let br = bl + 1
                indices.append(contentsOf: [tl, bl, tr, tr, bl, br])
            }
        }

        // Build geometry
        let vertexSource = SCNGeometrySource(vertices: vertices)
        let normalSource = SCNGeometrySource(normals: normals)

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

        let geometry = SCNGeometry(sources: [vertexSource, normalSource, colorSource], elements: [element])
        let material = SCNMaterial()
        material.lightingModel = .lambert
        material.isDoubleSided = true
        geometry.materials = [material]

        let node = SCNNode(geometry: geometry)
        node.name = "terrain"
        return node
    }

    /// Place vegetation on a terrain chunk appropriate for the biome
    static func scatterTrees(xStart: Float, zStart: Float, chunkSize: Float = 100, count: Int = 25, biome: TerrainBiome = .temperate) -> [SCNNode] {
        var nodes: [SCNNode] = []
        let actualCount = biome.vegetationCount
        let seedVal = abs(xStart * 7.3 + zStart * 13.7 + 42)
        var rng = SeededRandom(seed: UInt64(seedVal.bitPattern))

        for i in 0..<actualCount {
            let x = xStart + Float(rng.next(max: Int(chunkSize)))
            let z = zStart + Float(rng.next(max: Int(chunkSize)))
            let h = terrainHeight(x: x, z: z)

            // Only place on land above water, not too steep
            guard h > 1.2 && h < 7.0 else { continue }

            let objHeight = 1.5 + Float(rng.next(max: 25)) / 10.0 // 1.5 to 4.0

            let node: SCNNode
            switch biome {
            case .temperate:
                node = tree(height: objHeight, variation: i)
            case .desert:
                node = cactus(height: objHeight * 0.8, variation: i)
            case .arctic:
                node = snowPine(height: objHeight, variation: i)
            case .volcanic:
                if i % 3 == 0 {
                    node = deadTree(height: objHeight * 0.7, variation: i)
                } else {
                    node = volcanicRock(size: objHeight * 0.5, variation: i)
                }
            }

            node.position = SCNVector3(x, h, z)
            nodes.append(node)
        }

        return nodes
    }

    // MARK: - New Enemy Models (Mission)

    static func truck() -> SCNNode { cachedEnemy("truck") {
        let root = SCNNode()
        root.name = "truck"

        // Cab
        let cab = SCNBox(width: 0.9, height: 0.5, length: 0.7, chamferRadius: 0.04)
        cab.firstMaterial?.diffuse.contents = UIColor(red: 0.45, green: 0.42, blue: 0.35, alpha: 1)
        let cabNode = SCNNode(geometry: cab)
        cabNode.position = SCNVector3(0, 0.4, 0.4)
        root.addChildNode(cabNode)

        // Windshield
        let windshield = SCNBox(width: 0.7, height: 0.25, length: 0.02, chamferRadius: 0.01)
        windshield.firstMaterial?.diffuse.contents = UIColor(red: 0.5, green: 0.7, blue: 0.9, alpha: 0.8)
        let wsNode = SCNNode(geometry: windshield)
        wsNode.position = SCNVector3(0, 0.55, 0.75)
        root.addChildNode(wsNode)

        // Cargo bed
        let bed = SCNBox(width: 1.0, height: 0.15, length: 1.4, chamferRadius: 0.02)
        bed.firstMaterial?.diffuse.contents = UIColor(red: 0.42, green: 0.40, blue: 0.33, alpha: 1)
        let bedNode = SCNNode(geometry: bed)
        bedNode.position = SCNVector3(0, 0.22, -0.35)
        root.addChildNode(bedNode)

        // Cargo (covered tarp)
        let cargo = SCNBox(width: 0.85, height: 0.45, length: 1.2, chamferRadius: 0.06)
        cargo.firstMaterial?.diffuse.contents = UIColor(red: 0.38, green: 0.45, blue: 0.32, alpha: 1)
        let cargoNode = SCNNode(geometry: cargo)
        cargoNode.position = SCNVector3(0, 0.52, -0.35)
        root.addChildNode(cargoNode)

        // Wheels
        for (x, z): (Float, Float) in [(-0.45, 0.35), (0.45, 0.35), (-0.45, -0.55), (0.45, -0.55)] {
            let wheel = SCNCylinder(radius: 0.14, height: 0.1)
            wheel.firstMaterial?.diffuse.contents = UIColor(red: 0.18, green: 0.18, blue: 0.18, alpha: 1)
            let wheelNode = SCNNode(geometry: wheel)
            wheelNode.eulerAngles.z = .pi / 2
            wheelNode.position = SCNVector3(x, 0.1, z)
            root.addChildNode(wheelNode)
        }

        return root
    }}

    static func radioTower() -> SCNNode { cachedEnemy("radioTower") {
        let root = SCNNode()
        root.name = "radioTower"

        // Main mast
        let mast = SCNCylinder(radius: 0.06, height: 3.5)
        mast.firstMaterial?.diffuse.contents = UIColor(red: 0.6, green: 0.6, blue: 0.58, alpha: 1)
        let mastNode = SCNNode(geometry: mast)
        mastNode.position = SCNVector3(0, 1.75, 0)
        root.addChildNode(mastNode)

        // Support struts (tripod legs)
        for angle: Float in [0, 2.094, 4.189] { // 0, 2π/3, 4π/3
            let strut = SCNCylinder(radius: 0.03, height: 2.0)
            strut.firstMaterial?.diffuse.contents = UIColor(red: 0.5, green: 0.5, blue: 0.48, alpha: 1)
            let strutNode = SCNNode(geometry: strut)
            strutNode.position = SCNVector3(cos(angle) * 0.4, 0.8, sin(angle) * 0.4)
            strutNode.eulerAngles = SCNVector3(sin(angle) * 0.3, 0, -cos(angle) * 0.3)
            root.addChildNode(strutNode)
        }

        // Antenna dish
        let dish = SCNCylinder(radius: 0.25, height: 0.05)
        dish.firstMaterial?.diffuse.contents = UIColor(red: 0.7, green: 0.7, blue: 0.68, alpha: 1)
        let dishNode = SCNNode(geometry: dish)
        dishNode.position = SCNVector3(0, 3.2, 0)
        root.addChildNode(dishNode)

        // Top antenna spike
        let spike = SCNCylinder(radius: 0.02, height: 0.6)
        spike.firstMaterial?.diffuse.contents = UIColor(red: 0.8, green: 0.2, blue: 0.15, alpha: 1)
        let spikeNode = SCNNode(geometry: spike)
        spikeNode.position = SCNVector3(0, 3.55, 0)
        root.addChildNode(spikeNode)

        // Blinking light at top
        let light = SCNSphere(radius: 0.05)
        light.firstMaterial?.diffuse.contents = UIColor.red
        light.firstMaterial?.emission.contents = UIColor(red: 1, green: 0, blue: 0, alpha: 1)
        let lightNode = SCNNode(geometry: light)
        lightNode.position = SCNVector3(0, 3.85, 0)
        let blink = SCNAction.sequence([
            .fadeOut(duration: 0.5),
            .fadeIn(duration: 0.5),
        ])
        lightNode.runAction(.repeatForever(blink))
        root.addChildNode(lightNode)

        return root
    }}

    static func rock(scale: Float = 1.0) -> SCNNode {
        let root = SCNNode()
        root.name = "rock"

        // Irregular rock shape from deformed sphere
        let rockGeo = SCNSphere(radius: CGFloat(0.5 * scale))
        rockGeo.segmentCount = 8
        rockGeo.firstMaterial?.diffuse.contents = UIColor(red: 0.48, green: 0.46, blue: 0.42, alpha: 1)
        let rockNode = SCNNode(geometry: rockGeo)
        rockNode.scale = SCNVector3(1.0, 0.6, 0.85)
        rockNode.position = SCNVector3(0, 0.2 * scale, 0)
        root.addChildNode(rockNode)

        return root
    }

    // MARK: - Mission Terrain

    /// Water level used for areas outside the mission map bounds
    private static let missionWaterDepth: Float = -2.0

    /// Sample mission heightmap with bilinear interpolation; return deep water outside bounds
    static func missionTerrainHeight(terrainData: TerrainData, x: Float, z: Float) -> Float {
        let endX = terrainData.originX + terrainData.widthX
        let endZ = terrainData.originZ + terrainData.lengthZ

        // Outside mission bounds → water
        if z < terrainData.originZ || z > endZ || x < terrainData.originX || x > endX {
            return missionWaterDepth
        }

        // Normalised position within heightmap
        let u = (x - terrainData.originX) / terrainData.widthX * Float(terrainData.segmentsX)
        let v = (z - terrainData.originZ) / terrainData.lengthZ * Float(terrainData.segmentsZ)

        let ix = Int(u)
        let iz = Int(v)
        let fx = u - Float(ix)
        let fz = v - Float(iz)

        let maxIx = terrainData.segmentsX
        let maxIz = terrainData.segmentsZ

        let ix0 = min(ix, maxIx)
        let ix1 = min(ix + 1, maxIx)
        let iz0 = min(iz, maxIz)
        let iz1 = min(iz + 1, maxIz)

        // Bilinear interpolation
        let h00 = terrainData.heightmap[iz0][ix0]
        let h10 = terrainData.heightmap[iz0][ix1]
        let h01 = terrainData.heightmap[iz1][ix0]
        let h11 = terrainData.heightmap[iz1][ix1]

        let h = h00 * (1 - fx) * (1 - fz) + h10 * fx * (1 - fz) + h01 * (1 - fx) * fz + h11 * fx * fz
        return h
    }

    /// Create a terrain chunk for mission mode — uses heightmap inside bounds, water outside
    static func createMissionTerrainChunk(terrainData: TerrainData, waterLevel: Float, xStart: Float, zStart: Float, chunkSize: Float = 100, segments: Int = 40) -> SCNNode {
        let segW = chunkSize / Float(segments)
        let segD = chunkSize / Float(segments)
        let cols = segments + 1

        var vertices: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var colors: [Float] = []
        var indices: [Int32] = []

        for iz in 0...segments {
            for ix in 0...segments {
                let x = xStart + Float(ix) * segW
                let z = zStart + Float(iz) * segD
                let h = missionTerrainHeight(terrainData: terrainData, x: x, z: z)

                vertices.append(SCNVector3(x, h, z))

                let hL = missionTerrainHeight(terrainData: terrainData, x: x - 0.5, z: z)
                let hR = missionTerrainHeight(terrainData: terrainData, x: x + 0.5, z: z)
                let hD = missionTerrainHeight(terrainData: terrainData, x: x, z: z - 0.5)
                let hU = missionTerrainHeight(terrainData: terrainData, x: x, z: z + 0.5)
                let nx = hL - hR
                let nz = hD - hU
                let len = sqrt(nx * nx + 1.0 + nz * nz)
                normals.append(SCNVector3(nx / len, 1.0 / len, nz / len))

                let (r, g, b) = terrainColor(h, x: x, z: z)
                colors.append(contentsOf: [r, g, b, 1.0])
            }
        }

        for iz in 0..<segments {
            for ix in 0..<segments {
                let tl = Int32(iz * cols + ix)
                let tr = tl + 1
                let bl = tl + Int32(cols)
                let br = bl + 1
                indices.append(contentsOf: [tl, bl, tr, tr, bl, br])
            }
        }

        let vertexSource = SCNGeometrySource(vertices: vertices)
        let normalSource = SCNGeometrySource(normals: normals)

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

        let geometry = SCNGeometry(sources: [vertexSource, normalSource, colorSource], elements: [element])
        let material = SCNMaterial()
        material.lightingModel = .lambert
        material.isDoubleSided = true
        geometry.materials = [material]

        let node = SCNNode(geometry: geometry)
        node.name = "terrain"
        return node
    }

    /// Scatter trees on a mission terrain chunk — only on land within mission bounds
    static func scatterMissionTrees(terrainData: TerrainData, xStart: Float, zStart: Float, chunkSize: Float = 100, count: Int = 25) -> [SCNNode] {
        var trees: [SCNNode] = []
        let seedVal = abs(xStart * 7.3 + zStart * 13.7 + 42)
        var rng = SeededRandom(seed: UInt64(seedVal.bitPattern))

        for i in 0..<count {
            let x = xStart + Float(rng.next(max: Int(chunkSize)))
            let z = zStart + Float(rng.next(max: Int(chunkSize)))
            let h = missionTerrainHeight(terrainData: terrainData, x: x, z: z)

            guard h > 1.2 && h < 7.0 else { continue }

            let treeHeight = 1.5 + Float(rng.next(max: 25)) / 10.0
            let t = tree(height: treeHeight, variation: i)
            t.position = SCNVector3(x, h, z)
            trees.append(t)
        }

        return trees
    }

    // MARK: - Decorative Buildings (Map Editor)

    private static var buildingTemplates: [String: SCNNode] = [:]

    private static func cachedBuilding(_ key: String, builder: () -> SCNNode) -> SCNNode {
        if let template = buildingTemplates[key] { return template.clone() }
        let template = builder()
        buildingTemplates[key] = template
        return template.clone()
    }

    /// Small residential house — low poly box with pitched roof
    static func decorativeHouse() -> SCNNode { cachedBuilding("house") {
        let root = SCNNode()
        root.name = "deco_house"

        // Body
        let body = SCNBox(width: 2.0, height: 1.6, length: 2.4, chamferRadius: 0.03)
        body.firstMaterial?.diffuse.contents = UIColor(red: 0.82, green: 0.75, blue: 0.65, alpha: 1)
        let bodyNode = SCNNode(geometry: body)
        bodyNode.position = SCNVector3(0, 0.8, 0)
        root.addChildNode(bodyNode)

        // Roof (pyramid)
        let roof = SCNPyramid(width: 2.4, height: 0.9, length: 2.8)
        roof.firstMaterial?.diffuse.contents = UIColor(red: 0.55, green: 0.22, blue: 0.18, alpha: 1)
        let roofNode = SCNNode(geometry: roof)
        roofNode.position = SCNVector3(0, 1.6, 0)
        root.addChildNode(roofNode)

        // Door
        let door = SCNBox(width: 0.4, height: 0.7, length: 0.05, chamferRadius: 0.02)
        door.firstMaterial?.diffuse.contents = UIColor(red: 0.35, green: 0.22, blue: 0.15, alpha: 1)
        let doorNode = SCNNode(geometry: door)
        doorNode.position = SCNVector3(0, 0.35, 1.21)
        root.addChildNode(doorNode)

        return root
    }}

    /// Medium office building — boxy with rows of windows
    static func decorativeOffice() -> SCNNode { cachedBuilding("office") {
        let root = SCNNode()
        root.name = "deco_office"

        // Main body
        let body = SCNBox(width: 3.0, height: 4.0, length: 2.5, chamferRadius: 0.05)
        body.firstMaterial?.diffuse.contents = UIColor(red: 0.65, green: 0.63, blue: 0.60, alpha: 1)
        let bodyNode = SCNNode(geometry: body)
        bodyNode.position = SCNVector3(0, 2.0, 0)
        root.addChildNode(bodyNode)

        // Window rows (dark strips on each side)
        for floor in 0..<3 {
            let y: Float = 0.8 + Float(floor) * 1.2
            for side: Float in [-1.51, 1.51] {
                let windowStrip = SCNBox(width: 0.02, height: 0.5, length: 2.0, chamferRadius: 0)
                windowStrip.firstMaterial?.diffuse.contents = UIColor(red: 0.3, green: 0.35, blue: 0.45, alpha: 1)
                let windowNode = SCNNode(geometry: windowStrip)
                windowNode.position = SCNVector3(side, y, 0)
                root.addChildNode(windowNode)
            }
            for side: Float in [-1.26, 1.26] {
                let windowStrip = SCNBox(width: 2.5, height: 0.5, length: 0.02, chamferRadius: 0)
                windowStrip.firstMaterial?.diffuse.contents = UIColor(red: 0.3, green: 0.35, blue: 0.45, alpha: 1)
                let windowNode = SCNNode(geometry: windowStrip)
                windowNode.position = SCNVector3(0, y, side)
                root.addChildNode(windowNode)
            }
        }

        // Flat roof cap
        let roofCap = SCNBox(width: 3.2, height: 0.15, length: 2.7, chamferRadius: 0.02)
        roofCap.firstMaterial?.diffuse.contents = UIColor(red: 0.45, green: 0.43, blue: 0.40, alpha: 1)
        let roofNode = SCNNode(geometry: roofCap)
        roofNode.position = SCNVector3(0, 4.07, 0)
        root.addChildNode(roofNode)

        return root
    }}

    /// Tall skyscraper — glass/steel tower
    static func decorativeSkyscraper() -> SCNNode { cachedBuilding("skyscraper") {
        let root = SCNNode()
        root.name = "deco_skyscraper"

        // Main tower
        let tower = SCNBox(width: 2.5, height: 10.0, length: 2.5, chamferRadius: 0.08)
        tower.firstMaterial?.diffuse.contents = UIColor(red: 0.42, green: 0.48, blue: 0.55, alpha: 1)
        tower.firstMaterial?.metalness.contents = 0.6
        tower.firstMaterial?.roughness.contents = 0.3
        let towerNode = SCNNode(geometry: tower)
        towerNode.position = SCNVector3(0, 5.0, 0)
        root.addChildNode(towerNode)

        // Glass window bands
        for floor in 0..<8 {
            let y: Float = 1.0 + Float(floor) * 1.2
            let band = SCNBox(width: 2.55, height: 0.6, length: 2.55, chamferRadius: 0.02)
            band.firstMaterial?.diffuse.contents = UIColor(red: 0.25, green: 0.32, blue: 0.42, alpha: 0.85)
            band.firstMaterial?.metalness.contents = 0.8
            let bandNode = SCNNode(geometry: band)
            bandNode.position = SCNVector3(0, y, 0)
            root.addChildNode(bandNode)
        }

        // Antenna spire on top
        let spire = SCNCylinder(radius: 0.06, height: 1.5)
        spire.firstMaterial?.diffuse.contents = UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1)
        let spireNode = SCNNode(geometry: spire)
        spireNode.position = SCNVector3(0, 10.75, 0)
        root.addChildNode(spireNode)

        return root
    }}

    /// Low wide warehouse / industrial building
    static func decorativeWarehouse() -> SCNNode { cachedBuilding("warehouse") {
        let root = SCNNode()
        root.name = "deco_warehouse"

        // Main body — wide and low
        let body = SCNBox(width: 4.0, height: 2.0, length: 3.0, chamferRadius: 0.03)
        body.firstMaterial?.diffuse.contents = UIColor(red: 0.58, green: 0.56, blue: 0.52, alpha: 1)
        let bodyNode = SCNNode(geometry: body)
        bodyNode.position = SCNVector3(0, 1.0, 0)
        root.addChildNode(bodyNode)

        // Corrugated roof (slightly curved look via a flattened cylinder)
        let roof = SCNCylinder(radius: 2.2, height: 4.0)
        roof.firstMaterial?.diffuse.contents = UIColor(red: 0.48, green: 0.45, blue: 0.42, alpha: 1)
        let roofNode = SCNNode(geometry: roof)
        roofNode.eulerAngles.z = .pi / 2
        roofNode.position = SCNVector3(0, 2.1, 0)
        roofNode.scale = SCNVector3(0.45, 1.0, 0.7)
        root.addChildNode(roofNode)

        // Roll-up door
        let door = SCNBox(width: 1.8, height: 1.5, length: 0.05, chamferRadius: 0.02)
        door.firstMaterial?.diffuse.contents = UIColor(red: 0.40, green: 0.38, blue: 0.35, alpha: 1)
        let doorNode = SCNNode(geometry: door)
        doorNode.position = SCNVector3(0, 0.75, 1.51)
        root.addChildNode(doorNode)

        return root
    }}

    /// Tall narrow control tower / water tower
    static func decorativeTower() -> SCNNode { cachedBuilding("tower") {
        let root = SCNNode()
        root.name = "deco_tower"

        // Base column
        let column = SCNBox(width: 1.0, height: 6.0, length: 1.0, chamferRadius: 0.05)
        column.firstMaterial?.diffuse.contents = UIColor(red: 0.62, green: 0.58, blue: 0.55, alpha: 1)
        let colNode = SCNNode(geometry: column)
        colNode.position = SCNVector3(0, 3.0, 0)
        root.addChildNode(colNode)

        // Top platform / observation deck
        let platform = SCNBox(width: 1.8, height: 0.8, length: 1.8, chamferRadius: 0.05)
        platform.firstMaterial?.diffuse.contents = UIColor(red: 0.50, green: 0.48, blue: 0.45, alpha: 1)
        let platNode = SCNNode(geometry: platform)
        platNode.position = SCNVector3(0, 6.4, 0)
        root.addChildNode(platNode)

        // Glass windows on top
        let glass = SCNBox(width: 1.6, height: 0.5, length: 1.6, chamferRadius: 0.02)
        glass.firstMaterial?.diffuse.contents = UIColor(red: 0.3, green: 0.38, blue: 0.50, alpha: 0.8)
        let glassNode = SCNNode(geometry: glass)
        glassNode.position = SCNVector3(0, 6.4, 0)
        root.addChildNode(glassNode)

        // Small roof
        let roof = SCNPyramid(width: 2.0, height: 0.5, length: 2.0)
        roof.firstMaterial?.diffuse.contents = UIColor(red: 0.42, green: 0.40, blue: 0.38, alpha: 1)
        let roofNode = SCNNode(geometry: roof)
        roofNode.position = SCNVector3(0, 6.8, 0)
        root.addChildNode(roofNode)

        return root
    }}

    /// Create a decorative building by type string
    static func decorativeBuilding(type: String) -> SCNNode {
        switch type {
        case "house": return decorativeHouse()
        case "office": return decorativeOffice()
        case "skyscraper": return decorativeSkyscraper()
        case "warehouse": return decorativeWarehouse()
        case "tower": return decorativeTower()
        default: return decorativeHouse()
        }
    }

    /// Place mission buildings within a terrain chunk
    static func placeMissionBuildings(buildings: [BuildingPlacement], terrainData: TerrainData, zStart: Float, chunkSize: Float = 100) -> [SCNNode] {
        var nodes: [SCNNode] = []
        let zEnd = zStart + chunkSize

        for b in buildings {
            guard b.z >= zStart && b.z < zEnd else { continue }
            let h = missionTerrainHeight(terrainData: terrainData, x: b.x, z: b.z)
            let node = decorativeBuilding(type: b.type)
            node.position = SCNVector3(b.x, h, b.z)
            if let rot = b.rotation {
                node.eulerAngles.y = rot * .pi / 180.0
            }
            nodes.append(node)
        }

        return nodes
    }
}
