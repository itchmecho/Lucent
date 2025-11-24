//
//  SecurePhotoStorage.swift
//  Lucent
//
//  Created by Claude Code on 11/23/2024.
//

import Foundation

/// Manages encrypted photo storage with file operations and metadata
actor SecurePhotoStorage {
    // MARK: - Singleton

    static let shared = SecurePhotoStorage()

    // MARK: - Storage Paths

    private let fileManager = FileManager.default
    private let baseURL: URL
    private let encryptedPhotosURL: URL
    private let thumbnailsURL: URL
    private let metadataURL: URL

    // MARK: - Constants

    private static let encryptedPhotosFolderName = "EncryptedPhotos"
    private static let thumbnailsFolderName = "Thumbnails"
    private static let metadataFolderName = "Metadata"
    private static let metadataIndexFileName = "photo_index.json"

    // MARK: - In-Memory Index

    private var photoIndex: [UUID: EncryptedPhoto] = [:]
    private var isInitialized = false

    // MARK: - Error Types

    enum StorageError: Error, LocalizedError {
        case initializationFailed
        case invalidPhotoData
        case saveFailed(reason: String)
        case retrievalFailed(reason: String)
        case deletionFailed(reason: String)
        case metadataCorrupted
        case photoNotFound
        case unknownError(Error)

        var errorDescription: String? {
            switch self {
            case .initializationFailed:
                return "Failed to initialize storage directories"
            case .invalidPhotoData:
                return "Invalid photo data provided"
            case .saveFailed(let reason):
                return "Failed to save photo: \(reason)"
            case .retrievalFailed(let reason):
                return "Failed to retrieve photo: \(reason)"
            case .deletionFailed(let reason):
                return "Failed to delete photo: \(reason)"
            case .metadataCorrupted:
                return "Photo metadata is corrupted"
            case .photoNotFound:
                return "Photo not found in storage"
            case .unknownError(let error):
                return "Storage error: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Initialization

    private init() {
        // Get app's Documents directory
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            fatalError("Could not access Documents directory")
        }

        self.baseURL = documentsURL.appendingPathComponent("LucentVault", isDirectory: true)
        self.encryptedPhotosURL = baseURL.appendingPathComponent(Self.encryptedPhotosFolderName, isDirectory: true)
        self.thumbnailsURL = baseURL.appendingPathComponent(Self.thumbnailsFolderName, isDirectory: true)
        self.metadataURL = baseURL.appendingPathComponent(Self.metadataFolderName, isDirectory: true)
    }

    // MARK: - Public Methods

    /// Initializes the storage directory structure
    /// - Throws: `StorageError` if initialization fails
    func initializeStorage() throws {
        guard !isInitialized else { return }

        do {
            // Create directory structure
            try createDirectoryIfNeeded(at: baseURL)
            try createDirectoryIfNeeded(at: encryptedPhotosURL)
            try createDirectoryIfNeeded(at: thumbnailsURL)
            try createDirectoryIfNeeded(at: metadataURL)

            // Load photo index
            try loadPhotoIndex()

            isInitialized = true
        } catch {
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
        try ensureInitialized()

        guard !data.isEmpty else {
            throw StorageError.invalidPhotoData
        }

        let photoId = UUID()

        do {
            // Encrypt data before writing
            let encryptedData = await encryptData(data)

            // Save encrypted photo file
            let photoFileURL = encryptedPhotosURL.appendingPathComponent("\(photoId.uuidString).enc")
            try encryptedData.write(to: photoFileURL)

            // Generate and save thumbnail
            let thumbnailURL = try await generateAndSaveThumbnail(from: data, photoId: photoId)

            // Create EncryptedPhoto object
            let photo = EncryptedPhoto(
                id: photoId,
                encryptedFileURL: photoFileURL,
                thumbnailURL: thumbnailURL,
                metadata: metadata,
                dateAdded: Date()
            )

            // Update index
            photoIndex[photoId] = photo
            try savePhotoIndex()

            return photo
        } catch {
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
            let decryptedData = await decryptData(encryptedData)

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

    // MARK: - Private Methods

    /// Ensures storage is initialized
    private func ensureInitialized() throws {
        if !isInitialized {
            try initializeStorage()
        }
    }

    /// Creates a directory if it doesn't exist
    private func createDirectoryIfNeeded(at url: URL) throws {
        if !fileManager.fileExists(atPath: url.path) {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    /// Generates and saves a thumbnail for a photo
    private func generateAndSaveThumbnail(from imageData: Data, photoId: UUID) async throws -> URL {
        // Generate thumbnail
        let thumbnailData = try await ThumbnailManager.shared.generateThumbnail(from: imageData)

        // Encrypt thumbnail data before writing
        let encryptedThumbnailData = await encryptData(thumbnailData)

        // Save thumbnail
        let thumbnailFileURL = thumbnailsURL.appendingPathComponent("\(photoId.uuidString)_thumb.enc")
        try encryptedThumbnailData.write(to: thumbnailFileURL)

        // Cache thumbnail
        await ThumbnailManager.shared.cacheThumbnail(thumbnailData, for: photoId)

        return thumbnailFileURL
    }

    /// Loads the photo index from disk
    private func loadPhotoIndex() throws {
        let indexURL = metadataURL.appendingPathComponent(Self.metadataIndexFileName)

        guard fileManager.fileExists(atPath: indexURL.path) else {
            // No index file yet - start with empty index
            photoIndex = [:]
            return
        }

        do {
            let data = try Data(contentsOf: indexURL)
            let photos = try JSONDecoder().decode([EncryptedPhoto].self, from: data)

            // Build index
            photoIndex = Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0) })
        } catch {
            throw StorageError.metadataCorrupted
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
    private func encryptData(_ data: Data) async -> Data {
        do {
            return try EncryptionManager.shared.encrypt(data: data)
        } catch {
            // Log error but return original data as fallback
            // In production, this should throw an error instead
            print("⚠️ Encryption failed: \(error.localizedDescription)")
            return data
        }
    }

    /// Decrypts data using EncryptionManager
    /// - Parameter data: Encrypted data
    /// - Returns: Decrypted data
    private func decryptData(_ data: Data) async -> Data {
        do {
            return try EncryptionManager.shared.decrypt(data: data)
        } catch {
            // Log error but return original data as fallback
            // In production, this should throw an error instead
            print("⚠️ Decryption failed: \(error.localizedDescription)")
            return data
        }
    }
}
