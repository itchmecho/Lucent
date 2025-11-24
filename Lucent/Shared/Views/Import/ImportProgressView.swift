//
//  ImportProgressView.swift
//  Lucent
//
//  Created by Claude Code on 11/23/2024.
//

import SwiftUI

/// Progress indicator for photo import operations with liquid glass design
struct ImportProgressView: View {
    // MARK: - Properties

    @ObservedObject var importManager: PhotoImportManager
    var onDismiss: () -> Void

    @State private var showingSuccess = false
    @State private var showingError = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color.blue.opacity(0.3),
                        Color.purple.opacity(0.2),
                        Color.pink.opacity(0.1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()

                    // Main content card
                    VStack(spacing: 24) {
                        // Icon
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 100, height: 100)
                                .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)

                            if importManager.isImporting {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .scaleEffect(1.5)
                            } else if importManager.failureCount > 0 && importManager.successCount == 0 {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.orange)
                            } else if importManager.successCount > 0 {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.green)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: importManager.isImporting)

                        // Status text
                        VStack(spacing: 8) {
                            Text(importManager.statusMessage)
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.center)

                            if importManager.isImporting {
                                Text("\(Int(importManager.importProgress * 100))%")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        // Progress bar
                        if importManager.isImporting {
                            ProgressView(value: importManager.importProgress)
                                .progressViewStyle(.linear)
                                .tint(.blue)
                                .frame(maxWidth: 300)
                                .padding(.horizontal)
                        }

                        // Statistics
                        if !importManager.isImporting && (importManager.successCount > 0 || importManager.failureCount > 0) {
                            VStack(spacing: 12) {
                                Divider()
                                    .padding(.vertical, 8)

                                HStack(spacing: 40) {
                                    ImportStatisticView(
                                        title: "Imported",
                                        value: importManager.successCount,
                                        color: .green
                                    )

                                    if importManager.failureCount > 0 {
                                        ImportStatisticView(
                                            title: "Failed",
                                            value: importManager.failureCount,
                                            color: .orange
                                        )
                                    }
                                }
                            }
                        }

                        // Error message
                        if let error = importManager.currentError {
                            Text(error.localizedDescription)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .padding(.horizontal)
                                .multilineTextAlignment(.center)
                        }

                        // Done button
                        if !importManager.isImporting {
                            Button(action: {
                                onDismiss()
                                importManager.resetState()
                            }) {
                                Text("Done")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: 300)
                                    .padding()
                                    .background {
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(.blue)
                                    }
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 8)
                        }
                    }
                    .padding(32)
                    .background {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .shadow(color: .black.opacity(0.2), radius: 30, x: 0, y: 15)
                    }
                    .padding()

                    Spacer()
                }
            }
            .navigationTitle("Importing Photos")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                if !importManager.isImporting {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") {
                            onDismiss()
                            importManager.resetState()
                        }
                    }
                }
            }
        }
        .interactiveDismissDisabled(importManager.isImporting)
    }
}

// MARK: - Import Statistic View Component

private struct ImportStatisticView: View {
    let title: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(color)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @StateObject private var importManager = PhotoImportManager()

        var body: some View {
            ImportProgressView(importManager: importManager) {
                print("Dismissed")
            }
            .onAppear {
                // Simulate import progress
                Task {
                    await MainActor.run {
                        importManager.isImporting = true
                        importManager.statusMessage = "Importing photos..."
                    }

                    for i in 1...10 {
                        try? await Task.sleep(for: .milliseconds(500))
                        await MainActor.run {
                            importManager.importProgress = Double(i) / 10.0
                            importManager.statusMessage = "Importing photo \(i) of 10..."
                            importManager.successCount = i
                        }
                    }

                    await MainActor.run {
                        importManager.isImporting = false
                        importManager.statusMessage = "Import complete!"
                    }
                }
            }
        }
    }

    return PreviewWrapper()
}
