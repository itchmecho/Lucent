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
                photoCount == 1 ? "Delete Photo?" : "Delete \(photoCount) Photos?",
                isPresented: isPresented,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    onConfirm()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(photoCount == 1
                    ? "This photo will be permanently deleted. This action cannot be undone."
                    : "These \(photoCount) photos will be permanently deleted. This action cannot be undone."
                )
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
                photoCount == 1 ? "Export Photo?" : "Export \(photoCount) Photos?",
                isPresented: isPresented,
                titleVisibility: .visible
            ) {
                Button("Export to Photo Library") {
                    onConfirm()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(photoCount == 1
                    ? "This photo will be decrypted and saved to your photo library."
                    : "These \(photoCount) photos will be decrypted and saved to your photo library."
                )
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
                    Section("Albums") {
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
                            TextField("Album Name", text: $newAlbumName)
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
                            Label("Create New Album", systemImage: "folder.badge.plus")
                        }
                    }
                }

                // Info
                if photoCount > 1 {
                    Section {
                        HStack {
                            Text("Photos to Move")
                            Spacer()
                            Text("\(photoCount)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Move to Album")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Move") {
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
                    Section("Tags") {
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
                            TextField("Tag Name", text: $newTagName)
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
                            Label("Create New Tag", systemImage: "tag.fill")
                        }
                    }
                }

                // Selected Tags
                if !selectedTags.isEmpty {
                    Section("Selected Tags") {
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
                            Text("Photos to Tag")
                            Spacer()
                            Text("\(photoCount)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Add Tags")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
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
        alert("Operation Failed", isPresented: isPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(error ?? "An unknown error occurred")
        }
    }

    /// Presents an alert for operation success
    func operationSuccessAlert(
        isPresented: Binding<Bool>,
        message: String?
    ) -> some View {
        alert("Success", isPresented: isPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message ?? "Operation completed successfully")
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
