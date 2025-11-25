//
//  KeychainManager.swift
//  Lucent
//
//  Created by Claude Code on 11/23/2024.
//  Copyright © 2024 Lucent. All rights reserved.
//

import Foundation
import Security
import LocalAuthentication
import OSLog

/// Errors that can occur during keychain operations
/// Note: Error descriptions are sanitized to prevent information leakage
public enum KeychainError: LocalizedError {
    case saveFailed(OSStatus)
    case retrievalFailed(OSStatus)
    case deletionFailed(OSStatus)
    case notFound
    case invalidData
    case biometricAuthFailed
    case secureEnclaveNotAvailable

    /// User-facing error description - intentionally generic for security
    public var errorDescription: String? {
        switch self {
        case .saveFailed:
            // Don't expose OSStatus codes to users
            return "Failed to save secure data"
        case .retrievalFailed:
            // Don't expose OSStatus codes to users
            return "Failed to retrieve secure data"
        case .deletionFailed:
            // Don't expose OSStatus codes to users
            return "Failed to delete secure data"
        case .notFound:
            return "Secure data not found"
        case .invalidData:
            return "Invalid secure data"
        case .biometricAuthFailed:
            return "Biometric authentication required"
        case .secureEnclaveNotAvailable:
            return "Secure storage not available"
        }
    }

    /// Detailed error info for logging (use with privacy: .private)
    var debugDescription: String {
        switch self {
        case .saveFailed(let status):
            return "Keychain save failed with OSStatus: \(status)"
        case .retrievalFailed(let status):
            return "Keychain retrieval failed with OSStatus: \(status)"
        case .deletionFailed(let status):
            return "Keychain deletion failed with OSStatus: \(status)"
        case .notFound:
            return "Keychain item not found (errSecItemNotFound)"
        case .invalidData:
            return "Keychain returned invalid data type"
        case .biometricAuthFailed:
            return "SecAccessControl creation with biometry flag failed"
        case .secureEnclaveNotAvailable:
            return "Secure Enclave not available on this device/simulator"
        }
    }
}

/// Thread-safe keychain manager for secure storage of encryption keys
///
/// This class manages encryption keys in the iOS/macOS Keychain with support for:
/// - Secure Enclave when available
/// - Biometric authentication protection
/// - Maximum security access controls
///
/// Thread Safety: This class uses an internal serial DispatchQueue to synchronize
/// all mutable state access. The `@unchecked Sendable` conformance is valid because
/// all operations are synchronized through `queue.sync`. This is preferred over
/// converting to an actor because keychain operations are blocking and should not
/// require async/await at call sites.
///
/// Example usage:
/// ```swift
/// let manager = KeychainManager.shared
/// let key = SymmetricKey(size: .bits256)
/// let keyData = key.withUnsafeBytes { Data($0) }
/// try manager.saveKey(keyData)
/// let retrieved = try manager.retrieveKey()
/// ```
public final class KeychainManager: @unchecked Sendable {
    // Note: @unchecked Sendable is valid because all mutable state access is
    // synchronized through self.queue (a serial DispatchQueue)

    // MARK: - Properties

    /// Shared singleton instance
    public static let shared = KeychainManager()

    private let logger = Logger(subsystem: "com.lucent.security", category: "keychain")

    /// Serial queue for thread-safe operations
    private let queue = DispatchQueue(label: "com.lucent.keychain", qos: .userInitiated)

    /// Keychain service identifier
    private let service = "com.lucent.encryption"

    /// Key identifier for the encryption key
    private let keyIdentifier = "master-encryption-key"

    /// Access group for keychain sharing (optional)
    private let accessGroup: String?

    // MARK: - Initialization

    /// Initialize with optional access group for keychain sharing
    /// - Parameter accessGroup: Optional keychain access group for app group sharing
    public init(accessGroup: String? = nil) {
        self.accessGroup = accessGroup
    }

    // MARK: - Key Storage

    /// Saves an encryption key to the keychain
    ///
    /// The key is stored with maximum security settings:
    /// - Accessible only when device is unlocked
    /// - Only accessible on this device (not synced via iCloud)
    /// - Protected by Secure Enclave when available
    ///
    /// - Parameter keyData: The encryption key data to save
    /// - Throws: KeychainError if save operation fails
    public func saveKey(_ keyData: Data) throws {
        try queue.sync {
            logger.info("Saving encryption key to keychain")

            // Delete existing key if present
            try? deleteKeyInternal()

            // Build query
            var query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: keyIdentifier,
                kSecValueData as String: keyData,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            ]

            // Add access group if specified
            if let accessGroup = accessGroup {
                query[kSecAttrAccessGroup as String] = accessGroup
            }

            // Add to keychain
            let status = SecItemAdd(query as CFDictionary, nil)

            guard status == errSecSuccess else {
                logger.error("Failed to save key to keychain: \(status)")
                throw KeychainError.saveFailed(status)
            }

            logger.info("Successfully saved encryption key to keychain")
        }
    }

    /// Saves an encryption key with biometric authentication protection
    ///
    /// The key will require Face ID/Touch ID to access
    ///
    /// - Parameters:
    ///   - keyData: The encryption key data to save
    ///   - context: LAContext for biometric authentication (optional)
    /// - Throws: KeychainError if save operation fails
    public func saveKeyWithBiometrics(_ keyData: Data, context: LAContext? = nil) throws {
        try queue.sync {
            logger.info("Saving encryption key with biometric protection")

            // Delete existing key if present
            try? deleteKeyInternal()

            // Create access control
            var error: Unmanaged<CFError>?
            guard let accessControl = SecAccessControlCreateWithFlags(
                kCFAllocatorDefault,
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                [.biometryCurrentSet],
                &error
            ) else {
                if let error = error?.takeRetainedValue() {
                    logger.error("Failed to create access control: \(error)")
                }
                throw KeychainError.biometricAuthFailed
            }

            // Build query
            var query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: keyIdentifier,
                kSecValueData as String: keyData,
                kSecAttrAccessControl as String: accessControl
            ]

            // Add access group if specified
            if let accessGroup = accessGroup {
                query[kSecAttrAccessGroup as String] = accessGroup
            }

            // Add authentication context if provided
            if let context = context {
                query[kSecUseAuthenticationContext as String] = context
            }

            // Add to keychain
            let status = SecItemAdd(query as CFDictionary, nil)

            guard status == errSecSuccess else {
                logger.error("Failed to save key with biometrics: \(status)")
                throw KeychainError.saveFailed(status)
            }

            logger.info("Successfully saved encryption key with biometric protection")
        }
    }

    // MARK: - Key Retrieval

    /// Retrieves the encryption key from the keychain
    ///
    /// - Parameter context: Optional LAContext for biometric authentication
    /// - Returns: The encryption key data
    /// - Throws: KeychainError if retrieval fails
    public func retrieveKey(context: LAContext? = nil) throws -> Data {
        try queue.sync {
            logger.debug("Retrieving encryption key from keychain")

            // Build query
            var query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: keyIdentifier,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne
            ]

            // Add access group if specified
            if let accessGroup = accessGroup {
                query[kSecAttrAccessGroup as String] = accessGroup
            }

            // Add authentication context if provided
            if let context = context {
                query[kSecUseAuthenticationContext as String] = context
            }

            // Retrieve from keychain
            var result: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &result)

            switch status {
            case errSecSuccess:
                guard let keyData = result as? Data else {
                    logger.error("Invalid data type retrieved from keychain")
                    throw KeychainError.invalidData
                }
                logger.debug("Successfully retrieved encryption key")
                return keyData

            case errSecItemNotFound:
                logger.debug("Encryption key not found in keychain")
                throw KeychainError.notFound

            default:
                logger.error("Failed to retrieve key from keychain: \(status)")
                throw KeychainError.retrievalFailed(status)
            }
        }
    }

    // MARK: - Key Deletion

    /// Deletes the encryption key from the keychain
    /// - Throws: KeychainError if deletion fails
    public func deleteKey() throws {
        try queue.sync {
            try deleteKeyInternal()
        }
    }

    /// Internal deletion method (must be called on queue)
    private func deleteKeyInternal() throws {
        logger.info("Deleting encryption key from keychain")

        // Build query
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: keyIdentifier
        ]

        // Add access group if specified
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        // Delete from keychain
        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            logger.error("Failed to delete key from keychain: \(status)")
            throw KeychainError.deletionFailed(status)
        }

        logger.info("Successfully deleted encryption key from keychain")
    }

    // MARK: - Utility Methods

    /// Checks if an encryption key exists in the keychain
    /// - Returns: true if a key exists, false otherwise
    public func keyExists() -> Bool {
        return (try? retrieveKey()) != nil
    }

    /// Checks if the device supports Secure Enclave
    /// - Returns: true if Secure Enclave is available
    public static func supportsSecureEnclave() -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        // Check if device has Secure Enclave by attempting to create a private key
        var error: Unmanaged<CFError>?
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave
        ]

        guard SecKeyCreateRandomKey(attributes as CFDictionary, &error) != nil else {
            return false
        }
        return true
        #endif
    }

    /// Checks if the device supports biometric authentication
    /// - Returns: true if Face ID or Touch ID is available and enrolled
    public static func supportsBiometrics() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
}
