import CoreLocation
import Photos

struct PhotoImporter {

    static func importFromAlbum(
        _ album: PHAssetCollection
    ) -> [Photo] {

        var photos: [Photo] = []

        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [
            NSSortDescriptor(key: "creationDate", ascending: true)
        ]

        let assets = PHAsset.fetchAssets(in: album, options: fetchOptions)

        assets.enumerateObjects { asset, _, _ in
            guard asset.mediaType == .image else { return }

            let timestamp = asset.creationDate ?? Date()
            let location = asset.location ?? CLLocation(latitude: 0, longitude: 0)

            let photo = Photo(
                id: UUID(),
                timestamp: timestamp,
                location: location,
                phAsset: asset
            )

            photos.append(photo)
        }

        return photos
    }
}
