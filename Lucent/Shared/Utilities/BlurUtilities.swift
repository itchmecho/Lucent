//
//  BlurUtilities.swift
//  Lucent
//
//  Created by Claude Code on 11/23/24.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Blur Style

/// Defines the intensity of blur effects using design tokens
public enum BlurStyle {
    /// Subtle blur effect (10pt radius)
    case light

    /// Medium blur effect (40pt radius)
    case medium

    /// Heavy blur effect (60pt radius)
    case heavy

    /// Extra heavy blur effect (80pt radius)
    case extraHeavy

    /// Custom blur radius
    case custom(CGFloat)

    /// Returns the blur radius for this style
    var radius: CGFloat {
        switch self {
        case .light:
            return DesignTokens.BlurRadius.light
        case .medium:
            return DesignTokens.BlurRadius.medium
        case .heavy:
            return DesignTokens.BlurRadius.heavy
        case .extraHeavy:
            return DesignTokens.BlurRadius.extraHeavy
        case .custom(let radius):
            return radius
        }
    }

    /// Returns the corresponding Material for platform-native blur
    var material: Material {
        switch self {
        case .light:
            return DesignTokens.Materials.ultraThin
        case .medium:
            return DesignTokens.Materials.thin
        case .heavy:
            return DesignTokens.Materials.regular
        case .extraHeavy:
            return DesignTokens.Materials.thick
        case .custom:
            return DesignTokens.Materials.regular
        }
    }
}

// MARK: - SwiftUI View Modifiers

extension View {
    /// Applies a consistent glass blur effect to the view
    ///
    /// Example:
    /// ```swift
    /// Text("Hello")
    ///     .glassBlur(radius: 20, style: .medium)
    /// ```
    ///
    /// - Parameters:
    ///   - radius: Custom blur radius (overrides style if provided)
    ///   - style: Predefined blur style from design tokens
    /// - Returns: View with blur effect applied
    public func glassBlur(radius: CGFloat? = nil, style: BlurStyle = .medium) -> some View {
        let effectiveRadius = radius ?? style.radius
        return self.blur(radius: effectiveRadius)
    }

    /// Applies an animated blur effect that transitions on/off
    ///
    /// Example:
    /// ```swift
    /// Image("photo")
    ///     .animatedBlur(isActive: isBlurred)
    /// ```
    ///
    /// - Parameters:
    ///   - isActive: Whether the blur should be active
    ///   - style: The blur style to apply when active
    ///   - animation: The animation to use for the transition (default: .easeInOut)
    /// - Returns: View with animated blur effect
    public func animatedBlur(isActive: Bool, style: BlurStyle = .heavy, animation: Animation = .easeInOut) -> some View {
        self.blur(radius: isActive ? style.radius : 0)
            .animation(animation, value: isActive)
    }

    /// Applies a dynamic blur with variable intensity
    ///
    /// Example:
    /// ```swift
    /// Image("photo")
    ///     .dynamicBlur(intensity: scrollProgress)
    /// ```
    ///
    /// - Parameters:
    ///   - intensity: Blur intensity from 0.0 (no blur) to 1.0 (full blur)
    ///   - style: Maximum blur style at intensity 1.0
    /// - Returns: View with dynamic blur effect
    public func dynamicBlur(intensity: Double, style: BlurStyle = .heavy) -> some View {
        let clampedIntensity = max(0, min(1, intensity))
        let radius = style.radius * clampedIntensity
        return self.blur(radius: radius)
    }

    /// Applies a frosted glass background with material effect
    ///
    /// Example:
    /// ```swift
    /// VStack {
    ///     Text("Content")
    /// }
    /// .frostedBackground(style: .medium)
    /// ```
    ///
    /// - Parameters:
    ///   - style: Blur style determining material thickness
    ///   - tint: Optional color tint to apply over the blur
    ///   - opacity: Opacity of the tint color (0.0 to 1.0)
    /// - Returns: View with frosted glass background
    public func frostedBackground(
        style: BlurStyle = .medium,
        tint: Color? = nil,
        opacity: Double = 0.1
    ) -> some View {
        self.background {
            ZStack {
                Rectangle().fill(style.material)
                if let tint = tint {
                    tint.opacity(opacity)
                }
            }
        }
    }
}

// MARK: - Blur View Components

/// A reusable blur background view that adapts to the platform
///
/// Example:
/// ```swift
/// ZStack {
///     BlurView(style: .medium)
///     Text("Floating Content")
/// }
/// ```
public struct BlurView: View {
    let style: BlurStyle
    let tint: Color?
    let opacity: Double

    /// Creates a new blur view
    /// - Parameters:
    ///   - style: The blur intensity style
    ///   - tint: Optional color tint
    ///   - opacity: Opacity of the tint (default: 0.1)
    public init(style: BlurStyle = .medium, tint: Color? = nil, opacity: Double = 0.1) {
        self.style = style
        self.tint = tint
        self.opacity = opacity
    }

    public var body: some View {
        ZStack {
            #if canImport(UIKit)
            VisualEffectBlur(style: style)
            #elseif canImport(AppKit)
            MacVisualEffectBlur(style: style)
            #endif

            if let tint = tint {
                tint.opacity(opacity)
            }
        }
    }
}

// MARK: - Platform-Specific Blur Components

#if canImport(UIKit)
/// UIKit-based visual effect blur wrapper for iOS/iPadOS
private struct VisualEffectBlur: UIViewRepresentable {
    let style: BlurStyle

    func makeUIView(context: Context) -> UIVisualEffectView {
        let blurEffect = UIBlurEffect(style: uiBlurStyle)
        let view = UIVisualEffectView(effect: blurEffect)
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        return view
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: uiBlurStyle)
    }

    /// Maps BlurStyle to UIBlurEffect.Style
    private var uiBlurStyle: UIBlurEffect.Style {
        switch style {
        case .light:
            return .systemUltraThinMaterial
        case .medium:
            return .systemThinMaterial
        case .heavy:
            return .systemMaterial
        case .extraHeavy:
            return .systemThickMaterial
        case .custom:
            return .systemMaterial
        }
    }
}
#endif

#if canImport(AppKit)
/// AppKit-based visual effect blur wrapper for macOS
private struct MacVisualEffectBlur: NSViewRepresentable {
    let style: BlurStyle

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.autoresizingMask = [.width, .height]
        view.material = nsMaterial
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = nsMaterial
    }

    /// Maps BlurStyle to NSVisualEffectView.Material
    private var nsMaterial: NSVisualEffectView.Material {
        switch style {
        case .light:
            return .hudWindow
        case .medium:
            return .sidebar
        case .heavy:
            return .menu
        case .extraHeavy:
            return .popover
        case .custom:
            return .menu
        }
    }
}
#endif

// MARK: - Animated Blur Container

/// A container view that applies animated blur to its content
///
/// Example:
/// ```swift
/// AnimatedBlurContainer(isBlurred: $showBlur) {
///     Image("photo")
/// }
/// ```
public struct AnimatedBlurContainer<Content: View>: View {
    @Binding var isBlurred: Bool
    let style: BlurStyle
    let animation: Animation
    @ViewBuilder let content: () -> Content

    /// Creates an animated blur container
    /// - Parameters:
    ///   - isBlurred: Binding to control blur state
    ///   - style: Blur style when active
    ///   - animation: Animation for transitions
    ///   - content: Content to blur
    public init(
        isBlurred: Binding<Bool>,
        style: BlurStyle = .heavy,
        animation: Animation = .easeInOut(duration: 0.3),
        @ViewBuilder content: @escaping () -> Content
    ) {
        self._isBlurred = isBlurred
        self.style = style
        self.animation = animation
        self.content = content
    }

    public var body: some View {
        content()
            .blur(radius: isBlurred ? style.radius : 0)
            .animation(animation, value: isBlurred)
    }
}

// MARK: - Preview Helpers

#if DEBUG
struct BlurUtilities_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            // Static blur examples
            ZStack {
                LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                VStack(spacing: DesignTokens.Spacing.md) {
                    Text("Light Blur")
                        .font(.headline)

                    Text("This text has a light blur background")
                        .padding()
                        .background {
                            BlurView(style: .light)
                                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md))
                        }

                    Text("Heavy Blur")
                        .font(.headline)

                    Text("This text has a heavy blur background")
                        .padding()
                        .background {
                            BlurView(style: .heavy, tint: .white, opacity: 0.2)
                                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md))
                        }
                }
                .padding()
            }
            .frame(height: 300)

            // Frosted background example
            Text("Frosted Glass Card")
                .font(.title2)
                .foregroundColor(.white)
                .padding(DesignTokens.Spacing.xl)
                .frostedBackground(style: .medium, tint: .blue, opacity: 0.3)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.xl))
        }
        .padding()
        .previewDisplayName("Blur Utilities")
    }
}
#endif
