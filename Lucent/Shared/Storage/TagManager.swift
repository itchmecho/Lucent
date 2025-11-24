//
//  TagManager.swift
//  Lucent
//
//  Created by Claude Code on 11/23/2024.
//

import Foundation

/// Manages tag operations including adding, removing, and batch operations
actor TagManager {
    // MARK: - Singleton

    static let shared = TagManager()

    // MARK: - Error Types

    enum TagError: Error, LocalizedError {
        case invalidTag
        case photoNotFound
        case storageError(Error)

        var errorDescription: String? {
            switch self {
            case .invalidTag:
                return "Tag cannot be empty"
            case .photoNotFound:
                return "Photo not found"
            case .storageError(let error):
                return "Storage error: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Tag Operations

    /// Adds a tag to a photo
    /// - Parameters:
    ///   - tag: Tag to add
    ///   - photoId: Photo identifier
    func addTag(_ tag: String, toPhoto photoId: UUID) async throws {
        let normalizedTag = normalizeTag(tag)

        guard !normalizedTag.isEmpty else {
            throw TagError.invalidTag
        }

        let storage = SecurePhotoStorage.shared

        guard var photo = try? await storage.getPhoto(id: photoId) else {
            throw TagError.photoNotFound
        }

        photo.metadata.addTag(normalizedTag)

        do {
            try await storage.updateMetadata(id: photoId, metadata: photo.metadata)
        } catch {
            throw TagError.storageError(error)
        }
    }

    /// Removes a tag from a photo
    /// - Parameters:
    ///   - tag: Tag to remove
    ///   - photoId: Photo identifier
    func removeTag(_ tag: String, fromPhoto photoId: UUID) async throws {
        let storage = SecurePhotoStorage.shared

        guard var photo = try? await storage.getPhoto(id: photoId) else {
            throw TagError.photoNotFound
        }

        photo.metadata.removeTag(tag)

        do {
            try await storage.updateMetadata(id: photoId, metadata: photo.metadata)
        } catch {
            throw TagError.storageError(error)
        }
    }

    /// Adds multiple tags to a photo
    /// - Parameters:
    ///   - tags: Array of tags to add
    ///   - photoId: Photo identifier
    func addTags(_ tags: [String], toPhoto photoId: UUID) async throws {
        let normalizedTags = tags.map { normalizeTag($0) }.filter { !$0.isEmpty }

        guard !normalizedTags.isEmpty else {
            throw TagError.invalidTag
        }

        let storage = SecurePhotoStorage.shared

        guard var photo = try? await storage.getPhoto(id: photoId) else {
            throw TagError.photoNotFound
        }

        for tag in normalizedTags {
            photo.metadata.addTag(tag)
        }

        do {
            try await storage.updateMetadata(id: photoId, metadata: photo.metadata)
        } catch {
            throw TagError.storageError(error)
        }
    }

    /// Sets tags for a photo (replaces existing tags)
    /// - Parameters:
    ///   - tags: Array of tags
    ///   - photoId: Photo identifier
    func setTags(_ tags: [String], forPhoto photoId: UUID) async throws {
        let normalizedTags = tags.map { normalizeTag($0) }.filter { !$0.isEmpty }

        let storage = SecurePhotoStorage.shared

        guard var photo = try? await storage.getPhoto(id: photoId) else {
            throw TagError.photoNotFound
        }

        photo.metadata.tags = normalizedTags

        do {
            try await storage.updateMetadata(id: photoId, metadata: photo.metadata)
        } catch {
            throw TagError.storageError(error)
        }
    }

    /// Removes all tags from a photo
    /// - Parameter photoId: Photo identifier
    func removeAllTags(fromPhoto photoId: UUID) async throws {
        try await setTags([], forPhoto: photoId)
    }

    /// Gets all tags for a photo
    /// - Parameter photoId: Photo identifier
    /// - Returns: Array of tags
    func getTags(forPhoto photoId: UUID) async throws -> [String] {
        let storage = SecurePhotoStorage.shared

        guard let photo = try? await storage.getPhoto(id: photoId) else {
            throw TagError.photoNotFound
        }

        return photo.metadata.tags
    }

    // MARK: - Batch Operations

    /// Adds a tag to multiple photos
    /// - Parameters:
    ///   - tag: Tag to add
    ///   - photoIds: Array of photo identifiers
    func addTagToPhotos(_ tag: String, photoIds: [UUID]) async throws {
        for photoId in photoIds {
            try await addTag(tag, toPhoto: photoId)
        }
    }

    /// Removes a tag from multiple photos
    /// - Parameters:
    ///   - tag: Tag to remove
    ///   - photoIds: Array of photo identifiers
    func removeTagFromPhotos(_ tag: String, photoIds: [UUID]) async throws {
        for photoId in photoIds {
            try await removeTag(tag, fromPhoto: photoId)
        }
    }

    // MARK: - Tag Management

    /// Gets all unique tags in the vault
    /// - Returns: Array of tags sorted alphabetically
    func getAllTags() async throws -> [String] {
        return try await SearchManager.shared.getAllTags()
    }

    /// Gets tag statistics
    /// - Returns: Dictionary mapping tags to photo count
    func getTagStatistics() async throws -> [String: Int] {
        return try await SearchManager.shared.getTagStatistics()
    }

    /// Renames a tag across all photos
    /// - Parameters:
    ///   - oldTag: Current tag name
    ///   - newTag: New tag name
    func renameTag(from oldTag: String, to newTag: String) async throws {
        let normalizedNewTag = normalizeTag(newTag)

        guard !normalizedNewTag.isEmpty else {
            throw TagError.invalidTag
        }

        let storage = SecurePhotoStorage.shared
        let allPhotos = try await storage.listAllPhotos()

        // Find all photos with the old tag
        for photo in allPhotos where photo.metadata.tags.contains(oldTag) {
            var updatedMetadata = photo.metadata
            updatedMetadata.removeTag(oldTag)
            updatedMetadata.addTag(normalizedNewTag)

            do {
                try await storage.updateMetadata(id: photo.id, metadata: updatedMetadata)
            } catch {
                throw TagError.storageError(error)
            }
        }
    }

    /// Deletes a tag from all photos
    /// - Parameter tag: Tag to delete
    func deleteTag(_ tag: String) async throws {
        let storage = SecurePhotoStorage.shared
        let allPhotos = try await storage.listAllPhotos()

        // Find all photos with the tag and remove it
        for photo in allPhotos where photo.metadata.tags.contains(tag) {
            var updatedMetadata = photo.metadata
            updatedMetadata.removeTag(tag)

            do {
                try await storage.updateMetadata(id: photo.id, metadata: updatedMetadata)
            } catch {
                throw TagError.storageError(error)
            }
        }
    }

    /// Merges multiple tags into one
    /// - Parameters:
    ///   - sourceTags: Tags to merge
    ///   - destinationTag: Tag to merge into
    func mergeTags(from sourceTags: [String], to destinationTag: String) async throws {
        let normalizedDestination = normalizeTag(destinationTag)

        guard !normalizedDestination.isEmpty else {
            throw TagError.invalidTag
        }

        let storage = SecurePhotoStorage.shared
        let allPhotos = try await storage.listAllPhotos()

        // Find all photos with any of the source tags
        for photo in allPhotos {
            var hasSourceTag = false
            var updatedMetadata = photo.metadata

            for sourceTag in sourceTags {
                if updatedMetadata.tags.contains(sourceTag) {
                    hasSourceTag = true
                    updatedMetadata.removeTag(sourceTag)
                }
            }

            if hasSourceTag {
                updatedMetadata.addTag(normalizedDestination)

                do {
                    try await storage.updateMetadata(id: photo.id, metadata: updatedMetadata)
                } catch {
                    throw TagError.storageError(error)
                }
            }
        }
    }

    // MARK: - Favorites

    /// Toggles favorite status for a photo
    /// - Parameter photoId: Photo identifier
    /// - Returns: New favorite status
    @discardableResult
    func toggleFavorite(photoId: UUID) async throws -> Bool {
        let storage = SecurePhotoStorage.shared

        guard var photo = try? await storage.getPhoto(id: photoId) else {
            throw TagError.photoNotFound
        }

        photo.metadata.isFavorite.toggle()

        do {
            try await storage.updateMetadata(id: photo.id, metadata: photo.metadata)
        } catch {
            throw TagError.storageError(error)
        }

        // Sync favorites album
        try await AlbumManager.shared.syncSystemAlbums()

        return photo.metadata.isFavorite
    }

    /// Sets favorite status for a photo
    /// - Parameters:
    ///   - photoId: Photo identifier
    ///   - isFavorite: Favorite status
    func setFavorite(photoId: UUID, isFavorite: Bool) async throws {
        let storage = SecurePhotoStorage.shared

        guard var photo = try? await storage.getPhoto(id: photoId) else {
            throw TagError.photoNotFound
        }

        photo.metadata.isFavorite = isFavorite

        do {
            try await storage.updateMetadata(id: photo.id, metadata: photo.metadata)
        } catch {
            throw TagError.storageError(error)
        }

        // Sync favorites album
        try await AlbumManager.shared.syncSystemAlbums()
    }

    /// Adds multiple photos to favorites
    /// - Parameter photoIds: Array of photo identifiers
    func addToFavorites(photoIds: [UUID]) async throws {
        for photoId in photoIds {
            try await setFavorite(photoId: photoId, isFavorite: true)
        }
    }

    /// Removes multiple photos from favorites
    /// - Parameter photoIds: Array of photo identifiers
    func removeFromFavorites(photoIds: [UUID]) async throws {
        for photoId in photoIds {
            try await setFavorite(photoId: photoId, isFavorite: false)
        }
    }

    // MARK: - Helper Methods

    /// Normalizes a tag by trimming whitespace and converting to lowercase
    /// - Parameter tag: Tag to normalize
    /// - Returns: Normalized tag
    private func normalizeTag(_ tag: String) -> String {
        return tag.trimmingCharacters(in: .whitespaces)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

// MARK: - Tag Suggestions

extension TagManager {
    /// Get suggested tags based on photo metadata
    /// - Parameter photoId: Photo identifier
    /// - Returns: Array of suggested tags
    func getSuggestedTags(forPhoto photoId: UUID) async throws -> [String] {
        let storage = SecurePhotoStorage.shared

        guard let photo = try? await storage.getPhoto(id: photoId) else {
            throw TagError.photoNotFound
        }

        var suggestions: [String] = []

        // Suggest camera model as tag
        if let cameraModel = photo.metadata.cameraModel {
            suggestions.append(cameraModel)
        }

        // Suggest location-based tags if available
        if photo.metadata.hasLocation {
            suggestions.append("Location")
        }

        // Suggest date-based tags
        let calendar = Calendar.current
        let date = photo.displayDate
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let monthName = calendar.monthSymbols[month - 1]

        suggestions.append("\(year)")
        suggestions.append("\(monthName) \(year)")

        // Get frequently used tags as suggestions
        let tagStats = try await getTagStatistics()
        let topTags = tagStats.sorted { $0.value > $1.value }
            .prefix(5)
            .map { $0.key }

        suggestions.append(contentsOf: topTags)

        // Remove duplicates and existing tags
        let existingTags = Set(photo.metadata.tags)
        return Array(Set(suggestions)).filter { !existingTags.contains($0) }
    }
}
