import SwiftUI

/// On iPhone the app is the "sender": join the family, send photos and
/// messages, and manage what has been shared. The wall screen is the iPad.
/// Most photos arrive through Share ▸ Family Screen, which needs the app here.
struct PhoneHomeView: View {
    @ObservedObject private var store = FamilyStore.shared
    @ObservedObject private var settings = AppSettings.shared
    @State private var showSettings = false
    @State private var adding = false

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 6)]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    if store.photos.isEmpty {
                        PhotoSetupCard()
                            .background(RoundedRectangle(cornerRadius: 20).fill(Color.white.opacity(0.07)))
                    }
                    MessageBoard().frame(height: 300)
                    LazyVGrid(columns: columns, spacing: 6) {
                        ForEach(store.shownPhotos) { PhotoThumb(photo: $0) }
                    }
                    if !store.syncStatus.isEmpty {
                        Text(store.syncStatus).font(.footnote).foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("Family Screen")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel(settings.t(.settings))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { adding = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel(settings.t(.addPhoto))
                }
            }
            .refreshable { await store.refresh() }
        }
        .navigationViewStyle(.stack)
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $adding) { AddPhotoView() }
        .task {
            while !Task.isCancelled {
                await store.refresh()
                try? await Task.sleep(nanoseconds: 30_000_000_000)
            }
        }
    }
}

private struct PhotoThumb: View {
    let photo: FamilyPhoto
    @ObservedObject private var settings = AppSettings.shared
    @State private var thumb: UIImage?

    var body: some View {
        Color.gray.opacity(0.2)
            .aspectRatio(1, contentMode: .fit)
            .overlay(thumb.map { Image(uiImage: $0).resizable().scaledToFill() })
            .clipped()
            .overlay(alignment: .topTrailing) {
                if photo.pinned {
                    Image(systemName: "pin.fill").font(.caption).padding(5)
                        .background(Circle().fill(Color.black.opacity(0.5))).padding(4)
                }
            }
            .cornerRadius(8)
            .contextMenu {
                Button { FamilyStore.shared.setPinned(photo.id, !photo.pinned) } label: {
                    Label(settings.t(photo.pinned ? .unpin : .pin), systemImage: photo.pinned ? "pin.slash" : "pin")
                }
                Button(role: .destructive) { FamilyStore.shared.deletePhoto(photo.id) } label: {
                    Label(settings.t(.delete), systemImage: "trash")
                }
            }
            .task(id: photo.id) {
                let full = FamilyStore.shared.image(for: photo)
                thumb = await full?.byPreparingThumbnail(ofSize: CGSize(width: 240, height: 240))
            }
    }
}
