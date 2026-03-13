import SpriteKit

class ArmoryScene: SKScene {

    private var weaponCards: [SKNode] = []
    private let cardSize = CGSize(width: 140, height: 120)
    private let columns = 3
    private var selectedWeapon: WeaponInfo?
    private var scrollNode: SKNode!
    private var currencyBar: SKNode!

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.15, green: 0.15, blue: 0.20, alpha: 1.0)

        setupCurrencyBar()
        setupTitle()
        setupWeaponGrid()
        setupBackButton()
    }

    // MARK: - Setup

    private func setupCurrencyBar() {
        currencyBar = SKNode()
        currencyBar.zPosition = 50

        // Gems
        let gemIcon = SKSpriteNode(texture: SpriteGenerator.gemIcon())
        gemIcon.position = CGPoint(x: size.width - 120, y: size.height - 25)
        currencyBar.addChild(gemIcon)

        let gemLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        gemLabel.text = "\(PlayerData.shared.gems)"
        gemLabel.fontSize = 16
        gemLabel.fontColor = SKColor(red: 0.9, green: 0.3, blue: 0.8, alpha: 1)
        gemLabel.horizontalAlignmentMode = .left
        gemLabel.position = CGPoint(x: size.width - 105, y: size.height - 31)
        gemLabel.name = "gemCount"
        currencyBar.addChild(gemLabel)

        // Coins
        let coinIcon = SKSpriteNode(texture: SpriteGenerator.coinIcon())
        coinIcon.position = CGPoint(x: size.width - 50, y: size.height - 25)
        currencyBar.addChild(coinIcon)

        let coinLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        coinLabel.text = "\(PlayerData.shared.coins)"
        coinLabel.fontSize = 16
        coinLabel.fontColor = SKColor(red: 0.9, green: 0.8, blue: 0.2, alpha: 1)
        coinLabel.horizontalAlignmentMode = .left
        coinLabel.position = CGPoint(x: size.width - 35, y: size.height - 31)
        coinLabel.name = "coinCount"
        currencyBar.addChild(coinLabel)

        addChild(currencyBar)
    }

    private func setupTitle() {
        let title = SKLabelNode(fontNamed: "Menlo-Bold")
        title.text = "ARMORY"
        title.fontSize = 28
        title.fontColor = .white
        title.position = CGPoint(x: size.width / 2, y: size.height - 32)
        title.zPosition = 50
        addChild(title)
    }

    private func setupWeaponGrid() {
        scrollNode = SKNode()
        scrollNode.position = .zero
        addChild(scrollNode)

        let weapons = WeaponCatalog.all
        let padding: CGFloat = 12
        let totalCardWidth = cardSize.width + padding
        let totalCardHeight = cardSize.height + padding

        // Center the grid
        let gridWidth = CGFloat(columns) * totalCardWidth - padding
        let startX = (size.width - gridWidth) / 2 + cardSize.width / 2
        let startY = size.height - 80

        for (index, weapon) in weapons.enumerated() {
            let col = index % columns
            let row = index / columns

            let card = createWeaponCard(weapon: weapon)
            card.position = CGPoint(
                x: startX + CGFloat(col) * totalCardWidth,
                y: startY - CGFloat(row) * totalCardHeight
            )
            card.name = "weapon_\(weapon.id)"
            scrollNode.addChild(card)
            weaponCards.append(card)
        }
    }

    private func createWeaponCard(weapon: WeaponInfo) -> SKNode {
        let card = SKNode()

        let owned = PlayerData.shared.ownsWeapon(weapon.id)
        let equipped = PlayerData.shared.loadout.contains(weapon.id)

        // Card background
        let bg = SKShapeNode(rectOf: cardSize, cornerRadius: 10)
        if equipped {
            bg.fillColor = SKColor(red: 0.15, green: 0.35, blue: 0.15, alpha: 0.9)
            bg.strokeColor = SKColor(red: 0.3, green: 0.8, blue: 0.3, alpha: 0.9)
        } else if owned {
            bg.fillColor = SKColor(red: 0.2, green: 0.25, blue: 0.35, alpha: 0.9)
            bg.strokeColor = SKColor(red: 0.4, green: 0.5, blue: 0.7, alpha: 0.8)
        } else {
            bg.fillColor = SKColor(red: 0.2, green: 0.2, blue: 0.25, alpha: 0.9)
            bg.strokeColor = SKColor(white: 0.4, alpha: 0.6)
        }
        bg.lineWidth = 2
        bg.name = "card_bg"
        card.addChild(bg)

        // Weapon icon
        let icon = SKSpriteNode(texture: SpriteGenerator.weaponIcon(for: weapon.id))
        icon.position = CGPoint(x: 0, y: 15)
        icon.setScale(0.75)
        card.addChild(icon)

        // Name
        let nameLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        nameLabel.text = weapon.name
        nameLabel.fontSize = 11
        nameLabel.fontColor = .white
        nameLabel.position = CGPoint(x: 0, y: -28)
        card.addChild(nameLabel)

        // Cost or status
        if equipped {
            let statusLabel = SKLabelNode(fontNamed: "Menlo-Bold")
            statusLabel.text = "EQUIPPED"
            statusLabel.fontSize = 10
            statusLabel.fontColor = SKColor(red: 0.3, green: 0.9, blue: 0.3, alpha: 1)
            statusLabel.position = CGPoint(x: 0, y: -44)
            card.addChild(statusLabel)
        } else if owned {
            let statusLabel = SKLabelNode(fontNamed: "Menlo")
            statusLabel.text = "OWNED"
            statusLabel.fontSize = 10
            statusLabel.fontColor = SKColor(white: 0.7, alpha: 0.8)
            statusLabel.position = CGPoint(x: 0, y: -44)
            card.addChild(statusLabel)
        } else {
            // Gem cost
            let gemIcon = SKSpriteNode(texture: SpriteGenerator.gemIcon())
            gemIcon.position = CGPoint(x: -12, y: -42)
            gemIcon.setScale(0.9)
            card.addChild(gemIcon)

            let costLabel = SKLabelNode(fontNamed: "Menlo-Bold")
            costLabel.text = "\(weapon.gemCost)"
            costLabel.fontSize = 12
            costLabel.fontColor = SKColor(red: 0.9, green: 0.3, blue: 0.8, alpha: 1)
            costLabel.horizontalAlignmentMode = .left
            costLabel.position = CGPoint(x: 0, y: -47)
            card.addChild(costLabel)
        }

        return card
    }

    private func setupBackButton() {
        let backBg = SKShapeNode(rectOf: CGSize(width: 80, height: 36), cornerRadius: 8)
        backBg.fillColor = SKColor(red: 0.6, green: 0.3, blue: 0.1, alpha: 0.9)
        backBg.strokeColor = SKColor(white: 0.8, alpha: 0.5)
        backBg.lineWidth = 1.5
        backBg.position = CGPoint(x: 55, y: size.height - 25)
        backBg.zPosition = 50
        backBg.name = "backButton"
        addChild(backBg)

        let backLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        backLabel.text = "< Back"
        backLabel.fontSize = 14
        backLabel.fontColor = .white
        backLabel.verticalAlignmentMode = .center
        backLabel.name = "backButton"
        backBg.addChild(backLabel)
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let tappedNodes = nodes(at: location)

        // Back button
        if tappedNodes.contains(where: { $0.name == "backButton" }) {
            goBack()
            return
        }

        // Weapon cards
        for node in tappedNodes {
            if let name = node.name, name.hasPrefix("weapon_") {
                handleWeaponTap(name: name)
                return
            }
            // Check parents
            if let parentName = node.parent?.name, parentName.hasPrefix("weapon_") {
                handleWeaponTap(name: parentName)
                return
            }
            if let grandparentName = node.parent?.parent?.name, grandparentName.hasPrefix("weapon_") {
                handleWeaponTap(name: grandparentName)
                return
            }
        }
    }

    private func handleWeaponTap(name: String) {
        let weaponId = String(name.dropFirst("weapon_".count))
        guard let weapon = WeaponCatalog.weapon(byId: weaponId) else { return }

        let data = PlayerData.shared

        if data.ownsWeapon(weaponId) {
            // Already owned — equip to first empty slot
            if data.loadout.contains(weaponId) {
                // Already equipped — unequip
                if let idx = data.loadout.firstIndex(of: weaponId) {
                    data.unequipSlot(idx)
                }
            } else {
                // Find first empty slot
                if let emptySlot = data.loadout.firstIndex(where: { $0 == nil }) {
                    data.equipWeapon(weaponId, toSlot: emptySlot)
                }
            }
            refreshGrid()
        } else {
            // Try to buy
            if data.buyWeapon(weapon) {
                // Auto-equip to first empty slot
                if let emptySlot = data.loadout.firstIndex(where: { $0 == nil }) {
                    data.equipWeapon(weaponId, toSlot: emptySlot)
                }
                refreshGrid()
                refreshCurrency()
                showPurchaseEffect()
            } else {
                showInsufficientFunds()
            }
        }
    }

    private func refreshGrid() {
        scrollNode.removeAllChildren()
        weaponCards.removeAll()
        setupWeaponGrid()
    }

    private func refreshCurrency() {
        if let gem = currencyBar.childNode(withName: "gemCount") as? SKLabelNode {
            gem.text = "\(PlayerData.shared.gems)"
        }
        if let coin = currencyBar.childNode(withName: "coinCount") as? SKLabelNode {
            coin.text = "\(PlayerData.shared.coins)"
        }
    }

    private func showPurchaseEffect() {
        let flash = SKShapeNode(rectOf: size)
        flash.fillColor = SKColor(red: 0.3, green: 1.0, blue: 0.3, alpha: 0.2)
        flash.strokeColor = .clear
        flash.position = CGPoint(x: size.width / 2, y: size.height / 2)
        flash.zPosition = 100
        addChild(flash)
        flash.run(.sequence([.fadeOut(withDuration: 0.3), .removeFromParent()]))
    }

    private func showInsufficientFunds() {
        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.text = "Not enough gems!"
        label.fontSize = 18
        label.fontColor = SKColor(red: 1, green: 0.3, blue: 0.3, alpha: 1)
        label.position = CGPoint(x: size.width / 2, y: 30)
        label.zPosition = 100
        addChild(label)
        label.run(.sequence([
            .wait(forDuration: 1.5),
            .fadeOut(withDuration: 0.3),
            .removeFromParent()
        ]))
    }

    private func goBack() {
        let hangar = HangarScene(size: size)
        hangar.scaleMode = scaleMode
        view?.presentScene(hangar, transition: .push(with: .right, duration: 0.3))
    }
}
