import Foundation
import EventKit

struct UpcomingEvent: Identifiable {
    var id: String
    var title: String
    var start: Date
    var allDay: Bool
}

struct Birthday: Identifiable {
    var id: String { name }
    var name: String
    var date: Date   // the next one, today or later
}

/// Reads the calendars on this iPad (including iCloud family calendars the user
/// has added): the next few events, the next two weeks, and the year's birthdays
/// (from Contacts' Birthdays calendar or events named "birthday").
@MainActor
final class CalendarFeed: ObservableObject {
    @Published var events: [UpcomingEvent] = []
    @Published var fortnight: [UpcomingEvent] = []
    @Published var birthdays: [Birthday] = []
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
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let in14 = cal.date(byAdding: .day, value: 14, to: start) ?? start
        let all = store.events(matching: store.predicateForEvents(withStart: start, end: in14, calendars: nil))
            .filter { $0.endDate > Date() }
            .sorted { $0.startDate < $1.startDate }
            .map { UpcomingEvent(id: $0.eventIdentifier ?? UUID().uuidString, title: $0.title ?? "",
                                 start: $0.startDate, allDay: $0.isAllDay) }
        fortnight = all
        let in7 = cal.date(byAdding: .day, value: 7, to: start) ?? start
        events = Array(all.filter { $0.start < in7 }.prefix(12))
        loadBirthdays(from: start)
    }

    private func loadBirthdays(from start: Date) {
        // EventKit searches at most 4 years at once; one year is all we need.
        guard let end = Calendar.current.date(byAdding: .day, value: 366, to: start) else { return }
        let words = ["birthday", "bday", "生日", "urodziny", "जन्मदिन"]
        var seen = Set<String>()
        birthdays = store.events(matching: store.predicateForEvents(withStart: start, end: end, calendars: nil))
            .filter { e in
                e.calendar.type == .birthday || words.contains { (e.title ?? "").lowercased().contains($0) }
            }
            .sorted { $0.startDate < $1.startDate }
            .compactMap { e in
                let name = Self.name(fromBirthdayTitle: e.title ?? "")
                guard !name.isEmpty, seen.insert(name).inserted else { return nil }
                return Birthday(name: name, date: e.startDate)
            }
    }

    /// "Mum’s Birthday" → "Mum", "婆婆生日" → "婆婆".
    static func name(fromBirthdayTitle title: String) -> String {
        var t = title
        for cut in ["’s Birthday", "'s Birthday", "’s birthday", "'s birthday", " Birthday", " birthday", "生日"] {
            t = t.replacingOccurrences(of: cut, with: "")
        }
        t = t.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? title : t
    }
}
