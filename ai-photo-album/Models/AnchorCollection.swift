import Foundation

struct AnchorStats: Codable {
    var totalPhotos: Int = 0
    var facesExtracted: Int = 0
    var facesWithDescriptors: Int = 0
    var personsCreated: Int = 0
    var placesCreated: Int = 0
    var photosWithLocation: Int = 0
    var scenesCreated: Int = 0
    var photosWithScenes: Int = 0
}

struct AnchorCollection: Codable {
    var persons: [UUID: Person] = [:]
    var faces: [UUID: FaceInstance] = [:]
    var places: [UUID: Place] = [:]
    var photoPlaces: [UUID: PhotoPlace] = [:]
    var scenes: [UUID: Scene] = [:]
    var photoScenes: [UUID: PhotoScene] = [:]
    var stats: AnchorStats = AnchorStats()

    init(
        persons: [UUID: Person] = [:],
        faces: [UUID: FaceInstance] = [:],
        places: [UUID: Place] = [:],
        photoPlaces: [UUID: PhotoPlace] = [:],
        scenes: [UUID: Scene] = [:],
        photoScenes: [UUID: PhotoScene] = [:],
        stats: AnchorStats = AnchorStats()
    ) {
        self.persons = persons
        self.faces = faces
        self.places = places
        self.photoPlaces = photoPlaces
        self.scenes = scenes
        self.photoScenes = photoScenes
        self.stats = stats
    }
}
