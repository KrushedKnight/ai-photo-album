import Foundation
import CoreGraphics

struct Person: Identifiable, Codable {
    let id: UUID
    var name: String?
    var confidence: Float
    let createdAt: Date
    var lastSeenAt: Date
    var faceCount: Int
    var photoCount: Int
    var representativeFaceId: UUID?

    init(
        id: UUID = UUID(),
        name: String? = nil,
        confidence: Float = 0.0,
        createdAt: Date = Date(),
        lastSeenAt: Date = Date(),
        faceCount: Int = 0,
        photoCount: Int = 0,
        representativeFaceId: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.confidence = confidence
        self.createdAt = createdAt
        self.lastSeenAt = lastSeenAt
        self.faceCount = faceCount
        self.photoCount = photoCount
        self.representativeFaceId = representativeFaceId
    }
}

struct FaceInstance: Identifiable, Codable {
    let id: UUID
    let photoId: UUID
    var personId: UUID?
    let descriptor: [Float]
    let boundingBox: CGRect
    let captureQuality: Float
    let pitch: Float?
    let yaw: Float?
    let roll: Float?
    var confidence: Float

    init(
        id: UUID = UUID(),
        photoId: UUID,
        personId: UUID? = nil,
        descriptor: [Float],
        boundingBox: CGRect,
        captureQuality: Float,
        pitch: Float? = nil,
        yaw: Float? = nil,
        roll: Float? = nil,
        confidence: Float = 0.0
    ) {
        self.id = id
        self.photoId = photoId
        self.personId = personId
        self.descriptor = descriptor
        self.boundingBox = boundingBox
        self.captureQuality = captureQuality
        self.pitch = pitch
        self.yaw = yaw
        self.roll = roll
        self.confidence = confidence
    }
}
