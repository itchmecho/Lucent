//
//  CameraView.swift
//  Lucent
//
//  Created by Claude Code on 11/23/2024.
//

import SwiftUI
import AVFoundation
import os.log

#if canImport(UIKit)
import UIKit

/// SwiftUI wrapper for UIImagePickerController camera
struct CameraView: UIViewControllerRepresentable {
    // MARK: - Properties

    /// Callback when photo is captured
    var onPhotoCaptured: (Data) -> Void

    /// Callback when camera is dismissed
    var onDismiss: () -> Void

    // MARK: - Coordinator

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView

        init(_ parent: CameraView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage,
               let imageData = image.jpegData(compressionQuality: 0.9) {
                parent.onPhotoCaptured(imageData)
            }
            parent.onDismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onDismiss()
        }
    }

    // MARK: - UIViewControllerRepresentable

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.cameraDevice = .rear
        picker.delegate = context.coordinator

        // Enable camera controls
        picker.showsCameraControls = true

        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // No updates needed
    }
}

#endif

// MARK: - Camera Button with Liquid Glass Design

/// Wrapper to make Data identifiable for sheet presentation
private struct IdentifiableImageData: Identifiable {
    let id = UUID()
    let data: Data
}

struct CameraButton: View {
    @StateObject private var importManager = PhotoImportManager()
    @State private var showingCamera = false
    @State private var showingPermissionAlert = false
    @State private var capturedImageDataForImport: IdentifiableImageData?

    var onImportComplete: (EncryptedPhoto) -> Void = { _ in }

    var body: some View {
        Button(action: {
            checkPermissionAndShowCamera()
        }) {
            HStack(spacing: 12) {
                Image(systemName: "camera.fill")
                    .font(.title2)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Take Photo")
                        .font(.headline)

                    Text("Capture directly with camera")
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
        .sheet(isPresented: $showingCamera) {
            CameraView(
                onPhotoCaptured: { imageData in
                    handlePhotoCaptured(imageData)
                },
                onDismiss: {
                    showingCamera = false
                }
            )
            .ignoresSafeArea()
        }
        #endif
        .sheet(item: $capturedImageDataForImport) { imageDataWrapper in
            ImportProgressView(importManager: importManager) {
                capturedImageDataForImport = nil
            }
            .onAppear {
                importCapturedPhoto(imageDataWrapper.data)
            }
        }
        .alert("Camera Access Required", isPresented: $showingPermissionAlert) {
            Button("Settings", role: .none) {
                openSettings()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Lucent needs access to your camera to take photos. Please grant permission in Settings.")
        }
    }

    // MARK: - Private Methods

    private func checkPermissionAndShowCamera() {
        #if canImport(UIKit)
        // Check if camera is available
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            // Device doesn't have a camera (like simulator)
            return
        }

        Task {
            let status = AVCaptureDevice.authorizationStatus(for: .video)

            switch status {
            case .authorized:
                await MainActor.run {
                    showingCamera = true
                }
            case .notDetermined:
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                await MainActor.run {
                    if granted {
                        showingCamera = true
                    } else {
                        showingPermissionAlert = true
                    }
                }
            case .denied, .restricted:
                await MainActor.run {
                    showingPermissionAlert = true
                }
            @unknown default:
                await MainActor.run {
                    showingPermissionAlert = true
                }
            }
        }
        #endif
    }

    private func handlePhotoCaptured(_ imageData: Data) {
        // Delay showing progress sheet to allow camera dismissal to complete
        // This prevents "view not in window hierarchy" presentation conflicts
        Task { @MainActor in
            // Wait for camera sheet to fully dismiss (0.6s is standard sheet animation)
            try? await Task.sleep(nanoseconds: 600_000_000) // 0.6 seconds
            // Using item binding ensures the data is available when sheet presents
            capturedImageDataForImport = IdentifiableImageData(data: imageData)
        }
    }

    private func importCapturedPhoto(_ imageData: Data) {
        Task {
            do {
                let photo = try await importManager.importSinglePhoto(
                    imageData: imageData,
                    filename: "Camera_\(Date().formatted(date: .numeric, time: .omitted)).jpg"
                )
                await MainActor.run {
                    onImportComplete(photo)
                }
            } catch {
                AppLogger.importExport.error("Import error: \(error.localizedDescription, privacy: .public)")
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

// MARK: - Camera Permission Helper

extension CameraButton {
    /// Checks if camera access is authorized
    static func checkCameraPermission() -> AVAuthorizationStatus {
        return AVCaptureDevice.authorizationStatus(for: .video)
    }

    /// Requests camera access
    static func requestCameraPermission() async -> Bool {
        return await AVCaptureDevice.requestAccess(for: .video)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        CameraButton { photo in
            print("Captured and imported photo: \(photo.id)")
        }
    }
    .padding()
}
