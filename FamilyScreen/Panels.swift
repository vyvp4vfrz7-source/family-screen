import SwiftUI

// MARK: - Photos with notes

struct PhotoPanel: View {
    var onAdd: () -> Void
    @ObservedObject private var store = FamilyStore.shared
    @ObservedObject private var settings = AppSettings.shared
    @State private var index = 0
    @State private var image: UIImage?

    private var current: FamilyPhoto? {
        store.photos.isEmpty ? nil : store.photos[index % store.photos.count]
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 24).fill(Color.white.opacity(0.05))
            if let image = image {
                Image(uiImage: image).resizable().scaledToFill().blur(radius: 30).opacity(0.5)
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                Text(settings.t(.noPhotos)).font(.title3).foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            if let photo = current {
                VStack(alignment: .leading, spacing: 4) {
                    if !photo.note.isEmpty { Text(photo.note).font(.title2.weight(.semibold)) }
                    Text("\(photo.author) · \(Format.string(photo.date, template: "dMMM", language: settings.language))")
                        .font(.subheadline).foregroundColor(.secondary)
                }
                .padding(14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding(14)
            }
        }
        .overlay(alignment: .topTrailing) {
            Button(action: onAdd) {
                Image(systemName: "plus").font(.title.weight(.bold)).foregroundColor(.white)
                    .frame(width: 64, height: 64).background(Circle().fill(Color.accentColor))
            }
            .accessibilityLabel(settings.t(.addPhoto))
            .padding(14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .contextMenu {
            if let photo = current {
                Button(role: .destructive) { store.deletePhoto(photo.id) } label: {
                    Label(settings.t(.delete), systemImage: "trash")
                }
            }
        }
        .onTapGesture { advance() }
        .task(id: settings.slideSeconds) {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(max(settings.slideSeconds, 5)) * 1_000_000_000)
                if !Task.isCancelled { advance() }
            }
        }
        .onAppear(perform: loadImage)
        .onChange(of: store.photos) { _ in loadImage() }
        .onChange(of: store.arrival) { a in
            if a?.kind == .photo { index = 0; loadImage() }   // newest photo first
        }
    }

    private func advance() {
        guard !store.photos.isEmpty else { return }
        index = (index + 1) % store.photos.count
        loadImage()
    }

    private func loadImage() {
        image = current.flatMap { store.image(for: $0) }
    }
}

// MARK: - City clock and weather

struct CityCard: View {
    var city: City
    var weather: WeatherNow?
    @ObservedObject private var settings = AppSettings.shared
    @State private var legalURL: URL?

    var body: some View {
        Card(title: city.name) {
            TimelineView(.everyMinute) { context in
                VStack(alignment: .leading, spacing: 2) {
                    Text(Format.time(context.date, city: city, language: settings.language))
                        .font(.system(size: 44, weight: .bold, design: .rounded)).monospacedDigit()
                        .minimumScaleFactor(0.5).lineLimit(1)
                    Text(Format.string(context.date, template: "EEEEdMMM", city: city, language: settings.language))
                        .font(.subheadline).foregroundColor(.secondary)
                }
            }
            if let w = weather {
                HStack(spacing: 8) {
                    Image(systemName: w.symbol).symbolRenderingMode(.multicolor).font(.title2)
                    Text("\(Int(w.temperature.rounded()))°").font(.title2.bold())
                    if let hi = w.high, let lo = w.low {
                        Text("↑\(Int(hi.rounded()))° ↓\(Int(lo.rounded()))°").font(.subheadline).foregroundColor(.secondary)
                    }
                }
            }
            if WeatherProvider.usesWeatherKit, let url = legalURL {
                Link("\u{F8FF} Weather", destination: url).font(.caption2).foregroundColor(.secondary)
            }
        }
        .task {
            #if APPLE_SERVICES
            if #available(iOS 16, *) { legalURL = await WeatherProvider.legalURL() }
            #endif
        }
    }
}

// MARK: - Message board (留言板)

struct MessageBoard: View {
    @ObservedObject private var store = FamilyStore.shared
    @ObservedObject private var settings = AppSettings.shared
    @State private var draft = ""

    var body: some View {
        Card(title: settings.t(.messages)) {
            HStack {
                TextField(settings.t(.typeMessage), text: $draft)
                    .textFieldStyle(.roundedBorder).font(.title3)
                    .submitLabel(.send).onSubmit(send)
                Button(settings.t(.send), action: send).buttonStyle(.borderedProminent)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(store.messages.prefix(12)) { m in
                        row(m)
                    }
                }
            }
        }
    }

    private func row(_ m: FamilyMessage) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(m.text).font(.title3)
                Text("\(m.author) · \(Format.string(m.date, template: "dMMMjmm", language: settings.language))"
                     + (m.hearts.isEmpty ? "" : "  ❤️ " + m.hearts.joined(separator: ", ")))
                    .font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            if m.author != settings.homeName && !m.hearts.contains(settings.homeName) {
                Button(settings.t(.gotIt)) { store.heart(m.id) }.buttonStyle(.bordered)
            }
        }
        .contextMenu {
            Button(role: .destructive) { store.deleteMessage(m.id) } label: {
                Label(settings.t(.delete), systemImage: "trash")
            }
        }
    }

    private func send() {
        store.addMessage(draft)
        draft = ""
    }
}

// MARK: - Calendar

struct CalendarCard: View {
    @ObservedObject var feed: CalendarFeed
    var limit = 4
    var large = false
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Card(title: settings.t(.calendar)) {
            if feed.denied {
                Text(settings.t(.calendarDenied)).foregroundColor(.secondary)
            } else if feed.events.isEmpty {
                Text(settings.t(.noEvents)).foregroundColor(.secondary)
            } else {
                ForEach(feed.events.prefix(limit)) { e in
                    HStack {
                        Text(when(e)).font(large ? .title2.bold() : .subheadline.bold()).foregroundColor(.accentColor)
                            .frame(width: large ? 260 : 130, alignment: .leading)
                        Text(e.title).font(large ? .title2 : .body).lineLimit(1)
                    }
                    .padding(.vertical, large ? 6 : 0)
                }
            }
        }
    }

    private func when(_ e: UpcomingEvent) -> String {
        let cal = Calendar.current
        let day: String
        if cal.isDateInToday(e.start) { day = settings.t(.today) }
        else if cal.isDateInTomorrow(e.start) { day = settings.t(.tomorrow) }
        else { day = Format.string(e.start, template: "EEE", language: settings.language) }
        return e.allDay ? day : "\(day) \(Format.time(e.start, language: settings.language))"
    }
}

// MARK: - FaceTime orb

struct CallOrb: View {
    var openSettings: () -> Void
    @ObservedObject private var settings = AppSettings.shared
    @State private var pulse = false

    var body: some View {
        Button(action: call) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Color.green.opacity(0.35)).scaleEffect(pulse ? 1.25 : 1)
                    Circle().fill(Color.green)
                    Image(systemName: settings.audioOnly ? "phone.fill" : "video.fill")
                        .font(.title).foregroundColor(.white)
                }
                .frame(width: 72, height: 72)
                Text(settings.contactName.isEmpty ? settings.t(.callNotSet)
                                                  : "\(settings.t(.call)) \(settings.contactName)")
                    .font(.title3.bold()).foregroundColor(.white).lineLimit(2)
            }
            .padding(.trailing, 12)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { pulse = true }
        }
    }

    private func call() {
        let address = settings.contactAddress.filter { !$0.isWhitespace }
        guard !address.isEmpty,
              let url = URL(string: (settings.audioOnly ? "facetime-audio://" : "facetime://") + address)
        else { openSettings(); return }
        UIApplication.shared.open(url)
    }
}

// MARK: - News headlines

struct NewsStrip: View {
    var headlines: [Headline]
    var open: (URL) -> Void
    @ObservedObject private var settings = AppSettings.shared
    @State private var index = 0

    var body: some View {
        Card {
            if headlines.isEmpty {
                Text(settings.t(.noFeeds)).foregroundColor(.secondary)
            } else {
                let h = headlines[index % headlines.count]
                Button { open(h.link) } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(h.source).font(.caption.bold()).foregroundColor(.accentColor)
                        Text(h.title).font(.headline).foregroundColor(.white).lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
                .id(h.id)
                .transition(.opacity)
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                withAnimation { index += 1 }
            }
        }
    }
}

// MARK: - Pop-up when the other home sends something

struct ArrivalBanner: View {
    var arrival: Arrival
    @ObservedObject private var store = FamilyStore.shared
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        VStack {
            VStack(spacing: 14) {
                Text("\(settings.t(arrival.kind == .message ? .newMessageFrom : .newPhotoFrom)) \(arrival.author)")
                    .font(.headline).foregroundColor(.secondary)
                if !arrival.text.isEmpty {
                    Text(arrival.text).font(.system(size: 34, weight: .semibold)).multilineTextAlignment(.center)
                }
                Button {
                    if arrival.kind == .message { store.heart(arrival.id) }
                    store.arrival = nil
                } label: {
                    Text(settings.t(.gotIt)).font(.title2.bold()).padding(.horizontal, 28).padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(28)
            .frame(maxWidth: 640)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28))
            .padding(.top, 40)
            Spacer()
        }
    }
}

// MARK: - Night clock

struct NightClock: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        TimelineView(.everyMinute) { context in
            VStack(spacing: 18) {
                Text(Format.time(context.date, city: settings.cityA, language: settings.language))
                    .font(.system(size: 160, weight: .light, design: .rounded)).monospacedDigit()
                    .minimumScaleFactor(0.3).lineLimit(1)
                Text(Format.string(context.date, template: "EEEEdMMMM", city: settings.cityA, language: settings.language))
                    .font(.title)
                Text("\(settings.cityB.name)  \(Format.time(context.date, city: settings.cityB, language: settings.language))")
                    .font(.title2)
            }
            .foregroundColor(Color(red: 0.8, green: 0.35, blue: 0.2).opacity(0.7))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.ignoresSafeArea())
        }
    }
}

// MARK: - Add a photo with a note

struct AddPhotoView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = AppSettings.shared
    @State private var image: UIImage?
    @State private var note = ""

    var body: some View {
        if let image = image {
            NavigationView {
                VStack(spacing: 16) {
                    Image(uiImage: image).resizable().scaledToFit().cornerRadius(16)
                    TextField(settings.t(.addNote), text: $note)
                        .textFieldStyle(.roundedBorder).font(.title3)
                }
                .padding()
                .navigationTitle(settings.t(.photoNote))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button(settings.t(.cancel)) { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(settings.t(.send)) {
                            FamilyStore.shared.addPhoto(image, note: note)
                            dismiss()
                        }
                    }
                }
            }
            .navigationViewStyle(.stack)
        } else {
            PhotoPicker { picked in
                if let picked = picked { image = picked } else { dismiss() }
            }
        }
    }
}

// MARK: - Big clocks page

struct ClocksPage: View {
    var weatherA: WeatherNow?
    var weatherB: WeatherNow?
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        GeometryReader { geo in
            let layout = geo.size.width > geo.size.height ? AnyLayoutBox.horizontal : AnyLayoutBox.vertical
            layout.stack {
                bigCity(settings.cityA, weatherA)
                bigCity(settings.cityB, weatherB)
            }
        }
    }

    private func bigCity(_ city: City, _ weather: WeatherNow?) -> some View {
        Card {
            VStack(spacing: 10) {
                Text(city.name).font(.system(size: 40, weight: .bold)).foregroundColor(.accentColor)
                TimelineView(.everyMinute) { context in
                    VStack(spacing: 6) {
                        Text(Format.time(context.date, city: city, language: settings.language))
                            .font(.system(size: 110, weight: .bold, design: .rounded)).monospacedDigit()
                            .minimumScaleFactor(0.4).lineLimit(1)
                        Text(Format.string(context.date, template: "EEEEdMMMM", city: city, language: settings.language))
                            .font(.title).foregroundColor(.secondary)
                    }
                }
                if let w = weather {
                    HStack(spacing: 16) {
                        Image(systemName: w.symbol).symbolRenderingMode(.multicolor).font(.system(size: 64))
                        Text("\(Int(w.temperature.rounded()))°").font(.system(size: 64, weight: .bold))
                    }
                    if let hi = w.high, let lo = w.low {
                        Text("↑\(Int(hi.rounded()))°  ↓\(Int(lo.rounded()))°").font(.title).foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - News list page

struct NewsPage: View {
    var headlines: [Headline]
    var open: (URL) -> Void
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Card(title: settings.t(.news)) {
            if headlines.isEmpty {
                Text(settings.t(.noFeeds)).font(.title3).foregroundColor(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(headlines.prefix(12)) { h in
                            Button { open(h.link) } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(h.source).font(.subheadline.bold()).foregroundColor(.accentColor)
                                    Text(h.title).font(.title3.weight(.semibold)).foregroundColor(.white)
                                        .multilineTextAlignment(.leading)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
            }
        }
    }
}
