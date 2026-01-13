import Photos
import SwiftUI
import Combine

class AlbumViewModel: ObservableObject {
    @Published var albums: [PHAssetCollection] = []
    @Published var photos: [Photo] = []

    func loadAlbums() {
        // Fetch albums using the service
        self.albums = fetchAlbums()
    }

    func selectAlbum(_ album: PHAssetCollection) {
        // Import photos using the service
        self.photos = PhotoImporter.importFromAlbum(album)
    }
}
