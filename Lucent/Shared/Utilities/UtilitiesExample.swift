//
//  UtilitiesExample.swift
//  Lucent
//
//  Created by Claude Code on 11/23/24.
//  Example usage of BlurUtilities and HapticManager
//

import SwiftUI

#if DEBUG
/// Example view demonstrating blur and haptic utilities
struct UtilitiesExampleView: View {
    @State private var isBlurred = false
    @State private var blurIntensity: Double = 0.0
    @State private var selectedTab = 0

    var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.xl) {
                // MARK: - Header
                Text("Utilities Demo")
                    .font(.largeTitle)
                    .bold()
                    .padding(.top)

                // MARK: - Blur Utilities
                VStack(spacing: DesignTokens.Spacing.lg) {
                    Text("Blur Utilities")
                        .font(.title2)
                        .bold()

                    // Static blur example
                    ZStack {
                        LinearGradient(
                            colors: [.blue, .purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .frame(height: 200)

                        VStack(spacing: DesignTokens.Spacing.md) {
                            Text("Frosted Glass Card")
                                .font(.headline)
                                .foregroundColor(.white)

                            Text("Uses BlurView with tint")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding()
                        .background {
                            BlurView(style: .heavy, tint: .white, opacity: 0.2)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.xl))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.xl))

                    // Animated blur example
                    VStack(spacing: DesignTokens.Spacing.md) {
                        Text("Animated Blur")
                            .font(.headline)

                        Image(systemName: "photo.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(.blue)
                            .animatedBlur(isActive: isBlurred)

                        Button(isBlurred ? "Show Image" : "Blur Image") {
                            Task { @MainActor in
                                HapticManager.shared.impact(.light)
                                withAnimation {
                                    isBlurred.toggle()
                                }
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .frostedBackground(style: .medium)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg))

                    // Dynamic blur example
                    VStack(spacing: DesignTokens.Spacing.md) {
                        Text("Dynamic Blur")
                            .font(.headline)

                        Text("Intensity: \(Int(blurIntensity * 100))%")
                            .font(.caption)

                        Image(systemName: "photo.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(.green)
                            .dynamicBlur(intensity: blurIntensity)

                        Slider(value: $blurIntensity, in: 0...1)
                            .onChange(of: blurIntensity) { _, _ in
                                Task { @MainActor in
                                    HapticManager.shared.selection()
                                }
                            }
                    }
                    .padding()
                    .frostedBackground(style: .light, tint: .green, opacity: 0.05)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg))
                }
                .padding(.horizontal)

                Divider()
                    .padding(.vertical)

                // MARK: - Haptic Manager
                VStack(spacing: DesignTokens.Spacing.lg) {
                    Text("Haptic Manager")
                        .font(.title2)
                        .bold()

                    // Impact haptics
                    VStack(spacing: DesignTokens.Spacing.md) {
                        Text("Impact Haptics")
                            .font(.headline)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DesignTokens.Spacing.sm) {
                            Button("Light") {
                                Task { @MainActor in
                                    HapticManager.shared.impact(.light)
                                }
                            }
                            .buttonStyle(.bordered)

                            Button("Medium") {
                                Task { @MainActor in
                                    HapticManager.shared.impact(.medium)
                                }
                            }
                            .buttonStyle(.bordered)

                            Button("Heavy") {
                                Task { @MainActor in
                                    HapticManager.shared.impact(.heavy)
                                }
                            }
                            .buttonStyle(.bordered)

                            Button("Soft") {
                                Task { @MainActor in
                                    HapticManager.shared.impact(.soft)
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding()
                    .frostedBackground(style: .medium)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg))

                    // Notification haptics
                    VStack(spacing: DesignTokens.Spacing.md) {
                        Text("Notification Haptics")
                            .font(.headline)

                        HStack(spacing: DesignTokens.Spacing.sm) {
                            Button("Success") {
                                Task { @MainActor in
                                    HapticManager.shared.success()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)

                            Button("Warning") {
                                Task { @MainActor in
                                    HapticManager.shared.warning()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)

                            Button("Error") {
                                Task { @MainActor in
                                    HapticManager.shared.error()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                        }
                    }
                    .padding()
                    .frostedBackground(style: .medium)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg))

                    // View modifiers
                    VStack(spacing: DesignTokens.Spacing.md) {
                        Text("View Modifiers")
                            .font(.headline)

                        Button("Button with Haptic (.buttonHaptic)") {
                            print("Button tapped")
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonHaptic(.heavy)

                        Button("Success Haptic (.withSuccessHaptic)") {
                            print("Success action")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .withSuccessHaptic()
                    }
                    .padding()
                    .frostedBackground(style: .medium)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg))

                    // Tab selection with haptics
                    VStack(spacing: DesignTokens.Spacing.md) {
                        Text("Selection Haptics")
                            .font(.headline)

                        Picker("Tab", selection: $selectedTab) {
                            Text("Photos").tag(0)
                            Text("Albums").tag(1)
                            Text("Search").tag(2)
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: selectedTab) { _, _ in
                            Task { @MainActor in
                                HapticManager.shared.selection()
                            }
                        }

                        Text("Selected: Tab \(selectedTab + 1)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frostedBackground(style: .medium)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg))
                }
                .padding(.horizontal)
            }
            .padding(.bottom, DesignTokens.Spacing.xxl)
        }
        .background(
            LinearGradient(
                colors: [
                    Color.backgroundGradientStart,
                    Color.backgroundGradientMiddle,
                    Color.backgroundGradientEnd
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

struct UtilitiesExample_Previews: PreviewProvider {
    static var previews: some View {
        UtilitiesExampleView()
    }
}
#endif
