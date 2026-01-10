import CoreLocation
import Foundation

struct Event {
    let id: UUID
    let startTime: Date
    let endTime: Date
    let centralLocation: CLLocation
    let photos: [Photo]

}
