import SwiftUI
import os.log

struct ContentView: View {
    @State private var selectedTab = 0
    @AppStorage("useGridView") private var useGridView = false

    var body: some View {
        TabView(selection: $selectedTab) {
            // Photos tab - switch between list and grid view
            Group {
                if useGridView {
                    PhotoGridView()
                } else {
                    PhotosMainView()
                }
            }
            .tabItem {
                Label(L10n.Tabs.photos, systemImage: "photo.on.rectangle")
            }
            .tag(0)

            // Settings tab
            SettingsView()
                .tabItem {
                    Label(L10n.Tabs.settings, systemImage: "gear")
                }
                .tag(1)
        }
    }
}

// Main photos view
struct PhotosMainView: View {
    @State private var photos: [EncryptedPhoto] = []
    @State private var thumbnails: [UUID: PlatformImage] = [:]
    @State private var loadingThumbnails: Set<UUID> = []
    @State private var isLoading = true
    @State private var showingImportMenu = false
    @State private var selectedPhotoForDetail: EncryptedPhoto?
    @State private var photoToDelete: EncryptedPhoto?
    @State private var showingDeleteConfirmation = false
    @AppStorage("showThumbnails") private var showThumbnails = true

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

                if isLoading {
                    VStack(spacing: DesignTokens.Spacing.lg) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(Color.textPrimary)
                        Text(L10n.Common.loading)
                            .foregroundColor(Color.textSecondary)
                    }
                } else if photos.isEmpty {
                    emptyStateView
                } else {
                    photoListView
                }
            }
            .navigationTitle("Lucent")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        showingImportMenu = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                    .foregroundStyle(Color.lucentAccent)
                }
            }
            .sheet(isPresented: $showingImportMenu) {
                ImportMenuView(onImportComplete: {
                    showingImportMenu = false
                    Task {
                        await loadPhotos()
                    }
                })
            }
            .sheet(item: $selectedPhotoForDetail) { photo in
                PhotoDetailView(photo: photo, allPhotos: photos) {
                    selectedPhotoForDetail = nil
                }
            }
            .alert(L10n.Photos.deletePhotoTitle, isPresented: $showingDeleteConfirmation) {
                Button(L10n.Common.delete, role: .destructive) {
                    if let photo = photoToDelete {
                        Task {
                            await deletePhoto(photo)
                        }
                    }
                }
                Button(L10n.Common.cancel, role: .cancel) {}
            } message: {
                Text(L10n.Photos.deletePhotoMessage)
            }
            .task {
                await loadPhotos()
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: DesignTokens.IconSize.huge))
                .foregroundColor(Color.textSecondary)

            Text(L10n.Photos.noPhotosTitle)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(Color.textPrimary)

            Text(L10n.Photos.noPhotosMessage)
                .font(.subheadline)
                .foregroundColor(Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignTokens.Spacing.lg)
        }
        .padding(DesignTokens.Spacing.lg)
    }

    private var photoListView: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.md) {
                ForEach(photos) { photo in
                    PhotoRowView(
                        photo: photo,
                        thumbnail: thumbnails[photo.id],
                        isLoading: loadingThumbnails.contains(photo.id)
                    )
                    .onTapGesture {
                        selectedPhotoForDetail = photo
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            photoToDelete = photo
                            showingDeleteConfirmation = true
                        } label: {
                            Label(L10n.Common.delete, systemImage: "trash")
                        }
                    }
                    .task {
                        if showThumbnails {
                            await loadThumbnail(for: photo)
                        }
                    }
                    .onChange(of: showThumbnails) { oldValue, newValue in
                        if !newValue {
                            // Clear thumbnails from memory when disabled
                            thumbnails.removeAll()
                            loadingThumbnails.removeAll()
                        }
                    }
                }
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .scrollContentBackground(.hidden)
    }

    private func loadPhotos() async {
        isLoading = true

        do {
            try await SecurePhotoStorage.shared.initializeStorage()
            let loadedPhotos = try await SecurePhotoStorage.shared.listAllPhotos()
            await MainActor.run {
                self.photos = loadedPhotos
                self.isLoading = false
            }
        } catch {
            AppLogger.storage.error("Error loading photos: \(error.localizedDescription, privacy: .public)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }

    private func deletePhoto(_ photo: EncryptedPhoto) async {
        do {
            try await PhotoManagementManager.shared.deletePhoto(id: photo.id)
            // Reload photos after deletion
            await loadPhotos()
            photoToDelete = nil
        } catch {
            AppLogger.storage.error("Error deleting photo: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func loadThumbnail(for photo: EncryptedPhoto) async {
        // Skip if already loaded or loading
        guard thumbnails[photo.id] == nil, !loadingThumbnails.contains(photo.id) else {
            return
        }

        loadingThumbnails.insert(photo.id)

        do {
            // Load and decrypt thumbnail
            if let thumbnailURL = photo.thumbnailURL {
                let encryptedData = try Data(contentsOf: thumbnailURL)
                let decryptedData = try EncryptionManager.shared.decrypt(data: encryptedData)

                // Create platform image
                if let image = PlatformImage.from(data: decryptedData) {
                    thumbnails[photo.id] = image
                }
            }
        } catch {
            AppLogger.storage.error("Failed to load thumbnail for \(photo.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }

        loadingThumbnails.remove(photo.id)
    }
}

// Simple photo row with thumbnail support
struct PhotoRowView: View {
    let photo: EncryptedPhoto
    var thumbnail: PlatformImage?
    var isLoading: Bool = false

    var body: some View {
        HStack {
            // Thumbnail or placeholder
            ZStack {
                if let thumbnail = thumbnail {
                    #if canImport(UIKit)
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                    #elseif canImport(AppKit)
                    Image(nsImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                    #endif
                } else if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundColor(Color.textSecondary)
                }
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md))
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                    .fill(DesignTokens.Materials.ultraThin)
            )

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(photo.filename)
                    .font(.headline)
                    .foregroundColor(Color.textPrimary)

                Text(photo.formattedFileSize)
                    .font(.caption)
                    .foregroundColor(Color.textTertiary)

                Text(photo.displayDate, style: .date)
                    .font(.caption)
                    .foregroundColor(Color.textTertiary)
            }

            Spacer()
        }
        .padding(DesignTokens.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg)
                .fill(DesignTokens.Materials.ultraThin)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg)
                        .stroke(Color.glassBorder, lineWidth: 1)
                )
        )
        .glassShadow()
    }
}

// Settings placeholder - DEPRECATED: Using SettingsView instead
// Kept for backwards compatibility during migration

// Import menu view
struct ImportMenuView: View {
    @Environment(\.dismiss) private var dismiss
    var onImportComplete: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
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

                VStack(spacing: DesignTokens.Spacing.lg) {
                    Text(L10n.Import.addPhotos)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Color.textPrimary)
                        .padding(.top, DesignTokens.Spacing.xl)

                    Text(L10n.Import.chooseMethod)
                        .font(.subheadline)
                        .foregroundColor(Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DesignTokens.Spacing.lg)

                    VStack(spacing: DesignTokens.Spacing.md) {
                        PhotoPickerButton(selectionLimit: nil) { result in
                            onImportComplete()
                        }
                        .padding(.horizontal, DesignTokens.Spacing.lg)

                        #if canImport(UIKit)
                        CameraButton { photo in
                            onImportComplete()
                        }
                        .padding(.horizontal, DesignTokens.Spacing.lg)
                        #endif
                    }
                    .padding(.top, DesignTokens.Spacing.lg)

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(Color.textSecondary)
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
