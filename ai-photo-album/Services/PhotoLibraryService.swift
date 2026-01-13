import Photos

func requestPhotoLibraryAccess() async -> Bool {
    let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    return status == .authorized || status == .limited
}

func fetchAlbums() -> [PHAssetCollection] {
    var albums: [PHAssetCollection] = []

    let userAlbums = PHAssetCollection.fetchAssetCollections(
        with: .album,
        subtype: .any,
        options: nil
    )

    userAlbums.enumerateObjects { collection, _, _ in
        albums.append(collection)
    }

    let smartAlbums = PHAssetCollection.fetchAssetCollections(
        with: .smartAlbum,
        subtype: .any,
        options: nil
    )

    smartAlbums.enumerateObjects { collection, _, _ in
        albums.append(collection)
    }

    return albums
}
