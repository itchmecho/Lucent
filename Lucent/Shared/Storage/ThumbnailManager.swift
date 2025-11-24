//
//  ThumbnailManager.swift
//  Lucent
//
//  Created by Claude Code on 11/23/2024.
//

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Manages thumbnail generation and caching for photos
actor ThumbnailManager {
    // MARK: - Constants

    /// Default maximum thumbnail size
    static let defaultMaxSize = CGSize(width: 300, height: 300)

    /// Maximum cache size in bytes (50 MB)
    private static let maxCacheSize = 50 * 1024 * 1024

    // MARK: - Cache Entry

    private struct CacheEntry {
        let data: Data
        var accessTime: Date
        var accessCount: Int

        var size: Int {
            data.count
        }
    }

    // MARK: - Properties

    /// In-memory LRU cache
    private var cache: [UUID: CacheEntry] = [:]

    /// Current cache size in bytes
    private var currentCacheSize = 0

    // MARK: - Error Types

    enum ThumbnailError: Error, LocalizedError {
        case invalidImageData
        case thumbnailGenerationFailed
        case encodingFailed

        var errorDescription: String? {
            switch self {
            case .invalidImageData:
                return "Invalid image data provided"
            case .thumbnailGenerationFailed:
                return "Failed to generate thumbnail"
            case .encodingFailed:
                return "Failed to encode thumbnail"
            }
        }
    }

    // MARK: - Public Methods

    /// Generates a thumbnail from image data
    /// - Parameters:
    ///   - imageData: Original image data
    ///   - maxSize: Maximum size for the thumbnail (default: 300x300)
    /// - Returns: Thumbnail image data (JPEG format)
    /// - Throws: `ThumbnailError` if generation fails
    func generateThumbnail(from imageData: Data, maxSize: CGSize = defaultMaxSize) async throws -> Data {
        guard let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil) else {
            throw ThumbnailError.invalidImageData
        }

        // Create thumbnail options
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(maxSize.width, maxSize.height)
        ]

        // Generate thumbnail
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
            throw ThumbnailError.thumbnailGenerationFailed
        }

        // Encode as JPEG
        guard let thumbnailData = encodeThumbnail(thumbnail) else {
            throw ThumbnailError.encodingFailed
        }

        return thumbnailData
    }

    /// Retrieves a cached thumbnail or generates a new one
    /// - Parameters:
    ///   - photoId: Photo identifier
    ///   - imageData: Original image data (used if not cached)
    ///   - maxSize: Maximum thumbnail size
    /// - Returns: Thumbnail data
    func getThumbnail(for photoId: UUID, from imageData: Data, maxSize: CGSize = defaultMaxSize) async throws -> Data {
        // Check cache first
        if let cached = getCachedThumbnail(for: photoId) {
            return cached
        }

        // Generate new thumbnail
        let thumbnailData = try await generateThumbnail(from: imageData, maxSize: maxSize)

        // Cache it
        cacheThumbnail(thumbnailData, for: photoId)

        return thumbnailData
    }

    /// Caches thumbnail data
    /// - Parameters:
    ///   - thumbnailData: Thumbnail data to cache
    ///   - photoId: Photo identifier
    func cacheThumbnail(_ thumbnailData: Data, for photoId: UUID) {
        let entry = CacheEntry(
            data: thumbnailData,
            accessTime: Date(),
            accessCount: 1
        )

        // Add to cache
        cache[photoId] = entry
        currentCacheSize += entry.size

        // Evict if necessary
        evictIfNeeded()
    }

    /// Retrieves a thumbnail from cache
    /// - Parameter photoId: Photo identifier
    /// - Returns: Cached thumbnail data if available
    func getCachedThumbnail(for photoId: UUID) -> Data? {
        guard var entry = cache[photoId] else {
            return nil
        }

        // Update access time and count (LRU)
        entry.accessTime = Date()
        entry.accessCount += 1
        cache[photoId] = entry

        return entry.data
    }

    /// Removes a thumbnail from cache
    /// - Parameter photoId: Photo identifier
    func removeCachedThumbnail(for photoId: UUID) {
        if let entry = cache.removeValue(forKey: photoId) {
            currentCacheSize -= entry.size
        }
    }

    /// Clears the entire thumbnail cache
    func clearCache() {
        cache.removeAll()
        currentCacheSize = 0
    }

    /// Returns current cache statistics
    func getCacheStats() -> (count: Int, sizeBytes: Int, maxSizeBytes: Int) {
        (count: cache.count, sizeBytes: currentCacheSize, maxSizeBytes: Self.maxCacheSize)
    }

    // MARK: - Private Methods

    /// Encodes a CGImage as JPEG data
    /// - Parameter image: CGImage to encode
    /// - Returns: JPEG data
    private func encodeThumbnail(_ image: CGImage) -> Data? {
        let data = NSMutableData()

        guard let destination = CGImageDestinationCreateWithData(data as CFMutableData, UTType.jpeg.identifier as CFString, 1, nil) else {
            return nil
        }

        // JPEG compression quality (0.8 = 80%)
        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: 0.8
        ]

        CGImageDestinationAddImage(destination, image, options as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            return nil
        }

        return data as Data
    }

    /// Evicts least recently used items if cache exceeds size limit
    private func evictIfNeeded() {
        while currentCacheSize > Self.maxCacheSize && !cache.isEmpty {
            // Find least recently used entry
            let lruKey = cache.min { a, b in
                // Primary: access time (older first)
                // Secondary: access count (less frequently used first)
                if a.value.accessTime != b.value.accessTime {
                    return a.value.accessTime < b.value.accessTime
                }
                return a.value.accessCount < b.value.accessCount
            }?.key

            if let key = lruKey {
                removeCachedThumbnail(for: key)
            }
        }
    }
}

// MARK: - Convenience Extensions

extension ThumbnailManager {
    /// Shared instance for convenience
    static let shared = ThumbnailManager()
}
