//
//  HapticManager.swift
//  Lucent
//
//  Created by Claude Code on 11/23/24.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Haptic Types

/// Defines impact haptic feedback intensities
public enum HapticImpact {
    /// Light impact feedback
    case light

    /// Medium impact feedback
    case medium

    /// Heavy impact feedback
    case heavy

    /// Soft impact feedback (iOS 13+)
    case soft

    /// Rigid impact feedback (iOS 13+)
    case rigid

    #if canImport(UIKit)
    /// Maps to UIImpactFeedbackGenerator.FeedbackStyle
    var feedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle {
        switch self {
        case .light:
            return .light
        case .medium:
            return .medium
        case .heavy:
            return .heavy
        case .soft:
            return .soft
        case .rigid:
            return .rigid
        }
    }
    #endif
}

/// Defines notification haptic feedback types
public enum HapticNotification {
    /// Success notification feedback
    case success

    /// Warning notification feedback
    case warning

    /// Error notification feedback
    case error

    #if canImport(UIKit)
    /// Maps to UINotificationFeedbackGenerator.FeedbackType
    var feedbackType: UINotificationFeedbackGenerator.FeedbackType {
        switch self {
        case .success:
            return .success
        case .warning:
            return .warning
        case .error:
            return .error
        }
    }
    #endif
}

// MARK: - Haptic Manager

/// Thread-safe haptic feedback manager with generator pooling
///
/// Provides a unified API for haptic feedback across iOS/iPadOS/macOS.
/// On macOS, all haptic calls are no-ops as the platform doesn't support haptics.
///
/// Example:
/// ```swift
/// // Impact feedback
/// await HapticManager.shared.impact(.medium)
///
/// // Notification feedback
/// await HapticManager.shared.notification(.success)
///
/// // Selection feedback
/// await HapticManager.shared.selection()
/// ```
@MainActor
public final class HapticManager {

    // MARK: - Singleton

    /// Shared instance of the haptic manager
    public static let shared = HapticManager()

    // MARK: - Properties

    #if canImport(UIKit)
    /// Pool of impact feedback generators for reuse
    private var impactGenerators: [HapticImpact: UIImpactFeedbackGenerator] = [:]

    /// Notification feedback generator
    private var notificationGenerator: UINotificationFeedbackGenerator?

    /// Selection feedback generator
    private var selectionGenerator: UISelectionFeedbackGenerator?

    /// Timestamp of last cleanup to prevent memory buildup
    private var lastCleanupTime: Date = Date()

    /// Cleanup interval (60 seconds)
    private let cleanupInterval: TimeInterval = 60
    #endif

    // MARK: - Initialization

    private init() {
        #if canImport(UIKit)
        // Preload commonly used generators
        prepareImpactGenerator(.medium)
        prepareSelectionGenerator()
        #endif
    }

    // MARK: - Public API

    /// Triggers an impact haptic feedback
    ///
    /// - Parameter style: The intensity of the impact
    ///
    /// Example:
    /// ```swift
    /// // Light tap feedback
    /// await HapticManager.shared.impact(.light)
    ///
    /// // Heavy button press feedback
    /// await HapticManager.shared.impact(.heavy)
    /// ```
    public func impact(_ style: HapticImpact) {
        #if canImport(UIKit)
        let generator = getOrCreateImpactGenerator(for: style)
        generator.prepare()
        generator.impactOccurred()
        scheduleCleanupIfNeeded()
        #endif
        // No-op on macOS
    }

    /// Triggers a notification haptic feedback
    ///
    /// - Parameter type: The type of notification (success, warning, error)
    ///
    /// Example:
    /// ```swift
    /// // Success feedback after save
    /// await HapticManager.shared.notification(.success)
    ///
    /// // Error feedback on validation failure
    /// await HapticManager.shared.notification(.error)
    /// ```
    public func notification(_ type: HapticNotification) {
        #if canImport(UIKit)
        let generator = getOrCreateNotificationGenerator()
        generator.prepare()
        generator.notificationOccurred(type.feedbackType)
        scheduleCleanupIfNeeded()
        #endif
        // No-op on macOS
    }

    /// Triggers a selection haptic feedback
    ///
    /// Used for selection changes in pickers, segmented controls, etc.
    ///
    /// Example:
    /// ```swift
    /// // Feedback when user taps a tab
    /// await HapticManager.shared.selection()
    /// ```
    public func selection() {
        #if canImport(UIKit)
        let generator = getOrCreateSelectionGenerator()
        generator.prepare()
        generator.selectionChanged()
        scheduleCleanupIfNeeded()
        #endif
        // No-op on macOS
    }

    // MARK: - Generator Management

    #if canImport(UIKit)
    /// Gets or creates an impact generator for the specified style
    private func getOrCreateImpactGenerator(for style: HapticImpact) -> UIImpactFeedbackGenerator {
        if let generator = impactGenerators[style] {
            return generator
        }

        let generator = UIImpactFeedbackGenerator(style: style.feedbackStyle)
        impactGenerators[style] = generator
        return generator
    }

    /// Prepares an impact generator for the specified style
    private func prepareImpactGenerator(_ style: HapticImpact) {
        let generator = getOrCreateImpactGenerator(for: style)
        generator.prepare()
    }

    /// Gets or creates the notification generator
    private func getOrCreateNotificationGenerator() -> UINotificationFeedbackGenerator {
        if let generator = notificationGenerator {
            return generator
        }

        let generator = UINotificationFeedbackGenerator()
        notificationGenerator = generator
        return generator
    }

    /// Gets or creates the selection generator
    private func getOrCreateSelectionGenerator() -> UISelectionFeedbackGenerator {
        if let generator = selectionGenerator {
            return generator
        }

        let generator = UISelectionFeedbackGenerator()
        selectionGenerator = generator
        return generator
    }

    /// Prepares the selection generator
    private func prepareSelectionGenerator() {
        let generator = getOrCreateSelectionGenerator()
        generator.prepare()
    }

    /// Schedules cleanup of unused generators if needed
    private func scheduleCleanupIfNeeded() {
        let now = Date()
        if now.timeIntervalSince(lastCleanupTime) > cleanupInterval {
            cleanup()
            lastCleanupTime = now
        }
    }

    /// Cleans up all generators to free memory
    private func cleanup() {
        impactGenerators.removeAll()
        notificationGenerator = nil
        selectionGenerator = nil

        // Re-prepare commonly used generators
        prepareImpactGenerator(.medium)
        prepareSelectionGenerator()
    }
    #endif

    // MARK: - Convenience Methods

    /// Triggers haptic feedback for a successful action
    ///
    /// Example:
    /// ```swift
    /// await HapticManager.shared.success()
    /// ```
    public func success() {
        notification(.success)
    }

    /// Triggers haptic feedback for an error
    ///
    /// Example:
    /// ```swift
    /// await HapticManager.shared.error()
    /// ```
    public func error() {
        notification(.error)
    }

    /// Triggers haptic feedback for a warning
    ///
    /// Example:
    /// ```swift
    /// await HapticManager.shared.warning()
    /// ```
    public func warning() {
        notification(.warning)
    }

    /// Triggers light impact feedback
    ///
    /// Example:
    /// ```swift
    /// await HapticManager.shared.lightImpact()
    /// ```
    public func lightImpact() {
        impact(.light)
    }

    /// Triggers medium impact feedback
    ///
    /// Example:
    /// ```swift
    /// await HapticManager.shared.mediumImpact()
    /// ```
    public func mediumImpact() {
        impact(.medium)
    }

    /// Triggers heavy impact feedback
    ///
    /// Example:
    /// ```swift
    /// await HapticManager.shared.heavyImpact()
    /// ```
    public func heavyImpact() {
        impact(.heavy)
    }
}

// MARK: - SwiftUI View Extension

extension View {
    /// Adds haptic feedback to a tap gesture
    ///
    /// Example:
    /// ```swift
    /// Button("Delete") { deleteItem() }
    ///     .hapticFeedback(.impact(.medium))
    /// ```
    ///
    /// - Parameter type: The type of haptic feedback to trigger
    /// - Returns: View with haptic feedback on tap
    public func hapticFeedback(_ type: HapticFeedbackType) -> some View {
        self.onTapGesture {
            Task { @MainActor in
                switch type {
                case .impact(let style):
                    HapticManager.shared.impact(style)
                case .notification(let notificationType):
                    HapticManager.shared.notification(notificationType)
                case .selection:
                    HapticManager.shared.selection()
                }
            }
        }
    }
}

/// Types of haptic feedback for SwiftUI view modifier
public enum HapticFeedbackType {
    /// Impact feedback with specified style
    case impact(HapticImpact)

    /// Notification feedback with specified type
    case notification(HapticNotification)

    /// Selection feedback
    case selection
}

// MARK: - Button Extension

extension View {
    /// Adds haptic feedback on button press
    ///
    /// Example:
    /// ```swift
    /// Button("Save") { save() }
    ///     .buttonHaptic(.medium)
    /// ```
    ///
    /// - Parameter style: The impact style for the haptic
    /// - Returns: View with haptic feedback
    public func buttonHaptic(_ style: HapticImpact = .medium) -> some View {
        self.simultaneousGesture(
            TapGesture().onEnded { _ in
                Task { @MainActor in
                    HapticManager.shared.impact(style)
                }
            }
        )
    }

    /// Adds success haptic feedback and executes action
    ///
    /// Example:
    /// ```swift
    /// Button("Complete") { }
    ///     .withSuccessHaptic()
    /// ```
    public func withSuccessHaptic() -> some View {
        self.simultaneousGesture(
            TapGesture().onEnded { _ in
                Task { @MainActor in
                    HapticManager.shared.success()
                }
            }
        )
    }
}

// MARK: - Preview Helpers

#if DEBUG
struct HapticManager_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Text("Haptic Feedback Demo")
                .font(.largeTitle)
                .bold()

            Divider()

            // Impact haptics
            VStack(spacing: DesignTokens.Spacing.md) {
                Text("Impact Haptics")
                    .font(.headline)

                HStack(spacing: DesignTokens.Spacing.sm) {
                    Button("Light") {
                        Task { @MainActor in
                            HapticManager.shared.impact(.light)
                        }
                    }
                    .buttonStyle(.bordered)

                    Button("Medium") {
                        Task { @MainActor in
                            HapticManager.shared.impact(.medium)
                        }
                    }
                    .buttonStyle(.bordered)

                    Button("Heavy") {
                        Task { @MainActor in
                            HapticManager.shared.impact(.heavy)
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }

            Divider()

            // Notification haptics
            VStack(spacing: DesignTokens.Spacing.md) {
                Text("Notification Haptics")
                    .font(.headline)

                HStack(spacing: DesignTokens.Spacing.sm) {
                    Button("Success") {
                        Task { @MainActor in
                            HapticManager.shared.notification(.success)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)

                    Button("Warning") {
                        Task { @MainActor in
                            HapticManager.shared.notification(.warning)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)

                    Button("Error") {
                        Task { @MainActor in
                            HapticManager.shared.notification(.error)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
            }

            Divider()

            // Selection haptic
            Button("Selection Haptic") {
                Task { @MainActor in
                    HapticManager.shared.selection()
                }
            }
            .buttonStyle(.bordered)

            Divider()

            // Using view modifiers
            VStack(spacing: DesignTokens.Spacing.md) {
                Text("Using View Modifiers")
                    .font(.headline)

                Button("Button with Haptic") { }
                    .buttonStyle(.borderedProminent)
                    .buttonHaptic(.heavy)

                Button("Success Action") { }
                    .buttonStyle(.borderedProminent)
                    .withSuccessHaptic()
            }
        }
        .padding()
        .previewDisplayName("Haptic Manager")
    }
}
#endif
