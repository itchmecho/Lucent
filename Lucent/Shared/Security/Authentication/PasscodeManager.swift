//
//  PasscodeManager.swift
//  Lucent
//
//  Created by Claude Code on 11/23/24.
//

import Foundation
import Security
import CryptoKit

/// Manages passcode storage and verification using Keychain with secure salted hashing
@MainActor
final class PasscodeManager: ObservableObject {

    // MARK: - Properties

    @Published private(set) var isPasscodeSet: Bool = false

    private let keychainService = "com.lucent.app.passcode"
    private let keychainAccount = "userPasscode"

    // Salt size in bytes (32 bytes = 256 bits)
    private let saltSize = 32
    // Derived key size (32 bytes for AES-256 compatibility)
    private let derivedKeySize = 32

    // MARK: - Initialization

    init() {
        checkPasscodeStatus()
    }

    // MARK: - Public Methods

    /// Checks if a passcode is currently set
    func checkPasscodeStatus() {
        isPasscodeSet = retrievePasscodeData() != nil
    }

    /// Sets a new passcode
    /// - Parameter passcode: The passcode to set (will be hashed with salt before storage)
    /// - Returns: True if successful, false otherwise
    @discardableResult
    func setPasscode(_ passcode: String) -> Bool {
        guard !passcode.isEmpty else {
            return false
        }

        // Require 6-8 digit passcode for better security
        guard passcode.count >= 6 && passcode.count <= 8 else {
            return false
        }

        // Validate passcode contains only digits
        guard passcode.allSatisfy({ $0.isNumber }) else {
            return false
        }

        // Generate random salt
        guard let salt = generateSalt() else {
            return false
        }

        // Derive key from passcode using HKDF
        let derivedKey = deriveKey(from: passcode, salt: salt)

        // Combine salt and derived key for storage
        let passcodeData = PasscodeData(salt: salt, derivedKey: derivedKey)

        // Store in keychain
        let success = storePasscodeData(passcodeData)

        if success {
            isPasscodeSet = true
        }

        return success
    }

    /// Verifies a passcode against the stored salted hash
    /// - Parameter passcode: The passcode to verify
    /// - Returns: True if the passcode matches, false otherwise
    func verifyPasscode(_ passcode: String) -> Bool {
        guard let storedData = retrievePasscodeData() else {
            return false
        }

        // Derive key from input passcode using stored salt
        let inputDerivedKey = deriveKey(from: passcode, salt: storedData.salt)

        // Constant-time comparison to prevent timing attacks
        return constantTimeCompare(inputDerivedKey, storedData.derivedKey)
    }

    /// Removes the stored passcode
    /// - Returns: True if successful or if no passcode was set, false otherwise
    @discardableResult
    func removePasscode() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]

        let status = SecItemDelete(query as CFDictionary)

        if status == errSecSuccess || status == errSecItemNotFound {
            isPasscodeSet = false
            return true
        }

        return false
    }

    // MARK: - Private Methods

    /// Generates a cryptographically secure random salt
    /// - Returns: Random salt data, or nil if generation fails
    private func generateSalt() -> Data? {
        var saltData = Data(count: saltSize)
        let result = saltData.withUnsafeMutableBytes { buffer in
            guard let baseAddress = buffer.baseAddress else { return errSecParam }
            return SecRandomCopyBytes(kSecRandomDefault, saltSize, baseAddress)
        }

        guard result == errSecSuccess else {
            return nil
        }

        return saltData
    }

    /// Derives a key from passcode using HKDF (HMAC-based Key Derivation Function)
    /// - Parameters:
    ///   - passcode: The user's passcode
    ///   - salt: Random salt for key derivation
    /// - Returns: Derived key data
    private func deriveKey(from passcode: String, salt: Data) -> Data {
        let passcodeData = Data(passcode.utf8)

        // Use HKDF with SHA-256
        let inputKeyMaterial = SymmetricKey(data: passcodeData)
        let derivedKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: inputKeyMaterial,
            salt: salt,
            info: Data("com.lucent.passcode".utf8),
            outputByteCount: derivedKeySize
        )

        return derivedKey.withUnsafeBytes { Data($0) }
    }

    /// Performs constant-time comparison to prevent timing attacks
    /// - Parameters:
    ///   - lhs: First data to compare
    ///   - rhs: Second data to compare
    /// - Returns: True if data is equal, false otherwise
    private func constantTimeCompare(_ lhs: Data, _ rhs: Data) -> Bool {
        guard lhs.count == rhs.count else { return false }

        var result: UInt8 = 0
        for (byte1, byte2) in zip(lhs, rhs) {
            result |= byte1 ^ byte2
        }

        return result == 0
    }

    /// Stores passcode data (salt + derived key) in the keychain
    /// - Parameter passcodeData: The passcode data to store
    /// - Returns: True if successful, false otherwise
    private func storePasscodeData(_ passcodeData: PasscodeData) -> Bool {
        // First, delete any existing passcode
        removePasscode()

        // Encode passcode data as JSON
        let encoder = JSONEncoder()
        guard let encodedData = try? encoder.encode(passcodeData) else {
            return false
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: encodedData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Retrieves passcode data (salt + derived key) from the keychain
    /// - Returns: The passcode data if found, nil otherwise
    private func retrievePasscodeData() -> PasscodeData? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data else {
            return nil
        }

        // Decode passcode data from JSON
        let decoder = JSONDecoder()
        return try? decoder.decode(PasscodeData.self, from: data)
    }
}

// MARK: - PasscodeData Structure

/// Structure to store salt and derived key together
private struct PasscodeData: Codable {
    let salt: Data
    let derivedKey: Data
}
