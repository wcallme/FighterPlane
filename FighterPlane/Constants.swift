import SpriteKit

enum GameConfig {
    // Gameplay
    static let scrollSpeed: CGFloat = 120.0
    static let playerSpeed: CGFloat = 250.0
    static let playerHealth: Int = 100
    static let playerFireRate: TimeInterval = 0.18
    static let bombCooldown: TimeInterval = 1.5
    static let bombFallDuration: TimeInterval = 1.0
    static let bulletSpeed: CGFloat = 600.0
    static let enemyBulletSpeed: CGFloat = 300.0

    // Spawning
    static let groundEnemySpawnInterval: TimeInterval = 1.8
    static let airEnemySpawnInterval: TimeInterval = 6.0

    // Scoring
    static let tankScore = 100
    static let aaGunScore = 150
    static let buildingScore = 200
    static let fighterScore = 300

    // Enemy health
    static let tankHealth = 1
    static let aaGunHealth = 1
    static let buildingHealth = 2
    static let fighterHealth = 2
    static let samLauncherHealth = 2

    // Damage
    static let bulletDamage = 1
    static let bombDamage = 3
    static let enemyBulletDamage = 10
    static let samMissileDamage = 20
    static let collisionDamage = 25

    // Enemy firing ranges (3D distance)
    static let tankFireRange: Float = 30.0
    static let aaGunFireRange: Float = 35.0
    static let samFireRange: Float = 45.0
    static let fighterFireRange: Float = 25.0

    // Scoring
    static let samLauncherScore = 250
}

enum PhysicsCategory {
    static let none: UInt32       = 0
    static let player: UInt32     = 1 << 0
    static let playerBullet: UInt32 = 1 << 1
    static let enemy: UInt32      = 1 << 2
    static let enemyBullet: UInt32 = 1 << 3
    static let bomb: UInt32       = 1 << 4
    static let groundTarget: UInt32 = 1 << 5
}

enum ZLayer: CGFloat {
    case background = 0
    case groundDetail = 1
    case shadows = 2
    case groundEnemies = 3
    case explosions = 4
    case bombs = 5
    case playerShadow = 8
    case player = 10
    case bullets = 11
    case airEnemies = 12
    case clouds = 20
    case hud = 100
}

enum EnemyType {
    case tank
    case aaGun
    case building
    case fighter
    case samLauncher

    var health: Int {
        switch self {
        case .tank: return GameConfig.tankHealth
        case .aaGun: return GameConfig.aaGunHealth
        case .building: return GameConfig.buildingHealth
        case .fighter: return GameConfig.fighterHealth
        case .samLauncher: return GameConfig.samLauncherHealth
        }
    }

    var score: Int {
        switch self {
        case .tank: return GameConfig.tankScore
        case .aaGun: return GameConfig.aaGunScore
        case .building: return GameConfig.buildingScore
        case .fighter: return GameConfig.fighterScore
        case .samLauncher: return GameConfig.samLauncherScore
        }
    }

    var isGround: Bool {
        switch self {
        case .tank, .aaGun, .building, .samLauncher: return true
        case .fighter: return false
        }
    }

    var fireRange: Float {
        switch self {
        case .tank: return GameConfig.tankFireRange
        case .aaGun: return GameConfig.aaGunFireRange
        case .samLauncher: return GameConfig.samFireRange
        case .fighter: return GameConfig.fighterFireRange
        case .building: return 0 // buildings don't fire
        }
    }
}

enum GameState {
    case playing
    case paused
    case gameOver
}
