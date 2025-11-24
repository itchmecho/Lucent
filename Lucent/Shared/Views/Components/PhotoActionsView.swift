//
//  PhotoActionsView.swift
//  Lucent
//
//  Created by Claude Code on 11/23/2024.
//

import SwiftUI

/// Action menu for photo management operations
struct PhotoActionsView: View {
    // MARK: - Properties

    let photo: EncryptedPhoto
    let onAction: (PhotoAction) -> Void

    @Environment(\.dismiss) private var dismiss

    // MARK: - Action Types

    enum PhotoAction {
        case favorite
        case addToAlbum
        case addTags
        case share
        case export
        case delete
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            List {
                // Favorite Section
                Section {
                    Button(action: {
                        onAction(.favorite)
                        dismiss()
                    }) {
                        Label(
                            photo.metadata.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                            systemImage: photo.metadata.isFavorite ? "heart.slash.fill" : "heart.fill"
                        )
                    }
                }

                // Organization Section
                Section("Organization") {
                    Button(action: {
                        onAction(.addToAlbum)
                    }) {
                        Label("Move to Album", systemImage: "folder")
                    }

                    Button(action: {
                        onAction(.addTags)
                    }) {
                        Label("Add Tags", systemImage: "tag")
                    }
                }

                // Sharing Section
                Section("Sharing") {
                    Button(action: {
                        onAction(.share)
                        dismiss()
                    }) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }

                    Button(action: {
                        onAction(.export)
                        dismiss()
                    }) {
                        Label("Export to Photo Library", systemImage: "square.and.arrow.down")
                    }
                }

                // Delete Section
                Section {
                    Button(role: .destructive, action: {
                        onAction(.delete)
                    }) {
                        Label("Delete Photo", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Photo Actions")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

/// Batch actions menu for multiple selected photos
struct BatchActionsView: View {
    // MARK: - Properties

    let selectedCount: Int
    let onAction: (BatchAction) -> Void

    @Environment(\.dismiss) private var dismiss

    // MARK: - Action Types

    enum BatchAction {
        case addToFavorites
        case removeFromFavorites
        case moveToAlbum
        case addTags
        case share
        case export
        case delete
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            List {
                // Info Section
                Section {
                    HStack {
                        Text("Selected Photos")
                            .font(.headline)
                        Spacer()
                        Text("\(selectedCount)")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                }

                // Favorites Section
                Section("Favorites") {
                    Button(action: {
                        onAction(.addToFavorites)
                        dismiss()
                    }) {
                        Label("Add to Favorites", systemImage: "heart.fill")
                    }

                    Button(action: {
                        onAction(.removeFromFavorites)
                        dismiss()
                    }) {
                        Label("Remove from Favorites", systemImage: "heart.slash.fill")
                    }
                }

                // Organization Section
                Section("Organization") {
                    Button(action: {
                        onAction(.moveToAlbum)
                    }) {
                        Label("Move to Album", systemImage: "folder")
                    }

                    Button(action: {
                        onAction(.addTags)
                    }) {
                        Label("Add Tags", systemImage: "tag")
                    }
                }

                // Sharing Section
                Section("Sharing") {
                    Button(action: {
                        onAction(.share)
                        dismiss()
                    }) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }

                    Button(action: {
                        onAction(.export)
                        dismiss()
                    }) {
                        Label("Export to Photo Library", systemImage: "square.and.arrow.down")
                    }
                }

                // Delete Section
                Section {
                    Button(role: .destructive, action: {
                        onAction(.delete)
                    }) {
                        Label("Delete Selected", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Batch Actions")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Context Menu Builder

extension View {
    /// Adds a photo context menu with management actions
    func photoContextMenu(
        photo: EncryptedPhoto,
        onAction: @escaping (PhotoActionsView.PhotoAction) -> Void
    ) -> some View {
        contextMenu {
            // Favorite
            Button(action: { onAction(.favorite) }) {
                Label(
                    photo.metadata.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                    systemImage: photo.metadata.isFavorite ? "heart.slash" : "heart"
                )
            }

            Divider()

            // Organization
            Button(action: { onAction(.addToAlbum) }) {
                Label("Move to Album", systemImage: "folder")
            }

            Button(action: { onAction(.addTags) }) {
                Label("Add Tags", systemImage: "tag")
            }

            Divider()

            // Share & Export
            Button(action: { onAction(.share) }) {
                Label("Share", systemImage: "square.and.arrow.up")
            }

            Button(action: { onAction(.export) }) {
                Label("Export", systemImage: "square.and.arrow.down")
            }

            Divider()

            // Delete
            Button(role: .destructive, action: { onAction(.delete) }) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Preview

#Preview("Photo Actions") {
    PhotoActionsView(
        photo: EncryptedPhoto(
            metadata: PhotoMetadata(fileSize: 1024 * 1024)
        ),
        onAction: { _ in }
    )
}

#Preview("Batch Actions") {
    BatchActionsView(
        selectedCount: 5,
        onAction: { _ in }
    )
}
