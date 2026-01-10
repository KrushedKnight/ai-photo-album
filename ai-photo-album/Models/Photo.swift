import CoreLocation
import Foundation
import Photos

struct Photo {
    let id: UUID
    let timestamp: Date
    let location: CLLocation
    let phAsset: PHAsset?
}
