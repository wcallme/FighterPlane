import SpriteKit
import SceneKit
import Metal

class HangarScene: SKScene {

    private var loadoutSlots: [SKNode] = []
    private var upgradeNodes: [String: SKNode] = [:]
    private var safeTop: CGFloat = 59
    private var safeBottom: CGFloat = 34

    // Layout zones (computed once in didMove)
    private var headerY: CGFloat = 0
    private var planeAreaCenterY: CGFloat = 0
    private var upgradeRowY: CGFloat = 0
    private var loadoutRowY: CGFloat = 0
    private var buttonRowY: CGFloat = 0

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.06, green: 0.07, blue: 0.11, alpha: 1.0)
        safeTop = SafeArea.top
        safeBottom = SafeArea.bottom

        computeLayout()
        setupAtmosphericBackground()
        setupHeader()
        setupPlaneDisplay()
        setupStatsBar()
        setupUpgradeRow()
        setupLoadoutBar()
        setupActionButtons()
    }

    // MARK: - Layout Computation

    private func computeLayout() {
        let usableTop = size.height - safeTop
        let usableBottom = safeBottom

        // Header: from top
        headerY = usableTop - 40

        // Bottom sections (build upward from bottom with room for section labels)
        buttonRowY = usableBottom + 50
        loadoutRowY = buttonRowY + 64
        upgradeRowY = loadoutRowY + 64

        // Plane area: centered between upgrade section top and header bottom
        let headerBottom = usableTop - 80
        let upgradeTop = upgradeRowY + 34
        planeAreaCenterY = upgradeTop + (headerBottom - upgradeTop) * 0.5
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

        // Subtle radial glow behind plane area
        let glow = SKShapeNode(circleOfRadius: size.width * 0.45)
        glow.fillColor = SKColor(red: 0.08, green: 0.18, blue: 0.12, alpha: 0.35)
        glow.strokeColor = .clear
        glow.position = CGPoint(x: size.width / 2, y: planeAreaCenterY)
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

        // Top bar backing
        let topBar = SKShapeNode(rect: CGRect(x: 0, y: size.height - safeTop - 78, width: size.width, height: safeTop + 78))
        topBar.fillColor = SKColor(red: 0.05, green: 0.06, blue: 0.09, alpha: 0.92)
        topBar.strokeColor = .clear
        topBar.zPosition = 9
        addChild(topBar)

        // Glowing divider line under header
        let divider = SKShapeNode(rectOf: CGSize(width: size.width - 40, height: 1))
        divider.fillColor = SKColor(red: 0.2, green: 0.8, blue: 0.4, alpha: 0.3)
        divider.strokeColor = .clear
        divider.position = CGPoint(x: size.width / 2, y: size.height - safeTop - 78)
        divider.zPosition = 10
        divider.glowWidth = 2
        addChild(divider)

        // Bottom panel backing
        let bottomPanel = SKShapeNode(rect: CGRect(x: 0, y: 0, width: size.width, height: upgradeRowY + 36))
        bottomPanel.fillColor = SKColor(red: 0.05, green: 0.06, blue: 0.09, alpha: 0.88)
        bottomPanel.strokeColor = .clear
        bottomPanel.zPosition = 0
        addChild(bottomPanel)

        // Glowing divider above bottom panel
        let bottomDivider = SKShapeNode(rectOf: CGSize(width: size.width - 40, height: 1))
        bottomDivider.fillColor = SKColor(red: 0.2, green: 0.8, blue: 0.4, alpha: 0.2)
        bottomDivider.strokeColor = .clear
        bottomDivider.position = CGPoint(x: size.width / 2, y: upgradeRowY + 36)
        bottomDivider.zPosition = 10
        bottomDivider.glowWidth = 1
        addChild(bottomDivider)
    }

    // MARK: - Header

    private func setupHeader() {
        let data = PlayerData.shared

        // Player level badge - left
        let levelBadge = SKNode()
        levelBadge.position = CGPoint(x: 52, y: headerY)
        levelBadge.zPosition = 11

        let levelBg = SKShapeNode(rectOf: CGSize(width: 64, height: 26), cornerRadius: 13)
        levelBg.fillColor = SKColor(red: 0.15, green: 0.25, blue: 0.45, alpha: 0.9)
        levelBg.strokeColor = SKColor(red: 0.3, green: 0.5, blue: 0.9, alpha: 0.5)
        levelBg.lineWidth = 1
        levelBg.glowWidth = 1
        levelBadge.addChild(levelBg)

        let levelLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        levelLabel.text = "LV \(data.playerLevel)"
        levelLabel.fontSize = 12
        levelLabel.fontColor = SKColor(red: 0.6, green: 0.8, blue: 1, alpha: 1)
        levelLabel.verticalAlignmentMode = .center
        levelBadge.addChild(levelLabel)

        addChild(levelBadge)

        // Title - center
        let title = SKLabelNode(fontNamed: "Menlo-Bold")
        title.text = "HANGAR"
        title.fontSize = 18
        title.fontColor = SKColor(white: 0.92, alpha: 1)
        title.position = CGPoint(x: size.width / 2, y: headerY - 2)
        title.zPosition = 11
        addChild(title)

        // Currency display - right
        let currencyY = headerY

        // Gems
        let gemIcon = SKSpriteNode(texture: SpriteGenerator.gemIcon())
        gemIcon.position = CGPoint(x: size.width - 150, y: currencyY)
        gemIcon.setScale(1.2)
        gemIcon.zPosition = 11
        addChild(gemIcon)

        let gemLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        gemLabel.text = "\(data.gems)"
        gemLabel.fontSize = 14
        gemLabel.fontColor = SKColor(red: 0.9, green: 0.3, blue: 0.8, alpha: 1)
        gemLabel.horizontalAlignmentMode = .left
        gemLabel.position = CGPoint(x: size.width - 136, y: currencyY - 5)
        gemLabel.zPosition = 11
        gemLabel.name = "gemCount"
        addChild(gemLabel)

        // Coins
        let coinIcon = SKSpriteNode(texture: SpriteGenerator.coinIcon())
        coinIcon.position = CGPoint(x: size.width - 72, y: currencyY)
        coinIcon.setScale(1.2)
        coinIcon.zPosition = 11
        addChild(coinIcon)

        let coinLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        coinLabel.text = "\(data.coins)"
        coinLabel.fontSize = 14
        coinLabel.fontColor = SKColor(red: 0.9, green: 0.8, blue: 0.2, alpha: 1)
        coinLabel.horizontalAlignmentMode = .left
        coinLabel.position = CGPoint(x: size.width - 58, y: currencyY - 5)
        coinLabel.zPosition = 11
        coinLabel.name = "coinCount"
        addChild(coinLabel)
    }

    // MARK: - Plane Display

    private func setupPlaneDisplay() {
        // Plane model label
        let modelLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        modelLabel.text = PlayerData.shared.selectedPlaneName
        modelLabel.fontSize = 14
        modelLabel.fontColor = SKColor(white: 0.75, alpha: 0.9)
        let nameLabelY = min(planeAreaCenterY + 85, headerY - 50)
        modelLabel.position = CGPoint(x: size.width / 2, y: nameLabelY)
        modelLabel.zPosition = 10
        modelLabel.name = "planeNameLabel"
        addChild(modelLabel)

        // Plane selection arrows with touch-friendly areas
        let leftArrow = createArrowButton(text: "\u{25C0}", name: "planeLeft")
        leftArrow.position = CGPoint(x: size.width / 2 - 110, y: nameLabelY - 3)
        addChild(leftArrow)

        let rightArrow = createArrowButton(text: "\u{25B6}", name: "planeRight")
        rightArrow.position = CGPoint(x: size.width / 2 + 110, y: nameLabelY - 3)
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
            .moveBy(x: 0, y: 7, duration: 1.6),
            .moveBy(x: 0, y: -7, duration: 1.6)
        ])
        planeSprite.run(.repeatForever(hover))

        // Under-plane glow disc
        let planeGlow = SKShapeNode(ellipseOf: CGSize(width: 100, height: 30))
        planeGlow.fillColor = SKColor(red: 0.15, green: 0.6, blue: 0.25, alpha: 0.15)
        planeGlow.strokeColor = .clear
        planeGlow.position = CGPoint(x: size.width / 2, y: planeAreaCenterY - 50)
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
            sprite.size = CGSize(width: 180, height: 138)
            return
        }

        // Fallback to USDZ snapshot for planes without menu images
        let renderSize = CGSize(width: 360, height: 276)
        guard let image = renderPlaneSnapshot(planeId: planeId, size: renderSize) else { return }

        let texture = SKTexture(image: image)
        sprite.texture = texture
        sprite.size = CGSize(width: 180, height: 138)
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
        let node = SKNode()
        node.name = name
        node.zPosition = 10

        let bg = SKShapeNode(circleOfRadius: 18)
        bg.fillColor = SKColor(white: 0.15, alpha: 0.6)
        bg.strokeColor = SKColor(white: 0.4, alpha: 0.3)
        bg.lineWidth = 1
        bg.name = name
        node.addChild(bg)

        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.text = text
        label.fontSize = 16
        label.fontColor = SKColor(white: 0.7, alpha: 0.9)
        label.verticalAlignmentMode = .center
        label.name = name
        node.addChild(label)

        return node
    }

    // MARK: - Stats Bar

    private func setupStatsBar() {
        let data = PlayerData.shared
        let statsY = planeAreaCenterY - 85

        let statsText = "HP \(data.maxHealth)  \u{2022}  SPD \(String(format: "%.0f", data.speedMultiplier * 100))%  \u{2022}  ENG \(String(format: "%.0f", data.engineMultiplier * 100))%"
        let stats = SKLabelNode(fontNamed: "Menlo")
        stats.text = statsText
        stats.fontSize = 10
        stats.fontColor = SKColor(red: 0.4, green: 0.7, blue: 0.5, alpha: 0.9)
        stats.position = CGPoint(x: size.width / 2, y: statsY)
        stats.zPosition = 11

        // Dark backing to prevent background bleed-through
        let statsBg = SKShapeNode(rectOf: CGSize(width: stats.frame.width + 20, height: 18), cornerRadius: 6)
        statsBg.fillColor = SKColor(red: 0.05, green: 0.06, blue: 0.09, alpha: 0.85)
        statsBg.strokeColor = .clear
        statsBg.position = CGPoint(x: size.width / 2, y: statsY + 3)
        statsBg.zPosition = 10
        addChild(statsBg)

        addChild(stats)
    }

    // MARK: - Upgrade Row

    private func setupUpgradeRow() {
        let upgrades = UpgradeCatalog.all
        let spacing: CGFloat = 120
        let totalWidth = CGFloat(upgrades.count - 1) * spacing
        let startX = size.width / 2 - totalWidth / 2

        // Section label
        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.text = "UPGRADES"
        label.fontSize = 9
        label.fontColor = SKColor(white: 0.35, alpha: 0.6)
        label.position = CGPoint(x: size.width / 2, y: upgradeRowY + 22)
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

    private func createUpgradeChip(upgrade: UpgradeInfo) -> SKNode {
        let node = SKNode()
        let data = PlayerData.shared
        let level = data.upgradeLevel(for: upgrade.id)

        let bg = SKShapeNode(rectOf: CGSize(width: 110, height: 30), cornerRadius: 8)
        bg.fillColor = SKColor(red: 0.10, green: 0.12, blue: 0.18, alpha: 0.95)
        bg.strokeColor = SKColor(red: 0.25, green: 0.5, blue: 0.35, alpha: 0.3)
        bg.lineWidth = 1
        bg.name = "upgrade_\(upgrade.id)"
        node.addChild(bg)

        let nameLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        nameLabel.text = upgrade.name.uppercased()
        nameLabel.fontSize = 9
        nameLabel.fontColor = SKColor(white: 0.75, alpha: 1)
        nameLabel.horizontalAlignmentMode = .left
        nameLabel.position = CGPoint(x: -48, y: 3)
        node.addChild(nameLabel)

        // Upgrade pips
        for i in 0..<upgrade.maxLevel {
            let pip = SKShapeNode(rectOf: CGSize(width: 5, height: 4), cornerRadius: 1)
            pip.fillColor = i < level
                ? SKColor(red: 0.25, green: 0.85, blue: 0.35, alpha: 1)
                : SKColor(white: 0.2, alpha: 0.4)
            pip.strokeColor = .clear
            pip.position = CGPoint(x: -48 + CGFloat(i) * 7, y: -6)
            if i < level {
                pip.glowWidth = 1
            }
            node.addChild(pip)
        }

        // Cost or MAX (right-aligned to chip edge)
        if level < upgrade.maxLevel {
            let cost = upgrade.cost(forLevel: level)
            let costLabel = SKLabelNode(fontNamed: "Menlo-Bold")
            costLabel.text = "\(cost)"
            costLabel.fontSize = 9
            costLabel.fontColor = SKColor(red: 0.9, green: 0.8, blue: 0.2, alpha: 1)
            costLabel.horizontalAlignmentMode = .right
            costLabel.position = CGPoint(x: 50, y: -4)
            node.addChild(costLabel)

            let coinIcon = SKSpriteNode(texture: SpriteGenerator.coinIcon())
            coinIcon.position = CGPoint(x: 50 - costLabel.frame.width - 6, y: 0)
            coinIcon.setScale(0.55)
            node.addChild(coinIcon)
        } else {
            let maxLabel = SKLabelNode(fontNamed: "Menlo-Bold")
            maxLabel.text = "MAX"
            maxLabel.fontSize = 9
            maxLabel.fontColor = SKColor(red: 0.25, green: 0.85, blue: 0.35, alpha: 1)
            maxLabel.horizontalAlignmentMode = .right
            maxLabel.position = CGPoint(x: 50, y: -4)
            node.addChild(maxLabel)
        }

        return node
    }

    // MARK: - Loadout Bar

    private func setupLoadoutBar() {
        let slotSize: CGFloat = 40
        let spacing: CGFloat = 50
        let totalWidth = spacing * 5
        let startX = (size.width - totalWidth) / 2

        let data = PlayerData.shared

        // Section label
        let loadoutLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        loadoutLabel.text = "LOADOUT"
        loadoutLabel.fontSize = 9
        loadoutLabel.fontColor = SKColor(white: 0.35, alpha: 0.6)
        loadoutLabel.position = CGPoint(x: size.width / 2, y: loadoutRowY + 28)
        loadoutLabel.zPosition = 10
        addChild(loadoutLabel)

        for i in 0..<6 {
            let slot = SKNode()
            slot.position = CGPoint(x: startX + CGFloat(i) * spacing, y: loadoutRowY)
            slot.name = "slot_\(i)"
            slot.zPosition = 10

            let bg = SKShapeNode(rectOf: CGSize(width: slotSize, height: slotSize), cornerRadius: 8)
            if data.loadout[i] != nil {
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

            if let weaponId = data.loadout[i] {
                let icon = SKSpriteNode(texture: SpriteGenerator.weaponIcon(for: weaponId))
                icon.setScale(0.40)
                icon.position = .zero
                slot.addChild(icon)

                let numLabel = SKLabelNode(fontNamed: "Menlo-Bold")
                numLabel.text = "\(i + 1)"
                numLabel.fontSize = 7
                numLabel.fontColor = SKColor(white: 0.45, alpha: 0.5)
                numLabel.position = CGPoint(x: -14, y: 12)
                slot.addChild(numLabel)
            } else {
                let emptyLabel = SKLabelNode(fontNamed: "Menlo")
                emptyLabel.text = "\(i + 1)"
                emptyLabel.fontSize = 13
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
        let btnSpacing: CGFloat = 8
        let sideWidth: CGFloat = (size.width - btnSpacing * 4) * 0.28
        let centerWidth: CGFloat = (size.width - btnSpacing * 4) * 0.44

        let leftX = btnSpacing * 1.5 + sideWidth / 2
        let centerX = size.width / 2
        let rightX = size.width - btnSpacing * 1.5 - sideWidth / 2

        // ARMORY button - left (purple theme)
        let armoryBtn = createPremiumButton(
            text: "ARMORY",
            icon: "\u{2694}",
            width: sideWidth,
            height: 52,
            primaryColor: SKColor(red: 0.35, green: 0.15, blue: 0.55, alpha: 1),
            accentColor: SKColor(red: 0.6, green: 0.3, blue: 0.9, alpha: 1),
            glowColor: SKColor(red: 0.5, green: 0.2, blue: 0.8, alpha: 0.3),
            fontSize: 12
        )
        armoryBtn.position = CGPoint(x: leftX, y: buttonRowY)
        armoryBtn.name = "armoryButton"
        armoryBtn.zPosition = 20
        addChild(armoryBtn)

        // DEPLOY button - center (green theme, hero button)
        let goBtn = createPremiumButton(
            text: "DEPLOY",
            icon: "\u{1F680}",
            width: centerWidth,
            height: 58,
            primaryColor: SKColor(red: 0.10, green: 0.45, blue: 0.12, alpha: 1),
            accentColor: SKColor(red: 0.2, green: 0.9, blue: 0.3, alpha: 1),
            glowColor: SKColor(red: 0.15, green: 0.8, blue: 0.25, alpha: 0.4),
            fontSize: 18
        )
        goBtn.position = CGPoint(x: centerX, y: buttonRowY)
        goBtn.name = "goButton"
        goBtn.zPosition = 20
        addChild(goBtn)

        // Hero button pulse animation
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
        let glowRing = SKShapeNode(rectOf: CGSize(width: centerWidth + 6, height: 64), cornerRadius: 16)
        glowRing.fillColor = .clear
        glowRing.strokeColor = SKColor(red: 0.2, green: 0.9, blue: 0.3, alpha: 0.2)
        glowRing.lineWidth = 2
        glowRing.glowWidth = 6
        glowRing.position = CGPoint(x: centerX, y: buttonRowY)
        glowRing.zPosition = 19
        addChild(glowRing)

        let ringPulse = SKAction.sequence([
            .fadeAlpha(to: 0.08, duration: 1.0),
            .fadeAlpha(to: 0.35, duration: 1.0)
        ])
        glowRing.run(.repeatForever(ringPulse))

        // MISSIONS button - right (gold theme)
        let missionsBtn = createPremiumButton(
            text: "MISSIONS",
            icon: "\u{1F3AF}",
            width: sideWidth,
            height: 52,
            primaryColor: SKColor(red: 0.50, green: 0.35, blue: 0.08, alpha: 1),
            accentColor: SKColor(red: 0.95, green: 0.75, blue: 0.15, alpha: 1),
            glowColor: SKColor(red: 0.8, green: 0.6, blue: 0.1, alpha: 0.3),
            fontSize: 12
        )
        missionsBtn.position = CGPoint(x: rightX, y: buttonRowY)
        missionsBtn.name = "missionsButton"
        missionsBtn.zPosition = 20
        addChild(missionsBtn)
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
            if name == "planeLeft" {
                cyclePlane(direction: -1)
                return
            }
            if name == "planeRight" {
                cyclePlane(direction: 1)
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
        NavigationManager.shared.isInGame = true
    }

    private func openArmory() {
        let armory = ArmoryScene(size: size)
        armory.scaleMode = scaleMode
        view?.presentScene(armory, transition: .push(with: .left, duration: 0.3))
    }

    private func handleSlotTap(_ slotIndex: Int) {
        let data = PlayerData.shared
        guard slotIndex >= 0, slotIndex < 6, data.loadout[slotIndex] != nil else { return }

        data.unequipSlot(slotIndex)
        refreshLoadout()

        // Red flash on the slot
        let slotSpacing: CGFloat = 50
        let totalWidth = slotSpacing * 5
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
            let flash = SKShapeNode(rectOf: CGSize(width: 110, height: 30), cornerRadius: 8)
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
