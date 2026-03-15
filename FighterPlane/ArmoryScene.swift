import SpriteKit

class ArmoryScene: SKScene {

    // Layout constants computed from screen size
    private var safeTop: CGFloat = 59
    private var safeBottom: CGFloat = 34
    private var headerHeight: CGFloat = 78
    private var equippedSectionHeight: CGFloat = 110
    private var slotSize: CGFloat = 44

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

    // Nodes for refresh
    private var equippedSlotsNode: SKNode!
    private var currencyBar: SKNode!

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.10, green: 0.10, blue: 0.14, alpha: 1.0)
        safeTop = SafeArea.top
        safeBottom = SafeArea.bottom

        computeLayout()
        setupBackground()
        setupHeader()
        setupEquippedSection()
        setupScrollContent()
    }

    // MARK: - Layout

    private func computeLayout() {
        let w = size.width
        let totalSlotPadding: CGFloat = 16 + 5 * 8 + 16
        slotSize = min(52, floor((w - totalSlotPadding) / 6))
        equippedSectionHeight = slotSize + 52

        scrollAreaTop = size.height - safeTop - headerHeight - equippedSectionHeight
        scrollAreaBottom = safeBottom
    }

    // MARK: - Background

    private func setupBackground() {
        let glow = SKShapeNode(circleOfRadius: size.width * 0.6)
        glow.fillColor = SKColor(red: 0.08, green: 0.12, blue: 0.20, alpha: 0.25)
        glow.strokeColor = .clear
        glow.position = CGPoint(x: size.width / 2, y: size.height * 0.6)
        glow.zPosition = -5
        addChild(glow)
    }

    // MARK: - Header

    private func setupHeader() {
        let headerY = size.height - safeTop - 40

        // Top bar backing
        let topBar = SKShapeNode(rect: CGRect(x: 0, y: size.height - safeTop - headerHeight,
                                               width: size.width, height: safeTop + headerHeight))
        topBar.fillColor = SKColor(red: 0.07, green: 0.07, blue: 0.10, alpha: 0.95)
        topBar.strokeColor = .clear
        topBar.zPosition = 49
        addChild(topBar)

        // Divider
        let divider = SKShapeNode(rectOf: CGSize(width: size.width - 32, height: 1))
        divider.fillColor = SKColor(red: 0.3, green: 0.6, blue: 0.9, alpha: 0.25)
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
        title.text = "ARMORY"
        title.fontSize = 17
        title.fontColor = .white
        title.position = CGPoint(x: size.width / 2, y: headerY - 2)
        title.zPosition = 51
        addChild(title)

        // Shop button (right side of header)
        let shopNode = SKNode()
        shopNode.position = CGPoint(x: size.width - 44, y: headerY)
        shopNode.zPosition = 51
        shopNode.name = "shopButton"

        let shopBg = SKShapeNode(rectOf: CGSize(width: 68, height: 28), cornerRadius: 8)
        shopBg.fillColor = SKColor(red: 0.30, green: 0.15, blue: 0.45, alpha: 0.9)
        shopBg.strokeColor = SKColor(red: 0.6, green: 0.3, blue: 0.8, alpha: 0.5)
        shopBg.lineWidth = 1
        shopBg.name = "shopButton"
        shopNode.addChild(shopBg)

        let shopLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        shopLabel.text = "Shop >"
        shopLabel.fontSize = 12
        shopLabel.fontColor = SKColor(red: 0.8, green: 0.6, blue: 1, alpha: 1)
        shopLabel.verticalAlignmentMode = .center
        shopLabel.name = "shopButton"
        shopBg.addChild(shopLabel)
        addChild(shopNode)

        // Currency bar (below title, inside header)
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

    // MARK: - Equipped Section

    private func setupEquippedSection() {
        let sectionTop = size.height - safeTop - headerHeight

        let panelBg = SKShapeNode(rect: CGRect(x: 0, y: sectionTop - equippedSectionHeight,
                                                width: size.width, height: equippedSectionHeight))
        panelBg.fillColor = SKColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 0.9)
        panelBg.strokeColor = .clear
        panelBg.zPosition = 30
        addChild(panelBg)

        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.text = "EQUIPPED LOADOUT"
        label.fontSize = 10
        label.fontColor = SKColor(red: 0.3, green: 0.75, blue: 0.4, alpha: 0.7)
        label.position = CGPoint(x: size.width / 2, y: sectionTop - 18)
        label.zPosition = 31
        addChild(label)

        equippedSlotsNode = SKNode()
        equippedSlotsNode.zPosition = 31
        addChild(equippedSlotsNode)

        buildEquippedSlots(sectionTop: sectionTop)

        let bottomDiv = SKShapeNode(rectOf: CGSize(width: size.width - 24, height: 1))
        bottomDiv.fillColor = SKColor(red: 0.3, green: 0.65, blue: 0.4, alpha: 0.2)
        bottomDiv.strokeColor = .clear
        bottomDiv.position = CGPoint(x: size.width / 2, y: sectionTop - equippedSectionHeight)
        bottomDiv.zPosition = 31
        bottomDiv.glowWidth = 1
        addChild(bottomDiv)
    }

    private func buildEquippedSlots(sectionTop: CGFloat) {
        equippedSlotsNode.removeAllChildren()

        let data = PlayerData.shared
        let gap: CGFloat = 8
        let totalWidth = slotSize * 6 + gap * 5
        let startX = (size.width - totalWidth) / 2 + slotSize / 2
        let slotY = sectionTop - 24 - slotSize / 2 - 14

        for i in 0..<6 {
            let slot = SKNode()
            slot.position = CGPoint(x: startX + CGFloat(i) * (slotSize + gap), y: slotY)
            slot.name = "equipped_\(i)"

            let bg = SKShapeNode(rectOf: CGSize(width: slotSize, height: slotSize), cornerRadius: 8)
            bg.name = "equipped_\(i)"

            if let weaponId = data.loadout[i] {
                bg.fillColor = SKColor(red: 0.10, green: 0.25, blue: 0.12, alpha: 0.95)
                bg.strokeColor = SKColor(red: 0.25, green: 0.7, blue: 0.3, alpha: 0.6)
                bg.glowWidth = 1
                bg.lineWidth = 1.5
                slot.addChild(bg)

                let iconScale = slotSize / 100.0 * 0.85
                let icon = SKSpriteNode(texture: SpriteGenerator.weaponIcon(for: weaponId))
                icon.setScale(iconScale)
                icon.name = "equipped_\(i)"
                slot.addChild(icon)

                let numLabel = SKLabelNode(fontNamed: "Menlo-Bold")
                numLabel.text = "\(i + 1)"
                numLabel.fontSize = 7
                numLabel.fontColor = SKColor(white: 0.4, alpha: 0.5)
                numLabel.position = CGPoint(x: -slotSize / 2 + 8, y: slotSize / 2 - 11)
                numLabel.name = "equipped_\(i)"
                slot.addChild(numLabel)

                let removeBadge = SKShapeNode(circleOfRadius: 7)
                removeBadge.fillColor = SKColor(red: 0.7, green: 0.15, blue: 0.15, alpha: 0.9)
                removeBadge.strokeColor = .clear
                removeBadge.position = CGPoint(x: slotSize / 2 - 5, y: slotSize / 2 - 5)
                removeBadge.name = "equipped_\(i)"
                slot.addChild(removeBadge)

                let xLabel = SKLabelNode(fontNamed: "Menlo-Bold")
                xLabel.text = "-"
                xLabel.fontSize = 9
                xLabel.fontColor = .white
                xLabel.verticalAlignmentMode = .center
                xLabel.name = "equipped_\(i)"
                removeBadge.addChild(xLabel)

                if let weapon = WeaponCatalog.weapon(byId: weaponId) {
                    let nameLabel = SKLabelNode(fontNamed: "Menlo")
                    nameLabel.text = shortName(weapon.name)
                    nameLabel.fontSize = 7
                    nameLabel.fontColor = SKColor(white: 0.55, alpha: 0.7)
                    nameLabel.position = CGPoint(x: 0, y: -slotSize / 2 - 10)
                    nameLabel.name = "equipped_\(i)"
                    slot.addChild(nameLabel)
                }
            } else {
                bg.fillColor = SKColor(white: 0.08, alpha: 0.7)
                bg.strokeColor = SKColor(white: 0.20, alpha: 0.3)
                bg.lineWidth = 1
                slot.addChild(bg)

                let emptyLabel = SKLabelNode(fontNamed: "Menlo")
                emptyLabel.text = "\(i + 1)"
                emptyLabel.fontSize = 14
                emptyLabel.fontColor = SKColor(white: 0.18, alpha: 0.4)
                emptyLabel.verticalAlignmentMode = .center
                emptyLabel.name = "equipped_\(i)"
                slot.addChild(emptyLabel)
            }

            equippedSlotsNode.addChild(slot)
        }
    }

    // MARK: - Scroll Content (Inventory only)

    private func setupScrollContent() {
        if scrollNode != nil {
            scrollNode.removeFromParent()
        }

        scrollNode = SKNode()
        scrollNode.zPosition = 10
        addChild(scrollNode)

        let padding: CGFloat = 10
        let columns = columnsForWidth()
        let cardW = cardWidthForColumns(columns)
        let cardH = cardW * 0.85
        let totalCardWidth = cardW + padding
        let totalCardHeight = cardH + padding

        var currentY: CGFloat = 0

        let inventoryWeapons = buildInventoryList()

        // Inventory header
        currentY -= 28
        let invLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        invLabel.text = "INVENTORY"
        invLabel.fontSize = 10
        invLabel.fontColor = SKColor(red: 0.4, green: 0.65, blue: 0.9, alpha: 0.7)
        invLabel.position = CGPoint(x: size.width / 2, y: currentY)
        scrollNode.addChild(invLabel)

        let subLabel = SKLabelNode(fontNamed: "Menlo")
        subLabel.text = "Tap to equip to loadout"
        subLabel.fontSize = 8
        subLabel.fontColor = SKColor(white: 0.35, alpha: 0.5)
        subLabel.position = CGPoint(x: size.width / 2, y: currentY - 14)
        scrollNode.addChild(subLabel)

        if inventoryWeapons.isEmpty {
            currentY -= 50
            let emptyLabel = SKLabelNode(fontNamed: "Menlo")
            emptyLabel.text = "No unequipped weapons"
            emptyLabel.fontSize = 11
            emptyLabel.fontColor = SKColor(white: 0.3, alpha: 0.6)
            emptyLabel.position = CGPoint(x: size.width / 2, y: currentY)
            scrollNode.addChild(emptyLabel)

            currentY -= 20
            let hintLabel = SKLabelNode(fontNamed: "Menlo")
            hintLabel.text = "Visit the Shop to buy more"
            hintLabel.fontSize = 9
            hintLabel.fontColor = SKColor(red: 0.6, green: 0.4, blue: 0.8, alpha: 0.5)
            hintLabel.position = CGPoint(x: size.width / 2, y: currentY)
            scrollNode.addChild(hintLabel)
            currentY -= 20
        } else {
            currentY -= 28

            for (index, entry) in inventoryWeapons.enumerated() {
                let col = index % columns
                let row = index / columns

                let itemsOnRow = min(columns, inventoryWeapons.count - row * columns)
                let rowGridWidth = CGFloat(itemsOnRow) * totalCardWidth - (totalCardWidth - cardW)
                let rowStartX = (size.width - rowGridWidth) / 2 + cardW / 2

                let cardY = currentY - CGFloat(row) * totalCardHeight - cardH / 2
                let cardX = rowStartX + CGFloat(col) * totalCardWidth

                let card = createInventoryCard(weapon: entry.weapon, count: entry.count,
                                                cardSize: CGSize(width: cardW, height: cardH))
                card.position = CGPoint(x: cardX, y: cardY)
                card.name = "inv_\(entry.weapon.id)"
                scrollNode.addChild(card)
            }

            let invRows = ceil(Double(inventoryWeapons.count) / Double(columns))
            currentY -= CGFloat(invRows) * totalCardHeight + 8
        }

        currentY -= safeBottom + 20

        scrollContentHeight = abs(currentY)
        scrollOffset = 0
        scrollNode.position = CGPoint(x: 0, y: scrollAreaTop)

        setupScrollMask()
    }

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

    // MARK: - Responsive Grid

    private func columnsForWidth() -> Int {
        if size.width < 380 { return 3 }
        return 4
    }

    private func cardWidthForColumns(_ columns: Int) -> CGFloat {
        let padding: CGFloat = 10
        let sideMargin: CGFloat = 14
        let totalPadding = sideMargin * 2 + padding * CGFloat(columns - 1)
        return floor((size.width - totalPadding) / CGFloat(columns))
    }

    // MARK: - Data Helpers

    private struct InventoryEntry {
        let weapon: WeaponInfo
        let count: Int
    }

    private func buildInventoryList() -> [InventoryEntry] {
        let data = PlayerData.shared
        var entries: [InventoryEntry] = []
        var seen = Set<String>()

        for weaponId in data.ownedWeaponIds {
            guard !seen.contains(weaponId) else { continue }
            seen.insert(weaponId)
            let available = data.availableCount(of: weaponId)
            if available > 0, let weapon = WeaponCatalog.weapon(byId: weaponId) {
                entries.append(InventoryEntry(weapon: weapon, count: available))
            }
        }
        return entries
    }

    // MARK: - Card Builder

    private func createInventoryCard(weapon: WeaponInfo, count: Int, cardSize: CGSize) -> SKNode {
        let card = SKNode()

        let bg = SKShapeNode(rectOf: cardSize, cornerRadius: 8)
        bg.fillColor = SKColor(red: 0.14, green: 0.20, blue: 0.30, alpha: 0.9)
        bg.strokeColor = SKColor(red: 0.30, green: 0.50, blue: 0.70, alpha: 0.6)
        bg.lineWidth = 1.5
        bg.name = "card_bg"
        card.addChild(bg)

        let iconScale = cardSize.width / 180.0
        let icon = SKSpriteNode(texture: SpriteGenerator.weaponIcon(for: weapon.id))
        icon.setScale(iconScale)
        icon.position = CGPoint(x: 0, y: cardSize.height * 0.10)
        card.addChild(icon)

        let nameLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        nameLabel.text = shortName(weapon.name)
        nameLabel.fontSize = max(8, min(10, cardSize.width * 0.11))
        nameLabel.fontColor = .white
        nameLabel.position = CGPoint(x: 0, y: -cardSize.height * 0.25)
        card.addChild(nameLabel)

        if count > 1 {
            let badge = SKShapeNode(rectOf: CGSize(width: 22, height: 14), cornerRadius: 7)
            badge.fillColor = SKColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 0.9)
            badge.strokeColor = .clear
            badge.position = CGPoint(x: cardSize.width / 2 - 16, y: cardSize.height / 2 - 12)
            card.addChild(badge)

            let countLabel = SKLabelNode(fontNamed: "Menlo-Bold")
            countLabel.text = "x\(count)"
            countLabel.fontSize = 8
            countLabel.fontColor = .white
            countLabel.verticalAlignmentMode = .center
            badge.addChild(countLabel)
        }

        let hint = SKLabelNode(fontNamed: "Menlo")
        hint.text = "EQUIP"
        hint.fontSize = max(7, min(8, cardSize.width * 0.09))
        hint.fontColor = SKColor(red: 0.4, green: 0.7, blue: 1, alpha: 0.6)
        hint.position = CGPoint(x: 0, y: -cardSize.height * 0.38)
        card.addChild(hint)

        let addBadge = SKShapeNode(circleOfRadius: 7)
        addBadge.fillColor = SKColor(red: 0.15, green: 0.5, blue: 0.2, alpha: 0.9)
        addBadge.strokeColor = .clear
        addBadge.position = CGPoint(x: -cardSize.width / 2 + 12, y: cardSize.height / 2 - 12)
        card.addChild(addBadge)

        let plusLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        plusLabel.text = "+"
        plusLabel.fontSize = 10
        plusLabel.fontColor = .white
        plusLabel.verticalAlignmentMode = .center
        addBadge.addChild(plusLabel)

        return card
    }

    private func shortName(_ name: String) -> String {
        if name.count > 10 {
            let words = name.split(separator: " ")
            if words.count >= 2 {
                return String(words[0].prefix(4)) + ". " + words[1]
            }
        }
        return name
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

        if tappedNodes.contains(where: { $0.name == "shopButton" }) {
            openShop()
            return
        }

        // Equipped slot tap (unequip)
        for node in tappedNodes {
            let name = resolveNodeName(node, prefix: "equipped_")
            if let name = name, name.hasPrefix("equipped_") {
                let slotStr = String(name.dropFirst("equipped_".count))
                if let slotIndex = Int(slotStr) {
                    handleUnequipSlot(slotIndex)
                    return
                }
            }
        }

        // Inventory card tap (equip)
        for node in tappedNodes {
            let name = resolveNodeName(node, prefix: "inv_")
            if let name = name, name.hasPrefix("inv_") {
                let weaponId = String(name.dropFirst("inv_".count))
                handleEquipFromInventory(weaponId: weaponId)
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

    // MARK: - Actions

    private func handleUnequipSlot(_ slotIndex: Int) {
        let data = PlayerData.shared
        guard slotIndex >= 0, slotIndex < 6, data.loadout[slotIndex] != nil else { return }

        data.unequipSlot(slotIndex)
        refreshAll()
        showSlotFlash(slotIndex: slotIndex, color: SKColor(red: 1.0, green: 0.3, blue: 0.2, alpha: 0.3))
    }

    private func handleEquipFromInventory(weaponId: String) {
        let data = PlayerData.shared
        guard data.availableCount(of: weaponId) > 0 else { return }

        if let emptySlot = data.loadout.firstIndex(where: { $0 == nil }) {
            data.equipWeapon(weaponId, toSlot: emptySlot)
            refreshAll()
            showSlotFlash(slotIndex: emptySlot, color: SKColor(red: 0.2, green: 1.0, blue: 0.3, alpha: 0.3))
        } else {
            showMessage("All slots full!", color: SKColor(red: 1, green: 0.6, blue: 0.2, alpha: 1))
        }
    }

    // MARK: - Refresh

    private func refreshAll() {
        let sectionTop = size.height - safeTop - headerHeight
        buildEquippedSlots(sectionTop: sectionTop)
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

    private func showSlotFlash(slotIndex: Int, color: SKColor) {
        let gap: CGFloat = 8
        let totalWidth = slotSize * 6 + gap * 5
        let startX = (size.width - totalWidth) / 2 + slotSize / 2
        let sectionTop = size.height - safeTop - headerHeight
        let slotY = sectionTop - 24 - slotSize / 2 - 14
        let slotX = startX + CGFloat(slotIndex) * (slotSize + gap)

        let flash = SKShapeNode(rectOf: CGSize(width: slotSize + 4, height: slotSize + 4), cornerRadius: 10)
        flash.fillColor = color
        flash.strokeColor = .clear
        flash.glowWidth = 4
        flash.position = CGPoint(x: slotX, y: slotY)
        flash.zPosition = 60
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

    private func openShop() {
        let shop = ShopScene(size: size)
        shop.scaleMode = scaleMode
        view?.presentScene(shop, transition: .push(with: .left, duration: 0.3))
    }

    private func goBack() {
        let hangar = HangarScene(size: size)
        hangar.scaleMode = scaleMode
        view?.presentScene(hangar, transition: .push(with: .right, duration: 0.3))
    }
}
