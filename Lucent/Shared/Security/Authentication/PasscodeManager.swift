//
//  PasscodeManager.swift
//  Lucent
//
//  Created by Claude Code on 11/23/24.
//

import Foundation
import Security
import CryptoKit

/// Manages passcode storage and verification using Keychain
@MainActor
final class PasscodeManager: ObservableObject {

    // MARK: - Properties

    @Published private(set) var isPasscodeSet: Bool = false

    private let keychainService = "com.lucent.app.passcode"
    private let keychainAccount = "userPasscode"

    // MARK: - Initialization

    init() {
        checkPasscodeStatus()
    }

    // MARK: - Public Methods

    /// Checks if a passcode is currently set
    func checkPasscodeStatus() {
        isPasscodeSet = retrieveHashedPasscode() != nil
    }

    /// Sets a new passcode
    /// - Parameter passcode: The passcode to set (will be hashed before storage)
    /// - Returns: True if successful, false otherwise
    @discardableResult
    func setPasscode(_ passcode: String) -> Bool {
        guard !passcode.isEmpty else {
            return false
        }

        guard passcode.count >= 4 && passcode.count <= 6 else {
            return false
        }

        // Hash the passcode before storing
        let hashedPasscode = hashPasscode(passcode)

        // Store in keychain
        let success = storeHashedPasscode(hashedPasscode)

        if success {
            isPasscodeSet = true
        }

        return success
    }

    /// Verifies a passcode against the stored hash
    /// - Parameter passcode: The passcode to verify
    /// - Returns: True if the passcode matches, false otherwise
    func verifyPasscode(_ passcode: String) -> Bool {
        guard let storedHash = retrieveHashedPasscode() else {
            return false
        }

        let inputHash = hashPasscode(passcode)
        return inputHash == storedHash
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

    /// Hashes a passcode using SHA-256
    /// - Parameter passcode: The passcode to hash
    /// - Returns: The hashed passcode as a hex string
    private func hashPasscode(_ passcode: String) -> String {
        let inputData = Data(passcode.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Stores a hashed passcode in the keychain
    /// - Parameter hashedPasscode: The hashed passcode to store
    /// - Returns: True if successful, false otherwise
    private func storeHashedPasscode(_ hashedPasscode: String) -> Bool {
        // First, delete any existing passcode
        removePasscode()

        // Create keychain item
        let passcodeData = Data(hashedPasscode.utf8)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: passcodeData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Retrieves the hashed passcode from the keychain
    /// - Returns: The hashed passcode if found, nil otherwise
    private func retrieveHashedPasscode() -> String? {
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
              let data = result as? Data,
              let hashedPasscode = String(data: data, encoding: .utf8) else {
            return nil
        }

        return hashedPasscode
    }
}
