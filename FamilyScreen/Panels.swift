import SwiftUI

// MARK: - Photos with notes

struct PhotoPanel: View {
    var events: [UpcomingEvent] = []
    var onAdd: () -> Void
    /// Shows the time as big see-through digits on the photo (the Photos page).
    var bigTime = false
    @ObservedObject private var store = FamilyStore.shared
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var album = SharedAlbumSource.shared
    @State private var index = 0
    @State private var image: UIImage?
    /// The slide on screen; it changes only once the next image has loaded.
    @State private var shown: Slide?
    /// Which side the big time sits on: the calmer half of the photo.
    @State private var timeOnLeft = false

    /// Family photos and the chosen shared album, newest first.
    private var slides: [Slide] {
        (store.shownPhotos.map(Slide.family) + album.items.map(Slide.album)).sorted { $0.date > $1.date }
    }

    private var current: Slide? {
        let all = slides
        return all.isEmpty ? nil : all[index % all.count]
    }

    private var festival: Festival? {
        settings.festivalThemes ? Festival.on(Date(), events: events) : nil
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 24).fill(Color.white.opacity(0.05))
            if let image = image, let slide = shown, !slides.isEmpty {
                // Color.clear takes the panel's size, so the filled image can't grow past it.
                Color.clear
                    .overlay(Image(uiImage: image).resizable().scaledToFill().blur(radius: 30).opacity(0.5))
                    .clipped()
                FramedPhoto(image: image, style: settings.frameStyle, caption: slide.caption,
                            panZoom: settings.panZoom, seconds: Double(max(settings.slideSeconds, 5)),
                            seed: abs(slide.id.hashValue % 997))
                    .id(slide.id)
                    .transition(.opacity)
                caption(for: slide)
                if bigTime {
                    BigPhotoTime(onLeft: timeOnLeft)
                        .id("time-\(slide.id)")
                        .transition(.opacity)
                }
            } else if slides.isEmpty {
                PhotoSetupCard().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            if let festival = festival { FestivalOverlay(festival: festival) }
        }
        .animation(.easeInOut(duration: 0.8), value: shown?.id)
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
            if let photo = shown?.familyPhoto {
                Button { store.setPinned(photo.id, !photo.pinned) } label: {
                    Label(settings.t(photo.pinned ? .unpin : .pin), systemImage: photo.pinned ? "pin.slash" : "pin")
                }
                Button(role: .destructive) { store.deletePhoto(photo.id) } label: {
                    Label(settings.t(.delete), systemImage: "trash")
                }
                if photo.author != settings.homeName {
                    Button { store.hide(author: photo.author) } label: {
                        Label(settings.t(.hidePosts), systemImage: "eye.slash")
                    }
                    Button { store.report(author: photo.author, text: photo.note, id: photo.id) } label: {
                        Label(settings.t(.report), systemImage: "exclamationmark.bubble")
                    }
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
        .task(id: current?.id) { await loadImage() }
        .onChange(of: store.photos) { _ in Task { await loadImage() } }
        .onChange(of: store.arrival) { a in
            if a?.kind == .photo { index = 0 }   // newest photo first
        }
    }

    /// The note and who sent it. The polaroid frame already shows the note.
    @ViewBuilder
    private func caption(for slide: Slide) -> some View {
        let note = settings.frameStyle == .polaroid ? "" : slide.caption
        VStack(alignment: .leading, spacing: 4) {
            if !note.isEmpty { Text(note).font(.title2.weight(.semibold)) }
            HStack(spacing: 6) {
                if slide.familyPhoto?.pinned == true { Image(systemName: "pin.fill") }
                Text("\(slide.byline) · \(Format.string(slide.date, template: "dMMM", language: settings.language))")
            }
            .font(.subheadline).foregroundColor(.secondary)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(14)
    }

    private func advance() {
        let count = slides.count
        guard count > 0 else { return }
        index = (index + 1) % count
    }

    private func loadImage() async {
        guard let slide = current else { image = nil; shown = nil; return }
        let next: UIImage?
        switch slide {
        case .family(let photo):
            next = store.image(for: photo)
        case .album(let item):
            let side = UIScreen.main.nativeBounds.height
            next = await SharedAlbumSource.shared.image(item.id, size: CGSize(width: side, height: side))
        }
        guard current?.id == slide.id else { return }   // moved on while loading
        image = next
        shown = slide
        if bigTime, let next = next { timeOnLeft = BigPhotoTime.leftIsCalmer(next) }
    }
}

// MARK: - Big time on the photo

/// The hour and minute stacked as huge frosted digits over one side of the photo.
struct BigPhotoTime: View {
    var onLeft: Bool
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        GeometryReader { geo in
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let parts = Self.parts(context.date, city: settings.cityA, language: settings.language)
                let size = geo.size.height * 0.44
                VStack(spacing: -size * 0.12) {
                    Text(parts.hour)
                    Text(parts.minute)
                }
                .font(.custom("AvenirNextCondensed-Heavy", size: size))
                .monospacedDigit()
                .foregroundColor(.white.opacity(0.42))
                .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
                .lineLimit(1).minimumScaleFactor(0.5)
                .padding(.horizontal, geo.size.width * 0.04)
                .frame(width: geo.size.width, height: geo.size.height, alignment: onLeft ? .leading : .trailing)
            }
        }
        .allowsHitTesting(false)
        .animation(.easeInOut(duration: 0.8), value: onLeft)
    }

    static func parts(_ date: Date, city: City, language: AppLanguage) -> (hour: String, minute: String) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = city.timeZone
        let c = cal.dateComponents([.hour, .minute], from: date)
        var hour = c.hour ?? 0
        let format = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: language.locale) ?? "H"
        if format.contains("a") { hour = hour % 12 == 0 ? 12 : hour % 12 }
        return (String(format: "%02d", hour), String(format: "%02d", c.minute ?? 0))
    }

    /// True when the left half of the picture has less detail than the right,
    /// so the digits cover sky or wall rather than faces.
    static func leftIsCalmer(_ image: UIImage) -> Bool {
        guard let cg = image.cgImage else { return false }
        let w = 32, h = 32
        var pixels = [UInt8](repeating: 0, count: w * h)
        guard let ctx = CGContext(data: &pixels, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                                  space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)
        else { return false }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        func detail(_ xs: Range<Int>) -> Int {
            var sum = 0
            for y in 0..<h { for x in xs.dropFirst() {
                sum += abs(Int(pixels[y * w + x]) - Int(pixels[y * w + x - 1]))
                if y > 0 { sum += abs(Int(pixels[y * w + x]) - Int(pixels[(y - 1) * w + x])) }
            } }
            return sum
        }
        return detail(0..<(w / 2)) < detail((w / 2)..<w)
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
    @State private var picking = false
    @State private var asked = false

    // The picker is its own sheet on top of this one. On a Mac ("Designed for
    // iPad") the picker closes itself after a pick; if it were the root of this
    // sheet, the whole sheet would close before the photo arrived.
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                if let image = image {
                    Image(uiImage: image).resizable().scaledToFit().cornerRadius(16)
                } else {
                    Button { picking = true } label: {
                        Label(settings.t(.addPhoto), systemImage: "photo.on.rectangle")
                            .font(.title2).frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
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
                        if let image = image { FamilyStore.shared.addPhoto(image, note: note) }
                        dismiss()
                    }
                    .disabled(image == nil)
                }
            }
        }
        .navigationViewStyle(.stack)
        .onAppear {
            guard !asked else { return }
            asked = true
            picking = true
        }
        .sheet(isPresented: $picking) {
            PhotoPicker { picked in
                picking = false
                if let picked = picked { image = picked }
            }
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
