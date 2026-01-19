import Foundation

struct SceneClassification: Codable {
    let identifier: String
    let confidence: Float

    init(identifier: String, confidence: Float) {
        self.identifier = identifier
        self.confidence = confidence
    }
}

struct SceneEmbedding: Codable {
    let classifications: [SceneClassification]

    var dominantScene: SceneClassification? {
        classifications.first
    }

    init(classifications: [SceneClassification]) {
        self.classifications = classifications.sorted { $0.confidence > $1.confidence }
    }
}
