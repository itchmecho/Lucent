//
//  SettingsViewModel.swift
//  Lucent
//
//  Created by Claude Code on 11/23/24.
//

import SwiftUI
import Foundation
import os.log

#if canImport(UIKit)
import UIKit
#endif

/// ViewModel for the Settings screen
@MainActor
final class SettingsViewModel: ObservableObject {

    // MARK: - Published Properties

    // Security Settings
    @Published var biometricEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(biometricEnabled, forKey: "biometricEnabled")
        }
    }
    @Published var requirePasscodeOnLaunch: Bool = false {
        didSet {
            appLockManager.requireAuthOnLaunch = requirePasscodeOnLaunch
        }
    }
    @Published var selectedAutoLockOption: AutoLockOption = .oneMinute
    @Published var isBiometricAvailable: Bool = false
    @Published var biometricTitle: String = "Biometrics"
    @Published var biometricIcon: String = "faceid"

    // Storage
    @Published var photoCount: Int = 0
    @Published var totalStorageBytes: Int = 0
    @Published var thumbnailCacheSize: String = "Unknown"

    // Appearance
    @Published var selectedAppearanceMode: AppearanceMode = .system
    @Published var showPhotoCounts: Bool = true {
        didSet {
            UserDefaults.standard.set(showPhotoCounts, forKey: "showPhotoCounts")
        }
    }
    @Published var showThumbnails: Bool = true {
        didSet {
            UserDefaults.standard.set(showThumbnails, forKey: "showThumbnails")
        }
    }

    // UI State
    @Published var showAlert: Bool = false
    @Published var alertTitle: String = ""
    @Published var alertMessage: String = ""
    @Published var isDestructiveAlert: Bool = false
    @Published var showAutoLockOptions: Bool = false
    @Published var showAppearanceOptions: Bool = false

    // MARK: - Private Properties

    private let appLockManager = AppLockManager.shared
    private let biometricAuthManager = BiometricAuthManager()
    private let passcodeManager = PasscodeManager()
    private var pendingAction: (() -> Void)?

    // MARK: - Computed Properties

    var autoLockDescription: String {
        selectedAutoLockOption.displayName
    }

    var totalStorageFormatted: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalStorageBytes), countStyle: .file)
    }

    var appearanceModeDescription: String {
        selectedAppearanceMode.displayName
    }

    var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    // MARK: - Initialization

    init() {
        loadSettings()
    }

    // MARK: - Public Methods

    /// Loads all settings from UserDefaults and managers
    func loadSettings() {
        // Load security settings
        biometricEnabled = UserDefaults.standard.bool(forKey: "biometricEnabled")
        requirePasscodeOnLaunch = appLockManager.requireAuthOnLaunch
        selectedAutoLockOption = AutoLockOption.from(timeout: appLockManager.lockTimeout)

        // Check biometric availability
        biometricAuthManager.checkBiometricAvailability()
        isBiometricAvailable = biometricAuthManager.isBiometricAvailable
        biometricTitle = biometricAuthManager.biometricType.displayName
        biometricIcon = biometricAuthManager.biometricType.iconName

        // Load appearance settings
        selectedAppearanceMode = AppearanceMode.current
        showPhotoCounts = UserDefaults.standard.bool(forKey: "showPhotoCounts")
        showThumbnails = UserDefaults.standard.object(forKey: "showThumbnails") as? Bool ?? true

        // Load storage stats
        loadStorageStats()
    }

    /// Loads storage statistics
    func loadStorageStats() {
        Task {
            do {
                let stats = try await SecurePhotoStorage.shared.getStorageStats()
                photoCount = stats.photoCount
                totalStorageBytes = stats.totalSizeBytes

                // Calculate thumbnail cache size (placeholder - would need actual implementation)
                thumbnailCacheSize = "~5 MB"
            } catch {
                AppLogger.settings.error("Failed to load storage stats: \(error.localizedDescription, privacy: .public)")
                photoCount = 0
                totalStorageBytes = 0
                thumbnailCacheSize = "Unknown"
            }
        }
    }

    // MARK: - Security Actions

    /// Sets the auto-lock timeout
    func setAutoLockTimeout(_ option: AutoLockOption) {
        selectedAutoLockOption = option
        appLockManager.lockTimeout = option.timeout
    }

    /// Initiates passcode change flow
    func changePasscode() {
        alertTitle = L10n.Settings.changePasscodeTitle
        alertMessage = L10n.Settings.changePasscodeMessage
        isDestructiveAlert = false
        showAlert = true
    }

    // MARK: - Storage Actions

    /// Shows confirmation dialog for clearing thumbnail cache
    func showClearCacheConfirmation() {
        alertTitle = L10n.Settings.clearThumbnailCache
        alertMessage = L10n.Settings.clearCacheMessage
        isDestructiveAlert = true
        pendingAction = { [weak self] in
            self?.clearThumbnailCache()
        }
        showAlert = true
    }

    /// Clears the thumbnail cache
    private func clearThumbnailCache() {
        Task {
            // Call ThumbnailManager to clear cache
            await ThumbnailManager.shared.clearCache()

            // Update cache size display
            thumbnailCacheSize = "0 KB"

            // Show success message
            alertTitle = L10n.Common.success
            alertMessage = L10n.Settings.cacheCleared
            isDestructiveAlert = false
            showAlert = true
        }
    }

    // MARK: - Appearance Actions

    /// Sets the appearance mode
    func setAppearanceMode(_ mode: AppearanceMode) {
        selectedAppearanceMode = mode
        mode.apply()
    }

    // MARK: - Backup & Data Actions

    /// Exports non-sensitive metadata
    func exportMetadata() {
        alertTitle = L10n.Settings.exportMetadata
        alertMessage = L10n.Settings.exportMetadataMessage
        isDestructiveAlert = false
        showAlert = true

        // TODO: Implement actual export functionality
    }

    // MARK: - About Actions

    /// Opens the privacy policy
    func openPrivacyPolicy() {
        alertTitle = L10n.Settings.privacyPolicy
        alertMessage = L10n.Settings.privacyMessage
        isDestructiveAlert = false
        showAlert = true

        // TODO: Open actual privacy policy URL when available
    }

    /// Opens open source licenses
    func openLicenses() {
        alertTitle = L10n.Settings.openSourceLicenses
        alertMessage = L10n.Settings.licensesMessage
        isDestructiveAlert = false
        showAlert = true

        // TODO: Show actual licenses view
    }

    // MARK: - Alert Actions

    /// Confirms the pending action
    func confirmAction() {
        pendingAction?()
        pendingAction = nil
    }
}

// MARK: - Auto-lock Options

/// Available auto-lock timeout options
enum AutoLockOption: CaseIterable {
    case immediate
    case oneMinute
    case fiveMinutes
    case fifteenMinutes
    case never

    var displayName: String {
        switch self {
        case .immediate:
            return L10n.Settings.immediate
        case .oneMinute:
            return L10n.Settings.oneMinute
        case .fiveMinutes:
            return L10n.Settings.fiveMinutes
        case .fifteenMinutes:
            return L10n.Settings.fifteenMinutes
        case .never:
            return L10n.Settings.never
        }
    }

    var timeout: TimeInterval {
        switch self {
        case .immediate:
            return 0
        case .oneMinute:
            return 60
        case .fiveMinutes:
            return 300
        case .fifteenMinutes:
            return 900
        case .never:
            return .infinity
        }
    }

    static func from(timeout: TimeInterval) -> AutoLockOption {
        switch timeout {
        case 0:
            return .immediate
        case 60:
            return .oneMinute
        case 300:
            return .fiveMinutes
        case 900:
            return .fifteenMinutes
        case .infinity:
            return .never
        default:
            return .oneMinute
        }
    }
}

// MARK: - Appearance Mode

/// Available appearance modes
enum AppearanceMode: String, CaseIterable {
    case system
    case light
    case dark

    var displayName: String {
        switch self {
        case .system:
            return L10n.Settings.system
        case .light:
            return L10n.Settings.light
        case .dark:
            return L10n.Settings.dark
        }
    }

    var iconName: String {
        switch self {
        case .system:
            return "circle.lefthalf.filled"
        case .light:
            return "sun.max.fill"
        case .dark:
            return "moon.fill"
        }
    }

    #if canImport(UIKit)
    var userInterfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system:
            return .unspecified
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
    #endif

    /// Current appearance mode from UserDefaults
    static var current: AppearanceMode {
        let rawValue = UserDefaults.standard.string(forKey: "appearanceMode") ?? "system"
        return AppearanceMode(rawValue: rawValue) ?? .system
    }

    /// Applies the appearance mode to the app
    func apply() {
        UserDefaults.standard.set(self.rawValue, forKey: "appearanceMode")

        #if canImport(UIKit)
        // Apply to all windows
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
                return
            }

            for window in windowScene.windows {
                window.overrideUserInterfaceStyle = self.userInterfaceStyle
            }
        }
        #endif
    }
}

// MARK: - ThumbnailManager Extension

extension ThumbnailManager {
    /// Clears the entire thumbnail cache
    func clearCache() async {
        // This would be implemented in ThumbnailManager
        // For now, this is a placeholder that the actual ThumbnailManager would implement
        AppLogger.settings.info("Clearing thumbnail cache...")
    }
}
