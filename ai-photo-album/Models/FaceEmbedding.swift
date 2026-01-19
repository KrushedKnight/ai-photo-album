import Foundation
import CoreGraphics

struct FaceLandmark: Codable {
    let type: String
    let points: [CGPoint]
}

struct FaceEmbedding: Codable {
    let id: UUID
    let boundingBox: CGRect
    let landmarks: [FaceLandmark]
    let descriptor: [Float]?
    let captureQuality: Float
    let pitch: Float?
    let yaw: Float?
    let roll: Float?

    init(
        boundingBox: CGRect,
        landmarks: [FaceLandmark],
        descriptor: [Float]?,
        captureQuality: Float,
        pitch: Float? = nil,
        yaw: Float? = nil,
        roll: Float? = nil
    ) {
        self.id = UUID()
        self.boundingBox = boundingBox
        self.landmarks = landmarks
        self.descriptor = descriptor
        self.captureQuality = captureQuality
        self.pitch = pitch
        self.yaw = yaw
        self.roll = roll
    }
}
