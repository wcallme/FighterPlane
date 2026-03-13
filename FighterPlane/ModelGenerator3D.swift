import SceneKit
import UIKit

enum ModelGenerator3D {

    // MARK: - Player Plane

    static func playerPlane() -> SCNNode {
        let root = SCNNode()
        root.name = "player"

        // Fuselage
        let fuselage = SCNBox(width: 0.8, height: 0.35, length: 2.8, chamferRadius: 0.12)
        fuselage.firstMaterial?.diffuse.contents = UIColor(red: 0.18, green: 0.42, blue: 0.15, alpha: 1)
        let fuselageNode = SCNNode(geometry: fuselage)
        root.addChildNode(fuselageNode)

        // Nose cone
        let nose = SCNCone(topRadius: 0, bottomRadius: 0.35, height: 0.8)
        nose.firstMaterial?.diffuse.contents = UIColor(red: 0.22, green: 0.48, blue: 0.18, alpha: 1)
        let noseNode = SCNNode(geometry: nose)
        noseNode.eulerAngles.x = -.pi / 2
        noseNode.position = SCNVector3(0, 0, 1.8)
        root.addChildNode(noseNode)

        // Wings
        let wing = SCNBox(width: 5.5, height: 0.08, length: 1.1, chamferRadius: 0.03)
        wing.firstMaterial?.diffuse.contents = UIColor(red: 0.22, green: 0.48, blue: 0.18, alpha: 1)
        let wingNode = SCNNode(geometry: wing)
        wingNode.position = SCNVector3(0, 0.05, -0.1)
        root.addChildNode(wingNode)

        // Tail wings
        let tail = SCNBox(width: 2.2, height: 0.06, length: 0.55, chamferRadius: 0.02)
        tail.firstMaterial?.diffuse.contents = UIColor(red: 0.22, green: 0.48, blue: 0.18, alpha: 1)
        let tailNode = SCNNode(geometry: tail)
        tailNode.position = SCNVector3(0, 0.15, -1.3)
        root.addChildNode(tailNode)

        // Vertical stabilizer
        let vStab = SCNBox(width: 0.08, height: 0.7, length: 0.55, chamferRadius: 0.02)
        vStab.firstMaterial?.diffuse.contents = UIColor(red: 0.2, green: 0.45, blue: 0.16, alpha: 1)
        let vStabNode = SCNNode(geometry: vStab)
        vStabNode.position = SCNVector3(0, 0.45, -1.3)
        root.addChildNode(vStabNode)

        // Cockpit
        let cockpit = SCNSphere(radius: 0.28)
        cockpit.firstMaterial?.diffuse.contents = UIColor(red: 0.5, green: 0.75, blue: 0.95, alpha: 0.85)
        cockpit.firstMaterial?.transparency = 0.85
        let cockpitNode = SCNNode(geometry: cockpit)
        cockpitNode.position = SCNVector3(0, 0.3, 0.4)
        root.addChildNode(cockpitNode)

        // Engine nacelles
        for x: Float in [-1.3, 1.3] {
            let engine = SCNCylinder(radius: 0.18, height: 0.7)
            engine.firstMaterial?.diffuse.contents = UIColor(red: 0.25, green: 0.25, blue: 0.22, alpha: 1)
            let engineNode = SCNNode(geometry: engine)
            engineNode.eulerAngles.x = .pi / 2
            engineNode.position = SCNVector3(x, 0, 0.3)
            root.addChildNode(engineNode)

            // Propeller disc
            let prop = SCNCylinder(radius: 0.4, height: 0.03)
            prop.firstMaterial?.diffuse.contents = UIColor(white: 0.5, alpha: 0.4)
            prop.firstMaterial?.transparency = 0.4
            let propNode = SCNNode(geometry: prop)
            propNode.eulerAngles.x = .pi / 2
            propNode.position = SCNVector3(x, 0, 0.7)
            propNode.runAction(.repeatForever(.rotateBy(x: 0, y: 0, z: .pi * 2, duration: 0.08)))
            root.addChildNode(propNode)
        }

        return root
    }

    // MARK: - Enemy Plane

    static func enemyPlane() -> SCNNode {
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

        // Rotate to face -Z (toward player)
        root.eulerAngles.y = .pi

        return root
    }

    // MARK: - Ground Enemies

    static func tank() -> SCNNode {
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
    }

    static func aaGun() -> SCNNode {
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
    }

    static func building() -> SCNNode {
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
    }

    // MARK: - SAM Launcher

    static func samLauncher() -> SCNNode {
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

        return root
    }

    static func samMissile() -> SCNNode {
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

        return root
    }

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

    // MARK: - Projectiles

    static func playerBullet() -> SCNNode {
        // Very thin, long black line — like a tracer streak
        let stick = SCNCylinder(radius: 0.01, height: 2.5)
        stick.firstMaterial?.diffuse.contents = UIColor.black
        stick.firstMaterial?.lightingModel = .constant
        let node = SCNNode(geometry: stick)
        // Rotate so the stick points along Z (direction of travel)
        node.eulerAngles.x = .pi / 2
        node.name = "playerBullet"
        return node
    }

    static func enemyBullet() -> SCNNode {
        let sphere = SCNSphere(radius: 0.1)
        sphere.firstMaterial?.diffuse.contents = UIColor(red: 1.0, green: 0.3, blue: 0.2, alpha: 1)
        sphere.firstMaterial?.emission.contents = UIColor(red: 1.0, green: 0.2, blue: 0.1, alpha: 0.5)
        let node = SCNNode(geometry: sphere)
        node.name = "enemyBullet"
        return node
    }

    static func bomb3D() -> SCNNode {
        let root = SCNNode()
        root.name = "bomb3D"

        let body = SCNCapsule(capRadius: 0.15, height: 0.5)
        body.firstMaterial?.diffuse.contents = UIColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1)
        let bodyNode = SCNNode(geometry: body)
        root.addChildNode(bodyNode)

        // Fins
        let fin = SCNBox(width: 0.35, height: 0.02, length: 0.15, chamferRadius: 0.01)
        fin.firstMaterial?.diffuse.contents = UIColor(red: 0.25, green: 0.25, blue: 0.25, alpha: 1)
        let fin1 = SCNNode(geometry: fin)
        fin1.position = SCNVector3(0, 0.2, 0)
        root.addChildNode(fin1)
        let fin2 = SCNNode(geometry: fin)
        fin2.eulerAngles.y = .pi / 2
        fin2.position = SCNVector3(0, 0.2, 0)
        root.addChildNode(fin2)

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

    // MARK: - Water

    static func waterPlane(width: CGFloat, length: CGFloat) -> SCNNode {
        let plane = SCNPlane(width: width, height: length)
        let material = SCNMaterial()
        material.diffuse.contents = UIColor(red: 0.15, green: 0.45, blue: 0.7, alpha: 0.9)
        material.specular.contents = UIColor(white: 0.8, alpha: 0.5)
        material.transparency = 0.9
        material.isDoubleSided = true
        material.lightingModel = .lambert
        plane.materials = [material]
        let node = SCNNode(geometry: plane)
        node.eulerAngles.x = -.pi / 2 // lay flat
        node.name = "water"
        return node
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

    static func terrainColor(_ h: Float) -> (Float, Float, Float) {
        if h > 5.0 { return (0.15, 0.38, 0.10) }   // dark green hilltop
        if h > 3.0 { return (0.22, 0.50, 0.16) }    // green
        if h > 1.5 { return (0.32, 0.58, 0.22) }    // light green
        if h > 0.5 { return (0.55, 0.58, 0.35) }    // yellow-green (low)
        if h > 0.0 { return (0.72, 0.68, 0.48) }    // sandy beach
        return (0.55, 0.52, 0.40)                      // underwater sand
    }

    static func createTerrainChunk(xStart: Float, zStart: Float, chunkSize: Float = 100, segments: Int = 40) -> SCNNode {
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

                let (r, g, b) = terrainColor(h)
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

    /// Place trees on a terrain chunk, returns array of tree nodes
    static func scatterTrees(xStart: Float, zStart: Float, chunkSize: Float = 100, count: Int = 25) -> [SCNNode] {
        var trees: [SCNNode] = []
        let seedVal = abs(xStart * 7.3 + zStart * 13.7 + 42)
        var rng = SeededRandom(seed: UInt64(seedVal.bitPattern))

        for i in 0..<count {
            let x = xStart + Float(rng.next(max: Int(chunkSize)))
            let z = zStart + Float(rng.next(max: Int(chunkSize)))
            let h = terrainHeight(x: x, z: z)

            // Only place on land above water, not too steep
            guard h > 1.2 && h < 7.0 else { continue }

            let treeHeight = 1.5 + Float(rng.next(max: 25)) / 10.0 // 1.5 to 4.0
            let t = tree(height: treeHeight, variation: i)
            t.position = SCNVector3(x, h, z)
            trees.append(t)
        }

        return trees
    }
}
