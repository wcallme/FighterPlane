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

    static func loadAll() -> [MissionData] {
        guard let urls = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil) else { return [] }
        return urls.compactMap { url in
            guard let data = try? Data(contentsOf: url) else { return nil }
            // Only return files that successfully decode as MissionData
            return try? JSONDecoder().decode(MissionData.self, from: data)
        }
    }
}
