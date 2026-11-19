import SwiftUI
import Photos

/// Reads an iCloud Shared Album this iPad already follows (Photos ▸ Shared
/// Albums), so families who use one keep using it. Nothing is uploaded: the
/// album's photos are only shown here, next to the family's own photos.
@MainActor
final class SharedAlbumSource: NSObject, ObservableObject, PHPhotoLibraryChangeObserver {
    static let shared = SharedAlbumSource()

    struct Album: Identifiable { let id: String; let title: String }
    struct Item: Identifiable, Equatable { let id: String; let date: Date; let album: String }

    @Published private(set) var albums: [Album] = []
    @Published private(set) var items: [Item] = []
    @Published private(set) var status = PHPhotoLibrary.authorizationStatus(for: .readWrite)

    var allowed: Bool { status == .authorized }

    private override init() {
        super.init()
        if allowed {
            PHPhotoLibrary.shared().register(self)
            reload()
        }
    }

    func requestAccess() async {
        status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        if allowed {
            PHPhotoLibrary.shared().register(self)
            reload()
        }
    }

    /// Lists the shared albums and loads the newest photos of the chosen one.
    func reload() {
        guard allowed else { albums = []; items = []; return }
        let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumCloudShared, options: nil)
        var found: [Album] = []
        collections.enumerateObjects { c, _, _ in
            found.append(Album(id: c.localIdentifier, title: c.localizedTitle ?? "iCloud"))
        }
        albums = found

        let chosen = AppSettings.shared.sharedAlbumID
        guard !chosen.isEmpty,
              let album = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [chosen], options: nil).firstObject
        else { items = []; return }
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = PhotoLimits.maxPhotos
        var list: [Item] = []
        let title = album.localizedTitle ?? ""
        PHAsset.fetchAssets(in: album, options: options).enumerateObjects { a, _, _ in
            list.append(Item(id: a.localIdentifier, date: a.creationDate ?? .distantPast, album: title))
        }
        items = list
    }

    func image(_ id: String, size: CGSize) async -> UIImage? {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject else { return nil }
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat   // one callback only
        options.isNetworkAccessAllowed = true
        options.resizeMode = .fast
        return await withCheckedContinuation { cont in
            PHImageManager.default().requestImage(for: asset, targetSize: size, contentMode: .aspectFit,
                                                  options: options) { image, _ in
                cont.resume(returning: image)
            }
        }
    }

    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor in self.reload() }
    }
}

/// Settings row: allow Photos access, then pick one shared album.
struct SharedAlbumPicker: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var source = SharedAlbumSource.shared

    var body: some View {
        switch source.status {
        case .authorized:
            Picker(settings.t(.sharedAlbum), selection: $settings.sharedAlbumID) {
                Text(settings.t(.noAlbum)).tag("")
                ForEach(source.albums) { Text($0.title).tag($0.id) }
            }
            .onChange(of: settings.sharedAlbumID) { _ in source.reload() }
        case .notDetermined:
            Button(settings.t(.allowPhotos)) { Task { await source.requestAccess() } }
        default:
            Text(settings.t(.photosDenied)).foregroundColor(.secondary)
        }
    }
}
