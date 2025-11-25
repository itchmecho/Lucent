//
//  PrivacyProtectionManager.swift
//  Lucent
//
//  Created by Claude Code on 11/24/24.
//

import Foundation
import SwiftUI
import Combine
import os.log

#if canImport(UIKit)
import UIKit
#endif

/// Manages privacy protection features like app preview blur and screenshot detection
@MainActor
final class PrivacyProtectionManager: ObservableObject {

    // MARK: - Singleton

    static let shared = PrivacyProtectionManager()

    // MARK: - Published Properties

    /// Whether the privacy screen should be shown (app in background/switcher)
    @Published var showPrivacyScreen: Bool = false

    /// Whether screenshot protection is enabled
    @Published var screenshotProtectionEnabled: Bool {
        didSet {
            UserDefaults.standard.set(screenshotProtectionEnabled, forKey: screenshotProtectionKey)
        }
    }

    /// Whether app preview blur is enabled
    @Published var appPreviewBlurEnabled: Bool {
        didSet {
            UserDefaults.standard.set(appPreviewBlurEnabled, forKey: appPreviewBlurKey)
        }
    }

    /// Last screenshot detection timestamp
    @Published var lastScreenshotDetected: Date?

    /// Whether to show screenshot warning alert
    @Published var showScreenshotWarning: Bool = false

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private let screenshotProtectionKey = "screenshotProtectionEnabled"
    private let appPreviewBlurKey = "appPreviewBlurEnabled"

    #if canImport(UIKit)
    private var privacyWindow: UIWindow?
    #endif

    // MARK: - Initialization

    private init() {
        // Load settings from UserDefaults (default to enabled for security)
        self.screenshotProtectionEnabled = UserDefaults.standard.object(forKey: screenshotProtectionKey) as? Bool ?? true
        self.appPreviewBlurEnabled = UserDefaults.standard.object(forKey: appPreviewBlurKey) as? Bool ?? true

        setupObservers()
    }

    // MARK: - Setup

    private func setupObservers() {
        #if os(iOS)
        // App lifecycle notifications for privacy screen
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                self?.handleAppWillResignActive()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.handleAppDidBecomeActive()
            }
            .store(in: &cancellables)

        // Screenshot detection
        NotificationCenter.default.publisher(for: UIApplication.userDidTakeScreenshotNotification)
            .sink { [weak self] _ in
                self?.handleScreenshotDetected()
            }
            .store(in: &cancellables)

        #elseif os(macOS)
        // macOS notifications
        NotificationCenter.default.publisher(for: NSApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                self?.handleAppWillResignActive()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.handleAppDidBecomeActive()
            }
            .store(in: &cancellables)
        #endif
    }

    // MARK: - App Lifecycle Handlers

    private func handleAppWillResignActive() {
        guard appPreviewBlurEnabled else { return }

        AppLogger.security.info("App resigning active - showing privacy screen")
        showPrivacyScreen = true

        #if os(iOS)
        showPrivacyWindow()
        #endif
    }

    private func handleAppDidBecomeActive() {
        AppLogger.security.info("App became active - hiding privacy screen")
        showPrivacyScreen = false

        #if os(iOS)
        hidePrivacyWindow()
        #endif
    }

    // MARK: - Screenshot Detection

    private func handleScreenshotDetected() {
        guard screenshotProtectionEnabled else { return }

        AppLogger.security.warning("Screenshot detected!")
        lastScreenshotDetected = Date()
        showScreenshotWarning = true

        // Trigger haptic feedback
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
        #endif
    }

    /// Dismisses the screenshot warning
    func dismissScreenshotWarning() {
        showScreenshotWarning = false
    }

    // MARK: - Privacy Window (iOS)

    #if os(iOS)
    private func showPrivacyWindow() {
        guard privacyWindow == nil else { return }

        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first else {
            return
        }

        let window = UIWindow(windowScene: windowScene)
        window.windowLevel = .alert + 1
        window.backgroundColor = .clear

        let hostingController = UIHostingController(rootView: PrivacyScreenView())
        hostingController.view.backgroundColor = .clear
        window.rootViewController = hostingController
        window.isHidden = false

        privacyWindow = window
    }

    private func hidePrivacyWindow() {
        privacyWindow?.isHidden = true
        privacyWindow = nil
    }
    #endif
}

// MARK: - Privacy Screen View

/// The privacy screen shown when app is in multitasking view
struct PrivacyScreenView: View {
    var body: some View {
        ZStack {
            // Blur background
            Color.black
                .opacity(0.95)
                .ignoresSafeArea()

            // Frosted glass effect
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            // App branding
            VStack(spacing: 24) {
                // App icon placeholder
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 100, height: 100)

                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.white.opacity(0.9))
                }

                Text("Lucent")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                Text("Content Hidden")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }
}

// MARK: - Screenshot Warning View

/// Alert view shown when a screenshot is detected
struct ScreenshotWarningView: View {
    @ObservedObject var privacyManager = PrivacyProtectionManager.shared

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 48))
                .foregroundStyle(Color.warning)

            Text("Screenshot Detected")
                .font(.title2)
                .fontWeight(.bold)

            Text("A screenshot of this app was captured. Your encrypted photos remain secure, but please be mindful of sharing screenshots.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("I Understand") {
                privacyManager.dismissScreenshotWarning()
            }
            .buttonStyle(.borderedProminent)
            .tint(.lucentAccent)
        }
        .padding(32)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
        }
        .padding(40)
    }
}

// MARK: - Preview

#Preview("Privacy Screen") {
    PrivacyScreenView()
}

#Preview("Screenshot Warning") {
    ScreenshotWarningView()
}
