import Foundation

struct PersonClusteringConfig: Codable {
    let similarityThreshold: Float
    let minFaceQuality: Float
    let maxFacesPerPhoto: Int

    static let `default` = PersonClusteringConfig(
        similarityThreshold: 0.65,
        minFaceQuality: 0.3,
        maxFacesPerPhoto: 10
    )
}

struct PlaceClusteringConfig: Codable {
    let spatialRadiusMeters: Double
    let affinityThreshold: Float
    let spatialWeight: Double
    let sceneWeight: Double
    let mergeNearbyThreshold: Double

    static let `default` = PlaceClusteringConfig(
        spatialRadiusMeters: 100.0,
        affinityThreshold: 0.5,
        spatialWeight: 0.7,
        sceneWeight: 0.3,
        mergeNearbyThreshold: 50.0
    )
}

struct SceneGroupingConfig: Codable {
    let minConfidence: Float
    let maxScenesPerPhoto: Int

    static let `default` = SceneGroupingConfig(
        minConfidence: 0.2,
        maxScenesPerPhoto: 5
    )
}

struct AnchorConfig: Codable {
    let personConfig: PersonClusteringConfig
    let placeConfig: PlaceClusteringConfig
    let sceneConfig: SceneGroupingConfig

    static let `default` = AnchorConfig(
        personConfig: .default,
        placeConfig: .default,
        sceneConfig: .default
    )
}
