//
//  GlassCard.swift
//  Lucent
//
//  Created by Claude Code on 11/23/2024.
//

import SwiftUI

/// A reusable card component with liquid glass aesthetic
struct GlassCard<Content: View>: View {
    let content: Content
    var padding: CGFloat = 16
    var cornerRadius: CGFloat = 20
    var shadowRadius: CGFloat = 10
    var material: Material = .ultraThinMaterial

    init(
        padding: CGFloat = 16,
        cornerRadius: CGFloat = 20,
        shadowRadius: CGFloat = 10,
        material: Material = .ultraThinMaterial,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.shadowRadius = shadowRadius
        self.material = material
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(material)
            .cornerRadius(cornerRadius)
            .shadow(color: Color.black.opacity(0.1), radius: shadowRadius, x: 0, y: 5)
    }
}

/// A glass card with a tappable action
struct GlassActionCard<Content: View>: View {
    let content: Content
    let action: () -> Void
    var padding: CGFloat = 16
    var cornerRadius: CGFloat = 20
    var shadowRadius: CGFloat = 10
    var material: Material = .ultraThinMaterial
    var hapticStyle: HapticImpact = .light

    @State private var isPressed = false

    init(
        padding: CGFloat = 16,
        cornerRadius: CGFloat = 20,
        shadowRadius: CGFloat = 10,
        material: Material = .ultraThinMaterial,
        hapticStyle: HapticImpact = .light,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.shadowRadius = shadowRadius
        self.material = material
        self.hapticStyle = hapticStyle
        self.action = action
        self.content = content()
    }

    var body: some View {
        Button(action: {
            Task { @MainActor in
                HapticManager.shared.impact(hapticStyle)
            }
            action()
        }) {
            content
                .padding(padding)
                .background(material)
                .cornerRadius(cornerRadius)
        }
        .buttonStyle(GlassButtonStyle(isPressed: $isPressed))
        .shadow(color: Color.black.opacity(0.1), radius: shadowRadius, x: 0, y: 5)
    }
}

/// Button style for glass cards
struct GlassButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { oldValue, newValue in
                isPressed = newValue
            }
    }
}

/// A section header with glass styling
struct GlassSectionHeader: View {
    let title: String
    var action: (() -> Void)?
    var actionTitle: String?

    var body: some View {
        HStack {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            Spacer()

            if let action = action, let actionTitle = actionTitle {
                Button(action: {
                    Task { @MainActor in
                        HapticManager.shared.lightImpact()
                    }
                    action()
                }) {
                    Text(actionTitle)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.accentColor)
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

/// A glass input field
struct GlassTextField: View {
    let title: String
    @Binding var text: String
    var placeholder: String = ""
    var icon: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !title.isEmpty {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 12) {
                if let icon = icon {
                    Image(systemName: icon)
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                }

                TextField(placeholder, text: $text)
                    .textFieldStyle(PlainTextFieldStyle())
            }
            .padding()
            .background(Material.ultraThinMaterial)
            .cornerRadius(12)
        }
    }
}

/// A glass text editor for multi-line input
struct GlassTextEditor: View {
    let title: String
    @Binding var text: String
    var placeholder: String = ""
    var height: CGFloat = 100

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !title.isEmpty {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }

            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 8)
                }

                TextEditor(text: $text)
                    .scrollContentBackground(.hidden)
                    .padding(4)
            }
            .frame(height: height)
            .padding(8)
            .background(Material.ultraThinMaterial)
            .cornerRadius(12)
        }
    }
}

/// A glass tag chip
struct GlassTagChip: View {
    let tag: String
    var onDelete: (() -> Void)?

    var body: some View {
        HStack(spacing: 6) {
            Text(tag)
                .font(.subheadline)
                .fontWeight(.medium)

            if let onDelete = onDelete {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Material.thin)
        .cornerRadius(16)
    }
}

/// A glass color picker button
struct GlassColorPicker: View {
    let title: String
    @Binding var selectedColor: Color?
    let colors: [Color]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(colors, id: \.self) { color in
                        Button(action: {
                            selectedColor = color
                        }) {
                            Circle()
                                .fill(color)
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: selectedColor == color ? 3 : 0)
                                )
                                .shadow(radius: 4)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        LinearGradient(
            colors: [.blue, .purple, .pink],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        VStack(spacing: 20) {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Glass Card")
                        .font(.headline)
                    Text("This is a beautiful glass card with blur effect and shadows")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            GlassActionCard(action: {}) {
                HStack {
                    Image(systemName: "photo.stack.fill")
                    Text("Tappable Card")
                        .fontWeight(.semibold)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
            }

            GlassTagChip(tag: "Vacation", onDelete: {})
        }
        .padding()
    }
}
