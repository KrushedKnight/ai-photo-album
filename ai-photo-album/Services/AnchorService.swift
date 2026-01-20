import Foundation
internal import _LocationEssentials

struct AnchorService {
    static func generateAnchors(
        from photos: [Photo],
        config: AnchorConfig = .default
    ) async -> AnchorCollection {
        var collection = AnchorCollection()
        collection.stats.totalPhotos = photos.count

        async let personData = PersonClusteringService.clusterFaces(
            from: photos,
            config: config.personConfig
        )
        async let placeData = PlaceClusteringService.clusterPlaces(
            from: photos,
            config: config.placeConfig
        )
        async let sceneData = SceneGroupingService.groupScenes(
            from: photos,
            config: config.sceneConfig
        )

        let (persons, places, scenes) = await (personData, placeData, sceneData)

        collection.persons = persons.persons
        collection.faces = persons.faces
        collection.places = places.places
        collection.photoPlaces = places.photoPlaces
        collection.scenes = scenes.scenes
        collection.photoScenes = scenes.photoScenes

        collection.stats.facesExtracted = persons.faces.count
        collection.stats.facesWithDescriptors = persons.faces.values.filter {
            !$0.descriptor.isEmpty
        }.count
        collection.stats.personsCreated = persons.persons.count

        collection.stats.photosWithLocation = photos.filter {
            $0.location.coordinate.latitude != 0 && $0.location.coordinate.longitude != 0
        }.count
        collection.stats.placesCreated = places.places.count

        collection.stats.photosWithScenes = photos.filter {
            $0.embeddings?.scene != nil
        }.count
        collection.stats.scenesCreated = scenes.scenes.count

        print("📍 Generated anchors:")
        print("   Persons: \(collection.stats.personsCreated)")
        print("   Faces: \(collection.stats.facesExtracted) (\(collection.stats.facesWithDescriptors) with descriptors)")
        print("   Places: \(collection.stats.placesCreated)")
        print("   Scenes: \(collection.stats.scenesCreated)")

        return collection
    }
}
