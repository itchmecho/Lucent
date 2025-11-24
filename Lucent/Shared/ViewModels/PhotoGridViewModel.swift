//
//  PhotoGridViewModel.swift
//  Lucent
//
//  Created by Claude Code on 11/23/2024.
//

import Foundation
import SwiftUI
import os.log

/// View model for managing the photo grid state and operations
@MainActor
class PhotoGridViewModel: ObservableObject {
    // MARK: - Published Properties

    /// All photos in the vault
    @Published var photos: [EncryptedPhoto] = []

    /// Loading state
    @Published var isLoading = false

    /// Error message if loading fails
    @Published var errorMessage: String?

    /// Current sort order
    @Published var sortOrder: EncryptedPhoto.SortOrder = .dateAddedNewest {
        didSet {
            sortPhotos()
        }
    }

    /// Search query for filtering photos
    @Published var searchQuery = "" {
        didSet {
            filterPhotos()
        }
    }

    /// Selected filter (all, favorites, albums, tags)
    @Published var selectedFilter: PhotoFilter = .all {
        didSet {
            filterPhotos()
        }
    }

    /// Selected album for filtering
    @Published var selectedAlbum: String? {
        didSet {
            filterPhotos()
        }
    }

    /// Selected tag for filtering
    @Published var selectedTag: String? {
        didSet {
            filterPhotos()
        }
    }

    /// Filtered photos based on search and filters
    @Published var filteredPhotos: [EncryptedPhoto] = []

    /// Loaded thumbnail images keyed by photo ID
    @Published var thumbnails: [UUID: PlatformImage] = [:]

    /// Photos currently being loaded (for loading indicators)
    @Published var loadingPhotos: Set<UUID> = []

    // MARK: - Private Properties

    private let storage = SecurePhotoStorage.shared
    private let thumbnailManager = ThumbnailManager.shared

    // MARK: - Filter Types

    enum PhotoFilter: Equatable {
        case all
        case favorites
        case album(String)
        case tag(String)
    }

    // MARK: - Initialization

    init() {
        Task {
            await loadPhotos()
        }
    }

    // MARK: - Public Methods

    /// Loads all photos from storage
    func loadPhotos() async {
        isLoading = true
        errorMessage = nil

        do {
            let allPhotos = try await storage.listAllPhotos()
            self.photos = allPhotos
            sortPhotos()
            filterPhotos()
        } catch {
            errorMessage = "Failed to load photos: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Loads thumbnail for a specific photo
    func loadThumbnail(for photo: EncryptedPhoto) async {
        // Skip if already loaded or loading
        guard thumbnails[photo.id] == nil, !loadingPhotos.contains(photo.id) else {
            return
        }

        loadingPhotos.insert(photo.id)

        do {
            // Try to get cached thumbnail first
            if let cachedData = await thumbnailManager.getCachedThumbnail(for: photo.id) {
                if let image = PlatformImage.from(data: cachedData) {
                    thumbnails[photo.id] = image
                    loadingPhotos.remove(photo.id)
                    return
                }
            }

            // Load and decrypt thumbnail
            if let thumbnailURL = photo.thumbnailURL {
                let encryptedData = try Data(contentsOf: thumbnailURL)
                let decryptedData = try EncryptionManager.shared.decrypt(data: encryptedData)

                // Cache decrypted thumbnail
                await thumbnailManager.cacheThumbnail(decryptedData, for: photo.id)

                // Create platform image
                if let image = PlatformImage.from(data: decryptedData) {
                    thumbnails[photo.id] = image
                }
            }
        } catch {
            AppLogger.storage.error("Failed to load thumbnail for \(photo.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }

        loadingPhotos.remove(photo.id)
    }

    /// Deletes a photo
    func deletePhoto(_ photo: EncryptedPhoto) async {
        do {
            try await storage.deletePhoto(id: photo.id)

            // Remove from local state
            photos.removeAll { $0.id == photo.id }
            filteredPhotos.removeAll { $0.id == photo.id }
            thumbnails.removeValue(forKey: photo.id)
        } catch {
            errorMessage = "Failed to delete photo: \(error.localizedDescription)"
        }
    }

    /// Toggles favorite status for a photo
    func toggleFavorite(_ photo: EncryptedPhoto) async {
        guard let index = photos.firstIndex(where: { $0.id == photo.id }) else { return }

        var updatedPhoto = photos[index]
        updatedPhoto.metadata.isFavorite.toggle()

        do {
            try await storage.updateMetadata(id: photo.id, metadata: updatedPhoto.metadata)
            photos[index] = updatedPhoto
            filterPhotos()
        } catch {
            errorMessage = "Failed to update favorite: \(error.localizedDescription)"
        }
    }

    /// Gets all unique albums
    func getAllAlbums() -> [String] {
        let allAlbums = photos.flatMap { $0.albums }
        return Array(Set(allAlbums)).sorted()
    }

    /// Gets all unique tags
    func getAllTags() -> [String] {
        let allTags = photos.flatMap { $0.tags }
        return Array(Set(allTags)).sorted()
    }

    /// Clears all loaded thumbnails from memory (security)
    func clearThumbnailsFromMemory() {
        thumbnails.removeAll()
    }

    /// Refreshes the photo grid
    func refresh() async {
        await loadPhotos()
    }

    // MARK: - Private Methods

    /// Sorts photos based on current sort order
    private func sortPhotos() {
        photos = EncryptedPhoto.sorted(photos, by: sortOrder)
        filterPhotos()
    }

    /// Filters photos based on search query and selected filter
    private func filterPhotos() {
        var result = photos

        // Apply filter
        switch selectedFilter {
        case .all:
            break
        case .favorites:
            result = result.filter { $0.metadata.isFavorite }
        case .album(let album):
            result = result.filter { $0.albums.contains(album) }
        case .tag(let tag):
            result = result.filter { $0.tags.contains(tag) }
        }

        // Apply album filter
        if let album = selectedAlbum {
            result = result.filter { $0.albums.contains(album) }
        }

        // Apply tag filter
        if let tag = selectedTag {
            result = result.filter { $0.tags.contains(tag) }
        }

        // Apply search query
        if !searchQuery.isEmpty {
            result = result.filter { photo in
                // Search in filename
                if photo.filename.localizedCaseInsensitiveContains(searchQuery) {
                    return true
                }

                // Search in tags
                if photo.tags.contains(where: { $0.localizedCaseInsensitiveContains(searchQuery) }) {
                    return true
                }

                // Search in albums
                if photo.albums.contains(where: { $0.localizedCaseInsensitiveContains(searchQuery) }) {
                    return true
                }

                return false
            }
        }

        filteredPhotos = result
    }
}

// MARK: - Platform Image Helpers

#if canImport(UIKit)
import UIKit
typealias PlatformImage = UIImage

extension UIImage {
    static func from(data: Data) -> UIImage? {
        return UIImage(data: data)
    }
}
#elseif canImport(AppKit)
import AppKit
typealias PlatformImage = NSImage

extension NSImage {
    static func from(data: Data) -> NSImage? {
        return NSImage(data: data)
    }
}
#endif
