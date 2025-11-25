//
//  PhotoGridView.swift
//  Lucent
//
//  Created by Claude Code on 11/23/2024.
//

import SwiftUI

/// Main photo grid view displaying thumbnails in a responsive grid layout
struct PhotoGridView: View {
    // MARK: - Properties

    @StateObject private var viewModel = PhotoGridViewModel()
    @State private var selectedPhoto: EncryptedPhoto?
    @State private var showingPhotoDetail = false
    @State private var showingSlideshow = false
    @State private var showingImportMenu = false
    @State private var columns = 3
    @AppStorage("showThumbnails") private var showThumbnails = true
    @AppStorage("showCameraButton") private var showCameraButton = true

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // Liquid glass background
                Color.clear
                    .background(.ultraThinMaterial)
                    .ignoresSafeArea()

                if viewModel.isLoading && viewModel.photos.isEmpty {
                    // Loading state
                    loadingView
                } else if viewModel.filteredPhotos.isEmpty {
                    // Empty state
                    emptyStateView
                } else {
                    // Photo grid
                    photoGridContent
                }
            }
            .navigationTitle("Photos")
            .toolbar {
                toolbarContent
            }
            .searchable(text: $viewModel.searchQuery, prompt: "Search photos")
            .sheet(isPresented: $showingImportMenu) {
                ImportMenuView(onImportComplete: {
                    showingImportMenu = false
                    Task {
                        await viewModel.refresh()
                    }
                })
            }
            .sheet(isPresented: $showingPhotoDetail) {
                if let photo = selectedPhoto {
                    PhotoDetailView(
                        photo: photo,
                        allPhotos: viewModel.filteredPhotos,
                        onDismiss: {
                            showingPhotoDetail = false
                            selectedPhoto = nil
                        }
                    )
                }
            }
            #if canImport(UIKit)
            .fullScreenCover(isPresented: $showingSlideshow) {
                if !viewModel.filteredPhotos.isEmpty {
                    SlideshowView(
                        photos: viewModel.filteredPhotos,
                        startIndex: viewModel.filteredPhotos.firstIndex(where: { $0.id == selectedPhoto?.id }) ?? 0,
                        onDismiss: {
                            showingSlideshow = false
                        }
                    )
                }
            }
            #endif
            .refreshable {
                await viewModel.refresh()
            }
            .safeAreaInset(edge: .bottom) {
                if showCameraButton {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()

                            #if canImport(UIKit)
                            CameraButton { _ in
                                Task {
                                    await viewModel.refresh()
                                }
                            }
                            .frame(width: 60, height: 60)
                            #endif

                            Spacer()
                                .frame(width: 16)
                        }
                        .padding(.bottom, 16)
                    }
                    .frame(maxHeight: .infinity, alignment: .bottomTrailing)
                }
            }
        }
        .onDisappear {
            // Clear thumbnails from memory for security
            viewModel.clearThumbnailsFromMemory()
        }
    }

    // MARK: - View Components

    private var photoGridContent: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 2) {
                ForEach(viewModel.filteredPhotos) { photo in
                    PhotoGridCell(
                        photo: photo,
                        thumbnail: viewModel.thumbnails[photo.id],
                        isLoading: viewModel.loadingPhotos.contains(photo.id),
                        onRegenerateThumbnail: photo.thumbnailGenerationFailed ? {
                            Task {
                                await viewModel.regenerateThumbnail(for: photo)
                            }
                        } : nil
                    )
                    .aspectRatio(1, contentMode: .fill)
                    .onTapGesture {
                        selectedPhoto = photo
                        showingPhotoDetail = true
                    }
                    .contextMenu {
                        photoContextMenu(for: photo)
                    }
                    .task {
                        if showThumbnails {
                            await viewModel.loadThumbnail(for: photo)
                        }
                    }
                    .onChange(of: showThumbnails) { oldValue, newValue in
                        if !newValue {
                            // Clear thumbnails from memory when disabled
                            viewModel.clearThumbnailsFromMemory()
                        }
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading photos...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.stack")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text("No Photos")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Import photos to get started")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                // Import and camera section
                Section {
                    Button {
                        showingImportMenu = true
                    } label: {
                        Label("Import Photos", systemImage: "plus.circle.fill")
                    }

                    if !showCameraButton {
                        Button {
                            // Camera will be triggered via CameraButton in PhotoGridView
                        } label: {
                            Label("Take Photo", systemImage: "camera.fill")
                        }
                    }
                }

                // View options
                Section("View") {
                    Picker("Columns", selection: $columns) {
                        Text("2").tag(2)
                        Text("3").tag(3)
                        Text("4").tag(4)
                        Text("5").tag(5)
                    }
                    .pickerStyle(.menu)
                }

                // Sort options
                Section("Sort By") {
                    Button {
                        viewModel.sortOrder = .dateAddedNewest
                    } label: {
                        HStack {
                            Text("Date Added (Newest)")
                            Spacer()
                            if viewModel.sortOrder == .dateAddedNewest {
                                Image(systemName: "checkmark")
                            }
                        }
                    }

                    Button {
                        viewModel.sortOrder = .dateAddedOldest
                    } label: {
                        HStack {
                            Text("Date Added (Oldest)")
                            Spacer()
                            if viewModel.sortOrder == .dateAddedOldest {
                                Image(systemName: "checkmark")
                            }
                        }
                    }

                    Button {
                        viewModel.sortOrder = .dateTakenNewest
                    } label: {
                        HStack {
                            Text("Date Taken (Newest)")
                            Spacer()
                            if viewModel.sortOrder == .dateTakenNewest {
                                Image(systemName: "checkmark")
                            }
                        }
                    }

                    Button {
                        viewModel.sortOrder = .dateTakenOldest
                    } label: {
                        HStack {
                            Text("Date Taken (Oldest)")
                            Spacer()
                            if viewModel.sortOrder == .dateTakenOldest {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }

                // Filter options
                Section("Filter") {
                    Button {
                        viewModel.selectedFilter = .all
                    } label: {
                        HStack {
                            Text("All Photos")
                            Spacer()
                            if viewModel.selectedFilter == .all {
                                Image(systemName: "checkmark")
                            }
                        }
                    }

                    Button {
                        viewModel.selectedFilter = .favorites
                    } label: {
                        Label("Favorites", systemImage: "star.fill")
                    }
                }

                // Slideshow
                if !viewModel.filteredPhotos.isEmpty {
                    Section {
                        Button {
                            selectedPhoto = viewModel.filteredPhotos.first
                            showingSlideshow = true
                        } label: {
                            Label("Start Slideshow", systemImage: "play.fill")
                        }
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    @ViewBuilder
    private func photoContextMenu(for photo: EncryptedPhoto) -> some View {
        Button {
            Task {
                await viewModel.toggleFavorite(photo)
            }
        } label: {
            Label(
                photo.metadata.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                systemImage: photo.metadata.isFavorite ? "star.slash" : "star"
            )
        }

        Button {
            selectedPhoto = photo
            showingSlideshow = true
        } label: {
            Label("Slideshow from Here", systemImage: "play.fill")
        }

        Divider()

        Button(role: .destructive) {
            Task {
                await viewModel.deletePhoto(photo)
            }
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    // MARK: - Computed Properties

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 2), count: columns)
    }
}

// MARK: - Photo Grid Cell

struct PhotoGridCell: View {
    let photo: EncryptedPhoto
    let thumbnail: PlatformImage?
    let isLoading: Bool
    var onRegenerateThumbnail: (() -> Void)? = nil

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let thumbnail = thumbnail {
                    #if canImport(UIKit)
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                    #elseif canImport(AppKit)
                    Image(nsImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                    #endif
                } else if isLoading {
                    Color.gray.opacity(0.2)
                    ProgressView()
                } else if photo.thumbnailGenerationFailed {
                    // Show failed state with retry option
                    Color.gray.opacity(0.2)
                    VStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title2)
                            .foregroundStyle(.orange)
                        if let onRegenerate = onRegenerateThumbnail {
                            Button(action: onRegenerate) {
                                Text("Retry")
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } else {
                    Color.gray.opacity(0.2)
                    Image(systemName: "photo")
                        .font(.title)
                        .foregroundStyle(.secondary)
                }

                // Favorite badge
                if photo.metadata.isFavorite {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundStyle(.yellow)
                                .padding(6)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                                .padding(4)
                        }
                        Spacer()
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .clipShape(RoundedRectangle(cornerRadius: 2))
    }
}

// MARK: - Preview

#Preview {
    PhotoGridView()
}
