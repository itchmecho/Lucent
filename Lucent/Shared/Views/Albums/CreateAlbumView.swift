//
//  CreateAlbumView.swift
//  Lucent
//
//  Created by Claude Code on 11/23/2024.
//

import SwiftUI

/// View for creating a new album with liquid glass aesthetic
struct CreateAlbumView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = CreateAlbumViewModel()

    private let themeColors: [Color] = [
        .red, .orange, .yellow, .green, .mint, .teal,
        .cyan, .blue, .indigo, .purple, .pink, .brown
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
                    VStack(spacing: 24) {
                        // Album name
                        GlassTextField(
                            title: "Album Name",
                            text: $viewModel.albumName,
                            placeholder: "Enter album name",
                            icon: "rectangle.stack"
                        )

                        // Description
                        GlassTextEditor(
                            title: "Description (Optional)",
                            text: $viewModel.albumDescription,
                            placeholder: "Enter a description for this album",
                            height: 100
                        )

                        // Theme color picker
                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Theme Color")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)

                                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12) {
                                    ForEach(themeColors, id: \.self) { color in
                                        Button(action: {
                                            viewModel.selectedColor = color
                                        }) {
                                            Circle()
                                                .fill(color)
                                                .frame(width: 44, height: 44)
                                                .overlay(
                                                    Circle()
                                                        .stroke(Color.white, lineWidth: viewModel.selectedColor == color ? 3 : 0)
                                                )
                                                .shadow(radius: 4)
                                        }
                                    }
                                }
                            }
                        }

                        // Preview
                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Preview")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)

                                AlbumPreviewCard(
                                    name: viewModel.albumName.isEmpty ? "Album Name" : viewModel.albumName,
                                    photoCount: 0,
                                    color: viewModel.selectedColor
                                )
                            }
                        }

                        Spacer(minLength: 40)
                    }
                    .padding()
                }

                // Loading overlay
                if viewModel.isCreating {
                    ProgressView()
                        .scaleEffect(1.5)
                        .padding()
                        .background(Material.ultraThickMaterial)
                        .cornerRadius(12)
                }
            }
            .navigationTitle("New Album")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            await viewModel.createAlbum()
                            if viewModel.albumCreated {
                                dismiss()
                            }
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(viewModel.albumName.isEmpty || viewModel.isCreating)
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }
}

/// Preview card showing how the album will look
struct AlbumPreviewCard: View {
    let name: String
    let photoCount: Int
    let color: Color?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Color preview
            ZStack {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: {
                                if let c = color {
                                    return [c, c.opacity(0.7)]
                                } else {
                                    return [.purple, .pink]
                                }
                            }(),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 120)
                    .overlay {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 36))
                            .foregroundColor(.white.opacity(0.8))
                    }
            }

            // Album info
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.headline)
                    .lineLimit(1)

                Text("\(photoCount) photo\(photoCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Material.thin)
        }
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

// MARK: - ViewModel

@MainActor
class CreateAlbumViewModel: ObservableObject {
    @Published var albumName = ""
    @Published var albumDescription = ""
    @Published var selectedColor: Color? = .blue
    @Published var isCreating = false
    @Published var albumCreated = false
    @Published var showError = false
    @Published var errorMessage = ""

    func createAlbum() async {
        isCreating = true
        defer { isCreating = false }

        do {
            let albumManager = AlbumManager.shared

            let themeColorHex = selectedColor?.toHex()

            _ = try await albumManager.createAlbum(
                name: albumName.trimmingCharacters(in: .whitespacesAndNewlines),
                description: albumDescription.isEmpty ? nil : albumDescription.trimmingCharacters(in: .whitespacesAndNewlines),
                themeColor: themeColorHex
            )

            albumCreated = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Color to Hex Extension

extension Color {
    func toHex() -> String? {
        #if canImport(UIKit)
        guard let components = UIColor(self).cgColor.components, components.count >= 3 else {
            return nil
        }
        #else
        guard let components = NSColor(self).cgColor.components, components.count >= 3 else {
            return nil
        }
        #endif

        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])

        return String(format: "#%02lX%02lX%02lX",
                     lroundf(r * 255),
                     lroundf(g * 255),
                     lroundf(b * 255))
    }
}

// MARK: - Preview

#Preview {
    CreateAlbumView()
}
