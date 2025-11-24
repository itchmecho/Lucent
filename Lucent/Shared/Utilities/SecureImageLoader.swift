//
//  SecureImageLoader.swift
//  Lucent
//
//  Created by Claude Code on 11/23/2024.
//

import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Actor for securely loading and managing images with automatic memory cleanup
actor SecureImageLoader {
    // MARK: - Singleton

    static let shared = SecureImageLoader()

    // MARK: - Properties

    private var loadedImages: [UUID: PlatformImage] = [:]
    private var loadingTasks: [UUID: Task<PlatformImage?, Never>] = [:]

    // MARK: - Error Types

    enum LoadError: Error, LocalizedError {
        case photoNotFound
        case decryptionFailed
        case invalidImageData
        case loadCancelled

        var errorDescription: String? {
            switch self {
            case .photoNotFound:
                return "Photo not found in storage"
            case .decryptionFailed:
                return "Failed to decrypt photo"
            case .invalidImageData:
                return "Invalid image data"
            case .loadCancelled:
                return "Image loading was cancelled"
            }
        }
    }

    // MARK: - Image Loading

    /// Loads a full-resolution image for a photo
    /// - Parameter photo: The encrypted photo to load
    /// - Returns: Platform image (UIImage or NSImage)
    func loadImage(for photo: EncryptedPhoto) async throws -> PlatformImage {
        // Check if already loaded
        if let cached = loadedImages[photo.id] {
            return cached
        }

        // Check if already loading
        if let existingTask = loadingTasks[photo.id] {
            if let image = await existingTask.value {
                return image
            }
            throw LoadError.loadCancelled
        }

        // Create new loading task
        let task = Task<PlatformImage?, Never> {
            do {
                // Load and decrypt photo data
                let photoData = try await SecurePhotoStorage.shared.retrievePhoto(id: photo.id)

                // Create platform image
                guard let image = PlatformImage.from(data: photoData) else {
                    return nil
                }

                // Cache the image
                cacheImage(image, for: photo.id)

                return image
            } catch {
                print("Failed to load image: \(error.localizedDescription)")
                return nil
            }
        }

        loadingTasks[photo.id] = task

        guard let image = await task.value else {
            loadingTasks.removeValue(forKey: photo.id)
            throw LoadError.invalidImageData
        }

        loadingTasks.removeValue(forKey: photo.id)
        return image
    }

    /// Loads a thumbnail for a photo
    /// - Parameter photo: The encrypted photo
    /// - Returns: Platform image thumbnail
    func loadThumbnail(for photo: EncryptedPhoto) async throws -> PlatformImage {
        guard let thumbnailURL = photo.thumbnailURL else {
            throw LoadError.photoNotFound
        }

        do {
            // Try to get from thumbnail cache first
            if let cachedData = await ThumbnailManager.shared.getCachedThumbnail(for: photo.id),
               let image = PlatformImage.from(data: cachedData) {
                return image
            }

            // Load and decrypt thumbnail
            let encryptedData = try Data(contentsOf: thumbnailURL)
            let decryptedData = try EncryptionManager.shared.decrypt(data: encryptedData)

            // Cache it
            await ThumbnailManager.shared.cacheThumbnail(decryptedData, for: photo.id)

            guard let image = PlatformImage.from(data: decryptedData) else {
                throw LoadError.invalidImageData
            }

            return image
        } catch {
            throw LoadError.decryptionFailed
        }
    }

    // MARK: - Cache Management

    /// Caches an image in memory
    private func cacheImage(_ image: PlatformImage, for photoId: UUID) {
        loadedImages[photoId] = image
    }

    /// Removes a specific image from cache
    func clearImage(for photoId: UUID) {
        loadedImages.removeValue(forKey: photoId)
    }

    /// Clears all images from memory (security)
    func clearAllImages() {
        loadedImages.removeAll()
    }

    /// Returns current cache statistics
    func getCacheStats() -> (count: Int, estimatedSizeBytes: Int) {
        let count = loadedImages.count
        var estimatedSize = 0

        #if canImport(UIKit)
        for (_, image) in loadedImages {
            if let cgImage = image.cgImage {
                let width = cgImage.width
                let height = cgImage.height
                let bytesPerPixel = 4 // RGBA
                estimatedSize += width * height * bytesPerPixel
            }
        }
        #elseif canImport(AppKit)
        for (_, image) in loadedImages {
            // Rough estimate for macOS
            let width = Int(image.size.width)
            let height = Int(image.size.height)
            let bytesPerPixel = 4 // RGBA
            estimatedSize += width * height * bytesPerPixel
        }
        #endif

        return (count: count, estimatedSizeBytes: estimatedSize)
    }

    /// Cancels an in-progress loading task
    func cancelLoading(for photoId: UUID) {
        loadingTasks[photoId]?.cancel()
        loadingTasks.removeValue(forKey: photoId)
    }
}

// MARK: - SwiftUI View Extension for Image Loading

extension View {
    /// Modifier to automatically clear images when view disappears (security)
    func clearImagesOnDisappear() -> some View {
        self.onDisappear {
            Task {
                await SecureImageLoader.shared.clearAllImages()
            }
        }
    }
}
