import SwiftUI

@main
struct LucentApp: App {
    @StateObject private var appLockManager = AppLockManager.shared

    var body: some Scene {
        WindowGroup {
            ZStack {
                // Main app content
                ContentView()

                // Authentication overlay when app is locked
                if !appLockManager.isAuthenticated && appLockManager.isAppLockEnabled {
                    AuthenticationView(appLockManager: appLockManager)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut, value: appLockManager.isAuthenticated)
        }
    }
}
