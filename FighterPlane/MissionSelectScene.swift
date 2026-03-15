import SpriteKit

class MissionSelectScene: SKScene {

    private var safeTop: CGFloat = 59
    private var safeBottom: CGFloat = 34
    private var missions: [MissionData] = []

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.06, green: 0.07, blue: 0.11, alpha: 1.0)
        safeTop = SafeArea.top
        safeBottom = SafeArea.bottom
        missions = MissionLoader.loadAll()

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
        let headerY = size.height - safeTop - 40

        // Back button
        let backBtn = SKNode()
        backBtn.name = "backButton"
        backBtn.position = CGPoint(x: 40, y: headerY)
        backBtn.zPosition = 20

        let backBg = SKShapeNode(circleOfRadius: 18)
        backBg.fillColor = SKColor(white: 0.15, alpha: 0.6)
        backBg.strokeColor = SKColor(white: 0.4, alpha: 0.3)
        backBg.lineWidth = 1
        backBg.name = "backButton"
        backBtn.addChild(backBg)

        let backLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        backLabel.text = "\u{25C0}"
        backLabel.fontSize = 16
        backLabel.fontColor = SKColor(white: 0.7, alpha: 0.9)
        backLabel.verticalAlignmentMode = .center
        backLabel.name = "backButton"
        backBtn.addChild(backLabel)
        addChild(backBtn)

        // Title
        let title = SKLabelNode(fontNamed: "Menlo-Bold")
        title.text = "MISSIONS"
        title.fontSize = 18
        title.fontColor = SKColor(red: 0.95, green: 0.75, blue: 0.15, alpha: 1)
        title.position = CGPoint(x: size.width / 2, y: headerY - 2)
        title.zPosition = 20
        addChild(title)

        // Divider
        let divider = SKShapeNode(rectOf: CGSize(width: size.width - 40, height: 1))
        divider.fillColor = SKColor(red: 0.8, green: 0.6, blue: 0.1, alpha: 0.3)
        divider.strokeColor = .clear
        divider.position = CGPoint(x: size.width / 2, y: headerY - 30)
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

        let startY = size.height - safeTop - 100
        let rowHeight: CGFloat = 70
        let rowWidth: CGFloat = size.width - 40

        for (index, mission) in missions.enumerated() {
            let unlocked = MissionProgress.isUnlocked(index: index)
            let completed = index < MissionProgress.completedLevel
            let y = startY - CGFloat(index) * rowHeight
            let row = createMissionRow(mission: mission, index: index, width: rowWidth, unlocked: unlocked, completed: completed)
            row.position = CGPoint(x: size.width / 2, y: y)
            addChild(row)
        }
    }

    private func createMissionRow(mission: MissionData, index: Int, width: CGFloat, unlocked: Bool, completed: Bool) -> SKNode {
        let node = SKNode()
        node.name = unlocked ? "mission_\(index)" : "locked_\(index)"
        node.zPosition = 10

        // Row background
        let bg = SKShapeNode(rectOf: CGSize(width: width, height: 56), cornerRadius: 10)
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
        levelLabel.fontSize = 20
        levelLabel.fontColor = unlocked
            ? SKColor(red: 0.95, green: 0.75, blue: 0.15, alpha: 1)
            : SKColor(white: 0.3, alpha: 0.5)
        levelLabel.horizontalAlignmentMode = .left
        levelLabel.verticalAlignmentMode = .center
        levelLabel.position = CGPoint(x: -width / 2 + 20, y: 0)
        node.addChild(levelLabel)

        // Mission name
        let nameLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        nameLabel.text = mission.name
        nameLabel.fontSize = 13
        nameLabel.fontColor = unlocked ? SKColor(white: 0.85, alpha: 1) : SKColor(white: 0.35, alpha: 0.6)
        nameLabel.horizontalAlignmentMode = .left
        nameLabel.verticalAlignmentMode = .center
        nameLabel.position = CGPoint(x: -width / 2 + 55, y: completed ? 0 : 5)
        node.addChild(nameLabel)

        if unlocked && !completed {
            // Enemy count subtitle
            let sub = SKLabelNode(fontNamed: "Menlo")
            sub.text = "\(mission.enemies.count) enemies"
            sub.fontSize = 9
            sub.fontColor = SKColor(white: 0.5, alpha: 0.8)
            sub.horizontalAlignmentMode = .left
            sub.verticalAlignmentMode = .center
            sub.position = CGPoint(x: -width / 2 + 55, y: -10)
            node.addChild(sub)
        }

        // Right side indicator
        if completed {
            let check = SKLabelNode(fontNamed: "Menlo-Bold")
            check.text = "\u{2713}"
            check.fontSize = 20
            check.fontColor = SKColor(red: 0.2, green: 0.85, blue: 0.3, alpha: 0.9)
            check.horizontalAlignmentMode = .right
            check.verticalAlignmentMode = .center
            check.position = CGPoint(x: width / 2 - 20, y: 0)
            node.addChild(check)
        } else if unlocked {
            let arrow = SKLabelNode(fontNamed: "Menlo-Bold")
            arrow.text = "\u{25B6}"
            arrow.fontSize = 16
            arrow.fontColor = SKColor(red: 0.2, green: 0.9, blue: 0.3, alpha: 0.9)
            arrow.horizontalAlignmentMode = .right
            arrow.verticalAlignmentMode = .center
            arrow.position = CGPoint(x: width / 2 - 20, y: 0)
            node.addChild(arrow)
        } else {
            let lock = SKLabelNode(fontNamed: "Menlo-Bold")
            lock.text = "\u{1F512}"
            lock.fontSize = 14
            lock.horizontalAlignmentMode = .right
            lock.verticalAlignmentMode = .center
            lock.position = CGPoint(x: width / 2 - 20, y: 0)
            node.addChild(lock)
        }

        return node
    }

    private func setupComingSoon() {
        let centerY = size.height / 2

        let icon = SKLabelNode(fontNamed: "AppleColorEmoji")
        icon.text = "\u{1F3AF}"
        icon.fontSize = 48
        icon.position = CGPoint(x: size.width / 2, y: centerY + 40)
        icon.zPosition = 10
        addChild(icon)

        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.text = "NO MISSIONS YET"
        label.fontSize = 16
        label.fontColor = SKColor(white: 0.6, alpha: 0.8)
        label.position = CGPoint(x: size.width / 2, y: centerY - 10)
        label.zPosition = 10
        addChild(label)

        let sub = SKLabelNode(fontNamed: "Menlo")
        sub.text = "Add mission JSON files to play"
        sub.fontSize = 11
        sub.fontColor = SKColor(white: 0.4, alpha: 0.6)
        sub.position = CGPoint(x: size.width / 2, y: centerY - 35)
        sub.zPosition = 10
        addChild(sub)
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let tappedNodes = nodes(at: location)

        for node in tappedNodes {
            let name = node.name ?? node.parent?.name ?? node.parent?.parent?.name ?? ""

            if name == "backButton" {
                goBack()
                return
            }

            if name.hasPrefix("mission_") {
                if let index = Int(String(name.dropFirst("mission_".count))) {
                    launchMission(index: index)
                }
                return
            }
        }
    }

    private func goBack() {
        let hangar = HangarScene(size: size)
        hangar.scaleMode = scaleMode
        view?.presentScene(hangar, transition: .push(with: .right, duration: 0.3))
    }

    private func launchMission(index: Int) {
        guard index < missions.count else { return }
        NavigationManager.shared.gameMode = .mission(missions[index])
        NavigationManager.shared.isInGame = true
    }
}
