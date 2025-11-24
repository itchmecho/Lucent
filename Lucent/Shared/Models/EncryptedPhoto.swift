//
//  EncryptedPhoto.swift
//  Lucent
//
//  Created by Claude Code on 11/23/2024.
//

import Foundation

/// Represents an encrypted photo stored in the secure vault
struct EncryptedPhoto: Identifiable, Codable, Sendable {
    // MARK: - Properties

    /// Unique identifier for the photo
    let id: UUID

    /// URL to the encrypted photo file
    let encryptedFileURL: URL

    /// URL to the encrypted thumbnail file (optional)
    var thumbnailURL: URL?

    /// Metadata associated with the photo
    var metadata: PhotoMetadata

    /// Date when the photo was added to the vault
    let dateAdded: Date

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        encryptedFileURL: URL,
        thumbnailURL: URL? = nil,
        metadata: PhotoMetadata,
        dateAdded: Date = Date()
    ) {
        self.id = id
        self.encryptedFileURL = encryptedFileURL
        self.thumbnailURL = thumbnailURL
        self.metadata = metadata
        self.dateAdded = dateAdded
    }

    // MARK: - Computed Properties

    /// The original filename if available
    var filename: String {
        metadata.originalFilename ?? "Photo \(id.uuidString.prefix(8))"
    }

    /// Whether a thumbnail is available
    var hasThumbnail: Bool {
        thumbnailURL != nil
    }

    /// Date the photo was taken, falling back to date added
    var displayDate: Date {
        metadata.dateTaken ?? dateAdded
    }

    /// Formatted file size
    var formattedFileSize: String {
        metadata.formattedFileSize
    }

    /// Image dimensions if available
    var dimensions: String? {
        metadata.dimensionsString
    }

    /// Whether the photo has location data
    var hasLocation: Bool {
        metadata.hasLocation
    }

    /// Tags for organization
    var tags: [String] {
        metadata.tags
    }

    /// Albums this photo belongs to
    var albums: [String] {
        metadata.albums
    }
}

// MARK: - Hashable Conformance

extension EncryptedPhoto: Hashable {
    static func == (lhs: EncryptedPhoto, rhs: EncryptedPhoto) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Sorting Helpers

extension EncryptedPhoto {
    enum SortOrder {
        case dateAddedNewest
        case dateAddedOldest
        case dateTakenNewest
        case dateTakenOldest
        case filename
        case fileSize
    }

    static func sorted(_ photos: [EncryptedPhoto], by order: SortOrder) -> [EncryptedPhoto] {
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
        }
    }
}
