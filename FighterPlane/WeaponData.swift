import SpriteKit

// MARK: - Weapon Category

enum WeaponCategory: String, Codable {
    case gun
    case bomb
    case special
}

// MARK: - Weapon Definition

struct WeaponInfo {
    let id: String
    let name: String
    let category: WeaponCategory
    let gemCost: Int
    let damage: Int
    let fireRate: TimeInterval      // seconds between shots (guns)
    let blastRadius: CGFloat        // explosion radius (bombs)
    let bulletCount: Int            // projectiles per shot
    let bulletSpread: CGFloat       // spread angle in radians
    let projectileSpeed: CGFloat    // bullet/missile speed
    let isHoming: Bool              // missiles track targets
    let description: String

    // Derived convenience
    var isGun: Bool { category == .gun }
    var isBomb: Bool { category == .bomb }
    var isSpecial: Bool { category == .special }
}

// MARK: - Weapon Catalog

enum WeaponCatalog {

    // --- Guns ---

    static let basicGun = WeaponInfo(
        id: "basic_gun", name: "Machine Gun", category: .gun,
        gemCost: 0, damage: 1, fireRate: 0.22,
        blastRadius: 0, bulletCount: 1, bulletSpread: 0,
        projectileSpeed: 480, isHoming: false,
        description: "Standard-issue 7.62mm machine gun."
    )

    static let cannon = WeaponInfo(
        id: "cannon", name: "Heavy Cannon", category: .gun,
        gemCost: 40, damage: 3, fireRate: 0.9,
        blastRadius: 0, bulletCount: 1, bulletSpread: 0,
        projectileSpeed: 360, isHoming: false,
        description: "Slow-firing 30mm cannon, heavy punch."
    )

    static let machineGun = WeaponInfo(
        id: "machine_gun", name: "Chain Gun", category: .gun,
        gemCost: 100, damage: 1, fireRate: 0.08,
        blastRadius: 0, bulletCount: 1, bulletSpread: 0.03,
        projectileSpeed: 442, isHoming: false,
        description: "20mm chain-driven cannon, blistering fire rate."
    )

    static let autocannon = WeaponInfo(
        id: "autocannon", name: "Twin Autocannon", category: .gun,
        gemCost: 180, damage: 2, fireRate: 0.14,
        blastRadius: 0, bulletCount: 2, bulletSpread: 0.05,
        projectileSpeed: 480, isHoming: false,
        description: "Dual-linked 23mm cannons."
    )

    // --- Bombs ---

    static let bomb = WeaponInfo(
        id: "bomb", name: "Bomb", category: .bomb,
        gemCost: 80, damage: 8, fireRate: 2.6,
        blastRadius: 50, bulletCount: 1, bulletSpread: 0,
        projectileSpeed: 0, isHoming: false,
        description: "Standard explosive ordnance."
    )

    static let miningBomb = WeaponInfo(
        id: "mining_bomb", name: "Mining Bomb", category: .bomb,
        gemCost: 150, damage: 9, fireRate: 2.925,
        blastRadius: 45, bulletCount: 1, bulletSpread: 0,
        projectileSpeed: 0, isHoming: false,
        description: "Penetrating blast, focused radius."
    )

    static let heavyBomb = WeaponInfo(
        id: "heavy_bomb", name: "Heavy Bomb", category: .bomb,
        gemCost: 280, damage: 10, fireRate: 3.25,
        blastRadius: 80, bulletCount: 1, bulletSpread: 0,
        projectileSpeed: 0, isHoming: false,
        description: "Massive blast radius, heavy payload."
    )

    static let clusterWarhead = WeaponInfo(
        id: "cluster_warhead", name: "Cluster Warhead", category: .bomb,
        gemCost: 300, damage: 3, fireRate: 2.925,
        blastRadius: 30, bulletCount: 7, bulletSpread: 0,
        projectileSpeed: 0, isHoming: false,
        description: "Splits mid-air into 7 scatter bomblets."
    )

    // --- Specials ---

    static let ecmJammer = WeaponInfo(
        id: "ecm_jammer", name: "ECM Jammer", category: .special,
        gemCost: 200, damage: 0, fireRate: 42.5,
        blastRadius: 0, bulletCount: 0, bulletSpread: 0,
        projectileSpeed: 0, isHoming: false,
        description: "Jams enemy missiles for 5.5s. 37s recharge."
    )

    static let aimRockets = WeaponInfo(
        id: "aim_rockets", name: "AIM Rockets", category: .special,
        gemCost: 500, damage: 7, fireRate: 17.0,
        blastRadius: 0, bulletCount: 2, bulletSpread: 0,
        projectileSpeed: 300, isHoming: true,
        description: "2 homing rockets target enemy planes. 17s reload each."
    )

    // --- All weapons ---

    static let all: [WeaponInfo] = [
        basicGun, cannon, machineGun, autocannon,
        bomb, miningBomb, heavyBomb, clusterWarhead,
        ecmJammer, aimRockets
    ]

    static let guns: [WeaponInfo] = all.filter { $0.isGun }
    static let bombs: [WeaponInfo] = all.filter { $0.isBomb }
    static let specials: [WeaponInfo] = all.filter { $0.isSpecial }

    static func weapon(byId id: String) -> WeaponInfo? {
        all.first { $0.id == id }
    }
}

// MARK: - Upgrade Definition

struct UpgradeInfo {
    let id: String
    let name: String
    let maxLevel: Int
    let baseCost: Int
    let costMultiplier: Double

    func cost(forLevel level: Int) -> Int {
        guard level < maxLevel else { return 0 }
        return Int(Double(baseCost) * pow(costMultiplier, Double(level)))
    }
}

enum UpgradeCatalog {
    static let armor = UpgradeInfo(
        id: "armor", name: "Armor", maxLevel: 10, baseCost: 500, costMultiplier: 1.5
    )
    static let wings = UpgradeInfo(
        id: "wings", name: "Wings", maxLevel: 10, baseCost: 800, costMultiplier: 1.5
    )
    static let engine = UpgradeInfo(
        id: "engine", name: "Engine", maxLevel: 10, baseCost: 600, costMultiplier: 1.5
    )

    static let all: [UpgradeInfo] = [armor, wings, engine]
}
