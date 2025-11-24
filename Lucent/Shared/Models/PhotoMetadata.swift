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

    /// Whether this photo is marked as favorite
    var isFavorite: Bool

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
        isFavorite: Bool = false,
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
        self.isFavorite = isFavorite
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

// MARK: - EXIF Extraction Extension

import ImageIO
import CoreGraphics

extension PhotoMetadata {
    /// Extract metadata from image data using ImageIO framework
    /// - Parameter imageData: Raw image data to extract metadata from
    /// - Returns: PhotoMetadata with extracted EXIF data, or nil if extraction fails
    static func extract(from imageData: Data) -> PhotoMetadata? {
        guard let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            // If extraction fails, return basic metadata
            return PhotoMetadata(fileSize: imageData.count, dateTaken: Date())
        }

        // Extract basic file information
        let fileSize = imageData.count

        // Extract image dimensions
        var width: Int?
        var height: Int?
        if let pixelWidth = properties[kCGImagePropertyPixelWidth as String] as? Int,
           let pixelHeight = properties[kCGImagePropertyPixelHeight as String] as? Int {
            width = pixelWidth
            height = pixelHeight
        }

        // Extract EXIF data
        var dateTaken: Date?
        var cameraMake: String?
        var cameraModel: String?
        var iso: Int?
        var focalLength: Double?
        var aperture: Double?
        var shutterSpeed: Double?

        if let exifDict = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            // Date taken
            if let dateString = exifDict[kCGImagePropertyExifDateTimeOriginal as String] as? String {
                dateTaken = parseEXIFDate(dateString)
            }

            // ISO speed
            if let isoArray = exifDict[kCGImagePropertyExifISOSpeedRatings as String] as? [Int],
               let isoValue = isoArray.first {
                iso = isoValue
            }

            // Focal length
            if let focalLengthValue = exifDict[kCGImagePropertyExifFocalLength as String] as? Double {
                focalLength = focalLengthValue
            }

            // Aperture (f-number)
            if let apertureValue = exifDict[kCGImagePropertyExifFNumber as String] as? Double {
                aperture = apertureValue
            }

            // Shutter speed (exposure time)
            if let exposureTime = exifDict[kCGImagePropertyExifExposureTime as String] as? Double {
                shutterSpeed = exposureTime
            }
        }

        // Extract TIFF data (camera make/model)
        if let tiffDict = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
            cameraMake = tiffDict[kCGImagePropertyTIFFMake as String] as? String
            cameraModel = tiffDict[kCGImagePropertyTIFFModel as String] as? String
        }

        // Extract GPS data
        var latitude: Double?
        var longitude: Double?

        if let gpsDict = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any] {
            if let lat = gpsDict[kCGImagePropertyGPSLatitude as String] as? Double,
               let latRef = gpsDict[kCGImagePropertyGPSLatitudeRef as String] as? String {
                latitude = latRef == "S" ? -lat : lat
            }

            if let lon = gpsDict[kCGImagePropertyGPSLongitude as String] as? Double,
               let lonRef = gpsDict[kCGImagePropertyGPSLongitudeRef as String] as? String {
                longitude = lonRef == "W" ? -lon : lon
            }
        }

        // Create metadata object
        return PhotoMetadata(
            originalFilename: nil, // Will be set by importer
            fileSize: fileSize,
            dateTaken: dateTaken ?? Date(),
            width: width,
            height: height,
            tags: [],
            albums: [],
            isFavorite: false,
            cameraMake: cameraMake,
            cameraModel: cameraModel,
            latitude: latitude,
            longitude: longitude,
            iso: iso,
            focalLength: focalLength,
            aperture: aperture,
            shutterSpeed: shutterSpeed
        )
    }

    /// Parse EXIF date string format (yyyy:MM:dd HH:mm:ss)
    /// - Parameter dateString: EXIF formatted date string
    /// - Returns: Parsed Date object, or nil if parsing fails
    private static func parseEXIFDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        return formatter.date(from: dateString)
    }

    // MARK: - EXIF Formatting Helpers

    /// Formatted camera info string (e.g., "Apple iPhone 15 Pro")
    var cameraInfo: String? {
        if let make = cameraMake, let model = cameraModel {
            return "\(make) \(model)"
        } else if let model = cameraModel {
            return model
        } else if let make = cameraMake {
            return make
        }
        return nil
    }

    /// Formatted aperture string (e.g., "f/2.8")
    var formattedAperture: String? {
        guard let aperture = aperture else { return nil }
        return String(format: "f/%.1f", aperture)
    }

    /// Formatted shutter speed string (e.g., "1/250s" or "2.5s")
    var formattedShutterSpeed: String? {
        guard let shutterSpeed = shutterSpeed else { return nil }

        if shutterSpeed < 1 {
            // Display as fraction for fast shutter speeds
            let denominator = Int(1.0 / shutterSpeed)
            return "1/\(denominator)s"
        } else {
            // Display as decimal for slow shutter speeds
            return String(format: "%.1fs", shutterSpeed)
        }
    }

    /// Formatted ISO string (e.g., "ISO 400")
    var formattedISO: String? {
        guard let iso = iso else { return nil }
        return "ISO \(iso)"
    }

    /// Formatted focal length string (e.g., "24mm")
    var formattedFocalLength: String? {
        guard let focalLength = focalLength else { return nil }
        return String(format: "%.0fmm", focalLength)
    }

    /// Complete camera settings string (e.g., "f/2.8 • 1/250s • ISO 400 • 24mm")
    var cameraSettings: String? {
        let components = [
            formattedAperture,
            formattedShutterSpeed,
            formattedISO,
            formattedFocalLength
        ].compactMap { $0 }

        guard !components.isEmpty else { return nil }
        return components.joined(separator: " • ")
    }
}
