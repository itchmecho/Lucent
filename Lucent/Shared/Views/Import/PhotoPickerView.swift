//
//  PhotoPickerView.swift
//  Lucent
//
//  Created by Claude Code on 11/23/2024.
//

import SwiftUI
import PhotosUI

#if canImport(UIKit)
import UIKit

/// SwiftUI wrapper for PHPickerViewController with liquid glass design
struct PhotoPickerView: UIViewControllerRepresentable {
    // MARK: - Properties

    /// Callback when photos are selected
    var onPhotosSelected: ([PHPickerResult]) -> Void

    /// Callback when picker is dismissed
    var onDismiss: () -> Void

    /// Maximum number of photos to select (nil = unlimited)
    var selectionLimit: Int?

    // MARK: - Coordinator

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPickerView

        init(_ parent: PhotoPickerView) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.onPhotosSelected(results)
            parent.onDismiss()
        }
    }

    // MARK: - UIViewControllerRepresentable

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())

        // Configure picker
        configuration.filter = .images // Only images, no videos
        configuration.preferredAssetRepresentationMode = .current
        configuration.selection = .ordered // Maintain selection order

        // Set selection limit
        if let limit = selectionLimit {
            configuration.selectionLimit = limit
        } else {
            configuration.selectionLimit = 0 // 0 = unlimited
        }

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator

        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {
        // No updates needed
    }
}

#endif

// MARK: - Photo Picker Button with Liquid Glass Design

struct PhotoPickerButton: View {
    @StateObject private var importManager = PhotoImportManager()
    @State private var showingPicker = false
    @State private var showingPermissionAlert = false
    @State private var showingImportProgress = false

    var selectionLimit: Int? = nil
    var onImportComplete: (PhotoImportManager.ImportResult) -> Void = { _ in }

    var body: some View {
        Button(action: {
            checkPermissionAndShowPicker()
        }) {
            HStack(spacing: 12) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.title2)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Import Photos")
                        .font(.headline)

                    Text(selectionLimit == 1 ? "Select a photo" : "Select photos from library")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
            }
        }
        .buttonStyle(.plain)
        #if canImport(UIKit)
        .sheet(isPresented: $showingPicker) {
            PhotoPickerView(
                onPhotosSelected: { results in
                    handlePhotoSelection(results)
                },
                onDismiss: {
                    showingPicker = false
                },
                selectionLimit: selectionLimit
            )
            .ignoresSafeArea()
        }
        #endif
        .sheet(isPresented: $showingImportProgress) {
            ImportProgressView(importManager: importManager) {
                showingImportProgress = false
            }
        }
        .alert("Photo Library Access Required", isPresented: $showingPermissionAlert) {
            Button("Settings", role: .none) {
                openSettings()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Lucent needs access to your photo library to import photos. Please grant permission in Settings.")
        }
    }

    // MARK: - Private Methods

    private func checkPermissionAndShowPicker() {
        Task {
            let status = await PhotoImportManager.requestPhotoLibraryPermission()

            await MainActor.run {
                switch status {
                case .authorized, .limited:
                    showingPicker = true
                case .denied, .restricted:
                    showingPermissionAlert = true
                case .notDetermined:
                    // Should not happen after requesting, but try again
                    checkPermissionAndShowPicker()
                @unknown default:
                    showingPermissionAlert = true
                }
            }
        }
    }

    private func handlePhotoSelection(_ results: [PHPickerResult]) {
        guard !results.isEmpty else { return }

        showingImportProgress = true

        Task {
            do {
                let result = try await importManager.importPhotos(from: results)
                await MainActor.run {
                    onImportComplete(result)
                }
            } catch {
                print("Import error: \(error)")
            }
        }
    }

    private func openSettings() {
        #if canImport(UIKit)
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
        #endif
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        PhotoPickerButton(selectionLimit: nil) { result in
            print("Imported \(result.successCount) photos")
        }

        PhotoPickerButton(selectionLimit: 1) { result in
            print("Imported single photo")
        }
    }
    .padding()
}
