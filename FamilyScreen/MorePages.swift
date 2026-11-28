import SwiftUI

// Pages from the Home Clock design: pink analog clock, two-week calendar,
// birthday countdown, and the two homes' time and weather.

// MARK: - Pink analog clock

struct PinkClockPage: View {
    var weatherA: WeatherNow?
    @ObservedObject private var settings = AppSettings.shared

    private let pinkTop = Color(red: 0.87, green: 0.72, blue: 0.72)
    private let pinkBottom = Color(red: 0.80, green: 0.64, blue: 0.66)
    private let ink = Color(red: 0.42, green: 0.14, blue: 0.16)

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height) * 0.82
            ZStack {
                LinearGradient(colors: [pinkTop, pinkBottom], startPoint: .topLeading, endPoint: .bottomTrailing)
                TimelineView(.animation(minimumInterval: 1 / 10)) { context in
                    face(side: side, date: context.date)
                }
                footer()
                    .padding(22)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24))
        }
    }

    private func face(side: CGFloat, date: Date) -> some View {
        let parts = Calendar.current.dateComponents([.hour, .minute, .second, .nanosecond], from: date)
        let sec = Double(parts.second ?? 0) + Double(parts.nanosecond ?? 0) / 1e9
        let minute = Double(parts.minute ?? 0) + sec / 60
        let hour = Double((parts.hour ?? 0) % 12) + minute / 60
        let corner = side * 0.24
        return ZStack {
            RoundedRectangle(cornerRadius: corner)
                .fill(LinearGradient(colors: [Color(red: 0.92, green: 0.80, blue: 0.80), Color(red: 0.86, green: 0.72, blue: 0.73)],
                                     startPoint: .top, endPoint: .bottom))
                .shadow(color: .black.opacity(0.18), radius: side * 0.03, x: 0, y: side * 0.02)
                .overlay(RoundedRectangle(cornerRadius: corner).stroke(Color.white.opacity(0.35), lineWidth: 2))
            ForEach(1...12, id: \.self) { n in
                Text("\(n)")
                    .font(.system(size: side * 0.11, weight: .regular, design: .rounded))
                    .foregroundColor(Color(red: 0.80, green: 0.64, blue: 0.66))
                    .shadow(color: .white.opacity(0.6), radius: 0, x: 1, y: 1.5)
                    .shadow(color: .black.opacity(0.18), radius: 0, x: -1, y: -1)
                    .offset(numberOffset(n, side: side))
            }
            hand(width: side * 0.045, length: side * 0.22, tail: 0, angle: hour * 30, color: ink)
            hand(width: side * 0.035, length: side * 0.34, tail: 0, angle: minute * 6, color: ink)
            hand(width: 2.5, length: side * 0.40, tail: side * 0.06, angle: sec * 6,
                 color: Color(red: 0.93, green: 0.30, blue: 0.70))
            Circle().stroke(Color(red: 0.93, green: 0.30, blue: 0.70), lineWidth: 2.5)
                .background(Circle().fill(Color.white))
                .frame(width: side * 0.03, height: side * 0.03)
        }
        .frame(width: side, height: side)
    }

    /// Puts the numbers along the rounded square, not a circle.
    private func numberOffset(_ n: Int, side: CGFloat) -> CGSize {
        let a = Double(n) * .pi / 6
        let x = sin(a), y = -cos(a)
        let r = side * 0.39 / CGFloat(max(abs(x), abs(y)))
        let capped = min(r, side * 0.39 * 1.12)
        return CGSize(width: CGFloat(x) * capped, height: CGFloat(y) * capped)
    }

    private func hand(width: CGFloat, length: CGFloat, tail: CGFloat, angle: Double, color: Color) -> some View {
        Capsule().fill(color)
            .frame(width: width, height: length + tail)
            .offset(y: -(length - tail) / 2)
            .rotationEffect(.degrees(angle))
            .shadow(color: .black.opacity(0.2), radius: 2, y: 2)
    }

    private func footer() -> some View {
        TimelineView(.everyMinute) { ctx in
            VStack {
                Spacer()
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Format.string(ctx.date, template: "EEEEdMMM", language: settings.language))
                            .font(.headline)
                        Text("\(settings.cityB.name) \(Format.time(ctx.date, city: settings.cityB, language: settings.language))")
                            .font(.subheadline)
                    }
                    Spacer()
                    if let w = weatherA {
                        Text("\(settings.cityA.name) \(Int(w.temperature.rounded()))°").font(.headline)
                    }
                }
                .foregroundColor(ink.opacity(0.7))
            }
        }
    }
}

// MARK: - Two-week calendar

/// Two weeks of days, like the Home Clock calendar page: each day shows its
/// weather, then the events as coloured chips, or "Free" when nothing is on.
struct TwoWeekPage: View {
    @ObservedObject var feed: CalendarFeed
    var weather: WeatherNow?
    @ObservedObject private var settings = AppSettings.shared

    private var days: [Date] {
        let start = Calendar.current.startOfDay(for: Date())
        return (0..<14).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: start) }
    }

    private var range: String {
        guard let first = days.first, let last = days.last else { return "" }
        return Format.string(first, template: "dMMM", language: settings.language) + " – "
            + Format.string(last, template: "dMMM", language: settings.language)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PageTitle(key: .next2Weeks, trailing: range)
            if feed.denied {
                Text(settings.t(.calendarDenied)).foregroundColor(Theme.label)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(RoundedRectangle(cornerRadius: 22).fill(Theme.card))
            } else {
                GeometryReader { geo in
                    let columns = geo.size.width > geo.size.height ? 7 : 4
                    let rows = Int(ceil(14 / Double(columns)))
                    let gap: CGFloat = 8
                    let cellH = (geo.size.height - gap * CGFloat(rows - 1)) / CGFloat(rows)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: gap), count: columns), spacing: gap) {
                        ForEach(days, id: \.self) { day in
                            dayCell(day).frame(height: cellH)
                        }
                    }
                }
            }
        }
        .foregroundColor(.white)
    }

    private func forecast(for day: Date) -> DayForecast? {
        guard let w = weather else { return nil }
        if Calendar.current.isDateInToday(day), let hi = w.high, let lo = w.low {
            return DayForecast(date: day, high: hi, low: lo, symbol: w.symbol, rainChance: w.rainChance)
        }
        return w.daily?.first { Calendar.current.isDate($0.date, inSameDayAs: day) }
    }

    private func dayCell(_ day: Date) -> some View {
        let cal = Calendar.current
        let today = cal.isDateInToday(day)
        let items = feed.fortnight.filter { cal.isDate($0.start, inSameDayAs: day) }
        let holidays = Holidays.on(day, cities: [settings.cityA, settings.cityB])
        let weekday = cal.component(.weekday, from: day)   // 1 = Sunday, 7 = Saturday
        let red = !holidays.isEmpty || weekday == 1
        let tint: Color? = red ? DayColors.holiday : (weekday == 7 ? DayColors.saturday : nil)
        let maxItems = 3
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 6) {
                Text(Format.string(day, template: "d", language: settings.language))
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .foregroundColor(tint ?? .white)
                    .lineLimit(1).fixedSize()
                VStack(alignment: .leading, spacing: 0) {
                    Text(today ? settings.t(.today) : Format.string(day, template: "EEE", language: settings.language))
                        .font(.subheadline.bold()).foregroundColor(today ? Theme.notice : (tint ?? .white))
                    Text(Format.string(day, template: "MMM", language: settings.language))
                        .font(.caption).foregroundColor(Theme.label)
                }
                .lineLimit(1).minimumScaleFactor(0.7)
            }
            if let f = forecast(for: day) {
                HStack(spacing: 4) {
                    CuteWeatherIcon(symbol: f.symbol, size: 26)
                    Text("\(Int(f.high.rounded()))°").font(.caption.bold())
                        + Text(" \(Int(f.low.rounded()))°").font(.caption).foregroundColor(Theme.label)
                    Spacer(minLength: 0)
                    if let r = f.rainChance, r >= 0.2 {
                        Text("\(Int((r * 100).rounded()))%").font(.caption.bold()).foregroundColor(Theme.rain)
                    }
                }
                .lineLimit(1).minimumScaleFactor(0.7)
            }
            ForEach(Array(Set(holidays.map { $0.title(settings.language) })).sorted(), id: \.self) { name in
                let flags = holidays.filter { $0.title(settings.language) == name }.map(\.country.flag).joined()
                Text("\(name) \(flags)")
                    .font(.caption.weight(.semibold)).foregroundColor(DayColors.holidayText)
                    .lineLimit(2).minimumScaleFactor(0.8)
            }
            ForEach(items.prefix(maxItems)) { e in eventChip(e) }
            if items.count > maxItems {
                Text("+\(items.count - maxItems)").font(.caption.bold()).foregroundColor(Theme.label)
            }
            if items.isEmpty && holidays.isEmpty {
                Text(settings.t(.freeDay)).font(.caption).foregroundColor(Theme.label)
            }
            Spacer(minLength: 0)
        }
        .padding(9)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ZStack {
            RoundedRectangle(cornerRadius: 16).fill(today ? Theme.tile : Theme.card)
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearGradient(colors: [(tint ?? .clear).opacity(0.28), .clear], startPoint: .top, endPoint: .center))
        })
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(today ? Theme.notice.opacity(0.9) : Color.white.opacity(0.05),
                                                          lineWidth: today ? 3 : 1))
    }

    private func eventChip(_ e: UpcomingEvent) -> some View {
        let color = SoftColors.for(e.title)
        return VStack(alignment: .leading, spacing: 1) {
            if !e.allDay {
                Text(Format.time(e.start, language: settings.language))
                    .font(.caption2.bold()).foregroundColor(Theme.notice)
            }
            HStack(alignment: .top, spacing: 2) {
                Text(e.title).font(.caption.weight(.semibold)).lineLimit(2)
                Spacer(minLength: 0)
                if let emoji = EventEmoji.for(e.title) { BouncyEmoji(emoji: emoji, size: 14) }
            }
        }
        .padding(.vertical, 5).padding(.leading, 9).padding(.trailing, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.32)))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 3).padding(.vertical, 5).padding(.leading, 3)
        }
    }
}

/// Saturday is blue; Sunday and public holidays are red, like a paper calendar.
enum DayColors {
    static let saturday = Color(red: 0.50, green: 0.70, blue: 1.0)
    static let holiday = Color(red: 1.0, green: 0.48, blue: 0.48)
    static let holidayText = Color(red: 1.0, green: 0.70, blue: 0.70)
}

/// A steady colour for a name (event, news source, person), so the same
/// thing keeps the same colour from day to day.
enum SoftColors {
    static let palette: [Color] = [
        Color(red: 0.36, green: 0.56, blue: 0.96), Color(red: 0.30, green: 0.70, blue: 0.46),
        Color(red: 0.95, green: 0.46, blue: 0.42), Color(red: 0.66, green: 0.46, blue: 0.92),
        Color(red: 0.96, green: 0.64, blue: 0.30), Color(red: 0.28, green: 0.74, blue: 0.80),
        Color(red: 0.93, green: 0.48, blue: 0.70),
    ]
    static func `for`(_ text: String) -> Color {
        let sum = text.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return palette[abs(sum) % palette.count]
    }
}

/// Little pictures for common family events, like the old web page.
enum EventEmoji {
    static func `for`(_ title: String) -> String? {
        let t = title.lowercased()
        let table: [([String], String)] = [
            (["birthday", "bday", "生日"], "🎂"), (["swim", "游水", "游泳"], "🏊"),
            (["football", "soccer", "足球"], "⚽️"), (["school", "返學", "上学"], "🎒"),
            (["dinner", "lunch", "食飯", "吃饭", "yum cha", "飲茶"], "🍜"), (["flight", "fly", "機場", "airport"], "✈️"),
            (["doctor", "dentist", "睇醫生", "看医生"], "🩺"), (["party", "派對"], "🎉"),
            (["piano", "music", "鋼琴"], "🎹"), (["holiday", "假期", "trip"], "🏖️"),
        ]
        return table.first { $0.0.contains { t.contains($0) } }?.1
    }
}

struct BouncyEmoji: View {
    let emoji: String
    var size: CGFloat = 16
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var up = false

    var body: some View {
        Text(emoji).font(.system(size: size))
            .offset(y: up ? -3 : 0)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) { up = true }
            }
    }
}

/// Page heading like the Home Clock pages: the title in bold, the English
/// name in light text beside it (when the screen is in another language),
/// and a small note on the right.
struct PageTitle: View {
    var text: String
    var subtitle: String? = nil
    var trailing: String? = nil

    init(text: String, subtitle: String? = nil, trailing: String? = nil) {
        self.text = text; self.subtitle = subtitle; self.trailing = trailing
    }

    init(key: L, trailing: String? = nil) {
        let language = AppSettings.shared.language
        self.init(text: key.text(language), subtitle: language == .english ? nil : key.text(.english), trailing: trailing)
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(text).font(.system(size: 30, weight: .heavy)).foregroundColor(.white)
            if let subtitle = subtitle {
                Text(subtitle).font(.system(size: 20)).foregroundColor(.white.opacity(0.55))
            }
            Spacer(minLength: 8)
            if let trailing = trailing, !trailing.isEmpty {
                Text(trailing).font(.headline).foregroundColor(.white.opacity(0.7))
            }
        }
        .lineLimit(1).minimumScaleFactor(0.7)
    }
}

// MARK: - Birthday countdown

/// Like the Home Clock birthday page: the next birthday large, with a ring
/// counting down the days, and the ones after it in a list.
struct BirthdaysPage: View {
    @ObservedObject var feed: CalendarFeed
    @ObservedObject private var settings = AppSettings.shared
    private let pink = Color(red: 0.98, green: 0.70, blue: 0.80)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PageTitle(key: .birthdays, trailing: Format.string(Date(), template: "EEEEdMMMM", language: settings.language))
            if feed.denied {
                message(settings.t(.calendarDenied))
            } else if let next = feed.birthdays.first {
                GeometryReader { geo in
                    let wide = geo.size.width > geo.size.height
                    let rest = Array(feed.birthdays.dropFirst().prefix(wide ? 6 : 4))
                    if wide {
                        HStack(alignment: .top, spacing: 12) {
                            hero(next).frame(width: geo.size.width * 0.55)
                            list(rest)
                        }
                    } else {
                        VStack(spacing: 12) {
                            hero(next).frame(height: geo.size.height * 0.55)
                            list(rest)
                        }
                    }
                }
            } else {
                message(settings.t(.noBirthdays))
            }
        }
        .foregroundColor(.white)
    }

    private func message(_ text: String) -> some View {
        VStack(spacing: 12) {
            BouncyEmoji(emoji: "🎂", size: 64)
            Text(text).font(.title3).foregroundColor(Theme.label).multilineTextAlignment(.center)
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 22).fill(Theme.card))
    }

    private func hero(_ b: Birthday) -> some View {
        let days = daysUntil(b.date)
        return GeometryReader { geo in
            let ring = min(geo.size.width * 0.42, geo.size.height * 0.5, 300)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 18) {
                    Avatar(name: b.name, size: min(96, geo.size.height * 0.16))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(b.name).font(.system(size: 46, weight: .heavy)).lineLimit(1).minimumScaleFactor(0.5)
                        Text(countdown(b.date)).font(.title3.weight(.semibold)).foregroundColor(pink)
                    }
                }
                Spacer(minLength: 8)
                HStack(spacing: 28) {
                    ZStack {
                        Circle().stroke(Color.white.opacity(0.1), lineWidth: 12)
                        Circle().trim(from: 0, to: CGFloat(max(0.02, 1 - Double(days) / 365)))
                            .stroke(pink, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        if days == 0 {
                            BouncyEmoji(emoji: "🎉", size: ring * 0.4)
                        } else {
                            VStack(spacing: -4) {
                                Text("\(days)").font(.system(size: ring * 0.36, weight: .bold, design: .rounded))
                                    .lineLimit(1).minimumScaleFactor(0.5)
                                Text(settings.t(.daysUnit)).font(.title3).foregroundColor(Theme.label)
                            }
                        }
                    }
                    .frame(width: ring, height: ring)
                    VStack(alignment: .leading, spacing: 8) {
                        BouncyEmoji(emoji: "🎂", size: 64)
                        Text(Format.string(b.date, template: "dMMMM", language: settings.language))
                            .font(.system(size: 28, weight: .bold))
                        Text(Format.string(b.date, template: "EEEE", language: settings.language))
                            .font(.title3).foregroundColor(Theme.label)
                    }
                    .lineLimit(1).minimumScaleFactor(0.6)
                }
                .frame(maxWidth: .infinity)
                Spacer(minLength: 8)
            }
            .padding(26)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(LinearGradient(colors: [Color(red: 0.30, green: 0.18, blue: 0.30), Theme.card],
                                     startPoint: .topLeading, endPoint: .bottom))
        )
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.06)))
    }

    private func list(_ items: [Birthday]) -> some View {
        VStack(spacing: 10) {
            ForEach(items) { b in
                HStack(spacing: 14) {
                    Avatar(name: b.name, size: 52)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(b.name).font(.title3.weight(.bold)).lineLimit(1)
                        Text(Format.string(b.date, template: "EEEdMMMM", language: settings.language))
                            .font(.subheadline).foregroundColor(Theme.label).lineLimit(1)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: -2) {
                        Text("\(daysUntil(b.date))").font(.system(size: 36, weight: .bold, design: .rounded))
                        Text(settings.t(.daysUnit)).font(.caption).foregroundColor(Theme.label)
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 18).fill(Theme.card))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.06)))
            }
            Spacer(minLength: 0)
        }
    }

    private func daysUntil(_ date: Date) -> Int {
        let cal = Calendar.current
        return max(0, cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: date)).day ?? 0)
    }

    private func countdown(_ date: Date) -> String {
        let days = daysUntil(date)
        if days <= 0 { return settings.t(.birthdayToday) }
        if days == 1 { return settings.t(.tomorrow) }
        return String(format: settings.t(.inDays), days)
    }
}

/// A round badge with the first letter of a name, in that name's colour.
struct Avatar: View {
    var name: String
    var size: CGFloat

    var body: some View {
        let color = SoftColors.for(name)
        Text(String(name.prefix(1)).uppercased())
            .font(.system(size: size * 0.45, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .frame(width: size, height: size)
            .background(Circle().fill(LinearGradient(colors: [color.opacity(0.95), color.opacity(0.6)],
                                                     startPoint: .top, endPoint: .bottom)))
            .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 2))
    }
}

// MARK: - Two homes: time and weather

/// Like the Home Clock two-city page: each home has its name and clock on
/// top, and a pale sky card with the weather in front of a cartoon skyline.
struct TwoHomesPage: View {
    var weatherA: WeatherNow?
    var weatherB: WeatherNow?
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width > geo.size.height
            let layout = wide ? AnyLayoutBox.horizontal : AnyLayoutBox.vertical
            layout.stack {
                HomePanel(city: settings.cityA, weather: weatherA, other: nil, seed: 3)
                HomePanel(city: settings.cityB, weather: weatherB, other: settings.cityA, seed: 11)
            }
        }
    }
}

private struct HomePanel: View {
    let city: City
    let weather: WeatherNow?
    let other: City?
    let seed: Int
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        TimelineView(.everyMinute) { context in
            let night = isNight(context.date)
            let ink = night ? Color.white : Color(red: 0.13, green: 0.17, blue: 0.26)
            VStack(alignment: .leading, spacing: 10) {
                header(context.date)
                ZStack(alignment: .bottom) {
                    LinearGradient(colors: night
                                   ? [Color(red: 0.16, green: 0.18, blue: 0.32), Color(red: 0.27, green: 0.28, blue: 0.42)]
                                   : sky,
                                   startPoint: .top, endPoint: .bottom)
                    Skyline(seed: seed, night: night, water: city.timeZoneID == "Asia/Hong_Kong")
                        .frame(maxHeight: .infinity, alignment: .bottom)
                    Landmarks(city: city, night: night)
                    weatherInfo(ink: ink, night: night)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(18)
                }
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(night ? 0.06 : 0.5), lineWidth: 1.5))
            }
            .foregroundColor(.white)
        }
    }

    /// A pale sky, bluer when sunny and greyer when cloudy or wet.
    private var sky: [Color] {
        let s = weather?.symbol ?? ""
        if s.contains("sun") && !s.contains("cloud") {
            return [Color(red: 0.62, green: 0.80, blue: 0.97), Color(red: 0.86, green: 0.93, blue: 0.99)]
        }
        return [Color(red: 0.78, green: 0.84, blue: 0.91), Color(red: 0.90, green: 0.93, blue: 0.96)]
    }

    private func header(_ now: Date) -> some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text(city.name).font(.system(size: 30, weight: .heavy)).lineLimit(1).minimumScaleFactor(0.6)
                if let other = other { Text(difference(from: other, at: now)).font(.subheadline).foregroundColor(Theme.label) }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text(Format.time(now, city: city, language: settings.language))
                    .font(.system(size: 52, weight: .semibold, design: .rounded)).monospacedDigit()
                    .lineLimit(1).minimumScaleFactor(0.5)
                Text(Format.string(now, template: "EEEdMMM", city: city, language: settings.language))
                    .font(.subheadline).foregroundColor(Theme.label)
            }
        }
    }

    @ViewBuilder
    private func weatherInfo(ink: Color, night: Bool) -> some View {
        if let w = weather {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 14) {
                    CuteWeatherIcon(symbol: w.symbol, size: 110, windy: (w.windKmh ?? 0) >= WeatherWords.windyKmh)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("\(Int(w.temperature.rounded()))°").font(.system(size: 84, weight: .bold, design: .rounded))
                        Text(settings.t(WeatherWords.condition(for: w.symbol))).font(.title3.weight(.semibold))
                    }
                }
                Text(details(w)).font(.subheadline.weight(.medium)).opacity(0.8)
                HStack(spacing: 8) {
                    ForEach((w.daily ?? []).prefix(3), id: \.date) { day in
                        VStack(spacing: 2) {
                            Text(Format.string(day.date, template: "EEE", city: city, language: settings.language))
                                .font(.caption.bold())
                            CuteWeatherIcon(symbol: day.symbol, size: 38)
                            Text("\(Int(day.high.rounded()))° \(Int(day.low.rounded()))°").font(.caption.bold())
                            if let r = day.rainChance, r >= 0.2 {
                                Text("\(Int((r * 100).rounded()))%").font(.caption2.bold()).foregroundColor(Theme.rain)
                            }
                        }
                        .frame(minWidth: 64)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(night ? 0.15 : 0.7)))
                    }
                }
            }
            .foregroundColor(ink)
        } else {
            Text("–").font(.largeTitle).foregroundColor(ink)
        }
    }

    private func details(_ w: WeatherNow) -> String {
        var parts: [String] = []
        if let hi = w.high, let lo = w.low {
            parts.append("\(settings.t(.high)) \(Int(hi.rounded()))° · \(settings.t(.low)) \(Int(lo.rounded()))°")
        }
        if let f = w.feelsLike { parts.append("\(settings.t(.feelsLike)) \(Int(f.rounded()))°") }
        if let r = w.rainChance { parts.append("\(settings.t(.rain)) \(Int((r * 100).rounded()))%") }
        if let k = w.windKmh { parts.append("\(settings.t(.wind)) \(Int(k.rounded())) km/h") }
        return parts.joined(separator: " · ")
    }

    private func isNight(_ now: Date) -> Bool {
        if let rise = weather?.sunrise, let set = weather?.sunset, Calendar.current.isDateInToday(rise) {
            return now < rise || now > set
        }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = city.timeZone
        let h = cal.component(.hour, from: now)
        return h < 7 || h >= 19
    }

    private func difference(from other: City, at now: Date) -> String {
        let secs = city.timeZone.secondsFromGMT(for: now) - other.timeZone.secondsFromGMT(for: now)
        let hours = Double(secs) / 3600
        let text = hours == hours.rounded() ? "\(Int(abs(hours)))" : String(format: "%.1f", abs(hours))
        if secs == 0 { return settings.t(.sameTime) }
        return String(format: settings.t(secs > 0 ? .hoursAhead : .hoursBehind), text)
    }
}

/// A cartoon skyline: green hills and pastel buildings by day, dark towers
/// with lit windows at night. Different for each seed.
private struct Skyline: View {
    let seed: Int
    let night: Bool
    var water = false

    private static let pastels: [Color] = [
        Color(red: 0.96, green: 0.76, blue: 0.80), Color(red: 0.99, green: 0.88, blue: 0.60),
        Color(red: 0.66, green: 0.79, blue: 0.96), Color(red: 0.72, green: 0.89, blue: 0.80),
        Color(red: 0.82, green: 0.76, blue: 0.94), Color(red: 0.99, green: 0.80, blue: 0.66),
    ]

    var body: some View {
        Canvas { ctx, size in
            var rng = SeededRandom(seed: UInt64(seed))
            let waterH: CGFloat = water ? size.height * 0.07 : 0
            let base = size.height - waterH
            // Rolling hills behind the town.
            var hills = Path()
            hills.move(to: CGPoint(x: 0, y: base))
            hills.addLine(to: CGPoint(x: 0, y: base - size.height * 0.3))
            hills.addCurve(to: CGPoint(x: size.width, y: base - size.height * 0.26),
                           control1: CGPoint(x: size.width * 0.3, y: base - size.height * 0.45),
                           control2: CGPoint(x: size.width * 0.6, y: base - size.height * 0.12))
            hills.addLine(to: CGPoint(x: size.width, y: base))
            ctx.fill(hills, with: .color(night ? Color(red: 0.12, green: 0.16, blue: 0.22) : Color(red: 0.55, green: 0.76, blue: 0.52)))
            var x: CGFloat = -10
            let lit = night ? Color(red: 1, green: 0.85, blue: 0.45) : Color.white.opacity(0.7)
            while x < size.width {
                let w = CGFloat(rng.next(in: 30...70))
                let h = size.height * CGFloat(rng.next(in: 12...38)) / 100
                let rect = CGRect(x: x, y: base - h, width: w, height: h)
                let fill = night ? Color(red: 0.12, green: 0.13, blue: 0.24) : Self.pastels[rng.next(in: 0...(Self.pastels.count - 1))]
                ctx.fill(Path(roundedRect: rect, cornerSize: CGSize(width: 3, height: 3)), with: .color(fill))
                var wy = rect.minY + 8
                while wy < base - 10 {
                    var wx = rect.minX + 6
                    while wx < rect.maxX - 8 {
                        if rng.next(in: 0...9) < (night ? 5 : 6) {
                            ctx.fill(Path(CGRect(x: wx, y: wy, width: 5, height: 6)), with: .color(lit))
                        }
                        wx += 10
                    }
                    wy += 12
                }
                x += w + CGFloat(rng.next(in: 2...8))
            }
            if water {
                ctx.fill(Path(CGRect(x: 0, y: base, width: size.width, height: waterH)),
                         with: .color(night ? Color(red: 0.10, green: 0.14, blue: 0.28) : Color(red: 0.45, green: 0.70, blue: 0.92)))
            }
        }
        .allowsHitTesting(false)
    }
}

/// Little landmark drawings in front of the skyline for cities we know:
/// a clock tower and big wheel for London, the Peak, a pointed tower and a
/// junk boat for Hong Kong. Other cities just keep the plain skyline.
private struct Landmarks: View {
    let city: City
    let night: Bool

    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            let ink = night ? Color(red: 0.09, green: 0.1, blue: 0.2) : Color(red: 0.86, green: 0.68, blue: 0.38)
            let glow = Color(red: 1, green: 0.85, blue: 0.45)
            switch city.timeZoneID {
            case "Europe/London":
                // Clock tower.
                let tx = w * 0.8, tw = max(w * 0.05, 18), top = h * 0.48
                ctx.fill(Path(CGRect(x: tx, y: top, width: tw, height: h - top)), with: .color(ink))
                var roof = Path()
                roof.move(to: CGPoint(x: tx - 3, y: top))
                roof.addLine(to: CGPoint(x: tx + tw / 2, y: top - tw * 1.4))
                roof.addLine(to: CGPoint(x: tx + tw + 3, y: top))
                ctx.fill(roof, with: .color(ink))
                let face = CGRect(x: tx + tw * 0.15, y: top + tw * 0.4, width: tw * 0.7, height: tw * 0.7)
                ctx.fill(Path(ellipseIn: face), with: .color(night ? glow : .white.opacity(0.8)))
                // Big wheel.
                let r = min(w, h) * 0.17
                let c = CGPoint(x: w * 0.62, y: h - r - 8)
                let wheel = night ? ink : Color.white
                ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(wheel), lineWidth: 4)
                for i in 0..<8 {
                    let a = Double(i) * .pi / 4
                    var spoke = Path()
                    spoke.move(to: c)
                    spoke.addLine(to: CGPoint(x: c.x + r * CGFloat(cos(a)), y: c.y + r * CGFloat(sin(a))))
                    ctx.stroke(spoke, with: .color(wheel), lineWidth: 1.5)
                }
                var legs = Path()
                legs.move(to: CGPoint(x: c.x - r * 0.5, y: h))
                legs.addLine(to: c)
                legs.addLine(to: CGPoint(x: c.x + r * 0.5, y: h))
                ctx.stroke(legs, with: .color(wheel), lineWidth: 4)
            case "Asia/Hong_Kong":
                // The Peak behind the towers.
                var hill = Path()
                hill.move(to: CGPoint(x: w * 0.45, y: h))
                hill.addQuadCurve(to: CGPoint(x: w * 0.75, y: h * 0.62), control: CGPoint(x: w * 0.6, y: h * 0.6))
                hill.addQuadCurve(to: CGPoint(x: w * 1.05, y: h), control: CGPoint(x: w * 0.92, y: h * 0.62))
                ctx.fill(hill, with: .color(night ? Color(red: 0.1, green: 0.16, blue: 0.2) : Color(red: 0.33, green: 0.47, blue: 0.45)))
                // Pointed tower.
                let tx = w * 0.62, tw = max(w * 0.06, 22)
                var tower = Path()
                tower.move(to: CGPoint(x: tx, y: h))
                tower.addLine(to: CGPoint(x: tx + tw * 0.5, y: h * 0.4))
                tower.addLine(to: CGPoint(x: tx + tw, y: h))
                ctx.fill(tower, with: .color(night ? ink : Color(red: 0.36, green: 0.55, blue: 0.86)))
                var mast = Path()
                mast.move(to: CGPoint(x: tx + tw * 0.5, y: h * 0.4))
                mast.addLine(to: CGPoint(x: tx + tw * 0.5, y: h * 0.33))
                ctx.stroke(mast, with: .color(ink), lineWidth: 2)
                // Junk boat with a red sail on the harbour.
                let bx = w * 0.84, by = h - 6
                var hull = Path()
                hull.move(to: CGPoint(x: bx - 26, y: by - 10))
                hull.addLine(to: CGPoint(x: bx + 26, y: by - 10))
                hull.addLine(to: CGPoint(x: bx + 18, y: by))
                hull.addLine(to: CGPoint(x: bx - 18, y: by))
                ctx.fill(hull, with: .color(Color(red: 0.45, green: 0.28, blue: 0.2)))
                var sail = Path()
                sail.move(to: CGPoint(x: bx - 4, y: by - 12))
                sail.addLine(to: CGPoint(x: bx - 4, y: by - 50))
                sail.addQuadCurve(to: CGPoint(x: bx + 16, y: by - 12), control: CGPoint(x: bx + 22, y: by - 40))
                ctx.fill(sail, with: .color(Color(red: 0.85, green: 0.3, blue: 0.28)))
            default:
                break
            }
        }
        .allowsHitTesting(false)
    }
}

private struct SeededRandom {
    var state: UInt64
    init(seed: UInt64) { state = seed &* 6364136223846793005 &+ 1442695040888963407 }
    mutating func next(in range: ClosedRange<Int>) -> Int {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        let span = UInt64(range.upperBound - range.lowerBound + 1)
        return range.lowerBound + Int((state >> 33) % span)
    }
}
