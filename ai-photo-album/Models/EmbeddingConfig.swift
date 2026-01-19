import Foundation

struct EmbeddingConfig {
    let generateVisual: Bool
    let generateFaces: Bool
    let generateScene: Bool
    let generateText: Bool

    let minFaceQuality: Float
    let maxFaces: Int

    let minSceneConfidence: Float
    let maxSceneClassifications: Int

    let minTextConfidence: Float
    let textRecognitionLevel: TextRecognitionLevel

    enum TextRecognitionLevel {
        case fast
        case accurate
    }

    static let `default` = EmbeddingConfig(
        generateVisual: true,
        generateFaces: true,
        generateScene: true,
        generateText: false,
        minFaceQuality: 0.3,
        maxFaces: 10,
        minSceneConfidence: 0.1,
        maxSceneClassifications: 5,
        minTextConfidence: 0.5,
        textRecognitionLevel: .fast
    )

    static let full = EmbeddingConfig(
        generateVisual: true,
        generateFaces: true,
        generateScene: true,
        generateText: true,
        minFaceQuality: 0.3,
        maxFaces: 10,
        minSceneConfidence: 0.1,
        maxSceneClassifications: 5,
        minTextConfidence: 0.5,
        textRecognitionLevel: .accurate
    )

    static let visualOnly = EmbeddingConfig(
        generateVisual: true,
        generateFaces: false,
        generateScene: false,
        generateText: false,
        minFaceQuality: 0.3,
        maxFaces: 10,
        minSceneConfidence: 0.1,
        maxSceneClassifications: 5,
        minTextConfidence: 0.5,
        textRecognitionLevel: .fast
    )
}
