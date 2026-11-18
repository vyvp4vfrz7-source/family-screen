import UIKit

/// Sample content for simulator screenshots. Only runs when the app is
/// launched with the "-demoData" argument (never on a family's iPad).
enum Demo {
    static var isOn: Bool { ProcessInfo.processInfo.arguments.contains("-demoData") }
    static var landscape: Bool { ProcessInfo.processInfo.arguments.contains("-landscape") }

    @MainActor
    static func seedIfNeeded() {
        guard isOn else { return }
        let s = AppSettings.shared
        s.homeName = "London home"
        s.contactName = "Grandma"
        s.contactAddress = "grandma@example.com"
        s.pages = ScreenPage.allCases
        s.rotatePages = true
        s.pageSeconds = 20
        s.nightFrom = 0
        s.nightTo = 0
        let store = FamilyStore.shared
        guard store.photos.isEmpty else { return }
        store.addPhoto(picture(top: .systemOrange, bottom: .systemPurple, emoji: "👨‍👩‍👧‍👦"), note: "Leo's first day at school!")
        store.addMessage("Video call Sunday 11am?")
        store.addMessage("Grandma, we made dumplings tonight 🥟")
    }

    private static func picture(top: UIColor, bottom: UIColor, emoji: String) -> UIImage {
        let size = CGSize(width: 1200, height: 900)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let colors = [top.cgColor, bottom.cgColor] as CFArray
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                ctx.cgContext.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
            }
            let text = emoji as NSString
            let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 300)]
            let t = text.size(withAttributes: attrs)
            text.draw(at: CGPoint(x: (size.width - t.width) / 2, y: (size.height - t.height) / 2), withAttributes: attrs)
        }
    }

    @MainActor
    static func rotateIfNeeded() {
        guard landscape, #available(iOS 16, *),
              let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight)) { _ in }
    }
}
