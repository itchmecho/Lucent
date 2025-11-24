//
//  KeychainManagerTests.swift
//  LucentTests
//
//  Created by Claude Code on 11/23/2024.
//  Copyright © 2024 Lucent. All rights reserved.
//

import XCTest
import CryptoKit
import LocalAuthentication
@testable import Lucent

final class KeychainManagerTests: XCTestCase {

    var keychainManager: KeychainManager!
    let testKeyData = Data(repeating: 0x42, count: 32) // 256-bit test key

    override func setUpWithError() throws {
        try super.setUpWithError()

        // Use default keychain manager for tests
        keychainManager = KeychainManager(accessGroup: nil)

        // Clean up any existing keys
        try? keychainManager.deleteKey()
    }

    override func tearDownWithError() throws {
        // Clean up after tests
        try? keychainManager.deleteKey()
        keychainManager = nil

        try super.tearDownWithError()
    }

    // MARK: - Save/Retrieve Tests

    func testSaveAndRetrieveKey() throws {
        // When
        try keychainManager.saveKey(testKeyData)
        let retrieved = try keychainManager.retrieveKey()

        // Then
        XCTAssertEqual(retrieved, testKeyData, "Retrieved key should match saved key")
    }

    func testSaveOverwritesExistingKey() throws {
        // Given
        try keychainManager.saveKey(testKeyData)

        // When
        let newKeyData = Data(repeating: 0x99, count: 32)
        try keychainManager.saveKey(newKeyData)
        let retrieved = try keychainManager.retrieveKey()

        // Then
        XCTAssertEqual(retrieved, newKeyData, "New key should overwrite old key")
        XCTAssertNotEqual(retrieved, testKeyData, "Old key should be replaced")
    }

    func testRetrieveNonExistentKeyThrowsError() throws {
        // When/Then
        XCTAssertThrowsError(try keychainManager.retrieveKey()) { error in
            guard let keychainError = error as? KeychainError else {
                XCTFail("Expected KeychainError")
                return
            }
            if case .notFound = keychainError {
                // Expected
            } else {
                XCTFail("Expected notFound error, got \(keychainError)")
            }
        }
    }

    func testKeyExists() throws {
        // Given
        XCTAssertFalse(keychainManager.keyExists(), "Key should not exist initially")

        // When
        try keychainManager.saveKey(testKeyData)

        // Then
        XCTAssertTrue(keychainManager.keyExists(), "Key should exist after saving")
    }

    // MARK: - Delete Tests

    func testDeleteKey() throws {
        // Given
        try keychainManager.saveKey(testKeyData)
        XCTAssertTrue(keychainManager.keyExists())

        // When
        try keychainManager.deleteKey()

        // Then
        XCTAssertFalse(keychainManager.keyExists(), "Key should not exist after deletion")
        XCTAssertThrowsError(try keychainManager.retrieveKey())
    }

    func testDeleteNonExistentKeyDoesNotThrow() throws {
        // Given
        XCTAssertFalse(keychainManager.keyExists())

        // When/Then
        XCTAssertNoThrow(try keychainManager.deleteKey(), "Deleting non-existent key should not throw")
    }

    func testDeleteKeyTwiceDoesNotThrow() throws {
        // Given
        try keychainManager.saveKey(testKeyData)

        // When/Then
        try keychainManager.deleteKey()
        XCTAssertNoThrow(try keychainManager.deleteKey(), "Second deletion should not throw")
    }

    // MARK: - Persistence Tests

    func testKeyPersistsAcrossManagerInstances() throws {
        // Given
        try keychainManager.saveKey(testKeyData)

        // When
        let newManager = KeychainManager(accessGroup: nil)
        let retrieved = try newManager.retrieveKey()

        // Then
        XCTAssertEqual(retrieved, testKeyData, "Key should persist across manager instances")

        // Cleanup
        try newManager.deleteKey()
    }

    func testSymmetricKeyRoundTrip() throws {
        // Given
        let symmetricKey = SymmetricKey(size: .bits256)
        let keyData = symmetricKey.withUnsafeBytes { Data($0) }

        // When
        try keychainManager.saveKey(keyData)
        let retrieved = try keychainManager.retrieveKey()
        let retrievedKey = SymmetricKey(data: retrieved)

        // Then - Use keys to encrypt/decrypt to verify they're identical
        let testData = "Test message".data(using: .utf8)!
        let encrypted = try AES.GCM.seal(testData, using: symmetricKey)
        let decrypted = try AES.GCM.open(encrypted, using: retrievedKey)

        XCTAssertEqual(decrypted, testData, "Keys should be functionally identical")
    }

    // MARK: - Biometric Tests

    func testSaveKeyWithBiometricsWhenAvailable() throws {
        // Skip if biometrics not available
        guard KeychainManager.supportsBiometrics() else {
            throw XCTSkip("Biometrics not available on this device")
        }

        // When/Then - Should not throw even if we can't test actual biometric auth
        XCTAssertNoThrow(try keychainManager.saveKeyWithBiometrics(testKeyData))

        // Cleanup
        try keychainManager.deleteKey()
    }

    func testRetrieveKeyWithContext() throws {
        // Given
        try keychainManager.saveKey(testKeyData)
        let context = LAContext()

        // When
        let retrieved = try keychainManager.retrieveKey(context: context)

        // Then
        XCTAssertEqual(retrieved, testKeyData)
    }

    // MARK: - Utility Method Tests

    func testSupportsSecureEnclave() {
        // This will return false on simulator, may return true on device
        let hasSecureEnclave = KeychainManager.supportsSecureEnclave()

        // Just verify it returns a boolean without error
        XCTAssertNotNil(hasSecureEnclave)

        #if targetEnvironment(simulator)
        XCTAssertFalse(hasSecureEnclave, "Simulator should not have Secure Enclave")
        #endif
    }

    func testSupportsBiometrics() {
        // This will vary by device and enrollment status
        let hasBiometrics = KeychainManager.supportsBiometrics()

        // Just verify it returns a boolean without error
        XCTAssertNotNil(hasBiometrics)
    }

    // MARK: - Thread Safety Tests

    func testConcurrentSaveAndRetrieve() throws {
        // Given
        let expectation = XCTestExpectation(description: "Concurrent keychain operations")
        expectation.expectedFulfillmentCount = 10
        var errors: [Error] = []
        let errorQueue = DispatchQueue(label: "error-queue")

        // When - Multiple threads trying to save and retrieve
        DispatchQueue.concurrentPerform(iterations: 10) { index in
            do {
                let keyData = Data(repeating: UInt8(index), count: 32)
                try keychainManager.saveKey(keyData)

                // Verify we can retrieve a key (might be from another thread)
                _ = try keychainManager.retrieveKey()

                expectation.fulfill()
            } catch {
                errorQueue.sync {
                    errors.append(error)
                }
                expectation.fulfill()
            }
        }

        // Then
        wait(for: [expectation], timeout: 5.0)

        // Some operations might conflict but shouldn't crash
        // We just verify at least one successful save happened
        XCTAssertTrue(keychainManager.keyExists(), "At least one key should be saved")
    }

    // MARK: - Error Handling Tests

    func testKeychainErrorDescriptions() {
        let errors: [KeychainError] = [
            .saveFailed(errSecDuplicateItem),
            .retrievalFailed(errSecItemNotFound),
            .deletionFailed(errSecInvalidParameter),
            .notFound,
            .invalidData,
            .biometricAuthFailed,
            .secureEnclaveNotAvailable
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription, "Error should have description: \(error)")
            XCTAssertFalse(error.errorDescription!.isEmpty, "Error description should not be empty")
        }
    }

    // MARK: - Data Integrity Tests

    func testSaveEmptyDataThrowsNoError() throws {
        // Given
        let emptyData = Data()

        // When/Then - Keychain should handle empty data
        XCTAssertNoThrow(try keychainManager.saveKey(emptyData))

        let retrieved = try keychainManager.retrieveKey()
        XCTAssertEqual(retrieved, emptyData)
    }

    func testSaveLargeKey() throws {
        // Given
        let largeKeyData = Data(repeating: 0x42, count: 1024) // 1KB key

        // When
        try keychainManager.saveKey(largeKeyData)
        let retrieved = try keychainManager.retrieveKey()

        // Then
        XCTAssertEqual(retrieved, largeKeyData)
    }

    func testSaveAndRetrieveRandomKeys() throws {
        // Test with multiple random keys
        for _ in 0..<5 {
            // Given
            var randomKeyData = Data(count: 32)
            _ = randomKeyData.withUnsafeMutableBytes { buffer in
                SecRandomCopyBytes(kSecRandomDefault, 32, buffer.baseAddress!)
            }

            // When
            try keychainManager.saveKey(randomKeyData)
            let retrieved = try keychainManager.retrieveKey()

            // Then
            XCTAssertEqual(retrieved, randomKeyData, "Random key should survive round-trip")
        }
    }
}
