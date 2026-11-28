import SwiftUI
import UIKit
#if APPLE_SERVICES
import CloudKit
#endif

@main
struct FamilyScreenApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            // The app now shows the home-clock web pages (WebDashboard.swift).
            // The native SwiftUI screens (DashboardView, PhoneHomeView) stay in the
            // project so key pages can move back to native later.
            WebRootView()
                .preferredColorScheme(.dark)
                .onAppear {
                    // Keep the wall screen on. A phone sleeps as usual.
                    UIApplication.shared.isIdleTimerDisabled = UIDevice.current.userInterfaceIdiom != .phone
                }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}

/// Receives the invite link when the other home taps it.
final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        #if APPLE_SERVICES
        if let metadata = connectionOptions.cloudKitShareMetadata { accept(metadata) }
        #endif
    }

    #if APPLE_SERVICES
    func windowScene(_ windowScene: UIWindowScene, userDidAcceptCloudKitShareWith metadata: CKShare.Metadata) {
        accept(metadata)
    }

    private func accept(_ metadata: CKShare.Metadata) {
        Task { @MainActor in
            let store = FamilyStore.shared
            do {
                try await store.cloud.accept(metadata)
                store.resetLocal()
                await store.refresh()
            } catch {
                store.syncStatus = error.localizedDescription
            }
        }
    }
    #endif
}
