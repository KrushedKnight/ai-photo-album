import CoreLocation
import Photos
import Vision
import UIKit

struct EmbeddingSuccessCounts {
    var visual: Int = 0
    var faces: Int = 0
    var scene: Int = 0
    var text: Int = 0
}

struct PhotoImporter {

    static func importFromAlbum(
        _ album: PHAssetCollection,
        config: EmbeddingConfig = .default
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
                vector: nil,
                embeddings: nil
            )

            photos.append(photo)
        }

        var successCounts = EmbeddingSuccessCounts()
        await withTaskGroup(of: (Int, PhotoEmbeddings?).self) { group in
            for (index, photo) in photos.enumerated() {
                group.addTask {
                    let embeddings = await generateAllEmbeddings(for: photo.phAsset, config: config)
                    return (index, embeddings)
                }
            }

            for await (index, embeddings) in group {
                photos[index].embeddings = embeddings

                if let embeds = embeddings {
                    if embeds.visual != nil { successCounts.visual += 1 }
                    if let faces = embeds.faces, !faces.isEmpty { successCounts.faces += 1 }
                    if embeds.scene != nil { successCounts.scene += 1 }
                    if embeds.text != nil { successCounts.text += 1 }
                }

                if let vector = embeddings?.visual?.vector {
                    photos[index].vector = vector
                }
            }
        }

        print("🎨 Generated embeddings for \(photos.count) photos:")
        print("   Visual: \(successCounts.visual)")
        print("   Faces: \(successCounts.faces)")
        print("   Scene: \(successCounts.scene)")
        print("   Text: \(successCounts.text)")

        return photos
    }

    private static func generateAllEmbeddings(
        for asset: PHAsset?,
        config: EmbeddingConfig
    ) async -> PhotoEmbeddings? {
        guard let asset = asset else { return nil }

        let image = await loadImage(from: asset)
        guard let image = image, let cgImage = image.cgImage else { return nil }

        async let visual = config.generateVisual ? generateVisualEmbedding(from: cgImage) : nil
        async let faces = config.generateFaces ? generateFaceEmbeddings(from: cgImage, config: config) : nil
        async let scene = config.generateScene ? generateSceneEmbedding(from: cgImage, config: config) : nil
        async let text = config.generateText ? generateTextEmbedding(from: cgImage, config: config) : nil

        return await PhotoEmbeddings(
            visual: visual,
            faces: faces,
            scene: scene,
            text: text
        )
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

    private static func generateVisualEmbedding(from cgImage: CGImage) async -> VisualEmbedding? {
        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
            guard let observation = request.results?.first as? VNFeaturePrintObservation else {
                return nil
            }

            let vector = extractFloatArray(from: observation.data)
            return VisualEmbedding(vector: vector)
        } catch {
            return nil
        }
    }

    private static func generateFaceEmbeddings(
        from cgImage: CGImage,
        config: EmbeddingConfig
    ) async -> [FaceEmbedding]? {
        let request = VNDetectFaceCaptureQualityRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
            guard let observations = request.results as? [VNFaceObservation] else {
                return []
            }

            var faceEmbeddings: [FaceEmbedding] = []

            for observation in observations.prefix(config.maxFaces) {
                guard let quality = observation.faceCaptureQuality,
                      quality >= config.minFaceQuality else {
                    continue
                }

                let landmarks = extractLandmarks(from: observation)

                let faceEmbedding = FaceEmbedding(
                    boundingBox: observation.boundingBox,
                    landmarks: landmarks,
                    descriptor: nil,
                    captureQuality: quality,
                    pitch: observation.pitch?.floatValue,
                    yaw: observation.yaw?.floatValue,
                    roll: observation.roll?.floatValue
                )

                faceEmbeddings.append(faceEmbedding)
            }

            return faceEmbeddings.isEmpty ? [] : faceEmbeddings
        } catch {
            return []
        }
    }

    private static func generateSceneEmbedding(
        from cgImage: CGImage,
        config: EmbeddingConfig
    ) async -> SceneEmbedding? {
        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
            guard let observations = request.results as? [VNClassificationObservation] else {
                return nil
            }

            let classifications = observations
                .filter { $0.confidence >= config.minSceneConfidence }
                .prefix(config.maxSceneClassifications)
                .map { SceneClassification(identifier: $0.identifier, confidence: $0.confidence) }

            return classifications.isEmpty ? nil : SceneEmbedding(classifications: Array(classifications))
        } catch {
            return nil
        }
    }

    private static func generateTextEmbedding(
        from cgImage: CGImage,
        config: EmbeddingConfig
    ) async -> TextEmbedding? {
        let request = VNRecognizeTextRequest()

        switch config.textRecognitionLevel {
        case .fast:
            request.recognitionLevel = .fast
        case .accurate:
            request.recognitionLevel = .accurate
        }

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                return nil
            }

            var textRegions: [TextRegion] = []

            for observation in observations {
                guard let topCandidate = observation.topCandidates(1).first,
                      topCandidate.confidence >= config.minTextConfidence else {
                    continue
                }

                let region = TextRegion(
                    text: topCandidate.string,
                    boundingBox: observation.boundingBox,
                    confidence: topCandidate.confidence,
                    languageCode: nil
                )

                textRegions.append(region)
            }

            return textRegions.isEmpty ? nil : TextEmbedding(regions: textRegions)
        } catch {
            return nil
        }
    }

    private static func extractFloatArray(from data: Data) -> [Float] {
        let count = data.count / MemoryLayout<Float>.size
        var floatArray = [Float](repeating: 0, count: count)

        data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return }
            let floatBuffer = baseAddress.assumingMemoryBound(to: Float.self)
            for i in 0..<count {
                floatArray[i] = floatBuffer[i]
            }
        }

        return floatArray
    }

    private static func extractLandmarks(from observation: VNFaceObservation) -> [FaceLandmark] {
        var landmarks: [FaceLandmark] = []

        if let allPoints = observation.landmarks?.allPoints {
            landmarks.append(FaceLandmark(type: "allPoints", points: allPoints.normalizedPoints))
        }
        if let leftEye = observation.landmarks?.leftEye {
            landmarks.append(FaceLandmark(type: "leftEye", points: leftEye.normalizedPoints))
        }
        if let rightEye = observation.landmarks?.rightEye {
            landmarks.append(FaceLandmark(type: "rightEye", points: rightEye.normalizedPoints))
        }
        if let nose = observation.landmarks?.nose {
            landmarks.append(FaceLandmark(type: "nose", points: nose.normalizedPoints))
        }
        if let noseCrest = observation.landmarks?.noseCrest {
            landmarks.append(FaceLandmark(type: "noseCrest", points: noseCrest.normalizedPoints))
        }
        if let medianLine = observation.landmarks?.medianLine {
            landmarks.append(FaceLandmark(type: "medianLine", points: medianLine.normalizedPoints))
        }
        if let outerLips = observation.landmarks?.outerLips {
            landmarks.append(FaceLandmark(type: "outerLips", points: outerLips.normalizedPoints))
        }
        if let innerLips = observation.landmarks?.innerLips {
            landmarks.append(FaceLandmark(type: "innerLips", points: innerLips.normalizedPoints))
        }
        if let leftEyebrow = observation.landmarks?.leftEyebrow {
            landmarks.append(FaceLandmark(type: "leftEyebrow", points: leftEyebrow.normalizedPoints))
        }
        if let rightEyebrow = observation.landmarks?.rightEyebrow {
            landmarks.append(FaceLandmark(type: "rightEyebrow", points: rightEyebrow.normalizedPoints))
        }
        if let faceContour = observation.landmarks?.faceContour {
            landmarks.append(FaceLandmark(type: "faceContour", points: faceContour.normalizedPoints))
        }

        return landmarks
    }
}
