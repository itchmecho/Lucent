//
//  AppLockManager.swift
//  Lucent
//
//  Created by Claude Code on 11/23/24.
//

import Foundation
import SwiftUI
import Combine
import os.log

/// Manages app locking and authentication state
@MainActor
final class AppLockManager: ObservableObject {

    // MARK: - Singleton

    static let shared = AppLockManager()

    // MARK: - Published Properties

    /// Whether the user is currently authenticated
    @Published var isAuthenticated: Bool = false

    /// Whether app lock is enabled
    @Published var isAppLockEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isAppLockEnabled, forKey: appLockEnabledKey)
        }
    }

    /// Whether to require authentication on app launch
    @Published var requireAuthOnLaunch: Bool {
        didSet {
            UserDefaults.standard.set(requireAuthOnLaunch, forKey: requireAuthOnLaunchKey)
        }
    }

    /// Time interval (in seconds) before requiring re-authentication
    @Published var lockTimeout: TimeInterval {
        didSet {
            UserDefaults.standard.set(lockTimeout, forKey: lockTimeoutKey)
        }
    }

    // MARK: - Private Properties

    private let biometricAuthManager = BiometricAuthManager()
    private let passcodeManager = PasscodeManager()

    private var cancellables = Set<AnyCancellable>()
    private var backgroundDate: Date?

    private let appLockEnabledKey = "appLockEnabled"
    private let requireAuthOnLaunchKey = "requireAuthOnLaunch"
    private let lockTimeoutKey = "lockTimeout"
    private let lastAuthenticationKey = "lastAuthenticationDate"
    private let failedAttemptsKey = "authFailedAttempts"
    private let lockoutUntilKey = "authLockoutUntil"

    // Rate limiting settings
    private let maxAttempts = 5
    private let lockoutDuration: TimeInterval = 300 // 5 minutes

    // MARK: - Initialization

    private init() {
        // Load settings from UserDefaults
        self.isAppLockEnabled = UserDefaults.standard.bool(forKey: appLockEnabledKey)
        self.requireAuthOnLaunch = UserDefaults.standard.bool(forKey: requireAuthOnLaunchKey)
        self.lockTimeout = UserDefaults.standard.double(forKey: lockTimeoutKey)

        // Default timeout to 1 minute if not set
        if lockTimeout == 0 {
            lockTimeout = 60
        }

        setupAppLifecycleObservers()
    }

    // MARK: - Public Methods

    /// Attempts to authenticate the user with biometrics or passcode
    /// - Parameter reason: The reason for authentication
    /// - Returns: True if authentication was successful
    @discardableResult
    func authenticate(reason: String = "Unlock Lucent") async -> Bool {
        // Check if currently locked out
        if isLockedOut() {
            return false
        }

        // Try biometric authentication first if available
        if biometricAuthManager.isBiometricAvailable {
            let result = await biometricAuthManager.authenticateWithFallback(reason: reason)

            switch result {
            case .success:
                isAuthenticated = true
                saveLastAuthenticationDate()
                resetFailedAttempts()
                AppLogger.auth.info("Biometric authentication successful")
                return true
            case .failure(let error):
                AppLogger.auth.warning("Biometric authentication failed: \(error.localizedDescription)")
                recordFailedAttempt()
                return false
            }
        } else {
            // Biometrics not available - user must use passcode
            // This would be handled by the PasscodeView
            return false
        }
    }

    /// Locks the app immediately
    func lockApp() {
        isAuthenticated = false
    }

    /// Checks if authentication is required based on time elapsed
    func shouldRequireAuthentication() -> Bool {
        guard isAppLockEnabled else {
            return false
        }

        // Always require auth on launch if enabled
        if requireAuthOnLaunch && !isAuthenticated {
            return true
        }

        // Check if timeout has elapsed
        guard let lastAuthDate = getLastAuthenticationDate() else {
            return true
        }

        let elapsed = Date().timeIntervalSince(lastAuthDate)
        return elapsed >= lockTimeout
    }

    /// Enables app lock with the specified settings
    func enableAppLock(requireOnLaunch: Bool = true, timeout: TimeInterval = 60) {
        isAppLockEnabled = true
        requireAuthOnLaunch = requireOnLaunch
        lockTimeout = timeout
    }

    /// Disables app lock
    func disableAppLock() {
        isAppLockEnabled = false
        isAuthenticated = true
    }

    // MARK: - Private Methods

    /// Sets up observers for app lifecycle events
    private func setupAppLifecycleObservers() {
        #if os(iOS)
        // iOS notifications
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

        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.handleAppDidEnterBackground()
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

        NotificationCenter.default.publisher(for: NSApplication.didHideNotification)
            .sink { [weak self] _ in
                self?.handleAppDidEnterBackground()
            }
            .store(in: &cancellables)
        #endif
    }

    /// Called when the app will resign active state
    private func handleAppWillResignActive() {
        guard isAppLockEnabled else { return }
        backgroundDate = Date()
    }

    /// Called when the app becomes active
    private func handleAppDidBecomeActive() {
        guard isAppLockEnabled else { return }

        if shouldRequireAuthentication() {
            isAuthenticated = false
        }
    }

    /// Called when the app enters background
    private func handleAppDidEnterBackground() {
        guard isAppLockEnabled else { return }

        // Lock the app when entering background
        backgroundDate = Date()

        // Lock immediately if timeout is 0
        if lockTimeout == 0 {
            isAuthenticated = false
        }
    }

    /// Saves the current date as the last authentication date
    private func saveLastAuthenticationDate() {
        UserDefaults.standard.set(Date(), forKey: lastAuthenticationKey)
    }

    /// Retrieves the last authentication date
    private func getLastAuthenticationDate() -> Date? {
        return UserDefaults.standard.object(forKey: lastAuthenticationKey) as? Date
    }

    // MARK: - Rate Limiting

    /// Records a failed authentication attempt
    func recordFailedAttempt() {
        let currentAttempts = getFailedAttempts()
        let newAttempts = currentAttempts + 1

        UserDefaults.standard.set(newAttempts, forKey: failedAttemptsKey)

        // Apply lockout if max attempts exceeded
        if newAttempts >= maxAttempts {
            let lockoutDate = Date().addingTimeInterval(lockoutDuration)
            UserDefaults.standard.set(lockoutDate, forKey: lockoutUntilKey)
        }
    }

    /// Resets failed authentication attempts
    func resetFailedAttempts() {
        UserDefaults.standard.removeObject(forKey: failedAttemptsKey)
        UserDefaults.standard.removeObject(forKey: lockoutUntilKey)
    }

    /// Gets the current number of failed attempts
    func getFailedAttempts() -> Int {
        return UserDefaults.standard.integer(forKey: failedAttemptsKey)
    }

    /// Checks if the user is currently locked out
    func isLockedOut() -> Bool {
        guard let lockoutDate = UserDefaults.standard.object(forKey: lockoutUntilKey) as? Date else {
            return false
        }

        // Check if lockout has expired
        if Date() >= lockoutDate {
            // Lockout expired, reset attempts
            resetFailedAttempts()
            return false
        }

        return true
    }

    /// Gets remaining lockout time in seconds
    func getRemainingLockoutTime() -> TimeInterval {
        guard let lockoutDate = UserDefaults.standard.object(forKey: lockoutUntilKey) as? Date else {
            return 0
        }

        let remaining = lockoutDate.timeIntervalSince(Date())
        return max(0, remaining)
    }

    /// Gets the number of remaining attempts before lockout
    func getRemainingAttempts() -> Int {
        return max(0, maxAttempts - getFailedAttempts())
    }
}
