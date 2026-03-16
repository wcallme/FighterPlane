import SpriteKit
import SceneKit
import Metal

class HangarScene: SKScene {

    private var loadoutSlots: [SKNode] = []
    private var upgradeNodes: [String: SKNode] = [:]
    private var safeTop: CGFloat = 59
    private var safeBottom: CGFloat = 34

    // Layout zones (computed once in didMove)
    private var planeAreaCenterY: CGFloat = 0
    private var upgradeRowY: CGFloat = 0
    private var loadoutRowY: CGFloat = 0
    private var buttonRowY: CGFloat = 0
    private var leftInfoX: CGFloat = 0
    private var rightInfoX: CGFloat = 0

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.06, green: 0.07, blue: 0.11, alpha: 1.0)
        safeTop = SafeArea.top
        safeBottom = SafeArea.bottom

        MenuMusicManager.shared.play()

        computeLayout()
        setupAtmosphericBackground()
        setupHeader()
        setupPlaneDisplay()
        setupUpgradeRow()
        setupLoadoutBar()
        setupActionButtons()

        // Signal that the menu is fully built so the splash overlay can fade out
        NotificationCenter.default.post(name: .menuSceneReady, object: nil)
    }

    // MARK: - Layout Computation

    private func computeLayout() {
        let usableTop = size.height - safeTop
        let usableBottom = safeBottom
        let safeLeft = SafeArea.left
        let safeRight = SafeArea.right
        let s = DeviceLayout.menuScale

        // Bottom sections — ensure enough clearance on iPhone 16/17 Pro
        let bottomPad = max(usableBottom, 21)
        buttonRowY = bottomPad + 30 * s
        loadoutRowY = buttonRowY + 54 * s
        upgradeRowY = loadoutRowY + 48 * s

        // Plane area: centered between upgrade section top and screen top
        let topBound = usableTop - 20
        let upgradeTop = upgradeRowY + 34 * s
        planeAreaCenterY = upgradeTop + (topBound - upgradeTop) * 0.5

        // Side info panels: centered in space between screen edges and plane zone
        let planeZoneHalf: CGFloat = 130 * s
        let planeZoneLeft = size.width / 2 - planeZoneHalf
        let planeZoneRight = size.width / 2 + planeZoneHalf
        leftInfoX = (safeLeft + planeZoneLeft) / 2
        rightInfoX = (planeZoneRight + size.width - safeRight) / 2
    }

    // MARK: - Atmospheric Background

    private func setupAtmosphericBackground() {
        // Deep gradient background layers
        let bgGradient = SKShapeNode(rectOf: CGSize(width: size.width + 4, height: size.height + 4))
        bgGradient.position = CGPoint(x: size.width / 2, y: size.height / 2)
        bgGradient.fillColor = SKColor(red: 0.06, green: 0.07, blue: 0.11, alpha: 1)
        bgGradient.strokeColor = .clear
        bgGradient.zPosition = -10
        addChild(bgGradient)

        // Oval glow behind plane / hangar area — taller to curve up around UI
        let glowW = size.width * 0.95
        let glowH = size.height * 0.75
        let glow = SKShapeNode(ellipseOf: CGSize(width: glowW, height: glowH))
        glow.fillColor = SKColor(red: 0.08, green: 0.18, blue: 0.12, alpha: 0.35)
        glow.strokeColor = .clear
        glow.position = CGPoint(x: size.width / 2, y: planeAreaCenterY - glowH * 0.08)
        glow.zPosition = -5
        glow.glowWidth = 40
        addChild(glow)

        // Floating dust particles
        for _ in 0..<30 {
            let particle = SKShapeNode(circleOfRadius: CGFloat.random(in: 0.5...1.5))
            particle.fillColor = SKColor(white: 1, alpha: CGFloat.random(in: 0.05...0.15))
            particle.strokeColor = .clear
            let startX = CGFloat.random(in: 0...size.width)
            let startY = CGFloat.random(in: 0...size.height)
            particle.position = CGPoint(x: startX, y: startY)
            particle.zPosition = -2

            let drift = SKAction.sequence([
                .moveBy(x: CGFloat.random(in: -20...20), y: CGFloat.random(in: 10...30), duration: Double.random(in: 4...8)),
                .moveBy(x: CGFloat.random(in: -20...20), y: CGFloat.random(in: 10...30), duration: Double.random(in: 4...8))
            ])
            let fade = SKAction.sequence([
                .fadeAlpha(to: CGFloat.random(in: 0.02...0.08), duration: Double.random(in: 2...4)),
                .fadeAlpha(to: CGFloat.random(in: 0.1...0.2), duration: Double.random(in: 2...4))
            ])
            particle.run(.repeatForever(.group([drift, fade])))

            addChild(particle)
        }

        // Horizontal scan line effect (subtle)
        let scanLine = SKShapeNode(rectOf: CGSize(width: size.width, height: 1))
        scanLine.fillColor = SKColor(red: 0.2, green: 0.9, blue: 0.4, alpha: 0.03)
        scanLine.strokeColor = .clear
        scanLine.position = CGPoint(x: size.width / 2, y: 0)
        scanLine.zPosition = -1
        addChild(scanLine)
        scanLine.run(.repeatForever(.sequence([
            .moveTo(y: size.height, duration: 4.0),
            .moveTo(y: 0, duration: 0)
        ])))

        // Bottom panel backing
        let panelTop = upgradeRowY + 42 * DeviceLayout.menuScale
        let bottomPanel = SKShapeNode(rect: CGRect(x: 0, y: 0, width: size.width, height: panelTop))
        bottomPanel.fillColor = SKColor(red: 0.05, green: 0.06, blue: 0.09, alpha: 0.88)
        bottomPanel.strokeColor = .clear
        bottomPanel.zPosition = 0
        addChild(bottomPanel)

        // Glowing divider above bottom panel
        let bottomDivider = SKShapeNode(rectOf: CGSize(width: size.width - 40, height: 1))
        bottomDivider.fillColor = SKColor(red: 0.2, green: 0.8, blue: 0.4, alpha: 0.2)
        bottomDivider.strokeColor = .clear
        bottomDivider.position = CGPoint(x: size.width / 2, y: panelTop)
        bottomDivider.zPosition = 10
        bottomDivider.glowWidth = 1
        addChild(bottomDivider)
    }

    // MARK: - Header

    private func setupHeader() {
        let data = PlayerData.shared
        let centerY = planeAreaCenterY
        let s = DeviceLayout.menuScale

        // --- LEFT SIDE: Title, Level, Settings ---

        // Title — centered above the plane (swapped with plane name position)
        let title = SKLabelNode(fontNamed: "Menlo-Bold")
        title.text = "FighterPlane"
        title.fontSize = DeviceLayout.fontSize(14)
        title.fontColor = SKColor(white: 0.75, alpha: 0.9)
        let titleY = min(planeAreaCenterY + 95 * s, size.height - max(safeTop, 10) - 35)
        title.position = CGPoint(x: size.width / 2, y: titleY)
        title.zPosition = 11
        addChild(title)

        // Player level badge
        let levelBadge = SKNode()
        levelBadge.position = CGPoint(x: leftInfoX, y: centerY - 10 * s)
        levelBadge.zPosition = 11

        let levelBg = SKShapeNode(rectOf: CGSize(width: 64 * s, height: 26 * s), cornerRadius: 13 * s)
        levelBg.fillColor = SKColor(red: 0.15, green: 0.25, blue: 0.45, alpha: 0.9)
        levelBg.strokeColor = SKColor(red: 0.3, green: 0.5, blue: 0.9, alpha: 0.5)
        levelBg.lineWidth = 1
        levelBg.glowWidth = 1
        levelBadge.addChild(levelBg)

        let levelLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        levelLabel.text = "LV \(data.playerLevel)"
        levelLabel.fontSize = DeviceLayout.fontSize(12)
        levelLabel.fontColor = SKColor(red: 0.6, green: 0.8, blue: 1, alpha: 1)
        levelLabel.verticalAlignmentMode = .center
        levelBadge.addChild(levelLabel)

        addChild(levelBadge)

        // Settings button
        let settingsBtn = SKNode()
        settingsBtn.name = "settingsButton"
        settingsBtn.position = CGPoint(x: leftInfoX, y: centerY - 45 * s)
        settingsBtn.zPosition = 11

        let settingsBg = SKShapeNode(circleOfRadius: 13 * s)
        settingsBg.fillColor = SKColor(white: 0.15, alpha: 0.6)
        settingsBg.strokeColor = SKColor(white: 0.3, alpha: 0.3)
        settingsBg.lineWidth = 1
        settingsBg.name = "settingsButton"
        settingsBtn.addChild(settingsBg)

        let gearLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        gearLabel.text = "\u{2699}"
        gearLabel.fontSize = DeviceLayout.fontSize(16)
        gearLabel.fontColor = SKColor(white: 0.6, alpha: 0.8)
        gearLabel.verticalAlignmentMode = .center
        gearLabel.name = "settingsButton"
        settingsBtn.addChild(gearLabel)
        addChild(settingsBtn)

        // --- RIGHT SIDE: Gems, Coins ---

        // Gems
        let gemIcon = SKSpriteNode(texture: SpriteGenerator.gemIcon())
        gemIcon.position = CGPoint(x: rightInfoX - 14 * s, y: centerY + 15 * s)
        gemIcon.setScale(1.2 * s)
        gemIcon.zPosition = 11
        addChild(gemIcon)

        let gemLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        gemLabel.text = "\(data.gems)"
        gemLabel.fontSize = DeviceLayout.fontSize(14)
        gemLabel.fontColor = SKColor(red: 0.9, green: 0.3, blue: 0.8, alpha: 1)
        gemLabel.horizontalAlignmentMode = .left
        gemLabel.position = CGPoint(x: rightInfoX, y: centerY + 10 * s)
        gemLabel.zPosition = 11
        gemLabel.name = "gemCount"
        addChild(gemLabel)

        // Coins
        let coinIcon = SKSpriteNode(texture: SpriteGenerator.coinIcon())
        coinIcon.position = CGPoint(x: rightInfoX - 14 * s, y: centerY - 20 * s)
        coinIcon.setScale(1.2 * s)
        coinIcon.zPosition = 11
        addChild(coinIcon)

        let coinLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        coinLabel.text = "\(data.coins)"
        coinLabel.fontSize = DeviceLayout.fontSize(14)
        coinLabel.fontColor = SKColor(red: 0.9, green: 0.8, blue: 0.2, alpha: 1)
        coinLabel.horizontalAlignmentMode = .left
        coinLabel.position = CGPoint(x: rightInfoX, y: centerY - 25 * s)
        coinLabel.zPosition = 11
        coinLabel.name = "coinCount"
        addChild(coinLabel)
    }

    // MARK: - Plane Display

    private func setupPlaneDisplay() {
        let s = DeviceLayout.menuScale

        // Plane model label — on the left side (swapped with title position)
        let modelLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        modelLabel.text = PlayerData.shared.selectedPlaneName
        modelLabel.fontSize = DeviceLayout.fontSize(18)
        modelLabel.fontColor = SKColor(white: 0.92, alpha: 1)
        modelLabel.position = CGPoint(x: leftInfoX, y: planeAreaCenterY + 30 * s)
        modelLabel.zPosition = 10
        modelLabel.name = "planeNameLabel"
        addChild(modelLabel)

        // Plane selection arrows — just outside the plane image edges
        let arrowOffset: CGFloat = 105 * s
        let leftArrow = createArrowButton(text: "\u{25C0}", name: "planeLeft")
        leftArrow.position = CGPoint(x: size.width / 2 - arrowOffset, y: planeAreaCenterY)
        addChild(leftArrow)

        let rightArrow = createArrowButton(text: "\u{25B6}", name: "planeRight")
        rightArrow.position = CGPoint(x: size.width / 2 + arrowOffset, y: planeAreaCenterY)
        addChild(rightArrow)

        // 3D plane rendered as a sprite (SCNRenderer snapshot - avoids SK3DNode crashes)
        let planeSprite = SKSpriteNode()
        planeSprite.position = CGPoint(x: size.width / 2, y: planeAreaCenterY)
        planeSprite.zPosition = 5
        planeSprite.name = "planeSprite"
        addChild(planeSprite)

        updatePlaneSprite(planeId: PlayerData.shared.selectedPlaneId)

        // Gentle floating hover
        let hover = SKAction.sequence([
            .moveBy(x: 0, y: 7 * s, duration: 1.6),
            .moveBy(x: 0, y: -7 * s, duration: 1.6)
        ])
        planeSprite.run(.repeatForever(hover))

        // Under-plane glow disc
        let planeGlow = SKShapeNode(ellipseOf: CGSize(width: 100 * s, height: 30 * s))
        planeGlow.fillColor = SKColor(red: 0.15, green: 0.6, blue: 0.25, alpha: 0.15)
        planeGlow.strokeColor = .clear
        planeGlow.position = CGPoint(x: size.width / 2, y: planeAreaCenterY - 50 * s)
        planeGlow.zPosition = 3
        planeGlow.glowWidth = 8
        addChild(planeGlow)

        let glowPulse = SKAction.sequence([
            .fadeAlpha(to: 0.08, duration: 1.6),
            .fadeAlpha(to: 0.2, duration: 1.6)
        ])
        planeGlow.run(.repeatForever(glowPulse))
    }

    private static let menuImageMap: [String: String] = [
        "F16": "MenuF16",
        "F22": "MenuF22",
        "B2":  "MenuB2",
    ]

    private func updatePlaneSprite(planeId: String) {
        guard let sprite = childNode(withName: "planeSprite") as? SKSpriteNode else { return }

        // Try pre-rendered menu image first (much faster than USDZ snapshot)
        if let assetName = Self.menuImageMap[planeId],
           let img = UIImage(named: assetName) {
            let texture = SKTexture(image: img)
            sprite.texture = texture
            let ps = DeviceLayout.menuScale
            sprite.size = CGSize(width: 180 * ps, height: 138 * ps)
            return
        }

        // Fallback to USDZ snapshot for planes without menu images
        let renderSize = CGSize(width: 360, height: 276)
        guard let image = renderPlaneSnapshot(planeId: planeId, size: renderSize) else { return }

        let texture = SKTexture(image: image)
        sprite.texture = texture
        let ps = DeviceLayout.menuScale
        sprite.size = CGSize(width: 180 * ps, height: 138 * ps)
    }

    private func renderPlaneSnapshot(planeId: String, size: CGSize) -> UIImage? {
        let scene = SCNScene()
        scene.background.contents = UIColor.clear

        // Lighting
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light!.type = .ambient
        ambientLight.light!.color = UIColor(red: 0.5, green: 0.55, blue: 0.65, alpha: 1)
        ambientLight.light!.intensity = 500
        scene.rootNode.addChildNode(ambientLight)

        let dirLight = SCNNode()
        dirLight.light = SCNLight()
        dirLight.light!.type = .directional
        dirLight.light!.color = UIColor(white: 1.0, alpha: 1)
        dirLight.light!.intensity = 900
        dirLight.eulerAngles = SCNVector3(-0.5, -0.4, 0)
        scene.rootNode.addChildNode(dirLight)

        let fillLight = SCNNode()
        fillLight.light = SCNLight()
        fillLight.light!.type = .directional
        fillLight.light!.color = UIColor(red: 0.3, green: 0.6, blue: 0.4, alpha: 1)
        fillLight.light!.intensity = 300
        fillLight.eulerAngles = SCNVector3(0.4, 0.6, 0)
        scene.rootNode.addChildNode(fillLight)

        // Environment for PBR materials (USDZ models)
        scene.lightingEnvironment.contents = UIColor(red: 0.3, green: 0.4, blue: 0.5, alpha: 1)
        scene.lightingEnvironment.intensity = 2.0

        // Camera
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera!.fieldOfView = 40
        cameraNode.position = SCNVector3(4, 3, 6)
        cameraNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(cameraNode)

        // Plane model
        let model = ModelGenerator3D.hangarPlane(forId: planeId)
        // Nice 3/4 viewing angle
        model.eulerAngles.y = Float.pi / 5
        scene.rootNode.addChildNode(model)

        // Render offscreen using SCNRenderer
        guard let device = MTLCreateSystemDefaultDevice() else { return nil }
        let renderer = SCNRenderer(device: device, options: nil)
        renderer.scene = scene
        renderer.pointOfView = cameraNode
        return renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X)
    }

    private func createArrowButton(text: String, name: String) -> SKNode {
        let s = DeviceLayout.menuScale
        let node = SKNode()
        node.name = name
        node.zPosition = 10

        let bg = SKShapeNode(circleOfRadius: 18 * s)
        bg.fillColor = SKColor(white: 0.15, alpha: 0.6)
        bg.strokeColor = SKColor(white: 0.4, alpha: 0.3)
        bg.lineWidth = 1
        bg.name = name
        node.addChild(bg)

        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.text = text
        label.fontSize = DeviceLayout.fontSize(16)
        label.fontColor = SKColor(white: 0.7, alpha: 0.9)
        label.verticalAlignmentMode = .center
        label.name = name
        node.addChild(label)

        return node
    }

    // MARK: - Upgrade Row

    private func setupUpgradeRow() {
        let s = DeviceLayout.menuScale
        let upgrades = UpgradeCatalog.all
        let spacing: CGFloat = 120 * s
        let totalWidth = CGFloat(upgrades.count - 1) * spacing
        let startX = size.width / 2 - totalWidth / 2

        // Section label
        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.text = "UPGRADES"
        label.fontSize = DeviceLayout.fontSize(9)
        label.fontColor = SKColor(white: 0.35, alpha: 0.6)
        label.position = CGPoint(x: size.width / 2, y: upgradeRowY + 28 * s)
        label.zPosition = 11
        addChild(label)

        for (index, upgrade) in upgrades.enumerated() {
            let node = createUpgradeChip(upgrade: upgrade)
            node.position = CGPoint(x: startX + CGFloat(index) * spacing, y: upgradeRowY)
            node.name = "upgrade_\(upgrade.id)"
            addChild(node)
            upgradeNodes[upgrade.id] = node
        }
    }

    private func statText(for upgradeId: String) -> String {
        let data = PlayerData.shared
        switch upgradeId {
        case "armor":  return "HP \(data.maxHealth)"
        case "wings":  return "SPD \(Int(data.speedMultiplier * 100))%"
        case "engine": return "ENG \(Int(data.engineMultiplier * 100))%"
        default:       return ""
        }
    }

    private func createUpgradeChip(upgrade: UpgradeInfo) -> SKNode {
        let s = DeviceLayout.menuScale
        let node = SKNode()
        let data = PlayerData.shared
        let level = data.upgradeLevel(for: upgrade.id)

        let chipW: CGFloat = 110 * s
        let chipH: CGFloat = 40 * s

        let bg = SKShapeNode(rectOf: CGSize(width: chipW, height: chipH), cornerRadius: 8 * s)
        bg.fillColor = SKColor(red: 0.10, green: 0.12, blue: 0.18, alpha: 0.95)
        bg.strokeColor = SKColor(red: 0.25, green: 0.5, blue: 0.35, alpha: 0.3)
        bg.lineWidth = 1
        bg.name = "upgrade_\(upgrade.id)"
        node.addChild(bg)

        // Top row: upgrade name (left) + stat value (right)
        let nameLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        nameLabel.text = upgrade.name.uppercased()
        nameLabel.fontSize = DeviceLayout.fontSize(9)
        nameLabel.fontColor = SKColor(white: 0.75, alpha: 1)
        nameLabel.horizontalAlignmentMode = .left
        nameLabel.position = CGPoint(x: -48 * s, y: 7 * s)
        node.addChild(nameLabel)

        let statLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        statLabel.text = statText(for: upgrade.id)
        statLabel.fontSize = DeviceLayout.fontSize(9)
        statLabel.fontColor = SKColor(red: 0.4, green: 0.85, blue: 0.55, alpha: 1)
        statLabel.horizontalAlignmentMode = .right
        statLabel.position = CGPoint(x: 50 * s, y: 7 * s)
        node.addChild(statLabel)

        // Middle row: upgrade pips
        for i in 0..<upgrade.maxLevel {
            let pip = SKShapeNode(rectOf: CGSize(width: 5 * s, height: 4 * s), cornerRadius: 1)
            pip.fillColor = i < level
                ? SKColor(red: 0.25, green: 0.85, blue: 0.35, alpha: 1)
                : SKColor(white: 0.2, alpha: 0.4)
            pip.strokeColor = .clear
            pip.position = CGPoint(x: (-48 + CGFloat(i) * 7) * s, y: -4 * s)
            if i < level {
                pip.glowWidth = 1
            }
            node.addChild(pip)
        }

        // Bottom-right: cost or MAX
        if level < upgrade.maxLevel {
            let cost = upgrade.cost(forLevel: level)
            let costLabel = SKLabelNode(fontNamed: "Menlo-Bold")
            costLabel.text = "\(cost)"
            costLabel.fontSize = DeviceLayout.fontSize(9)
            costLabel.fontColor = SKColor(red: 0.9, green: 0.8, blue: 0.2, alpha: 1)
            costLabel.horizontalAlignmentMode = .right
            costLabel.position = CGPoint(x: 50 * s, y: -13 * s)
            node.addChild(costLabel)

            let coinIcon = SKSpriteNode(texture: SpriteGenerator.coinIcon())
            coinIcon.position = CGPoint(x: 50 * s - costLabel.frame.width - 6 * s, y: -9 * s)
            coinIcon.setScale(0.55 * s)
            node.addChild(coinIcon)
        } else {
            let maxLabel = SKLabelNode(fontNamed: "Menlo-Bold")
            maxLabel.text = "MAX"
            maxLabel.fontSize = DeviceLayout.fontSize(9)
            maxLabel.fontColor = SKColor(red: 0.25, green: 0.85, blue: 0.35, alpha: 1)
            maxLabel.horizontalAlignmentMode = .right
            maxLabel.position = CGPoint(x: 50 * s, y: -13 * s)
            node.addChild(maxLabel)
        }

        return node
    }

    // MARK: - Loadout Bar

    private func setupLoadoutBar() {
        let s = DeviceLayout.menuScale
        let data = PlayerData.shared
        let slots = data.slotCount
        let currentLoadout = data.loadout  // cache once to avoid repeated UserDefaults reads

        // Dynamically size slots to fit the screen
        let maxSlotSize: CGFloat = 40 * s
        let margin: CGFloat = 20 * s
        let gapRatio: CGFloat = 0.25  // gap = 25% of slot size
        let slotSize = min(maxSlotSize, (size.width - margin * 2) / (CGFloat(slots) * (1 + gapRatio) - gapRatio))
        let spacing = slotSize * (1 + gapRatio)
        let totalWidth = spacing * CGFloat(slots - 1)
        let startX = (size.width - totalWidth) / 2

        // Section label
        let loadoutLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        loadoutLabel.text = "LOADOUT"
        loadoutLabel.fontSize = DeviceLayout.fontSize(9)
        loadoutLabel.fontColor = SKColor(white: 0.35, alpha: 0.6)
        loadoutLabel.position = CGPoint(x: size.width / 2, y: loadoutRowY + 28 * s)
        loadoutLabel.zPosition = 10
        addChild(loadoutLabel)

        for i in 0..<slots {
            let slot = SKNode()
            slot.position = CGPoint(x: startX + CGFloat(i) * spacing, y: loadoutRowY)
            slot.name = "slot_\(i)"
            slot.zPosition = 10

            let bg = SKShapeNode(rectOf: CGSize(width: slotSize, height: slotSize), cornerRadius: 8 * s)
            if currentLoadout[i] != nil {
                bg.fillColor = SKColor(red: 0.10, green: 0.22, blue: 0.12, alpha: 0.95)
                bg.strokeColor = SKColor(red: 0.25, green: 0.6, blue: 0.3, alpha: 0.6)
                bg.glowWidth = 1
            } else {
                bg.fillColor = SKColor(white: 0.08, alpha: 0.8)
                bg.strokeColor = SKColor(white: 0.2, alpha: 0.3)
            }
            bg.lineWidth = 1
            bg.name = "slot_\(i)"
            slot.addChild(bg)

            if let weaponId = currentLoadout[i] {
                let icon = SKSpriteNode(texture: SpriteGenerator.weaponIcon(for: weaponId))
                icon.setScale(0.40 * s)
                icon.position = .zero
                slot.addChild(icon)

                let numLabel = SKLabelNode(fontNamed: "Menlo-Bold")
                numLabel.text = "\(i + 1)"
                numLabel.fontSize = DeviceLayout.fontSize(7)
                numLabel.fontColor = SKColor(white: 0.45, alpha: 0.5)
                numLabel.position = CGPoint(x: -14 * s, y: 12 * s)
                slot.addChild(numLabel)
            } else {
                let emptyLabel = SKLabelNode(fontNamed: "Menlo")
                emptyLabel.text = "\(i + 1)"
                emptyLabel.fontSize = DeviceLayout.fontSize(13)
                emptyLabel.fontColor = SKColor(white: 0.2, alpha: 0.35)
                emptyLabel.verticalAlignmentMode = .center
                slot.addChild(emptyLabel)
            }

            addChild(slot)
            loadoutSlots.append(slot)
        }
    }

    // MARK: - Action Buttons (Premium Design)

    private func setupActionButtons() {
        let s = DeviceLayout.menuScale
        let safeLeft = SafeArea.left
        let safeRight = SafeArea.right
        let btnSpacing: CGFloat = 8 * s
        let usableWidth = size.width - safeLeft - safeRight
        let sideWidth: CGFloat = (usableWidth - btnSpacing * 4) * 0.28
        let centerWidth: CGFloat = (usableWidth - btnSpacing * 4) * 0.44
        let btnH: CGFloat = 44 * s
        let heroBtnH: CGFloat = 48 * s

        let leftX = safeLeft + btnSpacing * 1.5 + sideWidth / 2
        let centerX = size.width / 2
        let rightX = size.width - safeRight - btnSpacing * 1.5 - sideWidth / 2

        // ARMORY button - left (purple theme)
        let armoryBtn = createPremiumButton(
            text: "ARMORY",
            icon: "\u{2694}",
            width: sideWidth,
            height: btnH,
            primaryColor: SKColor(red: 0.35, green: 0.15, blue: 0.55, alpha: 1),
            accentColor: SKColor(red: 0.6, green: 0.3, blue: 0.9, alpha: 1),
            glowColor: SKColor(red: 0.5, green: 0.2, blue: 0.8, alpha: 0.3),
            fontSize: DeviceLayout.fontSize(11)
        )
        armoryBtn.position = CGPoint(x: leftX, y: buttonRowY)
        armoryBtn.name = "armoryButton"
        armoryBtn.zPosition = 20
        addChild(armoryBtn)

        // MISSIONS button - center (gold theme, hero button)
        let missionsBtn = createPremiumButton(
            text: "MISSIONS",
            icon: "\u{1F3AF}",
            width: centerWidth,
            height: heroBtnH,
            primaryColor: SKColor(red: 0.50, green: 0.35, blue: 0.08, alpha: 1),
            accentColor: SKColor(red: 0.95, green: 0.75, blue: 0.15, alpha: 1),
            glowColor: SKColor(red: 0.8, green: 0.6, blue: 0.1, alpha: 0.3),
            fontSize: DeviceLayout.fontSize(16)
        )
        missionsBtn.position = CGPoint(x: centerX, y: buttonRowY)
        missionsBtn.name = "missionsButton"
        missionsBtn.zPosition = 20
        addChild(missionsBtn)

        // DEPLOY button - right (green theme)
        let goBtn = createPremiumButton(
            text: "DEPLOY",
            icon: "\u{1F680}",
            width: sideWidth,
            height: btnH,
            primaryColor: SKColor(red: 0.10, green: 0.45, blue: 0.12, alpha: 1),
            accentColor: SKColor(red: 0.2, green: 0.9, blue: 0.3, alpha: 1),
            glowColor: SKColor(red: 0.15, green: 0.8, blue: 0.25, alpha: 0.4),
            fontSize: DeviceLayout.fontSize(11)
        )
        goBtn.position = CGPoint(x: rightX, y: buttonRowY)
        goBtn.name = "goButton"
        goBtn.zPosition = 20
        addChild(goBtn)

        // Deploy button pulse animation
        let pulse = SKAction.sequence([
            .group([
                .scale(to: 1.04, duration: 0.8),
            ]),
            .group([
                .scale(to: 1.0, duration: 0.8),
            ])
        ])
        goBtn.run(.repeatForever(pulse))

        // Animated glow ring behind deploy button
        let glowRing = SKShapeNode(rectOf: CGSize(width: sideWidth + 6, height: btnH + 6), cornerRadius: 14 * s)
        glowRing.fillColor = .clear
        glowRing.strokeColor = SKColor(red: 0.2, green: 0.9, blue: 0.3, alpha: 0.2)
        glowRing.lineWidth = 2
        glowRing.glowWidth = 6
        glowRing.position = CGPoint(x: rightX, y: buttonRowY)
        glowRing.zPosition = 19
        addChild(glowRing)

        let ringPulse = SKAction.sequence([
            .fadeAlpha(to: 0.08, duration: 1.0),
            .fadeAlpha(to: 0.35, duration: 1.0)
        ])
        glowRing.run(.repeatForever(ringPulse))
    }

    private func createPremiumButton(
        text: String,
        icon: String,
        width: CGFloat,
        height: CGFloat,
        primaryColor: SKColor,
        accentColor: SKColor,
        glowColor: SKColor,
        fontSize: CGFloat
    ) -> SKNode {
        let node = SKNode()

        // Outer glow layer
        let outerGlow = SKShapeNode(rectOf: CGSize(width: width + 4, height: height + 4), cornerRadius: 14)
        outerGlow.fillColor = glowColor
        outerGlow.strokeColor = .clear
        outerGlow.glowWidth = 4
        outerGlow.alpha = 0.6
        node.addChild(outerGlow)

        // Main button body
        let body = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: 12)
        body.fillColor = primaryColor
        body.strokeColor = accentColor.withAlphaComponent(0.5)
        body.lineWidth = 1.5
        body.name = node.name
        node.addChild(body)

        // Inner highlight (top edge shine)
        let highlight = SKShapeNode(rectOf: CGSize(width: width - 8, height: height * 0.4), cornerRadius: 8)
        highlight.fillColor = SKColor(white: 1, alpha: 0.06)
        highlight.strokeColor = .clear
        highlight.position = CGPoint(x: 0, y: height * 0.15)
        node.addChild(highlight)

        // Bottom edge shadow
        let bottomEdge = SKShapeNode(rectOf: CGSize(width: width - 4, height: 3), cornerRadius: 1.5)
        bottomEdge.fillColor = SKColor(white: 0, alpha: 0.3)
        bottomEdge.strokeColor = .clear
        bottomEdge.position = CGPoint(x: 0, y: -height / 2 + 2)
        node.addChild(bottomEdge)

        // Icon
        let iconLabel = SKLabelNode(fontNamed: "AppleColorEmoji")
        iconLabel.text = icon
        iconLabel.fontSize = fontSize * 0.9
        iconLabel.verticalAlignmentMode = .center
        iconLabel.position = CGPoint(x: 0, y: fontSize > 14 ? 8 : 6)
        node.addChild(iconLabel)

        // Text label
        let textLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        textLabel.text = text
        textLabel.fontSize = fontSize
        textLabel.fontColor = .white
        textLabel.verticalAlignmentMode = .center
        textLabel.position = CGPoint(x: 0, y: fontSize > 14 ? -10 : -8)
        node.addChild(textLabel)

        // Shimmer effect (moving highlight across button)
        let shimmer = SKShapeNode(rectOf: CGSize(width: 20, height: height - 4), cornerRadius: 10)
        shimmer.fillColor = SKColor(white: 1, alpha: 0.08)
        shimmer.strokeColor = .clear
        shimmer.position = CGPoint(x: -width / 2 - 20, y: 0)
        shimmer.zPosition = 2
        node.addChild(shimmer)

        let shimmerAction = SKAction.sequence([
            .moveTo(x: -width / 2 - 20, duration: 0),
            .wait(forDuration: Double.random(in: 2...5)),
            .moveTo(x: width / 2 + 20, duration: 0.6),
            .wait(forDuration: Double.random(in: 3...6))
        ])
        shimmer.run(.repeatForever(shimmerAction))

        return node
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let tappedNodes = nodes(at: location)

        for node in tappedNodes {
            let name = node.name ?? node.parent?.name ?? node.parent?.parent?.name ?? ""

            if name == "goButton" {
                animateButtonPress(named: "goButton")
                startGame()
                return
            }
            if name == "armoryButton" {
                animateButtonPress(named: "armoryButton")
                openArmory()
                return
            }
            if name == "missionsButton" {
                animateButtonPress(named: "missionsButton")
                openMissions()
                return
            }
            if name == "planeLeft" {
                cyclePlane(direction: -1)
                return
            }
            if name == "planeRight" {
                cyclePlane(direction: 1)
                return
            }
            if name == "settingsButton" {
                showSettingsOverlay()
                return
            }
            if name == "resetMissionsButton" {
                confirmResetMissions()
                return
            }
            if name == "resetConfirmYes" {
                MissionProgress.reset()
                dismissSettingsOverlay()
                return
            }
            if name == "resetConfirmNo" || name == "settingsOverlayBg" {
                dismissSettingsOverlay()
                return
            }
            if name.hasPrefix("upgrade_") {
                let upgradeId = String(name.dropFirst("upgrade_".count))
                handleUpgradeTap(upgradeId)
                return
            }
            if name.hasPrefix("slot_") {
                if let slotIndex = Int(String(name.dropFirst("slot_".count))) {
                    handleSlotTap(slotIndex)
                }
                return
            }
        }
    }

    private func animateButtonPress(named name: String) {
        guard let btn = childNode(withName: name) else { return }
        btn.run(.sequence([
            .scale(to: 0.93, duration: 0.06),
            .scale(to: 1.0, duration: 0.12)
        ]))
    }

    // MARK: - Actions

    private func startGame() {
        MenuMusicManager.shared.stop()
        NavigationManager.shared.gameMode = .infiniteBattle
        NavigationManager.shared.isInGame = true
    }

    private func openMissions() {
        let missionScene = MissionSelectScene(size: size)
        missionScene.scaleMode = scaleMode
        view?.presentScene(missionScene, transition: .push(with: .left, duration: 0.3))
    }

    private func openArmory() {
        let armory = ArmoryScene(size: size)
        armory.scaleMode = scaleMode
        view?.presentScene(armory, transition: .push(with: .left, duration: 0.3))
    }

    private func handleSlotTap(_ slotIndex: Int) {
        let data = PlayerData.shared
        guard slotIndex >= 0, slotIndex < data.slotCount, data.loadout[slotIndex] != nil else { return }

        data.unequipSlot(slotIndex)
        refreshLoadout()

        // Red flash on the slot
        let slots = data.slotCount
        let maxSlotSize: CGFloat = 40
        let margin: CGFloat = 20
        let gapRatio: CGFloat = 0.25
        let slotSz = min(maxSlotSize, (size.width - margin * 2) / (CGFloat(slots) * (1 + gapRatio) - gapRatio))
        let slotSpacing = slotSz * (1 + gapRatio)
        let totalWidth = slotSpacing * CGFloat(slots - 1)
        let startX = (size.width - totalWidth) / 2
        let slotX = startX + CGFloat(slotIndex) * slotSpacing

        let flash = SKShapeNode(rectOf: CGSize(width: 40, height: 40), cornerRadius: 8)
        flash.fillColor = SKColor(red: 1.0, green: 0.3, blue: 0.2, alpha: 0.3)
        flash.strokeColor = .clear
        flash.glowWidth = 3
        flash.position = CGPoint(x: slotX, y: loadoutRowY)
        flash.zPosition = 50
        addChild(flash)
        flash.run(.sequence([.fadeOut(withDuration: 0.3), .removeFromParent()]))
    }

    private func refreshLoadout() {
        for slot in loadoutSlots {
            slot.removeFromParent()
        }
        loadoutSlots.removeAll()
        setupLoadoutBar()
    }

    private func refreshUpgrades() {
        for (id, node) in upgradeNodes {
            node.removeFromParent()
            upgradeNodes.removeValue(forKey: id)
        }
        let s = DeviceLayout.menuScale
        let upgrades = UpgradeCatalog.all
        let spacing: CGFloat = 120 * s
        let totalWidth = CGFloat(upgrades.count - 1) * spacing
        let startX = size.width / 2 - totalWidth / 2
        for (index, upgrade) in upgrades.enumerated() {
            let node = createUpgradeChip(upgrade: upgrade)
            node.position = CGPoint(x: startX + CGFloat(index) * spacing, y: upgradeRowY)
            node.name = "upgrade_\(upgrade.id)"
            addChild(node)
            upgradeNodes[upgrade.id] = node
        }
    }

    private func handleUpgradeTap(_ upgradeId: String) {
        guard let upgrade = UpgradeCatalog.all.first(where: { $0.id == upgradeId }) else { return }

        if PlayerData.shared.purchaseUpgrade(upgrade) {
            if let oldNode = upgradeNodes[upgradeId] {
                let pos = oldNode.position
                oldNode.removeFromParent()
                let newNode = createUpgradeChip(upgrade: upgrade)
                newNode.position = pos
                newNode.name = "upgrade_\(upgrade.id)"
                addChild(newNode)
                upgradeNodes[upgradeId] = newNode
            }
            refreshCurrency()

            // Success flash
            let flash = SKShapeNode(rectOf: CGSize(width: 110, height: 40), cornerRadius: 8)
            flash.fillColor = SKColor(red: 0.2, green: 1.0, blue: 0.3, alpha: 0.25)
            flash.strokeColor = .clear
            flash.glowWidth = 4
            flash.position = upgradeNodes[upgradeId]?.position ?? .zero
            flash.zPosition = 50
            addChild(flash)
            flash.run(.sequence([.fadeOut(withDuration: 0.35), .removeFromParent()]))
        }
    }

    private func cyclePlane(direction: Int) {
        let data = PlayerData.shared
        let current = data.selectedPlaneId
        let newPlane = direction > 0
            ? PlaneCatalog.nextPlane(after: current)
            : PlaneCatalog.previousPlane(before: current)
        data.selectedPlaneId = newPlane.id

        if let label = childNode(withName: "planeNameLabel") as? SKLabelNode {
            label.text = newPlane.name
        }

        // Update the 3D plane render
        updatePlaneSprite(planeId: newPlane.id)

        // Refresh loadout and upgrades since they are per-plane
        refreshLoadout()
        refreshUpgrades()
    }

    private func refreshCurrency() {
        if let gem = childNode(withName: "gemCount") as? SKLabelNode {
            gem.text = "\(PlayerData.shared.gems)"
        }
        if let coin = childNode(withName: "coinCount") as? SKLabelNode {
            coin.text = "\(PlayerData.shared.coins)"
        }
    }

    // MARK: - Settings Overlay

    private func showSettingsOverlay() {
        guard childNode(withName: "settingsOverlay") == nil else { return }

        let overlay = SKNode()
        overlay.name = "settingsOverlay"
        overlay.zPosition = 100

        // Dim background
        let dimBg = SKShapeNode(rectOf: CGSize(width: size.width + 4, height: size.height + 4))
        dimBg.position = CGPoint(x: size.width / 2, y: size.height / 2)
        dimBg.fillColor = SKColor(white: 0, alpha: 0.6)
        dimBg.strokeColor = .clear
        dimBg.name = "settingsOverlayBg"
        overlay.addChild(dimBg)

        // Panel
        let panelW: CGFloat = size.width - 60
        let panelH: CGFloat = 200
        let panelY = size.height / 2

        let panel = SKShapeNode(rectOf: CGSize(width: panelW, height: panelH), cornerRadius: 16)
        panel.fillColor = SKColor(red: 0.08, green: 0.09, blue: 0.14, alpha: 0.98)
        panel.strokeColor = SKColor(red: 0.3, green: 0.5, blue: 0.35, alpha: 0.4)
        panel.lineWidth = 1
        panel.position = CGPoint(x: size.width / 2, y: panelY)
        panel.glowWidth = 3
        overlay.addChild(panel)

        // Title
        let title = SKLabelNode(fontNamed: "Menlo-Bold")
        title.text = "SETTINGS"
        title.fontSize = 16
        title.fontColor = SKColor(white: 0.9, alpha: 1)
        title.position = CGPoint(x: size.width / 2, y: panelY + 65)
        overlay.addChild(title)

        // Reset Missions button
        let resetBtn = SKNode()
        resetBtn.name = "resetMissionsButton"
        resetBtn.position = CGPoint(x: size.width / 2, y: panelY + 10)

        let resetBg = SKShapeNode(rectOf: CGSize(width: panelW - 40, height: 40), cornerRadius: 10)
        resetBg.fillColor = SKColor(red: 0.35, green: 0.08, blue: 0.08, alpha: 0.9)
        resetBg.strokeColor = SKColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 0.4)
        resetBg.lineWidth = 1
        resetBg.name = "resetMissionsButton"
        resetBtn.addChild(resetBg)

        let resetLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        resetLabel.text = "RESET MISSION PROGRESS"
        resetLabel.fontSize = 12
        resetLabel.fontColor = SKColor(red: 1.0, green: 0.4, blue: 0.3, alpha: 1)
        resetLabel.verticalAlignmentMode = .center
        resetLabel.name = "resetMissionsButton"
        resetBtn.addChild(resetLabel)
        overlay.addChild(resetBtn)

        // Close button
        let closeBtn = SKNode()
        closeBtn.name = "settingsOverlayBg"
        closeBtn.position = CGPoint(x: size.width / 2, y: panelY - 55)

        let closeBg = SKShapeNode(rectOf: CGSize(width: panelW - 40, height: 36), cornerRadius: 10)
        closeBg.fillColor = SKColor(white: 0.15, alpha: 0.8)
        closeBg.strokeColor = SKColor(white: 0.3, alpha: 0.3)
        closeBg.lineWidth = 1
        closeBg.name = "settingsOverlayBg"
        closeBtn.addChild(closeBg)

        let closeLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        closeLabel.text = "CLOSE"
        closeLabel.fontSize = 12
        closeLabel.fontColor = SKColor(white: 0.7, alpha: 0.9)
        closeLabel.verticalAlignmentMode = .center
        closeLabel.name = "settingsOverlayBg"
        closeBtn.addChild(closeLabel)
        overlay.addChild(closeBtn)

        overlay.alpha = 0
        addChild(overlay)
        overlay.run(.fadeIn(withDuration: 0.15))
    }

    private func confirmResetMissions() {
        guard let overlay = childNode(withName: "settingsOverlay") else { return }

        // Remove existing panel content and show confirmation
        overlay.children.filter { $0.name != "settingsOverlayBg" || $0 is SKShapeNode }.forEach {
            if $0.name != "settingsOverlayBg" { $0.removeFromParent() }
        }

        // Keep dim bg, re-add fresh
        let dimBg = SKShapeNode(rectOf: CGSize(width: size.width + 4, height: size.height + 4))
        dimBg.position = CGPoint(x: size.width / 2, y: size.height / 2)
        dimBg.fillColor = SKColor(white: 0, alpha: 0.6)
        dimBg.strokeColor = .clear
        dimBg.name = "settingsOverlayBg"

        // Clear overlay and rebuild
        overlay.removeAllChildren()
        overlay.addChild(dimBg)

        let panelW: CGFloat = size.width - 60
        let panelY = size.height / 2

        let panel = SKShapeNode(rectOf: CGSize(width: panelW, height: 160), cornerRadius: 16)
        panel.fillColor = SKColor(red: 0.08, green: 0.09, blue: 0.14, alpha: 0.98)
        panel.strokeColor = SKColor(red: 0.7, green: 0.2, blue: 0.2, alpha: 0.4)
        panel.lineWidth = 1
        panel.position = CGPoint(x: size.width / 2, y: panelY)
        panel.glowWidth = 3
        overlay.addChild(panel)

        let title = SKLabelNode(fontNamed: "Menlo-Bold")
        title.text = "RESET ALL PROGRESS?"
        title.fontSize = 14
        title.fontColor = SKColor(red: 1.0, green: 0.4, blue: 0.3, alpha: 1)
        title.position = CGPoint(x: size.width / 2, y: panelY + 40)
        overlay.addChild(title)

        let sub = SKLabelNode(fontNamed: "Menlo")
        sub.text = "This cannot be undone"
        sub.fontSize = 10
        sub.fontColor = SKColor(white: 0.5, alpha: 0.8)
        sub.position = CGPoint(x: size.width / 2, y: panelY + 15)
        overlay.addChild(sub)

        let btnW: CGFloat = (panelW - 60) / 2

        // Yes button
        let yesBtn = SKNode()
        yesBtn.name = "resetConfirmYes"
        yesBtn.position = CGPoint(x: size.width / 2 - btnW / 2 - 10, y: panelY - 30)

        let yesBg = SKShapeNode(rectOf: CGSize(width: btnW, height: 36), cornerRadius: 10)
        yesBg.fillColor = SKColor(red: 0.6, green: 0.1, blue: 0.1, alpha: 0.9)
        yesBg.strokeColor = SKColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 0.5)
        yesBg.lineWidth = 1
        yesBg.name = "resetConfirmYes"
        yesBtn.addChild(yesBg)

        let yesLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        yesLabel.text = "RESET"
        yesLabel.fontSize = 12
        yesLabel.fontColor = SKColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1)
        yesLabel.verticalAlignmentMode = .center
        yesLabel.name = "resetConfirmYes"
        yesBtn.addChild(yesLabel)
        overlay.addChild(yesBtn)

        // No button
        let noBtn = SKNode()
        noBtn.name = "resetConfirmNo"
        noBtn.position = CGPoint(x: size.width / 2 + btnW / 2 + 10, y: panelY - 30)

        let noBg = SKShapeNode(rectOf: CGSize(width: btnW, height: 36), cornerRadius: 10)
        noBg.fillColor = SKColor(white: 0.15, alpha: 0.8)
        noBg.strokeColor = SKColor(white: 0.3, alpha: 0.3)
        noBg.lineWidth = 1
        noBg.name = "resetConfirmNo"
        noBtn.addChild(noBg)

        let noLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        noLabel.text = "CANCEL"
        noLabel.fontSize = 12
        noLabel.fontColor = SKColor(white: 0.7, alpha: 0.9)
        noLabel.verticalAlignmentMode = .center
        noLabel.name = "resetConfirmNo"
        noBtn.addChild(noLabel)
        overlay.addChild(noBtn)
    }

    private func dismissSettingsOverlay() {
        guard let overlay = childNode(withName: "settingsOverlay") else { return }
        overlay.run(.sequence([.fadeOut(withDuration: 0.15), .removeFromParent()]))
    }
}
