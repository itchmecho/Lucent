//
//  SecurePhotoStorage.swift
//  Lucent
//
//  Created by Claude Code on 11/23/2024.
//

import Foundation
import os.log

/// Manages encrypted photo storage with file operations and metadata
actor SecurePhotoStorage {
    // MARK: - Singleton

    static let shared = SecurePhotoStorage()

    // MARK: - Storage Paths

    private let fileManager = FileManager.default

    /// Cached base URL - set during initialization
    private var _baseURL: URL?

    /// Base URL for LucentVault storage
    private var baseURL: URL {
        if let url = _baseURL {
            return url
        }
        // Fallback computation (should rarely be needed after init)
        return Self.computeBaseURL()
    }

    /// Computes the base URL for storage - static helper for nonisolated access
    private static func computeBaseURL() -> URL {
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            // This should essentially never happen on iOS/macOS
            // Log error and return a fallback that will fail gracefully on file operations
            AppLogger.storage.error("CRITICAL: Could not access Documents directory")
            return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("LucentVault", isDirectory: true)
        }
        return documentsURL.appendingPathComponent("LucentVault", isDirectory: true)
    }

    /// Public access to encrypted photos directory (for URL construction)
    nonisolated var encryptedPhotosURL: URL {
        Self.computeBaseURL().appendingPathComponent(Self.encryptedPhotosFolderName, isDirectory: true)
    }

    /// Public access to thumbnails directory (for URL construction)
    nonisolated var thumbnailsURL: URL {
        Self.computeBaseURL().appendingPathComponent(Self.thumbnailsFolderName, isDirectory: true)
    }

    /// Metadata URL
    private var metadataURL: URL {
        baseURL.appendingPathComponent(Self.metadataFolderName, isDirectory: true)
    }

    // MARK: - Constants

    private static let encryptedPhotosFolderName = "EncryptedPhotos"
    private static let thumbnailsFolderName = "Thumbnails"
    private static let metadataFolderName = "Metadata"
    private static let metadataIndexFileName = "photo_index.json"

    // MARK: - In-Memory Index

    private var photoIndex: [UUID: EncryptedPhoto] = [:]
    private var isInitialized = false

    // MARK: - Error Types

    /// Storage errors with sanitized user-facing messages
    /// Note: Detailed reasons are kept for logging but not exposed to users
    enum StorageError: Error, LocalizedError {
        case initializationFailed
        case invalidPhotoData
        case saveFailed(reason: String)
        case retrievalFailed(reason: String)
        case deletionFailed(reason: String)
        case metadataCorrupted
        case photoNotFound
        case unknownError(Error)

        /// User-facing error description - intentionally generic for security
        var errorDescription: String? {
            switch self {
            case .initializationFailed:
                return "Failed to initialize photo storage"
            case .invalidPhotoData:
                return "Invalid photo data"
            case .saveFailed:
                // Don't expose internal reason to users
                return "Failed to save photo"
            case .retrievalFailed:
                // Don't expose internal reason to users
                return "Failed to load photo"
            case .deletionFailed:
                // Don't expose internal reason to users
                return "Failed to delete photo"
            case .metadataCorrupted:
                return "Photo data is corrupted"
            case .photoNotFound:
                return "Photo not found"
            case .unknownError:
                // Don't expose underlying error details to users
                return "An unexpected error occurred"
            }
        }

        /// Detailed error info for logging (use with privacy: .private)
        var debugDescription: String {
            switch self {
            case .initializationFailed:
                return "Storage directory initialization failed"
            case .invalidPhotoData:
                return "Invalid photo data provided to storage"
            case .saveFailed(let reason):
                return "Photo save failed: \(reason)"
            case .retrievalFailed(let reason):
                return "Photo retrieval failed: \(reason)"
            case .deletionFailed(let reason):
                return "Photo deletion failed: \(reason)"
            case .metadataCorrupted:
                return "Photo index metadata is corrupted"
            case .photoNotFound:
                return "Photo ID not found in index"
            case .unknownError(let error):
                return "Unknown storage error: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Initialization

    private init() {
        // Cache the base URL on init
        _baseURL = Self.computeBaseURL()
    }

    // MARK: - Public Methods

    /// Initializes the storage directory structure
    /// - Throws: `StorageError` if initialization fails
    func initializeStorage() throws {
        guard !isInitialized else { return }

        // Refresh base URL in case container changed (simulator restart, etc.)
        _baseURL = Self.computeBaseURL()

        AppLogger.storage.info("Initializing storage at: \(self.baseURL.path)")

        do {
            // Create directory structure
            try createDirectoryIfNeeded(at: baseURL)
            AppLogger.storage.info("Created base directory")
            try createDirectoryIfNeeded(at: encryptedPhotosURL)
            AppLogger.storage.info("Created encrypted photos directory: \(self.encryptedPhotosURL.path)")
            try createDirectoryIfNeeded(at: thumbnailsURL)
            AppLogger.storage.info("Created thumbnails directory")
            try createDirectoryIfNeeded(at: metadataURL)
            AppLogger.storage.info("Created metadata directory")

            // Load photo index
            try loadPhotoIndex()
            AppLogger.storage.info("Loaded photo index with \(self.photoIndex.count) photos")

            isInitialized = true
        } catch {
            AppLogger.storage.error("Storage initialization failed: \(error.localizedDescription)")
            throw StorageError.initializationFailed
        }
    }

    /// Saves a photo with encryption and generates thumbnail
    /// - Parameters:
    ///   - data: Photo data to save
    ///   - metadata: Photo metadata
    /// - Returns: EncryptedPhoto object representing the saved photo
    /// - Throws: `StorageError` if save operation fails
    func savePhoto(data: Data, metadata: PhotoMetadata) async throws -> EncryptedPhoto {
        let perfSignpost = PerformanceSignpost(name: "Photo Save")
        defer { perfSignpost.end() }

        try ensureInitialized()

        guard !data.isEmpty else {
            throw StorageError.invalidPhotoData
        }

        let photoId = UUID()
        AppLogger.storage.info("Saving photo \(photoId.uuidString) - data size: \(data.count) bytes")

        do {
            // Encrypt data before writing
            let encryptedData = try encryptData(data)
            AppLogger.storage.info("Encrypted data size: \(encryptedData.count) bytes")

            // Save encrypted photo file
            let photoFileURL = encryptedPhotosURL.appendingPathComponent("\(photoId.uuidString).enc")
            AppLogger.storage.info("Writing to: \(photoFileURL.path)")
            try encryptedData.write(to: photoFileURL)

            // Set strict file permissions (0600 - owner read/write only)
            try setFilePermissions(at: photoFileURL)
            AppLogger.storage.info("Successfully wrote encrypted photo file with restricted permissions")

            // Generate and save thumbnail (optional - won't fail import if it fails)
            let thumbnailResult = try? await generateAndSaveThumbnail(from: data, photoId: photoId)
            let hasThumbnail = thumbnailResult != nil
            let thumbnailFailed = thumbnailResult == nil
            AppLogger.storage.info("Thumbnail generated: \(hasThumbnail), failed: \(thumbnailFailed)")

            // Create EncryptedPhoto object with hasThumbnail flag
            let photo = EncryptedPhoto(
                id: photoId,
                hasThumbnail: hasThumbnail,
                thumbnailGenerationFailed: thumbnailFailed,
                metadata: metadata,
                dateAdded: Date()
            )

            // Update index
            photoIndex[photoId] = photo
            try savePhotoIndex()
            AppLogger.storage.info("Photo index saved, total photos: \(self.photoIndex.count)")

            return photo
        } catch {
            AppLogger.storage.error("Failed to save photo: \(error.localizedDescription)")
            // Cleanup on failure
            try? await cleanupFailedSave(photoId: photoId)
            throw StorageError.saveFailed(reason: error.localizedDescription)
        }
    }

    /// Retrieves decrypted photo data
    /// - Parameter id: Photo identifier
    /// - Returns: Decrypted photo data
    /// - Throws: `StorageError` if retrieval fails
    func retrievePhoto(id: UUID) async throws -> Data {
        try ensureInitialized()

        guard let photo = photoIndex[id] else {
            throw StorageError.photoNotFound
        }

        do {
            // Read encrypted data
            let encryptedData = try Data(contentsOf: photo.encryptedFileURL)

            // Decrypt data before returning
            let decryptedData = try decryptData(encryptedData)

            return decryptedData
        } catch {
            throw StorageError.retrievalFailed(reason: error.localizedDescription)
        }
    }

    /// Deletes a photo and its associated files
    /// - Parameter id: Photo identifier
    /// - Throws: `StorageError` if deletion fails
    func deletePhoto(id: UUID) async throws {
        try ensureInitialized()

        guard let photo = photoIndex[id] else {
            throw StorageError.photoNotFound
        }

        do {
            // Securely delete encrypted photo file
            if fileManager.fileExists(atPath: photo.encryptedFileURL.path) {
                try await SecureDeletion.delete(fileAt: photo.encryptedFileURL)
            }

            // Securely delete thumbnail if it exists
            if let thumbnailURL = photo.thumbnailURL,
               fileManager.fileExists(atPath: thumbnailURL.path) {
                try await SecureDeletion.delete(fileAt: thumbnailURL)
            }

            // Remove from thumbnail cache
            await ThumbnailManager.shared.removeCachedThumbnail(for: id)

            // Remove from index
            photoIndex.removeValue(forKey: id)
            try savePhotoIndex()
        } catch {
            throw StorageError.deletionFailed(reason: error.localizedDescription)
        }
    }

    /// Lists all photos in storage
    /// - Returns: Array of all EncryptedPhoto objects
    func listAllPhotos() throws -> [EncryptedPhoto] {
        try ensureInitialized()
        return Array(photoIndex.values)
    }

    /// Retrieves a specific photo's metadata
    /// - Parameter id: Photo identifier
    /// - Returns: EncryptedPhoto object
    /// - Throws: `StorageError` if photo not found
    func getPhoto(id: UUID) throws -> EncryptedPhoto {
        try ensureInitialized()

        guard let photo = photoIndex[id] else {
            throw StorageError.photoNotFound
        }

        return photo
    }

    /// Updates photo metadata
    /// - Parameters:
    ///   - id: Photo identifier
    ///   - metadata: Updated metadata
    /// - Throws: `StorageError` if update fails
    func updateMetadata(id: UUID, metadata: PhotoMetadata) throws {
        try ensureInitialized()

        guard var photo = photoIndex[id] else {
            throw StorageError.photoNotFound
        }

        photo.metadata = metadata
        photoIndex[id] = photo
        try savePhotoIndex()
    }

    /// Returns storage statistics
    /// - Returns: Tuple with photo count and total size in bytes
    func getStorageStats() throws -> (photoCount: Int, totalSizeBytes: Int) {
        try ensureInitialized()

        let photoCount = photoIndex.count
        var totalSize = 0

        for photo in photoIndex.values {
            totalSize += photo.metadata.fileSize
        }

        return (photoCount: photoCount, totalSizeBytes: totalSize)
    }

    // MARK: - Thumbnail Regeneration

    /// Returns photos that need thumbnail regeneration
    /// - Returns: Array of photos without thumbnails or with failed thumbnail generation
    func photosNeedingThumbnails() throws -> [EncryptedPhoto] {
        try ensureInitialized()
        return photoIndex.values.filter { !$0.hasThumbnail || $0.thumbnailGenerationFailed }
    }

    /// Regenerates thumbnail for a specific photo
    /// - Parameter id: Photo identifier
    /// - Returns: Updated EncryptedPhoto with new thumbnail status
    /// - Throws: `StorageError` if photo not found or regeneration fails
    func regenerateThumbnail(for id: UUID) async throws -> EncryptedPhoto {
        try ensureInitialized()

        guard var photo = photoIndex[id] else {
            throw StorageError.photoNotFound
        }

        AppLogger.storage.info("Regenerating thumbnail for photo: \(id)")

        // Load and decrypt the original photo
        let encryptedData = try Data(contentsOf: photo.encryptedFileURL)
        let imageData = try decryptData(encryptedData)

        // Delete existing thumbnail if present
        let thumbnailFileURL = thumbnailsURL.appendingPathComponent("\(id.uuidString)_thumb.enc")
        if fileManager.fileExists(atPath: thumbnailFileURL.path) {
            try? fileManager.removeItem(at: thumbnailFileURL)
        }

        // Generate new thumbnail
        do {
            let thumbnailData = try await ThumbnailManager.shared.generateThumbnail(from: imageData)

            // Encrypt and save thumbnail
            let encryptedThumbnailData = try encryptData(thumbnailData)
            try encryptedThumbnailData.write(to: thumbnailFileURL)
            try setFilePermissions(at: thumbnailFileURL)

            // Cache the thumbnail
            await ThumbnailManager.shared.cacheThumbnail(thumbnailData, for: id)

            // Update photo status
            photo.setHasThumbnail(true)
            photo.setThumbnailGenerationFailed(false)
            photoIndex[id] = photo
            try savePhotoIndex()

            AppLogger.storage.info("Successfully regenerated thumbnail for photo: \(id)")
            return photo
        } catch {
            // Mark as failed again
            photo.setThumbnailGenerationFailed(true)
            photoIndex[id] = photo
            try savePhotoIndex()

            AppLogger.storage.error("Thumbnail regeneration failed for \(id): \(error.localizedDescription, privacy: .private)")
            throw StorageError.saveFailed(reason: "Thumbnail regeneration failed")
        }
    }

    /// Regenerates thumbnails for all photos that need them
    /// - Parameter progress: Optional callback to report progress (completed, total)
    /// - Returns: Number of successfully regenerated thumbnails
    func regenerateAllFailedThumbnails(progress: (@Sendable (Int, Int) -> Void)? = nil) async throws -> Int {
        let photosToRegenerate = try photosNeedingThumbnails()
        let total = photosToRegenerate.count

        guard total > 0 else {
            AppLogger.storage.info("No thumbnails need regeneration")
            return 0
        }

        AppLogger.storage.info("Regenerating \(total) failed thumbnails")

        var successCount = 0
        for (index, photo) in photosToRegenerate.enumerated() {
            do {
                _ = try await regenerateThumbnail(for: photo.id)
                successCount += 1
            } catch {
                AppLogger.storage.warning("Failed to regenerate thumbnail for \(photo.id): \(error.localizedDescription, privacy: .private)")
            }

            progress?(index + 1, total)
        }

        AppLogger.storage.info("Regenerated \(successCount)/\(total) thumbnails")
        return successCount
    }

    // MARK: - Private Methods

    /// Ensures storage is initialized
    private func ensureInitialized() throws {
        if !isInitialized {
            try initializeStorage()
        }
    }

    /// Directory permissions: 0700 (owner read/write/execute only)
    private static let directoryPermissions: Int = 0o700

    /// File permissions: 0600 (owner read/write only)
    private static let filePermissions: Int = 0o600

    /// Creates a directory if it doesn't exist with strict permissions
    private func createDirectoryIfNeeded(at url: URL) throws {
        if !fileManager.fileExists(atPath: url.path) {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)

            // Set strict permissions: 0700 (owner read/write/execute only)
            try fileManager.setAttributes(
                [.posixPermissions: Self.directoryPermissions],
                ofItemAtPath: url.path
            )

            AppLogger.storage.info("Created directory with restricted permissions (0700): \(url.lastPathComponent)")
        } else {
            // Verify existing directory has correct permissions and fix if needed
            try verifyAndFixDirectoryPermissions(at: url)
        }
    }

    /// Verifies directory has correct permissions and fixes if needed
    private func verifyAndFixDirectoryPermissions(at url: URL) throws {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        let permissions = attributes[.posixPermissions] as? Int

        if permissions != Self.directoryPermissions {
            let currentPerms = permissions.map { String(format: "%o", $0) } ?? "unknown"
            AppLogger.storage.warning("Directory has incorrect permissions (\(currentPerms)): \(url.lastPathComponent)")

            try fileManager.setAttributes(
                [.posixPermissions: Self.directoryPermissions],
                ofItemAtPath: url.path
            )

            AppLogger.storage.info("Fixed directory permissions to 0700: \(url.lastPathComponent)")
        }
    }

    /// Sets strict file permissions after writing
    private func setFilePermissions(at url: URL) throws {
        try fileManager.setAttributes(
            [.posixPermissions: Self.filePermissions],
            ofItemAtPath: url.path
        )
    }

    /// Generates and saves a thumbnail for a photo
    /// Note: If thumbnail generation fails, photo is still saved without thumbnail
    private func generateAndSaveThumbnail(from imageData: Data, photoId: UUID) async throws -> URL? {
        do {
            // Generate thumbnail - failures here won't block photo import
            let thumbnailData = try await ThumbnailManager.shared.generateThumbnail(from: imageData)

            // Encrypt thumbnail data before writing
            let encryptedThumbnailData = try encryptData(thumbnailData)

            // Save thumbnail with strict permissions
            let thumbnailFileURL = thumbnailsURL.appendingPathComponent("\(photoId.uuidString)_thumb.enc")
            try encryptedThumbnailData.write(to: thumbnailFileURL)
            try setFilePermissions(at: thumbnailFileURL)

            // Cache thumbnail
            await ThumbnailManager.shared.cacheThumbnail(thumbnailData, for: photoId)

            return thumbnailFileURL
        } catch {
            // Log thumbnail error but don't fail the entire import
            AppLogger.storage.warning("Thumbnail generation failed for \(photoId, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Loads the photo index from disk, attempting recovery if corrupted
    private func loadPhotoIndex() throws {
        let indexURL = metadataURL.appendingPathComponent(Self.metadataIndexFileName)

        guard fileManager.fileExists(atPath: indexURL.path) else {
            // No index file yet - check if there are orphaned photos to recover
            let orphanedPhotos = countOrphanedPhotos()
            if orphanedPhotos > 0 {
                AppLogger.storage.warning("No index file found but \(orphanedPhotos) encrypted photos exist - attempting recovery")
                try rebuildIndexFromFiles()
            } else {
                photoIndex = [:]
            }
            return
        }

        do {
            let data = try Data(contentsOf: indexURL)
            let photos = try JSONDecoder().decode([EncryptedPhoto].self, from: data)

            // Build index
            photoIndex = Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0) })

            AppLogger.storage.info("Loaded photo index with \(self.photoIndex.count) entries")
        } catch {
            AppLogger.storage.error("Photo index corrupted: \(error.localizedDescription, privacy: .private)")
            AppLogger.storage.notice("Attempting to rebuild index from filesystem...")

            // Backup the corrupted index for debugging
            try? backupCorruptedIndex(at: indexURL)

            // Try to rebuild from .enc files
            do {
                try rebuildIndexFromFiles()
                AppLogger.storage.notice("Successfully rebuilt photo index with \(self.photoIndex.count) photos")
            } catch {
                AppLogger.storage.fault("Index rebuild failed: \(error.localizedDescription, privacy: .private)")
                throw StorageError.metadataCorrupted
            }
        }
    }

    /// Counts encrypted photo files that exist on disk
    private func countOrphanedPhotos() -> Int {
        guard let files = try? fileManager.contentsOfDirectory(at: encryptedPhotosURL, includingPropertiesForKeys: nil) else {
            return 0
        }
        return files.filter { $0.pathExtension == "enc" && !$0.lastPathComponent.contains("_thumb") }.count
    }

    /// Backs up a corrupted index file for debugging
    private func backupCorruptedIndex(at indexURL: URL) throws {
        let backupURL = indexURL.deletingLastPathComponent()
            .appendingPathComponent("photo_index_corrupted_\(Date().timeIntervalSince1970).json")
        try fileManager.copyItem(at: indexURL, to: backupURL)
        AppLogger.storage.info("Backed up corrupted index to: \(backupURL.lastPathComponent)")
    }

    /// Rebuilds the photo index by scanning encrypted files on disk
    ///
    /// This is a recovery mechanism for when the index file is corrupted or missing.
    /// Some metadata will be lost (tags, favorites, EXIF) but photos will be accessible.
    private func rebuildIndexFromFiles() throws {
        var rebuiltIndex: [UUID: EncryptedPhoto] = [:]

        // Scan EncryptedPhotos directory
        let encryptedFiles: [URL]
        do {
            encryptedFiles = try fileManager.contentsOfDirectory(
                at: encryptedPhotosURL,
                includingPropertiesForKeys: [.creationDateKey, .fileSizeKey, .contentModificationDateKey]
            )
        } catch {
            AppLogger.storage.error("Cannot scan encrypted photos directory: \(error.localizedDescription, privacy: .private)")
            throw StorageError.initializationFailed
        }

        // Filter to only .enc files (excluding thumbnails)
        let photoFiles = encryptedFiles.filter { url in
            url.pathExtension == "enc" && !url.lastPathComponent.contains("_thumb")
        }

        AppLogger.storage.info("Found \(photoFiles.count) encrypted photo files to recover")

        for fileURL in photoFiles {
            // Parse UUID from filename (format: UUID.enc)
            let filename = fileURL.deletingPathExtension().lastPathComponent
            guard let photoId = UUID(uuidString: filename) else {
                AppLogger.storage.warning("Skipping invalid filename: \(fileURL.lastPathComponent)")
                continue
            }

            // Get file attributes
            let attributes: [FileAttributeKey: Any]
            do {
                attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
            } catch {
                AppLogger.storage.warning("Cannot read attributes for \(photoId): \(error.localizedDescription, privacy: .private)")
                continue
            }

            let fileSize = attributes[.size] as? Int ?? 0
            let creationDate = attributes[.creationDate] as? Date ?? Date()

            // Check if thumbnail exists
            let thumbnailURL = thumbnailsURL.appendingPathComponent("\(photoId.uuidString)_thumb.enc")
            let hasThumbnail = fileManager.fileExists(atPath: thumbnailURL.path)

            // Create minimal metadata (some info will be lost in recovery)
            let metadata = PhotoMetadata(
                originalFilename: "recovered_\(photoId.uuidString.prefix(8))",
                fileSize: fileSize,
                dateTaken: creationDate,
                width: nil,  // Unknown - would need to decrypt to determine
                height: nil, // Unknown - would need to decrypt to determine
                tags: [],
                albums: [],
                isFavorite: false
            )

            let photo = EncryptedPhoto(
                id: photoId,
                hasThumbnail: hasThumbnail,
                metadata: metadata,
                dateAdded: creationDate
            )

            rebuiltIndex[photoId] = photo
            AppLogger.storage.debug("Recovered photo: \(photoId)")
        }

        if rebuiltIndex.isEmpty && !photoFiles.isEmpty {
            AppLogger.storage.error("Recovery found \(photoFiles.count) files but couldn't parse any")
            throw StorageError.initializationFailed
        }

        photoIndex = rebuiltIndex

        // Save the rebuilt index
        if !rebuiltIndex.isEmpty {
            try savePhotoIndex()
            AppLogger.storage.notice("Rebuilt and saved index with \(rebuiltIndex.count) recovered photos")
        }
    }

    /// Saves the photo index to disk
    private func savePhotoIndex() throws {
        let indexURL = metadataURL.appendingPathComponent(Self.metadataIndexFileName)
        let photos = Array(photoIndex.values)

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(photos)
            try data.write(to: indexURL)

            // Set strict file permissions on metadata index
            try setFilePermissions(at: indexURL)
        } catch {
            throw StorageError.saveFailed(reason: "Failed to save metadata index")
        }
    }

    /// Cleans up files from a failed save operation
    private func cleanupFailedSave(photoId: UUID) async throws {
        let photoFileURL = encryptedPhotosURL.appendingPathComponent("\(photoId.uuidString).enc")
        let thumbnailFileURL = thumbnailsURL.appendingPathComponent("\(photoId.uuidString)_thumb.enc")

        if fileManager.fileExists(atPath: photoFileURL.path) {
            try? await SecureDeletion.delete(fileAt: photoFileURL)
        }

        if fileManager.fileExists(atPath: thumbnailFileURL.path) {
            try? await SecureDeletion.delete(fileAt: thumbnailFileURL)
        }

        photoIndex.removeValue(forKey: photoId)
    }
}

// MARK: - Encryption Integration

extension SecurePhotoStorage {
    /// Encrypts data using EncryptionManager
    /// - Parameter data: Data to encrypt
    /// - Returns: Encrypted data
    /// - Throws: Error if encryption fails
    private func encryptData(_ data: Data) throws -> Data {
        return try EncryptionManager.shared.encrypt(data: data)
    }

    /// Decrypts data using EncryptionManager
    /// - Parameter data: Encrypted data
    /// - Returns: Decrypted data
    /// - Throws: Error if decryption fails
    private func decryptData(_ data: Data) throws -> Data {
        return try EncryptionManager.shared.decrypt(data: data)
    }
}
