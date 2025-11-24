//
//  ConfirmationDialogs.swift
//  Lucent
//
//  Created by Claude Code on 11/23/2024.
//

import SwiftUI

// MARK: - Delete Photo Confirmation

struct DeletePhotoConfirmation: ViewModifier {
    let isPresented: Binding<Bool>
    let photoCount: Int
    let onConfirm: () -> Void

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                L10n.Photos.deletePhotosTitle(photoCount),
                isPresented: isPresented,
                titleVisibility: .visible
            ) {
                Button(L10n.Common.delete, role: .destructive) {
                    onConfirm()
                }
                Button(L10n.Common.cancel, role: .cancel) {}
            } message: {
                Text(L10n.Photos.deletePhotosMessage(photoCount))
            }
    }
}

extension View {
    /// Presents a confirmation dialog for photo deletion
    /// - Parameters:
    ///   - isPresented: Binding to control presentation
    ///   - photoCount: Number of photos to delete
    ///   - onConfirm: Callback when deletion is confirmed
    func deletePhotoConfirmation(
        isPresented: Binding<Bool>,
        photoCount: Int = 1,
        onConfirm: @escaping () -> Void
    ) -> some View {
        modifier(DeletePhotoConfirmation(
            isPresented: isPresented,
            photoCount: photoCount,
            onConfirm: onConfirm
        ))
    }
}

// MARK: - Export Confirmation

struct ExportPhotoConfirmation: ViewModifier {
    let isPresented: Binding<Bool>
    let photoCount: Int
    let onConfirm: () -> Void

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                L10n.Photos.exportPhotosTitle(photoCount),
                isPresented: isPresented,
                titleVisibility: .visible
            ) {
                Button(L10n.Photos.exportToLibrary) {
                    onConfirm()
                }
                Button(L10n.Common.cancel, role: .cancel) {}
            } message: {
                Text(L10n.Photos.exportPhotosMessage(photoCount))
            }
    }
}

extension View {
    /// Presents a confirmation dialog for photo export
    /// - Parameters:
    ///   - isPresented: Binding to control presentation
    ///   - photoCount: Number of photos to export
    ///   - onConfirm: Callback when export is confirmed
    func exportPhotoConfirmation(
        isPresented: Binding<Bool>,
        photoCount: Int = 1,
        onConfirm: @escaping () -> Void
    ) -> some View {
        modifier(ExportPhotoConfirmation(
            isPresented: isPresented,
            photoCount: photoCount,
            onConfirm: onConfirm
        ))
    }
}

// MARK: - Move to Album Sheet

struct MoveToAlbumSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedAlbum: String?
    @State private var isCreatingNewAlbum = false
    @State private var newAlbumName = ""

    let availableAlbums: [String]
    let photoCount: Int
    let onMove: (String) -> Void

    var body: some View {
        NavigationView {
            List {
                // Existing Albums
                if !availableAlbums.isEmpty {
                    Section(L10n.Albums.title) {
                        ForEach(availableAlbums, id: \.self) { album in
                            Button(action: {
                                selectedAlbum = album
                            }) {
                                HStack {
                                    Label(album, systemImage: "folder")
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if selectedAlbum == album {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                        }
                    }
                }

                // Create New Album
                Section {
                    if isCreatingNewAlbum {
                        HStack {
                            Image(systemName: "folder.badge.plus")
                                .foregroundStyle(.blue)
                            TextField(L10n.Albums.albumName, text: $newAlbumName)
                                .textFieldStyle(.plain)
                                .submitLabel(.done)
                                .onSubmit {
                                    if !newAlbumName.isEmpty {
                                        selectedAlbum = newAlbumName
                                        isCreatingNewAlbum = false
                                    }
                                }
                        }
                    } else {
                        Button(action: {
                            isCreatingNewAlbum = true
                        }) {
                            Label(L10n.Albums.createNewAlbum, systemImage: "folder.badge.plus")
                        }
                    }
                }

                // Info
                if photoCount > 1 {
                    Section {
                        HStack {
                            Text(L10n.Albums.photosToMove)
                            Spacer()
                            Text("\(photoCount)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle(L10n.Albums.moveToAlbum)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.cancel) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Common.move) {
                        if let album = selectedAlbum {
                            onMove(album)
                            dismiss()
                        }
                    }
                    .disabled(selectedAlbum == nil)
                }
            }
        }
    }
}

// MARK: - Add Tags Sheet

struct AddTagsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTags: Set<String> = []
    @State private var isCreatingNewTag = false
    @State private var newTagName = ""

    let availableTags: [String]
    let photoCount: Int
    let onAddTags: ([String]) -> Void

    var body: some View {
        NavigationView {
            List {
                // Existing Tags
                if !availableTags.isEmpty {
                    Section(L10n.Tags.title) {
                        ForEach(availableTags, id: \.self) { tag in
                            Button(action: {
                                if selectedTags.contains(tag) {
                                    selectedTags.remove(tag)
                                } else {
                                    selectedTags.insert(tag)
                                }
                            }) {
                                HStack {
                                    Label(tag, systemImage: "tag")
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if selectedTags.contains(tag) {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                        }
                    }
                }

                // Create New Tag
                Section {
                    if isCreatingNewTag {
                        HStack {
                            Image(systemName: "tag.fill")
                                .foregroundStyle(.blue)
                            TextField(L10n.Tags.tagName, text: $newTagName)
                                .textFieldStyle(.plain)
                                .submitLabel(.done)
                                .onSubmit {
                                    if !newTagName.isEmpty {
                                        selectedTags.insert(newTagName)
                                        newTagName = ""
                                        isCreatingNewTag = false
                                    }
                                }
                        }
                    } else {
                        Button(action: {
                            isCreatingNewTag = true
                        }) {
                            Label(L10n.Tags.createNewTag, systemImage: "tag.fill")
                        }
                    }
                }

                // Selected Tags
                if !selectedTags.isEmpty {
                    Section(L10n.Tags.selectedTags) {
                        ForEach(Array(selectedTags), id: \.self) { tag in
                            HStack {
                                Text(tag)
                                Spacer()
                                Button(action: {
                                    selectedTags.remove(tag)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                // Info
                if photoCount > 1 {
                    Section {
                        HStack {
                            Text(L10n.Tags.photosToTag)
                            Spacer()
                            Text("\(photoCount)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle(L10n.Tags.addTags)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.cancel) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Common.add) {
                        onAddTags(Array(selectedTags))
                        dismiss()
                    }
                    .disabled(selectedTags.isEmpty)
                }
            }
        }
    }
}

// MARK: - Operation Progress View

struct OperationProgressView: View {
    let operation: String
    let progress: Double?

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text(operation)
                .font(.headline)

            if let progress = progress {
                ProgressView(value: progress)
                    .frame(width: 200)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Material.ultraThinMaterial)
    }
}

// MARK: - Alert Helpers

extension View {
    /// Presents an alert for operation errors
    func operationErrorAlert(
        isPresented: Binding<Bool>,
        error: String?
    ) -> some View {
        alert(L10n.Alerts.operationFailed, isPresented: isPresented) {
            Button(L10n.Common.ok, role: .cancel) {}
        } message: {
            Text(error ?? L10n.Alerts.unknownError)
        }
    }

    /// Presents an alert for operation success
    func operationSuccessAlert(
        isPresented: Binding<Bool>,
        message: String?
    ) -> some View {
        alert(L10n.Common.success, isPresented: isPresented) {
            Button(L10n.Common.ok, role: .cancel) {}
        } message: {
            Text(message ?? L10n.Alerts.operationSuccess)
        }
    }
}

// MARK: - Previews

#Preview("Delete Confirmation") {
    Text("Test")
        .deletePhotoConfirmation(
            isPresented: .constant(true),
            photoCount: 1,
            onConfirm: {}
        )
}

#Preview("Export Confirmation") {
    Text("Test")
        .exportPhotoConfirmation(
            isPresented: .constant(true),
            photoCount: 5,
            onConfirm: {}
        )
}

#Preview("Move to Album") {
    MoveToAlbumSheet(
        availableAlbums: ["Vacation", "Family", "Work"],
        photoCount: 3,
        onMove: { _ in }
    )
}

#Preview("Add Tags") {
    AddTagsSheet(
        availableTags: ["Nature", "Portrait", "Landscape"],
        photoCount: 5,
        onAddTags: { _ in }
    )
}

#Preview("Operation Progress") {
    OperationProgressView(
        operation: "Exporting photos...",
        progress: 0.65
    )
}
