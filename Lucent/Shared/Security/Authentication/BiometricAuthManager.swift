//
//  BiometricAuthManager.swift
//  Lucent
//
//  Created by Claude Code on 11/23/24.
//

import Foundation
import LocalAuthentication

/// Errors that can occur during biometric authentication
/// Note: Error descriptions are sanitized to prevent information leakage
enum AuthError: Error, LocalizedError {
    case biometricNotAvailable
    case biometricNotEnrolled
    case authenticationFailed
    case userCancelled
    case systemCancelled
    case passcodeNotSet
    case unknown(Error)

    /// User-facing error description - intentionally generic for security
    var errorDescription: String? {
        switch self {
        case .biometricNotAvailable:
            return "Biometric authentication is not available"
        case .biometricNotEnrolled:
            return "Please set up Face ID or Touch ID in Settings"
        case .authenticationFailed:
            return "Authentication failed"
        case .userCancelled:
            return "Authentication was cancelled"
        case .systemCancelled:
            return "Authentication was interrupted"
        case .passcodeNotSet:
            return "Device passcode is required"
        case .unknown:
            // Don't expose underlying error to users
            return "Authentication error occurred"
        }
    }

    /// Detailed error info for logging (use with privacy: .private)
    var debugDescription: String {
        switch self {
        case .biometricNotAvailable:
            return "LAError.biometryNotAvailable - hardware not present or disabled"
        case .biometricNotEnrolled:
            return "LAError.biometryNotEnrolled - no fingerprints/faces enrolled"
        case .authenticationFailed:
            return "LAError.authenticationFailed - biometric didn't match"
        case .userCancelled:
            return "LAError.userCancel - user tapped cancel"
        case .systemCancelled:
            return "LAError.systemCancel - system interrupted auth"
        case .passcodeNotSet:
            return "LAError.passcodeNotSet - device has no passcode"
        case .unknown(let error):
            return "Unknown LAError: \(error.localizedDescription)"
        }
    }
}

/// Type of biometric authentication available on the device
enum BiometricType {
    case faceID
    case touchID
    case none

    var displayName: String {
        switch self {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .none:
            return "Biometrics"
        }
    }

    var iconName: String {
        switch self {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        case .none:
            return "lock.shield"
        }
    }
}

/// Manages biometric authentication (Face ID/Touch ID) for the app
@MainActor
final class BiometricAuthManager: ObservableObject {

    // MARK: - Properties

    @Published private(set) var biometricType: BiometricType = .none
    @Published private(set) var isBiometricAvailable: Bool = false

    /// Policy for biometric-only authentication
    private let policy: LAPolicy = .deviceOwnerAuthenticationWithBiometrics

    // MARK: - Initialization

    init() {
        checkBiometricAvailability()
    }

    // MARK: - Public Methods

    /// Checks what type of biometric authentication is available
    /// Uses a fresh LAContext each time to get accurate availability status
    func checkBiometricAvailability() {
        // Always create a fresh context - LAContext state can become stale after use
        let context = LAContext()
        var error: NSError?

        isBiometricAvailable = context.canEvaluatePolicy(policy, error: &error)

        if isBiometricAvailable {
            switch context.biometryType {
            case .faceID:
                biometricType = .faceID
            case .touchID:
                biometricType = .touchID
            case .opticID:
                biometricType = .faceID // Treat Optic ID as Face ID for UI purposes
            case .none:
                biometricType = .none
            @unknown default:
                biometricType = .none
            }
        } else {
            biometricType = .none
        }
    }

    /// Authenticates the user with biometrics
    /// - Parameter reason: The reason for authentication shown to the user
    /// - Returns: Result with success boolean or AuthError
    func authenticate(reason: String) async -> Result<Bool, AuthError> {
        // Create a fresh context for each authentication attempt
        let authContext = LAContext()
        authContext.localizedFallbackTitle = "Use Passcode"
        authContext.localizedCancelTitle = "Cancel"

        var error: NSError?

        // Check if biometric authentication is available
        guard authContext.canEvaluatePolicy(policy, error: &error) else {
            if let error = error {
                return .failure(mapAuthError(error))
            }
            return .failure(.biometricNotAvailable)
        }

        do {
            let success = try await authContext.evaluatePolicy(
                policy,
                localizedReason: reason
            )

            if success {
                return .success(true)
            } else {
                return .failure(.authenticationFailed)
            }
        } catch let error as LAError {
            return .failure(mapLAError(error))
        } catch {
            return .failure(.unknown(error))
        }
    }

    /// Authenticates with device owner authentication (includes passcode fallback)
    /// - Parameter reason: The reason for authentication shown to the user
    /// - Returns: Result with success boolean or AuthError
    func authenticateWithFallback(reason: String) async -> Result<Bool, AuthError> {
        let authContext = LAContext()
        authContext.localizedFallbackTitle = "Use Passcode"
        authContext.localizedCancelTitle = "Cancel"

        var error: NSError?

        // Use deviceOwnerAuthentication which includes passcode fallback
        let fallbackPolicy: LAPolicy = .deviceOwnerAuthentication

        guard authContext.canEvaluatePolicy(fallbackPolicy, error: &error) else {
            if let error = error {
                return .failure(mapAuthError(error))
            }
            return .failure(.passcodeNotSet)
        }

        do {
            let success = try await authContext.evaluatePolicy(
                fallbackPolicy,
                localizedReason: reason
            )

            if success {
                return .success(true)
            } else {
                return .failure(.authenticationFailed)
            }
        } catch let error as LAError {
            return .failure(mapLAError(error))
        } catch {
            return .failure(.unknown(error))
        }
    }

    // MARK: - Private Methods

    /// Maps LAError to AuthError
    private func mapLAError(_ error: LAError) -> AuthError {
        switch error.code {
        case .authenticationFailed:
            return .authenticationFailed
        case .userCancel:
            return .userCancelled
        case .systemCancel:
            return .systemCancelled
        case .passcodeNotSet:
            return .passcodeNotSet
        case .biometryNotAvailable:
            return .biometricNotAvailable
        case .biometryNotEnrolled:
            return .biometricNotEnrolled
        default:
            return .unknown(error)
        }
    }

    /// Maps NSError to AuthError
    private func mapAuthError(_ error: NSError) -> AuthError {
        guard let laError = error as? LAError else {
            return .unknown(error)
        }
        return mapLAError(laError)
    }
}
