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

struct TwoWeekPage: View {
    @ObservedObject var feed: CalendarFeed
    @ObservedObject private var settings = AppSettings.shared

    private var days: [Date] {
        let start = Calendar.current.startOfDay(for: Date())
        return (0..<14).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: start) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PageTitle(text: settings.t(.next2Weeks))
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

    private func dayCell(_ day: Date) -> some View {
        let cal = Calendar.current
        let today = cal.isDateInToday(day)
        let items = feed.fortnight.filter { cal.isDate($0.start, inSameDayAs: day) }
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(Format.string(day, template: "EEE", language: settings.language))
                    .font(.subheadline.bold()).foregroundColor(today ? Theme.notice : Theme.label)
                Text(Format.string(day, template: "d", language: settings.language))
                    .font(.title2.bold())
            }
            ForEach(items.prefix(4)) { e in
                HStack(alignment: .top, spacing: 4) {
                    if let emoji = EventEmoji.for(e.title) { BouncyEmoji(emoji: emoji) }
                    VStack(alignment: .leading, spacing: 0) {
                        if !e.allDay {
                            Text(Format.time(e.start, language: settings.language))
                                .font(.caption2).foregroundColor(Theme.cool)
                        }
                        Text(e.title).font(.caption.weight(.semibold)).lineLimit(2)
                    }
                }
            }
            if items.count > 4 {
                Text("+\(items.count - 4)").font(.caption).foregroundColor(Theme.label)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 16).fill(today ? Theme.tile : Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(today ? Theme.notice.opacity(0.7) : .clear, lineWidth: 2))
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

struct PageTitle: View {
    var text: String
    var body: some View {
        Text(text).font(.system(size: 30, weight: .bold)).foregroundColor(.white)
    }
}

// MARK: - Birthday countdown

struct BirthdaysPage: View {
    @ObservedObject var feed: CalendarFeed
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PageTitle(text: settings.t(.birthdays))
            if feed.denied {
                message(settings.t(.calendarDenied))
            } else if let next = feed.birthdays.first {
                GeometryReader { geo in
                    let wide = geo.size.width > geo.size.height
                    let rest = Array(feed.birthdays.dropFirst().prefix(wide ? 8 : 6))
                    if wide {
                        HStack(spacing: 12) {
                            hero(next).frame(width: geo.size.width * 0.45)
                            list(rest)
                        }
                    } else {
                        VStack(spacing: 12) {
                            hero(next).frame(height: geo.size.height * 0.45)
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
        ZStack {
            RoundedRectangle(cornerRadius: 22)
                .fill(LinearGradient(colors: [Color(red: 0.45, green: 0.22, blue: 0.42), Color(red: 0.20, green: 0.16, blue: 0.32)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            Balloons()
            VStack(spacing: 10) {
                BouncyEmoji(emoji: "🎂", size: 80)
                Text(b.name).font(.system(size: 44, weight: .bold)).lineLimit(1).minimumScaleFactor(0.5)
                Text(countdown(b.date)).font(.system(size: 34, weight: .semibold)).foregroundColor(Theme.notice)
                Text(Format.string(b.date, template: "EEEEdMMMM", language: settings.language))
                    .font(.title3).foregroundColor(.white.opacity(0.7))
            }
            .padding(20)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private func list(_ items: [Birthday]) -> some View {
        VStack(spacing: 8) {
            ForEach(items) { b in
                HStack {
                    Text("🎈").font(.title2)
                    Text(b.name).font(.title3.weight(.semibold)).lineLimit(1)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(countdown(b.date)).font(.headline).foregroundColor(Theme.notice)
                        Text(Format.string(b.date, template: "dMMM", language: settings.language))
                            .font(.caption).foregroundColor(Theme.label)
                    }
                }
                .padding(.horizontal, 16)
                .frame(maxHeight: 64)
                .background(RoundedRectangle(cornerRadius: 16).fill(Theme.card))
            }
            Spacer(minLength: 0)
        }
    }

    private func countdown(_ date: Date) -> String {
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: date)).day ?? 0
        if days <= 0 { return settings.t(.birthdayToday) }
        if days == 1 { return settings.t(.tomorrow) }
        return String(format: settings.t(.inDays), days)
    }
}

/// Balloons floating up behind the next birthday.
private struct Balloons: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1 / 20, paused: reduceMotion)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                ZStack {
                    ForEach(0..<5) { i in
                        let phase = (t / 9 + Double(i) / 5).truncatingRemainder(dividingBy: 1)
                        Text(["🎈", "🎈", "🎉", "🎈", "✨"][i]).font(.system(size: 34))
                            .position(x: geo.size.width * (0.1 + 0.2 * CGFloat(i)) + 10 * CGFloat(sin(t + Double(i))),
                                      y: geo.size.height * (1.1 - 1.2 * CGFloat(phase)))
                            .opacity(0.55)
                    }
                }
            }
        }
    }
}

// MARK: - Two homes: time and weather

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
                HomesLink(vertical: wide)
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
            VStack(alignment: .leading, spacing: 10) {
                header(context.date)
                ZStack(alignment: .bottom) {
                    LinearGradient(colors: night
                                   ? [Color(red: 0.16, green: 0.18, blue: 0.32), Color(red: 0.27, green: 0.28, blue: 0.42)]
                                   : [Color(red: 0.36, green: 0.55, blue: 0.82), Color(red: 0.62, green: 0.76, blue: 0.92)],
                                   startPoint: .top, endPoint: .bottom)
                    Skyline(seed: seed, night: night)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                    Landmarks(city: city, night: night)
                    weatherInfo
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(18)
                }
                .clipShape(RoundedRectangle(cornerRadius: 22))
            }
            .foregroundColor(.white)
        }
    }

    private func header(_ now: Date) -> some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text(city.name).font(.system(size: 30, weight: .bold)).lineLimit(1).minimumScaleFactor(0.6)
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
    private var weatherInfo: some View {
        if let w = weather {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 14) {
                    CuteWeatherIcon(symbol: w.symbol, size: 120, windy: (w.windKmh ?? 0) >= WeatherWords.windyKmh)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("\(Int(w.temperature.rounded()))°").font(.system(size: 76, weight: .bold))
                        Text(settings.t(WeatherWords.condition(for: w.symbol))).font(.title3.weight(.semibold))
                    }
                }
                Text(details(w)).font(.subheadline).foregroundColor(.white.opacity(0.85))
                HStack(spacing: 8) {
                    ForEach((w.daily ?? []).prefix(3), id: \.date) { day in
                        VStack(spacing: 2) {
                            Text(Format.string(day.date, template: "EEE", city: city, language: settings.language))
                                .font(.caption.bold())
                            CuteWeatherIcon(symbol: day.symbol, size: 38)
                            Text("\(Int(day.high.rounded()))° \(Int(day.low.rounded()))°").font(.caption)
                        }
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.15)))
                    }
                }
            }
        } else {
            Text("–").font(.largeTitle)
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

/// A simple city skyline with lit windows, different for each seed.
private struct Skyline: View {
    let seed: Int
    let night: Bool

    var body: some View {
        Canvas { ctx, size in
            var rng = SeededRandom(seed: UInt64(seed))
            let base = size.height
            var x: CGFloat = -10
            let fill = night ? Color(red: 0.12, green: 0.13, blue: 0.24) : Color(red: 0.30, green: 0.38, blue: 0.55)
            let lit = night ? Color(red: 1, green: 0.85, blue: 0.45) : Color.white.opacity(0.35)
            while x < size.width {
                let w = CGFloat(rng.next(in: 30...70))
                let h = size.height * CGFloat(rng.next(in: 12...38)) / 100
                let rect = CGRect(x: x, y: base - h, width: w, height: h)
                ctx.fill(Path(rect), with: .color(fill))
                var wy = rect.minY + 8
                while wy < base - 10 {
                    var wx = rect.minX + 6
                    while wx < rect.maxX - 8 {
                        if rng.next(in: 0...9) < (night ? 5 : 3) {
                            ctx.fill(Path(CGRect(x: wx, y: wy, width: 5, height: 6)), with: .color(lit))
                        }
                        wx += 10
                    }
                    wy += 12
                }
                x += w + CGFloat(rng.next(in: 2...8))
            }
        }
        .allowsHitTesting(false)
    }
}

/// The strip between the two homes: a dotted flight path with a little
/// plane flying back and forth and a beating heart in the middle.
private struct HomesLink: View {
    var vertical: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20, paused: reduceMotion)) { context in
            let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                let length = vertical ? geo.size.height : geo.size.width
                // 0...1...0 across the strip, slowing at each end.
                let p = 0.5 - 0.5 * cos(t * 0.35)
                let goingForward = sin(t * 0.35) > 0
                let pos = 50 + (length - 100) * CGFloat(p)
                ZStack {
                    Path { path in
                        if vertical {
                            path.move(to: CGPoint(x: geo.size.width / 2, y: 20))
                            path.addLine(to: CGPoint(x: geo.size.width / 2, y: geo.size.height - 20))
                        } else {
                            path.move(to: CGPoint(x: 20, y: geo.size.height / 2))
                            path.addLine(to: CGPoint(x: geo.size.width - 20, y: geo.size.height / 2))
                        }
                    }
                    .stroke(Color.white.opacity(0.3), style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [2, 10]))
                    Image(systemName: "heart.fill")
                        .font(.system(size: 30))
                        .foregroundColor(Color(red: 1, green: 0.48, blue: 0.66))
                        .scaleEffect(CGFloat(1 + 0.12 * max(0, sin(t * 5))))
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    Image(systemName: "airplane")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundColor(.white)
                        // The symbol points right; turn it to face where it is flying.
                        .rotationEffect(.degrees(vertical ? (goingForward ? 90 : -90) : (goingForward ? 0 : 180)))
                        .position(vertical ? CGPoint(x: geo.size.width / 2, y: pos) : CGPoint(x: pos, y: geo.size.height / 2))
                }
            }
        }
        .frame(width: vertical ? 56 : nil, height: vertical ? nil : 56)
        .accessibilityHidden(true)
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
            let ink = night ? Color(red: 0.09, green: 0.1, blue: 0.2) : Color(red: 0.24, green: 0.31, blue: 0.48)
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
                ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(ink), lineWidth: 4)
                for i in 0..<8 {
                    let a = Double(i) * .pi / 4
                    var spoke = Path()
                    spoke.move(to: c)
                    spoke.addLine(to: CGPoint(x: c.x + r * CGFloat(cos(a)), y: c.y + r * CGFloat(sin(a))))
                    ctx.stroke(spoke, with: .color(ink), lineWidth: 1.5)
                }
                var legs = Path()
                legs.move(to: CGPoint(x: c.x - r * 0.5, y: h))
                legs.addLine(to: c)
                legs.addLine(to: CGPoint(x: c.x + r * 0.5, y: h))
                ctx.stroke(legs, with: .color(ink), lineWidth: 4)
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
                ctx.fill(tower, with: .color(ink))
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
