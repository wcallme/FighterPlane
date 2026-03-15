import SpriteKit

class BombNode: SKNode {

    private let bombSprite: SKSpriteNode
    private let shadowSprite: SKSpriteNode
    private let fallDuration: TimeInterval
    private var elapsed: TimeInterval = 0
    private var hasExploded = false
    private let weaponId: String

    // Inherited momentum from the plane's velocity vector at drop time.
    // These define the direction and magnitude of the parabolic arc.
    //   momentumX = lateral banking speed (left/right)
    //   momentumY = forward flight speed (always positive — plane flies north)
    private let momentumX: CGFloat
    private let momentumY: CGFloat

    // Ground-relative shadow starting offset
    private let initialShadowPos: CGPoint

    // Animation state
    private var spinRate: CGFloat = 0
    private var wobblePhase: CGFloat = 0
    private var trailEmitter: SKEmitterNode?

    /// Called when the bomb reaches the ground
    var onImpact: ((CGPoint) -> Void)?

    init(startPosition: CGPoint, groundOffset: CGPoint, weaponId: String = "bomb",
         playerVelocityX: CGFloat = 0, scrollSpeed: CGFloat = 120) {
        self.weaponId = weaponId

        // The plane's world-space velocity vector at drop time:
        //   forward = scrollSpeed (the plane is always flying north at this speed)
        //   lateral = playerVelocityX (banking left/right)
        //
        // The bomb inherits this full velocity vector. In real physics, a bomb
        // released from a plane flying at 45° upward-right continues in that
        // direction before gravity curves it into a parabolic arc downward.
        //
        // We display this as a visible arc on screen: the bomb drifts in the
        // plane's heading direction, peaks, then falls to the impact point.
        self.momentumX = playerVelocityX
        self.momentumY = scrollSpeed

        bombSprite = SKSpriteNode(texture: SpriteGenerator.bomb(weaponId: weaponId))
        shadowSprite = SKSpriteNode(texture: SpriteGenerator.bombShadow())
        initialShadowPos = groundOffset
        fallDuration = GameConfig.bombFallDuration

        super.init()

        name = "bomb"

        shadowSprite.position = groundOffset
        shadowSprite.zPosition = ZLayer.shadows.rawValue
        shadowSprite.setScale(0.4)
        shadowSprite.alpha = 0.3
        addChild(shadowSprite)

        bombSprite.position = .zero
        bombSprite.zPosition = ZLayer.bombs.rawValue
        bombSprite.yScale = -1.0
        addChild(bombSprite)

        position = startPosition

        setupBombAnimation()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    // MARK: - Per-type animation setup

    private func setupBombAnimation() {
        switch weaponId {
        case "mining_bomb":
            spinRate = .pi * 6

        case "heavy_bomb":
            wobblePhase = CGFloat.random(in: 0...(.pi * 2))
            addSmokeTrail(color: UIColor(white: 0.4, alpha: 0.5), birthRate: 15, size: 4)

        case "cluster_bomb":
            spinRate = .pi * 3
            wobblePhase = CGFloat.random(in: 0...(.pi * 2))

        default:
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
        emitter.emissionAngle = .pi / 2
        emitter.emissionAngleRange = .pi / 4
        emitter.particleScaleSpeed = -0.5
        emitter.zPosition = ZLayer.bombs.rawValue - 0.1
        emitter.targetNode = self.scene ?? self
        bombSprite.addChild(emitter)
        trailEmitter = emitter
    }

    func update(deltaTime: TimeInterval, scrollSpeed: CGFloat) {
        guard !hasExploded else { return }

        elapsed += deltaTime

        let t = CGFloat(Swift.min(elapsed / fallDuration, 1.0))
        let easedT = t * t  // quadratic ease-in (gravity acceleration)

        // === SHADOW: stays on the ground, scrolls with terrain ===
        shadowSprite.position = CGPoint(
            x: initialShadowPos.x,
            y: initialShadowPos.y - scrollSpeed * CGFloat(elapsed)
        )

        // === BOMB SPRITE: parabolic arc from drop point to impact ===
        //
        // Real projectile physics: an object dropped from a moving vehicle
        // inherits the vehicle's velocity vector. It follows a parabolic
        // trajectory — drifting in the vehicle's direction before gravity
        // curves it back down.
        //
        // We compute this as:
        //   base = linear interpolation from origin (drop) to shadow (impact)
        //   arc  = parabolic hump in the direction of the plane's heading
        //
        // The arc uses 4*t*(1-t) which peaks at 1.0 when t=0.5, creating
        // a smooth bulge that departs from the linear path mid-fall then
        // converges back to the impact point at t=1.

        // Linear path from drop point (0,0) to shadow (impact)
        let baseX = shadowSprite.position.x * easedT
        let baseY = shadowSprite.position.y * easedT

        // Parabolic arc: peaks at t=0.5 with value 1.0, zero at t=0 and t=1
        let arcFactor = 4.0 * t * (1.0 - t)

        // Arc magnitude scales with momentum — faster plane = bigger arc.
        // Forward (Y) arc: the plane's forward speed creates upward drift.
        // Lateral (X) arc: banking creates sideways drift.
        let forwardArc = momentumY * CGFloat(fallDuration) * 0.35 * arcFactor
        let lateralArc = momentumX * CGFloat(fallDuration) * 0.2 * arcFactor

        bombSprite.position = CGPoint(
            x: baseX + lateralArc,
            y: baseY + forwardArc
        )

        // Bomb shrinks as it "falls away" from camera (preserve vertical flip)
        let fallScale = 1.0 - 0.4 * easedT
        bombSprite.xScale = fallScale
        bombSprite.yScale = -fallScale

        // Shadow grows and darkens as bomb approaches ground
        shadowSprite.setScale(0.4 + 0.6 * easedT)
        shadowSprite.alpha = 0.3 + 0.4 * easedT

        // Per-type falling animations
        updateBombAnimation(deltaTime: deltaTime, t: Double(t), easedT: Double(easedT))

        if t >= 1.0 {
            explode()
        }
    }

    private func updateBombAnimation(deltaTime: TimeInterval, t: Double, easedT: Double) {
        switch weaponId {
        case "mining_bomb":
            let currentSpin = spinRate * CGFloat(1.0 + easedT * 2.0)
            bombSprite.zRotation += currentSpin * CGFloat(deltaTime)

        case "heavy_bomb":
            wobblePhase += CGFloat(deltaTime) * 4.0
            let wobbleAmount = CGFloat(0.08 * (1.0 - easedT))
            bombSprite.zRotation = sin(wobblePhase) * wobbleAmount

        case "cluster_bomb":
            bombSprite.zRotation += spinRate * CGFloat(deltaTime)
            wobblePhase += CGFloat(deltaTime) * 8.0
            let jitter = sin(wobblePhase) * CGFloat(1.5 * (1.0 - easedT))
            bombSprite.position.x += jitter * CGFloat(deltaTime)

        default:
            // Bomb tilts to follow its arc direction.
            // Early: tilted in the momentum direction (riding the arc).
            // Late: pitched nose-down as gravity dominates.
            let noseDown = CGFloat(easedT) * 0.5
            let lateralTilt = momentumX * 0.0008 * CGFloat(1.0 - easedT)
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
        onImpact = nil

        run(.sequence([
            .wait(forDuration: 0.1),
            .removeFromParent()
        ]))
    }
}
