import UIKit
import SwiftUI
import UniformTypeIdentifiers

/// "Share ▸ Family Screen" on iPhone and iPad. Makes small, clean copies of up
/// to 10 photos and sends them straight into the family's CloudKit zone. If
/// that isn't possible yet, they wait in the app group and the app sends them.
@objc(ShareViewController)
final class ShareViewController: UIViewController {
    private let model = ShareModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        model.finish = { [weak self] in self?.extensionContext?.completeRequest(returningItems: nil) }
        model.cancel = { [weak self] in
            self?.extensionContext?.cancelRequest(withError: NSError(domain: "FamilyScreen", code: NSUserCancelledError))
        }
        let host = UIHostingController(rootView: ShareView(model: model))
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)

        let items = extensionContext?.inputItems as? [NSExtensionItem] ?? []
        model.load(items.flatMap { $0.attachments ?? [] })
    }
}

@MainActor
final class ShareModel: ObservableObject {
    struct Picked: Identifiable {
        let id = UUID()
        let jpeg: Data
        let thumb: UIImage
    }

    enum Stage: Equatable { case loading, ready, sending, finished(String), problem(String) }

    @Published var picked: [Picked] = []
    @Published var stage: Stage = .loading
    @Published var note = ""
    var finish: () -> Void = {}
    var cancel: () -> Void = {}

    let language = AppLanguage(rawValue: AppGroup.defaults.string(forKey: AppGroup.languageKey) ?? "") ?? .english
    func t(_ key: L) -> String { key.text(language) }

    func load(_ providers: [NSItemProvider]) {
        let images = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }.prefix(10)
        guard AppGroup.folder != nil else { stage = .problem(t(.shareNotSetUp)); return }
        guard !images.isEmpty else { stage = .problem(t(.shareNoPhoto)); return }
        Task {
            for provider in images {
                if let item = await Self.prepare(provider) { picked.append(item) }
            }
            stage = picked.isEmpty ? .problem(t(.shareNoPhoto)) : .ready
        }
    }

    /// Reads one shared image and makes the clean 2048 px copy (no location or EXIF).
    nonisolated private static func prepare(_ provider: NSItemProvider) async -> Picked? {
        let type = UTType.image.identifier
        let fromFile: Data? = await withCheckedContinuation { cont in
            provider.loadFileRepresentation(forTypeIdentifier: type) { url, _ in
                // The file is deleted when this returns, so read it now.
                cont.resume(returning: url.flatMap(PhotoPrep.jpeg(from:)))
            }
        }
        var jpeg = fromFile
        if jpeg == nil {
            jpeg = await withCheckedContinuation { cont in
                provider.loadDataRepresentation(forTypeIdentifier: type) { data, _ in
                    cont.resume(returning: data.flatMap(PhotoPrep.jpeg(from:)))
                }
            }
        }
        guard let jpeg = jpeg, let thumb = PhotoPrep.thumbnail(jpeg, maxPixels: 360) else { return nil }
        return Picked(jpeg: jpeg, thumb: thumb)
    }

    func send() {
        guard stage == .ready else { return }
        stage = .sending
        let home = AppGroup.defaults.string(forKey: AppGroup.homeNameKey) ?? "Home"
        let text = note.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            var queued: [FamilyPhoto] = []
            for (i, p) in picked.enumerated() {
                // A second apart keeps them in order on the screen.
                let photo = FamilyPhoto(id: UUID().uuidString, note: text, author: home,
                                        date: Date().addingTimeInterval(Double(i)))
                if Outbox.add(photo, jpeg: p.jpeg) { queued.append(photo) }
            }
            guard !queued.isEmpty else { stage = .problem(t(.shareNotSetUp)); return }
            var allSent = false
            #if APPLE_SERVICES
            if AppGroup.defaults.bool(forKey: AppGroup.cloudReadyKey) {
                let cloud = CloudSync()
                allSent = true
                for photo in queued {
                    do {
                        try await cloud.save(photo: photo, imageURL: Outbox.imageURL(photo.id))
                        Outbox.remove(photo.id)
                    } catch {
                        allSent = false
                    }
                }
            }
            #endif
            stage = .finished(allSent ? t(.shareSent) : t(.shareLater))
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            finish()
        }
    }
}

struct ShareView: View {
    @ObservedObject var model: ShareModel

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                switch model.stage {
                case .loading:
                    ProgressView()
                case .problem(let text):
                    Label(text, systemImage: "exclamationmark.triangle").font(.headline)
                case .finished(let text):
                    Label(text, systemImage: "checkmark.circle.fill").font(.headline).foregroundColor(.green)
                case .ready, .sending:
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(model.picked) { p in
                                Image(uiImage: p.thumb).resizable().scaledToFill()
                                    .frame(width: 130, height: 130).clipped().cornerRadius(12)
                            }
                        }
                    }
                    .frame(height: 130)
                    TextField(model.t(.addNote), text: $model.note)
                        .textFieldStyle(.roundedBorder).font(.title3)
                        .disabled(model.stage == .sending)
                    Text(model.t(.setupPrivacy)).font(.footnote).foregroundColor(.secondary)
                    if model.stage == .sending { ProgressView() }
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Family Screen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(model.t(.cancel)) { model.cancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(model.t(.send)) { model.send() }.disabled(model.stage != .ready)
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}
