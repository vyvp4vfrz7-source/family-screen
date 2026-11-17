import Foundation

struct Headline: Identifiable, Equatable {
    var id: String { link.absoluteString }
    var title: String
    var source: String
    var link: URL
}

/// Reads RSS and Atom feeds the family chose. Shows only the headline, the
/// source's name and a link: no article text is copied.
@MainActor
final class NewsFeedReader: ObservableObject {
    @Published var headlines: [Headline] = []

    func load(_ feeds: [NewsFeed]) async {
        var perFeed: [[Headline]] = []
        for feed in feeds {
            guard let url = URL(string: feed.url),
                  let response = try? await URLSession.shared.data(from: url) else { continue }
            perFeed.append(FeedParser(data: response.0, fallbackSource: url.host ?? "").parse())
        }
        // Mix the feeds: first story of each, then the second of each, …
        var mixed: [Headline] = []
        for i in 0..<10 {
            for list in perFeed where i < list.count { mixed.append(list[i]) }
        }
        headlines = mixed
    }
}

private final class FeedParser: NSObject, XMLParserDelegate {
    private let parser: XMLParser
    private var source: String
    private var items: [Headline] = []
    private var inItem = false
    private var element = ""
    private var title = ""
    private var link = ""
    private var channelTitle = ""

    init(data: Data, fallbackSource: String) {
        parser = XMLParser(data: data)
        source = fallbackSource
        super.init()
        parser.delegate = self
    }

    func parse() -> [Headline] {
        parser.parse()
        let name = channelTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { return items.map { Headline(title: $0.title, source: name, link: $0.link) } }
        return items
    }

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
                qualifiedName: String?, attributes: [String: String] = [:]) {
        element = name
        if name == "item" || name == "entry" {
            inItem = true; title = ""; link = ""
        } else if inItem, name == "link", let href = attributes["href"],
                  attributes["rel"] == nil || attributes["rel"] == "alternate" {
            link = href   // Atom
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inItem {
            if element == "title" { title += string }
            if element == "link" { link += string }
        } else if element == "title" {
            channelTitle += string
        }
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        if let s = String(data: CDATABlock, encoding: .utf8) { self.parser(parser, foundCharacters: s) }
    }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        if name == "item" || name == "entry" {
            inItem = false
            let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
            if let url = URL(string: link.trimmingCharacters(in: .whitespacesAndNewlines)), !t.isEmpty {
                items.append(Headline(title: t, source: source, link: url))
            }
        }
        if !inItem && name == "title" { element = "" }
        if inItem { element = "" }
    }
}
