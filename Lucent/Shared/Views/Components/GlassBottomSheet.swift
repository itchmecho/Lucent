//
//  GlassBottomSheet.swift
//  Lucent
//
//  Created by Claude Code on 11/23/24.
//

import SwiftUI

/// Height detent options for the bottom sheet
enum GlassBottomSheetDetent {
    case small      // 25% of screen
    case medium     // 50% of screen
    case large      // 75% of screen
    case custom(CGFloat)  // Custom height

    func height(for screenHeight: CGFloat) -> CGFloat {
        switch self {
        case .small:
            return screenHeight * 0.25
        case .medium:
            return screenHeight * 0.5
        case .large:
            return screenHeight * 0.75
        case .custom(let height):
            return height
        }
    }
}

/// A custom bottom sheet with liquid glass aesthetic
/// Supports drag gestures, multiple detents, and smooth animations
struct GlassBottomSheet<Content: View>: View {

    // MARK: - Properties

    /// Whether the sheet is currently presented
    @Binding var isPresented: Bool

    /// Available detents for the sheet
    var detents: [GlassBottomSheetDetent]

    /// Currently selected detent (defaults to first in array)
    @State private var currentDetent: GlassBottomSheetDetent

    /// Whether to show backdrop blur
    var showBackdrop: Bool

    /// Whether to allow dismiss on drag down
    var allowsDismiss: Bool

    /// Content of the bottom sheet
    let content: Content

    // MARK: - Drag State

    @State private var dragOffset: CGFloat = 0
    @GestureState private var isDragging = false

    // MARK: - Computed Properties

    /// Calculate the sheet height based on current detent
    private func sheetHeight(for detent: GlassBottomSheetDetent, screenHeight: CGFloat) -> CGFloat {
        detent.height(for: screenHeight)
    }

    /// Minimum drag distance to trigger dismissal
    private let dismissThreshold: CGFloat = 100

    /// Minimum velocity to trigger snap to next detent
    private let snapVelocityThreshold: CGFloat = 500

    // MARK: - Initialization

    init(
        isPresented: Binding<Bool>,
        detents: [GlassBottomSheetDetent] = [.medium],
        showBackdrop: Bool = true,
        allowsDismiss: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self._isPresented = isPresented
        self.detents = detents
        self._currentDetent = State(initialValue: detents.first ?? .medium)
        self.showBackdrop = showBackdrop
        self.allowsDismiss = allowsDismiss
        self.content = content()
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Backdrop
                if isPresented && showBackdrop {
                    Color.black
                        .opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            if allowsDismiss {
                                dismissSheet()
                            }
                        }
                        .transition(.opacity)
                }

                // Bottom sheet
                if isPresented {
                    VStack(spacing: 0) {
                        // Handle indicator
                        handleIndicator

                        // Content
                        content
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(height: sheetHeight(for: currentDetent, screenHeight: geometry.size.height))
                    .background(
                        ZStack {
                            // Frosted glass background
                            Rectangle()
                                .fill(DesignTokens.Materials.ultraThick)
                                .ignoresSafeArea(edges: .bottom)

                            // Glass overlay for extra depth
                            Color.glassOverlay
                                .ignoresSafeArea(edges: .bottom)
                        }
                    )
                    .cornerRadius(DesignTokens.CornerRadius.xxl, corners: [.topLeft, .topRight])
                    .glassShadow(DesignTokens.Shadow.extraHeavy)
                    .offset(y: max(0, dragOffset))
                    .gesture(dragGesture(screenHeight: geometry.size.height))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(Animations.smoothSpring, value: isPresented)
            .animation(Animations.smoothSpring, value: dragOffset)
        }
    }

    // MARK: - Handle Indicator

    private var handleIndicator: some View {
        VStack(spacing: 0) {
            // Glass pill handle
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                .fill(Color.glassBorder)
                .frame(width: 40, height: 5)
                .padding(.top, DesignTokens.Spacing.md)
                .padding(.bottom, DesignTokens.Spacing.lg)
        }
    }

    // MARK: - Drag Gesture

    private func dragGesture(screenHeight: CGFloat) -> some Gesture {
        DragGesture()
            .updating($isDragging) { _, state, _ in
                state = true
            }
            .onChanged { value in
                // Only allow dragging down
                if value.translation.height > 0 {
                    dragOffset = value.translation.height
                }
            }
            .onEnded { value in
                handleDragEnd(
                    translation: value.translation.height,
                    velocity: value.predictedEndLocation.y - value.location.y,
                    screenHeight: screenHeight
                )
            }
    }

    // MARK: - Drag Handling

    private func handleDragEnd(translation: CGFloat, velocity: CGFloat, screenHeight: CGFloat) {
        // Dismiss if dragged down past threshold
        if allowsDismiss && (translation > dismissThreshold || velocity > snapVelocityThreshold) {
            dismissSheet()
            return
        }

        // Snap to next detent if there are multiple detents
        if detents.count > 1 {
            snapToNearestDetent(translation: translation, velocity: velocity, screenHeight: screenHeight)
        } else {
            // Reset to current position
            withAnimation(Animations.smoothSpring) {
                dragOffset = 0
            }
        }
    }

    private func snapToNearestDetent(translation: CGFloat, velocity: CGFloat, screenHeight: CGFloat) {
        let currentHeight = sheetHeight(for: currentDetent, screenHeight: screenHeight)
        let newHeight = currentHeight - translation

        // Find closest detent
        var closestDetent = currentDetent
        var minDistance: CGFloat = .infinity

        for detent in detents {
            let detentHeight = sheetHeight(for: detent, screenHeight: screenHeight)
            let distance = abs(detentHeight - newHeight)

            if distance < minDistance {
                minDistance = distance
                closestDetent = detent
            }
        }

        // Animate to new detent
        withAnimation(Animations.smoothSpring) {
            currentDetent = closestDetent
            dragOffset = 0
        }
    }

    // MARK: - Actions

    private func dismissSheet() {
        withAnimation(Animations.smoothSpring) {
            dragOffset = 0
            isPresented = false
        }
    }
}

// MARK: - View Modifier

extension View {
    /// Present a glass bottom sheet
    /// - Parameters:
    ///   - isPresented: Binding to control sheet presentation
    ///   - detents: Available height detents for the sheet
    ///   - showBackdrop: Whether to show backdrop blur
    ///   - allowsDismiss: Whether sheet can be dismissed by dragging
    ///   - content: The content to display in the sheet
    func glassBottomSheet<Content: View>(
        isPresented: Binding<Bool>,
        detents: [GlassBottomSheetDetent] = [.medium],
        showBackdrop: Bool = true,
        allowsDismiss: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        ZStack {
            self

            GlassBottomSheet(
                isPresented: isPresented,
                detents: detents,
                showBackdrop: showBackdrop,
                allowsDismiss: allowsDismiss,
                content: content
            )
        }
    }
}

// MARK: - Helper Extension

extension View {
    /// Apply corner radius to specific corners
    func cornerRadius(_ radius: CGFloat, corners: RectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

/// Cross-platform corner specification
struct RectCorner: OptionSet {
    let rawValue: Int

    static let topLeft = RectCorner(rawValue: 1 << 0)
    static let topRight = RectCorner(rawValue: 1 << 1)
    static let bottomLeft = RectCorner(rawValue: 1 << 2)
    static let bottomRight = RectCorner(rawValue: 1 << 3)

    static let allCorners: RectCorner = [.topLeft, .topRight, .bottomLeft, .bottomRight]
}

/// Custom shape for rounding specific corners
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: RectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let tl = corners.contains(.topLeft) ? radius : 0
        let tr = corners.contains(.topRight) ? radius : 0
        let bl = corners.contains(.bottomLeft) ? radius : 0
        let br = corners.contains(.bottomRight) ? radius : 0

        path.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        if tr > 0 {
            path.addArc(center: CGPoint(x: rect.maxX - tr, y: rect.minY + tr),
                       radius: tr,
                       startAngle: .degrees(-90),
                       endAngle: .degrees(0),
                       clockwise: false)
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        if br > 0 {
            path.addArc(center: CGPoint(x: rect.maxX - br, y: rect.maxY - br),
                       radius: br,
                       startAngle: .degrees(0),
                       endAngle: .degrees(90),
                       clockwise: false)
        }
        path.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        if bl > 0 {
            path.addArc(center: CGPoint(x: rect.minX + bl, y: rect.maxY - bl),
                       radius: bl,
                       startAngle: .degrees(90),
                       endAngle: .degrees(180),
                       clockwise: false)
        }
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        if tl > 0 {
            path.addArc(center: CGPoint(x: rect.minX + tl, y: rect.minY + tl),
                       radius: tl,
                       startAngle: .degrees(180),
                       endAngle: .degrees(270),
                       clockwise: false)
        }
        path.closeSubpath()

        return path
    }
}

// MARK: - Preview

#Preview("Basic Bottom Sheet") {
    struct BottomSheetDemo: View {
        @State private var showSheet = false

        var body: some View {
            ZStack {
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

                VStack {
                    Spacer()

                    Button(action: {
                        showSheet = true
                    }) {
                        Text("Show Bottom Sheet")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(DesignTokens.Materials.thin)
                            .cornerRadius(DesignTokens.CornerRadius.md)
                            .glassShadow()
                    }

                    Spacer()
                }
            }
            .glassBottomSheet(isPresented: $showSheet) {
                VStack(spacing: DesignTokens.Spacing.lg) {
                    Text("Bottom Sheet")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Drag down to dismiss")
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)

                    Spacer()
                }
                .padding()
            }
        }
    }

    return BottomSheetDemo()
}

#Preview("Multi-Detent Bottom Sheet") {
    struct MultiDetentDemo: View {
        @State private var showSheet = false

        var body: some View {
            ZStack {
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

                VStack {
                    Spacer()

                    Button(action: {
                        showSheet = true
                    }) {
                        Text("Show Multi-Detent Sheet")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(DesignTokens.Materials.thin)
                            .cornerRadius(DesignTokens.CornerRadius.md)
                            .glassShadow()
                    }

                    Spacer()
                }
            }
            .glassBottomSheet(
                isPresented: $showSheet,
                detents: [.small, .medium, .large]
            ) {
                ScrollView {
                    VStack(spacing: DesignTokens.Spacing.lg) {
                        Text("Scrollable Content")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Drag to snap between small, medium, and large heights")
                            .font(.subheadline)
                            .foregroundColor(.textSecondary)
                            .multilineTextAlignment(.center)

                        ForEach(0..<10) { index in
                            GlassCard {
                                HStack {
                                    Image(systemName: "photo.fill")
                                        .foregroundColor(.lucentPrimary)
                                    Text("Item \(index + 1)")
                                        .font(.headline)
                                    Spacer()
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
    }

    return MultiDetentDemo()
}

#Preview("Photo Actions Sheet") {
    struct PhotoActionsDemo: View {
        @State private var showSheet = false

        var body: some View {
            ZStack {
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

                VStack {
                    // Mock photo
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg)
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 200, height: 200)
                        .glassShadow()
                        .onTapGesture {
                            showSheet = true
                        }

                    Text("Tap photo to show actions")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                        .padding(.top)
                }
            }
            .glassBottomSheet(
                isPresented: $showSheet,
                detents: [.small]
            ) {
                VStack(spacing: DesignTokens.Spacing.lg) {
                    Text("Photo Actions")
                        .font(.headline)
                        .foregroundColor(.textSecondary)

                    VStack(spacing: DesignTokens.Spacing.sm) {
                        actionButton(icon: "square.and.arrow.up", title: "Share", color: .blue)
                        actionButton(icon: "heart", title: "Favorite", color: .pink)
                        actionButton(icon: "folder", title: "Move to Album", color: .purple)
                        actionButton(icon: "tag", title: "Add Tags", color: .orange)
                        actionButton(icon: "trash", title: "Delete", color: .red)
                    }
                }
                .padding()
            }
        }

        private func actionButton(icon: String, title: String, color: Color) -> some View {
            Button(action: {}) {
                HStack(spacing: DesignTokens.Spacing.md) {
                    Image(systemName: icon)
                        .font(.system(size: DesignTokens.IconSize.md))
                        .foregroundColor(color)
                        .frame(width: DesignTokens.IconSize.xl)

                    Text(title)
                        .font(.body)
                        .foregroundColor(.textPrimary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: DesignTokens.IconSize.sm))
                        .foregroundColor(.textSecondary)
                }
                .padding()
                .background(DesignTokens.Materials.ultraThin)
                .cornerRadius(DesignTokens.CornerRadius.md)
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    return PhotoActionsDemo()
}
