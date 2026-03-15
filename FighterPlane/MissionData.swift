import Foundation

// MARK: - Mission Data Model

struct MissionData: Codable {
    let version: Int
    let name: String
    let description: String?
    let author: String?

    let terrain: TerrainData
    let terrainType: String?
    let waterLevel: Float
    let objects: ObjectsData
    let enemies: [EnemyPlacement]
    let playerStart: PlayerStart
    let objectives: MissionObjective?
}

struct TerrainData: Codable {
    let widthX: Float
    let lengthZ: Float
    let originX: Float
    let originZ: Float
    let segmentsX: Int
    let segmentsZ: Int
    let heightmap: [[Float]]
}

struct ObjectsData: Codable {
    let trees: [TreePlacement]
    let rocks: [RockPlacement]
}

struct TreePlacement: Codable {
    let x: Float
    let z: Float
    let height: Float
    let variation: Int
}

struct RockPlacement: Codable {
    let x: Float
    let z: Float
    let scale: Float
}

struct EnemyPlacement: Codable {
    let type: String
    let x: Float
    let z: Float
    let altitude: Float?
}

struct PlayerStart: Codable {
    let z: Float
    let altitude: Float
}

struct MissionObjective: Codable {
    let type: String
    let description: String?
}

// MARK: - Mission Loader

enum MissionLoader {
    static func load(from filename: String) -> MissionData? {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(MissionData.self, from: data)
    }

    /// Load all missions from bundle, sorted by filename (mission1, mission2, ...)
    static func loadAll() -> [MissionData] {
        guard let urls = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil) else { return [] }
        // Filter to mission files only, sort by name for level ordering
        let missionURLs = urls
            .filter { $0.lastPathComponent.hasPrefix("mission") }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        return missionURLs.compactMap { url in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? JSONDecoder().decode(MissionData.self, from: data)
        }
    }
}

// MARK: - Mission Progress

enum MissionProgress {
    private static let key = "completedMissionLevel"

    /// Highest completed mission level (0 = none completed, 1 = mission1 done, etc.)
    static var completedLevel: Int {
        get { UserDefaults.standard.integer(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }

    /// Call when player beats mission at this index (0-based)
    static func complete(levelIndex: Int) {
        let level = levelIndex + 1
        if level > completedLevel {
            completedLevel = level
        }
    }

    /// Is mission at this index unlocked? (index 0 always unlocked, others require prior completion)
    static func isUnlocked(index: Int) -> Bool {
        return index <= completedLevel
    }

    static func reset() {
        completedLevel = 0
    }
}
