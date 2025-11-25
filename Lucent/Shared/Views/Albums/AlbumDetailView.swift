//
//  AlbumDetailView.swift
//  Lucent
//
//  Created by Claude Code on 11/23/2024.
//

import SwiftUI
import os.log

/// View displaying photos in an album with grid layout and sorting options
struct AlbumDetailView: View {
    let album: Album
    @StateObject private var viewModel: AlbumDetailViewModel
    @State private var showingSortOptions = false
    @State private var showingEditSheet = false

    init(album: Album) {
        self.album = album
        _viewModel = StateObject(wrappedValue: AlbumDetailViewModel(album: album))
    }

    private let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 150), spacing: 2)
    ]

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.3),
                    Color.purple.opacity(0.3),
                    Color.pink.opacity(0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Album header
                    albumHeader

                    // Photos grid
                    if !viewModel.photos.isEmpty {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(viewModel.photos) { photo in
                                PhotoThumbnailView(photo: photo)
                                    .aspectRatio(1, contentMode: .fill)
                            }
                        }
                        .padding(.top)
                    } else {
                        // Empty state
                        GlassCard(padding: 40) {
                            VStack(spacing: 16) {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.system(size: 60))
                                    .foregroundColor(.secondary)

                                Text("No Photos")
                                    .font(.title2)
                                    .fontWeight(.bold)

                                Text(album.isSystemAlbum
                                     ? "Photos will appear here automatically"
                                     : "Add photos to this album to see them here")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding()
                    }
                }
            }
            .refreshable {
                await viewModel.loadPhotos()
            }

            // Loading overlay
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .padding()
                    .background(Material.ultraThickMaterial)
                    .cornerRadius(12)
            }
        }
        .navigationTitle(album.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(action: { showingSortOptions = true }) {
                        Label("Sort", systemImage: "arrow.up.arrow.down")
                    }

                    if !album.isSystemAlbum {
                        Button(action: { showingEditSheet = true }) {
                            Label("Edit Album", systemImage: "pencil")
                        }
                    }

                    Divider()

                    Picker("Sort Order", selection: $viewModel.sortOrder) {
                        ForEach(PhotoSortOrder.allCases, id: \.self) { order in
                            Label(order.displayName, systemImage: order.systemImageName)
                                .tag(order)
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditAlbumView(album: album)
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
        .task {
            await viewModel.loadPhotos()
        }
    }

    private var albumHeader: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(album.name)
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("\(viewModel.photos.count) photo\(viewModel.photos.count == 1 ? "" : "s")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if let themeColor = album.themeColor, let color = Color(hex: themeColor) {
                        Circle()
                            .fill(color)
                            .frame(width: 40, height: 40)
                            .shadow(radius: 4)
                    }
                }

                if let description = album.description {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }
}

/// Individual photo thumbnail view
struct PhotoThumbnailView: View {
    let photo: EncryptedPhoto
    #if canImport(UIKit)
    @State private var thumbnail: UIImage?
    #else
    @State private var thumbnail: NSImage?
    #endif

    var body: some View {
        ZStack {
            if let thumbnail = thumbnail {
                #if canImport(UIKit)
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                #else
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                #endif
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay {
                        ProgressView()
                    }
            }
        }
        .clipped()
        .task {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        let thumbnailManager = ThumbnailManager.shared

        do {
            // Try to get cached thumbnail first
            if let cachedData = await thumbnailManager.getCachedThumbnail(for: photo.id) {
                thumbnail = UIImage(data: cachedData)
                return
            }

            // Load and decrypt thumbnail from storage
            if let thumbnailURL = photo.thumbnailURL {
                let encryptedData = try Data(contentsOf: thumbnailURL)
                let decryptedData = try EncryptionManager.shared.decrypt(data: encryptedData)

                // Cache decrypted thumbnail
                await thumbnailManager.cacheThumbnail(decryptedData, for: photo.id)

                // Create UIImage
                thumbnail = UIImage(data: decryptedData)
            }
        } catch {
            // Silently fail - thumbnail will show placeholder
            AppLogger.storage.error("Failed to load thumbnail for \(photo.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }
}

/// Edit album view
struct EditAlbumView: View {
    @Environment(\.dismiss) private var dismiss
    let album: Album

    @State private var albumName: String
    @State private var albumDescription: String
    @State private var selectedColor: Color?
    @State private var isUpdating = false
    @State private var showError = false
    @State private var errorMessage = ""

    private let themeColors: [Color] = [
        .red, .orange, .yellow, .green, .mint, .teal,
        .cyan, .blue, .indigo, .purple, .pink, .brown
    ]

    init(album: Album) {
        self.album = album
        _albumName = State(initialValue: album.name)
        _albumDescription = State(initialValue: album.description ?? "")
        _selectedColor = State(initialValue: album.themeColor.flatMap { Color(hex: $0) })
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color.blue.opacity(0.3),
                        Color.purple.opacity(0.3),
                        Color.pink.opacity(0.2)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        GlassTextField(
                            title: "Album Name",
                            text: $albumName,
                            placeholder: "Enter album name",
                            icon: "rectangle.stack"
                        )

                        GlassTextEditor(
                            title: "Description (Optional)",
                            text: $albumDescription,
                            placeholder: "Enter a description for this album",
                            height: 100
                        )

                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Theme Color")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)

                                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12) {
                                    ForEach(themeColors, id: \.self) { color in
                                        Button(action: {
                                            selectedColor = color
                                        }) {
                                            Circle()
                                                .fill(color)
                                                .frame(width: 44, height: 44)
                                                .overlay(
                                                    Circle()
                                                        .stroke(Color.white, lineWidth: selectedColor == color ? 3 : 0)
                                                )
                                                .shadow(radius: 4)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }

                if isUpdating {
                    ProgressView()
                        .scaleEffect(1.5)
                        .padding()
                        .background(Material.ultraThickMaterial)
                        .cornerRadius(12)
                }
            }
            .navigationTitle("Edit Album")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button("Save") {
                        Task {
                            await saveChanges()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(albumName.isEmpty || isUpdating)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func saveChanges() async {
        isUpdating = true
        defer { isUpdating = false }

        do {
            var updatedAlbum = album
            updatedAlbum.rename(albumName.trimmingCharacters(in: .whitespacesAndNewlines))
            updatedAlbum.updateDescription(albumDescription.isEmpty ? nil : albumDescription.trimmingCharacters(in: .whitespacesAndNewlines))
            updatedAlbum.updateThemeColor(selectedColor?.toHex())

            try await AlbumManager.shared.updateAlbum(updatedAlbum)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - ViewModel

@MainActor
class AlbumDetailViewModel: ObservableObject {
    let album: Album

    @Published var photos: [EncryptedPhoto] = []
    @Published var sortOrder: PhotoSortOrder
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""

    init(album: Album) {
        self.album = album
        self.sortOrder = album.sortOrder
    }

    func loadPhotos() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let albumManager = AlbumManager.shared
            photos = try await albumManager.getPhotosInAlbum(albumId: album.id)

            // Re-sort if sort order changed
            photos = sortPhotos(photos, by: sortOrder)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func sortPhotos(_ photos: [EncryptedPhoto], by order: PhotoSortOrder) -> [EncryptedPhoto] {
        switch order {
        case .dateAddedNewest:
            return photos.sorted { $0.dateAdded > $1.dateAdded }
        case .dateAddedOldest:
            return photos.sorted { $0.dateAdded < $1.dateAdded }
        case .dateTakenNewest:
            return photos.sorted { $0.displayDate > $1.displayDate }
        case .dateTakenOldest:
            return photos.sorted { $0.displayDate < $1.displayDate }
        case .filename:
            return photos.sorted { $0.filename < $1.filename }
        case .fileSize:
            return photos.sorted { $0.metadata.fileSize > $1.metadata.fileSize }
        case .custom:
            return photos
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        AlbumDetailView(album: Album.favoritesAlbum())
    }
}
