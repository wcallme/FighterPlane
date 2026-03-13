import SpriteKit

class HangarScene: SKScene {

    private var loadoutSlots: [SKNode] = []
    private var upgradeNodes: [String: SKNode] = [:]

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.18, green: 0.18, blue: 0.22, alpha: 1.0)

        setupBackground()
        setupCurrencyBar()
        setupPlaneDisplay()
        setupUpgradePanel()
        setupLoadoutBar()
        setupButtons()
        setupPlayerInfo()
    }

    // MARK: - Setup

    private func setupBackground() {
        // Subtle gradient overlay
        let bg = SKShapeNode(rectOf: CGSize(width: size.width, height: size.height * 0.4))
        bg.fillColor = SKColor(red: 0.12, green: 0.14, blue: 0.18, alpha: 0.6)
        bg.strokeColor = .clear
        bg.position = CGPoint(x: size.width / 2, y: size.height * 0.2)
        bg.zPosition = -1
        addChild(bg)
    }

    private func setupCurrencyBar() {
        let barY = size.height - 22

        // Gems
        let gemIcon = SKSpriteNode(texture: SpriteGenerator.gemIcon())
        gemIcon.position = CGPoint(x: size.width - 155, y: barY)
        gemIcon.setScale(1.2)
        addChild(gemIcon)

        let gemLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        gemLabel.text = "\(PlayerData.shared.gems)"
        gemLabel.fontSize = 16
        gemLabel.fontColor = SKColor(red: 0.9, green: 0.3, blue: 0.8, alpha: 1)
        gemLabel.horizontalAlignmentMode = .left
        gemLabel.position = CGPoint(x: size.width - 140, y: barY - 6)
        gemLabel.name = "gemCount"
        addChild(gemLabel)

        // Coins
        let coinIcon = SKSpriteNode(texture: SpriteGenerator.coinIcon())
        coinIcon.position = CGPoint(x: size.width - 75, y: barY)
        coinIcon.setScale(1.2)
        addChild(coinIcon)

        let coinLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        coinLabel.text = "\(PlayerData.shared.coins)"
        coinLabel.fontSize = 16
        coinLabel.fontColor = SKColor(red: 0.9, green: 0.8, blue: 0.2, alpha: 1)
        coinLabel.horizontalAlignmentMode = .left
        coinLabel.position = CGPoint(x: size.width - 60, y: barY - 6)
        coinLabel.name = "coinCount"
        addChild(coinLabel)
    }

    private func setupPlaneDisplay() {
        // Big plane sprite in center
        let plane = SKSpriteNode(texture: SpriteGenerator.playerPlane())
        plane.setScale(3.0)
        plane.position = CGPoint(x: size.width / 2, y: size.height * 0.52)
        plane.zPosition = 5
        addChild(plane)

        // Shadow
        let shadow = SKSpriteNode(texture: SpriteGenerator.playerShadow())
        shadow.setScale(3.0)
        shadow.position = CGPoint(x: size.width / 2 + 12, y: size.height * 0.52 - 15)
        shadow.zPosition = 4
        shadow.alpha = 0.4
        addChild(shadow)

        // Plane name
        let planeName = SKLabelNode(fontNamed: "Menlo-Bold")
        planeName.text = "Fighter Plane Mk.I"
        planeName.fontSize = 14
        planeName.fontColor = SKColor(white: 0.8, alpha: 0.9)
        planeName.position = CGPoint(x: size.width / 2, y: size.height * 0.82)
        planeName.zPosition = 10
        addChild(planeName)

        // Stats display
        let data = PlayerData.shared
        let statsText = "HP: \(data.maxHealth)  SPD: \(String(format: "%.0f", data.speedMultiplier * 100))%  ENG: \(String(format: "%.0f", data.engineMultiplier * 100))%"
        let stats = SKLabelNode(fontNamed: "Menlo")
        stats.text = statsText
        stats.fontSize = 11
        stats.fontColor = SKColor(white: 0.6, alpha: 0.8)
        stats.position = CGPoint(x: size.width / 2, y: size.height * 0.78)
        stats.zPosition = 10
        addChild(stats)

        // Draw weapon attachment lines to loadout
        drawAttachmentLines()
    }

    private func drawAttachmentLines() {
        let data = PlayerData.shared
        let planeCenter = CGPoint(x: size.width / 2, y: size.height * 0.52)
        let slotY: CGFloat = 55

        // Hardpoints on the plane
        let hardpoints: [CGPoint] = [
            CGPoint(x: planeCenter.x - 50, y: planeCenter.y - 10),
            CGPoint(x: planeCenter.x - 25, y: planeCenter.y + 20),
            CGPoint(x: planeCenter.x, y: planeCenter.y + 30),
            CGPoint(x: planeCenter.x + 25, y: planeCenter.y + 20),
            CGPoint(x: planeCenter.x + 50, y: planeCenter.y - 10),
            CGPoint(x: planeCenter.x, y: planeCenter.y - 30),
        ]

        let slotSpacing: CGFloat = 55
        let totalWidth = slotSpacing * 5
        let startX = (size.width - totalWidth) / 2

        for i in 0..<6 {
            guard data.loadout[i] != nil else { continue }
            let slotX = startX + CGFloat(i) * slotSpacing
            let hp = hardpoints[i]

            let line = SKShapeNode()
            let path = CGMutablePath()
            path.move(to: hp)
            path.addLine(to: CGPoint(x: slotX, y: slotY + 20))
            line.path = path
            line.strokeColor = SKColor(white: 0.5, alpha: 0.3)
            line.lineWidth = 1
            line.zPosition = 3
            addChild(line)

            // Dot at hardpoint
            let dot = SKShapeNode(circleOfRadius: 3)
            dot.fillColor = SKColor(white: 0.8, alpha: 0.6)
            dot.strokeColor = .clear
            dot.position = hp
            dot.zPosition = 6
            addChild(dot)
        }
    }

    private func setupUpgradePanel() {
        let panelX: CGFloat = 85
        let startY = size.height * 0.62
        let spacing: CGFloat = 42

        for (index, upgrade) in UpgradeCatalog.all.enumerated() {
            let node = createUpgradeRow(upgrade: upgrade)
            node.position = CGPoint(x: panelX, y: startY - CGFloat(index) * spacing)
            node.name = "upgrade_\(upgrade.id)"
            addChild(node)
            upgradeNodes[upgrade.id] = node
        }
    }

    private func createUpgradeRow(upgrade: UpgradeInfo) -> SKNode {
        let node = SKNode()
        let data = PlayerData.shared
        let level = data.upgradeLevel(for: upgrade.id)

        // Background
        let bg = SKShapeNode(rectOf: CGSize(width: 140, height: 36), cornerRadius: 6)
        bg.fillColor = SKColor(red: 0.22, green: 0.25, blue: 0.30, alpha: 0.9)
        bg.strokeColor = SKColor(white: 0.4, alpha: 0.5)
        bg.lineWidth = 1
        bg.name = "upgrade_\(upgrade.id)"
        node.addChild(bg)

        // Name
        let nameLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        nameLabel.text = upgrade.name
        nameLabel.fontSize = 11
        nameLabel.fontColor = .white
        nameLabel.horizontalAlignmentMode = .left
        nameLabel.position = CGPoint(x: -62, y: 4)
        node.addChild(nameLabel)

        // Level pips
        for i in 0..<upgrade.maxLevel {
            let pip = SKShapeNode(rectOf: CGSize(width: 8, height: 6), cornerRadius: 1)
            pip.fillColor = i < level
                ? SKColor(red: 0.3, green: 0.8, blue: 0.3, alpha: 1)
                : SKColor(white: 0.3, alpha: 0.5)
            pip.strokeColor = .clear
            pip.position = CGPoint(x: -62 + CGFloat(i) * 11, y: -8)
            node.addChild(pip)
        }

        // Cost
        if level < upgrade.maxLevel {
            let cost = upgrade.cost(forLevel: level)
            let coinIcon = SKSpriteNode(texture: SpriteGenerator.coinIcon())
            coinIcon.position = CGPoint(x: 40, y: -1)
            coinIcon.setScale(0.7)
            node.addChild(coinIcon)

            let costLabel = SKLabelNode(fontNamed: "Menlo-Bold")
            costLabel.text = "\(cost)"
            costLabel.fontSize = 10
            costLabel.fontColor = SKColor(red: 0.9, green: 0.8, blue: 0.2, alpha: 1)
            costLabel.horizontalAlignmentMode = .left
            costLabel.position = CGPoint(x: 50, y: -5)
            node.addChild(costLabel)
        } else {
            let maxLabel = SKLabelNode(fontNamed: "Menlo-Bold")
            maxLabel.text = "MAX"
            maxLabel.fontSize = 10
            maxLabel.fontColor = SKColor(red: 0.3, green: 0.8, blue: 0.3, alpha: 1)
            maxLabel.position = CGPoint(x: 48, y: -5)
            node.addChild(maxLabel)
        }

        return node
    }

    private func setupLoadoutBar() {
        let slotSize: CGFloat = 44
        let spacing: CGFloat = 55
        let totalWidth = spacing * 5
        let startX = (size.width - totalWidth) / 2
        let slotY: CGFloat = 55

        let data = PlayerData.shared

        for i in 0..<6 {
            let slot = SKNode()
            slot.position = CGPoint(x: startX + CGFloat(i) * spacing, y: slotY)
            slot.name = "slot_\(i)"

            // Slot background
            let bg = SKShapeNode(rectOf: CGSize(width: slotSize, height: slotSize), cornerRadius: 6)
            if data.loadout[i] != nil {
                bg.fillColor = SKColor(red: 0.2, green: 0.3, blue: 0.2, alpha: 0.9)
                bg.strokeColor = SKColor(red: 0.4, green: 0.7, blue: 0.4, alpha: 0.8)
            } else {
                bg.fillColor = SKColor(white: 0.15, alpha: 0.8)
                bg.strokeColor = SKColor(white: 0.3, alpha: 0.5)
            }
            bg.lineWidth = 1.5
            bg.name = "slot_\(i)"
            slot.addChild(bg)

            // Weapon icon if equipped
            if let weaponId = data.loadout[i] {
                let icon = SKSpriteNode(texture: SpriteGenerator.weaponIcon(for: weaponId))
                icon.setScale(0.45)
                icon.position = .zero
                slot.addChild(icon)

                // Slot number
                let numLabel = SKLabelNode(fontNamed: "Menlo-Bold")
                numLabel.text = "\(i + 1)"
                numLabel.fontSize = 8
                numLabel.fontColor = SKColor(white: 0.6, alpha: 0.6)
                numLabel.position = CGPoint(x: -16, y: 14)
                slot.addChild(numLabel)
            } else {
                let emptyLabel = SKLabelNode(fontNamed: "Menlo")
                emptyLabel.text = "\(i + 1)"
                emptyLabel.fontSize = 14
                emptyLabel.fontColor = SKColor(white: 0.3, alpha: 0.5)
                emptyLabel.verticalAlignmentMode = .center
                slot.addChild(emptyLabel)
            }

            addChild(slot)
            loadoutSlots.append(slot)
        }
    }

    private func setupButtons() {
        // Armory button - left side
        let armoryBtn = createButton(
            text: "Armory", color: SKColor(red: 0.5, green: 0.2, blue: 0.6, alpha: 0.9),
            size: CGSize(width: 120, height: 40)
        )
        armoryBtn.position = CGPoint(x: 85, y: size.height * 0.35)
        armoryBtn.name = "armoryButton"
        addChild(armoryBtn)

        // Go! button - right side
        let goBtn = createButton(
            text: "Go!", color: SKColor(red: 0.2, green: 0.6, blue: 0.15, alpha: 0.9),
            size: CGSize(width: 140, height: 50)
        )
        goBtn.position = CGPoint(x: size.width - 90, y: size.height * 0.45)
        goBtn.name = "goButton"
        addChild(goBtn)

        // Pulse the Go button
        goBtn.run(.repeatForever(.sequence([
            .scale(to: 1.05, duration: 0.6),
            .scale(to: 1.0, duration: 0.6)
        ])))

        // Missions button
        let missionsBtn = createButton(
            text: "Missions", color: SKColor(red: 0.7, green: 0.5, blue: 0.1, alpha: 0.9),
            size: CGSize(width: 120, height: 40)
        )
        missionsBtn.position = CGPoint(x: size.width - 90, y: size.height * 0.30)
        missionsBtn.name = "missionsButton"
        addChild(missionsBtn)
    }

    private func createButton(text: String, color: SKColor, size btnSize: CGSize) -> SKNode {
        let node = SKNode()

        let bg = SKShapeNode(rectOf: btnSize, cornerRadius: 10)
        bg.fillColor = color
        bg.strokeColor = SKColor(white: 0.9, alpha: 0.4)
        bg.lineWidth = 2
        node.addChild(bg)

        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.text = text
        label.fontSize = text == "Go!" ? 24 : 14
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.position = .zero
        node.addChild(label)

        return node
    }

    private func setupPlayerInfo() {
        let data = PlayerData.shared

        let levelLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        levelLabel.text = "Level \(data.playerLevel)"
        levelLabel.fontSize = 14
        levelLabel.fontColor = .white
        levelLabel.horizontalAlignmentMode = .left
        levelLabel.position = CGPoint(x: 15, y: size.height - 22)
        levelLabel.zPosition = 10
        addChild(levelLabel)
    }

    // MARK: - Touch

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let tappedNodes = nodes(at: location)

        for node in tappedNodes {
            let name = node.name ?? node.parent?.name ?? ""

            if name == "goButton" || name.contains("Go!") {
                startGame()
                return
            }
            if name == "armoryButton" || name.contains("Armory") {
                openArmory()
                return
            }
            if name.hasPrefix("upgrade_") {
                let upgradeId = String(name.dropFirst("upgrade_".count))
                handleUpgradeTap(upgradeId)
                return
            }
        }
    }

    private func startGame() {
        NavigationManager.shared.isInGame = true
    }

    private func openArmory() {
        let armory = ArmoryScene(size: size)
        armory.scaleMode = scaleMode
        view?.presentScene(armory, transition: .push(with: .left, duration: 0.3))
    }

    private func handleUpgradeTap(_ upgradeId: String) {
        guard let upgrade = UpgradeCatalog.all.first(where: { $0.id == upgradeId }) else { return }

        if PlayerData.shared.purchaseUpgrade(upgrade) {
            // Refresh the upgrade row
            if let oldNode = upgradeNodes[upgradeId] {
                let pos = oldNode.position
                oldNode.removeFromParent()
                let newNode = createUpgradeRow(upgrade: upgrade)
                newNode.position = pos
                newNode.name = "upgrade_\(upgrade.id)"
                addChild(newNode)
                upgradeNodes[upgradeId] = newNode
            }
            refreshCurrency()

            // Flash effect
            let flash = SKShapeNode(rectOf: CGSize(width: 140, height: 36), cornerRadius: 6)
            flash.fillColor = SKColor(red: 0.3, green: 1.0, blue: 0.3, alpha: 0.3)
            flash.strokeColor = .clear
            flash.position = upgradeNodes[upgradeId]?.position ?? .zero
            flash.zPosition = 50
            addChild(flash)
            flash.run(.sequence([.fadeOut(withDuration: 0.3), .removeFromParent()]))
        }
    }

    private func refreshCurrency() {
        if let gem = childNode(withName: "gemCount") as? SKLabelNode {
            gem.text = "\(PlayerData.shared.gems)"
        }
        if let coin = childNode(withName: "coinCount") as? SKLabelNode {
            coin.text = "\(PlayerData.shared.coins)"
        }
    }
}
