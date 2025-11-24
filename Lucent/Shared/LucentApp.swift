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
                // TODO: Re-enable authentication after adding setup flow
                // Temporarily disabled for testing
                /*
                if !appLockManager.isAuthenticated && appLockManager.isAppLockEnabled {
                    AuthenticationView(appLockManager: appLockManager)
                        .transition(.opacity)
                }
                */
            }
            .animation(.easeInOut, value: appLockManager.isAuthenticated)
        }
    }
}
