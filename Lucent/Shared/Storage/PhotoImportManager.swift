//
//  PhotoImportManager.swift
//  Lucent
//
//  Created by Claude Code on 11/23/2024.
//

import Foundation
import PhotosUI
import OSLog

#if canImport(UIKit)
import UIKit
#else
import AppKit
typealias UIImage = NSImage
#endif

/// Manages photo import operations including batch imports and progress tracking
@MainActor
class PhotoImportManager: ObservableObject {
    // MARK: - Published Properties

    /// Current import progress (0.0 to 1.0)
    @Published var importProgress: Double = 0

    /// Current import status message
    @Published var statusMessage: String = ""

    /// Whether an import is currently in progress
    @Published var isImporting: Bool = false

    /// Number of photos successfully imported
    @Published var successCount: Int = 0

    /// Number of photos that failed to import
    @Published var failureCount: Int = 0

    /// Current error if any
    @Published var currentError: ImportError?

    // MARK: - Private Properties

    private let storage = SecurePhotoStorage.shared
    private let logger = Logger(subsystem: "com.lucent.import", category: "PhotoImport")

    // MARK: - Error Types

    enum ImportError: LocalizedError {
        case noPhotosSelected
        case photoLoadFailed(String)
        case importCancelled
        case storageError(Error)
        case unsupportedFormat
        case permissionDenied

        var errorDescription: String? {
            switch self {
            case .noPhotosSelected:
                return "No photos were selected for import"
            case .photoLoadFailed(let reason):
                return "Failed to load photo: \(reason)"
            case .importCancelled:
                return "Import was cancelled"
            case .storageError(let error):
                return "Storage error: \(error.localizedDescription)"
            case .unsupportedFormat:
                return "Unsupported photo format"
            case .permissionDenied:
                return "Photo library permission denied"
            }
        }
    }

    // MARK: - Import State

    struct ImportResult {
        let successCount: Int
        let failureCount: Int
        let totalCount: Int
        let importedPhotos: [EncryptedPhoto]

        var hasFailures: Bool {
            failureCount > 0
        }

        var successRate: Double {
            guard totalCount > 0 else { return 0 }
            return Double(successCount) / Double(totalCount)
        }
    }

    // MARK: - Public Methods

    /// Imports photos from PHPicker results
    /// - Parameter results: Array of PHPickerResult objects
    /// - Returns: ImportResult with statistics
    func importPhotos(from results: [PHPickerResult]) async throws -> ImportResult {
        guard !results.isEmpty else {
            throw ImportError.noPhotosSelected
        }

        logger.info("Starting import of \(results.count) photos")

        // Reset state
        await MainActor.run {
            isImporting = true
            importProgress = 0
            successCount = 0
            failureCount = 0
            statusMessage = "Preparing to import \(results.count) photos..."
        }

        var importedPhotos: [EncryptedPhoto] = []
        let totalCount = results.count

        // Initialize storage
        try await storage.initializeStorage()

        // Import each photo
        for (index, result) in results.enumerated() {
            let photoNumber = index + 1

            await MainActor.run {
                statusMessage = "Importing photo \(photoNumber) of \(totalCount)..."
                importProgress = Double(index) / Double(totalCount)
            }

            do {
                // Load photo data
                let (imageData, metadata) = try await loadPhoto(from: result)

                // Save to secure storage (encryption happens here)
                let encryptedPhoto = try await storage.savePhoto(data: imageData, metadata: metadata)
                importedPhotos.append(encryptedPhoto)

                await MainActor.run {
                    successCount += 1
                }

                logger.info("Successfully imported photo \(photoNumber): \(encryptedPhoto.id)")

            } catch {
                await MainActor.run {
                    failureCount += 1
                }
                logger.error("Failed to import photo \(photoNumber): \(error.localizedDescription)")
            }
        }

        // Finalize
        await MainActor.run {
            importProgress = 1.0
            statusMessage = "Import complete: \(successCount) succeeded, \(failureCount) failed"
            isImporting = false
        }

        logger.info("Import complete - Success: \(self.successCount), Failed: \(self.failureCount)")

        return ImportResult(
            successCount: successCount,
            failureCount: failureCount,
            totalCount: totalCount,
            importedPhotos: importedPhotos
        )
    }

    /// Imports a single photo from camera or direct source
    /// - Parameters:
    ///   - imageData: Raw image data
    ///   - filename: Optional filename for the photo
    /// - Returns: Imported encrypted photo
    func importSinglePhoto(imageData: Data, filename: String? = nil) async throws -> EncryptedPhoto {
        logger.info("Importing single photo")

        await MainActor.run {
            isImporting = true
            importProgress = 0
            statusMessage = "Importing photo..."
        }

        do {
            // Initialize storage
            try await storage.initializeStorage()

            await MainActor.run {
                importProgress = 0.3
                statusMessage = "Extracting metadata..."
            }

            // Extract metadata from image
            var metadata = PhotoMetadata.extract(from: imageData) ?? PhotoMetadata(fileSize: imageData.count)
            metadata.originalFilename = filename

            await MainActor.run {
                importProgress = 0.6
                statusMessage = "Encrypting photo..."
            }

            // Save to secure storage (encryption happens here)
            let encryptedPhoto = try await storage.savePhoto(data: imageData, metadata: metadata)

            await MainActor.run {
                importProgress = 1.0
                statusMessage = "Import complete"
                successCount = 1
                isImporting = false
            }

            logger.info("Successfully imported single photo: \(encryptedPhoto.id)")

            return encryptedPhoto

        } catch {
            await MainActor.run {
                failureCount = 1
                isImporting = false
                currentError = .storageError(error)
            }
            logger.error("Failed to import single photo: \(error.localizedDescription)")
            throw ImportError.storageError(error)
        }
    }

    /// Resets the import state
    func resetState() {
        isImporting = false
        importProgress = 0
        statusMessage = ""
        successCount = 0
        failureCount = 0
        currentError = nil
    }

    // MARK: - Private Methods

    /// Loads photo data and metadata from PHPickerResult
    /// - Parameter result: PHPickerResult from photo picker
    /// - Returns: Tuple of image data and metadata
    private func loadPhoto(from result: PHPickerResult) async throws -> (Data, PhotoMetadata) {
        let itemProvider = result.itemProvider

        // Check if it's an image
        guard itemProvider.canLoadObject(ofClass: UIImage.self) else {
            throw ImportError.unsupportedFormat
        }

        // Load image data
        let imageData = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            // Try to load as JPEG first
            if itemProvider.hasItemConformingToTypeIdentifier(UTType.jpeg.identifier) {
                itemProvider.loadDataRepresentation(forTypeIdentifier: UTType.jpeg.identifier) { data, error in
                    if let error = error {
                        continuation.resume(throwing: ImportError.photoLoadFailed(error.localizedDescription))
                        return
                    }
                    guard let data = data else {
                        continuation.resume(throwing: ImportError.photoLoadFailed("No data available"))
                        return
                    }
                    continuation.resume(returning: data)
                }
            }
            // Try PNG
            else if itemProvider.hasItemConformingToTypeIdentifier(UTType.png.identifier) {
                itemProvider.loadDataRepresentation(forTypeIdentifier: UTType.png.identifier) { data, error in
                    if let error = error {
                        continuation.resume(throwing: ImportError.photoLoadFailed(error.localizedDescription))
                        return
                    }
                    guard let data = data else {
                        continuation.resume(throwing: ImportError.photoLoadFailed("No data available"))
                        return
                    }
                    continuation.resume(returning: data)
                }
            }
            // Try HEIC
            else if itemProvider.hasItemConformingToTypeIdentifier(UTType.heic.identifier) {
                itemProvider.loadDataRepresentation(forTypeIdentifier: UTType.heic.identifier) { data, error in
                    if let error = error {
                        continuation.resume(throwing: ImportError.photoLoadFailed(error.localizedDescription))
                        return
                    }
                    guard let data = data else {
                        continuation.resume(throwing: ImportError.photoLoadFailed("No data available"))
                        return
                    }
                    continuation.resume(returning: data)
                }
            }
            // Fallback: load as UIImage and convert to JPEG
            else {
                itemProvider.loadObject(ofClass: UIImage.self) { object, error in
                    if let error = error {
                        continuation.resume(throwing: ImportError.photoLoadFailed(error.localizedDescription))
                        return
                    }
                    guard let image = object as? UIImage else {
                        continuation.resume(throwing: ImportError.photoLoadFailed("Invalid image object"))
                        return
                    }
                    #if canImport(UIKit)
                    guard let jpegData = image.jpegData(compressionQuality: 0.9) else {
                        continuation.resume(throwing: ImportError.photoLoadFailed("Failed to convert to JPEG"))
                        return
                    }
                    #else
                    // macOS: Convert NSImage to JPEG data
                    guard let tiffData = image.tiffRepresentation,
                          let bitmapRep = NSBitmapImageRep(data: tiffData),
                          let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.9]) else {
                        continuation.resume(throwing: ImportError.photoLoadFailed("Failed to convert to JPEG"))
                        return
                    }
                    #endif
                    continuation.resume(returning: jpegData)
                }
            }
        }

        // Extract metadata
        let metadata = PhotoMetadata.extract(from: imageData) ?? PhotoMetadata(fileSize: imageData.count)

        return (imageData, metadata)
    }
}

// MARK: - Photo Library Permission Helper

extension PhotoImportManager {
    /// Checks if photo library access is authorized
    static func checkPhotoLibraryPermission() -> PHAuthorizationStatus {
        return PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    /// Requests photo library access
    static func requestPhotoLibraryPermission() async -> PHAuthorizationStatus {
        return await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }
}
