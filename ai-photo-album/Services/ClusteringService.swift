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

    let maxPhotos = 250
    let processedPhotos = sortedPhotos.count > maxPhotos ? Array(sortedPhotos.prefix(maxPhotos)) : sortedPhotos
    if sortedPhotos.count > maxPhotos {
        print("⚠️ Limiting to first \(maxPhotos) photos (from \(sortedPhotos.count) total)")
    }

    var activeClusters: [ClusterBuilder] = []
    var completedClusters: [ClusterBuilder] = []
    var assignedCount = 0
    var newClustersCount = 0

    for (index, photo) in processedPhotos.enumerated() {
        print("\n🔍 Photo #\(index + 1) at \(formatTimestamp(photo.timestamp))")

        // Log active clusters
        print("   Active clusters: \(activeClusters.count)")
        for cluster in activeClusters {
            let timeDiff = photo.timestamp.timeIntervalSince(cluster.timeCentroid)
            let distance = photo.location.distance(from: cluster.locationCentroid)
            print("   - Cluster \(cluster.id.uuidString.prefix(8)): \(cluster.photos.count) photos, time diff: \(formatInterval(timeDiff)), distance: \(Int(distance))m")
        }

        // Filter eligible clusters
        let eligibleClusters = activeClusters.filter { cluster in
            isEligible(photo: photo, cluster: cluster, config: config)
        }
        print("   Eligible clusters: \(eligibleClusters.count)")

        // Calculate scores for all eligible clusters
        var scores: [(cluster: ClusterBuilder, score: Double)] = []
        for cluster in eligibleClusters {
            let score = calculateAffinity(photo: photo, cluster: cluster, config: config)
            scores.append((cluster, score))
            print("   - Cluster \(cluster.id.uuidString.prefix(8)): score = \(String(format: "%.3f", score))")
        }

        // Sort by score descending
        scores.sort { $0.score > $1.score }

        // Find best cluster
        let bestScore = scores.first?.score ?? 0.0
        let secondBestScore = scores.count >= 2 ? scores[1].score : 0.0

        if let best = scores.first, best.score > config.assignmentThreshold {
            best.cluster.addPhoto(photo)
            assignedCount += 1
            print("   ✅ ASSIGNED to cluster \(best.cluster.id.uuidString.prefix(8))")
            print("   Best score: \(String(format: "%.3f", bestScore))")
            if scores.count >= 2 {
                print("   2nd best score: \(String(format: "%.3f", secondBestScore))")
            }
        } else {
            let newCluster = ClusterBuilder(firstPhoto: photo)
            activeClusters.append(newCluster)
            newClustersCount += 1
            print("   🆕 NEW CLUSTER \(newCluster.id.uuidString.prefix(8))")
            print("   Best score: \(String(format: "%.3f", bestScore))")
            if scores.count >= 2 {
                print("   2nd best score: \(String(format: "%.3f", secondBestScore))")
            }
            if eligibleClusters.isEmpty {
                print("   Reason: No eligible clusters (all outside time/location windows)")
            } else if bestScore <= config.assignmentThreshold {
                print("   Reason: Best score \(String(format: "%.3f", bestScore)) ≤ threshold \(String(format: "%.3f", config.assignmentThreshold))")
            }
        }

        let (stillActive, nowCompleted) = activeClusters.reduce(into: ([ClusterBuilder](), [ClusterBuilder]())) { result, cluster in
            let timeSinceEnd = photo.timestamp.timeIntervalSince(cluster.endTime)
            if timeSinceEnd <= config.maxTimeWindow {
                result.0.append(cluster)
            } else {
                result.1.append(cluster)
            }
        }
        activeClusters = stillActive
        completedClusters.append(contentsOf: nowCompleted)
    }

    print("✅ Assigned \(assignedCount) photos, created \(newClustersCount) clusters")
    print("📊 Completed clusters: \(completedClusters.count), still active: \(activeClusters.count)")

    let allClusters = completedClusters + activeClusters
    let allEvents = allClusters.map { $0.toEvent() }
    let filtered = allEvents.filter { $0.photos.count >= config.minClusterSize }

    print("📦 After filtering (min size \(config.minClusterSize)): \(filtered.count) events")
    return filtered
}

private func isEligible(
    photo: Photo,
    cluster: ClusterBuilder,
    config: ClusteringConfig
) -> Bool {
    let timeToStart = photo.timestamp.timeIntervalSince(cluster.startTime)
    let timeToEnd = photo.timestamp.timeIntervalSince(cluster.endTime)

    let withinWindow: Bool
    if timeToStart < 0 {
        withinWindow = abs(timeToStart) <= config.maxTimeWindow
    } else if timeToEnd > 0 {
        withinWindow = timeToEnd <= config.maxTimeWindow
    } else {
        withinWindow = true
    }

    guard withinWindow else {
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

private func formatTimestamp(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM d, h:mm a"
    return formatter.string(from: date)
}

private func formatInterval(_ interval: TimeInterval) -> String {
    let absInterval = abs(interval)
    let hours = Int(absInterval) / 3600
    let minutes = Int(absInterval) % 3600 / 60
    let sign = interval >= 0 ? "+" : "-"

    if hours > 0 {
        return "\(sign)\(hours)h \(minutes)m"
    } else {
        return "\(sign)\(minutes)m"
    }
}
