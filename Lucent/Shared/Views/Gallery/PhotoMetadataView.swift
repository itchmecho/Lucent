//
//  PhotoMetadataView.swift
//  Lucent
//
//  Created by Claude Code on 11/23/2024.
//

import SwiftUI

/// Displays detailed metadata for a photo with liquid glass aesthetic
struct PhotoMetadataView: View {
    // MARK: - Properties

    let photo: EncryptedPhoto
    @Environment(\.dismiss) private var dismiss
    @State private var showingDatePicker = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // Liquid glass background
                Color.clear
                    .background(.thinMaterial)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Basic info section
                        basicInfoSection

                        // File details section
                        fileDetailsSection

                        // Camera info section (if available)
                        if hasCameraInfo {
                            cameraInfoSection
                        }

                        // Location section (if available)
                        if photo.hasLocation {
                            locationSection
                        }

                        // Organization section
                        organizationSection

                        // Dates section
                        datesSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Photo Details")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Sections

    private var basicInfoSection: some View {
        MetadataCard {
            VStack(alignment: .leading, spacing: 12) {
                MetadataRow(
                    icon: "doc.text",
                    label: "Filename",
                    value: photo.filename
                )

                if let dimensions = photo.dimensions {
                    MetadataRow(
                        icon: "square.resize",
                        label: "Dimensions",
                        value: dimensions
                    )
                }

                if let megapixels = photo.metadata.megapixels {
                    MetadataRow(
                        icon: "camera",
                        label: "Megapixels",
                        value: String(format: "%.1f MP", megapixels)
                    )
                }
            }
        }
    }

    private var fileDetailsSection: some View {
        MetadataCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "File Details")

                MetadataRow(
                    icon: "internaldrive",
                    label: "File Size",
                    value: photo.formattedFileSize
                )

                MetadataRow(
                    icon: "lock.shield",
                    label: "Encryption",
                    value: "AES-256"
                )

                MetadataRow(
                    icon: "square.stack.3d.up",
                    label: "Thumbnail",
                    value: photo.hasThumbnail ? "Available" : "Not available"
                )
            }
        }
    }

    private var cameraInfoSection: some View {
        MetadataCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Camera Info")

                if let make = photo.metadata.cameraMake {
                    MetadataRow(
                        icon: "camera",
                        label: "Make",
                        value: make
                    )
                }

                if let model = photo.metadata.cameraModel {
                    MetadataRow(
                        icon: "camera.fill",
                        label: "Model",
                        value: model
                    )
                }

                if let iso = photo.metadata.iso {
                    MetadataRow(
                        icon: "light.max",
                        label: "ISO",
                        value: "\(iso)"
                    )
                }

                if let focalLength = photo.metadata.focalLength {
                    MetadataRow(
                        icon: "scope",
                        label: "Focal Length",
                        value: String(format: "%.1f mm", focalLength)
                    )
                }

                if let aperture = photo.metadata.aperture {
                    MetadataRow(
                        icon: "circle.hexagongrid",
                        label: "Aperture",
                        value: String(format: "f/%.1f", aperture)
                    )
                }

                if let shutterSpeed = photo.metadata.shutterSpeed {
                    MetadataRow(
                        icon: "timer",
                        label: "Shutter Speed",
                        value: formatShutterSpeed(shutterSpeed)
                    )
                }
            }
        }
    }

    private var locationSection: some View {
        MetadataCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Location")

                if let latitude = photo.metadata.latitude,
                   let longitude = photo.metadata.longitude {
                    MetadataRow(
                        icon: "location",
                        label: "Coordinates",
                        value: String(format: "%.6f, %.6f", latitude, longitude)
                    )

                    // TODO: Implement map view
                    Button {
                        // Open in Maps
                    } label: {
                        HStack {
                            Image(systemName: "map")
                            Text("View on Map")
                        }
                        .font(.subheadline)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var organizationSection: some View {
        MetadataCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Organization")

                MetadataRow(
                    icon: "star",
                    label: "Favorite",
                    value: photo.metadata.isFavorite ? "Yes" : "No"
                )

                if !photo.albums.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "folder")
                                .foregroundStyle(.secondary)
                            Text("Albums")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        FlowLayout(spacing: 8) {
                            ForEach(photo.albums, id: \.self) { album in
                                TagView(text: album)
                            }
                        }
                    }
                }

                if !photo.tags.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "tag")
                                .foregroundStyle(.secondary)
                            Text("Tags")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        FlowLayout(spacing: 8) {
                            ForEach(photo.tags, id: \.self) { tag in
                                TagView(text: tag)
                            }
                        }
                    }
                } else {
                    Text("No tags")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 28)
                }
            }
        }
    }

    private var datesSection: some View {
        MetadataCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Dates")

                if let dateTaken = photo.metadata.dateTaken {
                    MetadataRow(
                        icon: "camera.shutter.button",
                        label: "Date Taken",
                        value: formatDate(dateTaken)
                    )
                }

                MetadataRow(
                    icon: "clock",
                    label: "Date Added",
                    value: formatDate(photo.dateAdded)
                )
            }
        }
    }

    // MARK: - Computed Properties

    private var hasCameraInfo: Bool {
        photo.metadata.cameraMake != nil ||
        photo.metadata.cameraModel != nil ||
        photo.metadata.iso != nil ||
        photo.metadata.focalLength != nil ||
        photo.metadata.aperture != nil ||
        photo.metadata.shutterSpeed != nil
    }

    // MARK: - Helper Methods

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatShutterSpeed(_ speed: Double) -> String {
        if speed >= 1 {
            return String(format: "%.1fs", speed)
        } else {
            let denominator = Int(1.0 / speed)
            return "1/\(denominator)s"
        }
    }
}

// MARK: - Supporting Views

struct MetadataCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.primary)
            .padding(.bottom, 4)
    }
}

struct MetadataRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.body)
                    .foregroundStyle(.primary)
            }

            Spacer()
        }
    }
}

struct TagView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.thinMaterial)
            .clipShape(Capsule())
    }
}

/// Flow layout for tags and chips
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}

// MARK: - Preview

#Preview {
    PhotoMetadataView(
        photo: EncryptedPhoto(
            metadata: PhotoMetadata(
                originalFilename: "IMG_1234.jpg",
                fileSize: 2_500_000,
                dateTaken: Date(),
                width: 4032,
                height: 3024,
                tags: ["vacation", "beach", "summer"],
                albums: ["Trip 2024"],
                isFavorite: true,
                cameraMake: "Apple",
                cameraModel: "iPhone 15 Pro",
                iso: 100,
                focalLength: 24.0,
                aperture: 1.8,
                shutterSpeed: 0.0025
            )
        )
    )
}
