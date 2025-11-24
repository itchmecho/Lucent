//
//  ExportManager.swift
//  Lucent
//
//  Created by Claude Code on 11/23/2024.
//

import Foundation
import Photos
import OSLog

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Manages secure export of photos to the device photo library
actor ExportManager {
    // MARK: - Singleton

    static let shared = ExportManager()

    // MARK: - Dependencies

    private let storage = SecurePhotoStorage.shared
    private let logger = Logger(subsystem: "com.lucent.management", category: "export")

    // MARK: - Error Types

    enum ExportError: Error, LocalizedError {
        case photoNotFound
        case decryptionFailed
        case invalidImageData
        case permissionDenied
        case saveFailed(reason: String)
        case exportCancelled

        var errorDescription: String? {
            switch self {
            case .photoNotFound:
                return "Photo not found"
            case .decryptionFailed:
                return "Failed to decrypt photo for export"
            case .invalidImageData:
                return "Invalid image data - cannot export"
            case .permissionDenied:
                return "Permission to access photo library denied. Please enable in Settings."
            case .saveFailed(let reason):
                return "Failed to save photo to library: \(reason)"
            case .exportCancelled:
                return "Export was cancelled"
            }
        }
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Permission Management

    /// Checks if photo library access is authorized
    /// - Returns: True if authorized, false otherwise
    func checkPhotoLibraryPermission() -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        return status == .authorized
    }

    /// Requests photo library access permission
    /// - Returns: True if permission granted, false otherwise
    func requestPhotoLibraryPermission() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        return status == .authorized
    }

    // MARK: - Export Operations

    /// Exports a single photo to the device photo library
    /// - Parameter photoId: Photo identifier
    /// - Throws: ExportError if export fails
    func exportPhoto(id photoId: UUID) async throws {
        logger.info("Exporting photo: \(photoId.uuidString)")

        // Check permission
        if !checkPhotoLibraryPermission() {
            let granted = await requestPhotoLibraryPermission()
            guard granted else {
                logger.error("Photo library permission denied")
                throw ExportError.permissionDenied
            }
        }

        do {
            // Retrieve and decrypt photo data
            let decryptedData = try await storage.retrievePhoto(id: photoId)

            // Validate image data
            #if canImport(UIKit)
            guard UIImage(data: decryptedData) != nil else {
                logger.error("Invalid image data for photo: \(photoId.uuidString)")
                throw ExportError.invalidImageData
            }
            #else
            guard NSImage(data: decryptedData) != nil else {
                logger.error("Invalid image data for photo: \(photoId.uuidString)")
                throw ExportError.invalidImageData
            }
            #endif

            // Save to photo library
            try await saveToPhotoLibrary(imageData: decryptedData, photoId: photoId)

            // Clear decrypted data from memory
            var mutableData = decryptedData
            mutableData.secureWipe()

            logger.info("Successfully exported photo: \(photoId.uuidString)")
        } catch let error as ExportError {
            throw error
        } catch {
            logger.error("Failed to export photo: \(error.localizedDescription)")
            throw ExportError.saveFailed(reason: error.localizedDescription)
        }
    }

    /// Exports multiple photos to the photo library
    /// - Parameter photoIds: Array of photo identifiers
    /// - Returns: Dictionary mapping photo IDs to export results
    func exportPhotos(ids photoIds: [UUID]) async -> [UUID: Result<Void, Error>] {
        logger.info("Batch exporting \(photoIds.count) photos")

        // Check permission once for all exports
        if !checkPhotoLibraryPermission() {
            let granted = await requestPhotoLibraryPermission()
            if !granted {
                logger.error("Photo library permission denied")
                // Return failure for all photos
                return photoIds.reduce(into: [:]) { result, id in
                    result[id] = .failure(ExportError.permissionDenied)
                }
            }
        }

        var results: [UUID: Result<Void, Error>] = [:]

        for id in photoIds {
            do {
                try await exportPhoto(id: id)
                results[id] = .success(())
            } catch {
                results[id] = .failure(error)
            }
        }

        let successCount = results.values.filter {
            if case .success = $0 { return true }
            return false
        }.count

        logger.info("Batch export completed: \(successCount)/\(photoIds.count) successful")
        return results
    }

    /// Exports a photo to a temporary file for sharing
    /// - Parameter photoId: Photo identifier
    /// - Returns: URL to the temporary decrypted file
    /// - Throws: ExportError if export fails
    func exportToTemporaryFile(photoId: UUID) async throws -> URL {
        logger.info("Exporting photo to temporary file: \(photoId.uuidString)")

        do {
            // Retrieve and decrypt photo data
            let decryptedData = try await storage.retrievePhoto(id: photoId)

            // Validate image data
            #if canImport(UIKit)
            guard UIImage(data: decryptedData) != nil else {
                logger.error("Invalid image data for photo: \(photoId.uuidString)")
                throw ExportError.invalidImageData
            }
            #else
            guard NSImage(data: decryptedData) != nil else {
                logger.error("Invalid image data for photo: \(photoId.uuidString)")
                throw ExportError.invalidImageData
            }
            #endif

            // Get photo metadata for filename
            let photo = try await storage.getPhoto(id: photoId)
            let filename = photo.metadata.originalFilename ?? "photo_\(photoId.uuidString.prefix(8)).jpg"

            // Create temporary file
            let tempDirectory = FileManager.default.temporaryDirectory
            let tempFileURL = tempDirectory.appendingPathComponent(filename)

            // Write decrypted data to temp file
            try decryptedData.write(to: tempFileURL, options: .atomic)

            logger.info("Exported to temporary file: \(tempFileURL.path)")
            return tempFileURL

        } catch let error as ExportError {
            throw error
        } catch {
            logger.error("Failed to export to temporary file: \(error.localizedDescription)")
            throw ExportError.saveFailed(reason: error.localizedDescription)
        }
    }

    /// Cleans up a temporary export file
    /// - Parameter url: URL of the temporary file to delete
    func cleanupTemporaryFile(at url: URL) async {
        logger.info("Cleaning up temporary file: \(url.path)")

        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: url.path) {
            do {
                // Use secure deletion for temporary files
                try await SecureDeletion.delete(fileAt: url)
                logger.info("Successfully cleaned up temporary file")
            } catch {
                logger.error("Failed to clean up temporary file: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Private Methods

    /// Saves image data to the photo library
    /// - Parameters:
    ///   - imageData: Decrypted image data
    ///   - photoId: Photo identifier (for logging)
    private func saveToPhotoLibrary(imageData: Data, photoId: UUID) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.shared().performChanges({
                let creationRequest = PHAssetCreationRequest.forAsset()
                creationRequest.addResource(with: .photo, data: imageData, options: nil)
            }) { success, error in
                if success {
                    continuation.resume()
                } else if let error = error {
                    continuation.resume(throwing: ExportError.saveFailed(reason: error.localizedDescription))
                } else {
                    continuation.resume(throwing: ExportError.saveFailed(reason: "Unknown error"))
                }
            }
        }
    }
}
