import SwiftUI

struct DashboardView: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var store = FamilyStore.shared
    @ObservedObject private var network = NetworkStatus.shared
    @StateObject private var calendar = CalendarFeed()
    @StateObject private var news = NewsFeedReader()

    @State private var weatherA: WeatherNow?
    @State private var weatherB: WeatherNow?
    @State private var now = Date()
    @State private var wakeUntil = Date.distantPast
    @State private var lastChimeHour = -1
    @State private var sheet: SheetRoute?
    @State private var pageIndex = 0

    enum SheetRoute: Identifiable {
        case settings, addPhoto, article(URL)
        var id: String {
            switch self {
            case .settings: return "settings"
            case .addPhoto: return "addPhoto"
            case .article(let url): return url.absoluteString
            }
        }
    }

    private var isNight: Bool { settings.isNight(now) && now > wakeUntil }

    var body: some View {
        ZStack {
            Color(red: 0.07, green: 0.06, blue: 0.08).ignoresSafeArea()
            if isNight {
                NightClock()
                    .contentShape(Rectangle())
                    .onTapGesture { wakeUntil = Date().addingTimeInterval(120); now = Date() }
            } else {
                dashboard
            }
            if !network.online && !isNight {
                VStack {
                    Label(settings.t(.offline), systemImage: "wifi.slash")
                        .font(.subheadline.bold())
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Capsule().fill(Color.orange.opacity(0.85)))
                        .padding(.top, 20)
                    Spacer()
                }
                .allowsHitTesting(false)
            }
            if let arrival = store.arrival, !isNight {
                ArrivalBanner(arrival: arrival)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut, value: store.arrival)
        .sheet(item: $sheet) { route in
            switch route {
            case .settings: SettingsView()
            case .addPhoto: AddPhotoView()
            case .article(let url): SafariView(url: url).ignoresSafeArea()
            }
        }
        .task { await runLoop() }
        .onChange(of: settings.cityA) { _ in Task { await loadWeather() } }
        .onChange(of: settings.cityB) { _ in Task { await loadWeather() } }
        .onChange(of: settings.feeds) { feeds in Task { await news.load(feeds) } }
        .onChange(of: store.arrival) { arrival in
            guard let a = arrival, settings.readMessages, !settings.isNight() else { return }
            let lead = a.kind == .message ? L.newMessageFrom : L.newPhotoFrom
            Speaker.shared.say("\(settings.t(lead)) \(a.author). \(a.text)", language: settings.language)
        }
    }

    private var dashboard: some View {
        VStack(spacing: 12) {
            TabView(selection: $pageIndex) {
                ForEach(Array(settings.pages.enumerated()), id: \.element) { i, page in
                    pageView(page).tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: settings.pages.count > 1 ? .always : .never))
            .task(id: "\(pageIndex)-\(settings.rotatePages)-\(settings.pageSeconds)-\(settings.pages.count)") {
                // Restarts after every swipe, so a page you swiped to stays for the full time.
                guard settings.rotatePages, settings.pages.count > 1 else { return }
                try? await Task.sleep(nanoseconds: UInt64(max(settings.pageSeconds, 10)) * 1_000_000_000)
                guard !Task.isCancelled else { return }
                withAnimation { pageIndex = (pageIndex + 1) % settings.pages.count }
            }
            HStack(spacing: 12) {
                CallOrb { sheet = .settings }
                NewsStrip(headlines: news.headlines) { sheet = .article($0) }
                toolButtons
            }
            .frame(height: 84)
        }
        .padding(12)
        .onChange(of: settings.pages) { _ in pageIndex = 0 }
    }

    @ViewBuilder
    private func pageView(_ page: ScreenPage) -> some View {
        switch page {
        case .home: homePage.padding(.bottom, 24)
        case .photos: PhotoPanel(events: calendar.events, onAdd: { sheet = .addPhoto }).padding(.bottom, 24)
        case .clocks: ClocksPage(weatherA: weatherA, weatherB: weatherB).padding(.bottom, 24)
        case .calendar: CalendarCard(feed: calendar, limit: 10, large: true).padding(.bottom, 24)
        case .news: NewsPage(headlines: news.headlines) { sheet = .article($0) }.padding(.bottom, 24)
        }
    }

    private var homePage: some View {
        GeometryReader { geo in
            let landscape = geo.size.width > geo.size.height
            let layout = landscape ? AnyLayoutBox.horizontal : AnyLayoutBox.vertical
            layout.stack {
                PhotoPanel(events: calendar.events, onAdd: { sheet = .addPhoto })
                    .frame(width: landscape ? geo.size.width * 0.52 : nil,
                           height: landscape ? nil : geo.size.height * 0.42)
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        CityCard(city: settings.cityA, weather: weatherA)
                        CityCard(city: settings.cityB, weather: weatherB)
                    }
                    .frame(height: 170)
                    MessageBoard()
                    CalendarCard(feed: calendar)
                        .frame(height: landscape ? 150 : 180)
                }
            }
        }
    }

    private var toolButtons: some View {
        HStack(spacing: 10) {
            Button {
                Speaker.shared.announce(settings: settings, weatherA: weatherA, weatherB: weatherB)
            } label: {
                Image(systemName: "speaker.wave.2.fill").font(.title2).frame(width: 60, height: 60)
                    .background(Circle().fill(Color.white.opacity(0.1)))
            }
            .accessibilityLabel(settings.t(.readNow))
            Button { sheet = .settings } label: {
                Image(systemName: "gearshape.fill").font(.title2).frame(width: 60, height: 60)
                    .background(Circle().fill(Color.white.opacity(0.1)))
            }
            .accessibilityLabel(settings.t(.settings))
        }
        .foregroundColor(.white)
    }

    // MARK: - Background refresh

    private func runLoop() async {
        var tick = 0
        while !Task.isCancelled {
            if tick % 30 == 0 {   // every 15 minutes
                await loadWeather()
                await calendar.load()
                await news.load(settings.feeds)
            }
            await store.refresh()
            now = Date()
            chimeIfNeeded()
            tick += 1
            try? await Task.sleep(nanoseconds: 30_000_000_000)
        }
    }

    private func loadWeather() async {
        weatherA = await WeatherProvider.current(for: settings.cityA)
        weatherB = await WeatherProvider.current(for: settings.cityB)
    }

    private func chimeIfNeeded() {
        let c = Calendar.current.dateComponents([.hour, .minute], from: now)
        guard settings.hourlyChime, c.minute == 0, c.hour != lastChimeHour, !settings.isNight(now) else { return }
        lastChimeHour = c.hour ?? -1
        Speaker.shared.say("\(settings.t(.itIs)) \(Format.time(now, language: settings.language))", language: settings.language)
    }
}

/// HStack in landscape, VStack in portrait (AnyLayout needs iPadOS 16).
enum AnyLayoutBox {
    case horizontal, vertical

    @ViewBuilder
    func stack<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        switch self {
        case .horizontal: HStack(spacing: 12) { content() }
        case .vertical: VStack(spacing: 12) { content() }
        }
    }
}
