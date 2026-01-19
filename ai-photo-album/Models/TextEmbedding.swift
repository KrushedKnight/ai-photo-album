import Foundation
import CoreGraphics

struct TextRegion: Codable {
    let text: String
    let boundingBox: CGRect
    let confidence: Float
    let languageCode: String?

    init(text: String, boundingBox: CGRect, confidence: Float, languageCode: String? = nil) {
        self.text = text
        self.boundingBox = boundingBox
        self.confidence = confidence
        self.languageCode = languageCode
    }
}

struct TextEmbedding: Codable {
    let regions: [TextRegion]

    var fullText: String {
        regions.map { $0.text }.joined(separator: " ")
    }

    init(regions: [TextRegion]) {
        self.regions = regions.sorted { $0.confidence > $1.confidence }
    }
}
