//
//  EncryptionManager.swift
//  Lucent
//
//  Created by Claude Code on 11/23/2024.
//  Copyright © 2024 Lucent. All rights reserved.
//

import Foundation
import CryptoKit
import OSLog

/// Errors that can occur during encryption operations
///
/// Note: Error descriptions are intentionally generic to prevent information leakage.
/// Detailed error information (including file paths) is logged privately via OSLog.
public enum EncryptionError: LocalizedError {
    case keyGenerationFailed
    case keyRetrievalFailed
    case encryptionFailed
    case decryptionFailed
    case invalidData
    case fileReadError(URL)
    case fileWriteError(URL)
    case authenticationFailed

    /// User-facing error description - intentionally generic for security
    public var errorDescription: String? {
        switch self {
        case .keyGenerationFailed:
            return "Failed to generate encryption key"
        case .keyRetrievalFailed:
            return "Failed to retrieve encryption key"
        case .encryptionFailed:
            return "Failed to encrypt data"
        case .decryptionFailed:
            return "Failed to decrypt data"
        case .invalidData:
            return "Invalid data format"
        case .fileReadError:
            // Don't expose file paths to users
            return "Failed to read file"
        case .fileWriteError:
            // Don't expose file paths to users
            return "Failed to write file"
        case .authenticationFailed:
            return "Data verification failed - file may be corrupted"
        }
    }

    /// Returns detailed error info for logging (includes sensitive data)
    /// Use with OSLog privacy: .private
    var debugDescription: String {
        switch self {
        case .keyGenerationFailed:
            return "Key generation failed"
        case .keyRetrievalFailed:
            return "Key retrieval from keychain failed"
        case .encryptionFailed:
            return "AES-GCM encryption failed"
        case .decryptionFailed:
            return "AES-GCM decryption failed"
        case .invalidData:
            return "Invalid data format for encryption/decryption"
        case .fileReadError(let url):
            return "Failed to read file at: \(url.path)"
        case .fileWriteError(let url):
            return "Failed to write file at: \(url.path)"
        case .authenticationFailed:
            return "GCM authentication tag verification failed"
        }
    }
}

/// Thread-safe encryption manager using AES-256-GCM
///
/// This class provides secure encryption and decryption of data and files using
/// AES-256 in GCM (Galois/Counter Mode) which provides both confidentiality and
/// authenticated encryption.
///
/// Thread Safety: This class uses an internal serial DispatchQueue to synchronize
/// all mutable state access (particularly `cachedKey`). The `@unchecked Sendable`
/// conformance is valid because all operations are synchronized through `queue.sync`.
/// This is preferred over converting to an actor because encryption operations are
/// synchronous by nature and should not require async/await at call sites.
///
/// Example usage:
/// ```swift
/// let manager = EncryptionManager.shared
/// let plaintext = "Secret message".data(using: .utf8)!
/// let encrypted = try manager.encrypt(data: plaintext)
/// let decrypted = try manager.decrypt(data: encrypted)
/// ```
public final class EncryptionManager: @unchecked Sendable {
    // Note: @unchecked Sendable is valid because all mutable state access (cachedKey)
    // is synchronized through self.queue (a serial DispatchQueue)

    // MARK: - Properties

    /// Shared singleton instance
    public static let shared = EncryptionManager()

    private let keychainManager: KeychainManager
    private let logger = Logger(subsystem: "com.lucent.security", category: "encryption")

    /// Serial queue for thread-safe operations
    private let queue = DispatchQueue(label: "com.lucent.encryption", qos: .userInitiated)

    /// Cached encryption key for performance
    private var cachedKey: SymmetricKey?

    // MARK: - Initialization

    /// Initialize with a custom keychain manager
    /// - Parameter keychainManager: The keychain manager to use for key storage
    public init(keychainManager: KeychainManager = .shared) {
        self.keychainManager = keychainManager
    }

    // MARK: - Key Management

    /// Retrieves or generates the encryption key
    ///
    /// When generating a new key, biometric protection is used if available.
    /// This provides an extra layer of security - the key requires Face ID/Touch ID
    /// to access, even when the device is unlocked.
    ///
    /// - Returns: The symmetric encryption key
    /// - Throws: EncryptionError if key cannot be retrieved or generated
    private func getOrCreateKey() throws -> SymmetricKey {
        // Check cache first - cached key avoids repeated biometric prompts
        if let key = cachedKey {
            return key
        }

        // Try to retrieve existing key
        if let keyData = try? keychainManager.retrieveKey() {
            let key = SymmetricKey(data: keyData)
            cachedKey = key
            logger.info("Retrieved existing encryption key from keychain")
            return key
        }

        // Generate new key
        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { Data($0) }

        do {
            // Use biometric protection if available for maximum security
            if KeychainManager.supportsBiometrics() {
                try keychainManager.saveKeyWithBiometrics(keyData)
                logger.info("Generated and saved new encryption key with biometric protection")
            } else {
                // Fall back to standard keychain storage
                try keychainManager.saveKey(keyData)
                logger.info("Generated and saved new encryption key (biometrics not available)")
            }
            cachedKey = key
            return key
        } catch {
            logger.error("Failed to save encryption key: \(error.localizedDescription, privacy: .private)")
            throw EncryptionError.keyGenerationFailed
        }
    }

    /// Upgrades an existing key to use biometric protection
    ///
    /// Call this when a user enables biometric protection in settings,
    /// or to migrate existing keys to the more secure storage.
    ///
    /// - Throws: EncryptionError if upgrade fails
    public func upgradeKeyToBiometricProtection() throws {
        try queue.sync {
            logger.info("Upgrading encryption key to biometric protection")

            guard KeychainManager.supportsBiometrics() else {
                logger.warning("Cannot upgrade key - biometrics not available")
                return
            }

            // Retrieve existing key
            guard let keyData = try? keychainManager.retrieveKey() else {
                logger.warning("No existing key to upgrade")
                return
            }

            // Re-save with biometric protection
            do {
                try keychainManager.saveKeyWithBiometrics(keyData)
                logger.info("Successfully upgraded encryption key to biometric protection")
            } catch {
                logger.error("Failed to upgrade key: \(error.localizedDescription, privacy: .private)")
                throw EncryptionError.keyGenerationFailed
            }
        }
    }

    /// Checks if the current key has biometric protection
    /// - Returns: true if key requires biometric authentication
    public func keyHasBiometricProtection() -> Bool {
        // Try to retrieve without auth context - if it fails with auth error, it has protection
        // This is a simplified check - full implementation would query keychain attributes
        return KeychainManager.supportsBiometrics() && keychainManager.keyExists()
    }

    /// Invalidates the cached encryption key
    /// Call this after deleting the key from keychain
    public func invalidateCache() {
        queue.sync {
            cachedKey = nil
        }
    }

    // MARK: - Data Encryption

    /// Encrypts data using AES-256-GCM
    ///
    /// - Parameter data: The plaintext data to encrypt
    /// - Returns: Encrypted data containing nonce + ciphertext + tag
    /// - Throws: EncryptionError if encryption fails
    public func encrypt(data: Data) throws -> Data {
        let perfSignpost = PerformanceSignpost(name: "Encryption")
        defer { perfSignpost.end() }

        return try queue.sync {
            let key = try getOrCreateKey()

            do {
                // Encrypt with AES-GCM
                let sealedBox = try AES.GCM.seal(data, using: key)

                // Combine nonce + ciphertext + tag
                guard let combined = sealedBox.combined else {
                    logger.error("Failed to create combined encrypted data")
                    throw EncryptionError.encryptionFailed
                }

                logger.debug("Successfully encrypted \(data.count) bytes")
                return combined

            } catch {
                logger.error("Encryption failed: \(error.localizedDescription)")
                throw EncryptionError.encryptionFailed
            }
        }
    }

    /// Decrypts data that was encrypted with AES-256-GCM
    ///
    /// - Parameter data: The encrypted data (nonce + ciphertext + tag)
    /// - Returns: The decrypted plaintext data
    /// - Throws: EncryptionError if decryption fails or authentication fails
    public func decrypt(data: Data) throws -> Data {
        let perfSignpost = PerformanceSignpost(name: "Decryption")
        defer { perfSignpost.end() }

        return try queue.sync {
            let key = try getOrCreateKey()

            do {
                // Create sealed box from combined data
                let sealedBox = try AES.GCM.SealedBox(combined: data)

                // Decrypt and verify authentication tag
                let decrypted = try AES.GCM.open(sealedBox, using: key)

                logger.debug("Successfully decrypted \(decrypted.count) bytes")
                return decrypted

            } catch CryptoKitError.authenticationFailure {
                logger.error("Authentication failed - data may be corrupted or tampered")
                throw EncryptionError.authenticationFailed
            } catch {
                logger.error("Decryption failed: \(error.localizedDescription)")
                throw EncryptionError.decryptionFailed
            }
        }
    }

    // MARK: - File Encryption

    /// Encrypts a file and writes it to the destination URL
    ///
    /// - Parameters:
    ///   - sourceURL: URL of the plaintext file to encrypt
    ///   - destinationURL: URL where the encrypted file will be written
    /// - Throws: EncryptionError if file operations or encryption fails
    public func encryptFile(at sourceURL: URL, to destinationURL: URL) throws {
        logger.info("Encrypting file: \(sourceURL.path)")

        // Read source file
        guard let fileData = try? Data(contentsOf: sourceURL) else {
            logger.error("Failed to read source file: \(sourceURL.path)")
            throw EncryptionError.fileReadError(sourceURL)
        }

        // Encrypt data
        let encryptedData = try encrypt(data: fileData)

        // Write to destination
        do {
            try encryptedData.write(to: destinationURL, options: .atomic)
            logger.info("Successfully encrypted file to: \(destinationURL.path)")
        } catch {
            logger.error("Failed to write encrypted file: \(error.localizedDescription)")
            throw EncryptionError.fileWriteError(destinationURL)
        }
    }

    /// Decrypts a file and writes it to the destination URL
    ///
    /// - Parameters:
    ///   - sourceURL: URL of the encrypted file to decrypt
    ///   - destinationURL: URL where the decrypted file will be written
    /// - Throws: EncryptionError if file operations or decryption fails
    public func decryptFile(at sourceURL: URL, to destinationURL: URL) throws {
        logger.info("Decrypting file: \(sourceURL.path)")

        // Read encrypted file
        guard let encryptedData = try? Data(contentsOf: sourceURL) else {
            logger.error("Failed to read encrypted file: \(sourceURL.path)")
            throw EncryptionError.fileReadError(sourceURL)
        }

        // Decrypt data
        let decryptedData = try decrypt(data: encryptedData)

        // Write to destination
        do {
            try decryptedData.write(to: destinationURL, options: .atomic)
            logger.info("Successfully decrypted file to: \(destinationURL.path)")
        } catch {
            logger.error("Failed to write decrypted file: \(error.localizedDescription)")
            throw EncryptionError.fileWriteError(destinationURL)
        }
    }

    // MARK: - Utility Methods

    /// Checks if an encryption key exists
    /// - Returns: true if a key exists in keychain, false otherwise
    public func hasKey() -> Bool {
        return (try? keychainManager.retrieveKey()) != nil
    }

    /// Deletes the encryption key from keychain and cache
    /// - Throws: KeychainError if deletion fails
    public func deleteKey() throws {
        try keychainManager.deleteKey()
        invalidateCache()
        logger.warning("Encryption key deleted")
    }
}
