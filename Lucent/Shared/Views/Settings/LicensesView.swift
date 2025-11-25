//
//  LicensesView.swift
//  Lucent
//
//  Created by Claude Code on 11/24/24.
//

import SwiftUI

/// View displaying open source licenses used in the app
struct LicensesView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
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

                // Main content
                ScrollView {
                    VStack(spacing: DesignTokens.Spacing.sectionSpacing) {
                        // Introduction
                        introductionSection

                        // Swift and Apple Frameworks
                        appleFrameworksSection

                        // Additional acknowledgements
                        acknowledgementSection
                    }
                    .padding()
                    .padding(.bottom, DesignTokens.Spacing.xxl)
                }
            }
            .navigationTitle("Open Source Licenses")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.Common.done) {
                        dismiss()
                    }
                    .foregroundColor(.lucentAccent)
                }
            }
        }
    }

    // MARK: - Introduction Section

    private var introductionSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            GlassSectionHeader(title: "Acknowledgements")

            GlassCard(padding: DesignTokens.Spacing.lg) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    HStack(spacing: DesignTokens.Spacing.md) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: DesignTokens.IconSize.lg))
                            .foregroundColor(.lucentPrimary)

                        Text("Built with Open Source")
                            .font(.headline)
                            .foregroundColor(.textPrimary)
                    }

                    Text("Lucent is built using Apple's native frameworks and the Swift programming language. This app respects your privacy by using only built-in, trusted technologies without any third-party tracking or analytics libraries.")
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - Apple Frameworks Section

    private var appleFrameworksSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            GlassSectionHeader(title: "Apple Frameworks & Technologies")

            VStack(spacing: DesignTokens.Spacing.sm) {
                // SwiftUI
                LicenseCard(
                    name: "SwiftUI",
                    author: "Apple Inc.",
                    purpose: "Modern declarative UI framework",
                    license: .appleSLA
                )

                // Swift
                LicenseCard(
                    name: "Swift Programming Language",
                    author: "Apple Inc.",
                    purpose: "Core programming language",
                    license: .apacheSwift
                )

                // Foundation
                LicenseCard(
                    name: "Foundation",
                    author: "Apple Inc.",
                    purpose: "Essential data types and utilities",
                    license: .appleSLA
                )

                // CryptoKit
                LicenseCard(
                    name: "CryptoKit",
                    author: "Apple Inc.",
                    purpose: "Cryptographic operations for secure photo encryption",
                    license: .appleSLA
                )

                // LocalAuthentication
                LicenseCard(
                    name: "LocalAuthentication",
                    author: "Apple Inc.",
                    purpose: "Biometric authentication (Face ID / Touch ID)",
                    license: .appleSLA
                )

                // Photos Framework
                LicenseCard(
                    name: "PhotosUI",
                    author: "Apple Inc.",
                    purpose: "Photo picker and library access",
                    license: .appleSLA
                )

                // Core Data
                LicenseCard(
                    name: "Core Data",
                    author: "Apple Inc.",
                    purpose: "Persistent data storage",
                    license: .appleSLA
                )

                // AVFoundation
                LicenseCard(
                    name: "AVFoundation",
                    author: "Apple Inc.",
                    purpose: "Camera capture and media handling",
                    license: .appleSLA
                )

                // ImageIO
                LicenseCard(
                    name: "ImageIO",
                    author: "Apple Inc.",
                    purpose: "High-performance image processing",
                    license: .appleSLA
                )
            }
        }
    }

    // MARK: - Acknowledgement Section

    private var acknowledgementSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            GlassSectionHeader(title: "Special Thanks")

            GlassCard(padding: DesignTokens.Spacing.lg) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    HStack(spacing: DesignTokens.Spacing.md) {
                        Image(systemName: "sparkles")
                            .font(.system(size: DesignTokens.IconSize.lg))
                            .foregroundColor(.success)

                        Text("Privacy First")
                            .font(.headline)
                            .foregroundColor(.textPrimary)
                    }

                    Text("This app is built entirely with Apple's native frameworks, ensuring your photos stay private and secure on your device. No third-party libraries, no tracking, no cloud services — just pure, local encryption and privacy.")
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

// MARK: - License Card Component

/// A card displaying information about a specific license
struct LicenseCard: View {
    let name: String
    let author: String
    let purpose: String
    let license: LicenseType

    @State private var isExpanded = false

    var body: some View {
        GlassCard(padding: 0) {
            VStack(spacing: 0) {
                // Header - Always visible
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isExpanded.toggle()
                    }
                }) {
                    HStack(spacing: DesignTokens.Spacing.md) {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                            Text(name)
                                .font(.body)
                                .fontWeight(.semibold)
                                .foregroundColor(.textPrimary)

                            Text(purpose)
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer()

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.textTertiary)
                    }
                    .padding(DesignTokens.Spacing.lg)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())

                // Expanded content - License details
                if isExpanded {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                        Divider()
                            .padding(.horizontal, DesignTokens.Spacing.lg)

                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                            HStack {
                                Text("Author:")
                                    .font(.caption)
                                    .foregroundColor(.textSecondary)
                                Text(author)
                                    .font(.caption)
                                    .foregroundColor(.textPrimary)
                            }

                            HStack {
                                Text("License:")
                                    .font(.caption)
                                    .foregroundColor(.textSecondary)
                                Text(license.displayName)
                                    .font(.caption)
                                    .foregroundColor(.textPrimary)
                            }
                        }
                        .padding(.horizontal, DesignTokens.Spacing.lg)

                        if !license.fullText.isEmpty {
                            Divider()
                                .padding(.horizontal, DesignTokens.Spacing.lg)

                            ScrollView {
                                Text(license.fullText)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxHeight: 300)
                            .padding(.horizontal, DesignTokens.Spacing.lg)
                        }
                    }
                    .padding(.bottom, DesignTokens.Spacing.lg)
                }
            }
        }
    }
}

// MARK: - License Types

/// Enumeration of license types used in the app
enum LicenseType {
    case appleSLA
    case apacheSwift
    case mit
    case custom(String)

    var displayName: String {
        switch self {
        case .appleSLA:
            return "Apple SLA"
        case .apacheSwift:
            return "Apache 2.0 (Swift)"
        case .mit:
            return "MIT License"
        case .custom(let name):
            return name
        }
    }

    var fullText: String {
        switch self {
        case .appleSLA:
            return """
            Apple Software License Agreement

            The Apple frameworks and technologies used in this application are provided by Apple Inc. and are subject to the Apple Software License Agreement.

            These frameworks are included with Xcode and iOS/macOS SDKs and are licensed for use in developing applications for Apple platforms.

            For more information, please visit:
            https://www.apple.com/legal/sla/
            """

        case .apacheSwift:
            return """
            Apache License, Version 2.0

            Copyright 2014-2024 Apple Inc. and the Swift project authors

            Licensed under the Apache License, Version 2.0 (the "License");
            you may not use this file except in compliance with the License.
            You may obtain a copy of the License at

                http://www.apache.org/licenses/LICENSE-2.0

            Unless required by applicable law or agreed to in writing, software
            distributed under the License is distributed on an "AS IS" BASIS,
            WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
            See the License for the specific language governing permissions and
            limitations under the License.

            Swift is licensed under the Apache License v2.0 with Runtime Library Exception.
            For more information, see: https://swift.org/LICENSE.txt
            """

        case .mit:
            return """
            MIT License

            Permission is hereby granted, free of charge, to any person obtaining a copy
            of this software and associated documentation files (the "Software"), to deal
            in the Software without restriction, including without limitation the rights
            to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
            copies of the Software, and to permit persons to whom the Software is
            furnished to do so, subject to the following conditions:

            The above copyright notice and this permission notice shall be included in all
            copies or substantial portions of the Software.

            THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
            IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
            FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
            AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
            LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
            OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
            SOFTWARE.
            """

        case .custom(let text):
            return text
        }
    }
}

// MARK: - Preview

#Preview {
    LicensesView()
}
