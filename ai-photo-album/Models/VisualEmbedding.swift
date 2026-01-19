import Foundation

struct VisualEmbedding: Codable {
    let vector: [Float]
    let dimension: Int
    let generatedAt: Date

    init(vector: [Float]) {
        self.vector = vector
        self.dimension = vector.count
        self.generatedAt = Date()
    }
}
