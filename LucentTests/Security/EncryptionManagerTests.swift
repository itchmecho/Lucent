//
//  EncryptionManagerTests.swift
//  LucentTests
//
//  Created by Claude Code on 11/23/2024.
//  Copyright © 2024 Lucent. All rights reserved.
//

import XCTest
import CryptoKit
@testable import Lucent

final class EncryptionManagerTests: XCTestCase {

    var encryptionManager: EncryptionManager!
    var keychainManager: KeychainManager!

    override func setUpWithError() throws {
        try super.setUpWithError()

        // Use a test-specific keychain manager
        keychainManager = KeychainManager(accessGroup: nil)
        encryptionManager = EncryptionManager(keychainManager: keychainManager)

        // Clean up any existing keys
        try? keychainManager.deleteKey()
        encryptionManager.invalidateCache()
    }

    override func tearDownWithError() throws {
        // Clean up after tests
        try? keychainManager.deleteKey()
        encryptionManager.invalidateCache()
        encryptionManager = nil
        keychainManager = nil

        try super.tearDownWithError()
    }

    // MARK: - Data Encryption Tests

    func testEncryptDecryptRoundTrip() throws {
        // Given
        let plaintext = "Hello, Secure World!".data(using: .utf8)!

        // When
        let encrypted = try encryptionManager.encrypt(data: plaintext)
        let decrypted = try encryptionManager.decrypt(data: encrypted)

        // Then
        XCTAssertNotEqual(encrypted, plaintext, "Encrypted data should differ from plaintext")
        XCTAssertEqual(decrypted, plaintext, "Decrypted data should match original plaintext")
    }

    func testEncryptProducesAuthenticatedData() throws {
        // Given
        let plaintext = "Test data".data(using: .utf8)!

        // When
        let encrypted = try encryptionManager.encrypt(data: plaintext)

        // Then
        // AES-GCM combined data includes: nonce (12 bytes) + ciphertext + tag (16 bytes)
        // Minimum size should be 12 + 16 = 28 bytes plus ciphertext
        XCTAssertGreaterThanOrEqual(encrypted.count, 28, "Encrypted data should include nonce and authentication tag")
    }

    func testEncryptDifferentDataProducesDifferentCiphertext() throws {
        // Given
        let plaintext1 = "First message".data(using: .utf8)!
        let plaintext2 = "Second message".data(using: .utf8)!

        // When
        let encrypted1 = try encryptionManager.encrypt(data: plaintext1)
        let encrypted2 = try encryptionManager.encrypt(data: plaintext2)

        // Then
        XCTAssertNotEqual(encrypted1, encrypted2, "Different plaintexts should produce different ciphertexts")
    }

    func testEncryptSameDataProducesDifferentCiphertext() throws {
        // Given
        let plaintext = "Same message".data(using: .utf8)!

        // When
        let encrypted1 = try encryptionManager.encrypt(data: plaintext)
        let encrypted2 = try encryptionManager.encrypt(data: plaintext)

        // Then
        XCTAssertNotEqual(encrypted1, encrypted2, "Same plaintext should produce different ciphertexts due to random nonce")
    }

    func testDecryptInvalidDataThrowsError() throws {
        // Given
        let invalidData = Data(repeating: 0xFF, count: 50)

        // When/Then
        XCTAssertThrowsError(try encryptionManager.decrypt(data: invalidData)) { error in
            XCTAssertTrue(error is EncryptionError, "Should throw EncryptionError")
        }
    }

    func testDecryptTamperedDataThrowsAuthenticationError() throws {
        // Given
        let plaintext = "Original data".data(using: .utf8)!
        var encrypted = try encryptionManager.encrypt(data: plaintext)

        // Tamper with the encrypted data
        if encrypted.count > 10 {
            encrypted[encrypted.count - 5] ^= 0xFF
        }

        // When/Then
        XCTAssertThrowsError(try encryptionManager.decrypt(data: encrypted)) { error in
            if let encError = error as? EncryptionError {
                switch encError {
                case .authenticationFailed, .decryptionFailed:
                    // Expected errors for tampered data
                    break
                default:
                    XCTFail("Expected authentication or decryption failure, got \(encError)")
                }
            } else {
                XCTFail("Expected EncryptionError")
            }
        }
    }

    func testEncryptEmptyData() throws {
        // Given
        let emptyData = Data()

        // When
        let encrypted = try encryptionManager.encrypt(data: emptyData)
        let decrypted = try encryptionManager.decrypt(data: encrypted)

        // Then
        XCTAssertEqual(decrypted, emptyData, "Should handle empty data")
    }

    func testEncryptLargeData() throws {
        // Given
        let largeData = Data(repeating: 0x42, count: 1_000_000) // 1 MB

        // When
        let encrypted = try encryptionManager.encrypt(data: largeData)
        let decrypted = try encryptionManager.decrypt(data: encrypted)

        // Then
        XCTAssertEqual(decrypted, largeData, "Should handle large data")
    }

    // MARK: - File Encryption Tests

    func testEncryptDecryptFile() throws {
        // Given
        let tempDir = FileManager.default.temporaryDirectory
        let sourceURL = tempDir.appendingPathComponent("test-source-\(UUID().uuidString).txt")
        let encryptedURL = tempDir.appendingPathComponent("test-encrypted-\(UUID().uuidString).bin")
        let decryptedURL = tempDir.appendingPathComponent("test-decrypted-\(UUID().uuidString).txt")

        let content = "This is a test file for encryption".data(using: .utf8)!
        try content.write(to: sourceURL)

        defer {
            try? FileManager.default.removeItem(at: sourceURL)
            try? FileManager.default.removeItem(at: encryptedURL)
            try? FileManager.default.removeItem(at: decryptedURL)
        }

        // When
        try encryptionManager.encryptFile(at: sourceURL, to: encryptedURL)
        try encryptionManager.decryptFile(at: encryptedURL, to: decryptedURL)

        // Then
        let decryptedContent = try Data(contentsOf: decryptedURL)
        XCTAssertEqual(decryptedContent, content, "Decrypted file should match original")

        // Verify encrypted file is different
        let encryptedContent = try Data(contentsOf: encryptedURL)
        XCTAssertNotEqual(encryptedContent, content, "Encrypted file should differ from original")
    }

    func testEncryptNonExistentFileThrowsError() throws {
        // Given
        let nonExistentURL = URL(fileURLWithPath: "/nonexistent/path/file.txt")
        let destinationURL = FileManager.default.temporaryDirectory.appendingPathComponent("output.bin")

        // When/Then
        XCTAssertThrowsError(try encryptionManager.encryptFile(at: nonExistentURL, to: destinationURL)) { error in
            guard let encError = error as? EncryptionError else {
                XCTFail("Expected EncryptionError")
                return
            }
            if case .fileReadError = encError {
                // Expected
            } else {
                XCTFail("Expected fileReadError")
            }
        }
    }

    func testDecryptNonExistentFileThrowsError() throws {
        // Given
        let nonExistentURL = URL(fileURLWithPath: "/nonexistent/path/file.bin")
        let destinationURL = FileManager.default.temporaryDirectory.appendingPathComponent("output.txt")

        // When/Then
        XCTAssertThrowsError(try encryptionManager.decryptFile(at: nonExistentURL, to: destinationURL)) { error in
            guard let encError = error as? EncryptionError else {
                XCTFail("Expected EncryptionError")
                return
            }
            if case .fileReadError = encError {
                // Expected
            } else {
                XCTFail("Expected fileReadError")
            }
        }
    }

    // MARK: - Key Management Tests

    func testKeyGenerationAndPersistence() throws {
        // Given
        XCTAssertFalse(encryptionManager.hasKey(), "Should not have key initially")

        // When - First encryption generates and saves key
        let data = "Test".data(using: .utf8)!
        _ = try encryptionManager.encrypt(data: data)

        // Then
        XCTAssertTrue(encryptionManager.hasKey(), "Should have key after first encryption")
    }

    func testKeyPersistenceAcrossInstances() throws {
        // Given
        let data = "Test data".data(using: .utf8)!
        let encrypted = try encryptionManager.encrypt(data: data)

        // When - Create new instance with same keychain manager
        let newManager = EncryptionManager(keychainManager: keychainManager)
        let decrypted = try newManager.decrypt(data: encrypted)

        // Then
        XCTAssertEqual(decrypted, data, "Different instance should use same key from keychain")
    }

    func testDeleteKey() throws {
        // Given
        let data = "Test".data(using: .utf8)!
        _ = try encryptionManager.encrypt(data: data)
        XCTAssertTrue(encryptionManager.hasKey())

        // When
        try encryptionManager.deleteKey()

        // Then
        XCTAssertFalse(encryptionManager.hasKey(), "Key should be deleted")
    }

    func testInvalidateCache() throws {
        // Given
        let data = "Test".data(using: .utf8)!
        _ = try encryptionManager.encrypt(data: data)

        // When
        encryptionManager.invalidateCache()

        // Then - Should still work by retrieving from keychain
        let encrypted = try encryptionManager.encrypt(data: data)
        let decrypted = try encryptionManager.decrypt(data: encrypted)
        XCTAssertEqual(decrypted, data)
    }

    // MARK: - Thread Safety Tests

    func testConcurrentEncryption() throws {
        // Given
        let expectation = XCTestExpectation(description: "Concurrent encryption")
        expectation.expectedFulfillmentCount = 10
        var errors: [Error] = []
        let errorQueue = DispatchQueue(label: "error-queue")

        // When
        DispatchQueue.concurrentPerform(iterations: 10) { index in
            do {
                let data = "Message \(index)".data(using: .utf8)!
                let encrypted = try encryptionManager.encrypt(data: data)
                let decrypted = try encryptionManager.decrypt(data: encrypted)
                XCTAssertEqual(decrypted, data)
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
        XCTAssertTrue(errors.isEmpty, "No errors should occur during concurrent encryption: \(errors)")
    }

    // MARK: - Error Handling Tests

    func testEncryptionErrorDescriptions() {
        let errors: [EncryptionError] = [
            .keyGenerationFailed,
            .keyRetrievalFailed,
            .encryptionFailed,
            .decryptionFailed,
            .invalidData,
            .fileReadError(URL(fileURLWithPath: "/test")),
            .fileWriteError(URL(fileURLWithPath: "/test")),
            .authenticationFailed
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription, "Error should have description: \(error)")
            XCTAssertFalse(error.errorDescription!.isEmpty, "Error description should not be empty")
        }
    }
}
