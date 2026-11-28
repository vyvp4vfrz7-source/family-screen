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

/// Pages the screen can show. Families pick which ones and swipe or auto-rotate between them.
enum ScreenPage: String, CaseIterable, Codable, Identifiable {
    case home, photos, clocks, calendar, birthdays, pinkClock, news
    var id: String { rawValue }
    var title: L {
        switch self {
        case .home: return .pageHome
        case .photos: return .pagePhotos
        case .clocks: return .pageClocks
        case .calendar: return .next2Weeks
        case .birthdays: return .birthdays
        case .pinkClock: return .pagePinkClock
        case .news: return .news
        }
    }

    /// Shown on a new iPad; news stays off until the family adds a feed.
    static let starter: [ScreenPage] = [.home, .photos, .clocks, .calendar, .birthdays, .pinkClock]
}

/// How photos are framed on the screen.
enum FrameStyle: String, CaseIterable, Codable, Identifiable {
    case plain, polaroid, whiteMat, goldChinese
    var id: String { rawValue }
    var title: L {
        switch self {
        case .plain: return .framePlain
        case .polaroid: return .framePolaroid
        case .whiteMat: return .frameMat
        case .goldChinese: return .frameGold
        }
    }
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
    @Published var pages: [ScreenPage] { didSet { save() } }
    @Published var rotatePages: Bool { didSet { save() } }
    @Published var pageSeconds: Int { didSet { save() } }
    @Published var hiddenHomes: [String] { didSet { save() } }
    /// Local identifier of the iCloud Shared Album shown with the family photos ("" = none).
    @Published var sharedAlbumID: String { didSet { save() } }
    @Published var frameStyle: FrameStyle { didSet { save() } }
    @Published var festivalThemes: Bool { didSet { save() } }
    @Published var panZoom: Bool { didSet { save() } }
    /// Grandparents' mode: Cantonese first, fewer buttons, settings behind a long press.
    @Published var grandparentMode: Bool { didSet { save() } }
    /// Lets the adult children change this screen from their own iPad. On by default.
    @Published var allowRemote: Bool { didSet { save() } }
    /// false until the welcome screen has been finished on this iPad.
    @Published var didSetup: Bool { didSet { save() } }
    /// Identifies this iPad's screen to the rest of the family.
    let screenID: String
    /// Called after every change, so a grandparents' screen can tell the family.
    var onChange: (@MainActor () -> Void)?
    private var homeClockPages = false

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
        var pages: [ScreenPage] = ScreenPage.starter
        var rotatePages = true
        var pageSeconds = 60
        var hiddenHomes: [String] = []
        // Added later: optional so older saved settings still load.
        var sharedAlbumID: String?
        var frameStyle: FrameStyle?
        var festivalThemes: Bool?
        var panZoom: Bool?
        /// Set once the Home Clock pages update has run on this iPad.
        var homeClockPages: Bool?
        var grandparentMode: Bool?
        var allowRemote: Bool?
        var screenID: String?
        var didSetup: Bool?
    }

    private let key = "settings.v1"
    private var loading = true

    private init() {
        var s = Stored()
        let hadSaved = UserDefaults.standard.data(forKey: key) != nil
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
        pages = s.pages.isEmpty ? [.home] : s.pages
        rotatePages = s.rotatePages
        pageSeconds = s.pageSeconds
        hiddenHomes = s.hiddenHomes
        sharedAlbumID = s.sharedAlbumID ?? ""
        frameStyle = s.frameStyle ?? .plain
        festivalThemes = s.festivalThemes ?? true
        panZoom = s.panZoom ?? true
        homeClockPages = s.homeClockPages ?? false
        grandparentMode = s.grandparentMode ?? false
        allowRemote = s.allowRemote ?? true
        screenID = s.screenID ?? UUID().uuidString
        // iPads that already had settings skip the welcome screen.
        didSetup = s.didSetup ?? hadSaved
        if !homeClockPages {
            // One-time update: turn on the new pages and show photos large, without a frame.
            pages = ScreenPage.allCases.filter { pages.contains($0) || ScreenPage.starter.contains($0) }
            frameStyle = .plain
            homeClockPages = true
        }
        loading = false
        save()
    }

    private func save() {
        guard !loading else { return }
        let s = Stored(homeName: homeName, language: language, cityA: cityA, cityB: cityB,
                       contactName: contactName, contactAddress: contactAddress, audioOnly: audioOnly,
                       nightFrom: nightFrom, nightTo: nightTo, hourlyChime: hourlyChime,
                       readMessages: readMessages, feeds: feeds, slideSeconds: slideSeconds,
                       pages: pages, rotatePages: rotatePages, pageSeconds: pageSeconds, hiddenHomes: hiddenHomes,
                       sharedAlbumID: sharedAlbumID, frameStyle: frameStyle, festivalThemes: festivalThemes,
                       panZoom: panZoom, homeClockPages: homeClockPages,
                       grandparentMode: grandparentMode, allowRemote: allowRemote, screenID: screenID, didSetup: didSetup)
        if let data = try? JSONEncoder().encode(s) {
            UserDefaults.standard.set(data, forKey: key)
        }
        shareWithExtension()
        if !applyingRemote { onChange?() }
    }

    /// true while settings sent by the family are being applied.
    private var applyingRemote = false

    /// The settings the family can see and change for this screen.
    func screenConfig(changedBy: String) -> ScreenConfig {
        ScreenConfig(screenID: screenID, name: homeName, grandparentMode: grandparentMode, allowRemote: allowRemote,
                     language: language, cityA: cityA, cityB: cityB, contactName: contactName,
                     contactAddress: contactAddress, audioOnly: audioOnly, nightFrom: nightFrom, nightTo: nightTo,
                     hourlyChime: hourlyChime, readMessages: readMessages, pages: pages, rotatePages: rotatePages,
                     pageSeconds: pageSeconds, slideSeconds: slideSeconds, changedAt: Date(), changedBy: changedBy)
    }

    /// Applies settings an adult child changed from their iPad. Grandparents'
    /// mode and the permission itself are only changed on this iPad.
    func apply(_ c: ScreenConfig) {
        applyingRemote = true
        defer { save(); applyingRemote = false }
        language = c.language
        cityA = c.cityA
        cityB = c.cityB
        contactName = c.contactName
        contactAddress = c.contactAddress
        audioOnly = c.audioOnly
        nightFrom = c.nightFrom
        nightTo = c.nightTo
        hourlyChime = c.hourlyChime
        readMessages = c.readMessages
        pages = c.pages.isEmpty ? [.home] : c.pages
        rotatePages = c.rotatePages
        pageSeconds = c.pageSeconds
        slideSeconds = c.slideSeconds
    }

    /// The Share Extension signs photos with this home's name and speaks its language.
    private func shareWithExtension() {
        AppGroup.defaults.set(homeName, forKey: AppGroup.homeNameKey)
        AppGroup.defaults.set(language.rawValue, forKey: AppGroup.languageKey)
    }

    func togglePage(_ page: ScreenPage, on: Bool) {
        if on, !pages.contains(page) {
            pages = ScreenPage.allCases.filter { pages.contains($0) || $0 == page }
        } else if !on, pages.count > 1 {
            pages.removeAll { $0 == page }
        }
    }

    func t(_ key: L) -> String { key.text(language) }

    func isNight(_ date: Date = Date()) -> Bool {
        let h = Calendar.current.component(.hour, from: date)
        if nightFrom == nightTo { return false }
        return nightFrom < nightTo ? (h >= nightFrom && h < nightTo) : (h >= nightFrom || h < nightTo)
    }
}
