import Foundation
import Vision
import CoreGraphics
import Photos

struct PersonClusteringResult {
    var persons: [UUID: Person]
    var faces: [UUID: FaceInstance]
}

struct PersonClusteringService {
    static func clusterFaces(
        from photos: [Photo],
        config: PersonClusteringConfig = .default
    ) async -> PersonClusteringResult {
        var persons: [UUID: Person] = [:]
        var faces: [UUID: FaceInstance] = [:]

        var allFaceInstances: [FaceInstance] = []

        for photo in photos {
            guard let faceEmbeddings = photo.embeddings?.faces,
                  !faceEmbeddings.isEmpty else {
                continue
            }

            guard let cgImage = await loadCGImage(for: photo) else {
                continue
            }

            let validFaces = faceEmbeddings
                .filter { $0.captureQuality >= config.minFaceQuality }
                .sorted { $0.captureQuality > $1.captureQuality }
                .prefix(config.maxFacesPerPhoto)

            for faceEmbedding in validFaces {
                if let descriptor = await generateFaceDescriptor(
                    faceEmbedding: faceEmbedding,
                    cgImage: cgImage
                ) {
                    let faceInstance = FaceInstance(
                        id: faceEmbedding.id,
                        photoId: photo.id,
                        personId: nil,
                        descriptor: descriptor,
                        boundingBox: faceEmbedding.boundingBox,
                        captureQuality: faceEmbedding.captureQuality,
                        pitch: faceEmbedding.landmarks.pitch,
                        yaw: faceEmbedding.landmarks.yaw,
                        roll: faceEmbedding.landmarks.roll,
                        confidence: 0.0
                    )
                    allFaceInstances.append(faceInstance)
                }
            }
        }

        let sortedFaces = allFaceInstances.sorted { $0.captureQuality > $1.captureQuality }

        for var face in sortedFaces {
            if persons.isEmpty {
                let person = createPerson(with: face)
                face.personId = person.id
                face.confidence = 1.0

                persons[person.id] = person
                faces[face.id] = face
            } else {
                var similarities: [(UUID, Float)] = []

                for (personId, person) in persons {
                    guard let repFaceId = person.representativeFaceId,
                          let repFace = faces[repFaceId] else {
                        continue
                    }

                    let similarity = cosineSimilarity(
                        vector1: face.descriptor,
                        vector2: repFace.descriptor
                    )
                    similarities.append((personId, similarity))
                }

                if let bestMatch = similarities.max(by: { $0.1 < $1.1 }),
                   bestMatch.1 >= config.similarityThreshold {
                    face.personId = bestMatch.0
                    face.confidence = bestMatch.1

                    updatePerson(
                        personId: bestMatch.0,
                        with: face,
                        persons: &persons
                    )

                    faces[face.id] = face
                } else {
                    let person = createPerson(with: face)
                    face.personId = person.id
                    face.confidence = 1.0

                    persons[person.id] = person
                    faces[face.id] = face
                }
            }
        }

        return PersonClusteringResult(
            persons: persons,
            faces: faces
        )
    }

    private static func loadCGImage(for photo: Photo) async -> CGImage? {
        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false

            PHImageManager.default().requestImage(
                for: photo.asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                continuation.resume(returning: image?.cgImage)
            }
        }
    }

    private static func generateFaceDescriptor(
        faceEmbedding: FaceEmbedding,
        cgImage: CGImage
    ) async -> [Float]? {
        return await withCheckedContinuation { continuation in
            let request = VNDetectFaceRectanglesRequest()

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])

                guard let observations = request.results,
                      !observations.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }

                let matchingFace = observations.min(by: { obs1, obs2 in
                    let dist1 = boundingBoxDistance(
                        faceEmbedding.boundingBox,
                        obs1.boundingBox
                    )
                    let dist2 = boundingBoxDistance(
                        faceEmbedding.boundingBox,
                        obs2.boundingBox
                    )
                    return dist1 < dist2
                })

                guard let face = matchingFace else {
                    continuation.resume(returning: nil)
                    return
                }

                generateFaceprintDescriptor(
                    faceObservation: face,
                    cgImage: cgImage
                ) { descriptor in
                    continuation.resume(returning: descriptor)
                }

            } catch {
                continuation.resume(returning: nil)
            }
        }
    }

    private static func generateFaceprintDescriptor(
        faceObservation: VNFaceObservation,
        cgImage: CGImage,
        completion: @escaping ([Float]?) -> Void
    ) {
        let faceprintRequest = VNGenerateFaceprintRequest()

        faceprintRequest.inputFaceObservations = [faceObservation]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([faceprintRequest])

            guard let results = faceprintRequest.results,
                  let faceprint = results.first else {
                completion(nil)
                return
            }

            let descriptor = extractDescriptor(from: faceprint)
            completion(descriptor)

        } catch {
            completion(nil)
        }
    }

    private static func extractDescriptor(from faceprint: VNFaceprint) -> [Float] {
        let data = faceprint.data
        let count = data.count / MemoryLayout<Float>.size
        var floatArray = [Float](repeating: 0, count: count)

        data.withUnsafeBytes { rawBufferPointer in
            let bufferPointer = rawBufferPointer.bindMemory(to: Float.self)
            for i in 0..<count {
                floatArray[i] = bufferPointer[i]
            }
        }

        return floatArray
    }

    private static func boundingBoxDistance(_ box1: CGRect, _ box2: CGRect) -> CGFloat {
        let center1 = CGPoint(x: box1.midX, y: box1.midY)
        let center2 = CGPoint(x: box2.midX, y: box2.midY)

        let dx = center1.x - center2.x
        let dy = center1.y - center2.y

        return sqrt(dx * dx + dy * dy)
    }

    private static func cosineSimilarity(vector1: [Float], vector2: [Float]) -> Float {
        guard vector1.count == vector2.count else {
            return 0.0
        }

        var dotProduct: Float = 0.0
        var magnitude1: Float = 0.0
        var magnitude2: Float = 0.0

        for i in 0..<vector1.count {
            dotProduct += vector1[i] * vector2[i]
            magnitude1 += vector1[i] * vector1[i]
            magnitude2 += vector2[i] * vector2[i]
        }

        magnitude1 = sqrt(magnitude1)
        magnitude2 = sqrt(magnitude2)

        guard magnitude1 > 0 && magnitude2 > 0 else {
            return 0.0
        }

        return dotProduct / (magnitude1 * magnitude2)
    }

    private static func createPerson(with face: FaceInstance) -> Person {
        return Person(
            confidence: face.captureQuality,
            createdAt: Date(),
            lastSeenAt: Date(),
            faceCount: 1,
            photoCount: 1,
            representativeFaceId: face.id
        )
    }

    private static func updatePerson(
        personId: UUID,
        with face: FaceInstance,
        persons: inout [UUID: Person]
    ) {
        guard var person = persons[personId] else { return }

        person.faceCount += 1

        if let repFaceId = person.representativeFaceId,
           let repFace = persons.values.first(where: { $0.representativeFaceId == repFaceId }) {
            if face.captureQuality > repFace.confidence {
                person.representativeFaceId = face.id
            }
        }

        person.lastSeenAt = Date()
        person.confidence = (person.confidence * Float(person.faceCount - 1) + face.confidence) /
                            Float(person.faceCount)

        persons[personId] = person
    }
}
