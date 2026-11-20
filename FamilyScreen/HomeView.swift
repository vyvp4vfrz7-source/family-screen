import SwiftUI

// The home page: a slim clock, weather and notice bar on top, and a big
// family photo filling the rest of the screen.

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
            let landscape = geo.size.width > geo.size.height
            VStack(spacing: gap) {
                HeroBar(weatherA: weatherA, weatherB: weatherB, showForecast: landscape, onEditNotice: onEditNotice)
                    .frame(height: geo.size.height * (landscape ? 0.25 : 0.17))
                PhotoPanel(events: events, onAdd: onAddPhoto)
                if !landscape {
                    DailyCard(weather: weatherA).frame(height: geo.size.height * 0.2)
                }
            }
        }
    }
}

// MARK: - Slim clock, weather and notice bar

/// One slim bar on top of the home page, so the photo below can be big:
/// clock and date, both homes' weather characters, a 5-day forecast and the
/// yellow post-it notice.
struct HeroBar: View {
    var weatherA: WeatherNow?
    var weatherB: WeatherNow?
    var showForecast = true
    var onEditNotice: () -> Void
    @ObservedObject private var settings = AppSettings.shared
    /// Which home the 5-day forecast shows; it swaps every 10 seconds or on tap.
    @State private var forecastB = false

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            HStack(alignment: .center, spacing: h * 0.14) {
                clock(height: h)
                divider(h)
                cityWeather(settings.cityA, weatherA, height: h, big: true)
                cityWeather(settings.cityB, weatherB, height: h, big: false)
                if showForecast {
                    divider(h)
                    forecast(height: h)
                }
                Spacer(minLength: 0)
                NoticePill(onEdit: onEditNotice, fontSize: max(h * 0.13, 18))
                    .frame(maxWidth: geo.size.width * (showForecast ? 0.2 : 0.3))
            }
            .padding(.horizontal, h * 0.16)
            .frame(width: geo.size.width, height: h)
        }
        .background(
            RoundedRectangle(cornerRadius: 26)
                .fill(LinearGradient(colors: [Theme.heroTop, Theme.heroBottom], startPoint: .top, endPoint: .bottom))
        )
        .foregroundColor(.white)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                withAnimation(.easeInOut(duration: 0.5)) { forecastB.toggle() }
            }
        }
    }

    private func divider(_ h: CGFloat) -> some View {
        Rectangle().fill(Color.white.opacity(0.2)).frame(width: 2, height: h * 0.65)
    }

    private func clock(height h: CGFloat) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let date = context.date
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(Format.time(date, city: settings.cityA, language: settings.language))
                        .font(.system(size: h * 0.48, weight: .light)).monospacedDigit()
                    Text(Format.string(date, template: "ss", city: settings.cityA, language: settings.language))
                        .font(.system(size: h * 0.15, weight: .light)).monospacedDigit()
                        .foregroundColor(.white.opacity(0.7))
                }
                .lineLimit(1).minimumScaleFactor(0.5)
                (Text(Format.string(date, template: "EEEE", city: settings.cityA, language: settings.language)).fontWeight(.semibold)
                 + Text(" " + Format.string(date, template: "dMMMM", city: settings.cityA, language: settings.language)))
                    .font(.system(size: h * 0.14))
                    .lineLimit(1).minimumScaleFactor(0.6)
            }
            .fixedSize(horizontal: true, vertical: false)
        }
    }

    private func cityWeather(_ city: City, _ w: WeatherNow?, height h: CGFloat, big: Bool) -> some View {
        HStack(spacing: h * 0.06) {
            CuteWeatherIcon(symbol: w?.symbol ?? "cloud.fill", size: h * (big ? 0.62 : 0.46),
                            windy: (w?.windKmh ?? 0) >= WeatherWords.windyKmh)
            VStack(alignment: .leading, spacing: 0) {
                Text(city.name.uppercased())
                    .font(.system(size: h * 0.09, weight: .semibold)).kerning(1.2)
                    .foregroundColor(.white.opacity(0.7))
                Text(w.map { "\(Int($0.temperature.rounded()))°" } ?? "–")
                    .font(.system(size: h * (big ? 0.36 : 0.26), weight: .light))
                if big, let w = w {
                    Text(settings.t(WeatherWords.condition(for: w.symbol)))
                        .font(.system(size: h * 0.1, weight: .semibold))
                } else {
                    TimelineView(.periodic(from: .now, by: 30)) { context in
                        Text(Format.time(context.date, city: city, language: settings.language))
                            .font(.system(size: h * 0.09)).foregroundColor(.white.opacity(0.8))
                    }
                }
            }
            .lineLimit(1).minimumScaleFactor(0.6)
        }
        .fixedSize()
    }

    private func forecast(height h: CGFloat) -> some View {
        let city = forecastB ? settings.cityB : settings.cityA
        let days = Array(((forecastB ? weatherB : weatherA)?.daily ?? []).prefix(5))
        return VStack(alignment: .leading, spacing: h * 0.02) {
            Text("\(city.name) · \(settings.t(.next5Days))".uppercased())
                .font(.system(size: h * 0.075, weight: .semibold)).kerning(1)
                .foregroundColor(.white.opacity(0.7)).lineLimit(1)
            HStack(spacing: h * 0.04) {
                if days.isEmpty { Text("–").foregroundColor(Theme.label) }
                ForEach(days, id: \.date) { day in
                    VStack(spacing: 0) {
                        Text(Format.string(day.date, template: "EEE", city: city, language: settings.language))
                            .font(.system(size: h * 0.09, weight: .semibold))
                        CuteWeatherIcon(symbol: day.symbol, size: h * 0.3)
                        HStack(spacing: 3) {
                            Text("\(Int(day.high.rounded()))°").fontWeight(.bold)
                            Text("\(Int(day.low.rounded()))°").foregroundColor(.white.opacity(0.6))
                        }
                        .font(.system(size: h * 0.09))
                    }
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .frame(width: h * 0.42)
                }
            }
        }
        .id(forecastB)
        .transition(.opacity)
        .contentShape(Rectangle())
        .onTapGesture { withAnimation { forecastB.toggle() } }
    }
}

/// Turns a weather symbol name into a word like "Cloudy".
enum WeatherWords {
    /// Wind speed from which the wind friend replaces the usual character.
    static let windyKmh: Double = 35

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

/// The family notice is the newest message from any home, shown as a yellow
/// post-it note. Writing a new notice replaces it on every screen in the family.
struct NoticePill: View {
    var onEdit: () -> Void
    var fontSize: CGFloat = 26
    @ObservedObject private var store = FamilyStore.shared
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        let notice = store.shownMessages.max { $0.date < $1.date }
        Button(action: onEdit) {
            Text(notice?.text ?? settings.t(.noticeEmpty))
                .font(.custom("Noteworthy-Bold", size: fontSize))
                .lineLimit(3).minimumScaleFactor(0.6).multilineTextAlignment(.leading)
                .foregroundColor(Color(red: 0.3, green: 0.24, blue: 0.08).opacity(notice == nil ? 0.5 : 1))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, fontSize * 0.8).padding(.top, fontSize * 0.7).padding(.bottom, fontSize * 0.6)
                .background(PostItPaper())
                .overlay(alignment: .top) {
                    // A strip of tape holding the note up.
                    Rectangle().fill(Color.white.opacity(0.5))
                        .frame(width: fontSize * 3, height: fontSize * 0.75)
                        .rotationEffect(.degrees(3))
                        .offset(y: -fontSize * 0.35)
                }
                .rotationEffect(.degrees(-2))
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

/// Yellow post-it paper with a soft shadow and a folded-up corner.
private struct PostItPaper: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let f = min(w, h) * 0.2
            ZStack {
                Path { p in
                    p.addLines([.zero, CGPoint(x: w, y: 0), CGPoint(x: w, y: h - f), CGPoint(x: w - f, y: h), CGPoint(x: 0, y: h)])
                    p.closeSubpath()
                }
                .fill(LinearGradient(colors: [Color(red: 1, green: 0.93, blue: 0.5), Color(red: 1, green: 0.88, blue: 0.4)],
                                     startPoint: .top, endPoint: .bottom))
                .shadow(color: .black.opacity(0.3), radius: 6, x: 3, y: 5)
                Path { p in
                    p.addLines([CGPoint(x: w, y: h - f), CGPoint(x: w - f, y: h - f), CGPoint(x: w - f, y: h)])
                    p.closeSubpath()
                }
                .fill(Color(red: 0.88, green: 0.76, blue: 0.3))
            }
        }
    }
}
