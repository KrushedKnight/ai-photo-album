import CoreLocation
import Photos
import Vision
import UIKit

struct PhotoImporter {

    static func importFromAlbum(
        _ album: PHAssetCollection
    ) async -> [Photo] {

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
                phAsset: asset,
                vector: nil
            )

            photos.append(photo)
        }

        await withTaskGroup(of: (Int, [Float]?).self) { group in
            for (index, photo) in photos.enumerated() {
                group.addTask {
                    let vector = await generateFeatureVector(for: photo.phAsset)
                    return (index, vector)
                }
            }

            for await (index, vector) in group {
                photos[index].vector = vector
            }
        }

        return photos
    }

    private static func generateFeatureVector(for asset: PHAsset?) async -> [Float]? {
        guard let asset = asset else { return nil }

        let image = await loadImage(from: asset)
        guard let image = image else { return nil }

        return await generateFeatureVector(from: image)
    }

    private static func loadImage(from asset: PHAsset) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isSynchronous = false
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 299, height: 299),
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }

    private static func generateFeatureVector(from image: UIImage) async -> [Float]? {
        guard let cgImage = image.cgImage else { return nil }

        let request = VNGenerateImageFeaturePrintRequest()

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
            guard let observation = request.results?.first as? VNFeaturePrintObservation else {
                return nil
            }

            let data = observation.data
            let count = data.count
            var floatArray = [Float](repeating: 0, count: count)

            for i in 0..<count {
                floatArray[i] = data[i].floatValue
            }

            return floatArray
        } catch {
            print("Failed to generate feature vector: \(error)")
            return nil
        }
    }
}
