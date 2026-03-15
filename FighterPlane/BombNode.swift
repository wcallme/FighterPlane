import SpriteKit

class BombNode: SKNode {

    private let bombSprite: SKSpriteNode
    private let shadowSprite: SKSpriteNode
    private let fallDuration: TimeInterval
    private var elapsed: TimeInterval = 0
    private var hasExploded = false
    private let weaponId: String

    // Momentum inherited from the plane at drop time
    private let lateralMomentum: CGFloat   // horizontal velocity (from player left/right movement)
    private let forwardMomentum: CGFloat   // forward velocity (from plane speed over ground)

    // Animation state
    private var spinRate: CGFloat = 0       // radians/sec for spinning bombs
    private var wobblePhase: CGFloat = 0    // phase for wobble animation
    private var trailEmitter: SKEmitterNode?

    /// Called when the bomb reaches the ground
    var onImpact: ((CGPoint) -> Void)?

    init(startPosition: CGPoint, groundOffset: CGPoint, weaponId: String = "bomb",
         playerVelocityX: CGFloat = 0, scrollSpeed: CGFloat = 120) {
        self.weaponId = weaponId
        self.lateralMomentum = playerVelocityX
        // Forward momentum determines arc height — bomb carries plane's forward speed
        self.forwardMomentum = scrollSpeed

        bombSprite = SKSpriteNode(texture: SpriteGenerator.bomb(weaponId: weaponId))
        shadowSprite = SKSpriteNode(texture: SpriteGenerator.bombShadow())
        fallDuration = GameConfig.bombFallDuration

        super.init()

        name = "bomb"

        // Shadow starts AHEAD of the drop point — the bomb's forward momentum
        // carries it forward relative to the ground before gravity wins
        let forwardShadowOffset = scrollSpeed * CGFloat(fallDuration) * 0.25
        let lateralShadowOffset = playerVelocityX * CGFloat(fallDuration) * 0.15
        let shadowStart = CGPoint(
            x: groundOffset.x + lateralShadowOffset,
            y: groundOffset.y + forwardShadowOffset
        )
        shadowSprite.position = shadowStart
        shadowSprite.zPosition = ZLayer.shadows.rawValue
        shadowSprite.setScale(0.4)
        shadowSprite.alpha = 0.3
        addChild(shadowSprite)

        // Bomb starts at plane position (local origin), flipped so nose points downward
        bombSprite.position = .zero
        bombSprite.zPosition = ZLayer.bombs.rawValue
        bombSprite.yScale = -1.0
        addChild(bombSprite)

        position = startPosition

        // Set up per-type animations
        setupBombAnimation()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    // MARK: - Per-type animation setup

    private func setupBombAnimation() {
        switch weaponId {
        case "mining_bomb":
            // Mining bomb spins like a drill as it falls
            spinRate = .pi * 6  // 3 full rotations per second

        case "heavy_bomb":
            // Heavy bomb has a smoke trail and slight wobble
            wobblePhase = CGFloat.random(in: 0...(.pi * 2))
            addSmokeTrail(color: UIColor(white: 0.4, alpha: 0.5), birthRate: 15, size: 4)

        case "cluster_bomb":
            // Cluster bomblets tumble erratically
            spinRate = .pi * 3
            wobblePhase = CGFloat.random(in: 0...(.pi * 2))

        default:
            // Standard bomb — gentle nose-down rotation, faint trail
            addSmokeTrail(color: UIColor(white: 0.5, alpha: 0.3), birthRate: 8, size: 3)
        }
    }

    private func addSmokeTrail(color: UIColor, birthRate: CGFloat, size: CGFloat) {
        let emitter = SKEmitterNode()
        emitter.particleBirthRate = birthRate
        emitter.particleLifetime = 0.4
        emitter.particleLifetimeRange = 0.15
        emitter.particleSize = CGSize(width: size, height: size)
        emitter.particleColor = color
        emitter.particleColorBlendFactor = 1.0
        emitter.particleAlpha = 0.6
        emitter.particleAlphaSpeed = -1.5
        emitter.particleSpeed = 5
        emitter.particleSpeedRange = 3
        emitter.emissionAngle = .pi / 2  // emit upward (behind the falling bomb visually)
        emitter.emissionAngleRange = .pi / 4
        emitter.particleScaleSpeed = -0.5
        emitter.zPosition = ZLayer.bombs.rawValue - 0.1
        emitter.targetNode = self // particles stay in world space
        bombSprite.addChild(emitter)
        trailEmitter = emitter
    }

    func update(deltaTime: TimeInterval, scrollSpeed: CGFloat) {
        guard !hasExploded else { return }

        elapsed += deltaTime

        // Shadow scrolls with the ground
        shadowSprite.position.y -= scrollSpeed * CGFloat(deltaTime)

        let t = Swift.min(elapsed / fallDuration, 1.0)
        let easedT = t * t // quadratic ease-in (gravity acceleration)

        // === BALLISTIC TRAJECTORY WITH INHERITED MOMENTUM ===
        //
        // The bomb inherits the plane's velocity when released. Instead of
        // lerping straight to the shadow, it follows a ballistic arc:
        //   - Forward arc: bomb drifts forward (upward on screen) before
        //     gravity curves it back down to the impact point.
        //   - Lateral drift: bomb carries any horizontal movement from the
        //     player banking left/right at drop time.
        //
        // Both offsets use t*(1-t²) which peaks around t≈0.58 and returns
        // to zero at t=1, so the bomb converges exactly to the shadow.

        // Forward arc: visible forward momentum that peaks mid-fall
        let arcScale = forwardMomentum * CGFloat(fallDuration) * 1.1
        let forwardArc = arcScale * CGFloat(t) * CGFloat(1.0 - easedT)

        // Lateral drift: horizontal momentum that decays over the fall
        let lateralScale = lateralMomentum * CGFloat(fallDuration) * 0.5
        let lateralDrift = lateralScale * CGFloat(t) * CGFloat(1.0 - easedT)

        // Base pull toward shadow (gravity) + momentum offsets
        bombSprite.position = CGPoint(
            x: shadowSprite.position.x * easedT + lateralDrift,
            y: shadowSprite.position.y * easedT + forwardArc
        )

        // Bomb shrinks as it "falls away" from camera (preserve vertical flip)
        let fallScale = 1.0 - 0.4 * easedT
        bombSprite.xScale = fallScale
        bombSprite.yScale = -fallScale

        // Shadow grows and darkens as bomb approaches ground
        shadowSprite.setScale(0.4 + 0.6 * easedT)
        shadowSprite.alpha = 0.3 + 0.4 * easedT

        // Per-type falling animations
        updateBombAnimation(deltaTime: deltaTime, t: t, easedT: easedT)

        // Explode when bomb reaches ground
        if t >= 1.0 {
            explode()
        }
    }

    private func updateBombAnimation(deltaTime: TimeInterval, t: Double, easedT: Double) {
        switch weaponId {
        case "mining_bomb":
            // Drill spin — accelerates as it falls
            let currentSpin = spinRate * CGFloat(1.0 + easedT * 2.0)
            bombSprite.zRotation += currentSpin * CGFloat(deltaTime)

        case "heavy_bomb":
            // Slow ominous wobble that dampens as it nears ground
            wobblePhase += CGFloat(deltaTime) * 4.0
            let wobbleAmount = CGFloat(0.08 * (1.0 - easedT))
            bombSprite.zRotation = sin(wobblePhase) * wobbleAmount

        case "cluster_bomb":
            // Erratic tumble
            bombSprite.zRotation += spinRate * CGFloat(deltaTime)
            wobblePhase += CGFloat(deltaTime) * 8.0
            let jitter = sin(wobblePhase) * CGFloat(1.5 * (1.0 - easedT))
            bombSprite.position.x += jitter * CGFloat(deltaTime)

        default:
            // Bomb tips to follow its trajectory — initially level (riding momentum),
            // then pitching nose-down as gravity takes over
            let noseDown = CGFloat(easedT) * 0.5
            let lateralTilt = lateralMomentum * 0.001 * CGFloat(1.0 - easedT)
            bombSprite.zRotation = noseDown + lateralTilt
        }
    }

    private func explode() {
        guard !hasExploded else { return }
        hasExploded = true

        let worldPos = CGPoint(
            x: position.x + shadowSprite.position.x,
            y: position.y + shadowSprite.position.y
        )
        onImpact?(worldPos)

        // Remove after brief delay for explosion to play
        run(.sequence([
            .wait(forDuration: 0.1),
            .removeFromParent()
        ]))
    }
}
