//
//  BiometricAuthManager.swift
//  Lucent
//
//  Created by Claude Code on 11/23/24.
//

import Foundation
import LocalAuthentication

/// Errors that can occur during biometric authentication
enum AuthError: Error, LocalizedError {
    case biometricNotAvailable
    case biometricNotEnrolled
    case authenticationFailed
    case userCancelled
    case systemCancelled
    case passcodeNotSet
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .biometricNotAvailable:
            return "Biometric authentication is not available on this device"
        case .biometricNotEnrolled:
            return "No biometric authentication is enrolled. Please set up Face ID or Touch ID in Settings"
        case .authenticationFailed:
            return "Authentication failed. Please try again"
        case .userCancelled:
            return "Authentication was cancelled"
        case .systemCancelled:
            return "Authentication was cancelled by the system"
        case .passcodeNotSet:
            return "Device passcode is not set"
        case .unknown(let error):
            return "An unknown error occurred: \(error.localizedDescription)"
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

    private let context = LAContext()
    private let policy: LAPolicy = .deviceOwnerAuthenticationWithBiometrics

    // MARK: - Initialization

    init() {
        checkBiometricAvailability()
    }

    // MARK: - Public Methods

    /// Checks what type of biometric authentication is available
    func checkBiometricAvailability() {
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
