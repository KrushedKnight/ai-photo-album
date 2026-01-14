import Photos
import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = AlbumViewModel()

    var body: some View {
        NavigationView {
            if viewModel.isProcessing {
                Text("Processing album...")
                    .font(.headline)
            } else if !viewModel.events.isEmpty {
                EventListView(events: viewModel.events)
            } else if viewModel.albums.isEmpty {
                Text("Loading albums...")
                    .onAppear {
                        viewModel.loadAlbums()
                    }
            } else {
                List(viewModel.albums, id: \.localIdentifier) { album in
                    Button(album.localizedTitle ?? "Untitled") {
                        Task {
                            await viewModel.selectAlbum(album)
                        }
                    }
                }
                .navigationBarTitle("Select an Album", displayMode: .inline)
            }
        }
    }
}
