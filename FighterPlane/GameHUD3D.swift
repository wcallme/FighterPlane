import SpriteKit

class GameHUD3D: SKScene {

    // Output: read by Game3DController each frame
    var steeringX: CGFloat = 0   // -1 (full left) to 1 (full right)
    var hasSteeringInput = false  // true when joystick is being used
    var steeringAngle: CGFloat = 0 // angle in radians from joystick (atan2 of knob offset)
    var isFiring = false
    var shouldDropBomb = false
    var shouldRestart = false

    // HUD elements
    private var joystickBase: SKShapeNode!
    private var joystickKnob: SKShapeNode!
    private let joystickRadius: CGFloat = 50
    private let knobRadius: CGFloat = 22

    private var fireButton: SKShapeNode!
    private var bombButton: SKShapeNode!

    private var healthBarBg: SKShapeNode!
    private var healthBarFill: SKShapeNode!
    private var scoreLabel: SKLabelNode!

    private var gameOverOverlay: SKNode?
    private var canRestart = false

    // Touch tracking
    private var joystickTouch: UITouch?
    private var fireTouch: UITouch?

    override func didMove(to view: SKView) {
        backgroundColor = .clear

        setupJoystick()
        setupButtons()
        setupHealthBar()
        setupScore()
    }

    // MARK: - Setup

    private func setupJoystick() {
        let baseX: CGFloat = 80
        let baseY: CGFloat = 80

        joystickBase = SKShapeNode(circleOfRadius: joystickRadius)
        joystickBase.fillColor = SKColor(white: 0.3, alpha: 0.3)
        joystickBase.strokeColor = SKColor(white: 0.8, alpha: 0.5)
        joystickBase.lineWidth = 2
        joystickBase.position = CGPoint(x: baseX, y: baseY)
        joystickBase.zPosition = 10
        addChild(joystickBase)

        joystickKnob = SKShapeNode(circleOfRadius: knobRadius)
        joystickKnob.fillColor = SKColor(white: 0.6, alpha: 0.5)
        joystickKnob.strokeColor = SKColor(white: 1.0, alpha: 0.7)
        joystickKnob.lineWidth = 2
        joystickKnob.position = joystickBase.position
        joystickKnob.zPosition = 11
        addChild(joystickKnob)
    }

    private func setupButtons() {
        // Fire button (bottom-right area, lower)
        fireButton = SKShapeNode(circleOfRadius: 32)
        fireButton.fillColor = SKColor(red: 0.8, green: 0.5, blue: 0.1, alpha: 0.5)
        fireButton.strokeColor = SKColor(white: 0.9, alpha: 0.7)
        fireButton.lineWidth = 2
        fireButton.position = CGPoint(x: size.width - 70, y: 60)
        fireButton.zPosition = 10
        fireButton.name = "fireBtn"
        addChild(fireButton)

        let fireIcon = SKLabelNode(fontNamed: "Menlo-Bold")
        fireIcon.text = "GUN"
        fireIcon.fontSize = 12
        fireIcon.fontColor = .white
        fireIcon.verticalAlignmentMode = .center
        fireButton.addChild(fireIcon)

        // Bomb button (above fire button)
        bombButton = SKShapeNode(circleOfRadius: 32)
        bombButton.fillColor = SKColor(red: 0.7, green: 0.2, blue: 0.2, alpha: 0.5)
        bombButton.strokeColor = SKColor(white: 0.9, alpha: 0.7)
        bombButton.lineWidth = 2
        bombButton.position = CGPoint(x: size.width - 70, y: 145)
        bombButton.zPosition = 10
        bombButton.name = "bombBtn"
        addChild(bombButton)

        let bombIcon = SKLabelNode(fontNamed: "Menlo-Bold")
        bombIcon.text = "BOMB"
        bombIcon.fontSize = 12
        bombIcon.fontColor = .white
        bombIcon.verticalAlignmentMode = .center
        bombButton.addChild(bombIcon)
    }

    private func setupHealthBar() {
        let barWidth: CGFloat = 140
        let barHeight: CGFloat = 14

        healthBarBg = SKShapeNode(rectOf: CGSize(width: barWidth, height: barHeight), cornerRadius: 4)
        healthBarBg.fillColor = SKColor(white: 0.15, alpha: 0.7)
        healthBarBg.strokeColor = SKColor(white: 0.8, alpha: 0.7)
        healthBarBg.lineWidth = 1.5
        healthBarBg.position = CGPoint(x: size.width / 2, y: size.height - 22)
        healthBarBg.zPosition = 10
        addChild(healthBarBg)

        healthBarFill = SKShapeNode(rectOf: CGSize(width: barWidth - 4, height: barHeight - 4), cornerRadius: 3)
        healthBarFill.fillColor = SKColor(red: 0.2, green: 0.8, blue: 0.2, alpha: 1)
        healthBarFill.strokeColor = .clear
        healthBarFill.position = healthBarBg.position
        healthBarFill.zPosition = 11
        addChild(healthBarFill)

        let hpLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        hpLabel.text = "HP"
        hpLabel.fontSize = 10
        hpLabel.fontColor = .white
        hpLabel.position = CGPoint(x: size.width / 2 - 82, y: size.height - 27)
        hpLabel.zPosition = 10
        addChild(hpLabel)
    }

    private func setupScore() {
        scoreLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        scoreLabel.text = "0"
        scoreLabel.fontSize = 20
        scoreLabel.fontColor = .white
        scoreLabel.horizontalAlignmentMode = .right
        scoreLabel.position = CGPoint(x: size.width - 20, y: size.height - 30)
        scoreLabel.zPosition = 10
        addChild(scoreLabel)

        let scoreIcon = SKLabelNode(fontNamed: "Menlo-Bold")
        scoreIcon.text = "SCORE"
        scoreIcon.fontSize = 10
        scoreIcon.fontColor = SKColor(white: 0.8, alpha: 0.8)
        scoreIcon.horizontalAlignmentMode = .right
        scoreIcon.position = CGPoint(x: size.width - 20, y: size.height - 14)
        scoreIcon.zPosition = 10
        addChild(scoreIcon)
    }

    // MARK: - Updates from Game

    func updateHealth(current: Int, maximum: Int) {
        let ratio = CGFloat(current) / CGFloat(Swift.max(1, maximum))
        let clamped = Swift.max(0, Swift.min(1, ratio))

        healthBarFill.xScale = clamped
        let fullWidth: CGFloat = 136
        let offset = (1 - clamped) * fullWidth / 2
        healthBarFill.position.x = healthBarBg.position.x - offset

        if ratio > 0.6 {
            healthBarFill.fillColor = SKColor(red: 0.2, green: 0.8, blue: 0.2, alpha: 1)
        } else if ratio > 0.3 {
            healthBarFill.fillColor = SKColor(red: 0.9, green: 0.7, blue: 0.1, alpha: 1)
        } else {
            healthBarFill.fillColor = SKColor(red: 0.9, green: 0.2, blue: 0.1, alpha: 1)
        }
    }

    func updateScore(_ score: Int) {
        scoreLabel.text = "\(score)"
    }

    func showGameOver(score: Int, highScore: Int, coins: Int, gems: Int) {
        let overlay = SKNode()
        overlay.zPosition = 50

        let bg = SKShapeNode(rectOf: size)
        bg.fillColor = SKColor(white: 0, alpha: 0.6)
        bg.strokeColor = .clear
        bg.position = CGPoint(x: size.width / 2, y: size.height / 2)
        overlay.addChild(bg)

        let title = SKLabelNode(fontNamed: "Menlo-Bold")
        title.text = "GAME OVER"
        title.fontSize = 40
        title.fontColor = .white
        title.position = CGPoint(x: size.width / 2, y: size.height / 2 + 50)
        overlay.addChild(title)

        let scoreLbl = SKLabelNode(fontNamed: "Menlo")
        scoreLbl.text = "Score: \(score)"
        scoreLbl.fontSize = 22
        scoreLbl.fontColor = SKColor(white: 0.9, alpha: 1)
        scoreLbl.position = CGPoint(x: size.width / 2, y: size.height / 2 + 10)
        overlay.addChild(scoreLbl)

        let bestLbl = SKLabelNode(fontNamed: "Menlo")
        bestLbl.text = "Best: \(highScore)"
        bestLbl.fontSize = 16
        bestLbl.fontColor = SKColor(white: 0.7, alpha: 1)
        bestLbl.position = CGPoint(x: size.width / 2, y: size.height / 2 - 15)
        overlay.addChild(bestLbl)

        let rewardsLbl = SKLabelNode(fontNamed: "Menlo-Bold")
        rewardsLbl.text = "+\(coins) coins  +\(gems) gems"
        rewardsLbl.fontSize = 14
        rewardsLbl.fontColor = SKColor(red: 0.9, green: 0.8, blue: 0.2, alpha: 1)
        rewardsLbl.position = CGPoint(x: size.width / 2, y: size.height / 2 - 40)
        overlay.addChild(rewardsLbl)

        let tapLbl = SKLabelNode(fontNamed: "Menlo-Bold")
        tapLbl.text = "Tap to Continue"
        tapLbl.fontSize = 18
        tapLbl.fontColor = SKColor(white: 0.8, alpha: 1)
        tapLbl.position = CGPoint(x: size.width / 2, y: size.height / 2 - 75)
        tapLbl.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.4, duration: 0.6),
            .fadeAlpha(to: 1.0, duration: 0.6)
        ])))
        overlay.addChild(tapLbl)

        addChild(overlay)
        gameOverOverlay = overlay

        // Delay before allowing restart
        run(.sequence([
            .wait(forDuration: 1.5),
            .run { [weak self] in self?.canRestart = true }
        ]))
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let loc = touch.location(in: self)

            // Game over tap
            if gameOverOverlay != nil && canRestart {
                shouldRestart = true
                return
            }

            // Joystick
            let joystickDist = hypot(loc.x - joystickBase.position.x, loc.y - joystickBase.position.y)
            if joystickDist <= joystickRadius * 1.5 && joystickTouch == nil {
                joystickTouch = touch
                updateJoystick(touch: touch)
                continue
            }

            // Fire button
            let fireDist = hypot(loc.x - fireButton.position.x, loc.y - fireButton.position.y)
            if fireDist <= 50 {
                isFiring = true
                fireTouch = touch
                continue
            }

            // Bomb button
            let bombDist = hypot(loc.x - bombButton.position.x, loc.y - bombButton.position.y)
            if bombDist <= 50 {
                shouldDropBomb = true
                continue
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if touch == joystickTouch {
                updateJoystick(touch: touch)
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if touch == joystickTouch {
                joystickTouch = nil
                joystickKnob.position = joystickBase.position
                steeringX = 0
                hasSteeringInput = false
            }
            if touch == fireTouch {
                isFiring = false
                fireTouch = nil
            }
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    private func updateJoystick(touch: UITouch) {
        let loc = touch.location(in: self)
        let dx = loc.x - joystickBase.position.x
        let dy = loc.y - joystickBase.position.y
        let dist = hypot(dx, dy)

        let maxDist = joystickRadius - knobRadius / 2
        if dist <= maxDist {
            joystickKnob.position = loc
        } else {
            let angle = atan2(dy, dx)
            joystickKnob.position = CGPoint(
                x: joystickBase.position.x + cos(angle) * maxDist,
                y: joystickBase.position.y + sin(angle) * maxDist
            )
        }

        // X axis steering (legacy, still used for bank visual)
        let clampedDist = min(dist, maxDist)
        steeringX = (dx / max(1, clampedDist)) * (clampedDist / maxDist)
        steeringX = max(-1, min(1, steeringX))

        // Flight angle: atan2(dy, dx) so right=0 (level), up=π/2 (climb), down=-π/2 (dive)
        let deadzone: CGFloat = 8
        if dist > deadzone {
            hasSteeringInput = true
            steeringAngle = atan2(dy, dx)
        } else {
            hasSteeringInput = false
        }
    }
}
