//
//  BackupManager.swift
//  Lucent
//
//  Created by Claude Code on 11/24/24.
//

import Foundation
import CryptoKit
import os.log
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// Manages secure backup and restore operations for encrypted photos
actor BackupManager {

    // MARK: - Singleton

    static let shared = BackupManager()

    // MARK: - Types

    /// Backup file format version for future compatibility
    private static let backupVersion: UInt32 = 1

    /// Magic bytes to identify Lucent backup files
    private static let magicBytes: [UInt8] = [0x4C, 0x55, 0x43, 0x42] // "LUCB"

    /// Errors that can occur during backup/restore operations
    /// Note: Error descriptions are sanitized to prevent information leakage
    enum BackupError: LocalizedError {
        case noPhotosToBackup
        case backupCreationFailed(String)
        case backupEncryptionFailed
        case invalidBackupFile
        case wrongPassword
        case backupCorrupted
        case restoreFailed(String)
        case insufficientStorage
        case cancelled

        /// User-facing error description - intentionally generic for security
        var errorDescription: String? {
            switch self {
            case .noPhotosToBackup:
                return "No photos available to backup"
            case .backupCreationFailed:
                // Don't expose internal reason to users
                return "Failed to create backup"
            case .backupEncryptionFailed:
                return "Failed to encrypt backup"
            case .invalidBackupFile:
                return "Invalid backup file"
            case .wrongPassword:
                return "Incorrect password"
            case .backupCorrupted:
                return "Backup file is corrupted"
            case .restoreFailed:
                // Don't expose internal reason to users
                return "Failed to restore backup"
            case .insufficientStorage:
                return "Not enough storage space"
            case .cancelled:
                return "Operation cancelled"
            }
        }

        /// Detailed error info for logging (use with privacy: .private)
        var debugDescription: String {
            switch self {
            case .noPhotosToBackup:
                return "No photos in storage to backup"
            case .backupCreationFailed(let reason):
                return "Backup creation failed: \(reason)"
            case .backupEncryptionFailed:
                return "Backup encryption with derived key failed"
            case .invalidBackupFile:
                return "File missing magic bytes or invalid format"
            case .wrongPassword:
                return "Password-derived key failed to decrypt backup"
            case .backupCorrupted:
                return "Backup file checksum or structure validation failed"
            case .restoreFailed(let reason):
                return "Backup restore failed: \(reason)"
            case .insufficientStorage:
                return "Insufficient disk space for backup/restore operation"
            case .cancelled:
                return "User cancelled backup/restore operation"
            }
        }
    }

    /// Progress information for backup/restore operations
    struct Progress {
        var phase: Phase
        var current: Int
        var total: Int
        var currentPhotoName: String?

        enum Phase: String {
            case preparing = "Preparing..."
            case encryptingPhotos = "Encrypting photos..."
            case writingBackup = "Writing backup..."
            case readingBackup = "Reading backup..."
            case decryptingPhotos = "Decrypting photos..."
            case importingPhotos = "Importing photos..."
            case complete = "Complete"
        }

        var fractionComplete: Double {
            guard total > 0 else { return 0 }
            return Double(current) / Double(total)
        }
    }

    /// Backup metadata stored in the backup file
    struct BackupMetadata: Codable {
        let version: UInt32
        let createdAt: Date
        let deviceName: String
        let photoCount: Int
        let totalSize: Int64
    }

    // MARK: - Private Properties

    private let storage = SecurePhotoStorage.shared
    private let encryptionManager = EncryptionManager.shared

    /// File permissions: 0600 (owner read/write only)
    private static let filePermissions: Int = 0o600

    /// Directory permissions: 0700 (owner read/write/execute only)
    private static let directoryPermissions: Int = 0o700

    // MARK: - Initialization

    private init() {}

    // MARK: - File Permissions

    /// Sets strict file permissions after writing
    private func setFilePermissions(at url: URL) throws {
        try FileManager.default.setAttributes(
            [.posixPermissions: Self.filePermissions],
            ofItemAtPath: url.path
        )
    }

    /// Sets strict directory permissions
    private func setDirectoryPermissions(at url: URL) throws {
        try FileManager.default.setAttributes(
            [.posixPermissions: Self.directoryPermissions],
            ofItemAtPath: url.path
        )
    }

    // MARK: - Backup Creation

    /// Creates an encrypted backup of all photos
    /// - Parameters:
    ///   - password: User-provided password for backup encryption
    ///   - progressHandler: Closure called with progress updates
    /// - Returns: URL to the created backup file
    func createBackup(
        password: String,
        progressHandler: @escaping @Sendable (Progress) -> Void
    ) async throws -> URL {
        AppLogger.storage.info("Starting backup creation...")

        // Get all photos
        let photos = try await storage.listAllPhotos()

        guard !photos.isEmpty else {
            throw BackupError.noPhotosToBackup
        }

        // Report initial progress
        progressHandler(Progress(
            phase: .preparing,
            current: 0,
            total: photos.count,
            currentPhotoName: nil
        ))

        // Create temporary directory for backup assembly
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LucentBackup-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            // Cleanup temp directory
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Derive encryption key from password using HKDF
        let backupKey = try deriveKeyFromPassword(password)

        // Create photos directory in temp
        let photosDir = tempDir.appendingPathComponent("photos", isDirectory: true)
        try FileManager.default.createDirectory(at: photosDir, withIntermediateDirectories: true)

        // Export each photo
        var exportedPhotos: [ExportedPhotoEntry] = []
        var totalSize: Int64 = 0

        for (index, photo) in photos.enumerated() {
            progressHandler(Progress(
                phase: .encryptingPhotos,
                current: index,
                total: photos.count,
                currentPhotoName: photo.filename
            ))

            do {
                // Get the encrypted photo data from storage
                let photoData = try await storage.retrievePhoto(id: photo.id)

                // Re-encrypt with backup key
                let reEncrypted = try encryptWithKey(data: photoData, key: backupKey)

                // Write to temp directory
                let photoFileName = "\(photo.id.uuidString).enc"
                let photoFileURL = photosDir.appendingPathComponent(photoFileName)
                try reEncrypted.write(to: photoFileURL)

                // Handle thumbnail if exists
                var thumbnailFileName: String?
                if photo.hasThumbnail, let thumbURL = photo.thumbnailURL {
                    let thumbData = try Data(contentsOf: thumbURL)
                    let decryptedThumb = try encryptionManager.decrypt(data: thumbData)
                    let reEncryptedThumb = try encryptWithKey(data: decryptedThumb, key: backupKey)

                    let thumbName = "\(photo.id.uuidString)_thumb.enc"
                    thumbnailFileName = thumbName
                    let thumbFileURL = photosDir.appendingPathComponent(thumbName)
                    try reEncryptedThumb.write(to: thumbFileURL)
                }

                // Record entry
                exportedPhotos.append(ExportedPhotoEntry(
                    id: photo.id,
                    filename: photoFileName,
                    thumbnailFilename: thumbnailFileName,
                    metadata: photo.metadata,
                    dateAdded: photo.dateAdded
                ))

                totalSize += Int64(reEncrypted.count)

            } catch {
                AppLogger.storage.error("Failed to export photo \(photo.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
                // Continue with other photos
            }
        }

        guard !exportedPhotos.isEmpty else {
            throw BackupError.backupCreationFailed("No photos could be exported")
        }

        // Create metadata
        let metadata = BackupMetadata(
            version: Self.backupVersion,
            createdAt: Date(),
            deviceName: getDeviceName(),
            photoCount: exportedPhotos.count,
            totalSize: totalSize
        )

        // Write manifest
        progressHandler(Progress(
            phase: .writingBackup,
            current: photos.count,
            total: photos.count,
            currentPhotoName: nil
        ))

        let manifest = BackupManifest(
            metadata: metadata,
            photos: exportedPhotos
        )

        let manifestData = try JSONEncoder().encode(manifest)
        let encryptedManifest = try encryptWithKey(data: manifestData, key: backupKey)
        try encryptedManifest.write(to: tempDir.appendingPathComponent("manifest.enc"))

        // Create final backup file
        let backupFileName = "Lucent-Backup-\(formattedDate()).lucent"
        guard let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw BackupError.backupCreationFailed("Could not access Documents directory")
        }
        let backupURL = documentsDir.appendingPathComponent(backupFileName)

        // Package everything into a single file
        try createBackupPackage(from: tempDir, to: backupURL)

        // Set strict permissions on the backup file
        try setFilePermissions(at: backupURL)

        progressHandler(Progress(
            phase: .complete,
            current: photos.count,
            total: photos.count,
            currentPhotoName: nil
        ))

        AppLogger.storage.info("Backup created successfully: \(backupURL.lastPathComponent, privacy: .public)")

        return backupURL
    }

    // MARK: - Backup Restoration

    /// Restores photos from an encrypted backup
    /// - Parameters:
    ///   - backupURL: URL to the backup file
    ///   - password: User-provided password for decryption
    ///   - progressHandler: Closure called with progress updates
    /// - Returns: Number of photos restored
    func restoreBackup(
        from backupURL: URL,
        password: String,
        progressHandler: @escaping @Sendable (Progress) -> Void
    ) async throws -> Int {
        AppLogger.storage.info("Starting backup restoration from: \(backupURL.lastPathComponent, privacy: .public)")

        progressHandler(Progress(
            phase: .readingBackup,
            current: 0,
            total: 1,
            currentPhotoName: nil
        ))

        // Create temp directory for extraction
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LucentRestore-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Extract backup package
        try extractBackupPackage(from: backupURL, to: tempDir)

        // Derive key from password
        let backupKey = try deriveKeyFromPassword(password)

        // Read and decrypt manifest
        let manifestURL = tempDir.appendingPathComponent("manifest.enc")
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            throw BackupError.invalidBackupFile
        }

        let encryptedManifest = try Data(contentsOf: manifestURL)
        let manifestData: Data

        do {
            manifestData = try decryptWithKey(data: encryptedManifest, key: backupKey)
        } catch {
            throw BackupError.wrongPassword
        }

        let manifest: BackupManifest
        do {
            manifest = try JSONDecoder().decode(BackupManifest.self, from: manifestData)
        } catch {
            throw BackupError.backupCorrupted
        }

        AppLogger.storage.info("Backup contains \(manifest.photos.count, privacy: .public) photos")

        // Restore each photo
        let photosDir = tempDir.appendingPathComponent("photos", isDirectory: true)
        var restoredCount = 0

        for (index, entry) in manifest.photos.enumerated() {
            progressHandler(Progress(
                phase: .importingPhotos,
                current: index,
                total: manifest.photos.count,
                currentPhotoName: entry.metadata.originalFilename ?? "Photo \(index + 1)"
            ))

            do {
                // Read and decrypt photo
                let photoFileURL = photosDir.appendingPathComponent(entry.filename)
                let encryptedPhoto = try Data(contentsOf: photoFileURL)
                let photoData = try decryptWithKey(data: encryptedPhoto, key: backupKey)

                // Import into storage (will re-encrypt with device key)
                _ = try await storage.savePhoto(data: photoData, metadata: entry.metadata)

                restoredCount += 1

            } catch {
                AppLogger.storage.error("Failed to restore photo \(entry.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
                // Continue with other photos
            }
        }

        progressHandler(Progress(
            phase: .complete,
            current: manifest.photos.count,
            total: manifest.photos.count,
            currentPhotoName: nil
        ))

        AppLogger.storage.info("Restored \(restoredCount, privacy: .public) of \(manifest.photos.count, privacy: .public) photos")

        return restoredCount
    }

    /// Reads metadata from a backup file without decrypting photos
    /// - Parameters:
    ///   - backupURL: URL to the backup file
    ///   - password: User-provided password
    /// - Returns: Backup metadata
    func readBackupMetadata(from backupURL: URL, password: String) async throws -> BackupMetadata {
        // Create temp directory
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LucentPeek-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Extract only manifest
        try extractBackupPackage(from: backupURL, to: tempDir, manifestOnly: true)

        // Derive key and decrypt manifest
        let backupKey = try deriveKeyFromPassword(password)
        let manifestURL = tempDir.appendingPathComponent("manifest.enc")

        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            throw BackupError.invalidBackupFile
        }

        let encryptedManifest = try Data(contentsOf: manifestURL)

        let manifestData: Data
        do {
            manifestData = try decryptWithKey(data: encryptedManifest, key: backupKey)
        } catch {
            throw BackupError.wrongPassword
        }

        let manifest = try JSONDecoder().decode(BackupManifest.self, from: manifestData)
        return manifest.metadata
    }

    // MARK: - Private Methods

    /// Derives an encryption key from a password using HKDF
    private func deriveKeyFromPassword(_ password: String) throws -> SymmetricKey {
        guard let passwordData = password.data(using: .utf8) else {
            throw BackupError.backupEncryptionFailed
        }

        // Use a fixed salt for backup key derivation (this is acceptable since
        // the password itself provides entropy, and we want deterministic keys)
        let salt = "LucentBackup-v1".data(using: .utf8)!

        let derivedKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: passwordData),
            salt: salt,
            info: "backup-encryption-key".data(using: .utf8)!,
            outputByteCount: 32
        )

        return derivedKey
    }

    /// Encrypts data with a specific key
    private func encryptWithKey(data: Data, key: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.seal(data, using: key)
        guard let combined = sealedBox.combined else {
            throw BackupError.backupEncryptionFailed
        }
        return combined
    }

    /// Decrypts data with a specific key
    private func decryptWithKey(data: Data, key: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedBox, using: key)
    }

    /// Creates a backup package from a directory
    private func createBackupPackage(from sourceDir: URL, to destinationURL: URL) throws {
        // Create a simple archive format:
        // [4 bytes magic] [4 bytes version] [file entries...]
        // Each entry: [4 bytes name length] [name] [8 bytes data length] [data]

        var packageData = Data()

        // Write magic bytes
        packageData.append(contentsOf: Self.magicBytes)

        // Write version
        var version = Self.backupVersion
        packageData.append(Data(bytes: &version, count: 4))

        // Enumerate and write all files
        let fileManager = FileManager.default
        let enumerator = fileManager.enumerator(at: sourceDir, includingPropertiesForKeys: nil)

        while let fileURL = enumerator?.nextObject() as? URL {
            guard !fileURL.hasDirectoryPath else { continue }

            let relativePath = fileURL.path.replacingOccurrences(of: sourceDir.path + "/", with: "")
            let fileData = try Data(contentsOf: fileURL)

            // Write filename length and filename
            let pathData = relativePath.data(using: .utf8)!
            var pathLength = UInt32(pathData.count)
            packageData.append(Data(bytes: &pathLength, count: 4))
            packageData.append(pathData)

            // Write file data length and data
            var dataLength = UInt64(fileData.count)
            packageData.append(Data(bytes: &dataLength, count: 8))
            packageData.append(fileData)
        }

        try packageData.write(to: destinationURL)
    }

    /// Extracts a backup package to a directory
    private func extractBackupPackage(from sourceURL: URL, to destinationDir: URL, manifestOnly: Bool = false) throws {
        let packageData = try Data(contentsOf: sourceURL)
        var offset = 0

        // Verify magic bytes
        guard packageData.count >= 8 else {
            throw BackupError.invalidBackupFile
        }

        let magic = [UInt8](packageData[0..<4])
        guard magic == Self.magicBytes else {
            throw BackupError.invalidBackupFile
        }
        offset = 4

        // Read version
        let version = packageData[offset..<offset+4].withUnsafeBytes { $0.load(as: UInt32.self) }
        guard version <= Self.backupVersion else {
            throw BackupError.invalidBackupFile
        }
        offset += 4

        // Extract files
        let fileManager = FileManager.default

        while offset < packageData.count {
            // Read filename length
            guard offset + 4 <= packageData.count else { break }
            let pathLength = Int(packageData[offset..<offset+4].withUnsafeBytes { $0.load(as: UInt32.self) })
            offset += 4

            // Read filename
            guard offset + pathLength <= packageData.count else { break }
            guard let path = String(data: packageData[offset..<offset+pathLength], encoding: .utf8) else { break }
            offset += pathLength

            // Read data length
            guard offset + 8 <= packageData.count else { break }
            let dataLength = Int(packageData[offset..<offset+8].withUnsafeBytes { $0.load(as: UInt64.self) })
            offset += 8

            // Read data
            guard offset + dataLength <= packageData.count else { break }
            let fileData = packageData[offset..<offset+dataLength]
            offset += dataLength

            // If manifest only, skip non-manifest files
            if manifestOnly && path != "manifest.enc" {
                continue
            }

            // Write file
            let fileURL = destinationDir.appendingPathComponent(path)
            let parentDir = fileURL.deletingLastPathComponent()
            try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)
            try fileData.write(to: fileURL)
        }
    }

    /// Returns the current device name
    private func getDeviceName() -> String {
        #if os(iOS)
        return UIDevice.current.name
        #elseif os(macOS)
        return Host.current().localizedName ?? "Mac"
        #else
        return "Unknown Device"
        #endif
    }

    /// Returns a formatted date string for filenames
    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter.string(from: Date())
    }
}

// MARK: - Supporting Types

/// Entry for a photo in the backup manifest
private struct ExportedPhotoEntry: Codable {
    let id: UUID
    let filename: String
    let thumbnailFilename: String?
    let metadata: PhotoMetadata
    let dateAdded: Date
}

/// Complete backup manifest
private struct BackupManifest: Codable {
    let metadata: BackupManager.BackupMetadata
    let photos: [ExportedPhotoEntry]
}
