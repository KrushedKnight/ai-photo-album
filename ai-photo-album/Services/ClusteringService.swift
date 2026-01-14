import Foundation
import CoreLocation
import Accelerate

func clusterPhotos(_ photos: [Photo], config: ClusteringConfig = .default) async -> [Event] {
    guard !photos.isEmpty else {
        print("No photos to cluster")
        return []
    }

    print("Starting clustering with \(photos.count) photos")
    var clusters = photos.map { singlePhotoCluster($0) }

    while clusters.count > 1 {
        let (idx1, idx2, dist) = closestClusters(clusters, photos, config)
        print("Closest clusters: distance = \(dist), threshold = \(config.similarityThreshold)")
        if dist > config.similarityThreshold { break }

        let merged = merge(clusters[idx1], clusters[idx2])
        clusters.remove(at: max(idx1, idx2))
        clusters.remove(at: min(idx1, idx2))
        clusters.append(merged)
        print("Merged clusters, now have \(clusters.count) clusters")
    }

    let filtered = clusters.filter { $0.photos.count >= config.minClusterSize }
    print("After filtering: \(filtered.count) events (from \(clusters.count) clusters)")
    return filtered
}

private func singlePhotoCluster(_ photo: Photo) -> Event {
    Event(
        id: UUID(),
        startTime: photo.timestamp,
        endTime: photo.timestamp,
        centralLocation: photo.location,
        photos: [photo]
    )
}

private func closestClusters(_ clusters: [Event], _ allPhotos: [Photo], _ config: ClusteringConfig) -> (Int, Int, Float) {
    var minDist: Float = .infinity
    var minPair = (0, 0)

    for i in 0..<clusters.count {
        for j in (i+1)..<clusters.count {
            let dist = clusterDistance(clusters[i], clusters[j], config)
            if dist < minDist {
                minDist = dist
                minPair = (i, j)
            }
        }
    }

    return (minPair.0, minPair.1, minDist)
}

private func clusterDistance(_ c1: Event, _ c2: Event, _ config: ClusteringConfig) -> Float {
    var totalDist: Float = 0
    var count = 0

    for p1 in c1.photos {
        for p2 in c2.photos {
            totalDist += distance(a: p1, b: p2, config: config)
            count += 1
        }
    }

    return count > 0 ? totalDist / Float(count) : .infinity
}

private func merge(_ c1: Event, _ c2: Event) -> Event {
    let allPhotos = c1.photos + c2.photos
    let sortedPhotos = allPhotos.sorted { $0.timestamp < $1.timestamp }

    let startTime = min(c1.startTime, c2.startTime)
    let endTime = max(c1.endTime, c2.endTime)

    let totalLat = c1.centralLocation.coordinate.latitude * Double(c1.photos.count) +
                   c2.centralLocation.coordinate.latitude * Double(c2.photos.count)
    let totalLon = c1.centralLocation.coordinate.longitude * Double(c1.photos.count) +
                   c2.centralLocation.coordinate.longitude * Double(c2.photos.count)
    let totalCount = Double(c1.photos.count + c2.photos.count)

    let centralLocation = CLLocation(
        latitude: totalLat / totalCount,
        longitude: totalLon / totalCount
    )

    return Event(
        id: UUID(),
        startTime: startTime,
        endTime: endTime,
        centralLocation: centralLocation,
        photos: sortedPhotos
    )
}

func distance(a: Photo, b: Photo, config: ClusteringConfig) -> Float {
    let visual = cosineDistance(a.vector, b.vector)
    let time = timeDistance(a.timestamp, b.timestamp)
    let location = locationDistance(a.location, b.location)

    return visual + config.timeWeight * time + config.locationWeight * location
}

private func cosineDistance(_ v1: [Float]?, _ v2: [Float]?) -> Float {
    guard let v1 = v1, let v2 = v2, v1.count == v2.count, !v1.isEmpty else {
        return 1.0
    }

    var dotProduct: Float = 0
    var normA: Float = 0
    var normB: Float = 0

    vDSP_dotpr(v1, 1, v2, 1, &dotProduct, vDSP_Length(v1.count))
    vDSP_svesq(v1, 1, &normA, vDSP_Length(v1.count))
    vDSP_svesq(v2, 1, &normB, vDSP_Length(v2.count))

    let magnitude = sqrt(normA * normB)
    if magnitude == 0 { return 1.0 }

    let similarity = dotProduct / magnitude
    return 1.0 - similarity
}

private func timeDistance(_ t1: Date, _ t2: Date) -> Float {
    let seconds = abs(t1.timeIntervalSince(t2))
    let hours = seconds / 3600.0
    return Float(min(hours / 24.0, 1.0))
}

private func locationDistance(_ loc1: CLLocation, _ loc2: CLLocation) -> Float {
    let meters = loc1.distance(from: loc2)
    let km = meters / 1000.0
    return Float(min(km / 100.0, 1.0))
}
