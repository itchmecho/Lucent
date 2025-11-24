//
//  FrostedNavigationBar.swift
//  Lucent
//
//  Created by Claude Code on 11/23/24.
//

import SwiftUI

/// A custom navigation bar with frosted glass effect that intensifies on scroll
/// Perfect for liquid glass aesthetic with translucent backgrounds and smooth animations
struct FrostedNavigationBar<Leading: View, Trailing: View>: View {

    // MARK: - Properties

    /// The main title text
    let title: String

    /// Optional subtitle text
    var subtitle: String?

    /// Leading button (e.g., back button, menu)
    var leadingButton: (() -> Leading)?

    /// Trailing button (e.g., settings, actions)
    var trailingButton: (() -> Trailing)?

    /// Scroll offset for blur intensity effect (0 = no scroll, increases with scroll)
    var scrollOffset: CGFloat = 0

    /// Whether to show the separator line
    var showSeparator: Bool = false

    // MARK: - Computed Properties

    /// Calculate blur intensity based on scroll offset
    private var blurIntensity: Material {
        if scrollOffset > 50 {
            return DesignTokens.Materials.thick
        } else if scrollOffset > 20 {
            return DesignTokens.Materials.regular
        } else {
            return DesignTokens.Materials.ultraThin
        }
    }

    /// Calculate opacity for title based on scroll
    private var titleOpacity: Double {
        min(1.0, Double(scrollOffset) / 50.0)
    }

    // MARK: - Initialization

    init(
        title: String,
        subtitle: String? = nil,
        scrollOffset: CGFloat = 0,
        showSeparator: Bool = false,
        @ViewBuilder leadingButton: @escaping () -> Leading,
        @ViewBuilder trailingButton: @escaping () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.scrollOffset = scrollOffset
        self.showSeparator = showSeparator
        self.leadingButton = leadingButton
        self.trailingButton = trailingButton
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DesignTokens.Spacing.md) {
                // Leading button
                if let leadingButton = leadingButton {
                    leadingButton()
                        .frame(width: DesignTokens.ButtonSize.md, height: DesignTokens.ButtonSize.md)
                } else {
                    Spacer()
                        .frame(width: DesignTokens.ButtonSize.md)
                }

                // Title section
                VStack(spacing: DesignTokens.Spacing.xs) {
                    Text(title)
                        .font(.system(size: DesignTokens.FontSize.title3, weight: .bold))
                        .foregroundColor(.textOnGlass)
                        .opacity(titleOpacity)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: DesignTokens.FontSize.footnote))
                            .foregroundColor(.textSecondary)
                            .opacity(titleOpacity * 0.8)
                    }
                }
                .frame(maxWidth: .infinity)

                // Trailing button
                if let trailingButton = trailingButton {
                    trailingButton()
                        .frame(width: DesignTokens.ButtonSize.md, height: DesignTokens.ButtonSize.md)
                } else {
                    Spacer()
                        .frame(width: DesignTokens.ButtonSize.md)
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.vertical, DesignTokens.Spacing.md)

            // Optional separator
            if showSeparator {
                Divider()
                    .background(Color.glassBorder)
                    .opacity(titleOpacity)
            }
        }
        .background(blurIntensity)
        .animation(Animations.smoothSpring, value: scrollOffset)
    }
}

// MARK: - Convenience Initializers

extension FrostedNavigationBar where Leading == EmptyView, Trailing == EmptyView {
    /// Initialize with just a title, no buttons
    init(
        title: String,
        subtitle: String? = nil,
        scrollOffset: CGFloat = 0,
        showSeparator: Bool = false
    ) {
        self.title = title
        self.subtitle = subtitle
        self.scrollOffset = scrollOffset
        self.showSeparator = showSeparator
        self.leadingButton = nil
        self.trailingButton = nil
    }
}

extension FrostedNavigationBar where Trailing == EmptyView {
    /// Initialize with title and leading button only
    init(
        title: String,
        subtitle: String? = nil,
        scrollOffset: CGFloat = 0,
        showSeparator: Bool = false,
        @ViewBuilder leadingButton: @escaping () -> Leading
    ) {
        self.title = title
        self.subtitle = subtitle
        self.scrollOffset = scrollOffset
        self.showSeparator = showSeparator
        self.leadingButton = leadingButton
        self.trailingButton = nil
    }
}

extension FrostedNavigationBar where Leading == EmptyView {
    /// Initialize with title and trailing button only
    init(
        title: String,
        subtitle: String? = nil,
        scrollOffset: CGFloat = 0,
        showSeparator: Bool = false,
        @ViewBuilder trailingButton: @escaping () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.scrollOffset = scrollOffset
        self.showSeparator = showSeparator
        self.leadingButton = nil
        self.trailingButton = trailingButton
    }
}

// MARK: - Custom Navigation Buttons

/// Glass-styled back button
struct FrostedBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: DesignTokens.IconSize.md, weight: .semibold))
                .foregroundColor(.textOnGlass)
                .frame(width: DesignTokens.ButtonSize.md, height: DesignTokens.ButtonSize.md)
                .background(Color.glassOverlay)
                .background(DesignTokens.Materials.ultraThin)
                .clipShape(Circle())
                .glassShadow(DesignTokens.Shadow.light)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

/// Glass-styled icon button for navigation bar
struct FrostedIconButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: DesignTokens.IconSize.md, weight: .medium))
                .foregroundColor(.textOnGlass)
                .frame(width: DesignTokens.ButtonSize.md, height: DesignTokens.ButtonSize.md)
                .background(Color.glassOverlay)
                .background(DesignTokens.Materials.ultraThin)
                .clipShape(Circle())
                .glassShadow(DesignTokens.Shadow.light)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

/// Scale button style for interactive feedback
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .opacity(configuration.isPressed ? DesignTokens.Opacity.pressed : 1.0)
            .animation(Animations.quickSpring, value: configuration.isPressed)
    }
}

// MARK: - View Modifier

extension View {
    /// Apply a frosted navigation bar to any view
    /// - Parameters:
    ///   - title: The navigation bar title
    ///   - subtitle: Optional subtitle text
    ///   - scrollOffset: Current scroll offset to adjust blur
    ///   - showSeparator: Whether to show bottom separator
    ///   - leadingButton: Optional leading button view
    ///   - trailingButton: Optional trailing button view
    func frostedNavigationBar<Leading: View, Trailing: View>(
        title: String,
        subtitle: String? = nil,
        scrollOffset: CGFloat = 0,
        showSeparator: Bool = false,
        @ViewBuilder leadingButton: @escaping () -> Leading = { EmptyView() },
        @ViewBuilder trailingButton: @escaping () -> Trailing = { EmptyView() }
    ) -> some View {
        VStack(spacing: 0) {
            FrostedNavigationBar(
                title: title,
                subtitle: subtitle,
                scrollOffset: scrollOffset,
                showSeparator: showSeparator,
                leadingButton: leadingButton,
                trailingButton: trailingButton
            )

            self
        }
    }
}

// MARK: - Preview

#Preview("Basic Navigation Bar") {
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

        VStack(spacing: 0) {
            FrostedNavigationBar(
                title: "Photos",
                scrollOffset: 0
            )

            Spacer()
        }
    }
}

#Preview("Navigation Bar with Buttons") {
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

        VStack(spacing: 0) {
            FrostedNavigationBar(
                title: "Album",
                subtitle: "42 photos",
                scrollOffset: 0,
                showSeparator: true,
                leadingButton: {
                    FrostedBackButton(action: {})
                },
                trailingButton: {
                    FrostedIconButton(icon: "ellipsis.circle", action: {})
                }
            )

            Spacer()
        }
    }
}

#Preview("Navigation Bar Scroll Effect") {
    struct ScrollEffectDemo: View {
        @State private var scrollOffset: CGFloat = 0

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

                VStack(spacing: 0) {
                    FrostedNavigationBar(
                        title: "Gallery",
                        subtitle: "Scroll to see effect",
                        scrollOffset: scrollOffset,
                        showSeparator: true,
                        leadingButton: {
                            FrostedBackButton(action: {})
                        },
                        trailingButton: {
                            FrostedIconButton(icon: "slider.horizontal.3", action: {})
                        }
                    )

                    ScrollView {
                        LazyVStack(spacing: DesignTokens.Spacing.lg) {
                            ForEach(0..<20) { index in
                                GlassCard {
                                    Text("Item \(index + 1)")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding()
                                }
                                .padding(.horizontal)
                            }
                        }
                        .background(GeometryReader { geometry in
                            Color.clear.preference(
                                key: ScrollOffsetPreferenceKey.self,
                                value: geometry.frame(in: .named("scroll")).minY
                            )
                        })
                    }
                    .coordinateSpace(name: "scroll")
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                        scrollOffset = -value
                    }
                }
            }
        }
    }

    return ScrollEffectDemo()
}

// MARK: - Helper

/// Preference key for tracking scroll offset
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
