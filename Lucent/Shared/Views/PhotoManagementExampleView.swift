//
//  PhotoManagementExampleView.swift
//  Lucent
//
//  Created by Claude Code on 11/23/2024.
//
//  Example view demonstrating how to integrate the photo management features

import SwiftUI

/// Example view showing how to integrate photo management features
struct PhotoManagementExampleView: View {
    // MARK: - State

    @StateObject private var multiSelectViewModel = MultiSelectViewModel()
    @State private var photos: [EncryptedPhoto] = []

    // Action sheets and dialogs
    @State private var showPhotoActions = false
    @State private var showBatchActions = false
    @State private var showDeleteConfirmation = false
    @State private var showExportConfirmation = false
    @State private var showMoveToAlbum = false
    @State private var showAddTags = false
    @State private var showShareSheet = false

    // Operation state
    @State private var selectedPhoto: EncryptedPhoto?
    @State private var shareResults: [ShareManager.ShareResult]?
    @State private var availableAlbums: [String] = ["Vacation", "Family", "Work"]
    @State private var availableTags: [String] = ["Nature", "Portrait", "Landscape"]

    // MARK: - Body

    var body: some View {
        NavigationView {
            Group {
                if photos.isEmpty {
                    emptyState
                } else {
                    photoGrid
                }
            }
            .navigationTitle("Photo Vault")
            .toolbar {
                toolbarContent
            }
            .sheet(isPresented: $showPhotoActions) {
                if let photo = selectedPhoto {
                    PhotoActionsView(photo: photo, onAction: handlePhotoAction)
                }
            }
            .sheet(isPresented: $showBatchActions) {
                BatchActionsView(
                    selectedCount: multiSelectViewModel.selectedCount,
                    onAction: handleBatchAction
                )
            }
            .sheet(isPresented: $showMoveToAlbum) {
                MoveToAlbumSheet(
                    availableAlbums: availableAlbums,
                    photoCount: multiSelectViewModel.hasSelection ?
                        multiSelectViewModel.selectedCount : 1,
                    onMove: handleMoveToAlbum
                )
            }
            .sheet(isPresented: $showAddTags) {
                AddTagsSheet(
                    availableTags: availableTags,
                    photoCount: multiSelectViewModel.hasSelection ?
                        multiSelectViewModel.selectedCount : 1,
                    onAddTags: handleAddTags
                )
            }
            .deletePhotoConfirmation(
                isPresented: $showDeleteConfirmation,
                photoCount: multiSelectViewModel.hasSelection ?
                    multiSelectViewModel.selectedCount : 1,
                onConfirm: handleDelete
            )
            .exportPhotoConfirmation(
                isPresented: $showExportConfirmation,
                photoCount: multiSelectViewModel.hasSelection ?
                    multiSelectViewModel.selectedCount : 1,
                onConfirm: handleExport
            )
            .shareSheet(
                isPresented: $showShareSheet,
                shareResults: shareResults ?? [],
                onDismiss: cleanupShareResults
            )
            .operationErrorAlert(
                isPresented: .constant(multiSelectViewModel.errorMessage != nil),
                error: multiSelectViewModel.errorMessage
            )
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("No Photos")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Add photos to your secure vault")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private var photoGrid: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 100), spacing: 2)
            ], spacing: 2) {
                ForEach(photos) { photo in
                    photoCell(photo)
                }
            }
        }
    }

    private func photoCell(_ photo: EncryptedPhoto) -> some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                // Selection indicator
                if multiSelectViewModel.isSelected(photo.id) {
                    Color.blue.opacity(0.3)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.white)
                }
            }
            .photoContextMenu(photo: photo, onAction: { action in
                selectedPhoto = photo
                handlePhotoAction(action)
            })
            .onTapGesture {
                if multiSelectViewModel.isMultiSelectMode {
                    multiSelectViewModel.toggleSelection(for: photo.id)
                } else {
                    // Open photo viewer
                }
            }
            .onLongPressGesture {
                if !multiSelectViewModel.isMultiSelectMode {
                    multiSelectViewModel.enterMultiSelectMode(selecting: photo.id)
                }
            }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // Leading - Multi-select mode
        ToolbarItem(placement: .automatic) {
            if multiSelectViewModel.isMultiSelectMode {
                Button("Cancel") {
                    multiSelectViewModel.exitMultiSelectMode()
                }
            }
        }

        // Trailing - Actions
        ToolbarItem(placement: .automatic) {
            if multiSelectViewModel.isMultiSelectMode {
                Button("Actions") {
                    showBatchActions = true
                }
                .disabled(!multiSelectViewModel.hasSelection)
            } else {
                Menu {
                    Button(action: {
                        multiSelectViewModel.toggleMultiSelectMode()
                    }) {
                        Label("Select Photos", systemImage: "checkmark.circle")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }

        // Bottom - Selection count
        if multiSelectViewModel.isMultiSelectMode {
            ToolbarItem(placement: .automatic) {
                Text("\(multiSelectViewModel.selectedCount) selected")
                    .font(.headline)
            }
        }
    }

    // MARK: - Action Handlers

    private func handlePhotoAction(_ action: PhotoActionsView.PhotoAction) {
        guard let photo = selectedPhoto else { return }

        Task {
            switch action {
            case .favorite:
                await toggleFavorite(photo)
            case .addToAlbum:
                showMoveToAlbum = true
            case .addTags:
                showAddTags = true
            case .share:
                await prepareShare(photo)
            case .export:
                showExportConfirmation = true
            case .delete:
                showDeleteConfirmation = true
            }
        }
    }

    private func handleBatchAction(_ action: BatchActionsView.BatchAction) {
        Task {
            switch action {
            case .addToFavorites:
                await multiSelectViewModel.setSelectedFavorites(true)
            case .removeFromFavorites:
                await multiSelectViewModel.setSelectedFavorites(false)
            case .moveToAlbum:
                showMoveToAlbum = true
            case .addTags:
                showAddTags = true
            case .share:
                await prepareBatchShare()
            case .export:
                showExportConfirmation = true
            case .delete:
                showDeleteConfirmation = true
            }
        }
    }

    private func handleMoveToAlbum(_ albumName: String) {
        Task {
            if multiSelectViewModel.hasSelection {
                await multiSelectViewModel.moveSelectedToAlbum(albumName)
            } else if let photo = selectedPhoto {
                do {
                    try await PhotoManagementManager.shared.moveToAlbum(
                        photoId: photo.id,
                        albumName: albumName
                    )
                } catch {
                    multiSelectViewModel.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func handleAddTags(_ tags: [String]) {
        Task {
            if multiSelectViewModel.hasSelection {
                await multiSelectViewModel.addTagsToSelected(tags)
            } else if let photo = selectedPhoto {
                do {
                    for tag in tags {
                        try await PhotoManagementManager.shared.addTag(
                            to: photo.id,
                            tag: tag
                        )
                    }
                } catch {
                    multiSelectViewModel.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func handleDelete() {
        Task {
            if multiSelectViewModel.hasSelection {
                await multiSelectViewModel.deleteSelected()
            } else if let photo = selectedPhoto {
                do {
                    try await PhotoManagementManager.shared.deletePhoto(id: photo.id)
                    // Refresh photo list
                } catch {
                    multiSelectViewModel.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func handleExport() {
        Task {
            if multiSelectViewModel.hasSelection {
                await multiSelectViewModel.exportSelected()
            } else if let photo = selectedPhoto {
                do {
                    try await ExportManager.shared.exportPhoto(id: photo.id)
                } catch {
                    multiSelectViewModel.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func toggleFavorite(_ photo: EncryptedPhoto) async {
        do {
            _ = try await PhotoManagementManager.shared.toggleFavorite(photoId: photo.id)
            // Refresh photo
        } catch {
            multiSelectViewModel.errorMessage = error.localizedDescription
        }
    }

    private func prepareShare(_ photo: EncryptedPhoto) async {
        do {
            let result = try await ShareManager.shared.preparePhotoForSharing(photoId: photo.id)
            shareResults = [result]
            showShareSheet = true
        } catch {
            multiSelectViewModel.errorMessage = error.localizedDescription
        }
    }

    private func prepareBatchShare() async {
        if let results = await multiSelectViewModel.prepareSelectedForSharing() {
            shareResults = results
            showShareSheet = true
        }
    }

    private func cleanupShareResults() {
        Task {
            if let results = shareResults {
                await ShareManager.shared.cleanupPreparedPhotos(results)
            }
            shareResults = nil
        }
    }
}

// MARK: - Preview

#Preview {
    PhotoManagementExampleView()
}
