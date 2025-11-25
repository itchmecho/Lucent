//
//  BackupView.swift
//  Lucent
//
//  Created by Claude Code on 11/24/24.
//

import SwiftUI
import UniformTypeIdentifiers

#if canImport(UIKit)
import UIKit
#endif

/// View for creating and restoring backups
struct BackupView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = BackupViewModel()

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

                ScrollView {
                    VStack(spacing: DesignTokens.Spacing.sectionSpacing) {
                        // Info section
                        infoSection

                        // Create backup section
                        createBackupSection

                        // Restore backup section
                        restoreBackupSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Backup & Restore")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert(viewModel.alertTitle, isPresented: $viewModel.showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.alertMessage)
            }
            .sheet(isPresented: $viewModel.showPasswordSheet) {
                PasswordInputView(
                    mode: viewModel.passwordMode,
                    onSubmit: { password in
                        viewModel.handlePasswordSubmit(password)
                    },
                    onCancel: {
                        viewModel.showPasswordSheet = false
                    }
                )
            }
            .sheet(isPresented: $viewModel.showProgressSheet) {
                BackupProgressView(
                    progress: viewModel.progress,
                    onCancel: {
                        viewModel.cancelOperation()
                    }
                )
                .interactiveDismissDisabled()
            }
            .fileImporter(
                isPresented: $viewModel.showFilePicker,
                allowedContentTypes: [.init(filenameExtension: "lucent") ?? .data],
                allowsMultipleSelection: false
            ) { result in
                viewModel.handleFileSelection(result)
            }
            #if os(iOS)
            .sheet(isPresented: $viewModel.showShareSheet) {
                if let url = viewModel.backupURL {
                    BackupShareSheet(items: [url])
                }
            }
            #endif
        }
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            GlassCard {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    HStack(spacing: DesignTokens.Spacing.md) {
                        Image(systemName: "lock.shield.fill")
                            .font(.title2)
                            .foregroundStyle(Color.lucentAccent)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Encrypted Backups")
                                .font(.headline)
                                .foregroundStyle(Color.textPrimary)

                            Text("Your backup is protected with a password you choose")
                                .font(.caption)
                                .foregroundStyle(Color.textSecondary)
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        InfoRow(icon: "checkmark.circle.fill", text: "Photos encrypted with AES-256", color: .success)
                        InfoRow(icon: "checkmark.circle.fill", text: "Password never stored", color: .success)
                        InfoRow(icon: "checkmark.circle.fill", text: "Portable between devices", color: .success)
                        InfoRow(icon: "exclamationmark.triangle.fill", text: "Losing password = losing backup", color: .warning)
                    }
                }
            }
        }
    }

    // MARK: - Create Backup Section

    private var createBackupSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            GlassSectionHeader(title: "Create Backup")

            GlassCard(padding: 0) {
                VStack(spacing: 0) {
                    SettingsRowInfo(
                        icon: "photo.stack.fill",
                        title: "Photos to Backup",
                        value: "\(viewModel.photoCount)"
                    )

                    Divider().padding(.leading, DesignTokens.Spacing.xxl + DesignTokens.Spacing.lg)

                    SettingsRowInfo(
                        icon: "externaldrive.fill",
                        title: "Estimated Size",
                        value: viewModel.estimatedBackupSize
                    )

                    Divider().padding(.leading, DesignTokens.Spacing.xxl + DesignTokens.Spacing.lg)

                    Button {
                        viewModel.startCreateBackup()
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up.fill")
                                .font(.system(size: DesignTokens.IconSize.md))
                                .foregroundStyle(Color.lucentAccent)
                                .frame(width: DesignTokens.IconSize.xl, alignment: .center)

                            Text("Create Backup")
                                .font(.body)
                                .foregroundStyle(Color.textPrimary)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(Color.textTertiary)
                        }
                        .padding(DesignTokens.Spacing.lg)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.photoCount == 0)
                    .opacity(viewModel.photoCount == 0 ? 0.5 : 1.0)
                }
            }
        }
    }

    // MARK: - Restore Backup Section

    private var restoreBackupSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            GlassSectionHeader(title: "Restore Backup")

            GlassCard(padding: 0) {
                VStack(spacing: 0) {
                    Button {
                        viewModel.startRestoreBackup()
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.down.fill")
                                .font(.system(size: DesignTokens.IconSize.md))
                                .foregroundStyle(Color.lucentPrimary)
                                .frame(width: DesignTokens.IconSize.xl, alignment: .center)

                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                                Text("Restore from Backup")
                                    .font(.body)
                                    .foregroundStyle(Color.textPrimary)

                                Text("Select a .lucent backup file")
                                    .font(.caption)
                                    .foregroundStyle(Color.textSecondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(Color.textTertiary)
                        }
                        .padding(DesignTokens.Spacing.lg)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            // Warning about restore
            Text("Restored photos will be added to your existing library. Duplicates may occur.")
                .font(.caption)
                .foregroundStyle(Color.textSecondary)
                .padding(.horizontal, DesignTokens.Spacing.sm)
        }
    }
}

// MARK: - Info Row

private struct InfoRow: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)

            Text(text)
                .font(.caption)
                .foregroundStyle(Color.textSecondary)
        }
    }
}

// MARK: - Password Input View

struct PasswordInputView: View {
    let mode: BackupViewModel.PasswordMode
    let onSubmit: (String) -> Void
    let onCancel: () -> Void

    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
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

                VStack(spacing: DesignTokens.Spacing.xl) {
                    // Icon
                    Image(systemName: mode == .create ? "lock.fill" : "lock.open.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.lucentAccent)
                        .padding(.top, DesignTokens.Spacing.xl)

                    // Title and description
                    VStack(spacing: DesignTokens.Spacing.sm) {
                        Text(mode == .create ? "Set Backup Password" : "Enter Backup Password")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.textPrimary)

                        Text(mode == .create
                            ? "Choose a strong password to protect your backup"
                            : "Enter the password used when creating this backup")
                            .font(.subheadline)
                            .foregroundStyle(Color.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // Password fields
                    GlassCard {
                        VStack(spacing: DesignTokens.Spacing.md) {
                            HStack {
                                if showPassword {
                                    TextField("Password", text: $password)
                                        .textContentType(.password)
                                } else {
                                    SecureField("Password", text: $password)
                                        .textContentType(.password)
                                }

                                Button {
                                    showPassword.toggle()
                                } label: {
                                    Image(systemName: showPassword ? "eye.slash" : "eye")
                                        .foregroundStyle(Color.textSecondary)
                                }
                            }

                            if mode == .create {
                                Divider()

                                if showPassword {
                                    TextField("Confirm Password", text: $confirmPassword)
                                        .textContentType(.password)
                                } else {
                                    SecureField("Confirm Password", text: $confirmPassword)
                                        .textContentType(.password)
                                }
                            }
                        }
                    }

                    // Error message
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(Color.error)
                    }

                    // Requirements for new password
                    if mode == .create {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                            RequirementRow(text: "At least 8 characters", met: password.count >= 8)
                            RequirementRow(text: "Passwords match", met: !confirmPassword.isEmpty && password == confirmPassword)
                        }
                        .padding(.horizontal)
                    }

                    Spacer()

                    // Submit button
                    Button {
                        if validate() {
                            onSubmit(password)
                        }
                    } label: {
                        Text(mode == .create ? "Create Backup" : "Restore Backup")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg)
                                    .fill(Color.lucentAccent)
                            )
                    }
                    .disabled(!isValid)
                    .opacity(isValid ? 1.0 : 0.5)
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var isValid: Bool {
        if mode == .create {
            return password.count >= 8 && password == confirmPassword
        } else {
            return !password.isEmpty
        }
    }

    private func validate() -> Bool {
        errorMessage = nil

        if mode == .create {
            if password.count < 8 {
                errorMessage = "Password must be at least 8 characters"
                return false
            }
            if password != confirmPassword {
                errorMessage = "Passwords don't match"
                return false
            }
        } else {
            if password.isEmpty {
                errorMessage = "Please enter a password"
                return false
            }
        }

        return true
    }
}

// MARK: - Requirement Row

private struct RequirementRow: View {
    let text: String
    let met: Bool

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: met ? "checkmark.circle.fill" : "circle")
                .font(.caption)
                .foregroundStyle(met ? Color.success : Color.textTertiary)

            Text(text)
                .font(.caption)
                .foregroundStyle(met ? Color.textPrimary : Color.textTertiary)
        }
    }
}

// MARK: - Backup Progress View

struct BackupProgressView: View {
    let progress: BackupManager.Progress
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            Spacer()

            // Progress indicator
            ZStack {
                Circle()
                    .stroke(Color.textTertiary.opacity(0.3), lineWidth: 8)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: progress.fractionComplete)
                    .stroke(Color.lucentAccent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: progress.fractionComplete)

                VStack(spacing: 4) {
                    Text("\(Int(progress.fractionComplete * 100))%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.textPrimary)

                    Text("\(progress.current)/\(progress.total)")
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)
                }
            }

            // Phase text
            Text(progress.phase.rawValue)
                .font(.headline)
                .foregroundStyle(Color.textPrimary)

            // Current file
            if let fileName = progress.currentPhotoName {
                Text(fileName)
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            // Cancel button (only if not complete)
            if progress.phase != .complete {
                Button {
                    onCancel()
                } label: {
                    Text("Cancel")
                        .font(.body)
                        .foregroundStyle(Color.error)
                }
                .padding(.bottom)
            }
        }
        .padding()
        .presentationDetents([.medium])
        .interactiveDismissDisabled(progress.phase != .complete)
    }
}

// MARK: - Backup Share Sheet (iOS)

#if os(iOS)
struct BackupShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

// MARK: - Preview

#Preview {
    BackupView()
}
