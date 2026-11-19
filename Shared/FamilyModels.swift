import Foundation
import UIKit
import ImageIO
import UniformTypeIdentifiers

// Code shared by the app and the Share Extension ("Share to Family Screen").

struct FamilyPhoto: Identifiable, Codable, Equatable {
    var id: String
    var note: String
    var author: String
    var date: Date
    /// Pinned photos never expire.
    var pinned: Bool = false

    init(id: String, note: String, author: String, date: Date, pinned: Bool = false) {
        self.id = id
        self.note = note
        self.author = author
        self.date = date
        self.pinned = pinned
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        author = try c.decodeIfPresent(String.self, forKey: .author) ?? ""
        date = try c.decodeIfPresent(Date.self, forKey: .date) ?? Date()
        pinned = try c.decodeIfPresent(Bool.self, forKey: .pinned) ?? false
    }
}

struct FamilyMessage: Identifiable, Codable, Equatable {
    var id: String
    var text: String
    var author: String
    var date: Date
    var hearts: [String]
}

/// Privacy limits for the family's photos (see docs/privacy.html).
enum PhotoLimits {
    /// Longest side of every shared copy, in pixels.
    static let maxPixels = 2048
    /// Most photos a family keeps. Pinned photos count, but are never removed.
    static let maxPhotos = 300
    /// Unpinned photos are removed after this many days.
    static let keepDays = 90
}

/// The app group the app and the Share Extension both read.
enum AppGroup {
    static let homeNameKey = "group.homeName"
    static let languageKey = "group.language"
    static let cloudReadyKey = "cloud.ready"

    static var id: String { Bundle.main.object(forInfoDictionaryKey: "FamilyAppGroup") as? String ?? "" }

    /// The shared container, or nil when the build has no app group (APPLE_SERVICES = NO).
    static var folder: URL? {
        id.isEmpty ? nil : FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id)
    }

    static var defaults: UserDefaults {
        guard folder != nil, let d = UserDefaults(suiteName: id) else { return .standard }
        return d
    }
}

/// Photos the Share Extension prepared but could not upload yet.
/// The app sends them the next time it opens.
enum Outbox {
    static var folder: URL? {
        guard let base = AppGroup.folder else { return nil }
        let url = base.appendingPathComponent("Outbox", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func imageURL(_ id: String) -> URL {
        (folder ?? FileManager.default.temporaryDirectory).appendingPathComponent("\(id).jpg")
    }

    private static func infoURL(_ id: String) -> URL {
        (folder ?? FileManager.default.temporaryDirectory).appendingPathComponent("\(id).json")
    }

    @discardableResult
    static func add(_ photo: FamilyPhoto, jpeg: Data) -> Bool {
        guard folder != nil, let info = try? JSONEncoder().encode(photo) else { return false }
        do {
            try jpeg.write(to: imageURL(photo.id), options: .atomic)
            try info.write(to: infoURL(photo.id), options: .atomic)
            return true
        } catch {
            return false
        }
    }

    static func pending() -> [FamilyPhoto] {
        guard let folder = folder,
              let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        else { return [] }
        return files.filter { $0.pathExtension == "json" }
            .compactMap { try? JSONDecoder().decode(FamilyPhoto.self, from: Data(contentsOf: $0)) }
            .filter { FileManager.default.fileExists(atPath: imageURL($0.id).path) }
            .sorted { $0.date < $1.date }
    }

    static func remove(_ id: String) {
        try? FileManager.default.removeItem(at: imageURL(id))
        try? FileManager.default.removeItem(at: infoURL(id))
    }
}

/// Makes the copy that is shared: at most 2048 px, upright, and re-encoded so
/// no EXIF data (location, camera, time) is kept.
enum PhotoPrep {
    static func jpeg(from url: URL) -> Data? {
        CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary)
            .flatMap(jpeg(from:))
    }

    static func jpeg(from data: Data) -> Data? {
        CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary)
            .flatMap(jpeg(from:))
    }

    static func jpeg(from image: UIImage) -> Data? {
        let longest = max(image.size.width, image.size.height)
        let scale = min(1, CGFloat(PhotoLimits.maxPixels) / max(longest, 1))
        let target = CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let drawn = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return drawn.cgImage.flatMap(encode)
    }

    /// A small preview, e.g. for the Share sheet.
    static func thumbnail(_ data: Data, maxPixels: Int) -> UIImage? {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return downsample(src, maxPixels: maxPixels).map { UIImage(cgImage: $0) }
    }

    private static func jpeg(from src: CGImageSource) -> Data? {
        downsample(src, maxPixels: PhotoLimits.maxPixels).flatMap(encode)
    }

    private static func downsample(_ src: CGImageSource, maxPixels: Int) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,   // bakes in the rotation
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels,
        ]
        return CGImageSourceCreateThumbnailAtIndex(src, 0, options as CFDictionary)
    }

    /// Writes only the pixels: no EXIF, GPS or maker notes.
    private static func encode(_ image: CGImage) -> Data? {
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: 0.82] as CFDictionary)
        return CGImageDestinationFinalize(dest) ? out as Data : nil
    }
}
