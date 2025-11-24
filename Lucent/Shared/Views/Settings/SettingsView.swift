//
//  SettingsView.swift
//  Lucent
//
//  Created by Claude Code on 11/23/24.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// Main settings screen for the Lucent app
struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
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
                        // Security Settings Section
                        securitySection

                        // Storage Management Section
                        storageSection

                        // Appearance Section
                        appearanceSection

                        // Backup & Data Section
                        backupSection

                        // About Section
                        aboutSection
                    }
                    .padding()
                    .padding(.bottom, DesignTokens.Spacing.xxl)
                }
            }
            .navigationTitle("Settings")
            .alert(viewModel.alertTitle, isPresented: $viewModel.showAlert) {
                if viewModel.isDestructiveAlert {
                    Button("Cancel", role: .cancel) { }
                    Button("Confirm", role: .destructive) {
                        viewModel.confirmAction()
                    }
                } else {
                    Button("OK", role: .cancel) { }
                }
            } message: {
                Text(viewModel.alertMessage)
            }
        }
        .onAppear {
            viewModel.loadSettings()
        }
    }

    // MARK: - Security Settings Section

    private var securitySection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            GlassSectionHeader(title: "Security")

            GlassCard(padding: 0) {
                VStack(spacing: 0) {
                    // Auto-lock timer
                    SettingsRowButton(
                        icon: "timer",
                        title: "Auto-lock",
                        value: viewModel.autoLockDescription,
                        action: { viewModel.showAutoLockOptions = true }
                    )

                    Divider().padding(.leading, DesignTokens.Spacing.xxl + DesignTokens.Spacing.lg)

                    // Biometric authentication toggle
                    SettingsRowToggle(
                        icon: viewModel.biometricIcon,
                        title: viewModel.biometricTitle,
                        subtitle: "Use \(viewModel.biometricTitle) to unlock",
                        isOn: $viewModel.biometricEnabled
                    )
                    .disabled(!viewModel.isBiometricAvailable)
                    .opacity(viewModel.isBiometricAvailable ? 1.0 : 0.5)

                    Divider().padding(.leading, DesignTokens.Spacing.xxl + DesignTokens.Spacing.lg)

                    // Change passcode button
                    SettingsRowButton(
                        icon: "key.fill",
                        title: "Change Passcode",
                        action: { viewModel.changePasscode() }
                    )

                    Divider().padding(.leading, DesignTokens.Spacing.xxl + DesignTokens.Spacing.lg)

                    // Require passcode on launch toggle
                    SettingsRowToggle(
                        icon: "lock.shield",
                        title: "Require on Launch",
                        subtitle: "Lock when app closes",
                        isOn: $viewModel.requirePasscodeOnLaunch
                    )
                }
            }
        }
        .sheet(isPresented: $viewModel.showAutoLockOptions) {
            autoLockSheet
        }
    }

    // MARK: - Storage Management Section

    private var storageSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            GlassSectionHeader(title: "Storage")

            GlassCard(padding: 0) {
                VStack(spacing: 0) {
                    // Total storage used
                    SettingsRowInfo(
                        icon: "externaldrive.fill",
                        title: "Total Storage",
                        value: viewModel.totalStorageFormatted
                    )

                    Divider().padding(.leading, DesignTokens.Spacing.xxl + DesignTokens.Spacing.lg)

                    // Number of photos
                    SettingsRowInfo(
                        icon: "photo.stack.fill",
                        title: "Photos Stored",
                        value: "\(viewModel.photoCount)"
                    )

                    Divider().padding(.leading, DesignTokens.Spacing.xxl + DesignTokens.Spacing.lg)

                    // Clear thumbnail cache button
                    SettingsRowButton(
                        icon: "trash.fill",
                        title: "Clear Thumbnail Cache",
                        subtitle: viewModel.thumbnailCacheSize,
                        tintColor: .warning,
                        action: { viewModel.showClearCacheConfirmation() }
                    )
                }
            }
        }
    }

    // MARK: - Appearance Section

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            GlassSectionHeader(title: "Appearance")

            GlassCard(padding: 0) {
                VStack(spacing: 0) {
                    // Dark mode selection
                    SettingsRowButton(
                        icon: "moon.fill",
                        title: "Appearance",
                        value: viewModel.appearanceModeDescription,
                        action: { viewModel.showAppearanceOptions = true }
                    )

                    Divider().padding(.leading, DesignTokens.Spacing.xxl + DesignTokens.Spacing.lg)

                    // Show photo count badges toggle
                    SettingsRowToggle(
                        icon: "number.circle.fill",
                        title: "Show Photo Counts",
                        subtitle: "Display counts on albums",
                        isOn: $viewModel.showPhotoCounts
                    )

                    Divider().padding(.leading, DesignTokens.Spacing.xxl + DesignTokens.Spacing.lg)

                    // Show thumbnails toggle
                    SettingsRowToggle(
                        icon: "photo.fill",
                        title: "Show Thumbnails",
                        subtitle: "Display photo previews in grid",
                        isOn: $viewModel.showThumbnails
                    )
                }
            }
        }
        .sheet(isPresented: $viewModel.showAppearanceOptions) {
            appearanceSheet
        }
    }

    // MARK: - Backup & Data Section

    private var backupSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            GlassSectionHeader(title: "Backup & Data")

            GlassCard(padding: 0) {
                VStack(spacing: 0) {
                    // Export metadata button
                    SettingsRowButton(
                        icon: "square.and.arrow.up.fill",
                        title: "Export Metadata",
                        subtitle: "Non-sensitive data only",
                        action: { viewModel.exportMetadata() }
                    )

                    Divider().padding(.leading, DesignTokens.Spacing.xxl + DesignTokens.Spacing.lg)

                    // Local-only warning
                    SettingsRowInfo(
                        icon: "exclamationmark.shield.fill",
                        title: "Local Storage Only",
                        subtitle: "Photos are stored only on this device. Back up your device regularly.",
                        tintColor: .info
                    )
                }
            }
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            GlassSectionHeader(title: "About")

            GlassCard(padding: 0) {
                VStack(spacing: 0) {
                    // App version
                    SettingsRowInfo(
                        icon: "info.circle.fill",
                        title: "Version",
                        value: viewModel.appVersion
                    )

                    Divider().padding(.leading, DesignTokens.Spacing.xxl + DesignTokens.Spacing.lg)

                    // Build number
                    SettingsRowInfo(
                        icon: "hammer.fill",
                        title: "Build",
                        value: viewModel.buildNumber
                    )

                    Divider().padding(.leading, DesignTokens.Spacing.xxl + DesignTokens.Spacing.lg)

                    // Privacy policy
                    SettingsRowButton(
                        icon: "hand.raised.fill",
                        title: "Privacy Policy",
                        action: { viewModel.openPrivacyPolicy() }
                    )

                    Divider().padding(.leading, DesignTokens.Spacing.xxl + DesignTokens.Spacing.lg)

                    // Open source licenses
                    SettingsRowButton(
                        icon: "doc.text.fill",
                        title: "Open Source Licenses",
                        action: { viewModel.openLicenses() }
                    )
                }
            }

            // Developer info
            Text("Made with care for your privacy")
                .font(.footnote)
                .foregroundColor(.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, DesignTokens.Spacing.md)
        }
    }

    // MARK: - Auto-lock Sheet

    private var autoLockSheet: some View {
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

                List {
                    ForEach(AutoLockOption.allCases, id: \.self) { option in
                        Button {
                            viewModel.setAutoLockTimeout(option)
                            viewModel.showAutoLockOptions = false
                        } label: {
                            HStack {
                                Text(option.displayName)
                                    .foregroundColor(.textPrimary)
                                Spacer()
                                if viewModel.selectedAutoLockOption == option {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.lucentAccent)
                                }
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Auto-lock Timer")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        viewModel.showAutoLockOptions = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Appearance Sheet

    private var appearanceSheet: some View {
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

                List {
                    ForEach(AppearanceMode.allCases, id: \.self) { mode in
                        Button {
                            viewModel.setAppearanceMode(mode)
                            viewModel.showAppearanceOptions = false
                        } label: {
                            HStack {
                                Image(systemName: mode.iconName)
                                    .frame(width: DesignTokens.IconSize.md)
                                Text(mode.displayName)
                                    .foregroundColor(.textPrimary)
                                Spacer()
                                if viewModel.selectedAppearanceMode == mode {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.lucentAccent)
                                }
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Appearance")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        viewModel.showAppearanceOptions = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Settings Row Components

/// A settings row with a button action
struct SettingsRowButton: View {
    let icon: String
    let title: String
    var subtitle: String?
    var value: String?
    var tintColor: Color = .lucentPrimary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: DesignTokens.IconSize.md))
                    .foregroundColor(tintColor)
                    .frame(width: DesignTokens.IconSize.xl, alignment: .center)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(title)
                        .font(.body)
                        .foregroundColor(.textPrimary)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                    }
                }

                Spacer()

                if let value = value {
                    Text(value)
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.textTertiary)
            }
            .padding(DesignTokens.Spacing.lg)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// A settings row with a toggle switch
struct SettingsRowToggle: View {
    let icon: String
    let title: String
    var subtitle: String?
    var tintColor: Color = .lucentPrimary
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: DesignTokens.IconSize.md))
                .foregroundColor(tintColor)
                .frame(width: DesignTokens.IconSize.xl, alignment: .center)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(title)
                    .font(.body)
                    .foregroundColor(.textPrimary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(.lucentAccent)
        }
        .padding(DesignTokens.Spacing.lg)
        .contentShape(Rectangle())
    }
}

/// A settings row with informational text
struct SettingsRowInfo: View {
    let icon: String
    let title: String
    var subtitle: String?
    var value: String?
    var tintColor: Color = .lucentPrimary

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: DesignTokens.IconSize.md))
                .foregroundColor(tintColor)
                .frame(width: DesignTokens.IconSize.xl, alignment: .center)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(title)
                    .font(.body)
                    .foregroundColor(.textPrimary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()

            if let value = value {
                Text(value)
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
            }
        }
        .padding(DesignTokens.Spacing.lg)
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
}
