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

    // Spawn rates (modified by difficulty)
    var groundSpawnInterval: TimeInterval {
        max(0.6, GameConfig.groundEnemySpawnInterval - Double(difficultyLevel - 1) * 0.15)
    }

    var airSpawnInterval: TimeInterval {
        max(2.0, GameConfig.airEnemySpawnInterval - Double(difficultyLevel - 1) * 0.4)
    }

    // Enemy health bonus from difficulty
    var enemyHealthBonus: Int {
        (difficultyLevel - 1) / 3 // +1 health every 3 difficulty levels
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
