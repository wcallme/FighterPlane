import Foundation

struct PlaneInfo {
    let id: String
    let name: String
}

enum PlaneCatalog {
    static let all: [PlaneInfo] = [
        PlaneInfo(id: "F16", name: "F-16 Falcon"),
        PlaneInfo(id: "F22", name: "F-22 Raptor"),
        PlaneInfo(id: "B2", name: "B-2 Spirit"),
        PlaneInfo(id: "B3", name: "B-3 Phantom"),
    ]

    static func plane(byId id: String) -> PlaneInfo? {
        all.first { $0.id == id }
    }

    static func nextPlane(after id: String) -> PlaneInfo {
        guard let idx = all.firstIndex(where: { $0.id == id }) else { return all[0] }
        return all[(idx + 1) % all.count]
    }

    static func previousPlane(before id: String) -> PlaneInfo {
        guard let idx = all.firstIndex(where: { $0.id == id }) else { return all[0] }
        return all[(idx - 1 + all.count) % all.count]
    }
}

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

    // MARK: - Plane Selection

    var selectedPlaneId: String {
        get {
            let id = defaults.string(forKey: "pd_selectedPlane") ?? "F16"
            // Migrate legacy "default" plane to F16
            if id == "default" { defaults.set("F16", forKey: "pd_selectedPlane"); return "F16" }
            return id
        }
        set { defaults.set(newValue, forKey: "pd_selectedPlane") }
    }

    var selectedPlaneName: String {
        PlaneCatalog.plane(byId: selectedPlaneId)?.name ?? "F-16 Falcon"
    }

    // MARK: - Weapons

    /// Stores owned weapons as a flat list allowing duplicates (e.g. ["bomb","bomb","basic_gun"])
    var ownedWeaponIds: [String] {
        get { defaults.stringArray(forKey: "pd_ownedWeapons") ?? ["basic_gun", "bomb"] }
        set { defaults.set(newValue, forKey: "pd_ownedWeapons") }
    }

    /// How many copies of a weapon the player owns
    func ownedCount(of weaponId: String) -> Int {
        ownedWeaponIds.filter { $0 == weaponId }.count
    }

    /// How many copies are currently equipped in the loadout
    func equippedCount(of weaponId: String) -> Int {
        loadout.compactMap { $0 }.filter { $0 == weaponId }.count
    }

    /// How many unequipped copies are available
    func availableCount(of weaponId: String) -> Int {
        ownedCount(of: weaponId) - equippedCount(of: weaponId)
    }

    /// 6 loadout slots, nil means empty
    /// Cached to avoid repeated UserDefaults deserialization (read by equippedGuns, equippedBombs, etc.)
    private var _loadoutCache: [String?]?

    var loadout: [String?] {
        get {
            if let cached = _loadoutCache { return cached }
            guard let raw = defaults.stringArray(forKey: "pd_loadout") else {
                let def: [String?] = ["basic_gun", "bomb", nil, nil, nil, nil]
                _loadoutCache = def
                return def
            }
            var result = raw.map { $0.isEmpty ? nil : $0 } as [String?]
            // Ensure exactly 6 slots
            while result.count < 6 { result.append(nil) }
            if result.count > 6 { result = Array(result.prefix(6)) }
            _loadoutCache = result
            return result
        }
        set {
            _loadoutCache = newValue
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
            var xp = newValue
            defaults.set(xp, forKey: "pd_experience")
            // Auto level-up
            while xp >= xpForNextLevel {
                xp -= xpForNextLevel
                playerLevel += 1
                defaults.set(xp, forKey: "pd_experience")
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

    /// All equipped bombs in loadout order (for multi-bomb system)
    var equippedBombs: [WeaponInfo] {
        let bombs = loadout.compactMap { $0 }
            .compactMap { WeaponCatalog.weapon(byId: $0) }
            .filter { $0.isBomb }
        return bombs.isEmpty ? [WeaponCatalog.bomb] : bombs
    }

    /// All equipped specials
    var equippedSpecials: [WeaponInfo] {
        loadout.compactMap { $0 }
            .compactMap { WeaponCatalog.weapon(byId: $0) }
            .filter { $0.isSpecial }
    }

    /// All equipped guns in loadout order (for multi-gun firing)
    var equippedGuns: [WeaponInfo] {
        let guns = loadout.compactMap { $0 }
            .compactMap { WeaponCatalog.weapon(byId: $0) }
            .filter { $0.isGun }
        return guns.isEmpty ? [WeaponCatalog.basicGun] : guns
    }

    /// Count of all equipped guns (for multi-barrel display)
    var equippedGunCount: Int {
        equippedGuns.count
    }

    private func gunScore(_ w: WeaponInfo) -> Double {
        Double(w.damage) / w.fireRate
    }

    // MARK: - Actions

    func ownsWeapon(_ id: String) -> Bool {
        ownedWeaponIds.contains(id)
    }

    func buyWeapon(_ weapon: WeaponInfo) -> Bool {
        guard gems >= weapon.gemCost else { return false }
        gems -= weapon.gemCost
        var owned = ownedWeaponIds
        owned.append(weapon.id)
        ownedWeaponIds = owned
        return true
    }

    func equipWeapon(_ weaponId: String, toSlot slot: Int) {
        guard slot >= 0 && slot < 6 else { return }
        // Must have an unequipped copy available
        guard availableCount(of: weaponId) > 0 else { return }
        var current = loadout
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
            coins = 30000
            gems = 1000
            ownedWeaponIds = ["basic_gun", "bomb"]
            loadout = ["basic_gun", "bomb", nil, nil, nil, nil]
            playerLevel = 1
        }
    }

    private init() {
        ensureDefaults()
    }
}
