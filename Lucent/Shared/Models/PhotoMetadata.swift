//
//  PhotoMetadata.swift
//  Lucent
//
//  Created by Claude Code on 11/23/2024.
//

import Foundation

/// Metadata for a photo including file information and optional EXIF data
struct PhotoMetadata: Codable, Sendable {
    // MARK: - Basic File Information

    /// Original filename of the photo
    var originalFilename: String?

    /// File size in bytes
    var fileSize: Int

    /// Date the photo was taken (from EXIF or file creation date)
    var dateTaken: Date?

    /// Image width in pixels
    var width: Int?

    /// Image height in pixels
    var height: Int?

    // MARK: - Organization

    /// User-assigned tags for categorization
    var tags: [String]

    /// Albums this photo belongs to
    var albums: [String]

    // MARK: - EXIF Data (Enhanced Later)

    /// Camera make (e.g., "Apple")
    var cameraMake: String?

    /// Camera model (e.g., "iPhone 15 Pro")
    var cameraModel: String?

    /// GPS latitude
    var latitude: Double?

    /// GPS longitude
    var longitude: Double?

    /// ISO speed
    var iso: Int?

    /// Focal length in mm
    var focalLength: Double?

    /// Aperture value (f-number)
    var aperture: Double?

    /// Shutter speed in seconds
    var shutterSpeed: Double?

    // MARK: - Initialization

    init(
        originalFilename: String? = nil,
        fileSize: Int,
        dateTaken: Date? = nil,
        width: Int? = nil,
        height: Int? = nil,
        tags: [String] = [],
        albums: [String] = [],
        cameraMake: String? = nil,
        cameraModel: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        iso: Int? = nil,
        focalLength: Double? = nil,
        aperture: Double? = nil,
        shutterSpeed: Double? = nil
    ) {
        self.originalFilename = originalFilename
        self.fileSize = fileSize
        self.dateTaken = dateTaken
        self.width = width
        self.height = height
        self.tags = tags
        self.albums = albums
        self.cameraMake = cameraMake
        self.cameraModel = cameraModel
        self.latitude = latitude
        self.longitude = longitude
        self.iso = iso
        self.focalLength = focalLength
        self.aperture = aperture
        self.shutterSpeed = shutterSpeed
    }

    // MARK: - Computed Properties

    /// Formatted file size string (e.g., "2.5 MB")
    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(fileSize))
    }

    /// Image dimensions as a string (e.g., "1920x1080")
    var dimensionsString: String? {
        guard let width = width, let height = height else { return nil }
        return "\(width)×\(height)"
    }

    /// Megapixel count
    var megapixels: Double? {
        guard let width = width, let height = height else { return nil }
        return Double(width * height) / 1_000_000
    }

    /// Whether location data is available
    var hasLocation: Bool {
        latitude != nil && longitude != nil
    }

    // MARK: - Helper Methods

    /// Add a tag to the photo
    mutating func addTag(_ tag: String) {
        if !tags.contains(tag) {
            tags.append(tag)
        }
    }

    /// Remove a tag from the photo
    mutating func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
    }

    /// Add photo to an album
    mutating func addToAlbum(_ album: String) {
        if !albums.contains(album) {
            albums.append(album)
        }
    }

    /// Remove photo from an album
    mutating func removeFromAlbum(_ album: String) {
        albums.removeAll { $0 == album }
    }
}

// MARK: - EXIF Extraction Extension (To be implemented)

extension PhotoMetadata {
    /// Extract metadata from image data
    /// TODO: Implement EXIF data extraction using ImageIO framework
    static func extract(from imageData: Data) -> PhotoMetadata? {
        // Placeholder for EXIF extraction
        // Will use CGImageSource and kCGImagePropertyExifDictionary
        return PhotoMetadata(fileSize: imageData.count)
    }
}
