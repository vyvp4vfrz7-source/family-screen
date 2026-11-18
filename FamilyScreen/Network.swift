import Foundation
import Network

/// Watches the Wi-Fi so the screen can say it is showing saved content.
@MainActor
final class NetworkStatus: ObservableObject {
    static let shared = NetworkStatus()
    @Published private(set) var online = true
    private let monitor = NWPathMonitor()

    private init() {
        monitor.pathUpdateHandler = { path in
            let ok = path.status == .satisfied
            Task { @MainActor in NetworkStatus.shared.online = ok }
        }
        monitor.start(queue: DispatchQueue(label: "network"))
    }
}
