import Foundation

class PlayerData {

    static let shared = PlayerData()

    private let defaults = UserDefaults.standard

    // MARK: - Currency

    var coins: Int {
        get { defaults.integer(forKey: "pd_coins") }
        set { defaults.set(newValue, forKey: "pd_coins") }
    }

    var gems: Int {
        get { defaults.integer(forKey: "pd_gems") }
        set { defaults.set(newValue, forKey: "pd_gems") }
    }

    // MARK: - Weapons

    var ownedWeaponIds: [String] {
        get { defaults.stringArray(forKey: "pd_ownedWeapons") ?? ["basic_gun", "bomb"] }
        set { defaults.set(newValue, forKey: "pd_ownedWeapons") }
    }

    /// 6 loadout slots, nil means empty
    var loadout: [String?] {
        get {
            guard let raw = defaults.stringArray(forKey: "pd_loadout") else {
                return ["basic_gun", "bomb", nil, nil, nil, nil]
            }
            return raw.map { $0.isEmpty ? nil : $0 }
        }
        set {
            let raw = newValue.map { $0 ?? "" }
            defaults.set(raw, forKey: "pd_loadout")
        }
    }

    // MARK: - Upgrades

    var armorLevel: Int {
        get { defaults.integer(forKey: "pd_armorLevel") }
        set { defaults.set(newValue, forKey: "pd_armorLevel") }
    }

    var wingsLevel: Int {
        get { defaults.integer(forKey: "pd_wingsLevel") }
        set { defaults.set(newValue, forKey: "pd_wingsLevel") }
    }

    var engineLevel: Int {
        get { defaults.integer(forKey: "pd_engineLevel") }
        set { defaults.set(newValue, forKey: "pd_engineLevel") }
    }

    // MARK: - Player Level

    var playerLevel: Int {
        get { Swift.max(1, defaults.integer(forKey: "pd_level")) }
        set { defaults.set(newValue, forKey: "pd_level") }
    }

    var experience: Int {
        get { defaults.integer(forKey: "pd_experience") }
        set {
            defaults.set(newValue, forKey: "pd_experience")
            // Auto level-up
            while newValue >= xpForNextLevel {
                let overflow = newValue - xpForNextLevel
                playerLevel += 1
                defaults.set(overflow, forKey: "pd_experience")
            }
        }
    }

    var xpForNextLevel: Int {
        playerLevel * 500
    }

    // MARK: - Computed Stats

    /// Total max health based on armor upgrade
    var maxHealth: Int {
        100 + armorLevel * 15
    }

    /// Speed multiplier based on wings upgrade (1.0 = base)
    var speedMultiplier: CGFloat {
        1.0 + CGFloat(wingsLevel) * 0.08
    }

    /// Scroll speed multiplier based on engine upgrade
    var engineMultiplier: CGFloat {
        1.0 + CGFloat(engineLevel) * 0.05
    }

    // MARK: - Equipped Weapon Helpers

    /// Best equipped gun (highest damage * fire_rate score), or default
    var equippedGun: WeaponInfo {
        let guns = loadout.compactMap { $0 }
            .compactMap { WeaponCatalog.weapon(byId: $0) }
            .filter { $0.isGun }
        return guns.max(by: { gunScore($0) < gunScore($1) }) ?? WeaponCatalog.basicGun
    }

    /// Best equipped bomb, or default
    var equippedBomb: WeaponInfo {
        let bombs = loadout.compactMap { $0 }
            .compactMap { WeaponCatalog.weapon(byId: $0) }
            .filter { $0.isBomb }
        return bombs.max(by: { $0.damage < $1.damage }) ?? WeaponCatalog.bomb
    }

    /// All equipped specials
    var equippedSpecials: [WeaponInfo] {
        loadout.compactMap { $0 }
            .compactMap { WeaponCatalog.weapon(byId: $0) }
            .filter { $0.isSpecial }
    }

    /// Count of all equipped guns (for multi-barrel display)
    var equippedGunCount: Int {
        loadout.compactMap { $0 }
            .compactMap { WeaponCatalog.weapon(byId: $0) }
            .filter { $0.isGun }
            .count
    }

    private func gunScore(_ w: WeaponInfo) -> Double {
        Double(w.damage) / w.fireRate
    }

    // MARK: - Actions

    func ownsWeapon(_ id: String) -> Bool {
        ownedWeaponIds.contains(id)
    }

    func buyWeapon(_ weapon: WeaponInfo) -> Bool {
        guard !ownsWeapon(weapon.id) else { return false }
        guard gems >= weapon.gemCost else { return false }
        gems -= weapon.gemCost
        var owned = ownedWeaponIds
        owned.append(weapon.id)
        ownedWeaponIds = owned
        return true
    }

    func equipWeapon(_ weaponId: String, toSlot slot: Int) {
        guard slot >= 0 && slot < 6 else { return }
        guard ownsWeapon(weaponId) else { return }
        var current = loadout
        // Remove from any other slot first
        for i in 0..<current.count {
            if current[i] == weaponId { current[i] = nil }
        }
        current[slot] = weaponId
        loadout = current
    }

    func unequipSlot(_ slot: Int) {
        guard slot >= 0 && slot < 6 else { return }
        var current = loadout
        current[slot] = nil
        loadout = current
    }

    func upgradeLevel(for upgradeId: String) -> Int {
        switch upgradeId {
        case "armor": return armorLevel
        case "wings": return wingsLevel
        case "engine": return engineLevel
        default: return 0
        }
    }

    func purchaseUpgrade(_ upgrade: UpgradeInfo) -> Bool {
        let currentLevel = upgradeLevel(for: upgrade.id)
        guard currentLevel < upgrade.maxLevel else { return false }
        let cost = upgrade.cost(forLevel: currentLevel)
        guard coins >= cost else { return false }

        coins -= cost
        switch upgrade.id {
        case "armor": armorLevel += 1
        case "wings": wingsLevel += 1
        case "engine": engineLevel += 1
        default: break
        }
        return true
    }

    // MARK: - First Launch

    func ensureDefaults() {
        if defaults.object(forKey: "pd_coins") == nil {
            coins = 1000
            gems = 50
            ownedWeaponIds = ["basic_gun", "bomb"]
            loadout = ["basic_gun", "bomb", nil, nil, nil, nil]
            playerLevel = 1
        }
    }

    private init() {
        ensureDefaults()
    }
}
