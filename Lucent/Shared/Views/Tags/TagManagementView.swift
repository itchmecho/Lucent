//
//  TagManagementView.swift
//  Lucent
//
//  Created by Claude Code on 11/23/2024.
//

import SwiftUI

/// View for managing tags including viewing, editing, and deleting tags
struct TagManagementView: View {
    @StateObject private var viewModel = TagManagementViewModel()
    @State private var showingAddTag = false
    @State private var selectedTag: String?

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
                    VStack(spacing: 20) {
                        if !viewModel.tags.isEmpty {
                            // Tag statistics
                            GlassCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Overview")
                                        .font(.headline)

                                    HStack(spacing: 20) {
                                        StatisticView(
                                            value: "\(viewModel.tags.count)",
                                            label: "Tags",
                                            icon: "tag.fill"
                                        )

                                        StatisticView(
                                            value: "\(viewModel.totalPhotos)",
                                            label: "Tagged Photos",
                                            icon: "photo.fill"
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal)

                            // Tag list
                            GlassCard(padding: 0) {
                                VStack(spacing: 0) {
                                    ForEach(viewModel.sortedTags, id: \.key) { tag, count in
                                        TagRowView(
                                            tag: tag,
                                            photoCount: count,
                                            onTap: {
                                                selectedTag = tag
                                            },
                                            onRename: {
                                                viewModel.startRenaming(tag)
                                            },
                                            onDelete: {
                                                viewModel.deleteTag(tag)
                                            }
                                        )

                                        if tag != viewModel.sortedTags.last?.key {
                                            Divider()
                                                .padding(.leading)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        } else if !viewModel.isLoading {
                            // Empty state
                            GlassCard(padding: 40) {
                                VStack(spacing: 16) {
                                    Image(systemName: "tag")
                                        .font(.system(size: 60))
                                        .foregroundColor(.secondary)

                                    Text("No Tags Yet")
                                        .font(.title2)
                                        .fontWeight(.bold)

                                    Text("Tags will appear here when you add them to photos")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                            }
                            .padding()
                        }
                    }
                    .padding(.vertical)
                }
                .refreshable {
                    await viewModel.loadTags()
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
            .navigationTitle("Tags")
            .navigationDestination(item: $selectedTag) { tag in
                TagDetailView(tag: tag)
            }
            .alert("Rename Tag", isPresented: $viewModel.showingRenameDialog) {
                TextField("New name", text: $viewModel.newTagName)
                Button("Cancel", role: .cancel) {
                    viewModel.cancelRename()
                }
                Button("Rename") {
                    Task {
                        await viewModel.confirmRename()
                    }
                }
            } message: {
                if let tag = viewModel.tagToRename {
                    Text("Rename \"\(tag)\" to:")
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
            .task {
                await viewModel.loadTags()
            }
        }
    }
}

/// Individual tag row view
struct TagRowView: View {
    let tag: String
    let photoCount: Int
    let onTap: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Tag icon
                Image(systemName: "tag.fill")
                    .foregroundColor(.accentColor)
                    .frame(width: 24)

                // Tag info
                VStack(alignment: .leading, spacing: 2) {
                    Text(tag)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Text("\(photoCount) photo\(photoCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .contentShape(Rectangle())
        }
        .contextMenu {
            Button(action: onRename) {
                Label("Rename", systemImage: "pencil")
            }

            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

/// Statistic view for overview
struct StatisticView: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)

                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

/// Detail view for a specific tag showing all photos with that tag
struct TagDetailView: View {
    let tag: String
    @StateObject private var viewModel: TagDetailViewModel

    init(tag: String) {
        self.tag = tag
        _viewModel = StateObject(wrappedValue: TagDetailViewModel(tag: tag))
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
                    // Tag header
                    GlassCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(tag)
                                    .font(.title2)
                                    .fontWeight(.bold)

                                Text("\(viewModel.photos.count) photo\(viewModel.photos.count == 1 ? "" : "s")")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Image(systemName: "tag.fill")
                                .font(.title2)
                                .foregroundColor(.accentColor)
                        }
                    }
                    .padding()

                    // Photos grid
                    if !viewModel.photos.isEmpty {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(viewModel.photos) { photo in
                                PhotoThumbnailView(photo: photo)
                                    .aspectRatio(1, contentMode: .fill)
                            }
                        }
                    } else if !viewModel.isLoading {
                        GlassCard(padding: 40) {
                            VStack(spacing: 16) {
                                Image(systemName: "photo")
                                    .font(.system(size: 60))
                                    .foregroundColor(.secondary)

                                Text("No Photos")
                                    .font(.title2)
                                    .fontWeight(.bold)
                            }
                        }
                        .padding()
                    }
                }
            }
            .refreshable {
                await viewModel.loadPhotos()
            }

            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .padding()
                    .background(Material.ultraThickMaterial)
                    .cornerRadius(12)
            }
        }
        .navigationTitle("Tag")
        .task {
            await viewModel.loadPhotos()
        }
    }
}

// MARK: - ViewModels

@MainActor
class TagManagementViewModel: ObservableObject {
    @Published var tags: [String: Int] = [:]
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var showingRenameDialog = false
    @Published var tagToRename: String?
    @Published var newTagName = ""

    var sortedTags: [(key: String, value: Int)] {
        tags.sorted { $0.value > $1.value }
    }

    var totalPhotos: Int {
        Set(tags.keys).count > 0 ? tags.values.reduce(0, +) : 0
    }

    func loadTags() async {
        isLoading = true
        defer { isLoading = false }

        do {
            tags = try await TagManager.shared.getTagStatistics()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func startRenaming(_ tag: String) {
        tagToRename = tag
        newTagName = tag
        showingRenameDialog = true
    }

    func cancelRename() {
        tagToRename = nil
        newTagName = ""
        showingRenameDialog = false
    }

    func confirmRename() async {
        guard let oldTag = tagToRename else { return }

        do {
            try await TagManager.shared.renameTag(from: oldTag, to: newTagName)
            await loadTags()
            cancelRename()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func deleteTag(_ tag: String) {
        Task {
            do {
                try await TagManager.shared.deleteTag(tag)
                await loadTags()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

@MainActor
class TagDetailViewModel: ObservableObject {
    let tag: String

    @Published var photos: [EncryptedPhoto] = []
    @Published var isLoading = false

    init(tag: String) {
        self.tag = tag
    }

    func loadPhotos() async {
        isLoading = true
        defer { isLoading = false }

        do {
            photos = try await SearchManager.shared.getPhotosWithTag(tag)
        } catch {
            photos = []
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TagManagementView()
    }
}
