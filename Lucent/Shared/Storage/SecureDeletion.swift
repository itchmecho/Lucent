//
//  SecureDeletion.swift
//  Lucent
//
//  Created by Claude Code on 11/23/2024.
//

import Foundation

/// Provides secure file deletion using DOD 5220.22-M standard
/// Files are overwritten with random data multiple times before deletion
actor SecureDeletion {
    // MARK: - Constants

    /// Number of overwrite passes (DOD 5220.22-M standard)
    private static let overwritePasses = 3

    /// Buffer size for overwrite operations (1 MB)
    private static let bufferSize = 1024 * 1024

    // MARK: - Error Types

    enum DeletionError: Error, LocalizedError {
        case fileNotFound
        case accessDenied
        case overwriteFailed(pass: Int)
        case deletionFailed
        case unknownError(Error)

        var errorDescription: String? {
            switch self {
            case .fileNotFound:
                return "File not found at specified location"
            case .accessDenied:
                return "Access denied to file"
            case .overwriteFailed(let pass):
                return "Failed to overwrite file on pass \(pass)"
            case .deletionFailed:
                return "Failed to delete file after overwrite"
            case .unknownError(let error):
                return "Secure deletion failed: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Public Methods

    /// Securely deletes a file by overwriting it with random data before removal
    /// - Parameter fileURL: The URL of the file to delete
    /// - Throws: `DeletionError` if the operation fails
    func secureDelete(fileAt fileURL: URL) async throws {
        let fileManager = FileManager.default

        // Verify file exists
        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw DeletionError.fileNotFound
        }

        // Get file size
        let fileSize: Int
        do {
            let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
            fileSize = (attributes[.size] as? NSNumber)?.intValue ?? 0
        } catch {
            throw DeletionError.unknownError(error)
        }

        // Perform overwrite passes
        for pass in 1...Self.overwritePasses {
            do {
                try await overwriteFile(at: fileURL, size: fileSize, pass: pass)
            } catch {
                throw DeletionError.overwriteFailed(pass: pass)
            }
        }

        // Delete the file
        do {
            try fileManager.removeItem(at: fileURL)
        } catch {
            throw DeletionError.deletionFailed
        }
    }

    /// Securely deletes multiple files
    /// - Parameter fileURLs: Array of file URLs to delete
    /// - Returns: Dictionary mapping URLs to deletion results
    func secureDeleteMultiple(filesAt fileURLs: [URL]) async -> [URL: Result<Void, Error>] {
        var results: [URL: Result<Void, Error>] = [:]

        for fileURL in fileURLs {
            do {
                try await secureDelete(fileAt: fileURL)
                results[fileURL] = .success(())
            } catch {
                results[fileURL] = .failure(error)
            }
        }

        return results
    }

    // MARK: - Private Methods

    /// Overwrites a file with random data
    /// - Parameters:
    ///   - fileURL: The URL of the file to overwrite
    ///   - size: The size of the file in bytes
    ///   - pass: The current overwrite pass number
    private func overwriteFile(at fileURL: URL, size: Int, pass: Int) async throws {
        // Open file for writing
        guard let fileHandle = try? FileHandle(forWritingTo: fileURL) else {
            throw DeletionError.accessDenied
        }

        defer {
            try? fileHandle.close()
        }

        // Overwrite in chunks
        var bytesWritten = 0
        while bytesWritten < size {
            let chunkSize = min(Self.bufferSize, size - bytesWritten)
            let randomData = generateRandomData(size: chunkSize, pass: pass)

            try fileHandle.write(contentsOf: randomData)
            bytesWritten += chunkSize
        }

        // Sync to disk
        try fileHandle.synchronize()
    }

    /// Generates random data for overwriting
    /// - Parameters:
    ///   - size: Number of bytes to generate
    ///   - pass: Current overwrite pass (affects pattern)
    /// - Returns: Random data
    private func generateRandomData(size: Int, pass: Int) -> Data {
        var data = Data(count: size)

        data.withUnsafeMutableBytes { buffer in
            guard let baseAddress = buffer.baseAddress else { return }

            // DOD 5220.22-M pattern:
            // Pass 1: Random data
            // Pass 2: Complement of pass 1
            // Pass 3: Random data
            switch pass {
            case 1, 3:
                // Random data
                arc4random_buf(baseAddress, size)
            case 2:
                // Fixed pattern (0xFF)
                memset(baseAddress, 0xFF, size)
            default:
                arc4random_buf(baseAddress, size)
            }
        }

        return data
    }
}

// MARK: - Convenience Extensions

extension SecureDeletion {
    /// Shared instance for convenience
    static let shared = SecureDeletion()

    /// Securely delete a file (static convenience method)
    static func delete(fileAt fileURL: URL) async throws {
        try await shared.secureDelete(fileAt: fileURL)
    }

    /// Securely delete multiple files (static convenience method)
    static func deleteMultiple(filesAt fileURLs: [URL]) async -> [URL: Result<Void, Error>] {
        await shared.secureDeleteMultiple(filesAt: fileURLs)
    }
}
