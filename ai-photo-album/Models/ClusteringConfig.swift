import Foundation

struct ClusteringConfig {
    let maxTimeWindow: TimeInterval
    let maxLocationDistance: Double

    let timeWeight: Double
    let locationWeight: Double
    let sizeWeight: Double

    let timeDecayTau: TimeInterval
    let locationDecaySigma: Double

    let assignmentThreshold: Double

    let minClusterSize: Int

    static let `default` = ClusteringConfig(
        maxTimeWindow: 3600,
        maxLocationDistance: 10_000,
        timeWeight: 0.6,
        locationWeight: 0.3,
        sizeWeight: 0.1,
        timeDecayTau: 3600,
        locationDecaySigma: 10_000,
        assignmentThreshold: 0.5,
        minClusterSize: 3
    )
}
