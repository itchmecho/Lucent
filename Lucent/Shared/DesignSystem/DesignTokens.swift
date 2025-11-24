//
//  DesignTokens.swift
//  Lucent
//
//  Created by Claude Code on 11/23/24.
//

import SwiftUI

/// Design tokens for consistent spacing, sizing, and styling throughout the app
enum DesignTokens {

    // MARK: - Spacing

    enum Spacing {
        /// Extra small spacing (4pt)
        static let xs: CGFloat = 4

        /// Small spacing (8pt)
        static let sm: CGFloat = 8

        /// Medium spacing (12pt)
        static let md: CGFloat = 12

        /// Large spacing (16pt) - Default card padding
        static let lg: CGFloat = 16

        /// Extra large spacing (24pt)
        static let xl: CGFloat = 24

        /// Extra extra large spacing (32pt)
        static let xxl: CGFloat = 32

        /// Extra extra extra large spacing (40pt)
        static let xxxl: CGFloat = 40

        /// Grid spacing for photo grids
        static let gridSpacing: CGFloat = 8

        /// Section spacing
        static let sectionSpacing: CGFloat = 24
    }

    // MARK: - Corner Radius

    enum CornerRadius {
        /// Small radius for buttons and chips (8pt)
        static let sm: CGFloat = 8

        /// Medium radius for small cards (12pt)
        static let md: CGFloat = 12

        /// Large radius for standard cards (16pt)
        static let lg: CGFloat = 16

        /// Extra large radius for primary cards (20pt)
        static let xl: CGFloat = 20

        /// Extra extra large radius for featured elements (24pt)
        static let xxl: CGFloat = 24

        /// Circular elements
        static let circle: CGFloat = 999
    }

    // MARK: - Shadow

    enum Shadow {
        /// Light shadow for subtle depth
        static let light = ShadowStyle(
            color: Color.glassShadow,
            radius: 5,
            x: 0,
            y: 2
        )

        /// Medium shadow for cards
        static let medium = ShadowStyle(
            color: Color.glassShadow,
            radius: 10,
            x: 0,
            y: 5
        )

        /// Heavy shadow for floating elements
        static let heavy = ShadowStyle(
            color: Color.glassShadow,
            radius: 20,
            x: 0,
            y: 10
        )

        /// Extra heavy shadow for modals
        static let extraHeavy = ShadowStyle(
            color: Color.glassShadow,
            radius: 30,
            x: 0,
            y: 15
        )
    }

    /// Shadow style configuration
    struct ShadowStyle {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }

    // MARK: - Materials

    enum Materials {
        /// Ultra thin material for glass components
        static let ultraThin: Material = .ultraThinMaterial

        /// Thin material for secondary glass components
        static let thin: Material = .thinMaterial

        /// Regular material for backgrounds
        static let regular: Material = .regularMaterial

        /// Thick material for prominent elements
        static let thick: Material = .thickMaterial

        /// Ultra thick material for modals
        static let ultraThick: Material = .ultraThickMaterial
    }

    // MARK: - Opacity

    enum Opacity {
        /// Very subtle opacity
        static let subtle: Double = 0.05

        /// Light opacity
        static let light: Double = 0.1

        /// Medium opacity
        static let medium: Double = 0.2

        /// Strong opacity
        static let strong: Double = 0.3

        /// Disabled state
        static let disabled: Double = 0.5

        /// Pressed state
        static let pressed: Double = 0.9
    }

    // MARK: - Icon Sizes

    enum IconSize {
        /// Small icon (16pt)
        static let sm: CGFloat = 16

        /// Medium icon (20pt)
        static let md: CGFloat = 20

        /// Large icon (24pt)
        static let lg: CGFloat = 24

        /// Extra large icon (32pt)
        static let xl: CGFloat = 32

        /// Extra extra large icon (48pt)
        static let xxl: CGFloat = 48

        /// Huge icon for featured elements (64pt)
        static let huge: CGFloat = 64
    }

    // MARK: - Button Sizes

    enum ButtonSize {
        /// Small button height (36pt)
        static let sm: CGFloat = 36

        /// Medium button height (44pt)
        static let md: CGFloat = 44

        /// Large button height (54pt)
        static let lg: CGFloat = 54

        /// Extra large button height (64pt)
        static let xl: CGFloat = 64
    }

    // MARK: - Grid Columns

    enum GridColumns {
        /// Minimum columns for photo grid
        static let min: Int = 2

        /// Default columns for iPhone
        static let phone: Int = 3

        /// Default columns for iPad portrait
        static let tabletPortrait: Int = 4

        /// Default columns for iPad landscape
        static let tabletLandscape: Int = 5

        /// Maximum columns
        static let max: Int = 6
    }

    // MARK: - Blur Radius

    enum BlurRadius {
        /// Subtle blur
        static let subtle: CGFloat = 10

        /// Light blur
        static let light: CGFloat = 20

        /// Medium blur
        static let medium: CGFloat = 40

        /// Heavy blur
        static let heavy: CGFloat = 60

        /// Extra heavy blur for backgrounds
        static let extraHeavy: CGFloat = 80
    }

    // MARK: - Typography (Font Sizes)

    enum FontSize {
        /// Caption text (11pt)
        static let caption: CGFloat = 11

        /// Footnote text (13pt)
        static let footnote: CGFloat = 13

        /// Subheadline text (15pt)
        static let subheadline: CGFloat = 15

        /// Body text (17pt)
        static let body: CGFloat = 17

        /// Callout text (16pt)
        static let callout: CGFloat = 16

        /// Headline text (17pt)
        static let headline: CGFloat = 17

        /// Title 3 (20pt)
        static let title3: CGFloat = 20

        /// Title 2 (22pt)
        static let title2: CGFloat = 22

        /// Title 1 (28pt)
        static let title1: CGFloat = 28

        /// Large title (34pt)
        static let largeTitle: CGFloat = 34
    }
}

// MARK: - View Extensions

extension View {
    /// Apply a glass shadow to a view
    func glassShadow(_ style: DesignTokens.ShadowStyle = DesignTokens.Shadow.medium) -> some View {
        self.shadow(color: style.color, radius: style.radius, x: style.x, y: style.y)
    }

    /// Apply standard card padding
    func cardPadding() -> some View {
        self.padding(DesignTokens.Spacing.lg)
    }

    /// Apply section spacing
    func sectionSpacing() -> some View {
        self.padding(.bottom, DesignTokens.Spacing.sectionSpacing)
    }
}
