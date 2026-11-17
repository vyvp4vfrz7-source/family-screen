import Foundation
import UIKit

struct FamilyPhoto: Identifiable, Codable, Equatable {
    var id: String
    var note: String
    var author: String
    var date: Date
}

struct FamilyMessage: Identifiable, Codable, Equatable {
    var id: String
    var text: String
    var author: String
    var date: Date
    var hearts: [String]
}

/// Something new from the other home, shown as a pop-up.
struct Arrival: Identifiable, Equatable {
    enum Kind { case message, photo }
    var id: String
    var kind: Kind
    var author: String
    var text: String
}

/// Photos and messages shared by the family. Kept on this iPad, and synced
/// between homes with CloudKit when the app is built with APPLE_SERVICES = YES.
@MainActor
final class FamilyStore: ObservableObject {
    static let shared = FamilyStore()

    @Published private(set) var photos: [FamilyPhoto] = []
    @Published private(set) var messages: [FamilyMessage] = []
    @Published var arrival: Arrival?
    @Published var syncStatus: String = ""

    private let folder: URL
    private var lastSeen: Date {
        get { UserDefaults.standard.object(forKey: "lastSeen") as? Date ?? .distantPast }
        set { UserDefaults.standard.set(newValue, forKey: "lastSeen") }
    }

    #if APPLE_SERVICES
    let cloud: CloudSync
    #endif

    private init() {
        #if APPLE_SERVICES
        cloud = CloudSync()
        #endif
        folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("family", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        load()
    }

    var homeName: String { AppSettings.shared.homeName }

    // MARK: - Images on disk

    func imageURL(_ id: String) -> URL { folder.appendingPathComponent("\(id).jpg") }

    func image(for photo: FamilyPhoto) -> UIImage? {
        UIImage(contentsOfFile: imageURL(photo.id).path)
    }

    // MARK: - Local cache

    private var indexURL: URL { folder.appendingPathComponent("index.json") }

    private struct Index: Codable { var photos: [FamilyPhoto]; var messages: [FamilyMessage] }

    private func load() {
        guard let data = try? Data(contentsOf: indexURL),
              let index = try? JSONDecoder().decode(Index.self, from: data) else { return }
        photos = index.photos
        messages = index.messages
    }

    private func persist() {
        photos.sort { $0.date > $1.date }
        messages.sort { $0.date > $1.date }
        if let data = try? JSONEncoder().encode(Index(photos: photos, messages: messages)) {
            try? data.write(to: indexURL, options: .atomic)
        }
    }

    // MARK: - Actions from this iPad

    func addPhoto(_ image: UIImage, note: String) {
        let id = UUID().uuidString
        guard let jpeg = image.resizedForSharing().jpegData(compressionQuality: 0.8) else { return }
        try? jpeg.write(to: imageURL(id), options: .atomic)
        let photo = FamilyPhoto(id: id, note: note, author: homeName, date: Date())
        photos.append(photo)
        persist()
        #if APPLE_SERVICES
        Task { await pushing { try await cloud.save(photo: photo, imageURL: imageURL(id)) } }
        #endif
    }

    func addMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let message = FamilyMessage(id: UUID().uuidString, text: trimmed, author: homeName, date: Date(), hearts: [])
        messages.append(message)
        persist()
        #if APPLE_SERVICES
        Task { await pushing { try await cloud.save(message: message) } }
        #endif
    }

    func heart(_ messageID: String) {
        guard let i = messages.firstIndex(where: { $0.id == messageID }) else { return }
        if !messages[i].hearts.contains(homeName) { messages[i].hearts.append(homeName) }
        persist()
        #if APPLE_SERVICES
        let msg = messages[i]
        Task { await pushing { try await cloud.saveHearts(messageID: msg.id, hearts: msg.hearts) } }
        #endif
    }

    func deletePhoto(_ id: String) {
        photos.removeAll { $0.id == id }
        try? FileManager.default.removeItem(at: imageURL(id))
        persist()
        #if APPLE_SERVICES
        Task { await pushing { try await cloud.delete(id) } }
        #endif
    }

    func deleteMessage(_ id: String) {
        messages.removeAll { $0.id == id }
        persist()
        #if APPLE_SERVICES
        Task { await pushing { try await cloud.delete(id) } }
        #endif
    }

    // MARK: - Sync

    /// Called every 30 seconds while the screen is on.
    func refresh() async {
        #if APPLE_SERVICES
        do {
            let changes = try await cloud.fetchChanges()
            for photo in changes.photos {
                if let tmp = changes.assetFiles[photo.id] {
                    try? FileManager.default.removeItem(at: imageURL(photo.id))
                    try? FileManager.default.copyItem(at: tmp, to: imageURL(photo.id))
                }
                photos.removeAll { $0.id == photo.id }
                photos.append(photo)
            }
            for message in changes.messages {
                messages.removeAll { $0.id == message.id }
                messages.append(message)
            }
            for id in changes.deleted {
                photos.removeAll { $0.id == id }
                messages.removeAll { $0.id == id }
                try? FileManager.default.removeItem(at: imageURL(id))
            }
            persist()
            syncStatus = ""
        } catch {
            syncStatus = error.localizedDescription
        }
        #endif
        announceArrivals()
    }

    /// Clears the local copy, e.g. after joining another home's family.
    func resetLocal() {
        for p in photos { try? FileManager.default.removeItem(at: imageURL(p.id)) }
        photos = []
        messages = []
        persist()
    }

    private func announceArrivals() {
        let fresh = lastSeen
        let newMessage = messages.first { $0.author != homeName && $0.date > fresh }
        let newPhoto = photos.first { $0.author != homeName && $0.date > fresh }
        if let m = newMessage {
            arrival = Arrival(id: m.id, kind: .message, author: m.author, text: m.text)
        } else if let p = newPhoto {
            arrival = Arrival(id: p.id, kind: .photo, author: p.author, text: p.note)
        }
        let newest = ([messages.first?.date, photos.first?.date].compactMap { $0 }).max()
        if lastSeen == .distantPast {
            // First launch: don't pop up old items.
            arrival = nil
            lastSeen = newest ?? Date()
        } else if newMessage != nil || newPhoto != nil, let newest = newest {
            lastSeen = newest
        }
    }

    private func pushing(_ work: () async throws -> Void) async {
        do { try await work(); syncStatus = "" } catch { syncStatus = error.localizedDescription }
    }
}

extension UIImage {
    /// Shrinks big camera photos so they upload quickly and fit old iPads.
    func resizedForSharing(maxSide: CGFloat = 1600) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxSide else { return self }
        let scale = maxSide / longest
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
