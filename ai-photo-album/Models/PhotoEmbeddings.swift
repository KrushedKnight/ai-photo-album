import Foundation

struct PhotoEmbeddings: Codable {
    let visual: VisualEmbedding?
    let faces: [FaceEmbedding]?
    let scene: SceneEmbedding?
    let text: TextEmbedding?

    init(
        visual: VisualEmbedding? = nil,
        faces: [FaceEmbedding]? = nil,
        scene: SceneEmbedding? = nil,
        text: TextEmbedding? = nil
    ) {
        self.visual = visual
        self.faces = faces
        self.scene = scene
        self.text = text
    }
}
