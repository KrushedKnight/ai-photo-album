import Foundation

struct ClusteringConfig {
    let similarityThreshold: Float
    let minClusterSize: Int
    let timeWeight: Float
    let locationWeight: Float

    static let `default` = ClusteringConfig(
        similarityThreshold: 0.8,
        minClusterSize: 1,
        timeWeight: 0.3,
        locationWeight: 0.2
    )
}
