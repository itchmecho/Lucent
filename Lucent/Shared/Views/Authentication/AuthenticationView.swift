//
//  AuthenticationView.swift
//  Lucent
//
//  Created by Claude Code on 11/23/24.
//

import SwiftUI

/// Lock screen view with biometric authentication
struct AuthenticationView: View {

    // MARK: - Properties

    @StateObject private var biometricAuthManager = BiometricAuthManager()
    @StateObject private var passcodeManager = PasscodeManager()
    @ObservedObject var appLockManager: AppLockManager

    @State private var showPasscodeView = false
    @State private var authenticationError: String?
    @State private var isAuthenticating = false

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background with blur effect
            backgroundView

            // Main content
            VStack(spacing: 40) {
                Spacer()

                // App icon and title
                headerView

                // Biometric authentication section
                if !showPasscodeView {
                    biometricAuthSection
                } else {
                    PasscodeView(
                        passcodeManager: passcodeManager,
                        onSuccess: {
                            handleAuthenticationSuccess()
                        },
                        onCancel: {
                            if biometricAuthManager.isBiometricAvailable {
                                showPasscodeView = false
                            }
                        }
                    )
                }

                Spacer()
            }
            .padding()
        }
        .onAppear {
            // Attempt biometric authentication automatically if available
            if biometricAuthManager.isBiometricAvailable && !showPasscodeView {
                Task {
                    await attemptBiometricAuthentication()
                }
            }
        }
    }

    // MARK: - Subviews

    private var backgroundView: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.2),
                    Color(red: 0.15, green: 0.15, blue: 0.25)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Liquid glass effect overlay
            liquidGlassOverlay
        }
    }

    private var liquidGlassOverlay: some View {
        ZStack {
            // Animated circles for liquid effect
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.blue.opacity(0.3),
                            Color.purple.opacity(0.2)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(x: -100, y: -200)

            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.purple.opacity(0.3),
                            Color.pink.opacity(0.2)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 250, height: 250)
                .blur(radius: 50)
                .offset(x: 150, y: 200)
        }
        .ignoresSafeArea()
    }

    private var headerView: some View {
        VStack(spacing: 16) {
            // App icon or logo
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("Lucent")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text("Your photos are protected")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
        }
    }

    private var biometricAuthSection: some View {
        VStack(spacing: 24) {
            // Biometric icon button
            Button(action: {
                Task {
                    await attemptBiometricAuthentication()
                }
            }) {
                VStack(spacing: 16) {
                    Image(systemName: biometricAuthManager.biometricType.iconName)
                        .font(.system(size: 50))
                        .foregroundColor(.white)

                    Text("Unlock with \(biometricAuthManager.biometricType.displayName)")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .frame(width: 200, height: 120)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            .disabled(isAuthenticating)
            .opacity(isAuthenticating ? 0.6 : 1.0)

            // Error message
            if let error = authenticationError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Fallback to passcode button
            if passcodeManager.isPasscodeSet || !biometricAuthManager.isBiometricAvailable {
                Button(action: {
                    showPasscodeView = true
                    authenticationError = nil
                }) {
                    Text("Use Passcode")
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 24)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        )
                }
            }
        }
    }

    // MARK: - Methods

    private func attemptBiometricAuthentication() async {
        guard !isAuthenticating else { return }

        isAuthenticating = true
        authenticationError = nil

        let result = await biometricAuthManager.authenticateWithFallback(
            reason: "Unlock Lucent to access your photos"
        )

        isAuthenticating = false

        switch result {
        case .success:
            handleAuthenticationSuccess()
        case .failure(let error):
            switch error {
            case .userCancelled, .systemCancelled:
                authenticationError = nil
            case .biometricNotAvailable, .biometricNotEnrolled:
                showPasscodeView = true
            default:
                authenticationError = error.localizedDescription
            }
        }
    }

    private func handleAuthenticationSuccess() {
        // Animate the success
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            appLockManager.isAuthenticated = true
        }
    }
}

// MARK: - Preview

#Preview {
    AuthenticationView(appLockManager: AppLockManager.shared)
}
