import CoreLocation
import Foundation

struct Event: Identifiable {
    let id: UUID
    let startTime: Date
    let endTime: Date
    let centralLocation: CLLocation
    let photos: [Photo]
}
