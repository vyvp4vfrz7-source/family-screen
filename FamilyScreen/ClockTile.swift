import SwiftUI

/// The big top tile of the home page, in the look of the Home Clock dashboard:
/// huge clock and date on the left (with the other home's time below), and
/// this home's weather on the right with a rain / wind / sunrise / sunset strip.
struct ClockTile: View {
    var weather: WeatherNow?
    var onEditNotice: () -> Void
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let w = geo.size.width
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: h * 0.04) {
                    clock(h: h)
                    NoticePill(onEdit: onEditNotice, fontSize: max(h * 0.05, 16))
                        .frame(maxWidth: w * 0.4, alignment: .leading)
                    Spacer(minLength: 0)
                }
                Spacer(minLength: 12)
                currentWeather(h: h)
                    .frame(maxWidth: w * 0.42, alignment: .trailing)
            }
            .padding(.horizontal, h * 0.08)
            .padding(.vertical, h * 0.06)
            .frame(width: w, height: h)
        }
        .background(
            RoundedRectangle(cornerRadius: 26)
                .fill(LinearGradient(colors: [Theme.heroTop, Theme.heroBottom], startPoint: .top, endPoint: .bottom))
        )
        .foregroundColor(.white)
    }

    private func clock(h: CGFloat) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let date = context.date
            let lang = settings.language
            VStack(alignment: .leading, spacing: h * 0.01) {
                HStack(alignment: .lastTextBaseline, spacing: h * 0.02) {
                    Text(Format.time(date, city: settings.cityA, language: lang))
                        .font(.system(size: h * 0.42, weight: .light)).monospacedDigit()
                    Text(Format.string(date, template: "ss", city: settings.cityA, language: lang))
                        .font(.system(size: h * 0.1, weight: .light)).monospacedDigit()
                        .foregroundColor(.white.opacity(0.7))
                }
                .lineLimit(1).minimumScaleFactor(0.5)
                (Text(Format.string(date, template: "EEEE", city: settings.cityA, language: lang)).fontWeight(.semibold)
                 + Text(" " + Format.string(date, template: "dMMMM", city: settings.cityA, language: lang)))
                    .font(.system(size: h * 0.09))
                    .lineLimit(1).minimumScaleFactor(0.6)
                (Text(settings.cityB.name + " ")
                 + Text(Format.time(date, city: settings.cityB, language: lang)).fontWeight(.semibold)
                 + Text(" · " + Format.string(date, template: "EEE", city: settings.cityB, language: lang)))
                    .font(.system(size: h * 0.065))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1).minimumScaleFactor(0.6)
            }
            .fixedSize(horizontal: true, vertical: false)
        }
    }

    private func currentWeather(h: CGFloat) -> some View {
        let w = weather
        return VStack(alignment: .trailing, spacing: h * 0.015) {
            HStack(alignment: .top, spacing: h * 0.03) {
                CuteWeatherIcon(symbol: w?.symbol ?? "cloud.fill", size: h * 0.34,
                                windy: (w?.windKmh ?? 0) >= WeatherWords.windyKmh)
                VStack(alignment: .trailing, spacing: 0) {
                    Text(settings.cityA.name.uppercased())
                        .font(.system(size: h * 0.04, weight: .semibold)).kerning(1.2)
                        .foregroundColor(.white.opacity(0.7))
                    Text(w.map { "\(Int($0.temperature.rounded()))°" } ?? "–")
                        .font(.system(size: h * 0.26, weight: .light))
                }
            }
            if let w = w {
                Text(settings.t(WeatherWords.condition(for: w.symbol)))
                    .font(.system(size: h * 0.075, weight: .semibold))
                Text(detailLine(w))
                    .font(.system(size: h * 0.055))
                    .foregroundColor(.white.opacity(0.85))
            }
            Spacer(minLength: 0)
            strip(h: h)
        }
        .lineLimit(1).minimumScaleFactor(0.6)
    }

    private func detailLine(_ w: WeatherNow) -> String {
        var parts: [String] = []
        if let f = w.feelsLike { parts.append("\(settings.t(.feelsLike)) \(Int(f.rounded()))°") }
        if let hi = w.high { parts.append("\(settings.t(.high)) \(Int(hi.rounded()))°") }
        if let lo = w.low { parts.append("\(settings.t(.low)) \(Int(lo.rounded()))°") }
        return parts.joined(separator: " · ")
    }

    private func strip(h: CGFloat) -> some View {
        let w = weather
        let city = settings.cityA
        let lang = settings.language
        let items: [(L, String)] = [
            (.rain, w?.rainChance.map { "\(Int(($0 * 100).rounded()))%" } ?? "–"),
            (.wind, w?.windKmh.map { "\(Int($0.rounded())) km/h" } ?? "–"),
            (.sunrise, w?.sunrise.map { Format.time($0, city: city, language: lang) } ?? "–"),
            (.sunset, w?.sunset.map { Format.time($0, city: city, language: lang) } ?? "–"),
        ]
        return HStack(spacing: 0) {
            ForEach(items, id: \.0) { item in
                VStack(spacing: h * 0.01) {
                    Text(settings.t(item.0).uppercased())
                        .font(.system(size: h * 0.035, weight: .semibold)).kerning(1)
                        .foregroundColor(.white.opacity(0.6))
                    Text(item.1).font(.system(size: h * 0.065)).monospacedDigit()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, h * 0.03)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(0.18)))
    }
}
