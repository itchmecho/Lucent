//
//  ShareManager.swift
//  Lucent
//
//  Created by Claude Code on 11/23/2024.
//

import Foundation
import SwiftUI
import OSLog

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Manages secure photo sharing with automatic cleanup
actor ShareManager {
    // MARK: - Singleton

    static let shared = ShareManager()

    // MARK: - Dependencies

    private let storage = SecurePhotoStorage.shared
    private let exportManager = ExportManager.shared
    private let logger = Logger(subsystem: "com.lucent.management", category: "share")

    // MARK: - Tracking

    /// Tracks active temporary files for cleanup
    private var activeTemporaryFiles: Set<URL> = []

    // MARK: - Error Types

    enum ShareError: Error, LocalizedError {
        case photoNotFound
        case exportFailed
        case shareCancelled
        case cleanupFailed

        var errorDescription: String? {
            switch self {
            case .photoNotFound:
                return "Photo not found"
            case .exportFailed:
                return "Failed to prepare photo for sharing"
            case .shareCancelled:
                return "Sharing was cancelled"
            case .cleanupFailed:
                return "Failed to clean up shared photo"
            }
        }
    }

    // MARK: - Share Result

    struct ShareResult {
        let tempFileURL: URL
        let photoId: UUID
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Share Operations

    /// Prepares a photo for sharing by exporting to temporary file
    /// - Parameter photoId: Photo identifier
    /// - Returns: ShareResult containing temporary file URL
    /// - Throws: ShareError if preparation fails
    func preparePhotoForSharing(photoId: UUID) async throws -> ShareResult {
        logger.info("Preparing photo for sharing: \(photoId.uuidString)")

        do {
            let tempFileURL = try await exportManager.exportToTemporaryFile(photoId: photoId)

            // Track the temporary file
            activeTemporaryFiles.insert(tempFileURL)

            logger.info("Photo prepared for sharing at: \(tempFileURL.path)")
            return ShareResult(tempFileURL: tempFileURL, photoId: photoId)

        } catch {
            logger.error("Failed to prepare photo for sharing: \(error.localizedDescription)")
            throw ShareError.exportFailed
        }
    }

    /// Prepares multiple photos for sharing
    /// - Parameter photoIds: Array of photo identifiers
    /// - Returns: Array of temporary file URLs
    /// - Throws: ShareError if preparation fails
    func preparePhotosForSharing(photoIds: [UUID]) async throws -> [ShareResult] {
        logger.info("Preparing \(photoIds.count) photos for sharing")

        var results: [ShareResult] = []

        for photoId in photoIds {
            do {
                let result = try await preparePhotoForSharing(photoId: photoId)
                results.append(result)
            } catch {
                // Clean up any already-prepared files
                await cleanupPreparedPhotos(results)
                throw error
            }
        }

        logger.info("Prepared \(results.count) photos for sharing")
        return results
    }

    /// Cleans up a shared photo's temporary file
    /// - Parameter shareResult: The share result to clean up
    func cleanupSharedPhoto(_ shareResult: ShareResult) async {
        logger.info("Cleaning up shared photo: \(shareResult.photoId.uuidString)")

        await exportManager.cleanupTemporaryFile(at: shareResult.tempFileURL)
        activeTemporaryFiles.remove(shareResult.tempFileURL)

        logger.info("Cleaned up shared photo")
    }

    /// Cleans up multiple shared photos
    /// - Parameter shareResults: Array of share results to clean up
    func cleanupPreparedPhotos(_ shareResults: [ShareResult]) async {
        logger.info("Cleaning up \(shareResults.count) prepared photos")

        for result in shareResults {
            await cleanupSharedPhoto(result)
        }
    }

    /// Cleans up all active temporary files (call on app termination)
    func cleanupAllTemporaryFiles() async {
        logger.info("Cleaning up all temporary files (\(self.activeTemporaryFiles.count) files)")

        for fileURL in activeTemporaryFiles {
            await exportManager.cleanupTemporaryFile(at: fileURL)
        }

        activeTemporaryFiles.removeAll()
        logger.info("All temporary files cleaned up")
    }

    // MARK: - Share Sheet Helpers

    #if os(iOS)
    /// Creates a UIActivityViewController for sharing photos
    /// - Parameter shareResults: Photos prepared for sharing
    /// - Returns: Configured UIActivityViewController
    @MainActor
    func createShareSheet(for shareResults: [ShareResult]) -> UIActivityViewController {
        let items = shareResults.map { $0.tempFileURL as Any }

        let activityVC = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )

        // Exclude activities that could leak the photo
        activityVC.excludedActivityTypes = [
            .addToReadingList,
            .assignToContact,
            .openInIBooks,
            .postToVimeo
        ]

        return activityVC
    }
    #endif

    // MARK: - Statistics

    /// Returns the number of active temporary files
    func getActiveTemporaryFileCount() -> Int {
        return activeTemporaryFiles.count
    }

    /// Lists all active temporary file URLs
    func getActiveTemporaryFiles() -> [URL] {
        return Array(activeTemporaryFiles)
    }
}

// MARK: - SwiftUI Integration

#if os(iOS)
/// SwiftUI wrapper for UIActivityViewController
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    let excludedActivityTypes: [UIActivity.ActivityType]?
    let onComplete: ((Bool) -> Void)?

    init(
        items: [Any],
        excludedActivityTypes: [UIActivity.ActivityType]? = nil,
        onComplete: ((Bool) -> Void)? = nil
    ) {
        self.items = items
        self.excludedActivityTypes = excludedActivityTypes
        self.onComplete = onComplete
    }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        controller.excludedActivityTypes = excludedActivityTypes
        controller.completionWithItemsHandler = { _, completed, _, _ in
            onComplete?(completed)
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}
#endif

// MARK: - Share Modifiers

extension View {
    /// Presents a share sheet with photos prepared by ShareManager
    /// - Parameters:
    ///   - isPresented: Binding to control presentation
    ///   - shareResults: Photos prepared for sharing
    ///   - onDismiss: Callback when share sheet is dismissed
    func shareSheet(
        isPresented: Binding<Bool>,
        shareResults: [ShareManager.ShareResult],
        onDismiss: @escaping () -> Void
    ) -> some View {
        #if os(iOS)
        sheet(isPresented: isPresented, onDismiss: onDismiss) {
            ShareSheet(
                items: shareResults.map { $0.tempFileURL as Any },
                excludedActivityTypes: [
                    .addToReadingList,
                    .assignToContact,
                    .openInIBooks,
                    .postToVimeo
                ],
                onComplete: { _ in
                    isPresented.wrappedValue = false
                }
            )
        }
        #else
        self
        #endif
    }

    /// Presents a share sheet for a single photo
    /// - Parameters:
    ///   - isPresented: Binding to control presentation
    ///   - shareResult: Photo prepared for sharing
    ///   - onDismiss: Callback when share sheet is dismissed
    func shareSheet(
        isPresented: Binding<Bool>,
        shareResult: ShareManager.ShareResult?,
        onDismiss: @escaping () -> Void
    ) -> some View {
        #if os(iOS)
        sheet(isPresented: isPresented, onDismiss: onDismiss) {
            if let result = shareResult {
                ShareSheet(
                    items: [result.tempFileURL as Any],
                    excludedActivityTypes: [
                        .addToReadingList,
                        .assignToContact,
                        .openInIBooks,
                        .postToVimeo
                    ],
                    onComplete: { _ in
                        isPresented.wrappedValue = false
                    }
                )
            }
        }
        #else
        self
        #endif
    }
}
