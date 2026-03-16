import Foundation

class GameManager {

    static let shared = GameManager()

    // Persistent stats
    var highScore: Int {
        get { UserDefaults.standard.integer(forKey: "highScore") }
        set { UserDefaults.standard.set(newValue, forKey: "highScore") }
    }

    var totalCoins: Int {
        get { UserDefaults.standard.integer(forKey: "totalCoins") }
        set { UserDefaults.standard.set(newValue, forKey: "totalCoins") }
    }

    var gamesPlayed: Int {
        get { UserDefaults.standard.integer(forKey: "gamesPlayed") }
        set { UserDefaults.standard.set(newValue, forKey: "gamesPlayed") }
    }

    // Current session
    var currentScore: Int = 0
    var currentCoins: Int = 0
    var enemiesDestroyed: Int = 0
    var bombsDropped: Int = 0
    var shotsFired: Int = 0

    // Difficulty scaling
    var difficultyLevel: Int = 1
    private var elapsedTime: TimeInterval = 0
    private let difficultyInterval: TimeInterval = 30.0 // increase every 30 seconds

    // MARK: - Infinite Battle Scaling

    // Spawn rates — accelerate with difficulty
    var groundSpawnInterval: TimeInterval {
        // Starts at 1.8s, drops faster as difficulty climbs, floors at 0.35s
        max(0.35, GameConfig.groundEnemySpawnInterval - Double(difficultyLevel - 1) * 0.12)
    }

    var airSpawnInterval: TimeInterval {
        // Starts at 6.0s, floors at 1.2s
        max(1.2, GameConfig.airEnemySpawnInterval - Double(difficultyLevel - 1) * 0.35)
    }

    // Enemy health bonus from difficulty
    var enemyHealthBonus: Int {
        (difficultyLevel - 1) / 3 // +1 health every 3 difficulty levels
    }

    // AA gun accuracy — jitter shrinks as difficulty rises, making shots deadlier
    // At level 1: ±1.0 Y, ±0.5 Z (easy to dodge)
    // By level 10: ±0.25 Y, ±0.12 Z (near-perfect aim)
    var aaJitterY: Float {
        max(0.15, 1.0 - Float(difficultyLevel - 1) * 0.09)
    }

    var aaJitterZ: Float {
        max(0.08, 0.5 - Float(difficultyLevel - 1) * 0.05)
    }

    // Enemy fire rate multiplier — guns shoot faster at higher difficulty
    // Level 1: 1.0x (normal), Level 5: 0.7x (30% faster), Level 10: 0.5x (2x speed)
    var fireRateMultiplier: Float {
        max(0.4, 1.0 - Float(difficultyLevel - 1) * 0.06)
    }

    // Enemy bullet speed scales up slightly
    var enemyBulletSpeedMultiplier: Float {
        min(1.8, 1.0 + Float(difficultyLevel - 1) * 0.06)
    }

    // Number of simultaneous ground enemies per spawn wave (more targets at once)
    var groundSpawnCount: Int {
        switch difficultyLevel {
        case 1...3: return 1
        case 4...6: return Int.random(in: 1...2)
        case 7...9: return Int.random(in: 1...3)
        default:    return Int.random(in: 2...3)
        }
    }

    // MARK: - Biome Tracking (Endless Mode)

    /// Each biome spans 3 difficulty levels (90 seconds).
    /// 0=temperate, 1=desert, 2=arctic, 3=volcanic, 4+=random
    var currentBiome: Int {
        (difficultyLevel - 1) / 3
    }

    /// True once the player is halfway through biome 1 (difficulty >= 2)
    var shouldSpawnEnemyPlanes: Bool {
        difficultyLevel >= 2
    }

    /// How many planes per air spawn wave, based on biome progression
    var airSpawnGroupSize: Int {
        switch currentBiome {
        case 0: return 1            // temperate: single fighters
        case 1: return 2            // desert: pairs
        case 2: return Int.random(in: 1...2)
        case 3: return Int.random(in: 1...2)
        default: return 2           // after biome 4: always pairs
        }
    }

    /// Whether AI tracking fighters should appear in this biome
    var shouldSpawnAIFighters: Bool {
        currentBiome >= 1           // AI fighters from desert onward
    }

    /// After the 4th biome, every plane has AI tracking
    var allPlanesAreAI: Bool {
        currentBiome >= 4
    }

    private init() {}

    func resetSession() {
        currentScore = 0
        currentCoins = 0
        enemiesDestroyed = 0
        bombsDropped = 0
        shotsFired = 0
        difficultyLevel = 1
        elapsedTime = 0
    }

    func update(deltaTime: TimeInterval) {
        elapsedTime += deltaTime
        let newLevel = Int(elapsedTime / difficultyInterval) + 1
        if newLevel != difficultyLevel {
            difficultyLevel = newLevel
        }
    }

    func addScore(_ points: Int) {
        currentScore += points
        currentCoins += points / 10
    }

    func endGame() {
        gamesPlayed += 1
        if currentScore > highScore {
            highScore = currentScore
        }
        totalCoins += currentCoins

        // Award currency to PlayerData
        let data = PlayerData.shared
        data.coins += currentCoins
        data.gems += currentScore / 100 // 1 gem per 100 score

        // Award XP
        data.experience += currentScore / 10
    }
}
