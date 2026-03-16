import SpriteKit

enum SpriteGenerator {

    // MARK: - Texture Cache

    private static var textureCache: [String: SKTexture] = [:]

    private static func cached(_ key: String, generator: () -> SKTexture) -> SKTexture {
        if let tex = textureCache[key] { return tex }
        let tex = generator()
        textureCache[key] = tex
        return tex
    }

    // MARK: - Player

    static func playerPlane() -> SKTexture {
        cached("playerPlane") { renderTexture(size: CGSize(width: 48, height: 56)) { ctx in
            // Fuselage
            ctx.setFillColor(rgb(0.18, 0.42, 0.15))
            ctx.fill(CGRect(x: 19, y: 4, width: 10, height: 48))
            ctx.fillEllipse(in: CGRect(x: 17, y: 44, width: 14, height: 12))

            // Wings
            ctx.setFillColor(rgb(0.22, 0.48, 0.18))
            ctx.fill(CGRect(x: 2, y: 22, width: 44, height: 10))
            ctx.fill(CGRect(x: 0, y: 24, width: 6, height: 6))
            ctx.fill(CGRect(x: 42, y: 24, width: 6, height: 6))

            // Tail wings
            ctx.fill(CGRect(x: 10, y: 2, width: 28, height: 6))

            // Engine nacelles
            ctx.setFillColor(rgb(0.25, 0.25, 0.22))
            ctx.fillEllipse(in: CGRect(x: 8, y: 24, width: 6, height: 8))
            ctx.fillEllipse(in: CGRect(x: 34, y: 24, width: 6, height: 8))

            // Cockpit
            ctx.setFillColor(UIColor(red: 0.5, green: 0.75, blue: 0.95, alpha: 0.9).cgColor)
            ctx.fillEllipse(in: CGRect(x: 20, y: 30, width: 8, height: 12))

            // Propeller disc (translucent)
            ctx.setFillColor(UIColor(white: 0.7, alpha: 0.3).cgColor)
            ctx.fillEllipse(in: CGRect(x: 12, y: 50, width: 24, height: 6))
        }}
    }

    static func playerShadow() -> SKTexture {
        cached("playerShadow") { renderTexture(size: CGSize(width: 48, height: 56)) { ctx in
            ctx.setFillColor(UIColor(white: 0, alpha: 0.3).cgColor)
            ctx.fillEllipse(in: CGRect(x: 6, y: 10, width: 36, height: 36))
        }}
    }

    // MARK: - Enemies

    static func enemyPlane() -> SKTexture {
        cached("enemyPlane") { renderTexture(size: CGSize(width: 44, height: 52)) { ctx in
            // Fuselage (gray)
            ctx.setFillColor(rgb(0.45, 0.45, 0.43))
            ctx.fill(CGRect(x: 17, y: 4, width: 10, height: 44))
            ctx.fillEllipse(in: CGRect(x: 15, y: 0, width: 14, height: 12))

            // Wings
            ctx.setFillColor(rgb(0.50, 0.50, 0.48))
            ctx.fill(CGRect(x: 2, y: 20, width: 40, height: 8))

            // Tail
            ctx.fill(CGRect(x: 10, y: 42, width: 24, height: 6))

            // Cockpit (red tint)
            ctx.setFillColor(UIColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 0.9).cgColor)
            ctx.fillEllipse(in: CGRect(x: 19, y: 10, width: 6, height: 8))

            // Wing markings
            ctx.setFillColor(UIColor(white: 0.3, alpha: 0.5).cgColor)
            ctx.fillEllipse(in: CGRect(x: 5, y: 21, width: 6, height: 6))
            ctx.fillEllipse(in: CGRect(x: 33, y: 21, width: 6, height: 6))
        }}
    }

    static func aiFighterPlane() -> SKTexture {
        cached("aiFighterPlane") { renderTexture(size: CGSize(width: 44, height: 52)) { ctx in
            // Fuselage (dark red)
            ctx.setFillColor(rgb(0.55, 0.12, 0.10))
            ctx.fill(CGRect(x: 17, y: 4, width: 10, height: 44))
            ctx.fillEllipse(in: CGRect(x: 15, y: 0, width: 14, height: 12))

            // Wings (darker red)
            ctx.setFillColor(rgb(0.60, 0.15, 0.12))
            ctx.fill(CGRect(x: 2, y: 20, width: 40, height: 8))

            // Tail
            ctx.fill(CGRect(x: 10, y: 42, width: 24, height: 6))

            // Cockpit (bright yellow)
            ctx.setFillColor(UIColor(red: 1.0, green: 0.85, blue: 0.1, alpha: 0.9).cgColor)
            ctx.fillEllipse(in: CGRect(x: 19, y: 10, width: 6, height: 8))

            // Wing stripes (menacing)
            ctx.setFillColor(UIColor(white: 0.15, alpha: 0.6).cgColor)
            ctx.fill(CGRect(x: 4, y: 22, width: 8, height: 4))
            ctx.fill(CGRect(x: 32, y: 22, width: 8, height: 4))
        }}
    }

    static func aiFighterBullet() -> SKTexture {
        cached("aiFighterBullet") { renderTexture(size: CGSize(width: 6, height: 6)) { ctx in
            // Small yellow tracer round
            ctx.setFillColor(UIColor(red: 1.0, green: 0.9, blue: 0.2, alpha: 1.0).cgColor)
            ctx.fillEllipse(in: CGRect(x: 0, y: 0, width: 6, height: 6))
            // Bright core
            ctx.setFillColor(UIColor(red: 1.0, green: 1.0, blue: 0.8, alpha: 0.8).cgColor)
            ctx.fillEllipse(in: CGRect(x: 1, y: 1, width: 4, height: 4))
        }}
    }

    static func enemyShadow() -> SKTexture {
        cached("enemyShadow") { renderTexture(size: CGSize(width: 44, height: 52)) { ctx in
            ctx.setFillColor(UIColor(white: 0, alpha: 0.25).cgColor)
            ctx.fillEllipse(in: CGRect(x: 6, y: 10, width: 32, height: 32))
        }}
    }

    static func tank() -> SKTexture {
        cached("tank") { renderTexture(size: CGSize(width: 28, height: 36)) { ctx in
            // Tracks
            ctx.setFillColor(rgb(0.28, 0.28, 0.25))
            ctx.fill(CGRect(x: 1, y: 2, width: 7, height: 32))
            ctx.fill(CGRect(x: 20, y: 2, width: 7, height: 32))

            // Body
            ctx.setFillColor(rgb(0.42, 0.44, 0.36))
            ctx.fill(CGRect(x: 5, y: 6, width: 18, height: 24))

            // Turret
            ctx.setFillColor(rgb(0.38, 0.40, 0.32))
            ctx.fillEllipse(in: CGRect(x: 7, y: 10, width: 14, height: 14))

            // Barrel
            ctx.setFillColor(rgb(0.30, 0.30, 0.26))
            ctx.fill(CGRect(x: 12, y: 24, width: 4, height: 12))
        }}
    }

    static func aaGun() -> SKTexture {
        cached("aaGun") { renderTexture(size: CGSize(width: 26, height: 26)) { ctx in
            // Sandbag base
            ctx.setFillColor(rgb(0.55, 0.50, 0.38))
            ctx.fillEllipse(in: CGRect(x: 1, y: 1, width: 24, height: 24))

            // Platform
            ctx.setFillColor(rgb(0.38, 0.38, 0.34))
            ctx.fillEllipse(in: CGRect(x: 5, y: 5, width: 16, height: 16))

            // Gun barrels
            ctx.setFillColor(rgb(0.25, 0.25, 0.22))
            ctx.fill(CGRect(x: 8, y: 0, width: 3, height: 26))
            ctx.fill(CGRect(x: 15, y: 0, width: 3, height: 26))

            // Center mount
            ctx.setFillColor(rgb(0.45, 0.45, 0.40))
            ctx.fillEllipse(in: CGRect(x: 9, y: 9, width: 8, height: 8))
        }}
    }

    static func building() -> SKTexture {
        cached("building") { renderTexture(size: CGSize(width: 40, height: 40)) { ctx in
            // Building shadow
            ctx.setFillColor(UIColor(white: 0, alpha: 0.2).cgColor)
            ctx.fill(CGRect(x: 6, y: 0, width: 34, height: 34))

            // Building body
            ctx.setFillColor(rgb(0.55, 0.50, 0.45))
            ctx.fill(CGRect(x: 0, y: 6, width: 34, height: 34))

            // Roof
            ctx.setFillColor(rgb(0.45, 0.35, 0.30))
            ctx.fill(CGRect(x: 2, y: 8, width: 30, height: 30))

            // Windows
            ctx.setFillColor(UIColor(red: 0.7, green: 0.8, blue: 0.9, alpha: 0.7).cgColor)
            for row in 0..<2 {
                for col in 0..<3 {
                    ctx.fill(CGRect(x: 5 + col * 9, y: 12 + row * 12, width: 5, height: 5))
                }
            }
        }}
    }

    // MARK: - Projectiles

    // MARK: - Bomb Sprites (per-type)

    static func bomb(weaponId: String = "bomb") -> SKTexture {
        cached("bomb_\(weaponId)") {
            switch weaponId {
            case "mining_bomb": return miningBombSprite()
            case "heavy_bomb": return heavyBombSprite()
            case "cluster_warhead": return clusterWarheadSprite()
            default: return standardBombSprite()
            }
        }
    }

    /// Classic iron bomb — fat bulbous pear body, rounded nose, dramatic flared 3-blade tail
    private static func standardBombSprite() -> SKTexture {
        renderTexture(size: CGSize(width: 20, height: 32)) { ctx in
            let cx: CGFloat = 10

            // Bulbous pear-shaped body (fat front, tapers to rear)
            ctx.setFillColor(rgb(0.18, 0.18, 0.18))
            // Front bulge — wide
            ctx.fillEllipse(in: CGRect(x: 2, y: 0, width: 16, height: 20))
            // Rear taper — narrower ellipse overlaps
            ctx.fillEllipse(in: CGRect(x: 4, y: 12, width: 12, height: 12))

            // 3D body highlight — left-lit crescent
            ctx.setFillColor(UIColor(white: 0.32, alpha: 0.45).cgColor)
            ctx.fillEllipse(in: CGRect(x: 3, y: 1, width: 7, height: 16))

            // Subtle dark shadow on right
            ctx.setFillColor(UIColor(white: 0.08, alpha: 0.3).cgColor)
            ctx.fillEllipse(in: CGRect(x: 12, y: 3, width: 5, height: 14))

            // Rounded nose cap
            ctx.setFillColor(rgb(0.28, 0.26, 0.24))
            ctx.fillEllipse(in: CGRect(x: 5, y: 0, width: 10, height: 7))

            // Fuze nub
            ctx.setFillColor(UIColor(white: 0.42, alpha: 0.9).cgColor)
            ctx.fillEllipse(in: CGRect(x: cx - 1.5, y: 0, width: 3, height: 3))

            // Rivets along centerline
            ctx.setFillColor(UIColor(white: 0.38, alpha: 0.5).cgColor)
            for y: CGFloat in [6, 10, 14] {
                ctx.fillEllipse(in: CGRect(x: cx - 1, y: y, width: 2, height: 2))
            }

            // Tail neck — narrow section before fins
            ctx.setFillColor(rgb(0.20, 0.20, 0.20))
            ctx.fill(CGRect(x: 6, y: 18, width: 8, height: 4))

            // Tail fin assembly — 3 dramatic flared blades (like reference image)
            // Left fin blade — thick, flared outward
            ctx.setFillColor(rgb(0.25, 0.25, 0.23))
            let lFin = CGMutablePath()
            lFin.move(to: CGPoint(x: 6, y: 19))
            lFin.addLine(to: CGPoint(x: 1, y: 29))
            lFin.addLine(to: CGPoint(x: 0, y: 31))
            lFin.addLine(to: CGPoint(x: 4, y: 28))
            lFin.addLine(to: CGPoint(x: 7, y: 23))
            lFin.closeSubpath()
            ctx.addPath(lFin)
            ctx.fillPath()

            // Right fin blade
            ctx.setFillColor(rgb(0.28, 0.28, 0.26))
            let rFin = CGMutablePath()
            rFin.move(to: CGPoint(x: 14, y: 19))
            rFin.addLine(to: CGPoint(x: 19, y: 29))
            rFin.addLine(to: CGPoint(x: 20, y: 31))
            rFin.addLine(to: CGPoint(x: 16, y: 28))
            rFin.addLine(to: CGPoint(x: 13, y: 23))
            rFin.closeSubpath()
            ctx.addPath(rFin)
            ctx.fillPath()

            // Center fin blade — taller, narrower
            ctx.setFillColor(rgb(0.22, 0.22, 0.22))
            let cFin = CGMutablePath()
            cFin.move(to: CGPoint(x: cx - 2, y: 20))
            cFin.addLine(to: CGPoint(x: cx - 1, y: 32))
            cFin.addLine(to: CGPoint(x: cx + 1, y: 32))
            cFin.addLine(to: CGPoint(x: cx + 2, y: 20))
            cFin.closeSubpath()
            ctx.addPath(cFin)
            ctx.fillPath()

            // Fin edge highlights
            ctx.setStrokeColor(UIColor(white: 0.35, alpha: 0.4).cgColor)
            ctx.setLineWidth(0.5)
            ctx.move(to: CGPoint(x: 6, y: 19))
            ctx.addLine(to: CGPoint(x: 0, y: 31))
            ctx.strokePath()
            ctx.move(to: CGPoint(x: 14, y: 19))
            ctx.addLine(to: CGPoint(x: 20, y: 31))
            ctx.strokePath()
        }
    }

    /// Mining bomb — bronze drill-nose penetrator, pear body with angular tail blades
    private static func miningBombSprite() -> SKTexture {
        renderTexture(size: CGSize(width: 18, height: 34)) { ctx in
            let cx: CGFloat = 9

            // Drill tip — sharp pointed nose
            ctx.setFillColor(rgb(0.70, 0.50, 0.15))
            let tip = CGMutablePath()
            tip.move(to: CGPoint(x: cx - 5, y: 8))
            tip.addLine(to: CGPoint(x: cx, y: 0))
            tip.addLine(to: CGPoint(x: cx + 5, y: 8))
            tip.closeSubpath()
            ctx.addPath(tip)
            ctx.fillPath()

            // Drill highlight
            ctx.setFillColor(UIColor(red: 0.90, green: 0.70, blue: 0.30, alpha: 0.5).cgColor)
            let tipHL = CGMutablePath()
            tipHL.move(to: CGPoint(x: cx - 2, y: 7))
            tipHL.addLine(to: CGPoint(x: cx, y: 1))
            tipHL.addLine(to: CGPoint(x: cx + 1, y: 7))
            tipHL.closeSubpath()
            ctx.addPath(tipHL)
            ctx.fillPath()

            // Bulbous pear body — copper/bronze
            ctx.setFillColor(rgb(0.55, 0.38, 0.12))
            ctx.fillEllipse(in: CGRect(x: 1, y: 5, width: 16, height: 18))
            ctx.fillEllipse(in: CGRect(x: 3, y: 16, width: 12, height: 8))

            // 3D left highlight
            ctx.setFillColor(UIColor(red: 0.75, green: 0.55, blue: 0.22, alpha: 0.4).cgColor)
            ctx.fillEllipse(in: CGRect(x: 2, y: 6, width: 6, height: 14))

            // Spiral grooves (drill threading)
            ctx.setStrokeColor(UIColor(red: 0.38, green: 0.26, blue: 0.08, alpha: 0.6).cgColor)
            ctx.setLineWidth(1.0)
            for y in stride(from: CGFloat(9), to: 20, by: 3.5) {
                ctx.move(to: CGPoint(x: 2, y: y))
                ctx.addQuadCurve(to: CGPoint(x: 16, y: y + 2), control: CGPoint(x: 9, y: y - 2))
                ctx.strokePath()
            }

            // Tail neck
            ctx.setFillColor(rgb(0.38, 0.28, 0.10))
            ctx.fill(CGRect(x: 5, y: 21, width: 8, height: 4))

            // Angular tail blades — flared like reference
            ctx.setFillColor(rgb(0.48, 0.35, 0.12))
            // Left fin
            let lFin = CGMutablePath()
            lFin.move(to: CGPoint(x: 5, y: 22))
            lFin.addLine(to: CGPoint(x: 0, y: 32))
            lFin.addLine(to: CGPoint(x: 3, y: 30))
            lFin.addLine(to: CGPoint(x: 6, y: 25))
            lFin.closeSubpath()
            ctx.addPath(lFin)
            ctx.fillPath()
            // Right fin
            let rFin = CGMutablePath()
            rFin.move(to: CGPoint(x: 13, y: 22))
            rFin.addLine(to: CGPoint(x: 18, y: 32))
            rFin.addLine(to: CGPoint(x: 15, y: 30))
            rFin.addLine(to: CGPoint(x: 12, y: 25))
            rFin.closeSubpath()
            ctx.addPath(rFin)
            ctx.fillPath()
            // Center fin
            ctx.setFillColor(rgb(0.42, 0.30, 0.10))
            let cFin = CGMutablePath()
            cFin.move(to: CGPoint(x: cx - 1.5, y: 23))
            cFin.addLine(to: CGPoint(x: cx, y: 34))
            cFin.addLine(to: CGPoint(x: cx + 1.5, y: 23))
            cFin.closeSubpath()
            ctx.addPath(cFin)
            ctx.fillPath()
        }
    }

    /// Heavy bomb — massive fat pear body, red warning bands, huge flared tail fins
    private static func heavyBombSprite() -> SKTexture {
        renderTexture(size: CGSize(width: 26, height: 40)) { ctx in
            let cx: CGFloat = 13

            // Massive pear-shaped body — very fat
            ctx.setFillColor(rgb(0.16, 0.16, 0.16))
            ctx.fillEllipse(in: CGRect(x: 1, y: 0, width: 24, height: 26))
            ctx.fillEllipse(in: CGRect(x: 4, y: 18, width: 18, height: 10))

            // 3D highlight crescent
            ctx.setFillColor(UIColor(white: 0.28, alpha: 0.4).cgColor)
            ctx.fillEllipse(in: CGRect(x: 3, y: 1, width: 10, height: 20))

            // Dark shadow side
            ctx.setFillColor(UIColor(white: 0.06, alpha: 0.3).cgColor)
            ctx.fillEllipse(in: CGRect(x: 16, y: 4, width: 7, height: 16))

            // Rounded nose cap
            ctx.setFillColor(rgb(0.24, 0.22, 0.20))
            ctx.fillEllipse(in: CGRect(x: 6, y: 0, width: 14, height: 10))

            // Fuze nub
            ctx.setFillColor(UIColor(white: 0.45, alpha: 0.9).cgColor)
            ctx.fillEllipse(in: CGRect(x: cx - 2, y: 0, width: 4, height: 4))

            // Red warning band — thick
            ctx.setFillColor(UIColor(red: 0.78, green: 0.12, blue: 0.08, alpha: 0.85).cgColor)
            ctx.fill(CGRect(x: 2, y: 8, width: 22, height: 3))

            // Second red band
            ctx.setFillColor(UIColor(red: 0.70, green: 0.10, blue: 0.06, alpha: 0.65).cgColor)
            ctx.fill(CGRect(x: 4, y: 15, width: 18, height: 2))

            // Tail neck — wide
            ctx.setFillColor(rgb(0.18, 0.18, 0.18))
            ctx.fill(CGRect(x: 7, y: 24, width: 12, height: 5))

            // Massive flared tail fin assembly — 3 thick blades
            // Left fin — big dramatic sweep
            ctx.setFillColor(rgb(0.24, 0.24, 0.22))
            let lFin = CGMutablePath()
            lFin.move(to: CGPoint(x: 7, y: 25))
            lFin.addLine(to: CGPoint(x: 0, y: 37))
            lFin.addLine(to: CGPoint(x: 1, y: 39))
            lFin.addLine(to: CGPoint(x: 5, y: 35))
            lFin.addLine(to: CGPoint(x: 9, y: 28))
            lFin.closeSubpath()
            ctx.addPath(lFin)
            ctx.fillPath()

            // Right fin
            ctx.setFillColor(rgb(0.27, 0.27, 0.25))
            let rFin = CGMutablePath()
            rFin.move(to: CGPoint(x: 19, y: 25))
            rFin.addLine(to: CGPoint(x: 26, y: 37))
            rFin.addLine(to: CGPoint(x: 25, y: 39))
            rFin.addLine(to: CGPoint(x: 21, y: 35))
            rFin.addLine(to: CGPoint(x: 17, y: 28))
            rFin.closeSubpath()
            ctx.addPath(rFin)
            ctx.fillPath()

            // Center fin — tall blade
            ctx.setFillColor(rgb(0.20, 0.20, 0.20))
            let cFin = CGMutablePath()
            cFin.move(to: CGPoint(x: cx - 2.5, y: 26))
            cFin.addLine(to: CGPoint(x: cx - 1, y: 40))
            cFin.addLine(to: CGPoint(x: cx + 1, y: 40))
            cFin.addLine(to: CGPoint(x: cx + 2.5, y: 26))
            cFin.closeSubpath()
            ctx.addPath(cFin)
            ctx.fillPath()

            // Fin edge highlights
            ctx.setStrokeColor(UIColor(white: 0.32, alpha: 0.35).cgColor)
            ctx.setLineWidth(0.8)
            ctx.move(to: CGPoint(x: 7, y: 25))
            ctx.addLine(to: CGPoint(x: 1, y: 39))
            ctx.strokePath()
            ctx.move(to: CGPoint(x: 19, y: 25))
            ctx.addLine(to: CGPoint(x: 25, y: 39))
            ctx.strokePath()

            // Tail ring
            ctx.setStrokeColor(UIColor(white: 0.30, alpha: 0.5).cgColor)
            ctx.setLineWidth(1.5)
            ctx.strokeEllipse(in: CGRect(x: 7, y: 27, width: 12, height: 4))
        }
    }

    /// Cluster warhead — small stubby pear with flared mini-fins, olive with yellow band
    private static func clusterWarheadSprite() -> SKTexture {
        renderTexture(size: CGSize(width: 14, height: 22)) { ctx in
            let cx: CGFloat = 7

            // Small stubby pear body — olive green
            ctx.setFillColor(rgb(0.28, 0.34, 0.18))
            ctx.fillEllipse(in: CGRect(x: 1, y: 0, width: 12, height: 14))
            ctx.fillEllipse(in: CGRect(x: 3, y: 10, width: 8, height: 5))

            // 3D highlight
            ctx.setFillColor(UIColor(red: 0.38, green: 0.46, blue: 0.26, alpha: 0.4).cgColor)
            ctx.fillEllipse(in: CGRect(x: 2, y: 1, width: 5, height: 10))

            // Yellow identification band
            ctx.setFillColor(UIColor(red: 0.92, green: 0.82, blue: 0.18, alpha: 0.85).cgColor)
            ctx.fill(CGRect(x: 2, y: 5, width: 10, height: 2))

            // Tail neck
            ctx.setFillColor(rgb(0.24, 0.28, 0.16))
            ctx.fill(CGRect(x: 4, y: 13, width: 6, height: 3))

            // Flared mini tail fins — proportionally dramatic like reference
            ctx.setFillColor(rgb(0.22, 0.26, 0.14))
            // Left fin
            let lFin = CGMutablePath()
            lFin.move(to: CGPoint(x: 4, y: 14))
            lFin.addLine(to: CGPoint(x: 0, y: 20))
            lFin.addLine(to: CGPoint(x: 1, y: 21))
            lFin.addLine(to: CGPoint(x: 5, y: 17))
            lFin.closeSubpath()
            ctx.addPath(lFin)
            ctx.fillPath()
            // Right fin
            ctx.setFillColor(rgb(0.26, 0.30, 0.16))
            let rFin = CGMutablePath()
            rFin.move(to: CGPoint(x: 10, y: 14))
            rFin.addLine(to: CGPoint(x: 14, y: 20))
            rFin.addLine(to: CGPoint(x: 13, y: 21))
            rFin.addLine(to: CGPoint(x: 9, y: 17))
            rFin.closeSubpath()
            ctx.addPath(rFin)
            ctx.fillPath()
            // Center fin
            ctx.setFillColor(rgb(0.20, 0.24, 0.12))
            let cFin = CGMutablePath()
            cFin.move(to: CGPoint(x: cx - 1, y: 15))
            cFin.addLine(to: CGPoint(x: cx, y: 22))
            cFin.addLine(to: CGPoint(x: cx + 1, y: 15))
            cFin.closeSubpath()
            ctx.addPath(cFin)
            ctx.fillPath()
        }
    }

    static func bombShadow() -> SKTexture {
        cached("bombShadow") { renderTexture(size: CGSize(width: 24, height: 24)) { ctx in
            ctx.setFillColor(UIColor(white: 0, alpha: 0.4).cgColor)
            ctx.fillEllipse(in: CGRect(x: 2, y: 2, width: 20, height: 20))
        }}
    }

    static func bullet(weaponId: String = "basic_gun") -> SKTexture {
        cached("bullet_\(weaponId)") {
            switch weaponId {
            case "cannon": return cannonBulletSprite()
            case "machine_gun": return machineGunBulletSprite()
            case "autocannon": return autocannonBulletSprite()
            default: return basicBulletSprite()
            }
        }
    }

    /// Basic gun — dark tracer, slightly thicker than original
    private static func basicBulletSprite() -> SKTexture {
        renderTexture(size: CGSize(width: 6, height: 22)) { ctx in
            // Dark core
            ctx.setFillColor(rgb(0.10, 0.10, 0.10))
            ctx.fill(CGRect(x: 1, y: 0, width: 4, height: 22))
            // Slight metallic edge highlights
            ctx.setFillColor(UIColor(white: 0.35, alpha: 0.4).cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: 1, height: 22))
            ctx.fill(CGRect(x: 5, y: 0, width: 1, height: 22))
            // Dark metallic tip
            ctx.setFillColor(UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 0.8).cgColor)
            ctx.fillEllipse(in: CGRect(x: 0, y: 0, width: 6, height: 6))
        }
    }

    /// Heavy Cannon — big dark yellow slug
    private static func cannonBulletSprite() -> SKTexture {
        renderTexture(size: CGSize(width: 14, height: 30)) { ctx in
            // Dark yellow outer glow
            ctx.setFillColor(UIColor(red: 0.8, green: 0.65, blue: 0.05, alpha: 0.3).cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: 14, height: 30))
            // Dark yellow core
            ctx.setFillColor(UIColor(red: 0.7, green: 0.55, blue: 0.0, alpha: 0.95).cgColor)
            ctx.fill(CGRect(x: 3, y: 1, width: 8, height: 28))
            // Darker center line
            ctx.setFillColor(UIColor(red: 0.5, green: 0.4, blue: 0.0, alpha: 0.6).cgColor)
            ctx.fill(CGRect(x: 4, y: 1, width: 6, height: 28))
            // Dark golden tip
            ctx.setFillColor(UIColor(red: 0.85, green: 0.7, blue: 0.05, alpha: 0.9).cgColor)
            ctx.fillEllipse(in: CGRect(x: 1, y: 0, width: 12, height: 10))
        }
    }

    /// Machine gun — medium tracer with golden-amber glow trail
    private static func machineGunBulletSprite() -> SKTexture {
        renderTexture(size: CGSize(width: 20, height: 26)) { ctx in
            // Golden glow halo
            ctx.setFillColor(UIColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 0.25).cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: 20, height: 26))
            // Amber tracer core
            ctx.setFillColor(UIColor(red: 0.85, green: 0.65, blue: 0.1, alpha: 0.9).cgColor)
            ctx.fill(CGRect(x: 4, y: 0, width: 12, height: 26))
            // Bright center line
            ctx.setFillColor(UIColor(red: 1.0, green: 0.95, blue: 0.6, alpha: 0.8).cgColor)
            ctx.fill(CGRect(x: 7, y: 0, width: 6, height: 26))
            // Hot leading edge
            ctx.setFillColor(UIColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 0.9).cgColor)
            ctx.fillEllipse(in: CGRect(x: 4, y: 0, width: 12, height: 10))
        }
    }

    /// Autocannon — twin heavy golden tracers, bright and aggressive
    private static func autocannonBulletSprite() -> SKTexture {
        renderTexture(size: CGSize(width: 9, height: 22)) { ctx in
            // Wide golden glow
            ctx.setFillColor(UIColor(red: 1.0, green: 0.8, blue: 0.15, alpha: 0.3).cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: 9, height: 22))
            // Dark steel core
            ctx.setFillColor(rgb(0.15, 0.15, 0.12))
            ctx.fill(CGRect(x: 1, y: 0, width: 7, height: 22))
            // Golden hot edges
            ctx.setFillColor(UIColor(red: 1.0, green: 0.75, blue: 0.1, alpha: 0.7).cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: 1, height: 22))
            ctx.fill(CGRect(x: 8, y: 0, width: 1, height: 22))
            // Bright golden center
            ctx.setFillColor(UIColor(red: 1.0, green: 0.9, blue: 0.4, alpha: 0.6).cgColor)
            ctx.fill(CGRect(x: 3, y: 0, width: 3, height: 22))
            // Golden tip
            ctx.setFillColor(UIColor(red: 1.0, green: 0.8, blue: 0.1, alpha: 0.95).cgColor)
            ctx.fillEllipse(in: CGRect(x: 0, y: 0, width: 9, height: 8))
        }
    }

    static func enemyBullet() -> SKTexture {
        cached("enemyBullet") { renderTexture(size: CGSize(width: 11, height: 11)) { ctx in
            ctx.setFillColor(UIColor(red: 0.7, green: 0.1, blue: 0.08, alpha: 1.0).cgColor)
            ctx.fillEllipse(in: CGRect(x: 0, y: 0, width: 11, height: 11))
        }}
    }

    // MARK: - Environment

    static func groundTile(variant: Int) -> SKTexture {
        cached("groundTile_\(variant)") { renderTexture(size: CGSize(width: 128, height: 128)) { ctx in
            var rng = SeededRandom(seed: UInt64(variant) &+ 42)

            // Base ground with subtle variation patches
            let g: CGFloat = variant % 2 == 0 ? 0.50 : 0.48
            ctx.setFillColor(rgb(0.36, g, 0.28))
            ctx.fill(CGRect(x: 0, y: 0, width: 128, height: 128))

            // Large soft color variation patches (break up uniformity)
            for _ in 0..<6 {
                let px = CGFloat(rng.next(max: 128))
                let py = CGFloat(rng.next(max: 128))
                let pr = CGFloat(20 + rng.next(max: 30))
                let shade = 0.02 * CGFloat(rng.next(max: 3))
                ctx.setFillColor(UIColor(red: 0.34 + shade, green: g - 0.02 + shade, blue: 0.26 + shade, alpha: 0.3).cgColor)
                ctx.fillEllipse(in: CGRect(x: px - pr, y: py - pr, width: pr * 2, height: pr * 2))
            }

            // Grass texture dots (medium)
            ctx.setFillColor(UIColor(red: 0.32, green: 0.46, blue: 0.24, alpha: 0.4).cgColor)
            for _ in 0..<25 {
                let x = rng.next(max: 120)
                let y = rng.next(max: 120)
                ctx.fillEllipse(in: CGRect(x: CGFloat(x), y: CGFloat(y), width: 8, height: 8))
            }

            // Small bright grass flecks (fine detail)
            for _ in 0..<35 {
                let x = CGFloat(rng.next(max: 126))
                let y = CGFloat(rng.next(max: 126))
                let bright = 0.48 + CGFloat(rng.next(max: 10)) / 100.0
                ctx.setFillColor(UIColor(red: 0.30, green: bright, blue: 0.20, alpha: 0.35).cgColor)
                ctx.fillEllipse(in: CGRect(x: x, y: y, width: 3, height: 3))
            }

            // Tiny dark specks (soil/pebble texture)
            for _ in 0..<20 {
                let x = CGFloat(rng.next(max: 126))
                let y = CGFloat(rng.next(max: 126))
                ctx.setFillColor(UIColor(red: 0.28, green: 0.32, blue: 0.20, alpha: 0.25).cgColor)
                ctx.fill(CGRect(x: x, y: y, width: 2, height: 2))
            }

            // Occasional road
            if variant % 4 == 0 {
                ctx.setFillColor(rgb(0.40, 0.38, 0.34))
                ctx.fill(CGRect(x: 56, y: 0, width: 16, height: 128))
                // Road texture grit
                for _ in 0..<15 {
                    let rx = CGFloat(56 + rng.next(max: 16))
                    let ry = CGFloat(rng.next(max: 128))
                    ctx.setFillColor(UIColor(red: 0.36, green: 0.34, blue: 0.30, alpha: 0.3).cgColor)
                    ctx.fill(CGRect(x: rx, y: ry, width: 2, height: 2))
                }
                ctx.setFillColor(UIColor.white.withAlphaComponent(0.4).cgColor)
                for i in stride(from: 0, to: 128, by: 20) {
                    ctx.fill(CGRect(x: 62, y: CGFloat(i), width: 4, height: 10))
                }
            }

            // Occasional dirt patch with sandy edge
            if variant % 3 == 1 {
                // Sandy edge ring
                ctx.setFillColor(rgb(0.56, 0.50, 0.38))
                ctx.fillEllipse(in: CGRect(x: 26, y: 36, width: 68, height: 48))
                // Inner dirt
                ctx.setFillColor(rgb(0.50, 0.44, 0.32))
                ctx.fillEllipse(in: CGRect(x: 30, y: 40, width: 60, height: 40))
                // Dirt specks
                for _ in 0..<8 {
                    let dx = CGFloat(32 + rng.next(max: 56))
                    let dy = CGFloat(42 + rng.next(max: 36))
                    ctx.setFillColor(UIColor(red: 0.44, green: 0.38, blue: 0.26, alpha: 0.4).cgColor)
                    ctx.fill(CGRect(x: dx, y: dy, width: 3, height: 2))
                }
            }
        }}
    }

    static func cloud() -> SKTexture {
        cached("cloud") { renderTexture(size: CGSize(width: 140, height: 70)) { ctx in
            let c = UIColor(white: 1.0, alpha: 0.2).cgColor
            ctx.setFillColor(c)
            ctx.fillEllipse(in: CGRect(x: 10, y: 15, width: 50, height: 30))
            ctx.fillEllipse(in: CGRect(x: 35, y: 5, width: 60, height: 45))
            ctx.fillEllipse(in: CGRect(x: 70, y: 10, width: 55, height: 40))
            ctx.fillEllipse(in: CGRect(x: 50, y: 25, width: 40, height: 30))
        }}
    }

    static func treePatch() -> SKTexture {
        cached("treePatch") { renderTexture(size: CGSize(width: 32, height: 32)) { ctx in
            // Tree shadow
            ctx.setFillColor(UIColor(white: 0, alpha: 0.15).cgColor)
            ctx.fillEllipse(in: CGRect(x: 6, y: 2, width: 22, height: 22))

            // Tree canopy
            ctx.setFillColor(rgb(0.15, 0.40, 0.12))
            ctx.fillEllipse(in: CGRect(x: 4, y: 6, width: 24, height: 24))

            // Lighter center
            ctx.setFillColor(rgb(0.20, 0.50, 0.18))
            ctx.fillEllipse(in: CGRect(x: 8, y: 10, width: 16, height: 16))
        }}
    }

    // MARK: - UI

    static func buttonTexture(width: CGFloat, height: CGFloat, color: UIColor, label: String) -> SKTexture {
        renderTexture(size: CGSize(width: width, height: height)) { ctx in
            // Button background
            let rect = CGRect(x: 2, y: 2, width: width - 4, height: height - 4)
            ctx.setFillColor(color.withAlphaComponent(0.6).cgColor)
            ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.8).cgColor)
            ctx.setLineWidth(2)
            let path = CGPath(roundedRect: rect, cornerWidth: 8, cornerHeight: 8, transform: nil)
            ctx.addPath(path)
            ctx.drawPath(using: .fillStroke)

            // Label
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 14),
                .foregroundColor: UIColor.white
            ]
            let text = NSAttributedString(string: label, attributes: attrs)
            let textSize = text.size()
            let textRect = CGRect(
                x: (width - textSize.width) / 2,
                y: (height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            // Flip context for text drawing
            ctx.saveGState()
            ctx.translateBy(x: 0, y: height)
            ctx.scaleBy(x: 1, y: -1)
            let flippedRect = CGRect(
                x: textRect.origin.x,
                y: (height - textRect.origin.y - textRect.height),
                width: textRect.width,
                height: textRect.height
            )
            text.draw(in: flippedRect)
            ctx.restoreGState()
        }
    }

    // MARK: - Weapon Icons (80x80 cards)

    static func weaponIcon(for weaponId: String) -> SKTexture {
        cached("weaponIcon_\(weaponId)") {
        let s: CGFloat = 80
        return renderTexture(size: CGSize(width: s, height: s)) { ctx in
            // Card background gradient
            let bgColor: UIColor
            switch weaponId {
            case "basic_gun": bgColor = UIColor(red: 0.3, green: 0.5, blue: 0.3, alpha: 1)
            case "cannon": bgColor = UIColor(red: 0.5, green: 0.4, blue: 0.25, alpha: 1)
            case "machine_gun": bgColor = UIColor(red: 0.4, green: 0.35, blue: 0.5, alpha: 1)
            case "autocannon": bgColor = UIColor(red: 0.5, green: 0.3, blue: 0.3, alpha: 1)
            case "bomb": bgColor = UIColor(red: 0.45, green: 0.45, blue: 0.35, alpha: 1)
            case "mining_bomb": bgColor = UIColor(red: 0.55, green: 0.4, blue: 0.2, alpha: 1)
            case "heavy_bomb": bgColor = UIColor(red: 0.5, green: 0.25, blue: 0.25, alpha: 1)
            case "cluster_warhead": bgColor = UIColor(red: 0.35, green: 0.45, blue: 0.35, alpha: 1)
            case "decoy_flare": bgColor = UIColor(red: 0.6, green: 0.5, blue: 0.2, alpha: 1)
            case "missile_launcher": bgColor = UIColor(red: 0.4, green: 0.3, blue: 0.5, alpha: 1)
            default: bgColor = UIColor(white: 0.35, alpha: 1)
            }

            // Rounded card background
            let cardRect = CGRect(x: 2, y: 2, width: s - 4, height: s - 4)
            let cardPath = CGPath(roundedRect: cardRect, cornerWidth: 8, cornerHeight: 8, transform: nil)
            ctx.addPath(cardPath)
            ctx.setFillColor(bgColor.cgColor)
            ctx.fillPath()

            // Explosion/glow behind weapon
            ctx.setFillColor(UIColor(red: 1, green: 0.7, blue: 0.2, alpha: 0.3).cgColor)
            ctx.fillEllipse(in: CGRect(x: 15, y: 15, width: 50, height: 50))

            // Draw weapon silhouette
            ctx.setFillColor(UIColor(white: 0.15, alpha: 0.9).cgColor)
            drawWeaponShape(ctx: ctx, id: weaponId, bounds: CGRect(x: 15, y: 18, width: 50, height: 44))

            // Card border
            ctx.addPath(cardPath)
            ctx.setStrokeColor(UIColor(white: 0.8, alpha: 0.6).cgColor)
            ctx.setLineWidth(1.5)
            ctx.strokePath()
        }}
    }

    private static func drawWeaponShape(ctx: CGContext, id: String, bounds: CGRect) {
        let cx = bounds.midX
        let cy = bounds.midY

        switch id {
        case "basic_gun":
            // Single barrel
            ctx.fill(CGRect(x: cx - 3, y: bounds.minY, width: 6, height: bounds.height))
            ctx.fillEllipse(in: CGRect(x: cx - 6, y: cy - 4, width: 12, height: 12))

        case "cannon":
            // Wide barrel
            ctx.fill(CGRect(x: cx - 5, y: bounds.minY, width: 10, height: bounds.height))
            ctx.fill(CGRect(x: cx - 8, y: cy, width: 16, height: 14))
            ctx.fillEllipse(in: CGRect(x: cx - 4, y: bounds.minY - 2, width: 8, height: 8))

        case "machine_gun":
            // Triple barrel
            ctx.fill(CGRect(x: cx - 8, y: bounds.minY, width: 4, height: bounds.height - 8))
            ctx.fill(CGRect(x: cx - 2, y: bounds.minY, width: 4, height: bounds.height - 4))
            ctx.fill(CGRect(x: cx + 4, y: bounds.minY, width: 4, height: bounds.height - 8))
            ctx.fill(CGRect(x: cx - 10, y: cy + 4, width: 20, height: 10))

        case "autocannon":
            // Twin barrel with ammo belt
            ctx.fill(CGRect(x: cx - 7, y: bounds.minY, width: 5, height: bounds.height))
            ctx.fill(CGRect(x: cx + 2, y: bounds.minY, width: 5, height: bounds.height))
            ctx.fill(CGRect(x: cx - 9, y: cy + 2, width: 18, height: 12))
            ctx.setFillColor(UIColor(red: 0.6, green: 0.5, blue: 0.2, alpha: 0.8).cgColor)
            ctx.fill(CGRect(x: cx - 12, y: cy + 6, width: 6, height: 8))

        case "bomb":
            // Classic pear bomb with flared tail fins
            ctx.fillEllipse(in: CGRect(x: cx - 10, y: cy - 14, width: 20, height: 22))
            ctx.fillEllipse(in: CGRect(x: cx - 7, y: cy + 4, width: 14, height: 6))
            // Flared tail fins
            let bFinL = CGMutablePath()
            bFinL.move(to: CGPoint(x: cx - 6, y: cy + 6))
            bFinL.addLine(to: CGPoint(x: cx - 12, y: cy + 18))
            bFinL.addLine(to: CGPoint(x: cx - 4, y: cy + 12))
            bFinL.closeSubpath()
            ctx.addPath(bFinL); ctx.fillPath()
            let bFinR = CGMutablePath()
            bFinR.move(to: CGPoint(x: cx + 6, y: cy + 6))
            bFinR.addLine(to: CGPoint(x: cx + 12, y: cy + 18))
            bFinR.addLine(to: CGPoint(x: cx + 4, y: cy + 12))
            bFinR.closeSubpath()
            ctx.addPath(bFinR); ctx.fillPath()
            let bFinC = CGMutablePath()
            bFinC.move(to: CGPoint(x: cx - 1.5, y: cy + 8))
            bFinC.addLine(to: CGPoint(x: cx, y: cy + 20))
            bFinC.addLine(to: CGPoint(x: cx + 1.5, y: cy + 8))
            bFinC.closeSubpath()
            ctx.addPath(bFinC); ctx.fillPath()

        case "mining_bomb":
            // Drill-tipped pear bomb
            let mTip = CGMutablePath()
            mTip.move(to: CGPoint(x: cx - 6, y: cy - 8))
            mTip.addLine(to: CGPoint(x: cx, y: cy - 18))
            mTip.addLine(to: CGPoint(x: cx + 6, y: cy - 8))
            mTip.closeSubpath()
            ctx.addPath(mTip); ctx.fillPath()
            ctx.fillEllipse(in: CGRect(x: cx - 9, y: cy - 10, width: 18, height: 20))
            ctx.fillEllipse(in: CGRect(x: cx - 6, y: cy + 6, width: 12, height: 5))
            ctx.setFillColor(UIColor(red: 0.7, green: 0.5, blue: 0.1, alpha: 0.8).cgColor)
            // Tail fins
            let mFinL = CGMutablePath()
            mFinL.move(to: CGPoint(x: cx - 5, y: cy + 8))
            mFinL.addLine(to: CGPoint(x: cx - 10, y: cy + 17))
            mFinL.addLine(to: CGPoint(x: cx - 3, y: cy + 12))
            mFinL.closeSubpath()
            ctx.addPath(mFinL); ctx.fillPath()
            let mFinR = CGMutablePath()
            mFinR.move(to: CGPoint(x: cx + 5, y: cy + 8))
            mFinR.addLine(to: CGPoint(x: cx + 10, y: cy + 17))
            mFinR.addLine(to: CGPoint(x: cx + 3, y: cy + 12))
            mFinR.closeSubpath()
            ctx.addPath(mFinR); ctx.fillPath()

        case "heavy_bomb":
            // Fat pear bomb with red band and huge fins
            ctx.fillEllipse(in: CGRect(x: cx - 14, y: cy - 14, width: 28, height: 24))
            ctx.fillEllipse(in: CGRect(x: cx - 9, y: cy + 6, width: 18, height: 6))
            ctx.setFillColor(UIColor(red: 0.8, green: 0.15, blue: 0.1, alpha: 0.7).cgColor)
            ctx.fill(CGRect(x: cx - 12, y: cy - 8, width: 24, height: 3))
            ctx.setFillColor(UIColor(white: 0.15, alpha: 0.9).cgColor)
            // Huge flared fins
            let hFinL = CGMutablePath()
            hFinL.move(to: CGPoint(x: cx - 8, y: cy + 8))
            hFinL.addLine(to: CGPoint(x: cx - 15, y: cy + 20))
            hFinL.addLine(to: CGPoint(x: cx - 5, y: cy + 14))
            hFinL.closeSubpath()
            ctx.addPath(hFinL); ctx.fillPath()
            let hFinR = CGMutablePath()
            hFinR.move(to: CGPoint(x: cx + 8, y: cy + 8))
            hFinR.addLine(to: CGPoint(x: cx + 15, y: cy + 20))
            hFinR.addLine(to: CGPoint(x: cx + 5, y: cy + 14))
            hFinR.closeSubpath()
            ctx.addPath(hFinR); ctx.fillPath()
            let hFinC = CGMutablePath()
            hFinC.move(to: CGPoint(x: cx - 2, y: cy + 10))
            hFinC.addLine(to: CGPoint(x: cx, y: cy + 22))
            hFinC.addLine(to: CGPoint(x: cx + 2, y: cy + 10))
            hFinC.closeSubpath()
            ctx.addPath(hFinC); ctx.fillPath()

        case "cluster_warhead":
            // Multiple small pear bombs with tiny fins
            let offsets: [(CGFloat, CGFloat)] = [(-10, -8), (0, -12), (10, -8), (-6, 4), (6, 4)]
            for (ox, oy) in offsets {
                ctx.fillEllipse(in: CGRect(x: cx + ox - 5, y: cy + oy - 6, width: 10, height: 12))
                let miniF = CGMutablePath()
                miniF.move(to: CGPoint(x: cx + ox - 3, y: cy + oy + 4))
                miniF.addLine(to: CGPoint(x: cx + ox, y: cy + oy + 9))
                miniF.addLine(to: CGPoint(x: cx + ox + 3, y: cy + oy + 4))
                miniF.closeSubpath()
                ctx.addPath(miniF); ctx.fillPath()
            }

        case "decoy_flare":
            // Starburst
            ctx.setFillColor(UIColor(red: 1, green: 0.8, blue: 0.2, alpha: 0.9).cgColor)
            for i in 0..<6 {
                let angle = CGFloat(i) * .pi / 3
                let ex = cx + cos(angle) * 18
                let ey = cy + sin(angle) * 18
                ctx.fillEllipse(in: CGRect(x: ex - 3, y: ey - 3, width: 6, height: 6))
                ctx.fill(CGRect(x: Swift.min(cx, ex), y: Swift.min(cy, ey),
                                width: abs(ex - cx) + 2, height: abs(ey - cy) + 2))
            }
            ctx.fillEllipse(in: CGRect(x: cx - 6, y: cy - 6, width: 12, height: 12))

        case "missile_launcher":
            // Missile shape
            ctx.fill(CGRect(x: cx - 4, y: cy - 14, width: 8, height: 28))
            ctx.fillEllipse(in: CGRect(x: cx - 4, y: cy - 18, width: 8, height: 8))
            ctx.fill(CGRect(x: cx - 10, y: cy + 10, width: 20, height: 6))
            ctx.setFillColor(UIColor(red: 0.8, green: 0.2, blue: 0.1, alpha: 0.7).cgColor)
            ctx.fillEllipse(in: CGRect(x: cx - 3, y: cy + 14, width: 6, height: 8))

        default:
            ctx.fillEllipse(in: CGRect(x: cx - 10, y: cy - 10, width: 20, height: 20))
        }
    }

    static func gemIcon() -> SKTexture {
        cached("gemIcon") { renderTexture(size: CGSize(width: 20, height: 20)) { ctx in
            ctx.setFillColor(UIColor(red: 0.85, green: 0.2, blue: 0.7, alpha: 1).cgColor)
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 10, y: 0))
            path.addLine(to: CGPoint(x: 18, y: 7))
            path.addLine(to: CGPoint(x: 10, y: 20))
            path.addLine(to: CGPoint(x: 2, y: 7))
            path.closeSubpath()
            ctx.addPath(path)
            ctx.fillPath()
            // Highlight
            ctx.setFillColor(UIColor(white: 1, alpha: 0.3).cgColor)
            ctx.fill(CGRect(x: 8, y: 3, width: 5, height: 6))
        }}
    }

    static func coinIcon() -> SKTexture {
        cached("coinIcon") { renderTexture(size: CGSize(width: 20, height: 20)) { ctx in
            ctx.setFillColor(UIColor(red: 0.9, green: 0.75, blue: 0.1, alpha: 1).cgColor)
            ctx.fillEllipse(in: CGRect(x: 1, y: 1, width: 18, height: 18))
            ctx.setFillColor(UIColor(red: 0.7, green: 0.55, blue: 0.05, alpha: 1).cgColor)
            ctx.fillEllipse(in: CGRect(x: 4, y: 4, width: 12, height: 12))
            ctx.setFillColor(UIColor(red: 0.95, green: 0.85, blue: 0.2, alpha: 1).cgColor)
            ctx.fillEllipse(in: CGRect(x: 6, y: 6, width: 8, height: 8))
        }}
    }

    // MARK: - Helpers

    private static func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> CGColor {
        UIColor(red: r, green: g, blue: b, alpha: 1.0).cgColor
    }

    private static func renderTexture(size: CGSize, drawing: (CGContext) -> Void) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            drawing(context.cgContext)
        }
        return SKTexture(image: image)
    }
}

// Simple seeded random for deterministic ground tile generation
struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next(max: Int) -> Int {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Int((state >> 33) % UInt64(max))
    }
}
