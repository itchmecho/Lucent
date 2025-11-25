//
//  BackupViewModel.swift
//  Lucent
//
//  Created by Claude Code on 11/24/24.
//

import SwiftUI
import Foundation

/// ViewModel for the Backup & Restore view
@MainActor
final class BackupViewModel: ObservableObject {

    // MARK: - Types

    enum PasswordMode {
        case create
        case restore
    }

    // MARK: - Published Properties

    @Published var photoCount: Int = 0
    @Published var estimatedBackupSize: String = "Calculating..."

    @Published var showAlert = false
    @Published var alertTitle = ""
    @Published var alertMessage = ""

    @Published var showPasswordSheet = false
    @Published var passwordMode: PasswordMode = .create

    @Published var showProgressSheet = false
    @Published var progress = BackupManager.Progress(
        phase: .preparing,
        current: 0,
        total: 0,
        currentPhotoName: nil
    )

    @Published var showFilePicker = false
    @Published var showShareSheet = false
    @Published var backupURL: URL?

    // MARK: - Private Properties

    private let backupManager = BackupManager.shared
    private let storage = SecurePhotoStorage.shared
    private var selectedBackupURL: URL?
    private var currentTask: Task<Void, Never>?

    // MARK: - Initialization

    init() {
        Task {
            await loadStats()
        }
    }

    // MARK: - Public Methods

    func loadStats() async {
        do {
            let stats = try await storage.getStorageStats()
            photoCount = stats.photoCount
            estimatedBackupSize = ByteCountFormatter.string(
                fromByteCount: Int64(stats.totalSizeBytes),
                countStyle: .file
            )
        } catch {
            AppLogger.storage.error("Failed to load stats: \(error.localizedDescription, privacy: .public)")
            photoCount = 0
            estimatedBackupSize = "Unknown"
        }
    }

    // MARK: - Create Backup

    func startCreateBackup() {
        guard photoCount > 0 else {
            showError(title: "No Photos", message: "There are no photos to backup.")
            return
        }

        passwordMode = .create
        showPasswordSheet = true
    }

    // MARK: - Restore Backup

    func startRestoreBackup() {
        showFilePicker = true
    }

    func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            // Start accessing security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                showError(title: "Access Denied", message: "Unable to access the selected file.")
                return
            }

            selectedBackupURL = url
            passwordMode = .restore
            showPasswordSheet = true

        case .failure(let error):
            AppLogger.storage.error("File selection failed: \(error.localizedDescription, privacy: .public)")
            showError(title: "Error", message: "Failed to select backup file.")
        }
    }

    // MARK: - Password Handling

    func handlePasswordSubmit(_ password: String) {
        showPasswordSheet = false

        switch passwordMode {
        case .create:
            performBackupCreation(password: password)
        case .restore:
            performBackupRestore(password: password)
        }
    }

    // MARK: - Backup Operations

    private func performBackupCreation(password: String) {
        showProgressSheet = true

        currentTask = Task {
            do {
                let url = try await backupManager.createBackup(
                    password: password,
                    progressHandler: { [weak self] progress in
                        Task { @MainActor in
                            self?.progress = progress
                        }
                    }
                )

                // Show share sheet
                backupURL = url
                showProgressSheet = false
                showShareSheet = true

            } catch BackupManager.BackupError.cancelled {
                showProgressSheet = false

            } catch {
                showProgressSheet = false
                showError(title: "Backup Failed", message: error.localizedDescription)
            }
        }
    }

    private func performBackupRestore(password: String) {
        guard let backupURL = selectedBackupURL else { return }

        showProgressSheet = true

        currentTask = Task {
            defer {
                // Stop accessing security-scoped resource
                backupURL.stopAccessingSecurityScopedResource()
                selectedBackupURL = nil
            }

            do {
                let restoredCount = try await backupManager.restoreBackup(
                    from: backupURL,
                    password: password,
                    progressHandler: { [weak self] progress in
                        Task { @MainActor in
                            self?.progress = progress
                        }
                    }
                )

                showProgressSheet = false

                // Refresh stats
                await loadStats()

                // Show success
                showSuccess(
                    title: "Restore Complete",
                    message: "Successfully restored \(restoredCount) photo\(restoredCount == 1 ? "" : "s")."
                )

            } catch BackupManager.BackupError.wrongPassword {
                showProgressSheet = false
                showError(title: "Incorrect Password", message: "The password you entered is incorrect.")

            } catch BackupManager.BackupError.cancelled {
                showProgressSheet = false

            } catch {
                showProgressSheet = false
                showError(title: "Restore Failed", message: error.localizedDescription)
            }
        }
    }

    func cancelOperation() {
        currentTask?.cancel()
        currentTask = nil
        showProgressSheet = false
    }

    // MARK: - Alerts

    private func showError(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }

    private func showSuccess(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
}
