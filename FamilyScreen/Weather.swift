import Foundation
import CoreLocation
#if APPLE_SERVICES
import WeatherKit
#endif

struct WeatherNow: Equatable, Codable {
    var temperature: Double   // °C
    var high: Double?
    var low: Double?
    var symbol: String        // SF Symbol name
}

/// Weather for a city. Uses Apple WeatherKit on iPadOS 16+ when the app is built
/// with APPLE_SERVICES = YES; otherwise Open-Meteo (free, no key, non-commercial).
enum WeatherProvider {
    /// Latest weather, or the last saved reading when offline.
    static func current(for city: City) async -> WeatherNow? {
        let key = "weather.\(city.latitude),\(city.longitude)"
        if let fresh = await fetch(city) {
            if let data = try? JSONEncoder().encode(fresh) { UserDefaults.standard.set(data, forKey: key) }
            return fresh
        }
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WeatherNow.self, from: data)
    }

    private static func fetch(_ city: City) async -> WeatherNow? {
        #if APPLE_SERVICES
        if #available(iOS 16, *) {
            if let w = await weatherKit(city) { return w }
        }
        #endif
        return await openMeteo(city)
    }

    /// True when the Apple Weather mark and legal link must be shown.
    static var usesWeatherKit: Bool {
        #if APPLE_SERVICES
        if #available(iOS 16, *) { return true }
        #endif
        return false
    }

    #if APPLE_SERVICES
    @available(iOS 16, *)
    private static func weatherKit(_ city: City) async -> WeatherNow? {
        guard let result = try? await WeatherService.shared.weather(for: city.location, including: .current, .daily)
        else { return nil }
        let (current, daily) = result
        let today = daily.forecast.first
        return WeatherNow(temperature: current.temperature.converted(to: .celsius).value,
                          high: today?.highTemperature.converted(to: .celsius).value,
                          low: today?.lowTemperature.converted(to: .celsius).value,
                          symbol: current.symbolName)
    }

    @available(iOS 16, *)
    static func legalURL() async -> URL? {
        try? await WeatherService.shared.attribution.legalPageURL
    }
    #endif

    private struct OpenMeteo: Decodable {
        struct Current: Decodable { var temperature_2m: Double; var weather_code: Int; var is_day: Int? }
        struct Daily: Decodable { var temperature_2m_max: [Double]; var temperature_2m_min: [Double] }
        var current: Current
        var daily: Daily
    }

    private static func openMeteo(_ city: City) async -> WeatherNow? {
        var c = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        c.queryItems = [
            .init(name: "latitude", value: String(city.latitude)),
            .init(name: "longitude", value: String(city.longitude)),
            .init(name: "current", value: "temperature_2m,weather_code,is_day"),
            .init(name: "daily", value: "temperature_2m_max,temperature_2m_min"),
            .init(name: "timezone", value: "auto"),
            .init(name: "forecast_days", value: "1"),
        ]
        guard let url = c.url,
              let response = try? await URLSession.shared.data(from: url),
              let r = try? JSONDecoder().decode(OpenMeteo.self, from: response.0) else { return nil }
        return WeatherNow(temperature: r.current.temperature_2m,
                          high: r.daily.temperature_2m_max.first,
                          low: r.daily.temperature_2m_min.first,
                          symbol: symbol(forWMO: r.current.weather_code, day: (r.current.is_day ?? 1) == 1))
    }

    private static func symbol(forWMO code: Int, day: Bool) -> String {
        switch code {
        case 0: return day ? "sun.max.fill" : "moon.stars.fill"
        case 1, 2: return day ? "cloud.sun.fill" : "cloud.moon.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51...57: return "cloud.drizzle.fill"
        case 61...67, 80...82: return "cloud.rain.fill"
        case 71...77, 85, 86: return "cloud.snow.fill"
        case 95...99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }
}
