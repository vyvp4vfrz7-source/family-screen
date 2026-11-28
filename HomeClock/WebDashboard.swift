import SwiftUI
import UIKit
import WebKit
import UniformTypeIdentifiers

/// The home-clock web pages, shown full screen inside the app.
///
/// Pages load from `fsapp://home/…`. `SiteSchemeHandler` answers each request:
/// it fetches the newest copy from the live site, saves it for offline use, and
/// falls back to the saved copy, then to the copy bundled in `WebPages/`.
enum WebSite {
    static let live = URL(string: "https://vyvp4vfrz7-source.github.io/home-clock/")!
    static let scheme = "fsapp"

    enum Start: String, CaseIterable, Identifiable {
        case family = "index.html"
        case parents = "parents/index.html"
        var id: String { rawValue }
        var title: String { self == .family ? "Family dashboard" : "Parents' screen" }
        var url: URL { URL(string: "\(WebSite.scheme)://home/\(rawValue)")! }
    }
}

struct WebRootView: View {
    @AppStorage("webStartPage") private var startPage = WebSite.Start.family.rawValue
    @State private var showMenu = false
    @State private var reloadToken = 0

    private var start: WebSite.Start { WebSite.Start(rawValue: startPage) ?? .family }

    var body: some View {
        WebPageView(url: start.url, reloadToken: reloadToken) { showMenu = true }
            .id(startPage)
            .ignoresSafeArea()
            .background(Color.black.ignoresSafeArea())
            .statusBarHidden(true)
            .modifier(HideHomeIndicator())
            // Hold two fingers on the screen for 2 seconds to open this menu.
            .confirmationDialog("Family Screen", isPresented: $showMenu, titleVisibility: .visible) {
                ForEach(WebSite.Start.allCases) { page in
                    Button(page == start ? "\(page.title) ✓" : page.title) { startPage = page.rawValue }
                }
                Button("Reload page") { reloadToken += 1 }
                Button("Cancel", role: .cancel) {}
            }
    }
}

private struct HideHomeIndicator: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.persistentSystemOverlays(.hidden)
        } else {
            content
        }
    }
}

struct WebPageView: UIViewRepresentable {
    let url: URL
    let reloadToken: Int
    let onMenu: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onMenu: onMenu) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(context.coordinator.handler, forURLScheme: WebSite.scheme)
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.websiteDataStore = .default()   // keeps the pages' saved settings (localStorage)

        let web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = context.coordinator
        web.uiDelegate = context.coordinator
        web.isOpaque = false
        web.backgroundColor = .black
        web.scrollView.backgroundColor = .black
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.scrollView.bounces = false
        web.allowsLinkPreview = false
        if #available(iOS 16.4, *) { web.isInspectable = true }   // Safari > Develop on the Mac

        let hold = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.held(_:)))
        hold.numberOfTouchesRequired = 2
        hold.minimumPressDuration = 2
        hold.cancelsTouchesInView = false
        hold.delegate = context.coordinator
        web.addGestureRecognizer(hold)

        context.coordinator.lastReload = reloadToken
        web.load(URLRequest(url: url))
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {
        context.coordinator.onMenu = onMenu
        if context.coordinator.lastReload != reloadToken {
            context.coordinator.lastReload = reloadToken
            web.load(URLRequest(url: url))
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, UIGestureRecognizerDelegate {
        let handler = SiteSchemeHandler()
        var onMenu: () -> Void
        var lastReload = 0

        init(onMenu: @escaping () -> Void) { self.onMenu = onMenu }

        @objc func held(_ g: UILongPressGestureRecognizer) {
            if g.state == .began { onMenu() }
        }

        func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }

        // Our own pages and iframes (YouTube, maps) stay in the app. Links that leave
        // the dashboard (Safari pages, Shortcuts, FaceTime, Spotify…) open outside it.
        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = action.request.url, let scheme = url.scheme?.lowercased() else {
                return decisionHandler(.allow)
            }
            if [WebSite.scheme, "about", "blob", "data"].contains(scheme) { return decisionHandler(.allow) }
            let isMainFrame = action.targetFrame?.isMainFrame ?? true
            if (scheme == "http" || scheme == "https") && !isMainFrame { return decisionHandler(.allow) }
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
        }

        // target="_blank" and window.open: open in Safari or the right app.
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let url = action.request.url { UIApplication.shared.open(url) }
            return nil
        }

        // If the page crashes (low memory on old iPads), start it again.
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { webView.reload() }
    }
}

/// Serves `fsapp://home/<path>`: live site first, then the offline copy, then the bundled copy.
/// Photos and book covers never change, so those come from the offline copy when it exists.
final class SiteSchemeHandler: NSObject, WKURLSchemeHandler {
    private var stopped = Set<ObjectIdentifier>()
    private let session: URLSession = {
        let c = URLSessionConfiguration.default
        c.requestCachePolicy = .reloadIgnoringLocalCacheData
        c.timeoutIntervalForRequest = 8
        c.waitsForConnectivity = false
        return URLSession(configuration: c)
    }()
    private let cacheDir: URL = {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("site", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()
    private let bundleDir = Bundle.main.resourceURL?.appendingPathComponent("WebPages", isDirectory: true)

    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let url = task.request.url else { return }
        var path = url.path
        if path.hasPrefix("/") { path.removeFirst() }
        if path.isEmpty || path.hasSuffix("/") { path += "index.html" }
        if path.contains("..") { return fail(task) }

        let key = ObjectIdentifier(task)
        let range = task.request.value(forHTTPHeaderField: "Range")
        let immutable = path.hasPrefix("photos/") || path.hasPrefix("books/")

        if immutable, let saved = read(cacheDir, path) {
            return respond(task, saved, path: path, range: range)
        }

        var remote = URLComponents(url: WebSite.live.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        remote.percentEncodedQuery = URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedQuery
        var request = URLRequest(url: remote.url!)
        if let method = task.request.httpMethod { request.httpMethod = method }

        session.dataTask(with: request) { [weak self] data, response, _ in
            guard let self else { return }
            var body: Data?
            if let http = response as? HTTPURLResponse, http.statusCode == 200, let data {
                body = data
                self.save(data, path)
            } else {
                body = self.read(self.cacheDir, path) ?? self.bundleDir.flatMap { self.read($0, path) }
            }
            DispatchQueue.main.async {
                guard !self.stopped.contains(key) else { self.stopped.remove(key); return }
                if let body { self.respond(task, body, path: path, range: range) } else { self.fail(task) }
            }
        }.resume()
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {
        stopped.insert(ObjectIdentifier(task))
    }

    // MARK: - Helpers

    private func read(_ dir: URL, _ path: String) -> Data? {
        try? Data(contentsOf: dir.appendingPathComponent(path))
    }

    private func save(_ data: Data, _ path: String) {
        let file = cacheDir.appendingPathComponent(path)
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: file, options: .atomic)
    }

    private func mime(_ path: String) -> String {
        let ext = (path as NSString).pathExtension.lowercased()
        let type = UTType(filenameExtension: ext)?.preferredMIMEType ?? "application/octet-stream"
        let text = ["html", "js", "css", "json", "svg", "txt"].contains(ext)
        return text ? "\(type); charset=utf-8" : type
    }

    /// Sends the file. Videos ask for byte ranges, so those get a 206 slice.
    private func respond(_ task: WKURLSchemeTask, _ data: Data, path: String, range: String?) {
        guard let url = task.request.url else { return }
        var status = 200
        var body = data
        var headers = ["Content-Type": mime(path), "Cache-Control": "no-store", "Accept-Ranges": "bytes",
                       "Access-Control-Allow-Origin": "*"]
        if let range, range.hasPrefix("bytes="), !data.isEmpty {
            let parts = range.dropFirst(6).split(separator: "-", omittingEmptySubsequences: false)
            let start = Int(parts.first ?? "") ?? 0
            let end = min(Int(parts.count > 1 ? parts[1] : "") ?? data.count - 1, data.count - 1)
            if start <= end {
                status = 206
                body = data.subdata(in: start..<(end + 1))
                headers["Content-Range"] = "bytes \(start)-\(end)/\(data.count)"
            }
        }
        headers["Content-Length"] = String(body.count)
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
        task.didReceive(response)
        task.didReceive(body)
        task.didFinish()
    }

    private func fail(_ task: WKURLSchemeTask) {
        task.didFailWithError(URLError(.fileDoesNotExist))
    }
}
