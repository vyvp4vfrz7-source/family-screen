import SwiftUI
import UIKit

/// Home Clock: Billy's own app. It shows the home-clock web pages full screen
/// (see WebDashboard.swift). The native Family Screen app is a separate target.
@main
struct HomeClockApp: App {
    var body: some Scene {
        WindowGroup {
            WebRootView()
                .preferredColorScheme(.dark)
                .onAppear {
                    // Keep the wall screen on. A phone sleeps as usual.
                    UIApplication.shared.isIdleTimerDisabled = UIDevice.current.userInterfaceIdiom != .phone
                }
        }
    }
}
