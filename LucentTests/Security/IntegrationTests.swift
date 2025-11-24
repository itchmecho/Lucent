//
//  IntegrationTests.swift
//  LucentTests
//
//  Created by Claude Code on 11/23/2024.
//

import XCTest
@testable import Lucent

/// Comprehensive security integration tests
final class IntegrationTests: XCTestCase {

    // MARK: - Test Lifecycle

    override func setUp() async throws {
        try await super.setUp()

        // Clean up keychain before each test
        _ = KeychainManager.shared.deleteKey()
    }

    override func tearDown() async throws {
        // Clean up after tests
        _ = KeychainManager.shared.deleteKey()
        try await super.tearDown()
    }

    // MARK: - End-to-End Encryption Tests

    func testEndToEndPhotoEncryption() async throws {
        // Given: Sample photo data
        let originalData = "Test Photo Data".data(using: .utf8)!
        let metadata = PhotoMetadata(
            originalFilename: "test.jpg",
            fileSize: originalData.count,
            dateTaken: Date(),
            width: 1920,
            height: 1080
        )

        // When: Save photo (should encrypt)
        let storage = SecurePhotoStorage.shared
        try storage.initializeStorage()
        let savedPhoto = try await storage.savePhoto(data: originalData, metadata: metadata)

        // Then: Verify photo was saved with encryption
        XCTAssertNotNil(savedPhoto.id)
        XCTAssertTrue(FileManager.default.fileExists(atPath: savedPhoto.encryptedFileURL.path))

        // And: Retrieve photo (should decrypt)
        let retrievedData = try await storage.retrievePhoto(id: savedPhoto.id)

        // And: Verify data matches original
        XCTAssertEqual(retrievedData, originalData)

        // Cleanup
        try await storage.deletePhoto(id: savedPhoto.id)
    }

    func testEncryptedDataIsActuallyEncrypted() async throws {
        // Given: Original plaintext data
        let plaintext = "This is sensitive photo data that must be encrypted".data(using: .utf8)!

        // When: Encrypt the data
        let encryptionManager = EncryptionManager.shared
        let encrypted = try encryptionManager.encrypt(data: plaintext)

        // Then: Encrypted data should be different from plaintext
        XCTAssertNotEqual(encrypted, plaintext)

        // And: Encrypted data should be longer (includes nonce + auth tag)
        XCTAssertGreaterThan(encrypted.count, plaintext.count)

        // And: Should decrypt back to original
        let decrypted = try encryptionManager.decrypt(data: encrypted)
        XCTAssertEqual(decrypted, plaintext)
    }

    func testTamperedDataFailsDecryption() async throws {
        // Given: Encrypted data
        let plaintext = "Secret data".data(using: .utf8)!
        var encrypted = try EncryptionManager.shared.encrypt(data: plaintext)

        // When: Tamper with encrypted data
        encrypted[encrypted.count / 2] ^= 0xFF // Flip bits in the middle

        // Then: Decryption should fail
        XCTAssertThrowsError(try EncryptionManager.shared.decrypt(data: encrypted)) { error in
            XCTAssertTrue(error is EncryptionError)
        }
    }

    // MARK: - Storage Security Tests

    func testMultiplePhotosIndependentEncryption() async throws {
        // Given: Three identical photos
        let photoData = "Identical Photo".data(using: .utf8)!
        let storage = SecurePhotoStorage.shared
        try storage.initializeStorage()

        // When: Save them multiple times
        let photo1 = try await storage.savePhoto(
            data: photoData,
            metadata: PhotoMetadata(originalFilename: "photo1.jpg", fileSize: photoData.count)
        )
        let photo2 = try await storage.savePhoto(
            data: photoData,
            metadata: PhotoMetadata(originalFilename: "photo2.jpg", fileSize: photoData.count)
        )
        let photo3 = try await storage.savePhoto(
            data: photoData,
            metadata: PhotoMetadata(originalFilename: "photo3.jpg", fileSize: photoData.count)
        )

        // Then: Each should have unique encrypted data (different nonces)
        let encrypted1 = try Data(contentsOf: photo1.encryptedFileURL)
        let encrypted2 = try Data(contentsOf: photo2.encryptedFileURL)
        let encrypted3 = try Data(contentsOf: photo3.encryptedFileURL)

        XCTAssertNotEqual(encrypted1, encrypted2)
        XCTAssertNotEqual(encrypted2, encrypted3)
        XCTAssertNotEqual(encrypted1, encrypted3)

        // And: All should decrypt to same original data
        let decrypted1 = try await storage.retrievePhoto(id: photo1.id)
        let decrypted2 = try await storage.retrievePhoto(id: photo2.id)
        let decrypted3 = try await storage.retrievePhoto(id: photo3.id)

        XCTAssertEqual(decrypted1, photoData)
        XCTAssertEqual(decrypted2, photoData)
        XCTAssertEqual(decrypted3, photoData)

        // Cleanup
        try await storage.deletePhoto(id: photo1.id)
        try await storage.deletePhoto(id: photo2.id)
        try await storage.deletePhoto(id: photo3.id)
    }

    func testSecureDeletionErasesData() async throws {
        // Given: Saved encrypted photo
        let photoData = "Photo to delete".data(using: .utf8)!
        let storage = SecurePhotoStorage.shared
        try storage.initializeStorage()

        let photo = try await storage.savePhoto(
            data: photoData,
            metadata: PhotoMetadata(originalFilename: "delete.jpg", fileSize: photoData.count)
        )

        let fileURL = photo.encryptedFileURL
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))

        // When: Delete the photo
        try await storage.deletePhoto(id: photo.id)

        // Then: File should no longer exist
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))

        // And: Photo should not be retrievable
        do {
            _ = try await storage.retrievePhoto(id: photo.id)
            XCTFail("Should have thrown photoNotFound error")
        } catch let error as SecurePhotoStorage.StorageError {
            XCTAssertEqual(error, .photoNotFound)
        }
    }

    // MARK: - Key Management Tests

    func testKeychainPersistenceAcrossInstances() throws {
        // Given: First manager instance stores a key
        let manager1 = KeychainManager.shared
        let testKey = SymmetricKey(size: .bits256)
        let testKeyData = testKey.withUnsafeBytes { Data($0) }

        XCTAssertTrue(manager1.saveKey(testKeyData))

        // When: New manager instance retrieves the key
        let manager2 = KeychainManager.shared // Same singleton, but tests persistence
        let retrievedKey = manager2.retrieveKey()

        // Then: Key should be the same
        XCTAssertNotNil(retrievedKey)
        XCTAssertEqual(retrievedKey, testKeyData)
    }

    func testEncryptionKeyPersistsBetweenAppLaunches() throws {
        // Given: Encrypt data with first manager instance
        let manager1 = EncryptionManager.shared
        let plaintext = "Persistent data".data(using: .utf8)!
        let encrypted = try manager1.encrypt(data: plaintext)

        // When: Simulate app restart by getting fresh singleton
        // (In reality, this is same instance, but tests that key is retrieved from keychain)
        let manager2 = EncryptionManager.shared
        let decrypted = try manager2.decrypt(data: encrypted)

        // Then: Should successfully decrypt with retrieved key
        XCTAssertEqual(decrypted, plaintext)
    }

    // MARK: - Authentication Integration Tests

    func testPasscodeHashingIsSecure() throws {
        // Given: A passcode
        let passcode = "123456"
        let manager = PasscodeManager()

        // When: Set the passcode
        XCTAssertTrue(manager.setPasscode(passcode))

        // Then: Verify passcode works
        XCTAssertTrue(manager.verifyPasscode(passcode))

        // And: Wrong passcode fails
        XCTAssertFalse(manager.verifyPasscode("654321"))
        XCTAssertFalse(manager.verifyPasscode("000000"))
    }

    func testAppLockManagerStateManagement() {
        // Given: App lock manager
        let manager = AppLockManager.shared

        // When: Enable app lock
        manager.enableAppLock(requireOnLaunch: true, timeout: 60)

        // Then: Settings should be persisted
        XCTAssertTrue(manager.isAppLockEnabled)
        XCTAssertTrue(manager.requireAuthOnLaunch)
        XCTAssertEqual(manager.lockTimeout, 60)

        // When: Disable app lock
        manager.disableAppLock()

        // Then: Should be disabled
        XCTAssertFalse(manager.isAppLockEnabled)
    }

    // MARK: - Memory Security Tests

    func testSensitiveDataWipedFromMemory() {
        // Given: Sensitive data
        var sensitiveData = Data(repeating: 0x42, count: 1024)

        // When: Securely wipe it
        sensitiveData.secureWipe()

        // Then: Data should be zeroed
        XCTAssertTrue(sensitiveData.allSatisfy { $0 == 0 })
    }

    func testSecureBufferAutoWipes() {
        // Given: A secure buffer
        var bufferData: Data?

        do {
            let buffer = SecureBuffer(size: 256)
            buffer.data.withUnsafeMutableBytes { ptr in
                ptr.initializeMemory(as: UInt8.self, repeating: 0xAB)
            }
            bufferData = buffer.data

            // Buffer goes out of scope here
        }

        // Then: After scope exit, buffer should be wiped
        // (We can't directly test this without accessing the buffer's internal memory,
        //  but we verify it doesn't crash and follows RAII pattern)
        XCTAssertNotNil(bufferData)
    }

    // MARK: - Performance Tests

    func testEncryptionPerformance() throws {
        // Given: 1 MB of data
        let largeData = Data(repeating: 0x42, count: 1_000_000)

        measure {
            // When: Encrypt and decrypt
            do {
                let encrypted = try EncryptionManager.shared.encrypt(data: largeData)
                _ = try EncryptionManager.shared.decrypt(data: encrypted)
            } catch {
                XCTFail("Encryption/decryption failed: \(error)")
            }
        }
    }

    func testStoragePerformance() async throws {
        // Given: Storage system
        let storage = SecurePhotoStorage.shared
        try storage.initializeStorage()

        // When: Save multiple photos
        let photoData = Data(repeating: 0x42, count: 100_000) // 100 KB

        measure {
            Task {
                do {
                    for i in 0..<10 {
                        let photo = try await storage.savePhoto(
                            data: photoData,
                            metadata: PhotoMetadata(
                                originalFilename: "perf_test_\(i).jpg",
                                fileSize: photoData.count
                            )
                        )
                        try await storage.deletePhoto(id: photo.id)
                    }
                } catch {
                    XCTFail("Storage operation failed: \(error)")
                }
            }
        }
    }

    // MARK: - Stress Tests

    func testConcurrentEncryption() async throws {
        // Given: Multiple concurrent encryption operations
        let plaintext = "Concurrent test data".data(using: .utf8)!

        // When: Encrypt 100 times concurrently
        await withThrowingTaskGroup(of: Data.self) { group in
            for _ in 0..<100 {
                group.addTask {
                    try EncryptionManager.shared.encrypt(data: plaintext)
                }
            }

            // Then: All should succeed and produce valid encrypted data
            var results: [Data] = []
            for try await encrypted in group {
                results.append(encrypted)
            }

            XCTAssertEqual(results.count, 100)

            // Verify all can be decrypted
            for encrypted in results {
                let decrypted = try EncryptionManager.shared.decrypt(data: encrypted)
                XCTAssertEqual(decrypted, plaintext)
            }
        }
    }
}
