import Foundation
import CoreLocation

struct PlaceClusteringResult {
    var places: [UUID: Place]
    var photoPlaces: [UUID: PhotoPlace]
}

struct PlaceCandidate {
    let photo: Photo
    let location: CLLocation
    let dominantScene: String?
}

struct PlaceClusteringService {
    static func clusterPlaces(
        from photos: [Photo],
        config: PlaceClusteringConfig = .default
    ) async -> PlaceClusteringResult {
        var places: [UUID: Place] = [:]
        var photoPlaces: [UUID: PhotoPlace] = [:]

        let candidates = extractLocationCandidates(from: photos)
        let sortedCandidates = candidates.sorted { $0.photo.timestamp < $1.photo.timestamp }

        for candidate in sortedCandidates {
            let nearby = findNearbyPlaces(
                location: candidate.location,
                places: Array(places.values),
                radius: config.spatialRadiusMeters
            )

            if nearby.isEmpty {
                let newPlace = createPlace(from: candidate)
                places[newPlace.id] = newPlace

                let photoPlace = PhotoPlace(
                    photoId: candidate.photo.id,
                    placeId: newPlace.id,
                    distanceMeters: 0.0,
                    confidence: 1.0,
                    visitedAt: candidate.photo.timestamp
                )
                photoPlaces[photoPlace.id] = photoPlace
            } else {
                let affinities = nearby.map { place in
                    (place, calculateAffinity(
                        candidate: candidate,
                        place: place,
                        config: config
                    ))
                }

                if let bestMatch = affinities.max(by: { $0.1 < $1.1 }),
                   bestMatch.1 >= config.affinityThreshold {
                    let distance = candidate.location.distance(from: bestMatch.0.centroid)

                    let photoPlace = PhotoPlace(
                        photoId: candidate.photo.id,
                        placeId: bestMatch.0.id,
                        distanceMeters: distance,
                        confidence: bestMatch.1,
                        visitedAt: candidate.photo.timestamp
                    )
                    photoPlaces[photoPlace.id] = photoPlace

                    updatePlace(
                        placeId: bestMatch.0.id,
                        with: candidate,
                        places: &places
                    )
                } else {
                    let newPlace = createPlace(from: candidate)
                    places[newPlace.id] = newPlace

                    let photoPlace = PhotoPlace(
                        photoId: candidate.photo.id,
                        placeId: newPlace.id,
                        distanceMeters: 0.0,
                        confidence: 1.0,
                        visitedAt: candidate.photo.timestamp
                    )
                    photoPlaces[photoPlace.id] = photoPlace
                }
            }
        }

        mergeNearbyPlaces(
            places: &places,
            photoPlaces: &photoPlaces,
            threshold: config.mergeNearbyThreshold
        )

        return PlaceClusteringResult(
            places: places,
            photoPlaces: photoPlaces
        )
    }

    private static func extractLocationCandidates(from photos: [Photo]) -> [PlaceCandidate] {
        return photos.compactMap { photo in
            guard photo.location.coordinate.latitude != 0 &&
                  photo.location.coordinate.longitude != 0 else {
                return nil
            }

            let dominantScene = photo.embeddings?.scene?.classifications
                .max(by: { $0.confidence < $1.confidence })?.identifier

            return PlaceCandidate(
                photo: photo,
                location: photo.location,
                dominantScene: dominantScene
            )
        }
    }

    private static func findNearbyPlaces(
        location: CLLocation,
        places: [Place],
        radius: Double
    ) -> [Place] {
        return places.filter { place in
            location.distance(from: place.centroid) <= radius
        }
    }

    private static func calculateAffinity(
        candidate: PlaceCandidate,
        place: Place,
        config: PlaceClusteringConfig
    ) -> Float {
        let distance = candidate.location.distance(from: place.centroid)
        let spatialScore = 1.0 - (distance / config.spatialRadiusMeters)

        var sceneScore: Double = 0.0
        if let candidateScene = candidate.dominantScene {
            if place.dominantScenes.contains(candidateScene) {
                sceneScore = 1.0
            } else if !place.dominantScenes.isEmpty {
                sceneScore = 0.3
            }
        }

        let affinity = config.spatialWeight * spatialScore + config.sceneWeight * sceneScore
        return Float(affinity)
    }

    private static func createPlace(from candidate: PlaceCandidate) -> Place {
        return Place(
            centroid: candidate.location,
            radiusMeters: 100.0,
            visitCount: 1,
            photoCount: 1,
            createdAt: candidate.photo.timestamp,
            lastVisitedAt: candidate.photo.timestamp,
            dominantScenes: candidate.dominantScene != nil ? [candidate.dominantScene!] : [],
            confidence: 1.0
        )
    }

    private static func updatePlace(
        placeId: UUID,
        with candidate: PlaceCandidate,
        places: inout [UUID: Place]
    ) {
        guard var place = places[placeId] else { return }

        let oldCentroid = place.centroid
        let newLat = (oldCentroid.coordinate.latitude * Double(place.photoCount) +
                      candidate.location.coordinate.latitude) / Double(place.photoCount + 1)
        let newLon = (oldCentroid.coordinate.longitude * Double(place.photoCount) +
                      candidate.location.coordinate.longitude) / Double(place.photoCount + 1)

        place.centroid = CLLocation(
            latitude: newLat,
            longitude: newLon
        )

        place.photoCount += 1
        place.lastVisitedAt = max(place.lastVisitedAt, candidate.photo.timestamp)

        if let scene = candidate.dominantScene {
            if !place.dominantScenes.contains(scene) {
                place.dominantScenes.append(scene)
            }
        }

        places[placeId] = place
    }

    private static func mergeNearbyPlaces(
        places: inout [UUID: Place],
        photoPlaces: inout [UUID: PhotoPlace],
        threshold: Double
    ) {
        let placeArray = Array(places.values)

        for i in 0..<placeArray.count {
            for j in (i+1)..<placeArray.count {
                let place1 = placeArray[i]
                let place2 = placeArray[j]

                guard places[place1.id] != nil && places[place2.id] != nil else {
                    continue
                }

                let distance = place1.centroid.distance(from: place2.centroid)

                if distance < threshold {
                    let sceneOverlap = calculateSceneOverlap(
                        scenes1: place1.dominantScenes,
                        scenes2: place2.dominantScenes
                    )

                    if sceneOverlap > 0.5 {
                        let (keepId, removeId) = place1.photoCount >= place2.photoCount ?
                            (place1.id, place2.id) : (place2.id, place1.id)

                        for (id, var photoPlace) in photoPlaces {
                            if photoPlace.placeId == removeId {
                                photoPlace.placeId = keepId
                                photoPlaces[id] = photoPlace
                            }
                        }

                        places.removeValue(forKey: removeId)
                    }
                }
            }
        }
    }

    private static func calculateSceneOverlap(
        scenes1: [String],
        scenes2: [String]
    ) -> Double {
        guard !scenes1.isEmpty && !scenes2.isEmpty else {
            return 0.0
        }

        let set1 = Set(scenes1)
        let set2 = Set(scenes2)
        let intersection = set1.intersection(set2)

        return Double(intersection.count) / Double(min(set1.count, set2.count))
    }
}
