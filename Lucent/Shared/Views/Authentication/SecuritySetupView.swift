//
//  SecuritySetupView.swift
//  Lucent
//
//  Created by Claude Code on 11/24/24.
//

import SwiftUI

/// Onboarding view for setting up app security (Face ID/PIN)
struct SecuritySetupView: View {
    @StateObject private var biometricAuthManager = BiometricAuthManager()
    @ObservedObject var appLockManager: AppLockManager
    let onComplete: () -> Void

    @State private var currentStep: SetupStep = .welcome
    @State private var isSettingUp = false
    @State private var setupError: String?

    enum SetupStep {
        case welcome
        case biometricOffer
        case pinOffer
        case noProtectionWarning
        case complete
    }

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.2),
                    Color(red: 0.15, green: 0.15, blue: 0.25)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Animated background circles
            backgroundDecoration

            // Content
            VStack(spacing: 0) {
                Spacer()

                switch currentStep {
                case .welcome:
                    welcomeContent
                case .biometricOffer:
                    biometricOfferContent
                case .pinOffer:
                    pinOfferContent
                case .noProtectionWarning:
                    noProtectionWarningContent
                case .complete:
                    completeContent
                }

                Spacer()
            }
            .padding(.horizontal, 32)
        }
        .onAppear {
            // Start with biometric offer if available, otherwise welcome
            if biometricAuthManager.isBiometricAvailable {
                currentStep = .biometricOffer
            } else {
                currentStep = .pinOffer
            }
        }
    }

    // MARK: - Background

    private var backgroundDecoration: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(
                    colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(x: -100, y: -200)

            Circle()
                .fill(LinearGradient(
                    colors: [Color.purple.opacity(0.3), Color.pink.opacity(0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 250, height: 250)
                .blur(radius: 50)
                .offset(x: 150, y: 200)
        }
        .ignoresSafeArea()
    }

    // MARK: - Welcome Content

    private var welcomeContent: some View {
        VStack(spacing: 32) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                )

            VStack(spacing: 12) {
                Text("Welcome to Lucent")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("Your photos are encrypted and stored securely on your device.")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }

            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    if biometricAuthManager.isBiometricAvailable {
                        currentStep = .biometricOffer
                    } else {
                        currentStep = .pinOffer
                    }
                }
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(Capsule())
            }
        }
        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
    }

    // MARK: - Biometric Offer Content

    private var biometricOfferContent: some View {
        VStack(spacing: 32) {
            Image(systemName: biometricAuthManager.biometricType.iconName)
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                )

            VStack(spacing: 12) {
                Text("Enable \(biometricAuthManager.biometricType.displayName)?")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("Use \(biometricAuthManager.biometricType.displayName) to quickly and securely unlock your photos.")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 16) {
                Button {
                    Task {
                        await setupBiometric()
                    }
                } label: {
                    HStack {
                        if isSettingUp {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: biometricAuthManager.biometricType.iconName)
                        }
                        Text("Enable \(biometricAuthManager.biometricType.displayName)")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(Capsule())
                }
                .disabled(isSettingUp)

                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        currentStep = .pinOffer
                    }
                } label: {
                    Text("Maybe Later")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
                .disabled(isSettingUp)
            }

            if let error = setupError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
    }

    // MARK: - PIN Offer Content

    private var pinOfferContent: some View {
        VStack(spacing: 32) {
            Image(systemName: "key.fill")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
                )

            VStack(spacing: 12) {
                Text("Set Up a PIN?")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("A PIN provides an extra layer of security to prevent unauthorized access to your photos.")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 16) {
                Button {
                    // TODO: Implement PIN setup flow
                    // For now, just complete setup
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        currentStep = .complete
                    }
                } label: {
                    HStack {
                        Image(systemName: "key.fill")
                        Text("Set Up PIN")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(Capsule())
                }

                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        currentStep = .noProtectionWarning
                    }
                } label: {
                    Text("Skip for Now")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
    }

    // MARK: - No Protection Warning Content

    private var noProtectionWarningContent: some View {
        VStack(spacing: 32) {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
                )

            VStack(spacing: 16) {
                Text("Are You Sure?")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Without app lock protection:")
                        .font(.headline)
                        .foregroundColor(.white)

                    VStack(alignment: .leading, spacing: 8) {
                        warningPoint("Anyone with access to your unlocked phone can open Lucent and view your photos")
                        warningPoint("Your photos are still encrypted on disk")
                        warningPoint("The encryption protects against file-level access, backups, and forensic extraction")
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                )

                Text("You can always enable Face ID or PIN later in Settings.")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 16) {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        currentStep = .biometricOffer
                    }
                } label: {
                    Text("Go Back & Set Up Security")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(Capsule())
                }

                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        currentStep = .complete
                    }
                } label: {
                    Text("Continue Without Protection")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
    }

    private func warningPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "circle.fill")
                .font(.system(size: 6))
                .foregroundColor(.orange)
                .padding(.top, 6)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
        }
    }

    // MARK: - Complete Content

    private var completeContent: some View {
        VStack(spacing: 32) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
                )

            VStack(spacing: 12) {
                Text("You're All Set!")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("Start adding photos to your secure vault.")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }

            Button {
                completeSetup()
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(Capsule())
            }
        }
        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
    }

    // MARK: - Actions

    private func setupBiometric() async {
        isSettingUp = true
        setupError = nil

        let result = await biometricAuthManager.authenticate(
            reason: "Verify \(biometricAuthManager.biometricType.displayName) to enable unlock"
        )

        isSettingUp = false

        switch result {
        case .success:
            // Enable app lock with biometric
            UserDefaults.standard.set(true, forKey: "biometricEnabled")
            appLockManager.enableAppLock(requireOnLaunch: true, timeout: 60)
            appLockManager.markAuthenticationSuccessful()

            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                currentStep = .complete
            }

        case .failure(let error):
            if case .userCancelled = error {
                // User cancelled - don't show error, just stay on this screen
            } else {
                setupError = error.localizedDescription
            }
        }
    }

    private func completeSetup() {
        // Mark onboarding as complete
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        onComplete()
    }
}

// MARK: - Preview

#Preview {
    SecuritySetupView(appLockManager: AppLockManager.shared) {
        print("Setup complete")
    }
}
