import SwiftUI
import StoreKit

/// Family Screen Plus: a one-off in-app purchase that unlocks the extra pages.
/// To change what is paid, edit `ScreenPage.plusPages` only.
extension ScreenPage {
    /// Empty = everything free (Billy's choice for v1, 2026-11-28). Later e.g. [.calendar, .birthdays, .pinkClock, .news].
    static let plusPages: Set<ScreenPage> = []
    var needsPlus: Bool { ScreenPage.plusPages.contains(self) }
}

@MainActor
final class PlusStore: ObservableObject {
    static let shared = PlusStore()
    /// Create a non-consumable product with this ID in App Store Connect.
    static let productID = (Bundle.main.bundleIdentifier ?? "familyscreen") + ".plus"

    @Published private(set) var isPlus: Bool
    @Published private(set) var price = ""
    @Published private(set) var busy = false
    @Published var message = ""
    private var product: Product?
    private var updates: Task<Void, Never>?
    private let key = "plus.v1"

    private init() {
        isPlus = Demo.isOn || UserDefaults.standard.bool(forKey: key)
        updates = Task { [weak self] in
            for await result in StoreKit.Transaction.updates {
                if case .verified(let t) = result { await t.finish() }
                await self?.refresh()
            }
        }
        Task { await load() }
    }

    func load() async {
        product = try? await Product.products(for: [Self.productID]).first
        price = product?.displayPrice ?? ""
        await refresh()
    }

    /// Asks StoreKit what this Apple ID owns (works offline from its cache).
    func refresh() async {
        var owned = Demo.isOn
        for await result in StoreKit.Transaction.currentEntitlements {
            if case .verified(let t) = result, t.productID == Self.productID, t.revocationDate == nil { owned = true }
        }
        set(owned)
    }

    func buy() async {
        message = ""
        if product == nil { await load() }
        guard let product else { message = AppSettings.shared.t(.plusUnavailable); return }
        busy = true
        defer { busy = false }
        do {
            switch try await product.purchase() {
            case .success(.verified(let t)):
                await t.finish()
                set(true)
            case .success(.unverified):
                message = AppSettings.shared.t(.plusUnavailable)
            default:
                break // cancelled, or waiting for a parent's Ask to Buy
            }
        } catch {
            message = error.localizedDescription
        }
    }

    func restore() async {
        busy = true
        defer { busy = false }
        try? await AppStore.sync()
        await refresh()
    }

    private func set(_ owned: Bool) {
        isPlus = owned
        UserDefaults.standard.set(owned, forKey: key)
    }
}

/// Settings section: buy once, or restore on a new iPad.
struct PlusSection: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var plus = PlusStore.shared

    var body: some View {
        Section(header: Text("Family Screen Plus"), footer: Text(plus.message.isEmpty ? settings.t(.plusHint) : plus.message)) {
            if plus.isPlus {
                Label(settings.t(.plusOwned), systemImage: "checkmark.seal.fill").foregroundColor(.green)
            } else {
                Button {
                    Task { await plus.buy() }
                } label: {
                    Label(plus.price.isEmpty ? settings.t(.plusBuy) : "\(settings.t(.plusBuy)) · \(plus.price)",
                          systemImage: "sparkles")
                }
                .disabled(plus.busy)
                Button(settings.t(.plusRestore)) { Task { await plus.restore() } }
                    .disabled(plus.busy)
            }
        }
    }
}
