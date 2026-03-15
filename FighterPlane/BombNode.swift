import SpriteKit

class BombNode: SKNode {

    private let bombSprite: SKSpriteNode
    private let shadowSprite: SKSpriteNode
    private let fallDuration: TimeInterval
    private var elapsed: TimeInterval = 0
    private var hasExploded = false
    private let weaponId: String

    // Physics: velocity inherited from the plane at drop time
    private var velocityX: CGFloat        // lateral speed (from player banking)
    private var velocityY: CGFloat        // forward speed (from plane flying forward)
    private let deceleration: CGFloat     // how fast forward momentum bleeds off

    // Track total node displacement so shadow can stay ground-relative
    private var nodeDisplacementX: CGFloat = 0
    private var nodeDisplacementY: CGFloat = 0
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

        // Bomb inherits the plane's velocity:
        // - Forward: the plane moves at scrollSpeed relative to the ground.
        //   In screen space the plane is stationary, so the bomb's visible
        //   forward velocity is the portion that exceeds the camera/scroll.
        //   We give it a kick so it visibly drifts upward before arcing down.
        // - Lateral: whatever horizontal speed the player has at drop time.
        self.velocityX = playerVelocityX * 0.8
        self.velocityY = scrollSpeed * 1.0

        // Deceleration pulls the bomb from forward velocity to negative (falling back).
        // Tuned so the bomb peaks around 40% through the fall, then curves down.
        self.deceleration = scrollSpeed * 2.5

        bombSprite = SKSpriteNode(texture: SpriteGenerator.bomb(weaponId: weaponId))
        shadowSprite = SKSpriteNode(texture: SpriteGenerator.bombShadow())
        initialShadowPos = groundOffset
        fallDuration = GameConfig.bombFallDuration

        super.init()

        name = "bomb"

        // Shadow starts at the ground offset (will be kept ground-relative in update)
        shadowSprite.position = groundOffset
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
        let dt = CGFloat(deltaTime)

        // === PHYSICS: move bomb node with inherited momentum ===
        // The bomb physically drifts forward (up on screen) then arcs backward
        // as it decelerates and gravity takes over.
        let dx = velocityX * dt
        let dy = velocityY * dt
        position.x += dx
        position.y += dy
        nodeDisplacementX += dx
        nodeDisplacementY += dy

        // Decelerate forward velocity (drag + no engine = bomb slows down)
        velocityY -= deceleration * dt

        // Lateral velocity decays with drag
        velocityX *= max(0, 1.0 - 3.0 * dt)

        // === SHADOW: stays on the ground, independent of bomb node movement ===
        // Undo node displacement so the shadow remains ground-relative,
        // then apply ground scroll for how far the terrain has moved.
        shadowSprite.position = CGPoint(
            x: initialShadowPos.x - nodeDisplacementX,
            y: initialShadowPos.y - scrollSpeed * CGFloat(elapsed) - nodeDisplacementY
        )

        let t = Swift.min(elapsed / fallDuration, 1.0)
        let easedT = t * t // quadratic ease-in (gravity acceleration)

        // === BOMB SPRITE: converges from node origin toward shadow (falling to ground) ===
        // At t=0 the bomb is at the node position (riding momentum).
        // At t=1 the bomb is at the shadow position (hit the ground).
        bombSprite.position = CGPoint(
            x: shadowSprite.position.x * easedT,
            y: shadowSprite.position.y * easedT
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
            // Bomb pitches nose-down as momentum gives way to gravity
            let noseDown = CGFloat(easedT) * 0.5
            let lateralTilt = velocityX * 0.001
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
