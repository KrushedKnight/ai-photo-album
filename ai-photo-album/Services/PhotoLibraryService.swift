import Photos

func requestPhotoLibraryAccess() async -> Bool {
    let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    return status == .authorized || status == .limited
}

func fetchAlbums() -> [PHAssetCollection] {
    var albums: [PHAssetCollection] = []

    let fetchResult = PHAssetCollection.fetchAssetCollections(
        with: .album,
        subtype: .any,
        options: nil
    )

    fetchResult.enumerateObjects { collection, _, _ in
        albums.append(collection)
    }

    return albums
}
