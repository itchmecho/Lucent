//
//  MultiSelectViewModel.swift
//  Lucent
//
//  Created by Claude Code on 11/23/2024.
//

import Foundation
import SwiftUI
import OSLog

/// Manages multi-select state for photo operations
@MainActor
class MultiSelectViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Whether multi-select mode is active
    @Published var isMultiSelectMode: Bool = false

    /// Set of currently selected photo IDs
    @Published var selectedPhotoIds: Set<UUID> = []

    /// Whether an operation is in progress
    @Published var isOperationInProgress: Bool = false

    /// Error message to display
    @Published var errorMessage: String?

    /// Success message to display
    @Published var successMessage: String?

    // MARK: - Dependencies

    private let managementManager = PhotoManagementManager.shared
    private let exportManager = ExportManager.shared
    private let shareManager = ShareManager.shared
    private let logger = Logger(subsystem: "com.lucent.viewmodel", category: "multi-select")

    // MARK: - Computed Properties

    /// Number of photos currently selected
    var selectedCount: Int {
        selectedPhotoIds.count
    }

    /// Whether any photos are selected
    var hasSelection: Bool {
        !selectedPhotoIds.isEmpty
    }

    /// Whether all given photos are selected
    func areAllSelected(in photos: [EncryptedPhoto]) -> Bool {
        guard !photos.isEmpty else { return false }
        let photoIds = Set(photos.map { $0.id })
        return photoIds.isSubset(of: selectedPhotoIds)
    }

    // MARK: - Selection Management

    /// Toggles selection for a photo
    /// - Parameter photoId: Photo identifier
    func toggleSelection(for photoId: UUID) {
        if selectedPhotoIds.contains(photoId) {
            selectedPhotoIds.remove(photoId)
        } else {
            selectedPhotoIds.insert(photoId)
        }
        logger.debug("Toggled selection for \(photoId.uuidString). Selected: \(self.selectedCount)")
    }

    /// Checks if a photo is selected
    /// - Parameter photoId: Photo identifier
    /// - Returns: True if selected
    func isSelected(_ photoId: UUID) -> Bool {
        selectedPhotoIds.contains(photoId)
    }

    /// Selects all photos in a list
    /// - Parameter photos: Array of photos to select
    func selectAll(_ photos: [EncryptedPhoto]) {
        selectedPhotoIds = Set(photos.map { $0.id })
        logger.info("Selected all \(self.selectedCount) photos")
    }

    /// Deselects all photos
    func deselectAll() {
        let count = selectedCount
        selectedPhotoIds.removeAll()
        logger.info("Deselected all photos (was \(count))")
    }

    /// Toggles multi-select mode on/off
    func toggleMultiSelectMode() {
        isMultiSelectMode.toggle()

        if !isMultiSelectMode {
            // Exit multi-select mode, clear selections
            deselectAll()
        }

        logger.info("Multi-select mode: \(self.isMultiSelectMode)")
    }

    /// Enters multi-select mode and selects a photo
    /// - Parameter photoId: Initial photo to select
    func enterMultiSelectMode(selecting photoId: UUID) {
        isMultiSelectMode = true
        selectedPhotoIds.insert(photoId)
        logger.info("Entered multi-select mode with photo: \(photoId.uuidString)")
    }

    /// Exits multi-select mode
    func exitMultiSelectMode() {
        isMultiSelectMode = false
        deselectAll()
        logger.info("Exited multi-select mode")
    }

    // MARK: - Batch Operations

    /// Deletes all selected photos
    /// - Returns: Number of photos successfully deleted
    @discardableResult
    func deleteSelected() async -> Int {
        guard hasSelection else { return 0 }

        let photoIds = Array(selectedPhotoIds)
        logger.info("Deleting \(photoIds.count) selected photos")

        isOperationInProgress = true
        errorMessage = nil
        successMessage = nil

        let results = await managementManager.deletePhotos(ids: photoIds)

        let successCount = results.values.filter {
            if case .success = $0 { return true }
            return false
        }.count

        isOperationInProgress = false

        if successCount == photoIds.count {
            successMessage = "Deleted \(successCount) photo\(successCount == 1 ? "" : "s")"
            exitMultiSelectMode()
        } else {
            let failCount = photoIds.count - successCount
            errorMessage = "Deleted \(successCount) photo\(successCount == 1 ? "" : "s"), \(failCount) failed"
        }

        logger.info("Batch delete completed: \(successCount)/\(photoIds.count) successful")
        return successCount
    }

    /// Moves all selected photos to an album
    /// - Parameter albumName: Target album name
    /// - Returns: Number of photos successfully moved
    @discardableResult
    func moveSelectedToAlbum(_ albumName: String) async -> Int {
        guard hasSelection else { return 0 }

        let photoIds = Array(selectedPhotoIds)
        logger.info("Moving \(photoIds.count) selected photos to album: \(albumName)")

        isOperationInProgress = true
        errorMessage = nil
        successMessage = nil

        let results = await managementManager.movePhotosToAlbum(photoIds: photoIds, albumName: albumName)

        let successCount = results.values.filter {
            if case .success = $0 { return true }
            return false
        }.count

        isOperationInProgress = false

        if successCount == photoIds.count {
            successMessage = "Moved \(successCount) photo\(successCount == 1 ? "" : "s") to \(albumName)"
            exitMultiSelectMode()
        } else {
            let failCount = photoIds.count - successCount
            errorMessage = "Moved \(successCount) photo\(successCount == 1 ? "" : "s"), \(failCount) failed"
        }

        logger.info("Batch move completed: \(successCount)/\(photoIds.count) successful")
        return successCount
    }

    /// Exports all selected photos to the photo library
    /// - Returns: Number of photos successfully exported
    @discardableResult
    func exportSelected() async -> Int {
        guard hasSelection else { return 0 }

        let photoIds = Array(selectedPhotoIds)
        logger.info("Exporting \(photoIds.count) selected photos")

        isOperationInProgress = true
        errorMessage = nil
        successMessage = nil

        let results = await exportManager.exportPhotos(ids: photoIds)

        let successCount = results.values.filter {
            if case .success = $0 { return true }
            return false
        }.count

        isOperationInProgress = false

        if successCount == photoIds.count {
            successMessage = "Exported \(successCount) photo\(successCount == 1 ? "" : "s") to photo library"
            exitMultiSelectMode()
        } else {
            let failCount = photoIds.count - successCount
            errorMessage = "Exported \(successCount) photo\(successCount == 1 ? "" : "s"), \(failCount) failed"
        }

        logger.info("Batch export completed: \(successCount)/\(photoIds.count) successful")
        return successCount
    }

    /// Marks all selected photos as favorite/unfavorite
    /// - Parameter isFavorite: Whether to mark as favorite
    /// - Returns: Number of photos successfully updated
    @discardableResult
    func setSelectedFavorites(_ isFavorite: Bool) async -> Int {
        guard hasSelection else { return 0 }

        let photoIds = Array(selectedPhotoIds)
        logger.info("Setting favorite=\(isFavorite) for \(photoIds.count) selected photos")

        isOperationInProgress = true
        errorMessage = nil
        successMessage = nil

        let results = await managementManager.setFavorites(photoIds: photoIds, isFavorite: isFavorite)

        let successCount = results.values.filter {
            if case .success = $0 { return true }
            return false
        }.count

        isOperationInProgress = false

        let action = isFavorite ? "added to favorites" : "removed from favorites"
        if successCount == photoIds.count {
            successMessage = "\(successCount) photo\(successCount == 1 ? "" : "s") \(action)"
            exitMultiSelectMode()
        } else {
            let failCount = photoIds.count - successCount
            errorMessage = "\(successCount) photo\(successCount == 1 ? "" : "s") \(action), \(failCount) failed"
        }

        logger.info("Batch favorite update completed: \(successCount)/\(photoIds.count) successful")
        return successCount
    }

    /// Adds tags to all selected photos
    /// - Parameter tags: Tags to add
    /// - Returns: Number of photos successfully updated
    @discardableResult
    func addTagsToSelected(_ tags: [String]) async -> Int {
        guard hasSelection else { return 0 }

        let photoIds = Array(selectedPhotoIds)
        logger.info("Adding \(tags.count) tags to \(photoIds.count) selected photos")

        isOperationInProgress = true
        errorMessage = nil
        successMessage = nil

        let results = await managementManager.addTagsToPhotos(photoIds: photoIds, tags: tags)

        let successCount = results.values.filter {
            if case .success = $0 { return true }
            return false
        }.count

        isOperationInProgress = false

        if successCount == photoIds.count {
            successMessage = "Added tags to \(successCount) photo\(successCount == 1 ? "" : "s")"
            exitMultiSelectMode()
        } else {
            let failCount = photoIds.count - successCount
            errorMessage = "Added tags to \(successCount) photo\(successCount == 1 ? "" : "s"), \(failCount) failed"
        }

        logger.info("Batch tag addition completed: \(successCount)/\(photoIds.count) successful")
        return successCount
    }

    /// Prepares selected photos for sharing
    /// - Returns: Array of share results, or nil if operation fails
    func prepareSelectedForSharing() async -> [ShareManager.ShareResult]? {
        guard hasSelection else { return nil }

        let photoIds = Array(selectedPhotoIds)
        logger.info("Preparing \(photoIds.count) selected photos for sharing")

        isOperationInProgress = true
        errorMessage = nil

        do {
            let results = try await shareManager.preparePhotosForSharing(photoIds: photoIds)
            isOperationInProgress = false
            logger.info("Prepared \(results.count) photos for sharing")
            return results
        } catch {
            isOperationInProgress = false
            errorMessage = "Failed to prepare photos for sharing: \(error.localizedDescription)"
            logger.error("Failed to prepare photos for sharing: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Message Management

    /// Clears any displayed messages
    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }
}
