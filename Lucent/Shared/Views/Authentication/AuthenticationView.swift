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
    @State private var hasAttemptedAutoAuth = false

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
            // Only attempt once per view appearance to prevent loops
            if biometricAuthManager.isBiometricAvailable && !showPasscodeView && !hasAttemptedAutoAuth {
                hasAttemptedAutoAuth = true
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

            Text(L10n.Common.appName)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text(L10n.Auth.photosProtected)
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

                    Text(L10n.Auth.unlockWith(biometricAuthManager.biometricType.displayName))
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
                    Text(L10n.Auth.usePasscode)
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

        // Use AppLockManager's authenticate method to ensure proper state management
        // This prevents race conditions with app lifecycle events
        let success = await appLockManager.authenticate(reason: L10n.Auth.unlockReason)

        isAuthenticating = false

        if success {
            // AppLockManager already sets isAuthenticated = true
            // Just animate the transition
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                // State is already updated, this just ensures animation
            }
        } else {
            // Check if biometrics failed due to user cancel or system issues
            if !biometricAuthManager.isBiometricAvailable {
                showPasscodeView = true
            }
            // Note: AppLockManager handles rate limiting and lockout internally
        }
    }

    private func handleAuthenticationSuccess() {
        // Animate the success and use AppLockManager to ensure grace period is set
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            appLockManager.markAuthenticationSuccessful()
        }
    }
}

// MARK: - Preview

#Preview {
    AuthenticationView(appLockManager: AppLockManager.shared)
}
