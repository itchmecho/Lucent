//
//  SearchManager.swift
//  Lucent
//
//  Created by Claude Code on 11/23/2024.
//

import Foundation

/// Manages search and filtering operations for encrypted photos
actor SearchManager {
    // MARK: - Singleton

    static let shared = SearchManager()

    // MARK: - Search Options

    struct SearchOptions {
        var query: String = ""
        var searchInTags: Bool = true
        var searchInAlbums: Bool = true
        var searchInFilenames: Bool = true
        var searchInMetadata: Bool = true
        var favoriteOnly: Bool = false
        var dateRange: DateRange?
        var tags: [String] = []
        var albums: [String] = []
        var sortOrder: PhotoSortOrder = .dateAddedNewest

        init() {}
    }

    struct DateRange {
        var start: Date
        var end: Date

        init(start: Date, end: Date) {
            self.start = start
            self.end = end
        }
    }

    // MARK: - Search Results

    struct SearchResult {
        var photos: [EncryptedPhoto]
        var matchedTags: Set<String>
        var matchedAlbums: Set<String>
        var totalMatches: Int

        init(photos: [EncryptedPhoto] = [], matchedTags: Set<String> = [], matchedAlbums: Set<String> = []) {
            self.photos = photos
            self.matchedTags = matchedTags
            self.matchedAlbums = matchedAlbums
            self.totalMatches = photos.count
        }
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Search Methods

    /// Performs a comprehensive search across all photos
    /// - Parameter options: Search options
    /// - Returns: Search results
    func search(options: SearchOptions) async throws -> SearchResult {
        let storage = SecurePhotoStorage.shared
        let allPhotos = try await storage.listAllPhotos()

        var filteredPhotos = allPhotos
        var matchedTags = Set<String>()
        var matchedAlbums = Set<String>()

        // Apply text search
        if !options.query.isEmpty {
            filteredPhotos = filterByQuery(filteredPhotos, query: options.query, options: options)

            // Collect matched tags and albums for UI display
            for photo in filteredPhotos {
                photo.metadata.tags.forEach { matchedTags.insert($0) }
                photo.metadata.albums.forEach { matchedAlbums.insert($0) }
            }
        }

        // Apply tag filter
        if !options.tags.isEmpty {
            filteredPhotos = filterByTags(filteredPhotos, tags: options.tags)
        }

        // Apply album filter
        if !options.albums.isEmpty {
            filteredPhotos = filterByAlbums(filteredPhotos, albums: options.albums)
        }

        // Apply favorite filter
        if options.favoriteOnly {
            filteredPhotos = filteredPhotos.filter { $0.metadata.isFavorite }
        }

        // Apply date range filter
        if let dateRange = options.dateRange {
            filteredPhotos = filterByDateRange(filteredPhotos, range: dateRange)
        }

        // Apply sorting
        filteredPhotos = sortPhotos(filteredPhotos, by: options.sortOrder)

        return SearchResult(
            photos: filteredPhotos,
            matchedTags: matchedTags,
            matchedAlbums: matchedAlbums
        )
    }

    /// Quick search by query string
    /// - Parameter query: Search query
    /// - Returns: Matching photos
    func quickSearch(query: String) async throws -> [EncryptedPhoto] {
        var options = SearchOptions()
        options.query = query
        let result = try await search(options: options)
        return result.photos
    }

    /// Search photos by tags
    /// - Parameter tags: Array of tags to match
    /// - Returns: Photos matching any of the tags
    func searchByTags(_ tags: [String]) async throws -> [EncryptedPhoto] {
        var options = SearchOptions()
        options.tags = tags
        let result = try await search(options: options)
        return result.photos
    }

    /// Search photos by date range
    /// - Parameters:
    ///   - start: Start date
    ///   - end: End date
    /// - Returns: Photos within the date range
    func searchByDateRange(start: Date, end: Date) async throws -> [EncryptedPhoto] {
        var options = SearchOptions()
        options.dateRange = DateRange(start: start, end: end)
        let result = try await search(options: options)
        return result.photos
    }

    /// Get all unique tags from all photos
    /// - Returns: Array of unique tags sorted alphabetically
    func getAllTags() async throws -> [String] {
        let storage = SecurePhotoStorage.shared
        let allPhotos = try await storage.listAllPhotos()

        var tags = Set<String>()
        for photo in allPhotos {
            photo.metadata.tags.forEach { tags.insert($0) }
        }

        return Array(tags).sorted()
    }

    /// Get tag usage statistics
    /// - Returns: Dictionary mapping tags to usage count
    func getTagStatistics() async throws -> [String: Int] {
        let storage = SecurePhotoStorage.shared
        let allPhotos = try await storage.listAllPhotos()

        var tagCounts: [String: Int] = [:]
        for photo in allPhotos {
            for tag in photo.metadata.tags {
                tagCounts[tag, default: 0] += 1
            }
        }

        return tagCounts
    }

    /// Get photos with a specific tag
    /// - Parameter tag: Tag to search for
    /// - Returns: Photos with the tag
    func getPhotosWithTag(_ tag: String) async throws -> [EncryptedPhoto] {
        let storage = SecurePhotoStorage.shared
        let allPhotos = try await storage.listAllPhotos()

        return allPhotos.filter { photo in
            photo.metadata.tags.contains(tag)
        }
    }

    /// Get favorite photos
    /// - Returns: All favorite photos
    func getFavoritePhotos() async throws -> [EncryptedPhoto] {
        let storage = SecurePhotoStorage.shared
        let allPhotos = try await storage.listAllPhotos()

        return allPhotos.filter { $0.metadata.isFavorite }
            .sorted { $0.dateAdded > $1.dateAdded }
    }

    // MARK: - Private Filter Methods

    private func filterByQuery(_ photos: [EncryptedPhoto], query: String, options: SearchOptions) -> [EncryptedPhoto] {
        let lowercasedQuery = query.lowercased()

        return photos.filter { photo in
            // Search in tags
            if options.searchInTags {
                for tag in photo.metadata.tags {
                    if tag.lowercased().contains(lowercasedQuery) {
                        return true
                    }
                }
            }

            // Search in albums
            if options.searchInAlbums {
                for album in photo.metadata.albums {
                    if album.lowercased().contains(lowercasedQuery) {
                        return true
                    }
                }
            }

            // Search in filename
            if options.searchInFilenames {
                if let filename = photo.metadata.originalFilename,
                   filename.lowercased().contains(lowercasedQuery) {
                    return true
                }
            }

            // Search in metadata
            if options.searchInMetadata {
                // Search in camera info
                if let cameraMake = photo.metadata.cameraMake,
                   cameraMake.lowercased().contains(lowercasedQuery) {
                    return true
                }
                if let cameraModel = photo.metadata.cameraModel,
                   cameraModel.lowercased().contains(lowercasedQuery) {
                    return true
                }
            }

            return false
        }
    }

    private func filterByTags(_ photos: [EncryptedPhoto], tags: [String]) -> [EncryptedPhoto] {
        return photos.filter { photo in
            // Match photos that have ANY of the specified tags
            for tag in tags {
                if photo.metadata.tags.contains(tag) {
                    return true
                }
            }
            return false
        }
    }

    private func filterByAlbums(_ photos: [EncryptedPhoto], albums: [String]) -> [EncryptedPhoto] {
        return photos.filter { photo in
            // Match photos that belong to ANY of the specified albums
            for album in albums {
                if photo.metadata.albums.contains(album) {
                    return true
                }
            }
            return false
        }
    }

    private func filterByDateRange(_ photos: [EncryptedPhoto], range: DateRange) -> [EncryptedPhoto] {
        return photos.filter { photo in
            let date = photo.displayDate
            return date >= range.start && date <= range.end
        }
    }

    private func sortPhotos(_ photos: [EncryptedPhoto], by order: PhotoSortOrder) -> [EncryptedPhoto] {
        switch order {
        case .dateAddedNewest:
            return photos.sorted { $0.dateAdded > $1.dateAdded }
        case .dateAddedOldest:
            return photos.sorted { $0.dateAdded < $1.dateAdded }
        case .dateTakenNewest:
            return photos.sorted { $0.displayDate > $1.displayDate }
        case .dateTakenOldest:
            return photos.sorted { $0.displayDate < $1.displayDate }
        case .filename:
            return photos.sorted { $0.filename < $1.filename }
        case .fileSize:
            return photos.sorted { $0.metadata.fileSize > $1.metadata.fileSize }
        case .custom:
            return photos
        }
    }
}

// MARK: - Suggested Searches

extension SearchManager {
    /// Get suggested search queries based on recent activity
    func getSuggestedSearches() async throws -> [String] {
        // Return top 10 most used tags as suggestions
        let tagStats = try await getTagStatistics()
        let sortedTags = tagStats.sorted { $0.value > $1.value }

        return Array(sortedTags.prefix(10).map { $0.key })
    }
}
