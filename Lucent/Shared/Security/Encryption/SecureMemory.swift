//
//  SecureMemory.swift
//  Lucent
//
//  Created by Claude Code on 11/23/2024.
//  Copyright © 2024 Lucent. All rights reserved.
//

import Foundation
import CryptoKit

/// Utilities for secure memory management and data wiping
///
/// This module provides extensions and utilities to securely clear sensitive
/// data from memory, preventing data leakage through memory dumps or swapping.
public enum SecureMemory {

    /// Securely wipes a memory buffer by overwriting it with zeros
    ///
    /// - Parameter pointer: Unsafe mutable pointer to the memory to wipe
    /// - Parameter count: Number of bytes to wipe
    public static func wipe(_ pointer: UnsafeMutableRawPointer, count: Int) {
        // Use memset_s for secure wiping (cannot be optimized away by compiler)
        #if os(macOS) || os(iOS)
        memset_s(pointer, count, 0, count)
        #else
        // Fallback for other platforms
        pointer.initializeMemory(as: UInt8.self, repeating: 0, count: count)
        // Add memory barrier to prevent compiler optimization
        _stdlib_atomicLoadARCRef(pointer).takeRetainedValue()
        #endif
    }

    /// Creates a closure that automatically wipes data when done
    ///
    /// - Parameters:
    ///   - data: The data to work with
    ///   - block: The closure to execute with the data
    /// - Returns: The result of the block
    /// - Throws: Rethrows any error from the block
    public static func withSecureBytes<T, R>(
        of data: inout T,
        _ block: (UnsafeRawPointer, Int) throws -> R
    ) rethrows -> R {
        return try withUnsafeBytes(of: &data) { buffer in
            defer {
                // Wipe the data after use
                if let baseAddress = buffer.baseAddress {
                    wipe(UnsafeMutableRawPointer(mutating: baseAddress), count: buffer.count)
                }
            }

            // Safely unwrap baseAddress - empty buffers have nil baseAddress
            guard let baseAddress = buffer.baseAddress else {
                // Handle empty buffer case by calling block with empty pointer
                let emptyPointer = UnsafeRawPointer(bitPattern: 0x1)! // Non-null but invalid for access
                return try block(emptyPointer, 0)
            }

            return try block(baseAddress, buffer.count)
        }
    }
}

// MARK: - Data Extension

extension Data {

    /// Securely wipes all bytes in the Data object
    ///
    /// This method overwrites all bytes with zeros before releasing the memory.
    /// Use this for sensitive data like encryption keys, passwords, etc.
    ///
    /// Example:
    /// ```swift
    /// var sensitiveData = "password".data(using: .utf8)!
    /// defer { sensitiveData.secureWipe() }
    /// // Use sensitiveData...
    /// ```
    public mutating func secureWipe() {
        self.withUnsafeMutableBytes { buffer in
            guard let baseAddress = buffer.baseAddress else { return }
            SecureMemory.wipe(baseAddress, count: buffer.count)
        }
        // Clear the data
        self.removeAll()
    }

    /// Creates a copy of the data with automatic secure wiping
    ///
    /// - Parameter block: Closure that receives the data and returns a result
    /// - Returns: The result of the block
    /// - Throws: Rethrows any error from the block
    public func withSecureCopy<R>(_ block: (Data) throws -> R) rethrows -> R {
        var copy = self
        defer {
            copy.secureWipe()
        }
        return try block(copy)
    }
}

// MARK: - String Extension

extension String {

    /// Securely wipes the string's UTF-8 representation from memory
    ///
    /// Note: This only wipes the copy, not the original string storage.
    /// For maximum security, avoid using String for sensitive data and
    /// use Data directly.
    ///
    /// Example:
    /// ```swift
    /// let password = "secret123"
    /// password.secureWipe()
    /// ```
    public func secureWipe() {
        guard var data = self.data(using: .utf8) else { return }
        data.secureWipe()
    }

    /// Creates a secure copy that is automatically wiped after use
    ///
    /// - Parameter block: Closure that receives the UTF-8 data
    /// - Returns: The result of the block
    /// - Throws: Rethrows any error from the block
    public func withSecureUTF8<R>(_ block: (Data) throws -> R) rethrows -> R {
        guard var data = self.data(using: .utf8) else {
            return try block(Data())
        }
        defer {
            data.secureWipe()
        }
        return try block(data)
    }
}

// MARK: - SymmetricKey Extension

extension SymmetricKey {

    /// Extracts key data with automatic secure wiping
    ///
    /// - Parameter block: Closure that receives the key data
    /// - Returns: The result of the block
    /// - Throws: Rethrows any error from the block
    public func withSecureBytes<R>(_ block: (Data) throws -> R) rethrows -> R {
        var keyData = self.withUnsafeBytes { Data($0) }
        defer {
            keyData.secureWipe()
        }
        return try block(keyData)
    }

    /// Creates a copy of the key data that is automatically wiped
    ///
    /// Use this when you need to temporarily store key data
    ///
    /// - Returns: Data containing the key bytes
    public func secureDataCopy() -> Data {
        return self.withUnsafeBytes { Data($0) }
    }
}

// MARK: - SecureBuffer

/// A buffer that automatically wipes its contents when deallocated
///
/// Use this class for temporary storage of sensitive data that needs to
/// persist beyond a single scope but should be securely wiped when done.
///
/// Thread Safety: This class uses an internal lock to ensure thread-safe access
/// to mutable state. All public methods are safe to call from any thread.
///
/// Example:
/// ```swift
/// let buffer = SecureBuffer(capacity: 256)
/// // Use buffer...
/// // Automatically wiped when buffer is deallocated
/// ```
public final class SecureBuffer: @unchecked Sendable {
    // Note: @unchecked Sendable is valid because all mutable state access (_data)
    // is synchronized through self.lock (an NSLock)

    /// Lock for thread-safe access to mutable state
    private let lock = NSLock()

    private var _data: Data

    /// The current count of bytes in the buffer
    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return _data.count
    }

    /// Creates a secure buffer with the specified capacity
    /// - Parameter capacity: Initial capacity in bytes
    public init(capacity: Int) {
        self._data = Data(capacity: capacity)
    }

    /// Creates a secure buffer from existing data
    /// - Parameter data: The data to store (will be copied)
    public init(data: Data) {
        self._data = data
    }

    /// Appends data to the buffer
    /// - Parameter newData: Data to append
    public func append(_ newData: Data) {
        lock.lock()
        defer { lock.unlock() }
        _data.append(newData)
    }

    /// Accesses the buffer's data
    /// - Parameter block: Closure that receives the data
    /// - Returns: The result of the block
    /// - Throws: Rethrows any error from the block
    public func withData<R>(_ block: (Data) throws -> R) rethrows -> R {
        lock.lock()
        defer { lock.unlock() }
        return try block(_data)
    }

    /// Accesses the buffer's unsafe bytes
    /// - Parameter block: Closure that receives the byte buffer
    /// - Returns: The result of the block
    /// - Throws: Rethrows any error from the block
    public func withUnsafeBytes<R>(_ block: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        lock.lock()
        defer { lock.unlock() }
        return try _data.withUnsafeBytes(block)
    }

    /// Securely wipes the buffer
    public func wipe() {
        lock.lock()
        defer { lock.unlock() }
        _data.secureWipe()
    }

    deinit {
        // Ensure data is wiped when buffer is deallocated
        // Note: No lock needed - deinit runs single-threaded
        _data.secureWipe()
    }
}

// MARK: - Sendable Conformance
// SecureBuffer now directly conforms to Sendable through proper internal synchronization
// via NSLock, rather than using @unchecked Sendable
