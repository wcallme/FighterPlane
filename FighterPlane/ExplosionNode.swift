import SpriteKit

class ExplosionNode: SKNode {

    enum ExplosionSize {
        case small   // bullet hit
        case medium  // enemy destroyed
        case large   // bomb impact

        var particleCount: Int {
            switch self {
            case .small: return 6
            case .medium: return 12
            case .large: return 20
            }
        }

        var radius: CGFloat {
            switch self {
            case .small: return 15
            case .medium: return 25
            case .large: return 40
            }
        }

        var duration: TimeInterval {
            switch self {
            case .small: return 0.3
            case .medium: return 0.5
            case .large: return 0.8
            }
        }
    }

    init(at position: CGPoint, size: ExplosionSize) {
        super.init()

        self.position = position
        zPosition = ZLayer.explosions.rawValue
        name = "explosion"

        createExplosion(size: size)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    private func createExplosion(size: ExplosionSize) {
        // Central flash
        let flash = SKShapeNode(circleOfRadius: size.radius * 0.8)
        flash.fillColor = .white
        flash.strokeColor = .clear
        flash.alpha = 0.9
        addChild(flash)

        flash.run(.sequence([
            .group([
                .scale(to: 1.5, duration: size.duration * 0.3),
                .fadeOut(withDuration: size.duration * 0.3)
            ]),
            .removeFromParent()
        ]))

        // Fire ball
        let fireball = SKShapeNode(circleOfRadius: size.radius)
        fireball.fillColor = SKColor(red: 1.0, green: 0.6, blue: 0.1, alpha: 0.9)
        fireball.strokeColor = .clear
        addChild(fireball)

        fireball.run(.sequence([
            .group([
                .scale(to: 2.0, duration: size.duration * 0.5),
                .fadeOut(withDuration: size.duration * 0.6)
            ]),
            .removeFromParent()
        ]))

        // Smoke ring
        let smoke = SKShapeNode(circleOfRadius: size.radius * 0.6)
        smoke.fillColor = SKColor(white: 0.3, alpha: 0.6)
        smoke.strokeColor = .clear
        addChild(smoke)

        smoke.run(.sequence([
            .wait(forDuration: size.duration * 0.2),
            .group([
                .scale(to: 3.0, duration: size.duration * 0.8),
                .fadeOut(withDuration: size.duration * 0.8)
            ]),
            .removeFromParent()
        ]))

        // Debris particles
        for _ in 0..<size.particleCount {
            let particle = SKShapeNode(circleOfRadius: CGFloat.random(in: 1...3))
            particle.fillColor = [
                SKColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 1.0),
                SKColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 1.0),
                SKColor(red: 0.8, green: 0.3, blue: 0.0, alpha: 1.0),
                SKColor(white: 0.2, alpha: 0.8)
            ].randomElement()!
            particle.strokeColor = .clear
            particle.position = .zero
            addChild(particle)

            let angle = CGFloat.random(in: 0...(.pi * 2))
            let distance = CGFloat.random(in: size.radius...(size.radius * 2.5))
            let dest = CGPoint(x: cos(angle) * distance, y: sin(angle) * distance)
            let duration = size.duration * Double.random(in: 0.5...1.0)

            particle.run(.sequence([
                .group([
                    .move(to: dest, duration: duration),
                    .fadeOut(withDuration: duration),
                    .scale(to: 0.1, duration: duration)
                ]),
                .removeFromParent()
            ]))
        }

        // Ground scorch mark for bomb explosions
        if size == .large {
            let scorch = SKShapeNode(ellipseOf: CGSize(width: size.radius * 2, height: size.radius * 1.5))
            scorch.fillColor = SKColor(red: 0.15, green: 0.15, blue: 0.10, alpha: 0.4)
            scorch.strokeColor = .clear
            scorch.zPosition = -1
            addChild(scorch)

            scorch.run(.sequence([
                .fadeOut(withDuration: 3.0),
                .removeFromParent()
            ]))
        }

        // Remove self after everything is done
        run(.sequence([
            .wait(forDuration: size.duration + 0.5),
            .run { [weak self] in
                // Only remove if no scorch marks remain
                if size != .large {
                    self?.removeFromParent()
                }
            }
        ]))

        if size == .large {
            run(.sequence([
                .wait(forDuration: 3.5),
                .removeFromParent()
            ]))
        }
    }

    // MARK: - Screen Shake Helper

    static func shakeScreen(scene: SKScene, intensity: CGFloat = 4, duration: TimeInterval = 0.3) {
        guard let camera = scene.camera else { return }

        // Cancel any existing shake first
        camera.removeAction(forKey: "screenShake")

        let restPosition = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2)
        let shakeCount = Int(duration / 0.04)
        var actions: [SKAction] = []

        for _ in 0..<shakeCount {
            let dx = CGFloat.random(in: -intensity...intensity)
            let dy = CGFloat.random(in: -intensity...intensity)
            actions.append(.move(to: CGPoint(x: restPosition.x + dx,
                                             y: restPosition.y + dy), duration: 0.02))
        }
        // Always return to rest position at end
        actions.append(.move(to: restPosition, duration: 0.02))

        camera.run(.sequence(actions), withKey: "screenShake")
    }
}
