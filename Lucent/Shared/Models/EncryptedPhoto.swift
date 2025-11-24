//
//  EncryptedPhoto.swift
//  Lucent
//
//  Created by Claude Code on 11/23/2024.
//

import Foundation

/// Represents an encrypted photo stored in the secure vault
struct EncryptedPhoto: Identifiable, Sendable {
    // MARK: - Properties

    /// Unique identifier for the photo
    let id: UUID

    /// URL to the encrypted photo file (dynamically constructed)
    var encryptedFileURL: URL {
        SecurePhotoStorage.shared.encryptedPhotosURL.appendingPathComponent("\(id.uuidString).enc")
    }

    /// URL to the encrypted thumbnail file (dynamically constructed if thumbnail exists)
    var thumbnailURL: URL? {
        guard hasThumbnail else { return nil }
        return SecurePhotoStorage.shared.thumbnailsURL.appendingPathComponent("\(id.uuidString)_thumb.enc")
    }

    /// Whether a thumbnail exists for this photo
    private(set) var hasThumbnail: Bool

    /// Metadata associated with the photo
    var metadata: PhotoMetadata

    /// Date when the photo was added to the vault
    let dateAdded: Date

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        hasThumbnail: Bool = false,
        metadata: PhotoMetadata,
        dateAdded: Date = Date()
    ) {
        self.id = id
        self.hasThumbnail = hasThumbnail
        self.metadata = metadata
        self.dateAdded = dateAdded
    }

    // MARK: - Helper Methods

    /// Updates thumbnail availability status
    mutating func setHasThumbnail(_ has: Bool) {
        self.hasThumbnail = has
    }

    // MARK: - Computed Properties

    /// The original filename if available
    var filename: String {
        metadata.originalFilename ?? "Photo \(id.uuidString.prefix(8))"
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

// MARK: - Codable Conformance

extension EncryptedPhoto: Codable {
    enum CodingKeys: String, CodingKey {
        case id
        case hasThumbnail
        case metadata
        case dateAdded
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.hasThumbnail = try container.decodeIfPresent(Bool.self, forKey: .hasThumbnail) ?? false
        self.metadata = try container.decode(PhotoMetadata.self, forKey: .metadata)
        self.dateAdded = try container.decode(Date.self, forKey: .dateAdded)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(hasThumbnail, forKey: .hasThumbnail)
        try container.encode(metadata, forKey: .metadata)
        try container.encode(dateAdded, forKey: .dateAdded)
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
