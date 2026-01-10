import Photos
import SwiftUI

@main
struct PhotoAlbumApp: App {
    @State private var accessGranted = false

    var body: some Scene {
        WindowGroup {
            if accessGranted {
                ContentView()
            } else {
                Text("Requesting Photo Library Access...")
                    .font(.headline)
                    .onAppear {
                        Task {
                            let granted = await requestPhotoLibraryAccess()
                            accessGranted = granted
                            if granted {
                                print("Access granted. You can now import photos.")
                            } else {
                                print("Access denied.")
                            }
                        }
                    }
            }
        }
    }
}
