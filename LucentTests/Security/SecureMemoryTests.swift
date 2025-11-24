//
//  SecureMemoryTests.swift
//  LucentTests
//
//  Created by Claude Code on 11/23/2024.
//  Copyright © 2024 Lucent. All rights reserved.
//

import XCTest
import CryptoKit
@testable import Lucent

final class SecureMemoryTests: XCTestCase {

    // MARK: - Data Extension Tests

    func testSecureWipeData() {
        // Given
        var sensitiveData = "password123".data(using: .utf8)!
        let originalCount = sensitiveData.count
        XCTAssertTrue(originalCount > 0)

        // When
        sensitiveData.secureWipe()

        // Then
        XCTAssertEqual(sensitiveData.count, 0, "Data should be empty after wipe")
    }

    func testWithSecureCopy() throws {
        // Given
        let originalData = "sensitive".data(using: .utf8)!
        var copyUsedInBlock: Data?

        // When
        let result = try originalData.withSecureCopy { copy in
            copyUsedInBlock = copy
            return copy.count
        }

        // Then
        XCTAssertEqual(result, originalData.count)
        XCTAssertNotNil(copyUsedInBlock)

        // Original should still be intact
        XCTAssertEqual(originalData.count, "sensitive".count)
    }

    func testWithSecureCopyThrowsError() {
        // Given
        let data = "test".data(using: .utf8)!
        enum TestError: Error { case intentional }

        // When/Then
        XCTAssertThrowsError(try data.withSecureCopy { _ in
            throw TestError.intentional
        }) { error in
            XCTAssertTrue(error is TestError)
        }
    }

    func testSecureWipeEmptyData() {
        // Given
        var emptyData = Data()

        // When/Then
        XCTAssertNoThrow(emptyData.secureWipe())
        XCTAssertEqual(emptyData.count, 0)
    }

    func testSecureWipeLargeData() {
        // Given
        var largeData = Data(repeating: 0x42, count: 1_000_000) // 1 MB
        XCTAssertEqual(largeData.count, 1_000_000)

        // When
        largeData.secureWipe()

        // Then
        XCTAssertEqual(largeData.count, 0, "Large data should be wiped")
    }

    // MARK: - String Extension Tests

    func testSecureWipeString() {
        // Given
        let password = "super-secret-password"

        // When/Then
        XCTAssertNoThrow(password.secureWipe())
        // Note: The original string is not modified (strings are value types)
        // This test verifies the method doesn't crash
    }

    func testWithSecureUTF8() throws {
        // Given
        let message = "secret message"

        // When
        let result = try message.withSecureUTF8 { data in
            return data.count
        }

        // Then
        XCTAssertEqual(result, message.utf8.count)
    }

    func testWithSecureUTF8ThrowsError() {
        // Given
        let message = "test"
        enum TestError: Error { case intentional }

        // When/Then
        XCTAssertThrowsError(try message.withSecureUTF8 { _ in
            throw TestError.intentional
        }) { error in
            XCTAssertTrue(error is TestError)
        }
    }

    func testWithSecureUTF8EmptyString() throws {
        // Given
        let empty = ""

        // When
        let result = try empty.withSecureUTF8 { data in
            return data.count
        }

        // Then
        XCTAssertEqual(result, 0)
    }

    // MARK: - SymmetricKey Extension Tests

    func testSymmetricKeyWithSecureBytes() throws {
        // Given
        let key = SymmetricKey(size: .bits256)

        // When
        let result = try key.withSecureBytes { data in
            return data.count
        }

        // Then
        XCTAssertEqual(result, 32, "256-bit key should be 32 bytes")
    }

    func testSymmetricKeyWithSecureBytesThrowsError() {
        // Given
        let key = SymmetricKey(size: .bits256)
        enum TestError: Error { case intentional }

        // When/Then
        XCTAssertThrowsError(try key.withSecureBytes { _ in
            throw TestError.intentional
        }) { error in
            XCTAssertTrue(error is TestError)
        }
    }

    func testSymmetricKeySecureDataCopy() {
        // Given
        let key = SymmetricKey(size: .bits128)

        // When
        let keyData = key.secureDataCopy()

        // Then
        XCTAssertEqual(keyData.count, 16, "128-bit key should be 16 bytes")
    }

    func testSymmetricKeySecureDataCopyDifferentSizes() {
        let sizes: [(SymmetricKey.Size, Int)] = [
            (.bits128, 16),
            (.bits192, 24),
            (.bits256, 32)
        ]

        for (size, expectedBytes) in sizes {
            // Given
            let key = SymmetricKey(size: size)

            // When
            let keyData = key.secureDataCopy()

            // Then
            XCTAssertEqual(keyData.count, expectedBytes, "Key size \(size) should be \(expectedBytes) bytes")
        }
    }

    // MARK: - SecureBuffer Tests

    func testSecureBufferInitWithCapacity() {
        // Given/When
        let buffer = SecureBuffer(capacity: 256)

        // Then
        XCTAssertEqual(buffer.count, 0, "New buffer should be empty")
    }

    func testSecureBufferInitWithData() {
        // Given
        let data = "test data".data(using: .utf8)!

        // When
        let buffer = SecureBuffer(data: data)

        // Then
        XCTAssertEqual(buffer.count, data.count)
    }

    func testSecureBufferAppend() {
        // Given
        let buffer = SecureBuffer(capacity: 100)
        let data1 = "Hello".data(using: .utf8)!
        let data2 = " World".data(using: .utf8)!

        // When
        buffer.append(data1)
        buffer.append(data2)

        // Then
        XCTAssertEqual(buffer.count, data1.count + data2.count)
    }

    func testSecureBufferWithData() throws {
        // Given
        let testData = "buffer data".data(using: .utf8)!
        let buffer = SecureBuffer(data: testData)

        // When
        let result = try buffer.withData { data in
            return String(data: data, encoding: .utf8)
        }

        // Then
        XCTAssertEqual(result, "buffer data")
    }

    func testSecureBufferWithUnsafeBytes() throws {
        // Given
        let testData = Data([0x01, 0x02, 0x03, 0x04])
        let buffer = SecureBuffer(data: testData)

        // When
        let sum = try buffer.withUnsafeBytes { bytes in
            return bytes.reduce(0, +)
        }

        // Then
        XCTAssertEqual(sum, 10, "Sum of [1,2,3,4] should be 10")
    }

    func testSecureBufferWipe() {
        // Given
        let buffer = SecureBuffer(data: "secret".data(using: .utf8)!)
        XCTAssertGreaterThan(buffer.count, 0)

        // When
        buffer.wipe()

        // Then
        XCTAssertEqual(buffer.count, 0, "Buffer should be empty after wipe")
    }

    func testSecureBufferDeinit() {
        // Given
        var buffer: SecureBuffer? = SecureBuffer(data: "secret".data(using: .utf8)!)
        weak var weakBuffer = buffer

        // When
        buffer = nil

        // Then
        XCTAssertNil(weakBuffer, "Buffer should be deallocated")
    }

    func testSecureBufferConcurrentAccess() throws {
        // Given
        let buffer = SecureBuffer(capacity: 1000)
        let expectation = XCTestExpectation(description: "Concurrent buffer access")
        expectation.expectedFulfillmentCount = 10

        // When - Multiple threads appending data
        DispatchQueue.concurrentPerform(iterations: 10) { index in
            let data = Data([UInt8(index)])
            buffer.append(data)
            expectation.fulfill()
        }

        // Then
        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(buffer.count, 10, "All appends should complete")
    }

    // MARK: - SecureMemory Static Methods Tests

    func testWipeMemory() {
        // Given
        var testData = Data([0x42, 0x42, 0x42, 0x42])

        // When
        testData.withUnsafeMutableBytes { buffer in
            guard let baseAddress = buffer.baseAddress else { return }
            SecureMemory.wipe(baseAddress, count: buffer.count)
        }

        // Then
        let allZeros = testData.allSatisfy { $0 == 0 }
        XCTAssertTrue(allZeros, "Memory should be zeroed after wipe")
    }

    // MARK: - Integration Tests

    func testSecureDataHandling() {
        // Simulate handling sensitive data with proper cleanup
        var sensitiveData = "credit-card-number".data(using: .utf8)!
        defer {
            sensitiveData.secureWipe()
        }

        // Use the data
        XCTAssertGreaterThan(sensitiveData.count, 0)

        // Data should be wiped in defer
    }

    func testSecureBufferLifecycle() throws {
        // Given
        let buffer = SecureBuffer(capacity: 256)
        let password = "my-password".data(using: .utf8)!

        // When
        buffer.append(password)

        // Use the buffer
        let result = try buffer.withData { data in
            return data.count
        }

        XCTAssertEqual(result, password.count)

        // Clean up
        buffer.wipe()
        XCTAssertEqual(buffer.count, 0)
    }

    func testEncryptionKeySecureHandling() throws {
        // Given
        let key = SymmetricKey(size: .bits256)

        // When - Extract key data securely
        try key.withSecureBytes { keyData in
            // Use key data
            XCTAssertEqual(keyData.count, 32)

            // Verify we can use it for encryption
            let plaintext = "test".data(using: .utf8)!
            let encrypted = try AES.GCM.seal(plaintext, using: key)
            XCTAssertNotNil(encrypted.combined)
        }

        // Key data should be wiped after block
    }

    // MARK: - Performance Tests

    func testSecureWipePerformance() {
        let data = Data(repeating: 0x42, count: 1_000_000) // 1 MB

        measure {
            var copy = data
            copy.secureWipe()
        }
    }

    func testSecureBufferPerformance() {
        measure {
            let buffer = SecureBuffer(capacity: 1000)
            for i in 0..<100 {
                buffer.append(Data([UInt8(i % 256)]))
            }
            buffer.wipe()
        }
    }
}
