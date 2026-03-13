import SpriteKit

enum SpriteGenerator {

    // MARK: - Player

    static func playerPlane() -> SKTexture {
        renderTexture(size: CGSize(width: 48, height: 56)) { ctx in
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
        }
    }

    static func playerShadow() -> SKTexture {
        renderTexture(size: CGSize(width: 48, height: 56)) { ctx in
            ctx.setFillColor(UIColor(white: 0, alpha: 0.3).cgColor)
            ctx.fillEllipse(in: CGRect(x: 6, y: 10, width: 36, height: 36))
        }
    }

    // MARK: - Enemies

    static func enemyPlane() -> SKTexture {
        renderTexture(size: CGSize(width: 44, height: 52)) { ctx in
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
        }
    }

    static func enemyShadow() -> SKTexture {
        renderTexture(size: CGSize(width: 44, height: 52)) { ctx in
            ctx.setFillColor(UIColor(white: 0, alpha: 0.25).cgColor)
            ctx.fillEllipse(in: CGRect(x: 6, y: 10, width: 32, height: 32))
        }
    }

    static func tank() -> SKTexture {
        renderTexture(size: CGSize(width: 28, height: 36)) { ctx in
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
        }
    }

    static func aaGun() -> SKTexture {
        renderTexture(size: CGSize(width: 26, height: 26)) { ctx in
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
        }
    }

    static func building() -> SKTexture {
        renderTexture(size: CGSize(width: 40, height: 40)) { ctx in
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
        }
    }

    // MARK: - Projectiles

    static func bomb() -> SKTexture {
        renderTexture(size: CGSize(width: 10, height: 18)) { ctx in
            ctx.setFillColor(rgb(0.15, 0.15, 0.15))
            ctx.fillEllipse(in: CGRect(x: 0, y: 0, width: 10, height: 14))

            // Fins
            ctx.setFillColor(rgb(0.25, 0.25, 0.25))
            let finPath = CGMutablePath()
            finPath.move(to: CGPoint(x: 0, y: 12))
            finPath.addLine(to: CGPoint(x: 5, y: 18))
            finPath.addLine(to: CGPoint(x: 10, y: 12))
            finPath.closeSubpath()
            ctx.addPath(finPath)
            ctx.fillPath()
        }
    }

    static func bombShadow() -> SKTexture {
        renderTexture(size: CGSize(width: 24, height: 24)) { ctx in
            ctx.setFillColor(UIColor(white: 0, alpha: 0.4).cgColor)
            ctx.fillEllipse(in: CGRect(x: 2, y: 2, width: 20, height: 20))
        }
    }

    static func bullet() -> SKTexture {
        renderTexture(size: CGSize(width: 2, height: 20)) { ctx in
            ctx.setFillColor(UIColor.black.cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: 2, height: 20))
        }
    }

    static func enemyBullet() -> SKTexture {
        renderTexture(size: CGSize(width: 6, height: 6)) { ctx in
            ctx.setFillColor(UIColor(red: 1.0, green: 0.3, blue: 0.2, alpha: 1.0).cgColor)
            ctx.fillEllipse(in: CGRect(x: 0, y: 0, width: 6, height: 6))
        }
    }

    // MARK: - Environment

    static func groundTile(variant: Int) -> SKTexture {
        renderTexture(size: CGSize(width: 128, height: 128)) { ctx in
            // Base ground
            let g: CGFloat = variant % 2 == 0 ? 0.50 : 0.48
            ctx.setFillColor(rgb(0.36, g, 0.28))
            ctx.fill(CGRect(x: 0, y: 0, width: 128, height: 128))

            // Grass texture dots
            ctx.setFillColor(UIColor(red: 0.32, green: 0.46, blue: 0.24, alpha: 0.4).cgColor)
            var rng = SeededRandom(seed: UInt64(variant) &+ 42)
            for _ in 0..<25 {
                let x = rng.next(max: 120)
                let y = rng.next(max: 120)
                ctx.fillEllipse(in: CGRect(x: CGFloat(x), y: CGFloat(y), width: 8, height: 8))
            }

            // Occasional road
            if variant % 4 == 0 {
                ctx.setFillColor(rgb(0.40, 0.38, 0.34))
                ctx.fill(CGRect(x: 56, y: 0, width: 16, height: 128))
                ctx.setFillColor(UIColor.white.withAlphaComponent(0.4).cgColor)
                for i in stride(from: 0, to: 128, by: 20) {
                    ctx.fill(CGRect(x: 62, y: CGFloat(i), width: 4, height: 10))
                }
            }

            // Occasional dirt patch
            if variant % 3 == 1 {
                ctx.setFillColor(rgb(0.50, 0.44, 0.32))
                ctx.fillEllipse(in: CGRect(x: 30, y: 40, width: 60, height: 40))
            }
        }
    }

    static func cloud() -> SKTexture {
        renderTexture(size: CGSize(width: 140, height: 70)) { ctx in
            let c = UIColor(white: 1.0, alpha: 0.2).cgColor
            ctx.setFillColor(c)
            ctx.fillEllipse(in: CGRect(x: 10, y: 15, width: 50, height: 30))
            ctx.fillEllipse(in: CGRect(x: 35, y: 5, width: 60, height: 45))
            ctx.fillEllipse(in: CGRect(x: 70, y: 10, width: 55, height: 40))
            ctx.fillEllipse(in: CGRect(x: 50, y: 25, width: 40, height: 30))
        }
    }

    static func treePatch() -> SKTexture {
        renderTexture(size: CGSize(width: 32, height: 32)) { ctx in
            // Tree shadow
            ctx.setFillColor(UIColor(white: 0, alpha: 0.15).cgColor)
            ctx.fillEllipse(in: CGRect(x: 6, y: 2, width: 22, height: 22))

            // Tree canopy
            ctx.setFillColor(rgb(0.15, 0.40, 0.12))
            ctx.fillEllipse(in: CGRect(x: 4, y: 6, width: 24, height: 24))

            // Lighter center
            ctx.setFillColor(rgb(0.20, 0.50, 0.18))
            ctx.fillEllipse(in: CGRect(x: 8, y: 10, width: 16, height: 16))
        }
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
            case "cluster_bomb": bgColor = UIColor(red: 0.35, green: 0.45, blue: 0.35, alpha: 1)
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
        }
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
            // Classic bomb shape
            ctx.fillEllipse(in: CGRect(x: cx - 10, y: cy - 10, width: 20, height: 28))
            let finPath = CGMutablePath()
            finPath.move(to: CGPoint(x: cx - 10, y: cy + 14))
            finPath.addLine(to: CGPoint(x: cx, y: cy + 22))
            finPath.addLine(to: CGPoint(x: cx + 10, y: cy + 14))
            finPath.closeSubpath()
            ctx.addPath(finPath)
            ctx.fillPath()

        case "mining_bomb":
            // Drill-tipped bomb
            ctx.fillEllipse(in: CGRect(x: cx - 9, y: cy - 6, width: 18, height: 22))
            let tip = CGMutablePath()
            tip.move(to: CGPoint(x: cx - 6, y: cy - 6))
            tip.addLine(to: CGPoint(x: cx, y: cy - 16))
            tip.addLine(to: CGPoint(x: cx + 6, y: cy - 6))
            tip.closeSubpath()
            ctx.addPath(tip)
            ctx.fillPath()
            ctx.setFillColor(UIColor(red: 0.7, green: 0.5, blue: 0.1, alpha: 0.8).cgColor)
            ctx.fill(CGRect(x: cx - 3, y: cy + 12, width: 6, height: 8))

        case "heavy_bomb":
            // Fat bomb
            ctx.fillEllipse(in: CGRect(x: cx - 14, y: cy - 12, width: 28, height: 32))
            ctx.fill(CGRect(x: cx - 8, y: cy + 16, width: 16, height: 6))
            ctx.setFillColor(UIColor(red: 0.8, green: 0.2, blue: 0.1, alpha: 0.6).cgColor)
            ctx.fill(CGRect(x: cx - 4, y: cy - 14, width: 8, height: 4))

        case "cluster_bomb":
            // Multiple small bombs
            let offsets: [(CGFloat, CGFloat)] = [(-10, -8), (0, -12), (10, -8), (-6, 4), (6, 4)]
            for (ox, oy) in offsets {
                ctx.fillEllipse(in: CGRect(x: cx + ox - 5, y: cy + oy - 5, width: 10, height: 14))
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
        renderTexture(size: CGSize(width: 20, height: 20)) { ctx in
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
        }
    }

    static func coinIcon() -> SKTexture {
        renderTexture(size: CGSize(width: 20, height: 20)) { ctx in
            ctx.setFillColor(UIColor(red: 0.9, green: 0.75, blue: 0.1, alpha: 1).cgColor)
            ctx.fillEllipse(in: CGRect(x: 1, y: 1, width: 18, height: 18))
            ctx.setFillColor(UIColor(red: 0.7, green: 0.55, blue: 0.05, alpha: 1).cgColor)
            ctx.fillEllipse(in: CGRect(x: 4, y: 4, width: 12, height: 12))
            ctx.setFillColor(UIColor(red: 0.95, green: 0.85, blue: 0.2, alpha: 1).cgColor)
            ctx.fillEllipse(in: CGRect(x: 6, y: 6, width: 8, height: 8))
        }
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
