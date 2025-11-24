//
//  SlideshowView.swift
//  Lucent
//
//  Created by Claude Code on 11/23/2024.
//

import SwiftUI
import os.log

/// Full-screen slideshow with automatic transitions
struct SlideshowView: View {
    // MARK: - Properties

    let photos: [EncryptedPhoto]
    let startIndex: Int
    let onDismiss: () -> Void

    @State private var currentIndex: Int
    @State private var currentImage: PlatformImage?
    @State private var isPlaying = true
    @State private var showingControls = true
    @State private var transitionInterval: TimeInterval = 3.0
    @State private var slideTimer: Timer?
    @State private var controlsTimer: Timer?
    @State private var transitionEffect: TransitionEffect = .fade

    private let storage = SecurePhotoStorage.shared

    // MARK: - Transition Effects

    enum TransitionEffect: String, CaseIterable, Identifiable {
        case fade = "Fade"
        case slide = "Slide"
        case scale = "Scale"

        var id: String { rawValue }
    }

    // MARK: - Initialization

    init(photos: [EncryptedPhoto], startIndex: Int = 0, onDismiss: @escaping () -> Void) {
        self.photos = photos
        self.startIndex = startIndex
        self.onDismiss = onDismiss
        _currentIndex = State(initialValue: startIndex)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Current photo
            if let image = currentImage {
                imageView(image)
            } else {
                loadingView
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
            if isPlaying {
                startSlideTimer()
            }
            resetControlsTimer()
        }
        .onDisappear {
            stopSlideTimer()
            controlsTimer?.invalidate()
            // Clear image from memory for security
            currentImage = nil
        }
    }

    // MARK: - View Components

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
            Text("Loading slideshow...")
                .foregroundStyle(.white)
        }
    }

    @ViewBuilder
    private func imageView(_ image: PlatformImage) -> some View {
        #if canImport(UIKit)
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .transition(currentTransition)
        #elseif canImport(AppKit)
        Image(nsImage: image)
            .resizable()
            .scaledToFit()
            .transition(currentTransition)
        #endif
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

                // Settings menu
                Menu {
                    // Play/pause
                    Button {
                        togglePlayPause()
                    } label: {
                        Label(isPlaying ? "Pause" : "Play", systemImage: isPlaying ? "pause.fill" : "play.fill")
                    }

                    Divider()

                    // Transition effect
                    Menu("Transition Effect") {
                        ForEach(TransitionEffect.allCases) { effect in
                            Button {
                                transitionEffect = effect
                            } label: {
                                Label(effect.rawValue, systemImage: transitionEffect == effect ? "checkmark" : "")
                            }
                        }
                    }

                    // Speed
                    Menu("Speed") {
                        Button {
                            transitionInterval = 2.0
                            restartSlideTimer()
                        } label: {
                            Label("Fast (2s)", systemImage: transitionInterval == 2.0 ? "checkmark" : "")
                        }

                        Button {
                            transitionInterval = 3.0
                            restartSlideTimer()
                        } label: {
                            Label("Normal (3s)", systemImage: transitionInterval == 3.0 ? "checkmark" : "")
                        }

                        Button {
                            transitionInterval = 5.0
                            restartSlideTimer()
                        } label: {
                            Label("Slow (5s)", systemImage: transitionInterval == 5.0 ? "checkmark" : "")
                        }
                    }
                } label: {
                    Image(systemName: "gear")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(.ultraThinMaterial.opacity(0.8))
                        .clipShape(Circle())
                }
            }
            .padding()

            Spacer()

            // Bottom controls
            VStack(spacing: 16) {
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.white.opacity(0.3))
                            .frame(height: 4)

                        Capsule()
                            .fill(.white)
                            .frame(width: geometry.size.width * progress, height: 4)
                    }
                }
                .frame(height: 4)
                .padding(.horizontal)

                // Navigation controls
                HStack(spacing: 32) {
                    // Previous
                    Button {
                        navigateToPrevious()
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(.ultraThinMaterial.opacity(0.8))
                            .clipShape(Circle())
                    }
                    .disabled(currentIndex == 0)

                    // Play/pause
                    Button {
                        togglePlayPause()
                    } label: {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                            .padding(16)
                            .background(.ultraThinMaterial.opacity(0.8))
                            .clipShape(Circle())
                    }

                    // Next
                    Button {
                        navigateToNext()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(.ultraThinMaterial.opacity(0.8))
                            .clipShape(Circle())
                    }
                    .disabled(currentIndex == photos.count - 1)
                }

                // Photo counter
                Text("\(currentIndex + 1) of \(photos.count)")
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial.opacity(0.8))
                    .clipShape(Capsule())
            }
            .padding(.bottom, 32)
        }
        .transition(.opacity)
    }

    // MARK: - Computed Properties

    private var currentTransition: AnyTransition {
        switch transitionEffect {
        case .fade:
            return .opacity
        case .slide:
            return .slide
        case .scale:
            return .scale.combined(with: .opacity)
        }
    }

    private var progress: CGFloat {
        guard !photos.isEmpty else { return 0 }
        return CGFloat(currentIndex) / CGFloat(photos.count - 1)
    }

    // MARK: - Navigation

    private func navigateToPrevious() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
        Task {
            await loadCurrentImage()
        }
        restartSlideTimer()
        resetControlsTimer()
    }

    private func navigateToNext() {
        if currentIndex < photos.count - 1 {
            currentIndex += 1
            Task {
                await loadCurrentImage()
            }
        } else {
            // Loop back to start
            currentIndex = 0
            Task {
                await loadCurrentImage()
            }
        }
        restartSlideTimer()
        resetControlsTimer()
    }

    // MARK: - Playback Control

    private func togglePlayPause() {
        isPlaying.toggle()
        if isPlaying {
            startSlideTimer()
        } else {
            stopSlideTimer()
        }
        resetControlsTimer()
    }

    private func startSlideTimer() {
        slideTimer = Timer.scheduledTimer(withTimeInterval: transitionInterval, repeats: true) { _ in
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.5)) {
                    self.navigateToNext()
                }
            }
        }
    }

    private func stopSlideTimer() {
        slideTimer?.invalidate()
        slideTimer = nil
    }

    private func restartSlideTimer() {
        if isPlaying {
            stopSlideTimer()
            startSlideTimer()
        }
    }

    // MARK: - Image Loading

    private func loadCurrentImage() async {
        guard currentIndex < photos.count else { return }

        let photo = photos[currentIndex]

        do {
            // Load and decrypt the full photo
            let photoData = try await storage.retrievePhoto(id: photo.id)

            // Create platform image
            if let image = PlatformImage.from(data: photoData) {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        currentImage = image
                    }
                }
            }
        } catch {
            AppLogger.storage.error("Failed to load photo for slideshow: \(error.localizedDescription, privacy: .public)")
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

// MARK: - Preview

#Preview {
    SlideshowView(
        photos: [
            EncryptedPhoto(
                encryptedFileURL: URL(fileURLWithPath: "/tmp/test1.enc"),
                metadata: PhotoMetadata(fileSize: 1024)
            ),
            EncryptedPhoto(
                encryptedFileURL: URL(fileURLWithPath: "/tmp/test2.enc"),
                metadata: PhotoMetadata(fileSize: 2048)
            )
        ],
        onDismiss: {}
    )
}
