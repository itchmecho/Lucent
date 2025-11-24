//
//  PasscodeView.swift
//  Lucent
//
//  Created by Claude Code on 11/23/24.
//

import SwiftUI

/// View for entering and verifying passcode
struct PasscodeView: View {

    // MARK: - Properties

    @ObservedObject var passcodeManager: PasscodeManager

    let onSuccess: () -> Void
    let onCancel: (() -> Void)?

    @State private var passcode: String = ""
    @State private var confirmPasscode: String = ""
    @State private var mode: PasscodeMode = .verify
    @State private var errorMessage: String?
    @State private var showError: Bool = false
    @State private var attemptCount: Int = 0

    private let maxPasscodeLength = 6
    private let maxAttempts = 5

    enum PasscodeMode {
        case verify
        case setup
        case confirm
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 32) {
            // Title and subtitle
            headerView

            // Passcode dots
            passcodeDotsView

            // Error message
            if showError, let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }

            // Numeric keypad
            numericKeypad

            // Cancel button
            if let cancelAction = onCancel {
                Button(action: cancelAction) {
                    Text("Cancel")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .onAppear {
            determineMode()
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        VStack(spacing: 8) {
            Text(headerTitle)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text(headerSubtitle)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
        }
    }

    private var passcodeDotsView: some View {
        HStack(spacing: 16) {
            ForEach(0..<maxPasscodeLength, id: \.self) { index in
                Circle()
                    .fill(index < currentPasscode.count ? Color.white : Color.white.opacity(0.3))
                    .frame(width: 16, height: 16)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.5), lineWidth: 1)
                    )
                    .scaleEffect(index == currentPasscode.count - 1 ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: currentPasscode.count)
            }
        }
        .padding()
    }

    private var numericKeypad: some View {
        VStack(spacing: 16) {
            // Rows 1-3
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 16) {
                    ForEach(1..<4, id: \.self) { col in
                        let number = row * 3 + col
                        keypadButton(for: "\(number)")
                    }
                }
            }

            // Bottom row with 0 and delete
            HStack(spacing: 16) {
                // Empty space
                Color.clear
                    .frame(width: 80, height: 80)

                // Zero button
                keypadButton(for: "0")

                // Delete button
                Button(action: deleteDigit) {
                    Image(systemName: "delete.left.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                        .frame(width: 80, height: 80)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                        )
                }
                .disabled(currentPasscode.isEmpty)
                .opacity(currentPasscode.isEmpty ? 0.3 : 1.0)
            }
        }
    }

    // MARK: - Helper Views

    private func keypadButton(for digit: String) -> some View {
        Button(action: {
            addDigit(digit)
        }) {
            Text(digit)
                .font(.system(size: 28, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 80, height: 80)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
        }
        .disabled(currentPasscode.count >= maxPasscodeLength)
    }

    // MARK: - Computed Properties

    private var currentPasscode: String {
        switch mode {
        case .verify, .setup:
            return passcode
        case .confirm:
            return confirmPasscode
        }
    }

    private var headerTitle: String {
        switch mode {
        case .verify:
            return "Enter Passcode"
        case .setup:
            return "Set Passcode"
        case .confirm:
            return "Confirm Passcode"
        }
    }

    private var headerSubtitle: String {
        switch mode {
        case .verify:
            return "Enter your \(passcodeManager.isPasscodeSet ? "" : "new ")passcode"
        case .setup:
            return "Create a 4-6 digit passcode"
        case .confirm:
            return "Enter your passcode again"
        }
    }

    // MARK: - Methods

    private func determineMode() {
        mode = passcodeManager.isPasscodeSet ? .verify : .setup
    }

    private func addDigit(_ digit: String) {
        guard currentPasscode.count < maxPasscodeLength else { return }

        // Haptic feedback
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif

        switch mode {
        case .verify, .setup:
            passcode += digit
            if passcode.count >= 4 {
                // Auto-submit when minimum length is reached
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    handlePasscodeEntry()
                }
            }
        case .confirm:
            confirmPasscode += digit
            if confirmPasscode.count >= 4 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    handlePasscodeEntry()
                }
            }
        }
    }

    private func deleteDigit() {
        // Haptic feedback
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif

        switch mode {
        case .verify, .setup:
            if !passcode.isEmpty {
                passcode.removeLast()
            }
        case .confirm:
            if !confirmPasscode.isEmpty {
                confirmPasscode.removeLast()
            }
        }

        showError = false
    }

    private func handlePasscodeEntry() {
        switch mode {
        case .verify:
            verifyPasscode()
        case .setup:
            setupPasscode()
        case .confirm:
            confirmSetupPasscode()
        }
    }

    private func verifyPasscode() {
        let isValid = passcodeManager.verifyPasscode(passcode)

        if isValid {
            // Success - haptic and callback
            #if os(iOS)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            #endif

            onSuccess()
        } else {
            // Failed - show error and reset
            attemptCount += 1

            #if os(iOS)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
            #endif

            if attemptCount >= maxAttempts {
                errorMessage = "Too many attempts. Please try again later."
            } else {
                errorMessage = "Incorrect passcode. \(maxAttempts - attemptCount) attempts remaining."
            }

            withAnimation {
                showError = true
            }

            // Shake animation
            shakePasscode()

            passcode = ""
        }
    }

    private func setupPasscode() {
        guard passcode.count >= 4 else {
            errorMessage = "Passcode must be at least 4 digits"
            showError = true
            return
        }

        mode = .confirm
        showError = false
    }

    private func confirmSetupPasscode() {
        guard confirmPasscode == passcode else {
            errorMessage = "Passcodes don't match. Try again."
            withAnimation {
                showError = true
            }

            #if os(iOS)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
            #endif

            shakePasscode()

            confirmPasscode = ""
            return
        }

        // Save the passcode
        let success = passcodeManager.setPasscode(passcode)

        if success {
            #if os(iOS)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            #endif

            onSuccess()
        } else {
            errorMessage = "Failed to save passcode. Please try again."
            showError = true
            passcode = ""
            confirmPasscode = ""
            mode = .setup
        }
    }

    private func shakePasscode() {
        // Visual shake feedback
        withAnimation(.default.repeatCount(3, autoreverses: true).speed(6)) {
            // Trigger shake animation
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        PasscodeView(
            passcodeManager: PasscodeManager(),
            onSuccess: {
                print("Passcode verified!")
            },
            onCancel: {
                print("Cancelled")
            }
        )
    }
}
