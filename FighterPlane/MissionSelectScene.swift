import SpriteKit

class MissionSelectScene: SKScene {

    private var safeTop: CGFloat = 59
    private var safeBottom: CGFloat = 34
    private var missions: [MissionData] = []

    // Scrolling
    private var scrollContainer = SKNode()
    private var scrollOffset: CGFloat = 0
    private var maxScrollOffset: CGFloat = 0
    private var scrollTouch: UITouch?
    private var lastTouchY: CGFloat = 0
    private var scrollVelocity: CGFloat = 0
    private var isDragging = false
    private var dragStartY: CGFloat = 0
    private var dragStartOffset: CGFloat = 0

    // Layout
    private let rowHeight: CGFloat = 70 * DeviceLayout.menuScale
    private var listTopY: CGFloat = 0
    private var listBottomY: CGFloat = 0

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.06, green: 0.07, blue: 0.11, alpha: 1.0)
        safeTop = SafeArea.top
        safeBottom = SafeArea.bottom
        missions = MissionLoader.loadAll()

        let s = DeviceLayout.menuScale
        listTopY = size.height - safeTop - 90 * s
        listBottomY = max(safeBottom, 21) + 20

        setupBackground()
        setupHeader()
        setupMissionList()
    }

    // MARK: - Background

    private func setupBackground() {
        let bg = SKShapeNode(rectOf: CGSize(width: size.width + 4, height: size.height + 4))
        bg.position = CGPoint(x: size.width / 2, y: size.height / 2)
        bg.fillColor = SKColor(red: 0.06, green: 0.07, blue: 0.11, alpha: 1)
        bg.strokeColor = .clear
        bg.zPosition = -10
        addChild(bg)

        let glow = SKShapeNode(circleOfRadius: size.width * 0.4)
        glow.fillColor = SKColor(red: 0.18, green: 0.12, blue: 0.08, alpha: 0.3)
        glow.strokeColor = .clear
        glow.position = CGPoint(x: size.width / 2, y: size.height * 0.6)
        glow.zPosition = -5
        glow.glowWidth = 30
        addChild(glow)
    }

    // MARK: - Header

    private func setupHeader() {
        let s = DeviceLayout.menuScale
        let headerY = size.height - safeTop - 40 * s

        // Back button
        let backBtn = SKNode()
        backBtn.name = "backButton"
        backBtn.position = CGPoint(x: SafeArea.left + 40 * s, y: headerY)
        backBtn.zPosition = 20

        let backBg = SKShapeNode(circleOfRadius: 18 * s)
        backBg.fillColor = SKColor(white: 0.15, alpha: 0.6)
        backBg.strokeColor = SKColor(white: 0.4, alpha: 0.3)
        backBg.lineWidth = 1
        backBg.name = "backButton"
        backBtn.addChild(backBg)

        let backLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        backLabel.text = "\u{25C0}"
        backLabel.fontSize = DeviceLayout.fontSize(16)
        backLabel.fontColor = SKColor(white: 0.7, alpha: 0.9)
        backLabel.verticalAlignmentMode = .center
        backLabel.name = "backButton"
        backBtn.addChild(backLabel)
        addChild(backBtn)

        // Title
        let title = SKLabelNode(fontNamed: "Menlo-Bold")
        title.text = "MISSIONS"
        title.fontSize = DeviceLayout.fontSize(18)
        title.fontColor = SKColor(red: 0.95, green: 0.75, blue: 0.15, alpha: 1)
        title.position = CGPoint(x: size.width / 2, y: headerY - 2)
        title.zPosition = 20
        addChild(title)

        // Progress label
        let completedCount = min(MissionProgress.completedLevel, missions.count)
        let progressLabel = SKLabelNode(fontNamed: "Menlo")
        progressLabel.text = "\(completedCount)/\(missions.count)"
        progressLabel.fontSize = DeviceLayout.fontSize(12)
        progressLabel.fontColor = SKColor(white: 0.5, alpha: 0.8)
        progressLabel.horizontalAlignmentMode = .right
        progressLabel.position = CGPoint(x: size.width - SafeArea.right - 30 * s, y: headerY - 4)
        progressLabel.zPosition = 20
        addChild(progressLabel)

        // Divider
        let divider = SKShapeNode(rectOf: CGSize(width: size.width - 40 * s, height: 1))
        divider.fillColor = SKColor(red: 0.8, green: 0.6, blue: 0.1, alpha: 0.3)
        divider.strokeColor = .clear
        divider.position = CGPoint(x: size.width / 2, y: headerY - 30 * s)
        divider.zPosition = 20
        divider.glowWidth = 2
        addChild(divider)
    }

    // MARK: - Mission List

    private func setupMissionList() {
        if missions.isEmpty {
            setupComingSoon()
            return
        }

        scrollContainer.name = "scrollContainer"
        scrollContainer.zPosition = 10
        addChild(scrollContainer)

        let s = DeviceLayout.menuScale
        let rowWidth: CGFloat = size.width - 40 * s
        let visibleHeight = listTopY - listBottomY
        let contentHeight = CGFloat(missions.count) * rowHeight

        // Calculate max scroll (0 = top, positive = scrolled down)
        maxScrollOffset = max(0, contentHeight - visibleHeight)

        for (index, mission) in missions.enumerated() {
            let unlocked = MissionProgress.isUnlocked(index: index)
            let completed = index < MissionProgress.completedLevel
            let y = listTopY - CGFloat(index) * rowHeight - rowHeight / 2
            let row = createMissionRow(mission: mission, index: index, width: rowWidth, unlocked: unlocked, completed: completed)
            row.position = CGPoint(x: size.width / 2, y: y)
            scrollContainer.addChild(row)
        }

        // Clip mask — hide rows outside visible area
        let cropNode = SKCropNode()
        cropNode.zPosition = 10
        let mask = SKShapeNode(rectOf: CGSize(width: size.width, height: visibleHeight + 10))
        mask.fillColor = .white
        mask.position = CGPoint(x: size.width / 2, y: listBottomY + visibleHeight / 2)
        cropNode.maskNode = mask

        scrollContainer.removeFromParent()
        cropNode.addChild(scrollContainer)
        addChild(cropNode)
    }

    private func createMissionRow(mission: MissionData, index: Int, width: CGFloat, unlocked: Bool, completed: Bool) -> SKNode {
        let s = DeviceLayout.menuScale
        let node = SKNode()
        node.name = unlocked ? "mission_\(index)" : "locked_\(index)"

        // Row background
        let bg = SKShapeNode(rectOf: CGSize(width: width, height: 56 * s), cornerRadius: 10 * s)
        if unlocked {
            bg.fillColor = SKColor(red: 0.10, green: 0.12, blue: 0.18, alpha: 0.95)
            bg.strokeColor = completed
                ? SKColor(red: 0.2, green: 0.8, blue: 0.3, alpha: 0.4)
                : SKColor(red: 0.8, green: 0.6, blue: 0.1, alpha: 0.3)
        } else {
            bg.fillColor = SKColor(white: 0.08, alpha: 0.9)
            bg.strokeColor = SKColor(white: 0.2, alpha: 0.2)
        }
        bg.lineWidth = 1
        bg.name = node.name
        node.addChild(bg)

        // Level number
        let levelLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        levelLabel.text = "\(index + 1)"
        levelLabel.fontSize = DeviceLayout.fontSize(20)
        levelLabel.fontColor = unlocked
            ? SKColor(red: 0.95, green: 0.75, blue: 0.15, alpha: 1)
            : SKColor(white: 0.3, alpha: 0.5)
        levelLabel.horizontalAlignmentMode = .left
        levelLabel.verticalAlignmentMode = .center
        levelLabel.position = CGPoint(x: -width / 2 + 20 * s, y: 0)
        node.addChild(levelLabel)

        // Mission name
        let nameLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        nameLabel.text = mission.name
        nameLabel.fontSize = DeviceLayout.fontSize(13)
        nameLabel.fontColor = unlocked ? SKColor(white: 0.85, alpha: 1) : SKColor(white: 0.35, alpha: 0.6)
        nameLabel.horizontalAlignmentMode = .left
        nameLabel.verticalAlignmentMode = .center
        nameLabel.position = CGPoint(x: -width / 2 + 55 * s, y: 5 * s)
        node.addChild(nameLabel)

        // Subtitle — enemy count for unlocked, description for completed
        let sub = SKLabelNode(fontNamed: "Menlo")
        sub.fontSize = DeviceLayout.fontSize(9)
        sub.fontColor = SKColor(white: 0.5, alpha: 0.8)
        sub.horizontalAlignmentMode = .left
        sub.verticalAlignmentMode = .center
        sub.position = CGPoint(x: -width / 2 + 55 * s, y: -10 * s)
        if unlocked {
            sub.text = "\(mission.enemies.count) enemies"
            node.addChild(sub)
        }

        // Right side indicator
        if completed {
            let check = SKLabelNode(fontNamed: "Menlo-Bold")
            check.text = "\u{2713}"
            check.fontSize = DeviceLayout.fontSize(20)
            check.fontColor = SKColor(red: 0.2, green: 0.85, blue: 0.3, alpha: 0.9)
            check.horizontalAlignmentMode = .right
            check.verticalAlignmentMode = .center
            check.position = CGPoint(x: width / 2 - 20 * s, y: 0)
            node.addChild(check)
        } else if unlocked {
            let arrow = SKLabelNode(fontNamed: "Menlo-Bold")
            arrow.text = "\u{25B6}"
            arrow.fontSize = DeviceLayout.fontSize(16)
            arrow.fontColor = SKColor(red: 0.2, green: 0.9, blue: 0.3, alpha: 0.9)
            arrow.horizontalAlignmentMode = .right
            arrow.verticalAlignmentMode = .center
            arrow.position = CGPoint(x: width / 2 - 20 * s, y: 0)
            node.addChild(arrow)
        } else {
            let lock = SKLabelNode(fontNamed: "Menlo-Bold")
            lock.text = "\u{1F512}"
            lock.fontSize = DeviceLayout.fontSize(14)
            lock.horizontalAlignmentMode = .right
            lock.verticalAlignmentMode = .center
            lock.position = CGPoint(x: width / 2 - 20 * s, y: 0)
            node.addChild(lock)
        }

        return node
    }

    private func setupComingSoon() {
        let s = DeviceLayout.menuScale
        let centerY = size.height / 2

        let icon = SKLabelNode(fontNamed: "AppleColorEmoji")
        icon.text = "\u{1F3AF}"
        icon.fontSize = DeviceLayout.fontSize(48)
        icon.position = CGPoint(x: size.width / 2, y: centerY + 40 * s)
        icon.zPosition = 10
        addChild(icon)

        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.text = "NO MISSIONS YET"
        label.fontSize = DeviceLayout.fontSize(16)
        label.fontColor = SKColor(white: 0.6, alpha: 0.8)
        label.position = CGPoint(x: size.width / 2, y: centerY - 10 * s)
        label.zPosition = 10
        addChild(label)

        let sub = SKLabelNode(fontNamed: "Menlo")
        sub.text = "Add mission JSON files to play"
        sub.fontSize = DeviceLayout.fontSize(11)
        sub.fontColor = SKColor(white: 0.4, alpha: 0.6)
        sub.position = CGPoint(x: size.width / 2, y: centerY - 35 * s)
        sub.zPosition = 10
        addChild(sub)
    }

    // MARK: - Scrolling

    private func clampScroll() {
        scrollOffset = max(0, min(maxScrollOffset, scrollOffset))
        scrollContainer.position.y = scrollOffset
    }

    override func update(_ currentTime: TimeInterval) {
        guard !isDragging && abs(scrollVelocity) > 0.5 else { return }
        scrollOffset += scrollVelocity
        scrollVelocity *= 0.92 // friction
        if abs(scrollVelocity) < 0.5 { scrollVelocity = 0 }
        clampScroll()
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        // Check header buttons first (not scrollable)
        let tappedNodes = nodes(at: location)
        for node in tappedNodes {
            let name = node.name ?? node.parent?.name ?? node.parent?.parent?.name ?? ""
            if name == "backButton" {
                goBack()
                return
            }
        }

        // Start scroll tracking
        scrollTouch = touch
        lastTouchY = location.y
        dragStartY = location.y
        dragStartOffset = scrollOffset
        isDragging = true
        scrollVelocity = 0
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, touch == scrollTouch else { return }
        let location = touch.location(in: self)
        let dy = location.y - lastTouchY
        scrollOffset -= dy // scroll up when dragging down
        lastTouchY = location.y
        scrollVelocity = -dy
        clampScroll()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, touch == scrollTouch else { return }
        let location = touch.location(in: self)
        isDragging = false
        scrollTouch = nil

        // If the finger barely moved, treat as a tap
        let totalDrag = abs(location.y - dragStartY)
        if totalDrag < 10 {
            scrollVelocity = 0
            handleTap(at: location)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        isDragging = false
        scrollTouch = nil
    }

    private func handleTap(at location: CGPoint) {
        // Convert to scroll container coordinates
        let containerLoc = CGPoint(x: location.x, y: location.y - scrollContainer.position.y)
        let tappedNodes = scrollContainer.nodes(at: containerLoc)

        for node in tappedNodes {
            let name = node.name ?? node.parent?.name ?? node.parent?.parent?.name ?? ""

            if name.hasPrefix("mission_") {
                if let index = Int(String(name.dropFirst("mission_".count))) {
                    launchMission(index: index)
                }
                return
            }
        }
    }

    // MARK: - Actions

    private func goBack() {
        let hangar = HangarScene(size: size)
        hangar.scaleMode = scaleMode
        view?.presentScene(hangar, transition: .push(with: .right, duration: 0.3))
    }

    private func launchMission(index: Int) {
        guard index < missions.count else { return }
        MenuMusicManager.shared.stop()
        NavigationManager.shared.gameMode = .mission(missions[index])
        NavigationManager.shared.isInGame = true
    }
}
