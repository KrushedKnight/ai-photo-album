import Photos
import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = AlbumViewModel()

    var body: some View {
        NavigationView {
            if viewModel.albums.isEmpty {
                Text("Loading albums...")
                    .onAppear {
                        viewModel.loadAlbums()
                    }
            } else {
                List(viewModel.albums, id: \.localIdentifier) { album in
                    Button(album.localizedTitle ?? "Untitled") {
                        viewModel.selectAlbum(album)
                        print("Imported \(viewModel.photos.count) photos")
                    }
                }
                .navigationBarTitle("Select an Album", displayMode: .inline)
            }
        }
    }
}
