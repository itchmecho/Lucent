//
//  Album.swift
//  Lucent
//
//  Created by Claude Code on 11/23/2024.
//

import Foundation

/// Represents a photo album/collection in the vault
struct Album: Identifiable, Codable, Sendable {
    // MARK: - Properties

    /// Unique identifier for the album
    let id: UUID

    /// Album name
    var name: String

    /// Optional description of the album
    var description: String?

    /// Date the album was created
    let dateCreated: Date

    /// Date the album was last modified
    var dateModified: Date

    /// Cover photo ID (optional)
    var coverPhotoId: UUID?

    /// Array of photo IDs in this album
    var photoIds: [UUID]

    /// Whether this is a system album (e.g., Favorites, All Photos)
    let isSystemAlbum: Bool

    /// Color theme for the album (optional hex color string)
    var themeColor: String?

    /// Sort order preference for photos in this album
    var sortOrder: PhotoSortOrder

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        dateCreated: Date = Date(),
        dateModified: Date = Date(),
        coverPhotoId: UUID? = nil,
        photoIds: [UUID] = [],
        isSystemAlbum: Bool = false,
        themeColor: String? = nil,
        sortOrder: PhotoSortOrder = .dateAddedNewest
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.dateCreated = dateCreated
        self.dateModified = dateModified
        self.coverPhotoId = coverPhotoId
        self.photoIds = photoIds
        self.isSystemAlbum = isSystemAlbum
        self.themeColor = themeColor
        self.sortOrder = sortOrder
    }

    // MARK: - Computed Properties

    /// Number of photos in the album
    var photoCount: Int {
        photoIds.count
    }

    /// Whether the album is empty
    var isEmpty: Bool {
        photoIds.isEmpty
    }

    /// Whether the album has a cover photo set
    var hasCoverPhoto: Bool {
        coverPhotoId != nil
    }

    // MARK: - Mutating Methods

    /// Adds a photo to the album
    mutating func addPhoto(_ photoId: UUID) {
        if !photoIds.contains(photoId) {
            photoIds.append(photoId)
            dateModified = Date()

            // Set as cover photo if this is the first photo
            if coverPhotoId == nil {
                coverPhotoId = photoId
            }
        }
    }

    /// Removes a photo from the album
    mutating func removePhoto(_ photoId: UUID) {
        photoIds.removeAll { $0 == photoId }
        dateModified = Date()

        // Clear cover photo if it was removed
        if coverPhotoId == photoId {
            coverPhotoId = photoIds.first
        }
    }

    /// Adds multiple photos to the album
    mutating func addPhotos(_ photoIds: [UUID]) {
        for photoId in photoIds {
            addPhoto(photoId)
        }
    }

    /// Removes multiple photos from the album
    mutating func removePhotos(_ photoIds: [UUID]) {
        for photoId in photoIds {
            removePhoto(photoId)
        }
    }

    /// Sets the cover photo for the album
    mutating func setCoverPhoto(_ photoId: UUID?) {
        // Only allow setting a photo that's in the album
        if let id = photoId {
            guard photoIds.contains(id) else { return }
        }
        coverPhotoId = photoId
        dateModified = Date()
    }

    /// Updates the album name
    mutating func rename(_ newName: String) {
        name = newName
        dateModified = Date()
    }

    /// Updates the album description
    mutating func updateDescription(_ newDescription: String?) {
        description = newDescription
        dateModified = Date()
    }

    /// Updates the theme color
    mutating func updateThemeColor(_ color: String?) {
        themeColor = color
        dateModified = Date()
    }

    /// Updates the sort order
    mutating func updateSortOrder(_ order: PhotoSortOrder) {
        sortOrder = order
        dateModified = Date()
    }
}

// MARK: - Hashable Conformance

extension Album: Hashable {
    static func == (lhs: Album, rhs: Album) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Photo Sort Order

enum PhotoSortOrder: String, Codable, CaseIterable, Sendable {
    case dateAddedNewest = "Date Added (Newest)"
    case dateAddedOldest = "Date Added (Oldest)"
    case dateTakenNewest = "Date Taken (Newest)"
    case dateTakenOldest = "Date Taken (Oldest)"
    case filename = "Filename"
    case fileSize = "File Size"
    case custom = "Custom Order"

    var displayName: String {
        rawValue
    }

    var systemImageName: String {
        switch self {
        case .dateAddedNewest, .dateTakenNewest:
            return "arrow.down.circle.fill"
        case .dateAddedOldest, .dateTakenOldest:
            return "arrow.up.circle.fill"
        case .filename:
            return "textformat.abc"
        case .fileSize:
            return "doc.fill"
        case .custom:
            return "hand.point.up.braille.fill"
        }
    }
}

// MARK: - System Albums

extension Album {
    /// Creates a system "All Photos" album
    static func allPhotosAlbum() -> Album {
        Album(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "All Photos",
            description: "All photos in your vault",
            isSystemAlbum: true,
            sortOrder: .dateAddedNewest
        )
    }

    /// Creates a system "Favorites" album
    static func favoritesAlbum() -> Album {
        Album(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            name: "Favorites",
            description: "Your favorite photos",
            isSystemAlbum: true,
            themeColor: "#FF6B6B",
            sortOrder: .dateAddedNewest
        )
    }

    /// Creates a system "Recent" album
    static func recentAlbum() -> Album {
        Album(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            name: "Recent",
            description: "Recently added photos",
            isSystemAlbum: true,
            sortOrder: .dateAddedNewest
        )
    }
}
