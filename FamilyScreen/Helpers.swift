import SwiftUI
import UIKit
import PhotosUI
import SafariServices
import UniformTypeIdentifiers

enum Format {
    static func string(_ date: Date, template: String, city: City? = nil, language: AppLanguage) -> String {
        let f = DateFormatter()
        f.locale = language.locale
        if let city = city { f.timeZone = city.timeZone }
        f.setLocalizedDateFormatFromTemplate(template)
        return f.string(from: date)
    }

    static func time(_ date: Date, city: City? = nil, language: AppLanguage) -> String {
        let f = DateFormatter()
        f.locale = language.locale
        if let city = city { f.timeZone = city.timeZone }
        f.timeStyle = .short
        return f.string(from: date)
    }
}

struct Card<Content: View>: View {
    var title: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = title {
                Text(title).font(.headline).foregroundColor(.accentColor)
            }
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.white.opacity(0.07)))
    }
}

/// Apple's photo picker. Needs no photo library permission.
struct PhotoPicker: UIViewControllerRepresentable {
    var onPick: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        config.preferredAssetRepresentationMode = .current   // skip HEIC→JPEG conversion, which can fail
        let vc = PHPickerViewController(configuration: config)
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPick: (UIImage?) -> Void
        init(onPick: @escaping (UIImage?) -> Void) { self.onPick = onPick }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider else {
                onPick(nil)
                return
            }
            // loadObject sometimes fails (HEIC, the simulator, iCloud-only photos),
            // so fall back to reading the image file itself.
            let fallback = {
                provider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, _ in
                    let image = url.flatMap { PhotoPrep.jpeg(from: $0) }.flatMap { UIImage(data: $0) }
                    DispatchQueue.main.async { self.onPick(image) }
                }
            }
            guard provider.canLoadObject(ofClass: UIImage.self) else { fallback(); return }
            provider.loadObject(ofClass: UIImage.self) { object, _ in
                if let image = object as? UIImage {
                    DispatchQueue.main.async { self.onPick(image) }
                } else {
                    fallback()
                }
            }
        }
    }
}

struct SafariView: UIViewControllerRepresentable {
    var url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController { SFSafariViewController(url: url) }
    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}

enum TopController {
    static func find() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes.first { $0.activationState == .foregroundActive } as? UIWindowScene
        var top = scene?.windows.first { $0.isKeyWindow }?.rootViewController
        while let next = top?.presentedViewController { top = next }
        return top
    }
}
