import Foundation
import CoreLocation

struct City: Codable, Equatable {
    var name: String
    var latitude: Double
    var longitude: Double
    var timeZoneID: String

    var timeZone: TimeZone { TimeZone(identifier: timeZoneID) ?? .current }
    var location: CLLocation { CLLocation(latitude: latitude, longitude: longitude) }

    static let london = City(name: "London", latitude: 51.5072, longitude: -0.1276, timeZoneID: "Europe/London")
    static let hongKong = City(name: "Hong Kong", latitude: 22.3193, longitude: 114.1694, timeZoneID: "Asia/Hong_Kong")

    /// Looks up a city by name with Apple's geocoder (no API key needed).
    static func find(_ query: String) async -> City? {
        guard let mark = try? await CLGeocoder().geocodeAddressString(query).first,
              let loc = mark.location else { return nil }
        return City(name: mark.locality ?? mark.name ?? query,
                    latitude: loc.coordinate.latitude,
                    longitude: loc.coordinate.longitude,
                    timeZoneID: (mark.timeZone ?? .current).identifier)
    }
}

struct NewsFeed: Codable, Equatable, Identifiable {
    var id = UUID()
    var url: String
}

/// Settings for this one iPad. Stored on the device only.
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var homeName: String { didSet { save() } }
    @Published var language: AppLanguage { didSet { save() } }
    @Published var cityA: City { didSet { save() } }
    @Published var cityB: City { didSet { save() } }
    @Published var contactName: String { didSet { save() } }
    @Published var contactAddress: String { didSet { save() } }
    @Published var audioOnly: Bool { didSet { save() } }
    @Published var nightFrom: Int { didSet { save() } }
    @Published var nightTo: Int { didSet { save() } }
    @Published var hourlyChime: Bool { didSet { save() } }
    @Published var readMessages: Bool { didSet { save() } }
    @Published var feeds: [NewsFeed] { didSet { save() } }
    @Published var slideSeconds: Int { didSet { save() } }

    private struct Stored: Codable {
        var homeName = "Home"
        var language = AppLanguage.english
        var cityA = City.london
        var cityB = City.hongKong
        var contactName = ""
        var contactAddress = ""
        var audioOnly = false
        var nightFrom = 22
        var nightTo = 7
        var hourlyChime = false
        var readMessages = true
        var feeds: [NewsFeed] = []
        var slideSeconds = 15
    }

    private let key = "settings.v1"
    private var loading = true

    private init() {
        var s = Stored()
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(Stored.self, from: data) {
            s = decoded
        }
        homeName = s.homeName
        language = s.language
        cityA = s.cityA
        cityB = s.cityB
        contactName = s.contactName
        contactAddress = s.contactAddress
        audioOnly = s.audioOnly
        nightFrom = s.nightFrom
        nightTo = s.nightTo
        hourlyChime = s.hourlyChime
        readMessages = s.readMessages
        feeds = s.feeds
        slideSeconds = s.slideSeconds
        loading = false
    }

    private func save() {
        guard !loading else { return }
        let s = Stored(homeName: homeName, language: language, cityA: cityA, cityB: cityB,
                       contactName: contactName, contactAddress: contactAddress, audioOnly: audioOnly,
                       nightFrom: nightFrom, nightTo: nightTo, hourlyChime: hourlyChime,
                       readMessages: readMessages, feeds: feeds, slideSeconds: slideSeconds)
        if let data = try? JSONEncoder().encode(s) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func t(_ key: L) -> String { key.text(language) }

    func isNight(_ date: Date = Date()) -> Bool {
        let h = Calendar.current.component(.hour, from: date)
        if nightFrom == nightTo { return false }
        return nightFrom < nightTo ? (h >= nightFrom && h < nightTo) : (h >= nightFrom || h < nightTo)
    }
}
