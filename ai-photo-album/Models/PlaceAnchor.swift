import Foundation
import CoreLocation

struct Place: Identifiable, Codable {
    let id: UUID
    var name: String?
    var centroid: CLLocation
    var radiusMeters: Double
    var visitCount: Int
    var photoCount: Int
    let createdAt: Date
    var lastVisitedAt: Date
    var dominantScenes: [String]
    var confidence: Float

    init(
        id: UUID = UUID(),
        name: String? = nil,
        centroid: CLLocation,
        radiusMeters: Double = 100.0,
        visitCount: Int = 1,
        photoCount: Int = 1,
        createdAt: Date = Date(),
        lastVisitedAt: Date = Date(),
        dominantScenes: [String] = [],
        confidence: Float = 1.0
    ) {
        self.id = id
        self.name = name
        self.centroid = centroid
        self.radiusMeters = radiusMeters
        self.visitCount = visitCount
        self.photoCount = photoCount
        self.createdAt = createdAt
        self.lastVisitedAt = lastVisitedAt
        self.dominantScenes = dominantScenes
        self.confidence = confidence
    }

    enum CodingKeys: String, CodingKey {
        case id, name, radiusMeters, visitCount, photoCount
        case createdAt, lastVisitedAt, dominantScenes, confidence
        case latitude, longitude, altitude, timestamp
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(radiusMeters, forKey: .radiusMeters)
        try container.encode(visitCount, forKey: .visitCount)
        try container.encode(photoCount, forKey: .photoCount)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(lastVisitedAt, forKey: .lastVisitedAt)
        try container.encode(dominantScenes, forKey: .dominantScenes)
        try container.encode(confidence, forKey: .confidence)
        try container.encode(centroid.coordinate.latitude, forKey: .latitude)
        try container.encode(centroid.coordinate.longitude, forKey: .longitude)
        try container.encode(centroid.altitude, forKey: .altitude)
        try container.encode(centroid.timestamp, forKey: .timestamp)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        radiusMeters = try container.decode(Double.self, forKey: .radiusMeters)
        visitCount = try container.decode(Int.self, forKey: .visitCount)
        photoCount = try container.decode(Int.self, forKey: .photoCount)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        lastVisitedAt = try container.decode(Date.self, forKey: .lastVisitedAt)
        dominantScenes = try container.decode([String].self, forKey: .dominantScenes)
        confidence = try container.decode(Float.self, forKey: .confidence)

        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        let altitude = try container.decode(Double.self, forKey: .altitude)
        let timestamp = try container.decodeIfPresent(Date.self, forKey: .timestamp)

        centroid = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            altitude: altitude,
            horizontalAccuracy: 0,
            verticalAccuracy: 0,
            timestamp: timestamp ?? Date()
        )
    }
}

struct PhotoPlace: Identifiable, Codable {
    let id: UUID
    let photoId: UUID
    var placeId: UUID
    let distanceMeters: Double
    let confidence: Float
    let visitedAt: Date

    init(
        id: UUID = UUID(),
        photoId: UUID,
        placeId: UUID,
        distanceMeters: Double,
        confidence: Float,
        visitedAt: Date
    ) {
        self.id = id
        self.photoId = photoId
        self.placeId = placeId
        self.distanceMeters = distanceMeters
        self.confidence = confidence
        self.visitedAt = visitedAt
    }
}
