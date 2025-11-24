//
//  PhotoDetailView.swift
//  Lucent
//
//  Created by Claude Code on 11/23/2024.
//

import SwiftUI

/// Full-screen photo viewer with zoom, pan, and swipe navigation
struct PhotoDetailView: View {
    // MARK: - Properties

    let photo: EncryptedPhoto
    let allPhotos: [EncryptedPhoto]
    let onDismiss: () -> Void

    @State private var currentPhoto: EncryptedPhoto
    @State private var currentImage: PlatformImage?
    @State private var isLoadingImage = false
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var showingControls = true
    @State private var showingMetadata = false
    @State private var controlsTimer: Timer?

    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 4.0

    // MARK: - Initialization

    init(photo: EncryptedPhoto, allPhotos: [EncryptedPhoto], onDismiss: @escaping () -> Void) {
        self.photo = photo
        self.allPhotos = allPhotos
        self.onDismiss = onDismiss
        _currentPhoto = State(initialValue: photo)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isLoadingImage {
                loadingView
            } else if let image = currentImage {
                imageView(image)
            } else {
                placeholderView
            }

            // Controls overlay
            if showingControls {
                controlsOverlay
            }
        }
        #if canImport(UIKit)
        .statusBar(hidden: !showingControls)
        #endif
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                showingControls.toggle()
            }
            resetControlsTimer()
        }
        .task {
            await loadCurrentImage()
            resetControlsTimer()
        }
        .onChange(of: currentPhoto) { _, _ in
            Task {
                await loadCurrentImage()
            }
        }
        .sheet(isPresented: $showingMetadata) {
            PhotoMetadataView(photo: currentPhoto)
        }
        .onDisappear {
            // Clear image from memory for security
            currentImage = nil
            controlsTimer?.invalidate()
        }
        .gesture(
            magnificationGesture
                .simultaneously(with: dragGesture)
        )
    }

    // MARK: - View Components

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
            Text("Loading photo...")
                .foregroundStyle(.white)
        }
    }

    private var placeholderView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo")
                .font(.system(size: 64))
                .foregroundStyle(.white.opacity(0.5))
            Text("Unable to load photo")
                .foregroundStyle(.white)
        }
    }

    @ViewBuilder
    private func imageView(_ image: PlatformImage) -> some View {
        GeometryReader { geometry in
            #if canImport(UIKit)
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: geometry.size.width, height: geometry.size.height)
                .scaleEffect(scale)
                .offset(offset)
                .gesture(doubleTapGesture(in: geometry))
            #elseif canImport(AppKit)
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: geometry.size.width, height: geometry.size.height)
                .scaleEffect(scale)
                .offset(offset)
                .gesture(doubleTapGesture(in: geometry))
            #endif
        }
    }

    private var controlsOverlay: some View {
        VStack {
            // Top bar
            HStack {
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(.ultraThinMaterial.opacity(0.8))
                        .clipShape(Circle())
                }

                Spacer()

                HStack(spacing: 16) {
                    // Info button
                    Button {
                        showingMetadata = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(.ultraThinMaterial.opacity(0.8))
                            .clipShape(Circle())
                    }

                    // Share button
                    Button {
                        // TODO: Implement share
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(.ultraThinMaterial.opacity(0.8))
                            .clipShape(Circle())
                    }
                }
            }
            .padding()

            Spacer()

            // Bottom navigation
            HStack(spacing: 32) {
                // Previous button
                Button {
                    navigateToPrevious()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(.ultraThinMaterial.opacity(0.8))
                        .clipShape(Circle())
                }
                .disabled(!canNavigatePrevious)
                .opacity(canNavigatePrevious ? 1 : 0.3)

                // Photo counter
                Text("\(currentPhotoIndex + 1) of \(allPhotos.count)")
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial.opacity(0.8))
                    .clipShape(Capsule())

                // Next button
                Button {
                    navigateToNext()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(.ultraThinMaterial.opacity(0.8))
                        .clipShape(Circle())
                }
                .disabled(!canNavigateNext)
                .opacity(canNavigateNext ? 1 : 0.3)
            }
            .padding(.bottom, 32)
        }
        .transition(.opacity)
    }

    // MARK: - Gestures

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let delta = value / lastScale
                lastScale = value
                let newScale = scale * delta

                // Clamp scale
                scale = min(max(newScale, minScale), maxScale)

                // Reset offset when zooming out to 1.0
                if scale <= minScale {
                    offset = .zero
                    lastOffset = .zero
                }

                resetControlsTimer()
            }
            .onEnded { _ in
                lastScale = 1.0

                // Snap to min or current scale
                withAnimation(.spring(response: 0.3)) {
                    if scale < minScale * 1.1 {
                        scale = minScale
                        offset = .zero
                        lastOffset = .zero
                    }
                }
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                // Only allow drag when zoomed in
                if scale > 1.0 {
                    offset = CGSize(
                        width: lastOffset.width + value.translation.width,
                        height: lastOffset.height + value.translation.height
                    )
                }
                resetControlsTimer()
            }
            .onEnded { value in
                lastOffset = offset

                // Swipe to navigate when not zoomed
                if scale <= 1.0 {
                    let swipeThreshold: CGFloat = 50
                    if value.translation.width < -swipeThreshold {
                        navigateToNext()
                    } else if value.translation.width > swipeThreshold {
                        navigateToPrevious()
                    }
                }
            }
    }

    private func doubleTapGesture(in geometry: GeometryProxy) -> some Gesture {
        TapGesture(count: 2)
            .onEnded { _ in
                withAnimation(.spring(response: 0.3)) {
                    if scale > 1.0 {
                        // Zoom out
                        scale = 1.0
                        offset = .zero
                        lastOffset = .zero
                    } else {
                        // Zoom in to 2x
                        scale = 2.0
                    }
                }
                resetControlsTimer()
            }
    }

    // MARK: - Navigation

    private var currentPhotoIndex: Int {
        allPhotos.firstIndex(where: { $0.id == currentPhoto.id }) ?? 0
    }

    private var canNavigatePrevious: Bool {
        currentPhotoIndex > 0
    }

    private var canNavigateNext: Bool {
        currentPhotoIndex < allPhotos.count - 1
    }

    private func navigateToPrevious() {
        guard canNavigatePrevious else { return }
        withAnimation {
            currentPhoto = allPhotos[currentPhotoIndex - 1]
            resetZoom()
        }
    }

    private func navigateToNext() {
        guard canNavigateNext else { return }
        withAnimation {
            currentPhoto = allPhotos[currentPhotoIndex + 1]
            resetZoom()
        }
    }

    private func resetZoom() {
        scale = 1.0
        lastScale = 1.0
        offset = .zero
        lastOffset = .zero
    }

    // MARK: - Image Loading

    private func loadCurrentImage() async {
        isLoadingImage = true
        currentImage = nil

        do {
            // Load and decrypt the full photo
            let photoData = try await SecurePhotoStorage.shared.retrievePhoto(id: currentPhoto.id)

            // Create platform image
            if let image = PlatformImage.from(data: photoData) {
                await MainActor.run {
                    currentImage = image
                }
            }
        } catch {
            print("Failed to load photo: \(error.localizedDescription)")
        }

        isLoadingImage = false
    }

    // MARK: - Controls Timer

    private func resetControlsTimer() {
        controlsTimer?.invalidate()

        // Auto-hide controls after 3 seconds
        controlsTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.showingControls = false
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    PhotoDetailView(
        photo: EncryptedPhoto(
            encryptedFileURL: URL(fileURLWithPath: "/tmp/test.enc"),
            metadata: PhotoMetadata(fileSize: 1024)
        ),
        allPhotos: [],
        onDismiss: {}
    )
}
