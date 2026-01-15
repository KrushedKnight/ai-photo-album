import Foundation
import CoreLocation

private class ClusterBuilder {
    let id: UUID
    var photos: [Photo]
    var timeCentroid: Date
    var locationCentroid: CLLocation
    var startTime: Date
    var endTime: Date

    init(firstPhoto: Photo) {
        self.id = UUID()
        self.photos = [firstPhoto]
        self.timeCentroid = firstPhoto.timestamp
        self.locationCentroid = firstPhoto.location
        self.startTime = firstPhoto.timestamp
        self.endTime = firstPhoto.timestamp
    }

    func addPhoto(_ photo: Photo) {
        let n = Double(photos.count)

        let currentInterval = timeCentroid.timeIntervalSinceReferenceDate
        let newInterval = photo.timestamp.timeIntervalSinceReferenceDate
        timeCentroid = Date(timeIntervalSinceReferenceDate: (currentInterval * n + newInterval) / (n + 1))

        let currentLat = locationCentroid.coordinate.latitude
        let currentLon = locationCentroid.coordinate.longitude
        let newLat = photo.location.coordinate.latitude
        let newLon = photo.location.coordinate.longitude
        locationCentroid = CLLocation(
            latitude: (currentLat * n + newLat) / (n + 1),
            longitude: (currentLon * n + newLon) / (n + 1)
        )

        startTime = min(startTime, photo.timestamp)
        endTime = max(endTime, photo.timestamp)

        photos.append(photo)
    }

    func toEvent() -> Event {
        Event(
            id: id,
            startTime: startTime,
            endTime: endTime,
            centralLocation: locationCentroid,
            photos: photos.sorted { $0.timestamp < $1.timestamp }
        )
    }
}

func clusterPhotos(_ photos: [Photo], config: ClusteringConfig = .default) async -> [Event] {
    guard !photos.isEmpty else { return [] }

    print("📊 Clustering \(photos.count) photos with online heuristic assignment")

    let sortedPhotos = photos.sorted { $0.timestamp < $1.timestamp }

    var activeClusters: [ClusterBuilder] = []
    var assignedCount = 0
    var newClustersCount = 0

    for photo in sortedPhotos {
        let eligibleClusters = activeClusters.filter { cluster in
            isEligible(photo: photo, cluster: cluster, config: config)
        }

        if let bestCluster = findBestCluster(for: photo, among: eligibleClusters, config: config) {
            bestCluster.addPhoto(photo)
            assignedCount += 1
        } else {
            activeClusters.append(ClusterBuilder(firstPhoto: photo))
            newClustersCount += 1
        }

        activeClusters = activeClusters.filter { cluster in
            abs(photo.timestamp.timeIntervalSince(cluster.timeCentroid)) <= config.maxTimeWindow
        }
    }

    print("✅ Assigned \(assignedCount) photos, created \(newClustersCount) clusters")

    let allEvents = activeClusters.map { $0.toEvent() }
    let filtered = allEvents.filter { $0.photos.count >= config.minClusterSize }

    print("📦 After filtering (min size \(config.minClusterSize)): \(filtered.count) events")
    return filtered
}

private func isEligible(
    photo: Photo,
    cluster: ClusterBuilder,
    config: ClusteringConfig
) -> Bool {
    let timeDelta = abs(photo.timestamp.timeIntervalSince(cluster.timeCentroid))
    guard timeDelta <= config.maxTimeWindow else {
        return false
    }

    let hasLocation = photo.location.coordinate.latitude != 0 ||
                     photo.location.coordinate.longitude != 0

    if hasLocation {
        let distance = photo.location.distance(from: cluster.locationCentroid)
        guard distance <= config.maxLocationDistance else {
            return false
        }
    }

    return true
}

private func calculateAffinity(
    photo: Photo,
    cluster: ClusterBuilder,
    config: ClusteringConfig
) -> Double {
    let timeDelta = abs(photo.timestamp.timeIntervalSince(cluster.timeCentroid))
    let timeScore = exp(-timeDelta / config.timeDecayTau)

    let distance = photo.location.distance(from: cluster.locationCentroid)
    let locationScore = exp(-distance / config.locationDecaySigma)

    let sizeScore = log(1.0 + Double(cluster.photos.count))

    return config.timeWeight * timeScore +
           config.locationWeight * locationScore +
           config.sizeWeight * sizeScore
}

private func findBestCluster(
    for photo: Photo,
    among clusters: [ClusterBuilder],
    config: ClusteringConfig
) -> ClusterBuilder? {
    guard !clusters.isEmpty else { return nil }

    var bestCluster: ClusterBuilder?
    var bestScore = config.assignmentThreshold

    for cluster in clusters {
        let score = calculateAffinity(photo: photo, cluster: cluster, config: config)
        if score > bestScore {
            bestScore = score
            bestCluster = cluster
        }
    }

    return bestCluster
}
