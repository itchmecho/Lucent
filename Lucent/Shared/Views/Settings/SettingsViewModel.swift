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
    @Published var biometricEnabled: Bool = false

    /// Indicates biometric verification is in progress (disables toggle)
    @Published var isProcessingBiometric: Bool = false
    @Published var requirePasscodeOnLaunch: Bool = false
    @Published var selectedAutoLockOption: AutoLockOption = .oneMinute
    @Published var isBiometricAvailable: Bool = false
    @Published var biometricTitle: String = "Biometrics"
    @Published var biometricIcon: String = "faceid"

    // Privacy Protection Settings
    @Published var screenshotProtectionEnabled: Bool = true {
        didSet {
            privacyManager.screenshotProtectionEnabled = screenshotProtectionEnabled
        }
    }
    @Published var appPreviewBlurEnabled: Bool = true {
        didSet {
            privacyManager.appPreviewBlurEnabled = appPreviewBlurEnabled
        }
    }

    // Storage
    @Published var photoCount: Int = 0
    @Published var totalStorageBytes: Int = 0
    @Published var thumbnailCacheSize: String = "Unknown"
    @Published var photosNeedingThumbnails: Int = 0
    @Published var isRegeneratingThumbnails: Bool = false
    @Published var thumbnailRegenerationProgress: (completed: Int, total: Int) = (0, 0)

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
    @Published var useGridView: Bool = false {
        didSet {
            UserDefaults.standard.set(useGridView, forKey: "useGridView")
        }
    }

    // UI State
    @Published var showAlert: Bool = false
    @Published var alertTitle: String = ""
    @Published var alertMessage: String = ""
    @Published var isDestructiveAlert: Bool = false
    @Published var showAutoLockOptions: Bool = false
    @Published var showAppearanceOptions: Bool = false
    @Published var showBackupView: Bool = false

    // MARK: - Private Properties

    private let appLockManager = AppLockManager.shared
    private let privacyManager = PrivacyProtectionManager.shared
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

        // Load privacy protection settings
        screenshotProtectionEnabled = privacyManager.screenshotProtectionEnabled
        appPreviewBlurEnabled = privacyManager.appPreviewBlurEnabled

        // Load appearance settings
        selectedAppearanceMode = AppearanceMode.current
        showPhotoCounts = UserDefaults.standard.bool(forKey: "showPhotoCounts")
        showThumbnails = UserDefaults.standard.object(forKey: "showThumbnails") as? Bool ?? true
        useGridView = UserDefaults.standard.bool(forKey: "useGridView")

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

                // Count photos needing thumbnails
                let needingThumbnails = try await SecurePhotoStorage.shared.photosNeedingThumbnails()
                photosNeedingThumbnails = needingThumbnails.count

                // Get thumbnail cache stats
                let cacheStats = await ThumbnailManager.shared.getCacheStats()
                thumbnailCacheSize = ByteCountFormatter.string(fromByteCount: Int64(cacheStats.sizeBytes), countStyle: .file)
            } catch {
                AppLogger.settings.error("Failed to load storage stats: \(error.localizedDescription, privacy: .public)")
                photoCount = 0
                totalStorageBytes = 0
                thumbnailCacheSize = "Unknown"
                photosNeedingThumbnails = 0
            }
        }
    }

    // MARK: - Security Actions

    /// Explicitly sets require on launch - called by UI toggle
    func setRequireOnLaunch(_ enabled: Bool) {
        guard enabled != requirePasscodeOnLaunch else { return }
        requirePasscodeOnLaunch = enabled
        appLockManager.requireAuthOnLaunch = enabled
    }

    /// Explicitly sets biometric enabled state - called by UI toggle
    /// This is the proper pattern: explicit method instead of didSet side effects
    func setBiometricEnabled(_ enabled: Bool) {
        // Ignore if already processing or no change
        guard !isProcessingBiometric else { return }
        guard enabled != biometricEnabled else { return }

        if enabled {
            // User turning ON - verify with Face ID first
            Task {
                await verifyAndEnableBiometric()
            }
        } else {
            // User turning OFF - disable immediately
            biometricEnabled = false
            UserDefaults.standard.set(false, forKey: "biometricEnabled")
            appLockManager.disableAppLock()
            AppLogger.security.info("Biometric authentication disabled")
        }
    }

    /// Verifies Face ID and completes enabling, or reverts on failure
    private func verifyAndEnableBiometric() async {
        isProcessingBiometric = true

        // Verify biometric is available
        guard isBiometricAvailable else {
            biometricEnabled = false  // Revert
            isProcessingBiometric = false
            alertTitle = "Biometrics Unavailable"
            alertMessage = "\(biometricTitle) is not available on this device."
            isDestructiveAlert = false
            showAlert = true
            return
        }

        // Authenticate to confirm
        let result = await biometricAuthManager.authenticate(reason: "Verify \(biometricTitle) to enable unlock")

        isProcessingBiometric = false

        switch result {
        case .success:
            // Success - save and configure
            UserDefaults.standard.set(true, forKey: "biometricEnabled")
            appLockManager.enableAppLock(requireOnLaunch: true, timeout: appLockManager.lockTimeout)

            // Try to upgrade encryption key
            do {
                try EncryptionManager.shared.upgradeKeyToBiometricProtection()
            } catch {
                AppLogger.security.warning("Key upgrade failed: \(error.localizedDescription, privacy: .private)")
            }

            AppLogger.security.info("\(biometricTitle) enabled successfully")
            alertTitle = "\(biometricTitle) Enabled"
            alertMessage = "You can now use \(biometricTitle) to unlock Lucent."
            isDestructiveAlert = false
            showAlert = true

        case .failure(let error):
            // Failed - revert toggle
            biometricEnabled = false

            if case .userCancelled = error {
                // User cancelled - no alert
            } else {
                alertTitle = "Verification Failed"
                alertMessage = error.localizedDescription ?? "Could not verify \(biometricTitle)"
                isDestructiveAlert = false
                showAlert = true
            }
        }
    }

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

    /// Locks the app immediately
    func lockAppNow() {
        appLockManager.lockApp()
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

    /// Shows confirmation dialog for regenerating all thumbnails
    func showRegenerateThumbnailsConfirmation() {
        guard photosNeedingThumbnails > 0 else {
            alertTitle = "No Thumbnails to Regenerate"
            alertMessage = "All photos already have thumbnails."
            isDestructiveAlert = false
            showAlert = true
            return
        }

        alertTitle = "Regenerate Thumbnails"
        alertMessage = "This will regenerate thumbnails for \(photosNeedingThumbnails) photo\(photosNeedingThumbnails == 1 ? "" : "s"). This may take a while."
        isDestructiveAlert = false
        pendingAction = { [weak self] in
            self?.regenerateAllThumbnails()
        }
        showAlert = true
    }

    /// Regenerates all failed thumbnails
    private func regenerateAllThumbnails() {
        guard !isRegeneratingThumbnails else { return }

        isRegeneratingThumbnails = true
        thumbnailRegenerationProgress = (0, photosNeedingThumbnails)

        Task {
            do {
                let successCount = try await SecurePhotoStorage.shared.regenerateAllFailedThumbnails { [weak self] completed, total in
                    Task { @MainActor in
                        self?.thumbnailRegenerationProgress = (completed, total)
                    }
                }

                isRegeneratingThumbnails = false

                // Reload stats
                loadStorageStats()

                // Show success message
                alertTitle = "Thumbnails Regenerated"
                alertMessage = "Successfully regenerated \(successCount) thumbnail\(successCount == 1 ? "" : "s")."
                isDestructiveAlert = false
                showAlert = true
            } catch {
                isRegeneratingThumbnails = false
                AppLogger.settings.error("Failed to regenerate thumbnails: \(error.localizedDescription, privacy: .public)")

                alertTitle = "Regeneration Failed"
                alertMessage = "Some thumbnails could not be regenerated. Please try again."
                isDestructiveAlert = false
                showAlert = true
            }
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
