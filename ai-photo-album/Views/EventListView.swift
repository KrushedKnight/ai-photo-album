import SwiftUI
import Photos

struct EventListView: View {
    let events: [Event]
    @State private var selectedEvent: Event?

    var body: some View {
        List(events, id: \.id) { event in
            Button(action: {
                selectedEvent = event
            }) {
                EventRowView(event: event)
            }
        }
        .navigationTitle("Events")
        .sheet(item: $selectedEvent) { event in
            EventDetailView(event: event)
        }
    }
}

struct EventRowView: View {
    let event: Event

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eventTitle)
                .font(.headline)

            Text("\(event.photos.count) photos")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text(dateRange)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var eventTitle: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: event.startTime)
    }

    private var dateRange: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short

        if Calendar.current.isDate(event.startTime, inSameDayAs: event.endTime) {
            return formatter.string(from: event.startTime) + " - " + formatter.string(from: event.endTime)
        } else {
            formatter.dateStyle = .short
            return formatter.string(from: event.startTime) + " - " + formatter.string(from: event.endTime)
        }
    }
}
