import SwiftUI

@main
struct LucentApp: App {
    @StateObject private var appLockManager = AppLockManager.shared
    @StateObject private var privacyManager = PrivacyProtectionManager.shared
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

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

                // Privacy screen overlay for app switcher (SwiftUI layer)
                if privacyManager.showPrivacyScreen && privacyManager.appPreviewBlurEnabled {
                    PrivacyScreenView()
                        .transition(.opacity)
                }

                // Screenshot warning overlay
                if privacyManager.showScreenshotWarning {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            privacyManager.dismissScreenshotWarning()
                        }

                    ScreenshotWarningView()
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: appLockManager.isAuthenticated)
            .animation(.easeInOut(duration: 0.15), value: privacyManager.showPrivacyScreen)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: privacyManager.showScreenshotWarning)
            .fullScreenCover(isPresented: .constant(!hasCompletedOnboarding)) {
                SecuritySetupView(appLockManager: appLockManager) {
                    hasCompletedOnboarding = true
                }
            }
        }
    }
}
