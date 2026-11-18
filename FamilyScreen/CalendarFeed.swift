import Foundation
import EventKit

struct UpcomingEvent: Identifiable {
    var id: String
    var title: String
    var start: Date
    var allDay: Bool
}

/// Reads the next 7 days from the calendars on this iPad (including iCloud
/// family calendars the user has added).
@MainActor
final class CalendarFeed: ObservableObject {
    @Published var events: [UpcomingEvent] = []
    @Published var denied = false
    private let store = EKEventStore()

    func load() async {
        let granted: Bool
        if #available(iOS 17, *) {
            granted = (try? await store.requestFullAccessToEvents()) ?? false
        } else {
            granted = (try? await store.requestAccess(to: .event)) ?? false
        }
        denied = !granted
        guard granted else { return }
        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.date(byAdding: .day, value: 7, to: start) ?? start
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        events = store.events(matching: predicate)
            .filter { $0.endDate > Date() }
            .sorted { $0.startDate < $1.startDate }
            .prefix(12)
            .map { UpcomingEvent(id: $0.eventIdentifier ?? UUID().uuidString, title: $0.title ?? "",
                                 start: $0.startDate, allDay: $0.isAllDay) }
    }
}
