import SwiftUI

// MARK: - What the slideshow shows

/// A family photo, or a photo from the iCloud Shared Album chosen in Settings.
enum Slide: Identifiable, Equatable {
    case family(FamilyPhoto)
    case album(SharedAlbumSource.Item)

    var id: String {
        switch self {
        case .family(let p): return p.id
        case .album(let a): return "album-" + a.id
        }
    }

    var date: Date {
        switch self {
        case .family(let p): return p.date
        case .album(let a): return a.date
        }
    }

    var caption: String {
        if case .family(let p) = self { return p.note }
        return ""
    }

    var byline: String {
        switch self {
        case .family(let p): return p.author
        case .album(let a): return a.album
        }
    }

    var familyPhoto: FamilyPhoto? {
        if case .family(let p) = self { return p }
        return nil
    }
}

// MARK: - Frames

private let gold = Color(red: 0.86, green: 0.70, blue: 0.33)
private let chineseRed = Color(red: 0.55, green: 0.06, blue: 0.08)

/// One photo in the chosen frame, sized to fit the space it is given.
struct FramedPhoto: View {
    let image: UIImage
    let style: FrameStyle
    let caption: String
    let panZoom: Bool
    let seconds: Double
    let seed: Int

    private var ratio: CGFloat { image.size.width / max(image.size.height, 1) }

    private var picture: some View {
        KenBurnsImage(image: image, on: panZoom, seconds: seconds, seed: seed)
            .aspectRatio(ratio, contentMode: .fit)
    }

    var body: some View {
        Group {
            switch style {
            case .plain:
                picture
            case .polaroid:
                VStack(spacing: 0) {
                    picture
                    Text(caption.isEmpty ? " " : caption)
                        .font(.custom("Noteworthy-Bold", size: 28))
                        .foregroundColor(Color(white: 0.15))
                        .lineLimit(2).minimumScaleFactor(0.6)
                        .frame(maxWidth: .infinity, minHeight: 72)
                }
                .padding([.top, .horizontal], 18)
                .padding(.bottom, 6)
                .background(Color(white: 0.97))
                .shadow(color: .black.opacity(0.5), radius: 14, y: 8)
                .rotationEffect(.degrees(seed % 2 == 0 ? -1.5 : 1.2))
            case .whiteMat:
                picture
                    .padding(36)
                    .background(Color(white: 0.96))
                    .padding(12)
                    .background(Color(red: 0.24, green: 0.16, blue: 0.10))
                    .shadow(color: .black.opacity(0.5), radius: 12, y: 6)
            case .goldChinese:
                picture
                    .overlay(Rectangle().stroke(gold, lineWidth: 2))
                    .padding(26)
                    .background(chineseRed)
                    .overlay(Rectangle().strokeBorder(gold, lineWidth: 6))
                    .overlay(Rectangle().strokeBorder(gold.opacity(0.8), lineWidth: 1.5).padding(12))
                    .overlay(GoldCorners())
                    .overlay(alignment: .top) {
                        Text("福").font(.system(size: 22, weight: .bold)).foregroundColor(chineseRed)
                            .frame(width: 38, height: 38).background(Circle().fill(gold))
                            .offset(y: -12)
                    }
                    .shadow(color: .black.opacity(0.5), radius: 12, y: 6)
            }
        }
        .padding(style == .plain ? 0 : 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct GoldCorners: View {
    var body: some View {
        ZStack {
            mark.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            mark.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            mark.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            mark.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .padding(4)
    }

    private var mark: some View {
        Rectangle().fill(gold).frame(width: 12, height: 12).rotationEffect(.degrees(45))
    }
}

/// Slowly zooms towards one corner while the photo is shown ("Ken Burns").
struct KenBurnsImage: View {
    let image: UIImage
    let on: Bool
    let seconds: Double
    let seed: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var moved = false

    private static let anchors: [UnitPoint] = [.topLeading, .bottomTrailing, .topTrailing, .bottomLeading, .center]

    var body: some View {
        Color.clear
            .overlay(
                Image(uiImage: image).resizable().scaledToFill()
                    .scaleEffect(moved ? 1.12 : 1.0, anchor: Self.anchors[abs(seed) % Self.anchors.count])
            )
            .clipped()
            .onAppear {
                guard on, !reduceMotion else { return }
                withAnimation(.linear(duration: max(seconds, 5))) { moved = true }
            }
    }
}

// MARK: - Festival themes

enum Festival: Equatable {
    case christmas, lunarNewYear
    case birthday(String)

    /// Christmas 20–26 Dec, the first 15 days of the Chinese year, or a
    /// "birthday" event in today's calendar.
    static func on(_ date: Date, events: [UpcomingEvent]) -> Festival? {
        let words = ["birthday", "bday", "生日", "urodziny", "जन्मदिन"]
        if let e = events.first(where: { ev in
            Calendar.current.isDate(ev.start, inSameDayAs: date) && words.contains { ev.title.lowercased().contains($0) }
        }) {
            return .birthday(e.title)
        }
        var chinese = Calendar(identifier: .chinese)
        chinese.timeZone = TimeZone(identifier: "Asia/Hong_Kong") ?? .current
        let c = chinese.dateComponents([.month, .day], from: date)
        if c.month == 1, c.isLeapMonth != true, let d = c.day, d <= 15 { return .lunarNewYear }
        let g = Calendar.current.dateComponents([.month, .day], from: date)
        if g.month == 12, let d = g.day, (20...26).contains(d) { return .christmas }
        return nil
    }

    @MainActor
    func greeting(_ settings: AppSettings) -> String {
        switch self {
        case .christmas: return "🎄 \(settings.t(.merryChristmas))"
        case .lunarNewYear: return "🧧 \(settings.t(.happyLunarNewYear))"
        case .birthday(let title): return "🎂 \(title)"
        }
    }

    var color: Color {
        switch self {
        case .christmas: return Color(red: 0.75, green: 0.1, blue: 0.12)
        case .lunarNewYear: return gold
        case .birthday: return Color(red: 0.95, green: 0.45, blue: 0.7)
        }
    }

    var corners: (String, String) {
        switch self {
        case .christmas: return ("❄️", "🎁")
        case .lunarNewYear: return ("🏮", "🏮")
        case .birthday: return ("🎈", "🎉")
        }
    }
}

struct FestivalOverlay: View {
    let festival: Festival
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24).strokeBorder(festival.color, lineWidth: 6)
            VStack {
                HStack(alignment: .top) {
                    Text(festival.corners.0).font(.system(size: 44))
                    Spacer()
                    Text(festival.greeting(settings))
                        .font(.title2.weight(.bold)).foregroundColor(.white)
                        .padding(.horizontal, 18).padding(.vertical, 8)
                        .background(Capsule().fill(festival.color.opacity(0.9)))
                    Spacer()
                    Text(festival.corners.1).font(.system(size: 44)).padding(.trailing, 70) // clear of the + button
                }
                Spacer()
            }
            .padding(14)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Setup card

/// How to get photos onto the screen, shown until the first one arrives.
struct PhotoSetupCard: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(settings.t(.setupTitle)).font(.title2.weight(.bold))
            row("square.and.arrow.up", .setupShare)
            row("rectangle.stack.badge.person.crop", .setupAlbum)
            row("plus.circle", .setupPlus)
            Divider()
            row("lock.shield", .setupPrivacy).font(.subheadline).foregroundColor(.secondary)
        }
        .padding(20)
        .frame(maxWidth: 560, alignment: .leading)
    }

    private func row(_ icon: String, _ key: L) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.title3).foregroundColor(.accentColor).frame(width: 30)
            Text(settings.t(key)).fixedSize(horizontal: false, vertical: true)
        }
    }
}
