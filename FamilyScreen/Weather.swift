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
    // Extra detail for the home screen. Optional so older saved readings still load.
    var feelsLike: Double?
    var rainChance: Double?   // 0...1, today
    var windKmh: Double?
    var sunrise: Date?
    var sunset: Date?
    var hourly: [HourForecast]?
    var daily: [DayForecast]?  // starts tomorrow
}

struct HourForecast: Equatable, Codable {
    var time: Date
    var temperature: Double
    var symbol: String
    var rainChance: Double?   // 0...1
}

struct DayForecast: Equatable, Codable {
    var date: Date
    var high: Double
    var low: Double
    var symbol: String
    var rainChance: Double?   // 0...1
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
        guard let result = try? await WeatherService.shared.weather(for: city.location, including: .current, .hourly, .daily)
        else { return nil }
        let (current, hourly, daily) = result
        let today = daily.forecast.first
        let now = Date()
        let hours = hourly.forecast.filter { $0.date > now.addingTimeInterval(-3600) }.prefix(12).map {
            HourForecast(time: $0.date, temperature: $0.temperature.converted(to: .celsius).value,
                         symbol: $0.symbolName, rainChance: $0.precipitationChance)
        }
        let days = daily.forecast.dropFirst().prefix(13).map {
            DayForecast(date: $0.date, high: $0.highTemperature.converted(to: .celsius).value,
                        low: $0.lowTemperature.converted(to: .celsius).value,
                        symbol: $0.symbolName, rainChance: $0.precipitationChance)
        }
        return WeatherNow(temperature: current.temperature.converted(to: .celsius).value,
                          high: today?.highTemperature.converted(to: .celsius).value,
                          low: today?.lowTemperature.converted(to: .celsius).value,
                          symbol: current.symbolName,
                          feelsLike: current.apparentTemperature.converted(to: .celsius).value,
                          rainChance: today?.precipitationChance,
                          windKmh: current.wind.speed.converted(to: .kilometersPerHour).value,
                          sunrise: today?.sun.sunrise, sunset: today?.sun.sunset,
                          hourly: Array(hours), daily: Array(days))
    }

    @available(iOS 16, *)
    static func legalURL() async -> URL? {
        try? await WeatherService.shared.attribution.legalPageURL
    }
    #endif

    private struct OpenMeteo: Decodable {
        struct Current: Decodable {
            var temperature_2m: Double; var weather_code: Int; var is_day: Int?
            var apparent_temperature: Double?; var wind_speed_10m: Double?
        }
        struct Hourly: Decodable {
            var time: [Double]; var temperature_2m: [Double?]; var weather_code: [Int?]
            var precipitation_probability: [Double?]?; var is_day: [Int?]?
        }
        struct Daily: Decodable {
            var time: [Double]
            var temperature_2m_max: [Double?]; var temperature_2m_min: [Double?]
            var weather_code: [Int?]?; var precipitation_probability_max: [Double?]?
            var sunrise: [Double?]?; var sunset: [Double?]?
        }
        var current: Current
        var hourly: Hourly?
        var daily: Daily
    }

    private static func openMeteo(_ city: City) async -> WeatherNow? {
        var c = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        c.queryItems = [
            .init(name: "latitude", value: String(city.latitude)),
            .init(name: "longitude", value: String(city.longitude)),
            .init(name: "current", value: "temperature_2m,apparent_temperature,weather_code,is_day,wind_speed_10m"),
            .init(name: "hourly", value: "temperature_2m,weather_code,precipitation_probability,is_day"),
            .init(name: "daily", value: "temperature_2m_max,temperature_2m_min,weather_code,precipitation_probability_max,sunrise,sunset"),
            .init(name: "timezone", value: "auto"),
            .init(name: "timeformat", value: "unixtime"),
            .init(name: "forecast_days", value: "14"),
        ]
        guard let url = c.url,
              let response = try? await URLSession.shared.data(from: url),
              let r = try? JSONDecoder().decode(OpenMeteo.self, from: response.0) else { return nil }

        let percent: (Double?) -> Double? = { $0.map { $0 / 100 } }
        var hours: [HourForecast] = []
        if let h = r.hourly {
            let start = Date().addingTimeInterval(-3600)
            for i in h.time.indices {
                let time = Date(timeIntervalSince1970: h.time[i])
                guard time > start, hours.count < 12,
                      let temp = h.temperature_2m[safe: i] ?? nil, let code = h.weather_code[safe: i] ?? nil else { continue }
                let day = ((h.is_day?[safe: i] ?? nil) ?? 1) == 1
                hours.append(HourForecast(time: time, temperature: temp, symbol: symbol(forWMO: code, day: day),
                                          rainChance: percent(h.precipitation_probability?[safe: i] ?? nil)))
            }
        }
        let d = r.daily
        var days: [DayForecast] = []
        for i in d.time.indices.dropFirst().prefix(13) {
            guard let hi = d.temperature_2m_max[safe: i] ?? nil, let lo = d.temperature_2m_min[safe: i] ?? nil else { continue }
            let code = (d.weather_code?[safe: i] ?? nil) ?? 3
            days.append(DayForecast(date: Date(timeIntervalSince1970: d.time[i]), high: hi, low: lo,
                                    symbol: symbol(forWMO: code, day: true),
                                    rainChance: percent(d.precipitation_probability_max?[safe: i] ?? nil)))
        }
        let date: (Double??) -> Date? = { v in (v ?? nil).map { Date(timeIntervalSince1970: $0) } }
        return WeatherNow(temperature: r.current.temperature_2m,
                          high: d.temperature_2m_max.first ?? nil,
                          low: d.temperature_2m_min.first ?? nil,
                          symbol: symbol(forWMO: r.current.weather_code, day: (r.current.is_day ?? 1) == 1),
                          feelsLike: r.current.apparent_temperature,
                          rainChance: percent(d.precipitation_probability_max?.first ?? nil),
                          windKmh: r.current.wind_speed_10m,
                          sunrise: date(d.sunrise?.first), sunset: date(d.sunset?.first),
                          hourly: hours, daily: days)
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

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
