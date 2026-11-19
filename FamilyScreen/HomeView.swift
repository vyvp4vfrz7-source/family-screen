import SwiftUI

// The home page: a big clock-and-weather card on top, the next 12 hours and
// next 5 days below, and the family photo on the right. A one-line family
// notice sits in the clock card.

enum Theme {
    static let background = Color(red: 0.06, green: 0.07, blue: 0.10)
    static let card = Color(red: 0.10, green: 0.12, blue: 0.16)
    static let tile = Color(red: 0.15, green: 0.18, blue: 0.24)
    static let heroTop = Color(red: 0.30, green: 0.34, blue: 0.43)
    static let heroBottom = Color(red: 0.23, green: 0.26, blue: 0.34)
    static let label = Color.white.opacity(0.55)
    static let notice = Color(red: 1.0, green: 0.80, blue: 0.35)
    static let warm = Color(red: 0.95, green: 0.75, blue: 0.45)
    static let cool = Color(red: 0.55, green: 0.70, blue: 0.95)
    static let rain = Color(red: 0.45, green: 0.70, blue: 1.0)
}

struct HomePage: View {
    var weatherA: WeatherNow?
    var weatherB: WeatherNow?
    var events: [UpcomingEvent]
    var onAddPhoto: () -> Void
    var onEditNotice: () -> Void

    var body: some View {
        GeometryReader { geo in
            let gap: CGFloat = 12
            if geo.size.width > geo.size.height {
                VStack(spacing: gap) {
                    HeroCard(weatherA: weatherA, weatherB: weatherB, events: events, onEditNotice: onEditNotice)
                        .frame(height: geo.size.height * 0.48)
                    HStack(spacing: gap) {
                        VStack(spacing: gap) {
                            HourlyCard(weather: weatherA)
                            DailyCard(weather: weatherA)
                        }
                        PhotoPanel(events: events, onAdd: onAddPhoto)
                            .frame(width: geo.size.width * 0.40)
                    }
                }
            } else {
                VStack(spacing: gap) {
                    HeroCard(weatherA: weatherA, weatherB: weatherB, events: events, onEditNotice: onEditNotice)
                        .frame(height: geo.size.height * 0.30)
                    PhotoPanel(events: events, onAdd: onAddPhoto)
                    HourlyCard(weather: weatherA).frame(height: geo.size.height * 0.17)
                    DailyCard(weather: weatherA).frame(height: geo.size.height * 0.17)
                }
            }
        }
    }
}

// MARK: - Clock and weather

struct HeroCard: View {
    var weatherA: WeatherNow?
    var weatherB: WeatherNow?
    var events: [UpcomingEvent]
    var onEditNotice: () -> Void
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 0) {
                    clock(height: h)
                    Spacer(minLength: 8)
                    NoticePill(onEdit: onEditNotice)
                        .frame(maxWidth: geo.size.width * 0.5, alignment: .leading)
                }
                Spacer(minLength: 0)
                weather(height: h)
            }
            .padding(.horizontal, h * 0.09)
            .padding(.vertical, h * 0.07)
            .frame(width: geo.size.width, height: h)
        }
        .background(
            RoundedRectangle(cornerRadius: 26)
                .fill(LinearGradient(colors: [Theme.heroTop, Theme.heroBottom], startPoint: .top, endPoint: .bottom))
        )
        .foregroundColor(.white)
    }

    private func clock(height h: CGFloat) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let date = context.date
            VStack(alignment: .leading, spacing: h * 0.03) {
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(Format.time(date, city: settings.cityA, language: settings.language))
                        .font(.system(size: h * 0.34, weight: .light)).monospacedDigit()
                        .lineLimit(1).minimumScaleFactor(0.4)
                    Text(Format.string(date, template: "ss", city: settings.cityA, language: settings.language))
                        .font(.system(size: h * 0.10, weight: .light)).monospacedDigit()
                        .foregroundColor(.white.opacity(0.75))
                }
                (Text(Format.string(date, template: "EEEE", city: settings.cityA, language: settings.language)).fontWeight(.semibold)
                 + Text(" " + Format.string(date, template: "dMMMM", city: settings.cityA, language: settings.language))
                    .foregroundColor(.white.opacity(0.8)))
                    .font(.system(size: h * 0.085))
                    .lineLimit(1).minimumScaleFactor(0.6)
                Text(otherCityLine(date))
                    .font(.system(size: h * 0.06)).foregroundColor(.white.opacity(0.8))
                    .lineLimit(1).minimumScaleFactor(0.6)
                if let e = events.first {
                    Label(nextEvent(e), systemImage: "calendar")
                        .font(.system(size: h * 0.05)).foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                }
            }
        }
    }

    private func otherCityLine(_ date: Date) -> String {
        let b = settings.cityB
        var line = "\(b.name)  \(Format.time(date, city: b, language: settings.language)) · "
            + Format.string(date, template: "EEE", city: b, language: settings.language)
        if let w = weatherB { line += " · \(Int(w.temperature.rounded()))°" }
        return line
    }

    private func nextEvent(_ e: UpcomingEvent) -> String {
        let cal = Calendar.current
        let day: String
        if cal.isDateInToday(e.start) { day = settings.t(.today) }
        else if cal.isDateInTomorrow(e.start) { day = settings.t(.tomorrow) }
        else { day = Format.string(e.start, template: "EEE", language: settings.language) }
        let when = e.allDay ? day : "\(day) \(Format.time(e.start, language: settings.language))"
        return "\(settings.t(.nextUp)): \(e.title) · \(when)"
    }

    @ViewBuilder
    private func weather(height h: CGFloat) -> some View {
        VStack(alignment: .trailing, spacing: h * 0.025) {
            HStack(alignment: .center, spacing: 14) {
                CuteWeatherIcon(symbol: weatherA?.symbol ?? "cloud.fill", size: h * 0.32)
                VStack(alignment: .trailing, spacing: 0) {
                    Text(settings.cityA.name.uppercased())
                        .font(.system(size: h * 0.04, weight: .semibold)).kerning(1.5)
                        .foregroundColor(.white.opacity(0.7))
                    Text(weatherA.map { "\(Int($0.temperature.rounded()))°" } ?? "–")
                        .font(.system(size: h * 0.26, weight: .light))
                }
            }
            if let w = weatherA {
                Text(settings.t(WeatherWords.condition(for: w.symbol)))
                    .font(.system(size: h * 0.075, weight: .semibold))
                Text(detailLine(w))
                    .font(.system(size: h * 0.05)).foregroundColor(.white.opacity(0.8))
                Spacer(minLength: 4)
                HStack(spacing: 0) {
                    stat(.rain, w.rainChance.map { "\(Int(($0 * 100).rounded()))%" }, h)
                    stat(.wind, w.windKmh.map { "\(Int($0.rounded())) km/h" }, h)
                    stat(.sunrise, w.sunrise.map { Format.time($0, city: settings.cityA, language: settings.language) }, h)
                    stat(.sunset, w.sunset.map { Format.time($0, city: settings.cityA, language: settings.language) }, h)
                }
                .padding(.vertical, h * 0.035)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(0.18)))
            }
        }
    }

    private func detailLine(_ w: WeatherNow) -> String {
        var parts: [String] = []
        if let f = w.feelsLike { parts.append("\(settings.t(.feelsLike)) \(Int(f.rounded()))°") }
        if let hi = w.high, let lo = w.low {
            parts.append("\(settings.t(.high)) \(Int(hi.rounded()))° \(settings.t(.low)) \(Int(lo.rounded()))°")
        }
        return parts.joined(separator: " · ")
    }

    private func stat(_ key: L, _ value: String?, _ h: CGFloat) -> some View {
        VStack(spacing: 4) {
            Text(settings.t(key).uppercased())
                .font(.system(size: h * 0.035, weight: .semibold)).foregroundColor(.white.opacity(0.6))
            Text(value ?? "–")
                .font(.system(size: h * 0.06, weight: .medium)).monospacedDigit()
        }
        .lineLimit(1).minimumScaleFactor(0.6)
        .frame(width: h * 0.24)
    }
}

/// Turns a weather symbol name into a word like "Cloudy".
enum WeatherWords {
    static func condition(for symbol: String) -> L {
        if symbol.contains("bolt") { return .thunder }
        if symbol.contains("snow") || symbol.contains("sleet") { return .snowy }
        if symbol.contains("drizzle") { return .drizzle }
        if symbol.contains("rain") || symbol.contains("heavyrain") { return .rainy }
        if symbol.contains("fog") || symbol.contains("haze") || symbol.contains("smoke") { return .foggy }
        if symbol.hasPrefix("cloud.sun") || symbol.hasPrefix("cloud.moon") { return .partlyCloudy }
        if symbol.hasPrefix("cloud") { return .cloudy }
        if symbol.hasPrefix("moon") { return .clearNight }
        return .sunny
    }
}

// MARK: - Next 12 hours

struct HourlyCard: View {
    var weather: WeatherNow?
    @ObservedObject private var settings = AppSettings.shared

    private var hours: [HourForecast] { weather?.hourly ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: settings.t(.next12Hours))
            if hours.count < 2 {
                Spacer()
                Text("–").foregroundColor(Theme.label).frame(maxWidth: .infinity)
                Spacer()
            } else {
                GeometryReader { geo in
                    chart(in: geo.size)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 22).fill(Theme.card))
        .foregroundColor(.white)
    }

    private func chart(in size: CGSize) -> some View {
        let temps = hours.map(\.temperature)
        let lo = temps.min() ?? 0, hi = temps.max() ?? 1
        let span = max(hi - lo, 1)
        let column = size.width / CGFloat(hours.count)
        let lineTop = size.height * 0.16, lineBottom = size.height * 0.38
        let point: (Int) -> CGPoint = { i in
            let x = column * (CGFloat(i) + 0.5)
            let y = lineBottom - CGFloat((temps[i] - lo) / span) * (lineBottom - lineTop)
            return CGPoint(x: x, y: y)
        }
        return ZStack(alignment: .topLeading) {
            // Shade the hours that are likely to be wet.
            ForEach(hours.indices, id: \.self) { i in
                if (hours[i].rainChance ?? 0) >= 0.4 {
                    RoundedRectangle(cornerRadius: 8).fill(Theme.rain.opacity(0.12))
                        .frame(width: column - 4, height: size.height)
                        .offset(x: column * CGFloat(i) + 2)
                }
            }
            Path { p in
                p.move(to: point(0))
                for i in 1..<hours.count { p.addLine(to: point(i)) }
            }
            .stroke(LinearGradient(colors: [Theme.warm, Theme.cool], startPoint: .leading, endPoint: .trailing),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            ForEach(hours.indices, id: \.self) { i in
                let pt = point(i)
                Circle().fill(Color.white).frame(width: 7, height: 7).position(pt)
                Text("\(Int(hours[i].temperature.rounded()))°")
                    .font(.system(size: max(size.height * 0.1, 11), weight: .semibold))
                    .position(x: pt.x, y: pt.y - size.height * 0.1)
                VStack(spacing: 3) {
                    CuteWeatherIcon(symbol: hours[i].symbol, size: max(size.height * 0.2, 18))
                    Text(rain(hours[i].rainChance))
                        .font(.system(size: max(size.height * 0.08, 10))).foregroundColor(Theme.rain)
                    Text(hourLabel(hours[i].time))
                        .font(.system(size: max(size.height * 0.08, 10))).foregroundColor(Theme.label)
                }
                .frame(width: column)
                .position(x: pt.x, y: size.height * 0.74)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private func hourLabel(_ time: Date) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = settings.cityA.timeZone
        return String(format: "%02d", cal.component(.hour, from: time))
    }

    private func rain(_ chance: Double?) -> String {
        guard let c = chance, c >= 0.1 else { return " " }
        return "💧\(Int((c * 100).rounded()))%"
    }
}

// MARK: - Next 5 days

struct DailyCard: View {
    var weather: WeatherNow?
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: settings.t(.next5Days))
            HStack(spacing: 10) {
                let days = weather?.daily ?? []
                if days.isEmpty {
                    Text("–").foregroundColor(Theme.label).frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                ForEach(days, id: \.date) { day in
                    tile(day)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 22).fill(Theme.card))
        .foregroundColor(.white)
    }

    private func tile(_ day: DayForecast) -> some View {
        VStack(spacing: 6) {
            Text(Format.string(day.date, template: "EEEE", city: settings.cityA, language: settings.language))
                .font(.headline).lineLimit(1).minimumScaleFactor(0.6)
            CuteWeatherIcon(symbol: day.symbol, size: 44)
            HStack(spacing: 6) {
                Text("\(Int(day.high.rounded()))°").font(.title3.bold())
                Text("\(Int(day.low.rounded()))°").font(.title3).foregroundColor(Theme.label)
            }
            if let r = day.rainChance, r >= 0.1 {
                Text("☂ \(Int((r * 100).rounded()))%").font(.caption).foregroundColor(Theme.rain)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.tile))
    }
}

struct SectionLabel: View {
    var text: String
    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold)).kerning(1.2)
            .foregroundColor(Theme.label)
    }
}

// MARK: - Family notice

/// The family notice is the newest message from any home. Writing a new
/// notice replaces it on every screen in the family.
struct NoticePill: View {
    var onEdit: () -> Void
    @ObservedObject private var store = FamilyStore.shared
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        let notice = store.shownMessages.max { $0.date < $1.date }
        Button(action: onEdit) {
            HStack(spacing: 8) {
                Text("📌")
                Text(notice?.text ?? settings.t(.noticeEmpty))
                    .lineLimit(2).multilineTextAlignment(.leading)
            }
            .font(.title3.weight(.semibold))
            .foregroundColor(notice == nil ? .white.opacity(0.6) : Theme.notice)
            .padding(.horizontal, 18).padding(.vertical, 10)
            .background(Capsule().fill(Color.black.opacity(0.25)))
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let n = notice {
                Button(role: .destructive) { store.deleteMessage(n.id) } label: {
                    Label(settings.t(.clearNotice), systemImage: "trash")
                }
                if n.author != settings.homeName {
                    Button { store.hide(author: n.author) } label: {
                        Label(settings.t(.hidePosts), systemImage: "eye.slash")
                    }
                    Button { store.report(author: n.author, text: n.text, id: n.id) } label: {
                        Label(settings.t(.report), systemImage: "exclamationmark.bubble")
                    }
                }
            }
        }
    }
}

/// Write or clear the family notice. Used as a sheet on iPad and inline on iPhone.
struct NoticeEditor: View {
    var inline = false
    var onDone: () -> Void = {}
    @ObservedObject private var store = FamilyStore.shared
    @ObservedObject private var settings = AppSettings.shared
    @State private var draft = ""

    private var current: FamilyMessage? { store.shownMessages.max { $0.date < $1.date } }

    var body: some View {
        if inline {
            Card(title: settings.t(.notice)) { form }
        } else {
            NavigationView {
                form.padding()
                    .frame(maxHeight: .infinity, alignment: .top)
                    .navigationTitle(settings.t(.notice))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(settings.t(.cancel), action: onDone)
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button(settings.t(.send), action: save)
                                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
            }
            .navigationViewStyle(.stack)
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let n = current {
                Text("📌 \(n.text)").font(.title3.weight(.semibold))
                Text("\(n.author) · \(Format.string(n.date, template: "dMMMjmm", language: settings.language))")
                    .font(.caption).foregroundColor(.secondary)
            }
            Text(settings.t(.noticeHint)).font(.subheadline).foregroundColor(.secondary)
            HStack {
                TextField(settings.t(.notice), text: $draft)
                    .textFieldStyle(.roundedBorder).font(.title3)
                    .submitLabel(.send).onSubmit(save)
                    .onChange(of: draft) { d in if d.count > 80 { draft = String(d.prefix(80)) } }
                if inline {
                    Button(settings.t(.send), action: save).buttonStyle(.borderedProminent)
                }
            }
            if let n = current {
                Button(role: .destructive) {
                    store.deleteMessage(n.id)
                    onDone()
                } label: {
                    Label(settings.t(.clearNotice), systemImage: "trash")
                }
            }
        }
    }

    private func save() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        store.addMessage(text)
        draft = ""
        onDone()
    }
}
