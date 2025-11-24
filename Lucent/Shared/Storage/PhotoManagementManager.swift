//
//  PhotoManagementManager.swift
//  Lucent
//
//  Created by Claude Code on 11/23/2024.
//

import Foundation
import Photos
import OSLog

/// Manages photo operations including deletion, moving, export, and sharing
actor PhotoManagementManager {
    // MARK: - Singleton

    static let shared = PhotoManagementManager()

    // MARK: - Dependencies

    private let storage = SecurePhotoStorage.shared
    private let logger = Logger(subsystem: "com.lucent.management", category: "photo-management")

    // MARK: - Error Types

    enum ManagementError: Error, LocalizedError {
        case photoNotFound
        case deletionFailed(reason: String)
        case moveToAlbumFailed(reason: String)
        case exportFailed(reason: String)
        case photoLibraryPermissionDenied
        case invalidPhotoData
        case operationCancelled

        var errorDescription: String? {
            switch self {
            case .photoNotFound:
                return "Photo not found"
            case .deletionFailed(let reason):
                return "Failed to delete photo: \(reason)"
            case .moveToAlbumFailed(let reason):
                return "Failed to move photo to album: \(reason)"
            case .exportFailed(let reason):
                return "Failed to export photo: \(reason)"
            case .photoLibraryPermissionDenied:
                return "Permission to access photo library denied"
            case .invalidPhotoData:
                return "Invalid photo data"
            case .operationCancelled:
                return "Operation was cancelled"
            }
        }
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Delete Operations

    /// Deletes a single photo with secure deletion
    /// - Parameter id: Photo identifier
    /// - Throws: ManagementError if deletion fails
    func deletePhoto(id: UUID) async throws {
        logger.info("Deleting photo: \(id.uuidString)")

        do {
            try await storage.deletePhoto(id: id)
            logger.info("Successfully deleted photo: \(id.uuidString)")
        } catch {
            logger.error("Failed to delete photo \(id.uuidString): \(error.localizedDescription)")
            throw ManagementError.deletionFailed(reason: error.localizedDescription)
        }
    }

    /// Deletes multiple photos in batch
    /// - Parameter ids: Array of photo identifiers
    /// - Returns: Dictionary mapping photo IDs to deletion results
    func deletePhotos(ids: [UUID]) async -> [UUID: Result<Void, Error>] {
        logger.info("Batch deleting \(ids.count) photos")
        var results: [UUID: Result<Void, Error>] = [:]

        for id in ids {
            do {
                try await deletePhoto(id: id)
                results[id] = .success(())
            } catch {
                results[id] = .failure(error)
            }
        }

        let successCount = results.values.filter {
            if case .success = $0 { return true }
            return false
        }.count

        logger.info("Batch deletion completed: \(successCount)/\(ids.count) successful")
        return results
    }

    // MARK: - Move to Album Operations

    /// Moves a photo to a specific album
    /// - Parameters:
    ///   - photoId: Photo identifier
    ///   - albumName: Target album name
    /// - Throws: ManagementError if move operation fails
    func moveToAlbum(photoId: UUID, albumName: String) async throws {
        logger.info("Moving photo \(photoId.uuidString) to album: \(albumName)")

        do {
            let photo = try await storage.getPhoto(id: photoId)
            var metadata = photo.metadata

            // Add to new album if not already there
            if !metadata.albums.contains(albumName) {
                metadata.addToAlbum(albumName)
                try await storage.updateMetadata(id: photoId, metadata: metadata)
                logger.info("Successfully moved photo to album: \(albumName)")
            } else {
                logger.debug("Photo already in album: \(albumName)")
            }
        } catch {
            logger.error("Failed to move photo to album: \(error.localizedDescription)")
            throw ManagementError.moveToAlbumFailed(reason: error.localizedDescription)
        }
    }

    /// Removes a photo from a specific album
    /// - Parameters:
    ///   - photoId: Photo identifier
    ///   - albumName: Album to remove from
    /// - Throws: ManagementError if operation fails
    func removeFromAlbum(photoId: UUID, albumName: String) async throws {
        logger.info("Removing photo \(photoId.uuidString) from album: \(albumName)")

        do {
            let photo = try await storage.getPhoto(id: photoId)
            var metadata = photo.metadata

            metadata.removeFromAlbum(albumName)
            try await storage.updateMetadata(id: photoId, metadata: metadata)
            logger.info("Successfully removed photo from album: \(albumName)")
        } catch {
            logger.error("Failed to remove photo from album: \(error.localizedDescription)")
            throw ManagementError.moveToAlbumFailed(reason: error.localizedDescription)
        }
    }

    /// Moves multiple photos to an album
    /// - Parameters:
    ///   - photoIds: Array of photo identifiers
    ///   - albumName: Target album name
    /// - Returns: Dictionary mapping photo IDs to operation results
    func movePhotosToAlbum(photoIds: [UUID], albumName: String) async -> [UUID: Result<Void, Error>] {
        logger.info("Batch moving \(photoIds.count) photos to album: \(albumName)")
        var results: [UUID: Result<Void, Error>] = [:]

        for id in photoIds {
            do {
                try await moveToAlbum(photoId: id, albumName: albumName)
                results[id] = .success(())
            } catch {
                results[id] = .failure(error)
            }
        }

        return results
    }

    // MARK: - Favorite Operations

    /// Toggles favorite status for a photo
    /// - Parameter photoId: Photo identifier
    /// - Returns: New favorite status
    /// - Throws: ManagementError if operation fails
    func toggleFavorite(photoId: UUID) async throws -> Bool {
        logger.info("Toggling favorite for photo: \(photoId.uuidString)")

        do {
            let photo = try await storage.getPhoto(id: photoId)
            var metadata = photo.metadata

            metadata.isFavorite.toggle()
            let newStatus = metadata.isFavorite

            try await storage.updateMetadata(id: photoId, metadata: metadata)
            logger.info("Toggled favorite to: \(newStatus)")

            return newStatus
        } catch {
            logger.error("Failed to toggle favorite: \(error.localizedDescription)")
            throw ManagementError.moveToAlbumFailed(reason: error.localizedDescription)
        }
    }

    /// Sets favorite status for multiple photos
    /// - Parameters:
    ///   - photoIds: Array of photo identifiers
    ///   - isFavorite: Whether to mark as favorite
    /// - Returns: Dictionary mapping photo IDs to operation results
    func setFavorites(photoIds: [UUID], isFavorite: Bool) async -> [UUID: Result<Void, Error>] {
        logger.info("Batch setting favorite=\(isFavorite) for \(photoIds.count) photos")
        var results: [UUID: Result<Void, Error>] = [:]

        for id in photoIds {
            do {
                let photo = try await storage.getPhoto(id: id)
                var metadata = photo.metadata
                metadata.isFavorite = isFavorite
                try await storage.updateMetadata(id: id, metadata: metadata)
                results[id] = .success(())
            } catch {
                results[id] = .failure(error)
            }
        }

        return results
    }

    // MARK: - Tag Operations

    /// Adds a tag to a photo
    /// - Parameters:
    ///   - photoId: Photo identifier
    ///   - tag: Tag to add
    /// - Throws: ManagementError if operation fails
    func addTag(to photoId: UUID, tag: String) async throws {
        logger.info("Adding tag '\(tag)' to photo: \(photoId.uuidString)")

        do {
            let photo = try await storage.getPhoto(id: photoId)
            var metadata = photo.metadata

            metadata.addTag(tag)
            try await storage.updateMetadata(id: photoId, metadata: metadata)
            logger.info("Successfully added tag: \(tag)")
        } catch {
            logger.error("Failed to add tag: \(error.localizedDescription)")
            throw ManagementError.moveToAlbumFailed(reason: error.localizedDescription)
        }
    }

    /// Removes a tag from a photo
    /// - Parameters:
    ///   - photoId: Photo identifier
    ///   - tag: Tag to remove
    /// - Throws: ManagementError if operation fails
    func removeTag(from photoId: UUID, tag: String) async throws {
        logger.info("Removing tag '\(tag)' from photo: \(photoId.uuidString)")

        do {
            let photo = try await storage.getPhoto(id: photoId)
            var metadata = photo.metadata

            metadata.removeTag(tag)
            try await storage.updateMetadata(id: photoId, metadata: metadata)
            logger.info("Successfully removed tag: \(tag)")
        } catch {
            logger.error("Failed to remove tag: \(error.localizedDescription)")
            throw ManagementError.moveToAlbumFailed(reason: error.localizedDescription)
        }
    }

    /// Adds tags to multiple photos
    /// - Parameters:
    ///   - photoIds: Array of photo identifiers
    ///   - tags: Tags to add
    /// - Returns: Dictionary mapping photo IDs to operation results
    func addTagsToPhotos(photoIds: [UUID], tags: [String]) async -> [UUID: Result<Void, Error>] {
        logger.info("Batch adding \(tags.count) tags to \(photoIds.count) photos")
        var results: [UUID: Result<Void, Error>] = [:]

        for id in photoIds {
            do {
                let photo = try await storage.getPhoto(id: id)
                var metadata = photo.metadata

                for tag in tags {
                    metadata.addTag(tag)
                }

                try await storage.updateMetadata(id: id, metadata: metadata)
                results[id] = .success(())
            } catch {
                results[id] = .failure(error)
            }
        }

        return results
    }
}
