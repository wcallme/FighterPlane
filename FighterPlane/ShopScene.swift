import SpriteKit

class ShopScene: SKScene {

    private var safeTop: CGFloat = 59
    private var safeBottom: CGFloat = 34
    private let headerHeight: CGFloat = 78

    // Scroll state
    private var scrollNode: SKNode!
    private var scrollContentHeight: CGFloat = 0
    private var scrollOffset: CGFloat = 0
    private var scrollAreaTop: CGFloat = 0
    private var scrollAreaBottom: CGFloat = 0
    private var lastTouchY: CGFloat = 0
    private var isDragging = false
    private var velocity: CGFloat = 0
    private var lastTouchTime: TimeInterval = 0
    private var touchStartY: CGFloat = 0
    private var touchMoved = false

    private var currencyBar: SKNode!

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.09, green: 0.07, blue: 0.14, alpha: 1.0)
        safeTop = SafeArea.top
        safeBottom = SafeArea.bottom

        scrollAreaTop = size.height - safeTop - headerHeight
        scrollAreaBottom = max(safeBottom, 21)

        setupBackground()
        setupHeader()
        setupScrollContent()
    }

    // MARK: - Background

    private func setupBackground() {
        let glow = SKShapeNode(circleOfRadius: size.width * 0.5)
        glow.fillColor = SKColor(red: 0.12, green: 0.06, blue: 0.18, alpha: 0.3)
        glow.strokeColor = .clear
        glow.position = CGPoint(x: size.width / 2, y: size.height * 0.5)
        glow.zPosition = -5
        addChild(glow)
    }

    // MARK: - Header

    private func setupHeader() {
        let headerY = size.height - safeTop - 40

        let topBar = SKShapeNode(rect: CGRect(x: 0, y: size.height - safeTop - headerHeight,
                                               width: size.width, height: safeTop + headerHeight))
        topBar.fillColor = SKColor(red: 0.06, green: 0.05, blue: 0.10, alpha: 0.95)
        topBar.strokeColor = .clear
        topBar.zPosition = 49
        addChild(topBar)

        let divider = SKShapeNode(rectOf: CGSize(width: size.width - 32, height: 1))
        divider.fillColor = SKColor(red: 0.6, green: 0.3, blue: 0.8, alpha: 0.25)
        divider.strokeColor = .clear
        divider.position = CGPoint(x: size.width / 2, y: size.height - safeTop - headerHeight)
        divider.zPosition = 50
        divider.glowWidth = 1
        addChild(divider)

        // Back button
        let backNode = SKNode()
        backNode.position = CGPoint(x: 44, y: headerY)
        backNode.zPosition = 51
        backNode.name = "backButton"

        let backBg = SKShapeNode(rectOf: CGSize(width: 68, height: 28), cornerRadius: 8)
        backBg.fillColor = SKColor(red: 0.20, green: 0.20, blue: 0.26, alpha: 0.9)
        backBg.strokeColor = SKColor(white: 0.35, alpha: 0.4)
        backBg.lineWidth = 1
        backBg.name = "backButton"
        backNode.addChild(backBg)

        let backLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        backLabel.text = "< Back"
        backLabel.fontSize = 12
        backLabel.fontColor = SKColor(white: 0.8, alpha: 1)
        backLabel.verticalAlignmentMode = .center
        backLabel.name = "backButton"
        backBg.addChild(backLabel)
        addChild(backNode)

        // Title
        let title = SKLabelNode(fontNamed: "Menlo-Bold")
        title.text = "SHOP"
        title.fontSize = 17
        title.fontColor = SKColor(red: 0.9, green: 0.7, blue: 1, alpha: 1)
        title.position = CGPoint(x: size.width / 2, y: headerY - 2)
        title.zPosition = 51
        addChild(title)

        // Currency
        currencyBar = SKNode()
        currencyBar.zPosition = 51

        let currencyY = headerY - 28

        let gemIcon = SKSpriteNode(texture: SpriteGenerator.gemIcon())
        gemIcon.position = CGPoint(x: size.width / 2 - 60, y: currencyY)
        gemIcon.setScale(1.0)
        currencyBar.addChild(gemIcon)

        let gemLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        gemLabel.text = "\(PlayerData.shared.gems)"
        gemLabel.fontSize = 12
        gemLabel.fontColor = SKColor(red: 0.9, green: 0.3, blue: 0.8, alpha: 1)
        gemLabel.horizontalAlignmentMode = .left
        gemLabel.position = CGPoint(x: size.width / 2 - 48, y: currencyY - 5)
        gemLabel.name = "gemCount"
        currencyBar.addChild(gemLabel)

        let coinIcon = SKSpriteNode(texture: SpriteGenerator.coinIcon())
        coinIcon.position = CGPoint(x: size.width / 2 + 24, y: currencyY)
        coinIcon.setScale(1.0)
        currencyBar.addChild(coinIcon)

        let coinLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        coinLabel.text = "\(PlayerData.shared.coins)"
        coinLabel.fontSize = 12
        coinLabel.fontColor = SKColor(red: 0.9, green: 0.8, blue: 0.2, alpha: 1)
        coinLabel.horizontalAlignmentMode = .left
        coinLabel.position = CGPoint(x: size.width / 2 + 36, y: currencyY - 5)
        coinLabel.name = "coinCount"
        currencyBar.addChild(coinLabel)

        addChild(currencyBar)
    }

    // MARK: - Scroll Content

    private func setupScrollContent() {
        if scrollNode != nil {
            scrollNode.removeFromParent()
        }

        scrollNode = SKNode()
        scrollNode.zPosition = 10
        addChild(scrollNode)

        let padding: CGFloat = 6
        let columns = shopColumnsForWidth()
        let cardW = shopCardWidth(columns: columns)
        let cardH: CGFloat = cardW + 28 // icon + name + buy row
        let totalCardWidth = cardW + padding
        let totalCardHeight = cardH + padding
        let gridWidth = CGFloat(columns) * totalCardWidth - padding
        let gridStartX = (size.width - gridWidth) / 2 + cardW / 2

        var currentY: CGFloat = 0

        // Category: Guns
        currentY = layoutCategory(
            title: "GUNS",
            titleColor: SKColor(red: 0.4, green: 0.8, blue: 0.5, alpha: 0.7),
            weapons: WeaponCatalog.guns,
            startY: currentY,
            columns: columns,
            cardW: cardW, cardH: cardH,
            totalCardWidth: totalCardWidth, totalCardHeight: totalCardHeight,
            gridStartX: gridStartX
        )

        // Category: Bombs
        currentY = layoutCategory(
            title: "BOMBS",
            titleColor: SKColor(red: 0.9, green: 0.5, blue: 0.3, alpha: 0.7),
            weapons: WeaponCatalog.bombs,
            startY: currentY,
            columns: columns,
            cardW: cardW, cardH: cardH,
            totalCardWidth: totalCardWidth, totalCardHeight: totalCardHeight,
            gridStartX: gridStartX
        )

        // Category: Specials
        currentY = layoutCategory(
            title: "SPECIALS",
            titleColor: SKColor(red: 0.5, green: 0.6, blue: 1.0, alpha: 0.7),
            weapons: WeaponCatalog.specials,
            startY: currentY,
            columns: columns,
            cardW: cardW, cardH: cardH,
            totalCardWidth: totalCardWidth, totalCardHeight: totalCardHeight,
            gridStartX: gridStartX
        )

        currentY -= safeBottom + 30

        scrollContentHeight = abs(currentY)
        // Preserve scroll position on refresh, clamp to new content bounds
        let visibleHeight = scrollAreaTop - scrollAreaBottom
        let maxScroll = max(0, scrollContentHeight - visibleHeight)
        scrollOffset = max(0, min(scrollOffset, maxScroll))
        scrollNode.position = CGPoint(x: 0, y: scrollAreaTop + scrollOffset)

        setupScrollMask()
    }

    private func layoutCategory(
        title: String,
        titleColor: SKColor,
        weapons: [WeaponInfo],
        startY: CGFloat,
        columns: Int,
        cardW: CGFloat, cardH: CGFloat,
        totalCardWidth: CGFloat, totalCardHeight: CGFloat,
        gridStartX: CGFloat
    ) -> CGFloat {
        var currentY = startY

        // Section divider (skip for first section)
        if currentY < -10 {
            currentY -= 8
            let div = SKShapeNode(rectOf: CGSize(width: size.width - 48, height: 1))
            div.fillColor = SKColor(white: 0.25, alpha: 0.2)
            div.strokeColor = .clear
            div.position = CGPoint(x: size.width / 2, y: currentY)
            scrollNode.addChild(div)
        }

        currentY -= 24
        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.text = title
        label.fontSize = 10
        label.fontColor = titleColor
        label.position = CGPoint(x: size.width / 2, y: currentY)
        scrollNode.addChild(label)

        currentY -= 16

        for (index, weapon) in weapons.enumerated() {
            let col = index % columns
            let row = index / columns

            let itemsOnRow = min(columns, weapons.count - row * columns)
            let rowGridWidth = CGFloat(itemsOnRow) * totalCardWidth - (totalCardWidth - cardW)
            let rowStartX = (size.width - rowGridWidth) / 2 + cardW / 2

            let cardY = currentY - CGFloat(row) * totalCardHeight - cardH / 2
            let cardX = rowStartX + CGFloat(col) * totalCardWidth

            let card = createShopCard(weapon: weapon, cardSize: CGSize(width: cardW, height: cardH))
            card.position = CGPoint(x: cardX, y: cardY)
            card.name = "shop_\(weapon.id)"
            scrollNode.addChild(card)
        }

        let rows = ceil(Double(weapons.count) / Double(columns))
        currentY -= CGFloat(rows) * totalCardHeight + 4

        return currentY
    }

    // MARK: - Responsive Grid

    private func shopColumnsForWidth() -> Int {
        if size.width < 380 { return 4 }
        return 5
    }

    private func shopCardWidth(columns: Int) -> CGFloat {
        let padding: CGFloat = 6
        let sideMargin: CGFloat = 10
        let totalPadding = sideMargin * 2 + padding * CGFloat(columns - 1)
        return floor((size.width - totalPadding) / CGFloat(columns))
    }

    // MARK: - Card Builder

    private func createShopCard(weapon: WeaponInfo, cardSize: CGSize) -> SKNode {
        let card = SKNode()
        let data = PlayerData.shared
        let totalOwned = data.ownedCount(of: weapon.id)

        let bg = SKShapeNode(rectOf: cardSize, cornerRadius: 6)
        bg.fillColor = totalOwned > 0
            ? SKColor(red: 0.14, green: 0.10, blue: 0.22, alpha: 0.9)
            : SKColor(red: 0.12, green: 0.10, blue: 0.18, alpha: 0.9)
        bg.strokeColor = SKColor(red: 0.45, green: 0.25, blue: 0.65, alpha: totalOwned > 0 ? 0.4 : 0.5)
        bg.lineWidth = 1
        bg.name = "card_bg"
        card.addChild(bg)

        // Weapon icon (small)
        let iconScale = cardSize.width / 220.0
        let icon = SKSpriteNode(texture: SpriteGenerator.weaponIcon(for: weapon.id))
        icon.setScale(iconScale)
        icon.position = CGPoint(x: 0, y: cardSize.height * 0.18)
        card.addChild(icon)

        // Weapon name
        let nameLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        nameLabel.text = compactName(weapon.name)
        nameLabel.fontSize = max(7, min(9, cardSize.width * 0.12))
        nameLabel.fontColor = .white
        nameLabel.position = CGPoint(x: 0, y: -cardSize.height * 0.12)
        card.addChild(nameLabel)

        // Owned badge (top-right)
        if totalOwned > 0 {
            let badge = SKShapeNode(rectOf: CGSize(width: 18, height: 12), cornerRadius: 6)
            badge.fillColor = SKColor(red: 0.2, green: 0.5, blue: 0.3, alpha: 0.9)
            badge.strokeColor = .clear
            badge.position = CGPoint(x: cardSize.width / 2 - 12, y: cardSize.height / 2 - 10)
            card.addChild(badge)

            let countLabel = SKLabelNode(fontNamed: "Menlo-Bold")
            countLabel.text = "x\(totalOwned)"
            countLabel.fontSize = 7
            countLabel.fontColor = .white
            countLabel.verticalAlignmentMode = .center
            badge.addChild(countLabel)
        }

        // Buy row
        if weapon.gemCost > 0 {
            let buyH: CGFloat = min(16, cardSize.height * 0.18)
            let buyW: CGFloat = cardSize.width - 8
            let buyBg = SKShapeNode(rectOf: CGSize(width: buyW, height: buyH), cornerRadius: 4)
            buyBg.fillColor = SKColor(red: 0.35, green: 0.15, blue: 0.50, alpha: 0.9)
            buyBg.strokeColor = SKColor(red: 0.55, green: 0.30, blue: 0.75, alpha: 0.4)
            buyBg.lineWidth = 1
            buyBg.position = CGPoint(x: 0, y: -cardSize.height * 0.33)
            buyBg.name = "buyBtn_\(weapon.id)"
            card.addChild(buyBg)

            let gemIc = SKSpriteNode(texture: SpriteGenerator.gemIcon())
            gemIc.position = CGPoint(x: -buyW * 0.25, y: 0)
            gemIc.setScale(0.45)
            buyBg.addChild(gemIc)

            let costLabel = SKLabelNode(fontNamed: "Menlo-Bold")
            costLabel.text = "\(weapon.gemCost)"
            costLabel.fontSize = max(7, min(8, cardSize.width * 0.11))
            costLabel.fontColor = SKColor(red: 0.9, green: 0.3, blue: 0.8, alpha: 1)
            costLabel.horizontalAlignmentMode = .center
            costLabel.verticalAlignmentMode = .center
            costLabel.position = CGPoint(x: buyW * 0.10, y: 0)
            buyBg.addChild(costLabel)
        } else {
            let freeLabel = SKLabelNode(fontNamed: "Menlo-Bold")
            freeLabel.text = totalOwned > 0 ? "OWNED" : "FREE"
            freeLabel.fontSize = max(7, min(8, cardSize.width * 0.11))
            freeLabel.fontColor = SKColor(white: 0.4, alpha: 0.6)
            freeLabel.position = CGPoint(x: 0, y: -cardSize.height * 0.33)
            card.addChild(freeLabel)
        }

        return card
    }

    private func compactName(_ name: String) -> String {
        if name.count > 8 {
            let words = name.split(separator: " ")
            if words.count >= 2 {
                return String(words.last!)
            }
            return String(name.prefix(8))
        }
        return name
    }

    // MARK: - Scroll Mask

    private var cropNode: SKCropNode?

    private func setupScrollMask() {
        // Remove old crop node to prevent leak (#7)
        cropNode?.removeFromParent()

        let maskHeight = scrollAreaTop - scrollAreaBottom
        let newCrop = SKCropNode()
        newCrop.zPosition = 10

        let maskShape = SKSpriteNode(color: .white,
                                      size: CGSize(width: size.width, height: maskHeight))
        maskShape.position = CGPoint(x: size.width / 2,
                                      y: scrollAreaBottom + maskHeight / 2)
        newCrop.maskNode = maskShape

        scrollNode.removeFromParent()
        newCrop.addChild(scrollNode)
        addChild(newCrop)
        cropNode = newCrop
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        lastTouchY = touch.location(in: self).y
        touchStartY = lastTouchY
        touchMoved = false
        isDragging = true
        velocity = 0
        lastTouchTime = touch.timestamp
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, isDragging else { return }
        let currentY = touch.location(in: self).y
        let delta = currentY - lastTouchY

        if abs(currentY - touchStartY) > 8 {
            touchMoved = true
        }

        scrollOffset += delta
        clampScroll()

        let dt = touch.timestamp - lastTouchTime
        if dt > 0 {
            velocity = delta / CGFloat(dt)
        }

        lastTouchY = currentY
        lastTouchTime = touch.timestamp

        updateScrollPosition()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        isDragging = false

        if !touchMoved {
            guard let touch = touches.first else { return }
            handleTap(at: touch.location(in: self))
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        isDragging = false
    }

    override func update(_ currentTime: TimeInterval) {
        if !isDragging && abs(velocity) > 1 {
            let dt = 1.0 / CGFloat(view?.preferredFramesPerSecond ?? 60)
            scrollOffset += velocity * dt
            velocity *= 0.92
            clampScroll()
            updateScrollPosition()
        }
    }

    private func clampScroll() {
        let visibleHeight = scrollAreaTop - scrollAreaBottom
        let maxScroll = max(0, scrollContentHeight - visibleHeight)
        scrollOffset = max(0, min(scrollOffset, maxScroll))
    }

    private func updateScrollPosition() {
        scrollNode.position = CGPoint(x: 0, y: scrollAreaTop + scrollOffset)
    }

    // MARK: - Tap Handling

    private func handleTap(at location: CGPoint) {
        let tappedNodes = nodes(at: location)

        if tappedNodes.contains(where: { $0.name == "backButton" }) {
            goBack()
            return
        }

        // Buy button
        for node in tappedNodes {
            let name = resolveBuyName(node)
            if let name = name, name.hasPrefix("buyBtn_") {
                let weaponId = String(name.dropFirst("buyBtn_".count))
                handleBuyTap(weaponId: weaponId)
                return
            }
        }

        // Tap anywhere on a shop card also buys
        for node in tappedNodes {
            let name = resolveNodeName(node, prefix: "shop_")
            if let name = name, name.hasPrefix("shop_") {
                let weaponId = String(name.dropFirst("shop_".count))
                handleBuyTap(weaponId: weaponId)
                return
            }
        }
    }

    private func resolveNodeName(_ node: SKNode, prefix: String) -> String? {
        if let n = node.name, n.hasPrefix(prefix) { return n }
        if let n = node.parent?.name, n.hasPrefix(prefix) { return n }
        if let n = node.parent?.parent?.name, n.hasPrefix(prefix) { return n }
        if let n = node.parent?.parent?.parent?.name, n.hasPrefix(prefix) { return n }
        return nil
    }

    private func resolveBuyName(_ node: SKNode) -> String? {
        if let n = node.name, n.hasPrefix("buyBtn_") { return n }
        if let n = node.parent?.name, n.hasPrefix("buyBtn_") { return n }
        if let n = node.parent?.parent?.name, n.hasPrefix("buyBtn_") { return n }
        return nil
    }

    // MARK: - Actions

    private func handleBuyTap(weaponId: String) {
        guard let weapon = WeaponCatalog.weapon(byId: weaponId) else { return }
        let data = PlayerData.shared

        // Free weapons: just grant if not owned
        if weapon.gemCost == 0 {
            if !data.ownsWeapon(weaponId) {
                var owned = data.ownedWeaponIds
                owned.append(weaponId)
                data.ownedWeaponIds = owned
                if let emptySlot = data.loadout.firstIndex(where: { $0 == nil }) {
                    data.equipWeapon(weaponId, toSlot: emptySlot)
                }
                refreshGrid()
                showPurchaseEffect()
            }
            return
        }

        if data.buyWeapon(weapon) {
            if let emptySlot = data.loadout.firstIndex(where: { $0 == nil }) {
                data.equipWeapon(weaponId, toSlot: emptySlot)
            }
            refreshGrid()
            refreshCurrency()
            showPurchaseEffect()
        } else {
            showMessage("Not enough gems!", color: SKColor(red: 1, green: 0.3, blue: 0.3, alpha: 1))
        }
    }

    // MARK: - Refresh

    private func refreshGrid() {
        setupScrollContent()
    }

    private func refreshCurrency() {
        if let gem = currencyBar.childNode(withName: "gemCount") as? SKLabelNode {
            gem.text = "\(PlayerData.shared.gems)"
        }
        if let coin = currencyBar.childNode(withName: "coinCount") as? SKLabelNode {
            coin.text = "\(PlayerData.shared.coins)"
        }
    }

    // MARK: - Effects

    private func showPurchaseEffect() {
        let flash = SKShapeNode(rectOf: size)
        flash.fillColor = SKColor(red: 0.5, green: 0.2, blue: 0.8, alpha: 0.12)
        flash.strokeColor = .clear
        flash.position = CGPoint(x: size.width / 2, y: size.height / 2)
        flash.zPosition = 100
        addChild(flash)
        flash.run(.sequence([.fadeOut(withDuration: 0.3), .removeFromParent()]))
    }

    private func showMessage(_ text: String, color: SKColor) {
        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.text = text
        label.fontSize = 14
        label.fontColor = color
        label.position = CGPoint(x: size.width / 2, y: scrollAreaBottom + 30)
        label.zPosition = 100
        addChild(label)
        label.run(.sequence([
            .wait(forDuration: 1.2),
            .fadeOut(withDuration: 0.3),
            .removeFromParent()
        ]))
    }

    // MARK: - Navigation

    private func goBack() {
        let armory = ArmoryScene(size: size)
        armory.scaleMode = scaleMode
        view?.presentScene(armory, transition: .push(with: .right, duration: 0.3))
    }
}
