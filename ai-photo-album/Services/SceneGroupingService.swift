import Foundation

struct SceneGroupingResult {
    var scenes: [UUID: SceneAnchor]
    var photoScenes: [UUID: PhotoScene]
}

struct SceneGroupingService {
    static func groupScenes(
        from photos: [Photo],
        config: SceneGroupingConfig = .default
    ) async -> SceneGroupingResult {
        var scenes: [String: SceneAnchor] = [:]
        var photoScenes: [UUID: PhotoScene] = [:]

        for photo in photos {
            guard let sceneEmbedding = photo.embeddings?.scene else {
                continue
            }

            let sortedClassifications = sceneEmbedding.classifications
                .filter { $0.confidence >= config.minConfidence }
                .sorted { $0.confidence > $1.confidence }
                .prefix(config.maxScenesPerPhoto)

            for classification in sortedClassifications {
                let identifier = classification.identifier

                if scenes[identifier] == nil {
                    let category = categorizeScene(identifier: identifier)
                    scenes[identifier] = SceneAnchor(
                        identifier: identifier,
                        category: category,
                        photoCount: 0,
                        createdAt: photo.timestamp,
                        lastSeenAt: photo.timestamp
                    )
                }

                if var scene = scenes[identifier] {
                    scene.photoCount += 1
                    scene.lastSeenAt = max(scene.lastSeenAt, photo.timestamp)
                    scenes[identifier] = scene

                    let photoScene = PhotoScene(
                        photoId: photo.id,
                        sceneId: scene.id,
                        confidence: classification.confidence,
                        detectedAt: photo.timestamp
                    )
                    photoScenes[photoScene.id] = photoScene
                }
            }
        }

        let sceneDict = Dictionary(uniqueKeysWithValues: scenes.values.map { ($0.id, $0) })

        return SceneGroupingResult(
            scenes: sceneDict,
            photoScenes: photoScenes
        )
    }

    private static func categorizeScene(identifier: String) -> SceneCategory {
        let lower = identifier.lowercased()

        if lower.contains("beach") || lower.contains("mountain") ||
           lower.contains("forest") || lower.contains("lake") ||
           lower.contains("ocean") || lower.contains("river") ||
           lower.contains("desert") || lower.contains("sky") ||
           lower.contains("sunset") || lower.contains("nature") {
            return .nature
        }

        if lower.contains("city") || lower.contains("street") ||
           lower.contains("building") || lower.contains("urban") ||
           lower.contains("road") || lower.contains("downtown") {
            return .urban
        }

        if lower.contains("room") || lower.contains("indoor") ||
           lower.contains("kitchen") || lower.contains("bedroom") ||
           lower.contains("office") || lower.contains("home") {
            return .indoor
        }

        if lower.contains("person") || lower.contains("people") ||
           lower.contains("face") || lower.contains("portrait") ||
           lower.contains("group") {
            return .people
        }

        if lower.contains("food") || lower.contains("meal") ||
           lower.contains("restaurant") || lower.contains("dining") ||
           lower.contains("cafe") {
            return .food
        }

        if lower.contains("travel") || lower.contains("vacation") ||
           lower.contains("trip") || lower.contains("tourist") ||
           lower.contains("landmark") {
            return .travel
        }

        if lower.contains("party") || lower.contains("celebration") ||
           lower.contains("wedding") || lower.contains("concert") ||
           lower.contains("festival") {
            return .event
        }

        return .other
    }
}
