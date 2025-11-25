//
//  PhotoDetailView.swift
//  Lucent
//
//  Created by Claude Code on 11/23/2024.
//

import SwiftUI
import os.log

/// Full-screen photo viewer with zoom, pan, and swipe navigation
struct PhotoDetailView: View {
    // MARK: - Properties

    let photo: EncryptedPhoto
    let allPhotos: [EncryptedPhoto]
    let onDismiss: () -> Void

    @State private var currentIndex: Int
    @State private var imageCache: [UUID: SecureImage] = [:]
    @State private var loadingImages: Set<UUID> = []
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var showingControls = true
    @State private var showingMetadata = false
    @State private var controlsTimer: Timer?

    // Dismiss gesture state
    @State private var dismissOffset: CGSize = .zero
    @State private var dismissOpacity: Double = 1.0
    @State private var isDraggingToDismiss = false

    // Entrance animation
    @State private var hasAppeared = false

    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 4.0

    // MARK: - Initialization

    init(photo: EncryptedPhoto, allPhotos: [EncryptedPhoto], onDismiss: @escaping () -> Void) {
        self.photo = photo
        self.allPhotos = allPhotos
        self.onDismiss = onDismiss
        _currentIndex = State(initialValue: allPhotos.firstIndex(where: { $0.id == photo.id }) ?? 0)
    }

    private var currentPhoto: EncryptedPhoto {
        guard currentIndex >= 0 && currentIndex < allPhotos.count else {
            return photo
        }
        return allPhotos[currentIndex]
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background - fades with dismiss gesture
            Color.black
                .opacity(dismissOpacity)
                .ignoresSafeArea()

            // Photo gallery with TabView for smooth paging
            galleryTabView
                .offset(dismissOffset)
                .scaleEffect(dismissOpacity < 1 ? 0.9 + (dismissOpacity * 0.1) : 1.0)
                .opacity(hasAppeared ? 1 : 0)
                .scaleEffect(hasAppeared ? 1 : 0.8)

            // Controls overlay
            if showingControls && !isDraggingToDismiss {
                controlsOverlay
                    .opacity(dismissOpacity)
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
        .gesture(dismissDragGesture)
        .task {
            // Entrance animation
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                hasAppeared = true
            }
            await loadImageForCurrentPhoto()
            resetControlsTimer()
        }
        .onChange(of: currentIndex) { _, _ in
            Task {
                await loadImageForCurrentPhoto()
            }
            resetZoom()
        }
        .sheet(isPresented: $showingMetadata) {
            PhotoMetadataView(photo: currentPhoto)
        }
        .onDisappear {
            // Securely wipe all cached images from memory
            for (_, image) in imageCache {
                image.wipe()
            }
            imageCache.removeAll()
            controlsTimer?.invalidate()
        }
    }

    // MARK: - Gallery TabView

    private var galleryTabView: some View {
        TabView(selection: $currentIndex) {
            ForEach(Array(allPhotos.enumerated()), id: \.element.id) { index, galleryPhoto in
                ZoomablePhotoView(
                    photo: galleryPhoto,
                    image: imageCache[galleryPhoto.id],
                    isLoading: loadingImages.contains(galleryPhoto.id),
                    scale: index == currentIndex ? $scale : .constant(1.0),
                    lastScale: index == currentIndex ? $lastScale : .constant(1.0),
                    offset: index == currentIndex ? $offset : .constant(.zero),
                    lastOffset: index == currentIndex ? $lastOffset : .constant(.zero),
                    minScale: minScale,
                    maxScale: maxScale,
                    onControlsToggle: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showingControls.toggle()
                        }
                        resetControlsTimer()
                    }
                )
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentIndex)
    }

    // MARK: - View Components

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
                Text("\(currentIndex + 1) of \(allPhotos.count)")
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

    // MARK: - Dismiss Gesture

    private var dismissDragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                // Only allow vertical dismiss when not zoomed
                guard scale <= 1.0 else { return }

                // Check if this is primarily a vertical drag
                let isVerticalDrag = abs(value.translation.height) > abs(value.translation.width)
                guard isVerticalDrag else { return }

                isDraggingToDismiss = true
                dismissOffset = CGSize(width: 0, height: value.translation.height)

                // Calculate opacity based on drag distance
                let progress = min(abs(value.translation.height) / 300, 1.0)
                dismissOpacity = 1.0 - (progress * 0.5)
            }
            .onEnded { value in
                let velocity = value.predictedEndTranslation.height - value.translation.height
                let shouldDismiss = abs(value.translation.height) > 150 || abs(velocity) > 500

                if shouldDismiss {
                    // Animate out and dismiss
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        dismissOffset = CGSize(width: 0, height: value.translation.height > 0 ? 500 : -500)
                        dismissOpacity = 0
                    }
                    // Delay dismiss to allow animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        onDismiss()
                    }
                } else {
                    // Spring back
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        dismissOffset = .zero
                        dismissOpacity = 1.0
                        isDraggingToDismiss = false
                    }
                }
            }
    }

    // MARK: - Navigation

    private var canNavigatePrevious: Bool {
        currentIndex > 0
    }

    private var canNavigateNext: Bool {
        currentIndex < allPhotos.count - 1
    }

    private func navigateToPrevious() {
        guard canNavigatePrevious else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            currentIndex -= 1
        }
    }

    private func navigateToNext() {
        guard canNavigateNext else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            currentIndex += 1
        }
    }

    private func resetZoom() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            scale = 1.0
            lastScale = 1.0
            offset = .zero
            lastOffset = .zero
        }
    }

    // MARK: - Image Loading

    private func loadImageForCurrentPhoto() async {
        let photoToLoad = currentPhoto

        // Skip if already loaded or loading
        guard imageCache[photoToLoad.id] == nil && !loadingImages.contains(photoToLoad.id) else {
            return
        }

        loadingImages.insert(photoToLoad.id)

        do {
            var photoData = try await SecurePhotoStorage.shared.retrievePhoto(id: photoToLoad.id)

            if let secureImage = SecureImage(data: photoData) {
                await MainActor.run {
                    imageCache[photoToLoad.id] = secureImage
                }
            }

            photoData.secureWipe()
        } catch {
            AppLogger.storage.error("Failed to load photo: \(error.localizedDescription, privacy: .public)")
        }

        loadingImages.remove(photoToLoad.id)

        // Preload adjacent photos for smooth swiping
        await preloadAdjacentPhotos()
    }

    private func preloadAdjacentPhotos() async {
        // Preload previous
        if currentIndex > 0 {
            let prevPhoto = allPhotos[currentIndex - 1]
            if imageCache[prevPhoto.id] == nil && !loadingImages.contains(prevPhoto.id) {
                loadingImages.insert(prevPhoto.id)
                if let data = try? await SecurePhotoStorage.shared.retrievePhoto(id: prevPhoto.id),
                   let image = SecureImage(data: data) {
                    await MainActor.run {
                        imageCache[prevPhoto.id] = image
                    }
                }
                loadingImages.remove(prevPhoto.id)
            }
        }

        // Preload next
        if currentIndex < allPhotos.count - 1 {
            let nextPhoto = allPhotos[currentIndex + 1]
            if imageCache[nextPhoto.id] == nil && !loadingImages.contains(nextPhoto.id) {
                loadingImages.insert(nextPhoto.id)
                if let data = try? await SecurePhotoStorage.shared.retrievePhoto(id: nextPhoto.id),
                   let image = SecureImage(data: data) {
                    await MainActor.run {
                        imageCache[nextPhoto.id] = image
                    }
                }
                loadingImages.remove(nextPhoto.id)
            }
        }
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

// MARK: - Zoomable Photo View

/// Individual photo view with pinch-to-zoom and double-tap zoom
struct ZoomablePhotoView: View {
    let photo: EncryptedPhoto
    let image: SecureImage?
    let isLoading: Bool
    @Binding var scale: CGFloat
    @Binding var lastScale: CGFloat
    @Binding var offset: CGSize
    @Binding var lastOffset: CGSize
    let minScale: CGFloat
    let maxScale: CGFloat
    let onControlsToggle: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if isLoading {
                    loadingView
                } else if let secureImage = image, let platformImage = secureImage.getImage() {
                    imageContent(platformImage, geometry: geometry)
                } else {
                    placeholderView
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
            Text("Loading...")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private var placeholderView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo")
                .font(.system(size: 64))
                .foregroundStyle(.white.opacity(0.3))
            Text("Unable to load photo")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    @ViewBuilder
    private func imageContent(_ platformImage: PlatformImage, geometry: GeometryProxy) -> some View {
        #if canImport(UIKit)
        Image(uiImage: platformImage)
            .resizable()
            .scaledToFit()
            .frame(width: geometry.size.width, height: geometry.size.height)
            .scaleEffect(scale)
            .offset(offset)
            .gesture(magnificationGesture)
            .gesture(dragGesture)
            .gesture(doubleTapGesture)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: scale)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: offset)
        #elseif canImport(AppKit)
        Image(nsImage: platformImage)
            .resizable()
            .scaledToFit()
            .frame(width: geometry.size.width, height: geometry.size.height)
            .scaleEffect(scale)
            .offset(offset)
            .gesture(magnificationGesture)
            .gesture(dragGesture)
            .gesture(doubleTapGesture)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: scale)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: offset)
        #endif
    }

    // MARK: - Gestures

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let delta = value / lastScale
                lastScale = value
                let newScale = scale * delta
                scale = min(max(newScale, minScale), maxScale)

                if scale <= minScale {
                    offset = .zero
                    lastOffset = .zero
                }
            }
            .onEnded { _ in
                lastScale = 1.0
                if scale < minScale * 1.1 {
                    scale = minScale
                    offset = .zero
                    lastOffset = .zero
                }
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if scale > 1.0 {
                    offset = CGSize(
                        width: lastOffset.width + value.translation.width,
                        height: lastOffset.height + value.translation.height
                    )
                }
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }

    private var doubleTapGesture: some Gesture {
        TapGesture(count: 2)
            .onEnded {
                if scale > 1.0 {
                    scale = 1.0
                    offset = .zero
                    lastOffset = .zero
                } else {
                    scale = 2.5
                }
                onControlsToggle()
            }
    }
}

// MARK: - Preview

#Preview {
    PhotoDetailView(
        photo: EncryptedPhoto(
            metadata: PhotoMetadata(fileSize: 1024)
        ),
        allPhotos: [],
        onDismiss: {}
    )
}
