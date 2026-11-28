import UIKit

/// Sample content for simulator screenshots. Only runs when the app is
/// launched with the "-demoData" argument (never on a family's iPad).
enum Demo {
    static var isOn: Bool { ProcessInfo.processInfo.arguments.contains("-demoData") }
    static var landscape: Bool { ProcessInfo.processInfo.arguments.contains("-landscape") }
    /// "-page 3" opens on that page and stops the pages turning, for screenshots.
    static var startPage: Int? {
        let args = ProcessInfo.processInfo.arguments
        guard isOn, let i = args.firstIndex(of: "-page"), i + 1 < args.count else { return nil }
        return Int(args[i + 1])
    }

    static func events() -> [UpcomingEvent] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        func at(_ day: Int, _ hour: Int, _ title: String, allDay: Bool = false) -> UpcomingEvent {
            let d = cal.date(byAdding: .day, value: day, to: today) ?? today
            let start = allDay ? d : (cal.date(bySettingHour: hour, minute: hour == 8 ? 15 : 0, second: 0, of: d) ?? d)
            return UpcomingEvent(id: "demo-\(day)-\(hour)", title: title, start: start, allDay: allDay)
        }
        return [
            at(0, 16, "Swimming"), at(0, 18, "FaceTime Grandma"), at(1, 9, "Dentist"), at(1, 17, "Football practice"),
            at(2, 19, "Piano lesson"), at(4, 0, "Mum's birthday", allDay: true), at(4, 19, "Birthday dinner"),
            at(5, 9, "Parkrun"), at(5, 14, "Tennis"), at(6, 10, "Basketball"), at(8, 8, "School trip"),
            at(10, 18, "Flight to Hong Kong"),
        ]
    }

    static func birthdays() -> [Birthday] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return [("Grandma", 9), ("Mia", 38), ("Grandpa", 71), ("Mum", 124), ("Leo", 187), ("Dad", 262)].map {
            Birthday(name: $0.0, date: cal.date(byAdding: .day, value: $0.1, to: today) ?? today)
        }
    }

    static let headlines: [Headline] = [
        ("Heavy rain warning for the weekend across southern England", "BBC News"),
        ("Hong Kong's new harbourfront park opens to families", "RTHK"),
        ("Scientists spot a rare comet visible before sunrise", "The Guardian"),
        ("Christmas markets open early as crowds return", "Sky News"),
        ("Star Ferry celebrates 125 years crossing Victoria Harbour", "SCMP"),
        ("New trains on the Elizabeth line cut journey times", "Evening Standard"),
        ("Schools trial four-day week in pilot scheme", "BBC News"),
        ("Typhoon season ends quietly for the first time in a decade", "RTHK"),
    ].map { Headline(title: $0.0, source: $0.1, link: URL(string: "https://example.com/")!) }

    @MainActor
    static func seedIfNeeded() {
        guard isOn else { return }
        let s = AppSettings.shared
        s.homeName = "London home"
        s.contactName = "Grandma"
        s.contactAddress = "grandma@example.com"
        s.pages = ScreenPage.allCases
        s.rotatePages = true
        s.pageSeconds = 20
        s.nightFrom = 0
        s.nightTo = 0
        let store = FamilyStore.shared
        guard store.photos.isEmpty else { return }
        store.addPhoto(picture(top: .systemOrange, bottom: .systemPurple, emoji: "👨‍👩‍👧‍👦"), note: "Leo's first day at school!")
        store.addMessage("Video call Sunday 11am?")
        store.addMessage("Grandma, we made dumplings tonight 🥟")
    }

    private static func picture(top: UIColor, bottom: UIColor, emoji: String) -> UIImage {
        let size = CGSize(width: 1200, height: 900)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let colors = [top.cgColor, bottom.cgColor] as CFArray
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                ctx.cgContext.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
            }
            let text = emoji as NSString
            let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 300)]
            let t = text.size(withAttributes: attrs)
            text.draw(at: CGPoint(x: (size.width - t.width) / 2, y: (size.height - t.height) / 2), withAttributes: attrs)
        }
    }

    @MainActor
    static func rotateIfNeeded() {
        guard landscape, #available(iOS 16, *),
              let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight)) { _ in }
    }
}
