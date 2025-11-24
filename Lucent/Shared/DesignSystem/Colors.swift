//
//  Colors.swift
//  Lucent
//
//  Created by Claude Code on 11/23/24.
//

import SwiftUI

/// Semantic color definitions for the Lucent app
/// Supports both light and dark modes
extension Color {

    // MARK: - Brand Colors

    /// Primary brand color - adapts to light/dark mode
    static let lucentPrimary: Color = {
        Color(light: Color.blue, dark: Color.blue.opacity(0.9))
    }()

    /// Secondary brand color - adapts to light/dark mode
    static let lucentSecondary: Color = {
        Color(light: Color.purple, dark: Color.purple.opacity(0.9))
    }()

    /// Accent color for highlights and CTAs
    static let lucentAccent: Color = {
        Color(light: Color.pink, dark: Color.pink.opacity(0.9))
    }()

    // MARK: - Background Colors

    /// Primary background gradient start
    static let backgroundGradientStart: Color = {
        Color(light: Color.blue.opacity(0.3), dark: Color.blue.opacity(0.2))
    }()

    /// Primary background gradient middle
    static let backgroundGradientMiddle: Color = {
        Color(light: Color.purple.opacity(0.3), dark: Color.purple.opacity(0.2))
    }()

    /// Primary background gradient end
    static let backgroundGradientEnd: Color = {
        Color(light: Color.pink.opacity(0.2), dark: Color.pink.opacity(0.15))
    }()

    /// Secondary background gradient start (for alternate screens)
    static let backgroundGradientAlt1: Color = {
        Color(light: Color.indigo.opacity(0.3), dark: Color.indigo.opacity(0.2))
    }()

    /// Secondary background gradient end
    static let backgroundGradientAlt2: Color = {
        Color(light: Color.teal.opacity(0.2), dark: Color.teal.opacity(0.15))
    }()

    // MARK: - Glass Component Colors

    /// Shadow color for glass components
    static let glassShadow: Color = {
        Color(light: Color.black.opacity(0.1), dark: Color.black.opacity(0.3))
    }()

    /// Overlay color for glass components
    static let glassOverlay: Color = {
        Color(light: Color.white.opacity(0.1), dark: Color.white.opacity(0.05))
    }()

    /// Border color for glass components
    static let glassBorder: Color = {
        Color(light: Color.white.opacity(0.2), dark: Color.white.opacity(0.1))
    }()

    // MARK: - Text Colors

    /// Primary text color (uses system adaptive color)
    static let textPrimary = Color.primary

    /// Secondary text color (uses system adaptive color)
    static let textSecondary = Color.secondary

    /// Tertiary text color
    static let textTertiary: Color = {
        Color(light: Color.gray, dark: Color.gray.opacity(0.8))
    }()

    /// Text color on glass backgrounds
    static let textOnGlass: Color = {
        Color(light: Color.primary, dark: Color.white.opacity(0.9))
    }()

    // MARK: - Interactive Colors

    /// Success state color
    static let success: Color = {
        Color(light: Color.green, dark: Color.green.opacity(0.9))
    }()

    /// Error state color
    static let error: Color = {
        Color(light: Color.red, dark: Color.red.opacity(0.9))
    }()

    /// Warning state color
    static let warning: Color = {
        Color(light: Color.orange, dark: Color.orange.opacity(0.9))
    }()

    /// Info state color
    static let info: Color = {
        Color(light: Color.blue, dark: Color.blue.opacity(0.9))
    }()

    // MARK: - Album Theme Colors

    /// Predefined theme colors for albums
    static let albumThemeColors: [Color] = [
        .red, .orange, .yellow, .green, .mint, .teal,
        .cyan, .blue, .indigo, .purple, .pink, .brown
    ]

    // MARK: - Authentication Colors

    /// Biometric button gradient start
    static let biometricGradientStart: Color = {
        Color(light: Color.blue, dark: Color.blue.opacity(0.8))
    }()

    /// Biometric button gradient end
    static let biometricGradientEnd: Color = {
        Color(light: Color.purple, dark: Color.purple.opacity(0.8))
    }()

    /// Passcode dot filled color
    static let passcodeDotFilled: Color = {
        Color(light: Color.blue, dark: Color.blue.opacity(0.9))
    }()

    /// Passcode dot empty color
    static let passcodeDotEmpty: Color = {
        Color(light: Color.gray.opacity(0.3), dark: Color.gray.opacity(0.2))
    }()
}

// MARK: - Helper Extension

extension Color {
    /// Create a color that adapts to light and dark mode
    init(light: Color, dark: Color) {
        #if canImport(UIKit)
        self.init(uiColor: UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(dark)
            default:
                return UIColor(light)
            }
        })
        #else
        self.init(nsColor: NSColor(name: nil) { appearance in
            if appearance.name == .darkAqua || appearance.name == .vibrantDark {
                return NSColor(dark)
            } else {
                return NSColor(light)
            }
        } ?? NSColor(light))
        #endif
    }
}
