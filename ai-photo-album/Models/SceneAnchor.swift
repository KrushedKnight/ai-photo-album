import Foundation

enum SceneCategory: String, Codable {
    case nature
    case urban
    case indoor
    case people
    case food
    case travel
    case event
    case other
}

struct SceneAnchor: Identifiable, Codable {
    let id: UUID
    let identifier: String
    var displayName: String
    var category: SceneCategory
    var photoCount: Int
    let createdAt: Date
    var lastSeenAt: Date

    init(
        id: UUID = UUID(),
        identifier: String,
        displayName: String? = nil,
        category: SceneCategory = .other,
        photoCount: Int = 0,
        createdAt: Date = Date(),
        lastSeenAt: Date = Date()
    ) {
        self.id = id
        self.identifier = identifier
        self.displayName = displayName ?? identifier.capitalized
        self.category = category
        self.photoCount = photoCount
        self.createdAt = createdAt
        self.lastSeenAt = lastSeenAt
    }
}

struct PhotoScene: Identifiable, Codable {
    let id: UUID
    let photoId: UUID
    let sceneId: UUID
    let confidence: Float
    let detectedAt: Date

    init(
        id: UUID = UUID(),
        photoId: UUID,
        sceneId: UUID,
        confidence: Float,
        detectedAt: Date
    ) {
        self.id = id
        self.photoId = photoId
        self.sceneId = sceneId
        self.confidence = confidence
        self.detectedAt = detectedAt
    }
}
