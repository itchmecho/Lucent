//
//  Animations.swift
//  Lucent
//
//  Created by Claude Code on 11/23/24.
//

import SwiftUI

/// Preset animations for consistent motion throughout the app
enum Animations {

    // MARK: - Spring Animations

    /// Quick spring animation for immediate feedback (0.25s)
    static let quickSpring = Animation.spring(response: 0.25, dampingFraction: 0.7)

    /// Standard spring animation for most interactions (0.3s)
    static let standardSpring = Animation.spring(response: 0.3, dampingFraction: 0.7)

    /// Smooth spring animation for gentle transitions (0.4s)
    static let smoothSpring = Animation.spring(response: 0.4, dampingFraction: 0.75)

    /// Bouncy spring animation for playful interactions (0.3s, low damping)
    static let bouncySpring = Animation.spring(response: 0.3, dampingFraction: 0.6)

    /// Gentle spring animation for backgrounds (0.5s)
    static let gentleSpring = Animation.spring(response: 0.5, dampingFraction: 0.8)

    // MARK: - Easing Animations

    /// Quick ease out (0.2s)
    static let quickEaseOut = Animation.easeOut(duration: 0.2)

    /// Standard ease in-out (0.3s)
    static let standardEaseInOut = Animation.easeInOut(duration: 0.3)

    /// Smooth ease in-out (0.4s)
    static let smoothEaseInOut = Animation.easeInOut(duration: 0.4)

    /// Slow ease in-out for dramatic effects (0.6s)
    static let slowEaseInOut = Animation.easeInOut(duration: 0.6)

    // MARK: - Linear Animations

    /// Fast linear (0.15s)
    static let fastLinear = Animation.linear(duration: 0.15)

    /// Standard linear (0.25s)
    static let standardLinear = Animation.linear(duration: 0.25)

    /// Slow linear (0.4s)
    static let slowLinear = Animation.linear(duration: 0.4)

    // MARK: - Preset Animation Values

    enum Duration {
        /// Instant (0.1s)
        static let instant: Double = 0.1

        /// Very fast (0.15s)
        static let veryFast: Double = 0.15

        /// Fast (0.2s)
        static let fast: Double = 0.2

        /// Quick (0.25s)
        static let quick: Double = 0.25

        /// Standard (0.3s)
        static let standard: Double = 0.3

        /// Medium (0.4s)
        static let medium: Double = 0.4

        /// Slow (0.5s)
        static let slow: Double = 0.5

        /// Very slow (0.6s)
        static let verySlow: Double = 0.6
    }

    enum SpringValues {
        /// Standard spring response
        static let response: Double = 0.3

        /// Bouncy spring response
        static let bouncyResponse: Double = 0.25

        /// Smooth spring response
        static let smoothResponse: Double = 0.4

        /// Standard damping
        static let damping: Double = 0.7

        /// Low damping for bouncy effect
        static let lowDamping: Double = 0.6

        /// High damping for smooth effect
        static let highDamping: Double = 0.8
    }

    // MARK: - Gesture Animations

    /// Animation for button press
    static let buttonPress = quickSpring

    /// Animation for card tap
    static let cardTap = standardSpring

    /// Animation for sheet presentation
    static let sheetPresentation = smoothSpring

    /// Animation for modal presentation
    static let modalPresentation = smoothEaseInOut

    /// Animation for navigation transitions
    static let navigationTransition = standardEaseInOut

    /// Animation for photo zoom
    static let photoZoom = smoothSpring

    /// Animation for slideshow transitions
    static let slideshowTransition = slowEaseInOut

    // MARK: - State Change Animations

    /// Animation for loading states
    static let loadingState = standardLinear.repeatForever(autoreverses: true)

    /// Animation for error shake
    static let errorShake = bouncySpring

    /// Animation for success pulse
    static let successPulse = standardSpring

    /// Animation for deletion
    static let deletion = quickEaseOut

    // MARK: - Transition Effects

    /// Fade transition
    nonisolated(unsafe) static let fade = AnyTransition.opacity.animation(standardEaseInOut)

    /// Scale transition
    nonisolated(unsafe) static let scale = AnyTransition.scale.animation(standardSpring)

    /// Slide transition
    nonisolated(unsafe) static let slide = AnyTransition.slide.animation(smoothSpring)

    /// Combined fade and scale
    nonisolated(unsafe) static let fadeScale = AnyTransition.scale.combined(with: .opacity).animation(standardSpring)

    /// Move transition from bottom
    nonisolated(unsafe) static let moveFromBottom = AnyTransition.move(edge: .bottom).animation(smoothSpring)

    /// Move transition from top
    nonisolated(unsafe) static let moveFromTop = AnyTransition.move(edge: .top).animation(smoothSpring)

    // MARK: - Custom Animation Modifiers

    /// Pulse animation for attention-grabbing elements
    static func pulse(scale: CGFloat = 1.05, duration: Double = 1.0) -> Animation {
        Animation.easeInOut(duration: duration).repeatForever(autoreverses: true)
    }

    /// Rotation animation for loading spinners
    static func rotate(duration: Double = 1.0) -> Animation {
        Animation.linear(duration: duration).repeatForever(autoreverses: false)
    }

    /// Delayed animation
    static func delayed(_ delay: Double, animation: Animation = standardSpring) -> Animation {
        animation.delay(delay)
    }
}

// MARK: - View Extension

extension View {
    /// Apply standard button animation
    func buttonAnimation() -> some View {
        self.animation(Animations.buttonPress, value: UUID())
    }

    /// Apply card tap animation
    func cardAnimation() -> some View {
        self.animation(Animations.cardTap, value: UUID())
    }

    /// Apply smooth transition animation
    func smoothTransition() -> some View {
        self.animation(Animations.smoothSpring, value: UUID())
    }
}
