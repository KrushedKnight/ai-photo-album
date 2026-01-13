import Photos
import SwiftUI
import Combine

@MainActor
class AlbumViewModel: ObservableObject {
    @Published var albums: [PHAssetCollection] = []
    @Published var photos: [Photo] = []

    func loadAlbums() {
        self.albums = fetchAlbums()
    }

    func selectAlbum(_ album: PHAssetCollection) {
        // Import photos using the service
        self.photos = PhotoImporter.importFromAlbum(album)
    }
}
