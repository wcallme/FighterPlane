import SpriteKit

class GameHUD3D: SKScene {

    // Output: read by Game3DController on render thread, written from main thread.
    // All input state is bundled in a single struct behind one lock for atomic snapshots.
    struct InputState {
        var steeringX: CGFloat = 0
        var hasSteeringInput = false
        var steeringAngle: CGFloat = 0
        var isFiring = false
        var shouldDropBomb = false
        var shouldActivateECM = false
        var shouldRestart = false
        var shouldExitToMenu = false
        var shouldRetryMission = false
        var shouldNextMission = false
        var isGamePaused = false
    }

    private let _lock = NSLock()
    private var _state = InputState()

    /// Atomically read and optionally reset one-shot flags
    func consumeInputState() -> InputState {
        _lock.lock()
        let snapshot = _state
        _state.shouldDropBomb = false
        _state.shouldActivateECM = false
        _state.shouldRestart = false
        _state.shouldExitToMenu = false
        _state.shouldRetryMission = false
        _state.shouldNextMission = false
        _lock.unlock()
        return snapshot
    }

    var steeringX: CGFloat {
        get { _lock.lock(); defer { _lock.unlock() }; return _state.steeringX }
        set { _lock.lock(); _state.steeringX = newValue; _lock.unlock() }
    }
    var hasSteeringInput: Bool {
        get { _lock.lock(); defer { _lock.unlock() }; return _state.hasSteeringInput }
        set { _lock.lock(); _state.hasSteeringInput = newValue; _lock.unlock() }
    }
    var steeringAngle: CGFloat {
        get { _lock.lock(); defer { _lock.unlock() }; return _state.steeringAngle }
        set { _lock.lock(); _state.steeringAngle = newValue; _lock.unlock() }
    }
    var isFiring: Bool {
        get { _lock.lock(); defer { _lock.unlock() }; return _state.isFiring }
        set { _lock.lock(); _state.isFiring = newValue; _lock.unlock() }
    }
    var shouldDropBomb: Bool {
        get { _lock.lock(); defer { _lock.unlock() }; return _state.shouldDropBomb }
        set { _lock.lock(); _state.shouldDropBomb = newValue; _lock.unlock() }
    }
    var shouldActivateECM: Bool {
        get { _lock.lock(); defer { _lock.unlock() }; return _state.shouldActivateECM }
        set { _lock.lock(); _state.shouldActivateECM = newValue; _lock.unlock() }
    }
    var shouldRestart: Bool {
        get { _lock.lock(); defer { _lock.unlock() }; return _state.shouldRestart }
        set { _lock.lock(); _state.shouldRestart = newValue; _lock.unlock() }
    }
    var shouldExitToMenu: Bool {
        get { _lock.lock(); defer { _lock.unlock() }; return _state.shouldExitToMenu }
        set { _lock.lock(); _state.shouldExitToMenu = newValue; _lock.unlock() }
    }
    var shouldRetryMission: Bool {
        get { _lock.lock(); defer { _lock.unlock() }; return _state.shouldRetryMission }
        set { _lock.lock(); _state.shouldRetryMission = newValue; _lock.unlock() }
    }
    var shouldNextMission: Bool {
        get { _lock.lock(); defer { _lock.unlock() }; return _state.shouldNextMission }
        set { _lock.lock(); _state.shouldNextMission = newValue; _lock.unlock() }
    }
    var isGamePaused: Bool {
        get { _lock.lock(); defer { _lock.unlock() }; return _state.isGamePaused }
        set { _lock.lock(); _state.isGamePaused = newValue; _lock.unlock() }
    }

    // Mission mode state
    private(set) var isMissionMode = false
    private var hasNextMission = false

    // HUD elements
    private var joystickBase: SKShapeNode!
    private var joystickKnob: SKShapeNode!
    private let joystickRadius: CGFloat = DeviceLayout.joystickRadius
    private let knobRadius: CGFloat = DeviceLayout.knobRadius

    private var fireButton: SKShapeNode!
    private var bombButton: SKShapeNode!
    private var bombPips: [SKShapeNode] = []
    private var ecmButton: SKShapeNode?
    private var ecmCooldownRing: SKShapeNode?

    private var healthBarBg: SKShapeNode!
    private var healthBarFill: SKShapeNode!
    private var scoreLabel: SKLabelNode!

    private var pauseButton: SKNode!
    private var pauseOverlay: SKNode?

    private var gameOverOverlay: SKNode?
    private var canRestart = false

    // Mission HUD
    private var missionLabel: SKLabelNode?
    private var enemyCountLabel: SKLabelNode?

    // Touch tracking
    private var joystickTouch: UITouch?
    private var fireTouch: UITouch?

    // Safe area insets
    private var safeTop: CGFloat = 59
    private var safeBottom: CGFloat = 34
    private var safeLeft: CGFloat = 0
    private var safeRight: CGFloat = 0

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        safeTop = SafeArea.top
        safeBottom = SafeArea.bottom
        safeLeft = SafeArea.left
        safeRight = SafeArea.right

        setupJoystick()
        setupButtons()
        setupPauseButton()
        setupHealthBar()
        setupScore()
    }

    // MARK: - Setup

    private func setupJoystick() {
        // Joystick starts hidden — it appears wherever the thumb touches
        joystickBase = SKShapeNode(circleOfRadius: joystickRadius)
        joystickBase.fillColor = SKColor(white: 0.3, alpha: 0.3)
        joystickBase.strokeColor = SKColor(white: 0.8, alpha: 0.5)
        joystickBase.lineWidth = 2
        joystickBase.position = CGPoint(x: 80, y: 80)
        joystickBase.zPosition = 10
        joystickBase.alpha = 0
        addChild(joystickBase)

        joystickKnob = SKShapeNode(circleOfRadius: knobRadius)
        joystickKnob.fillColor = SKColor(white: 0.6, alpha: 0.5)
        joystickKnob.strokeColor = SKColor(white: 1.0, alpha: 0.7)
        joystickKnob.lineWidth = 2
        joystickKnob.position = joystickBase.position
        joystickKnob.zPosition = 11
        joystickKnob.alpha = 0
        addChild(joystickKnob)
    }

    private func setupButtons() {
        let btnR = DeviceLayout.buttonRadius
        let margin = DeviceLayout.buttonMargin
        let spacing = DeviceLayout.buttonSpacing
        let labelSize = DeviceLayout.fontSize(12)

        // Fire button (bottom-right area, lower)
        fireButton = SKShapeNode(circleOfRadius: btnR)
        fireButton.fillColor = SKColor(red: 0.8, green: 0.5, blue: 0.1, alpha: 0.5)
        fireButton.strokeColor = SKColor(white: 0.9, alpha: 0.7)
        fireButton.lineWidth = 2
        fireButton.position = CGPoint(x: size.width - safeRight - margin, y: safeBottom + btnR - 6)
        fireButton.zPosition = 10
        fireButton.name = "fireBtn"
        addChild(fireButton)

        let fireIcon = SKLabelNode(fontNamed: "Menlo-Bold")
        fireIcon.text = "GUN"
        fireIcon.fontSize = labelSize
        fireIcon.fontColor = .white
        fireIcon.verticalAlignmentMode = .center
        fireButton.addChild(fireIcon)

        // Bomb button (above fire button)
        bombButton = SKShapeNode(circleOfRadius: btnR)
        bombButton.fillColor = SKColor(red: 0.7, green: 0.2, blue: 0.2, alpha: 0.5)
        bombButton.strokeColor = SKColor(white: 0.9, alpha: 0.7)
        bombButton.lineWidth = 2
        bombButton.position = CGPoint(x: size.width - safeRight - margin, y: safeBottom + btnR - 6 + spacing)
        bombButton.zPosition = 10
        bombButton.name = "bombBtn"
        addChild(bombButton)

        let bombIcon = SKLabelNode(fontNamed: "Menlo-Bold")
        bombIcon.text = "BOMB"
        bombIcon.fontSize = labelSize
        bombIcon.fontColor = .white
        bombIcon.verticalAlignmentMode = .center
        bombIcon.position = CGPoint(x: 0, y: 4)
        bombButton.addChild(bombIcon)
    }

    func setupECMButton() {
        let btnR = DeviceLayout.buttonRadius
        let margin = DeviceLayout.buttonMargin
        let spacing = DeviceLayout.buttonSpacing

        let btn = SKShapeNode(circleOfRadius: btnR)
        btn.fillColor = SKColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 0.5)
        btn.strokeColor = SKColor(white: 0.9, alpha: 0.7)
        btn.lineWidth = 2
        btn.position = CGPoint(x: size.width - safeRight - margin, y: safeBottom + btnR - 6 + spacing * 2)
        btn.zPosition = 10
        btn.name = "ecmBtn"
        addChild(btn)

        let icon = SKLabelNode(fontNamed: "Menlo-Bold")
        icon.text = "ECM"
        icon.fontSize = DeviceLayout.fontSize(11)
        icon.fontColor = .white
        icon.verticalAlignmentMode = .center
        icon.position = CGPoint(x: 0, y: 4)
        btn.addChild(icon)

        // Cooldown overlay ring (fills as cooldown progresses)
        let ring = SKShapeNode(circleOfRadius: DeviceLayout.buttonRadius * 0.94)
        ring.fillColor = SKColor(white: 0, alpha: 0.55)
        ring.strokeColor = .clear
        ring.zPosition = 2
        ring.isHidden = true
        btn.addChild(ring)
        ecmCooldownRing = ring

        ecmButton = btn
    }

    func updateECMButton(isActive: Bool, isReady: Bool, cooldownFraction: CGFloat) {
        guard let btn = ecmButton else { return }
        if isActive {
            btn.fillColor = SKColor(red: 0.3, green: 0.9, blue: 1.0, alpha: 0.7)
            ecmCooldownRing?.isHidden = true
        } else if isReady {
            btn.fillColor = SKColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 0.5)
            ecmCooldownRing?.isHidden = true
        } else {
            btn.fillColor = SKColor(red: 0.2, green: 0.3, blue: 0.4, alpha: 0.4)
            ecmCooldownRing?.isHidden = false
            ecmCooldownRing?.alpha = CGFloat(1.0 - cooldownFraction)
        }
    }

    private func setupPauseButton() {
        let hs = DeviceLayout.hudScale
        pauseButton = SKNode()
        pauseButton.position = CGPoint(x: safeLeft + 50 * hs, y: size.height - safeTop - 26 * hs)
        pauseButton.zPosition = 20
        pauseButton.name = "pauseBtn"

        let bg = SKShapeNode(rectOf: CGSize(width: 40 * hs, height: 32 * hs), cornerRadius: 8 * hs)
        bg.fillColor = SKColor(white: 0.15, alpha: 0.6)
        bg.strokeColor = SKColor(white: 0.6, alpha: 0.4)
        bg.lineWidth = 1
        bg.name = "pauseBtn"
        pauseButton.addChild(bg)

        // Pause icon (two vertical bars)
        let bar1 = SKShapeNode(rectOf: CGSize(width: 4 * hs, height: 14 * hs), cornerRadius: 1)
        bar1.fillColor = .white
        bar1.strokeColor = .clear
        bar1.position = CGPoint(x: -5 * hs, y: 0)
        bar1.name = "pauseBtn"
        pauseButton.addChild(bar1)

        let bar2 = SKShapeNode(rectOf: CGSize(width: 4 * hs, height: 14 * hs), cornerRadius: 1)
        bar2.fillColor = .white
        bar2.strokeColor = .clear
        bar2.position = CGPoint(x: 5 * hs, y: 0)
        bar2.name = "pauseBtn"
        pauseButton.addChild(bar2)

        addChild(pauseButton)
    }

    private func showPauseMenu() {
        guard pauseOverlay == nil else { return }
        isGamePaused = true

        let overlay = SKNode()
        overlay.zPosition = 80
        overlay.name = "pauseOverlay"

        // Dimmed background
        let bg = SKShapeNode(rectOf: CGSize(width: size.width * 2, height: size.height * 2))
        bg.fillColor = SKColor(white: 0, alpha: 0.65)
        bg.strokeColor = .clear
        bg.position = CGPoint(x: size.width / 2, y: size.height / 2)
        overlay.addChild(bg)

        let hs = DeviceLayout.hudScale

        // Pause title
        let title = SKLabelNode(fontNamed: "Menlo-Bold")
        title.text = "PAUSED"
        title.fontSize = DeviceLayout.fontSize(32)
        title.fontColor = .white
        title.position = CGPoint(x: size.width / 2, y: size.height / 2 + 60 * hs)
        overlay.addChild(title)

        // Resume button
        let resumeBtn = createMenuButton(text: "RESUME", color: SKColor(red: 0.15, green: 0.5, blue: 0.2, alpha: 0.95))
        resumeBtn.position = CGPoint(x: size.width / 2, y: size.height / 2)
        resumeBtn.name = "resumeBtn"
        overlay.addChild(resumeBtn)

        // Exit to Menu button
        let exitBtn = createMenuButton(text: "EXIT TO MENU", color: SKColor(red: 0.55, green: 0.15, blue: 0.15, alpha: 0.95))
        exitBtn.position = CGPoint(x: size.width / 2, y: size.height / 2 - 60 * hs)
        exitBtn.name = "exitBtn"
        overlay.addChild(exitBtn)

        addChild(overlay)
        pauseOverlay = overlay
    }

    private func hidePauseMenu() {
        pauseOverlay?.removeFromParent()
        pauseOverlay = nil
        isGamePaused = false
    }

    private func createMenuButton(text: String, color: SKColor) -> SKNode {
        let hs = DeviceLayout.hudScale
        let node = SKNode()

        let bg = SKShapeNode(rectOf: CGSize(width: 200 * hs, height: 44 * hs), cornerRadius: 10 * hs)
        bg.fillColor = color
        bg.strokeColor = SKColor(white: 0.8, alpha: 0.4)
        bg.lineWidth = 1.5
        node.addChild(bg)

        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.text = text
        label.fontSize = DeviceLayout.fontSize(15)
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        node.addChild(label)

        return node
    }

    private var lastPipTotal = 0

    func updateBombIndicator(ready: Int, total: Int) {
        guard total > 0, bombButton != nil else { return }

        // Only rebuild pip nodes if total count changed; otherwise just update colors
        if total != lastPipTotal {
            for pip in bombPips { pip.removeFromParent() }
            bombPips.removeAll()
            lastPipTotal = total

            let pipRadius: CGFloat = 4
            let spacing: CGFloat = 12
            let totalWidth = CGFloat(total - 1) * spacing
            let startX = -totalWidth / 2

            for i in 0..<total {
                let pip = SKShapeNode(circleOfRadius: pipRadius)
                pip.strokeColor = SKColor(white: 0.9, alpha: 0.6)
                pip.lineWidth = 1
                pip.fillColor = SKColor(white: 0.2, alpha: 0.6)
                pip.position = CGPoint(x: startX + CGFloat(i) * spacing, y: -15)
                pip.zPosition = 1
                bombButton.addChild(pip)
                bombPips.append(pip)
            }
        }

        // Update colors only
        for (i, pip) in bombPips.enumerated() {
            pip.fillColor = i < ready
                ? SKColor(red: 1.0, green: 0.4, blue: 0.3, alpha: 1.0)
                : SKColor(white: 0.2, alpha: 0.6)
        }
    }

    private func setupHealthBar() {
        let hs = DeviceLayout.hudScale
        let barWidth: CGFloat = 140 * hs
        let barHeight: CGFloat = 14 * hs

        healthBarBg = SKShapeNode(rectOf: CGSize(width: barWidth, height: barHeight), cornerRadius: 4 * hs)
        healthBarBg.fillColor = SKColor(white: 0.15, alpha: 0.7)
        healthBarBg.strokeColor = SKColor(white: 0.8, alpha: 0.7)
        healthBarBg.lineWidth = 1.5
        healthBarBg.position = CGPoint(x: size.width / 2, y: size.height - safeTop - 24 * hs)
        healthBarBg.zPosition = 10
        addChild(healthBarBg)

        healthBarFill = SKShapeNode(rectOf: CGSize(width: barWidth - 4, height: barHeight - 4), cornerRadius: 3 * hs)
        healthBarFill.fillColor = SKColor(red: 0.2, green: 0.8, blue: 0.2, alpha: 1)
        healthBarFill.strokeColor = .clear
        healthBarFill.position = healthBarBg.position
        healthBarFill.zPosition = 11
        addChild(healthBarFill)

        let hpLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        hpLabel.text = "HP"
        hpLabel.fontSize = DeviceLayout.fontSize(10)
        hpLabel.fontColor = .white
        hpLabel.position = CGPoint(x: size.width / 2 - 82 * hs, y: size.height - safeTop - 29 * hs)
        hpLabel.zPosition = 10
        addChild(hpLabel)
    }

    private func setupScore() {
        let hs = DeviceLayout.hudScale
        scoreLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        scoreLabel.text = "0"
        scoreLabel.fontSize = DeviceLayout.fontSize(20)
        scoreLabel.fontColor = .white
        scoreLabel.horizontalAlignmentMode = .right
        scoreLabel.position = CGPoint(x: size.width - safeRight - 28 * hs, y: size.height - safeTop - 32 * hs)
        scoreLabel.zPosition = 10
        addChild(scoreLabel)

        let scoreIcon = SKLabelNode(fontNamed: "Menlo-Bold")
        scoreIcon.text = "SCORE"
        scoreIcon.fontSize = DeviceLayout.fontSize(10)
        scoreIcon.fontColor = SKColor(white: 0.8, alpha: 0.8)
        scoreIcon.horizontalAlignmentMode = .right
        scoreIcon.position = CGPoint(x: size.width - safeRight - 28 * hs, y: size.height - safeTop - 16 * hs)
        scoreIcon.zPosition = 10
        addChild(scoreIcon)
    }

    // MARK: - Mission Setup

    func setupMissionHUD(missionName: String, enemyTotal: Int, hasNext: Bool) {
        isMissionMode = true
        hasNextMission = hasNext

        let hs = DeviceLayout.hudScale

        // Mission name label (top center, above health bar)
        let ml = SKLabelNode(fontNamed: "Menlo-Bold")
        ml.text = missionName.uppercased()
        ml.fontSize = DeviceLayout.fontSize(10)
        ml.fontColor = SKColor(red: 0.95, green: 0.75, blue: 0.15, alpha: 0.9)
        ml.position = CGPoint(x: size.width / 2, y: size.height - safeTop - 8 * hs)
        ml.zPosition = 10
        addChild(ml)
        missionLabel = ml

        // Enemy counter (left side, below pause button)
        let ecl = SKLabelNode(fontNamed: "Menlo-Bold")
        ecl.text = "0 / \(enemyTotal)"
        ecl.fontSize = DeviceLayout.fontSize(12)
        ecl.fontColor = .white
        ecl.horizontalAlignmentMode = .left
        ecl.position = CGPoint(x: safeLeft + 24 * hs, y: size.height - safeTop - 54 * hs)
        ecl.zPosition = 10
        addChild(ecl)
        enemyCountLabel = ecl

        let ecIcon = SKLabelNode(fontNamed: "Menlo-Bold")
        ecIcon.text = "ENEMIES"
        ecIcon.fontSize = DeviceLayout.fontSize(8)
        ecIcon.fontColor = SKColor(white: 0.7, alpha: 0.8)
        ecIcon.horizontalAlignmentMode = .left
        ecIcon.position = CGPoint(x: safeLeft + 24 * hs, y: size.height - safeTop - 41 * hs)
        ecIcon.zPosition = 10
        addChild(ecIcon)
    }

    func updateEnemyCount(destroyed: Int, total: Int) {
        enemyCountLabel?.text = "\(destroyed) / \(total)"
    }

    // MARK: - Updates from Game

    func updateHealth(current: Int, maximum: Int) {
        let ratio = CGFloat(current) / CGFloat(Swift.max(1, maximum))
        let clamped = Swift.max(0, Swift.min(1, ratio))

        healthBarFill.xScale = clamped
        let fullWidth: CGFloat = 136
        let offset = (1 - clamped) * fullWidth / 2
        healthBarFill.position.x = healthBarBg.position.x - offset

        if clamped > 0.6 {
            healthBarFill.fillColor = SKColor(red: 0.2, green: 0.8, blue: 0.2, alpha: 1)
        } else if clamped > 0.3 {
            healthBarFill.fillColor = SKColor(red: 0.9, green: 0.7, blue: 0.1, alpha: 1)
        } else {
            healthBarFill.fillColor = SKColor(red: 0.9, green: 0.2, blue: 0.1, alpha: 1)
        }
    }

    func updateScore(_ score: Int) {
        scoreLabel.text = "\(score)"
    }

    func showGameOver(score: Int, highScore: Int, coins: Int, gems: Int) {
        let hs = DeviceLayout.hudScale
        let overlay = SKNode()
        overlay.zPosition = 50

        let bg = SKShapeNode(rectOf: size)
        bg.fillColor = SKColor(white: 0, alpha: 0.6)
        bg.strokeColor = .clear
        bg.position = CGPoint(x: size.width / 2, y: size.height / 2)
        overlay.addChild(bg)

        let title = SKLabelNode(fontNamed: "Menlo-Bold")
        title.text = "GAME OVER"
        title.fontSize = DeviceLayout.fontSize(40)
        title.fontColor = .white
        title.position = CGPoint(x: size.width / 2, y: size.height / 2 + 50 * hs)
        overlay.addChild(title)

        let scoreLbl = SKLabelNode(fontNamed: "Menlo")
        scoreLbl.text = "Score: \(score)"
        scoreLbl.fontSize = DeviceLayout.fontSize(22)
        scoreLbl.fontColor = SKColor(white: 0.9, alpha: 1)
        scoreLbl.position = CGPoint(x: size.width / 2, y: size.height / 2 + 10 * hs)
        overlay.addChild(scoreLbl)

        let bestLbl = SKLabelNode(fontNamed: "Menlo")
        bestLbl.text = "Best: \(highScore)"
        bestLbl.fontSize = DeviceLayout.fontSize(16)
        bestLbl.fontColor = SKColor(white: 0.7, alpha: 1)
        bestLbl.position = CGPoint(x: size.width / 2, y: size.height / 2 - 15 * hs)
        overlay.addChild(bestLbl)

        let rewardsLbl = SKLabelNode(fontNamed: "Menlo-Bold")
        rewardsLbl.text = "+\(coins) coins  +\(gems) gems"
        rewardsLbl.fontSize = DeviceLayout.fontSize(14)
        rewardsLbl.fontColor = SKColor(red: 0.9, green: 0.8, blue: 0.2, alpha: 1)
        rewardsLbl.position = CGPoint(x: size.width / 2, y: size.height / 2 - 40 * hs)
        overlay.addChild(rewardsLbl)

        let tapLbl = SKLabelNode(fontNamed: "Menlo-Bold")
        tapLbl.text = "Tap to Continue"
        tapLbl.fontSize = DeviceLayout.fontSize(18)
        tapLbl.fontColor = SKColor(white: 0.8, alpha: 1)
        tapLbl.position = CGPoint(x: size.width / 2, y: size.height / 2 - 75 * hs)
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

    func hideControlsDuringVictory() {
        fireButton.run(.fadeAlpha(to: 0, duration: 0.5))
        bombButton.run(.fadeAlpha(to: 0, duration: 0.5))
        joystickBase.run(.fadeAlpha(to: 0, duration: 0.5))
        joystickKnob.run(.fadeAlpha(to: 0, duration: 0.5))
        pauseButton.run(.fadeAlpha(to: 0, duration: 0.5))
        healthBarBg.run(.fadeAlpha(to: 0, duration: 0.5))
        healthBarFill.run(.fadeAlpha(to: 0, duration: 0.5))
        ecmButton?.run(.fadeAlpha(to: 0, duration: 0.5))
    }

    func showMissionComplete(score: Int, enemies: Int, coins: Int, gems: Int) {
        let hs = DeviceLayout.hudScale
        let overlay = SKNode()
        overlay.zPosition = 50

        let bg = SKShapeNode(rectOf: CGSize(width: size.width * 2, height: size.height * 2))
        bg.fillColor = SKColor(white: 0, alpha: 0.65)
        bg.strokeColor = .clear
        bg.position = CGPoint(x: size.width / 2, y: size.height / 2)
        overlay.addChild(bg)

        let cx = size.width / 2
        var y = size.height / 2 + 80 * hs

        let title = SKLabelNode(fontNamed: "Menlo-Bold")
        title.text = "MISSION COMPLETE"
        title.fontSize = DeviceLayout.fontSize(28)
        title.fontColor = SKColor(red: 0.2, green: 0.95, blue: 0.3, alpha: 1)
        title.position = CGPoint(x: cx, y: y)
        overlay.addChild(title)

        y -= 35 * hs
        let scoreLbl = SKLabelNode(fontNamed: "Menlo")
        scoreLbl.text = "Score: \(score)"
        scoreLbl.fontSize = DeviceLayout.fontSize(20)
        scoreLbl.fontColor = SKColor(white: 0.9, alpha: 1)
        scoreLbl.position = CGPoint(x: cx, y: y)
        overlay.addChild(scoreLbl)

        y -= 25 * hs
        let enemyLbl = SKLabelNode(fontNamed: "Menlo")
        enemyLbl.text = "Enemies Destroyed: \(enemies)"
        enemyLbl.fontSize = DeviceLayout.fontSize(13)
        enemyLbl.fontColor = SKColor(white: 0.7, alpha: 1)
        enemyLbl.position = CGPoint(x: cx, y: y)
        overlay.addChild(enemyLbl)

        y -= 25 * hs
        let rewardsLbl = SKLabelNode(fontNamed: "Menlo-Bold")
        rewardsLbl.text = "+\(coins) coins  +\(gems) gems"
        rewardsLbl.fontSize = DeviceLayout.fontSize(14)
        rewardsLbl.fontColor = SKColor(red: 0.9, green: 0.8, blue: 0.2, alpha: 1)
        rewardsLbl.position = CGPoint(x: cx, y: y)
        overlay.addChild(rewardsLbl)

        // Next Mission button (if available)
        y -= 45 * hs
        if hasNextMission {
            let nextBtn = createMenuButton(text: "NEXT MISSION", color: SKColor(red: 0.10, green: 0.45, blue: 0.12, alpha: 0.95))
            nextBtn.position = CGPoint(x: cx, y: y)
            nextBtn.name = "nextMissionBtn"
            overlay.addChild(nextBtn)
            y -= 55 * hs
        }

        // Exit to Menu button
        let exitBtn = createMenuButton(text: "BACK TO MENU", color: SKColor(red: 0.2, green: 0.2, blue: 0.3, alpha: 0.95))
        exitBtn.position = CGPoint(x: cx, y: y)
        exitBtn.name = "exitBtn"
        overlay.addChild(exitBtn)

        addChild(overlay)
        gameOverOverlay = overlay

        run(.sequence([
            .wait(forDuration: 1.0),
            .run { [weak self] in self?.canRestart = true }
        ]))
    }

    func showMissionFailed(score: Int, enemies: Int, total: Int) {
        let hs = DeviceLayout.hudScale
        let overlay = SKNode()
        overlay.zPosition = 50

        let bg = SKShapeNode(rectOf: CGSize(width: size.width * 2, height: size.height * 2))
        bg.fillColor = SKColor(white: 0, alpha: 0.65)
        bg.strokeColor = .clear
        bg.position = CGPoint(x: size.width / 2, y: size.height / 2)
        overlay.addChild(bg)

        let cx = size.width / 2
        var y = size.height / 2 + 70 * hs

        let title = SKLabelNode(fontNamed: "Menlo-Bold")
        title.text = "MISSION FAILED"
        title.fontSize = DeviceLayout.fontSize(30)
        title.fontColor = SKColor(red: 1.0, green: 0.3, blue: 0.2, alpha: 1)
        title.position = CGPoint(x: cx, y: y)
        overlay.addChild(title)

        y -= 35 * hs
        let scoreLbl = SKLabelNode(fontNamed: "Menlo")
        scoreLbl.text = "Score: \(score)"
        scoreLbl.fontSize = DeviceLayout.fontSize(20)
        scoreLbl.fontColor = SKColor(white: 0.9, alpha: 1)
        scoreLbl.position = CGPoint(x: cx, y: y)
        overlay.addChild(scoreLbl)

        y -= 25 * hs
        let progressLbl = SKLabelNode(fontNamed: "Menlo")
        progressLbl.text = "Enemies: \(enemies) / \(total)"
        progressLbl.fontSize = DeviceLayout.fontSize(13)
        progressLbl.fontColor = SKColor(white: 0.6, alpha: 1)
        progressLbl.position = CGPoint(x: cx, y: y)
        overlay.addChild(progressLbl)

        // Retry button
        y -= 45 * hs
        let retryBtn = createMenuButton(text: "RETRY", color: SKColor(red: 0.50, green: 0.35, blue: 0.08, alpha: 0.95))
        retryBtn.position = CGPoint(x: cx, y: y)
        retryBtn.name = "retryBtn"
        overlay.addChild(retryBtn)

        // Exit button
        y -= 55 * hs
        let exitBtn = createMenuButton(text: "BACK TO MENU", color: SKColor(red: 0.2, green: 0.2, blue: 0.3, alpha: 0.95))
        exitBtn.position = CGPoint(x: cx, y: y)
        exitBtn.name = "exitBtn"
        overlay.addChild(exitBtn)

        addChild(overlay)
        gameOverOverlay = overlay

        run(.sequence([
            .wait(forDuration: 1.0),
            .run { [weak self] in self?.canRestart = true }
        ]))
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let loc = touch.location(in: self)
            let tappedNodes = nodes(at: loc)

            // Game over / mission end tap
            if gameOverOverlay != nil && canRestart {
                if isMissionMode {
                    // Mission mode: check which button was tapped
                    let tapped = nodes(at: loc)
                    for n in tapped {
                        let btnName = n.name ?? n.parent?.name ?? ""
                        if btnName == "retryBtn" {
                            shouldRetryMission = true
                            return
                        }
                        if btnName == "nextMissionBtn" {
                            shouldNextMission = true
                            return
                        }
                        if btnName == "exitBtn" {
                            shouldExitToMenu = true
                            return
                        }
                    }
                    return // absorb touch even if no button hit
                }
                // Infinite mode: tap anywhere to exit
                shouldRestart = true
                return
            }

            // Pause menu interactions
            if pauseOverlay != nil {
                for node in tappedNodes {
                    let name = node.name ?? node.parent?.name ?? ""
                    if name == "resumeBtn" {
                        hidePauseMenu()
                        return
                    }
                    if name == "exitBtn" {
                        hidePauseMenu()
                        shouldExitToMenu = true
                        return
                    }
                }
                return // Absorb all touches while paused
            }

            // Pause button
            if tappedNodes.contains(where: { ($0.name ?? $0.parent?.name ?? "") == "pauseBtn" }) {
                showPauseMenu()
                return
            }

            // Joystick — spawns at touch location on the left half of screen
            if loc.x < size.width / 2 && joystickTouch == nil {
                joystickTouch = touch
                // Move joystick base to where the thumb landed
                joystickBase.removeAllActions()
                joystickKnob.removeAllActions()
                joystickBase.position = loc
                joystickKnob.position = loc
                joystickBase.alpha = 1
                joystickKnob.alpha = 1
                continue
            }

            // Fire button
            let hitR = DeviceLayout.buttonHitRadius
            let fireDist = hypot(loc.x - fireButton.position.x, loc.y - fireButton.position.y)
            if fireDist <= hitR {
                isFiring = true
                fireTouch = touch
                pressButton(fireButton)
                continue
            }

            // Bomb button
            let bombDist = hypot(loc.x - bombButton.position.x, loc.y - bombButton.position.y)
            if bombDist <= hitR {
                shouldDropBomb = true
                pressButton(bombButton)
                // Release after a short moment since bomb is a single tap
                bombButton.run(.sequence([
                    .wait(forDuration: 0.15),
                    .run { [weak self] in self?.releaseButton(self?.bombButton) }
                ]))
                continue
            }

            // ECM button
            if let ecm = ecmButton {
                let ecmDist = hypot(loc.x - ecm.position.x, loc.y - ecm.position.y)
                if ecmDist <= hitR {
                    shouldActivateECM = true
                    pressButton(ecm)
                    ecm.run(.sequence([
                        .wait(forDuration: 0.15),
                        .run { [weak self] in self?.releaseECMButton() }
                    ]))
                    continue
                }
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
                steeringX = 0
                hasSteeringInput = false
                // Fade out joystick
                let fadeOut = SKAction.fadeAlpha(to: 0, duration: 0.2)
                joystickBase.run(fadeOut)
                joystickKnob.run(fadeOut)
            }
            if touch == fireTouch {
                isFiring = false
                fireTouch = nil
                releaseButton(fireButton)
            }
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    private func pressButton(_ button: SKShapeNode) {
        button.removeAllActions()
        button.run(.group([
            .scale(to: 0.85, duration: 0.06),
            .run { button.fillColor = button.fillColor.withAlphaComponent(0.9) }
        ]))
    }

    private func releaseButton(_ button: SKShapeNode?) {
        guard let button = button else { return }
        button.removeAllActions()
        button.run(.group([
            .scale(to: 1.0, duration: 0.1),
            .run {
                // Restore original alpha
                if button.name == "fireBtn" {
                    button.fillColor = SKColor(red: 0.8, green: 0.5, blue: 0.1, alpha: 0.5)
                } else {
                    button.fillColor = SKColor(red: 0.7, green: 0.2, blue: 0.2, alpha: 0.5)
                }
            }
        ]))
    }

    private func releaseECMButton() {
        guard let btn = ecmButton else { return }
        btn.removeAllActions()
        btn.run(.scale(to: 1.0, duration: 0.1))
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
        let deadzone: CGFloat = 15
        if dist > deadzone {
            hasSteeringInput = true
            steeringAngle = atan2(dy, dx)
        } else {
            hasSteeringInput = false
        }
    }
}
