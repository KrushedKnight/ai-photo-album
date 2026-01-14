import Photos
import SwiftUI
import Combine

@MainActor
class AlbumViewModel: ObservableObject {
    @Published var albums: [PHAssetCollection] = []
    @Published var photos: [Photo] = []
    @Published var isProcessing = false
    @Published var events: [Event] = []

    func loadAlbums() {
        self.albums = fetchAlbums()
    }

    func selectAlbum(_ album: PHAssetCollection) async {
        isProcessing = true

        self.photos = await PhotoImporter.importFromAlbum(album)
        print("Imported \(photos.count) photos")

        self.events = await clusterPhotos(photos)
        print("Created \(events.count) events")

        isProcessing = false
    }
}
