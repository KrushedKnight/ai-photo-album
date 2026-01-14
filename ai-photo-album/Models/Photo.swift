import CoreLocation
import Foundation
import Photos

struct Photo: Identifiable {
    let id: UUID
    let timestamp: Date
    let location: CLLocation
    let phAsset: PHAsset?
    var vector: [Float]?
}
