//
//  AlbumListView.swift
//  Lucent
//
//  Created by Claude Code on 11/23/2024.
//

import SwiftUI

/// View displaying all albums in a grid layout with liquid glass aesthetic
struct AlbumListView: View {
    @StateObject private var viewModel = AlbumListViewModel()
    @State private var showingCreateSheet = false
    @State private var selectedAlbum: Album?

    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient with dark mode support
                LinearGradient(
                    colors: [
                        Color.backgroundGradientStart,
                        Color.backgroundGradientMiddle,
                        Color.backgroundGradientEnd
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // System Albums Section
                        if !viewModel.systemAlbums.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                GlassSectionHeader(title: L10n.Albums.library)

                                LazyVGrid(columns: columns, spacing: 16) {
                                    ForEach(viewModel.systemAlbums) { album in
                                        AlbumCardView(album: album)
                                            .onTapGesture {
                                                selectedAlbum = album
                                            }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }

                        // User Albums Section
                        if !viewModel.userAlbums.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                GlassSectionHeader(
                                    title: L10n.Albums.myAlbums,
                                    action: { showingCreateSheet = true },
                                    actionTitle: L10n.Common.new
                                )

                                LazyVGrid(columns: columns, spacing: 16) {
                                    ForEach(viewModel.userAlbums) { album in
                                        AlbumCardView(album: album)
                                            .onTapGesture {
                                                selectedAlbum = album
                                            }
                                            .contextMenu {
                                                Button(role: .destructive) {
                                                    viewModel.deleteAlbum(album)
                                                } label: {
                                                    Label(L10n.Albums.deleteAlbum, systemImage: "trash")
                                                }
                                            }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }

                        // Empty state
                        if viewModel.userAlbums.isEmpty && !viewModel.isLoading {
                            GlassCard(padding: 40) {
                                VStack(spacing: 16) {
                                    Image(systemName: "photo.stack")
                                        .font(.system(size: 60))
                                        .foregroundColor(.secondary)

                                    Text(L10n.Albums.noAlbumsTitle)
                                        .font(.title2)
                                        .fontWeight(.bold)

                                    Text(L10n.Albums.noAlbumsMessage)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)

                                    Button(action: { showingCreateSheet = true }) {
                                        Text(L10n.Albums.createAlbum)
                                            .fontWeight(.semibold)
                                            .padding(.horizontal, 24)
                                            .padding(.vertical, 12)
                                            .background(Material.thin)
                                            .cornerRadius(20)
                                    }
                                    .padding(.top, 8)
                                }
                            }
                            .padding()
                        }
                    }
                    .padding(.vertical)
                }
                .refreshable {
                    await viewModel.loadAlbums()
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
            .navigationTitle(L10n.Albums.title)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingCreateSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showingCreateSheet) {
                CreateAlbumView()
            }
            .navigationDestination(item: $selectedAlbum) { album in
                AlbumDetailView(album: album)
            }
            .alert(L10n.Common.error, isPresented: $viewModel.showError) {
                Button(L10n.Common.ok, role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
            .task {
                await viewModel.loadAlbums()
            }
        }
    }
}

/// Individual album card view
struct AlbumCardView: View {
    let album: Album
    #if canImport(UIKit)
    @State private var coverImage: UIImage?
    #else
    @State private var coverImage: NSImage?
    #endif

    var body: some View {
        GlassCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                // Cover image
                ZStack {
                    if let coverImage = coverImage {
                        #if canImport(UIKit)
                        Image(uiImage: coverImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 140)
                            .clipped()
                        #else
                        Image(nsImage: coverImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 140)
                            .clipped()
                        #endif
                    } else {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: albumGradientColors,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(height: 140)
                            .overlay {
                                Image(systemName: albumIcon)
                                    .font(.system(size: 40))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                    }
                }

                // Album info
                VStack(alignment: .leading, spacing: 4) {
                    Text(album.name)
                        .font(.headline)
                        .lineLimit(1)

                    Text(L10n.Photos.photoCount(album.photoCount))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(12)
            }
        }
        .task {
            await loadCoverImage()
        }
    }

    private var albumGradientColors: [Color] {
        if let themeColor = album.themeColor, let color = Color(hex: themeColor) {
            return [color, color.opacity(0.7)]
        }

        // Default colors for system albums
        if album.id == Album.allPhotosAlbum().id {
            return [.blue, .cyan]
        } else if album.id == Album.favoritesAlbum().id {
            return [.red, .orange]
        } else if album.id == Album.recentAlbum().id {
            return [.green, .mint]
        }

        return [.purple, .pink]
    }

    private var albumIcon: String {
        if album.id == Album.allPhotosAlbum().id {
            return "photo.stack.fill"
        } else if album.id == Album.favoritesAlbum().id {
            return "heart.fill"
        } else if album.id == Album.recentAlbum().id {
            return "clock.fill"
        }
        return "photo.on.rectangle"
    }

    private func loadCoverImage() async {
        guard let coverPhotoId = album.coverPhotoId else { return }

        do {
            let storage = SecurePhotoStorage.shared
            let thumbnailManager = ThumbnailManager.shared

            // Retrieve the photo data
            let photoData = try await storage.retrievePhoto(id: coverPhotoId)
            
            // Try to load thumbnail
            let thumbnailData = try await thumbnailManager.getThumbnail(for: coverPhotoId, from: photoData)
            
            // Convert thumbnail data to UIImage
            if let image = UIImage(data: thumbnailData) {
                coverImage = image
            }
        } catch {
            // Failed to load cover image, keep placeholder
        }
    }
}

// MARK: - ViewModel

@MainActor
class AlbumListViewModel: ObservableObject {
    @Published var systemAlbums: [Album] = []
    @Published var userAlbums: [Album] = []
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""

    func loadAlbums() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let albumManager = AlbumManager.shared
            try await albumManager.initialize()
            try await albumManager.syncSystemAlbums()

            let allAlbums = try await albumManager.listAlbums(includeSystem: true)

            systemAlbums = allAlbums.filter { $0.isSystemAlbum }
            userAlbums = allAlbums.filter { !$0.isSystemAlbum }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func deleteAlbum(_ album: Album) {
        Task {
            do {
                try await AlbumManager.shared.deleteAlbum(id: album.id)
                await loadAlbums()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

// MARK: - Color Extension

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Preview

#Preview {
    AlbumListView()
}
