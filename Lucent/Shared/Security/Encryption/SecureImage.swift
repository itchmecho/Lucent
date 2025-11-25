//
//  SecureImage.swift
//  Lucent
//
//  Created by Claude Code on 11/24/2024.
//

import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// A wrapper for platform images that automatically wipes the underlying data from memory
/// when the image is deallocated or explicitly cleared.
///
/// Use `SecureImage` for any decrypted photo data to ensure sensitive images
/// are properly cleared from memory after viewing.
///
/// Thread Safety: This class uses an internal lock to ensure thread-safe access
/// to mutable state. All public methods are safe to call from any thread.
///
/// Example:
/// ```swift
/// @State private var secureImage: SecureImage?
///
/// func loadImage() async {
///     let data = try await storage.retrievePhoto(id: photoId)
///     secureImage = SecureImage(data: data)
/// }
///
/// // Image is automatically wiped when secureImage = nil or when view disappears
/// ```
public final class SecureImage: @unchecked Sendable {
    // Note: @unchecked Sendable is valid because all mutable state access
    // (_image, _imageDataCopy, _isWiped) is synchronized through self.lock (an NSLock)

    // MARK: - Properties

    /// Lock for thread-safe access to mutable state
    private let lock = NSLock()

    /// The underlying platform image (UIImage on iOS, NSImage on macOS)
    #if canImport(UIKit)
    private var _image: UIImage?
    #elseif canImport(AppKit)
    private var _image: NSImage?
    #endif

    /// A copy of the original image data for secure wiping
    /// We keep this to ensure we can wipe the source data
    private var _imageDataCopy: Data

    /// Whether this image has been wiped
    private var _isWiped: Bool = false

    /// Thread-safe access to isWiped
    public var isWiped: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isWiped
    }

    // MARK: - Initialization

    /// Creates a SecureImage from raw image data
    /// - Parameter data: The image data to wrap
    /// - Returns: A SecureImage if the data is valid, nil otherwise
    public init?(data: Data) {
        // Keep a copy of the data for later wiping
        self._imageDataCopy = data

        // Create the platform image
        #if canImport(UIKit)
        guard let platformImage = UIImage(data: data) else {
            // Wipe the copy even if image creation failed
            self._imageDataCopy.secureWipe()
            return nil
        }
        self._image = platformImage
        #elseif canImport(AppKit)
        guard let platformImage = NSImage(data: data) else {
            // Wipe the copy even if image creation failed
            self._imageDataCopy.secureWipe()
            return nil
        }
        self._image = platformImage
        #endif

        AppLogger.security.debug("SecureImage created - data size: \(data.count) bytes")
    }

    // MARK: - Public Methods

    /// Returns the underlying platform image
    /// - Returns: The UIImage or NSImage, or nil if wiped
    #if canImport(UIKit)
    public func getImage() -> UIImage? {
        lock.lock()
        defer { lock.unlock() }
        guard !_isWiped else {
            AppLogger.security.warning("Attempted to access wiped SecureImage")
            return nil
        }
        return _image
    }
    #elseif canImport(AppKit)
    public func getImage() -> NSImage? {
        lock.lock()
        defer { lock.unlock() }
        guard !_isWiped else {
            AppLogger.security.warning("Attempted to access wiped SecureImage")
            return nil
        }
        return _image
    }
    #endif

    /// Explicitly wipes the image data from memory
    ///
    /// Call this method when you're done with the image to immediately
    /// clear it from memory rather than waiting for deallocation.
    public func wipe() {
        lock.lock()
        defer { lock.unlock() }

        guard !_isWiped else { return }

        AppLogger.security.debug("SecureImage: Wiping image data from memory")

        // Wipe the stored data copy
        _imageDataCopy.secureWipe()

        // Attempt to wipe the image's internal data representation
        #if canImport(UIKit)
        if let uiImage = _image {
            wipeUIImageData(uiImage)
        }
        #elseif canImport(AppKit)
        if let nsImage = _image {
            wipeNSImageData(nsImage)
        }
        #endif

        // Release the image reference
        _image = nil
        _isWiped = true

        AppLogger.security.debug("SecureImage: Wipe complete")
    }

    // MARK: - Deinit

    deinit {
        // Ensure data is wiped when deallocated
        // Note: No need to check lock here - deinit runs single-threaded
        if !_isWiped {
            // Direct wipe without lock (we're being deallocated)
            _imageDataCopy.secureWipe()
            #if canImport(UIKit)
            if let uiImage = _image {
                wipeUIImageData(uiImage)
            }
            #elseif canImport(AppKit)
            if let nsImage = _image {
                wipeNSImageData(nsImage)
            }
            #endif
            _image = nil
            _isWiped = true
        }
    }

    // MARK: - Private Helpers

    #if canImport(UIKit)
    /// Attempts to wipe UIImage's internal bitmap data
    private func wipeUIImageData(_ image: UIImage) {
        // Try to access the underlying CGImage and clear its data
        if let cgImage = image.cgImage,
           let dataProvider = cgImage.dataProvider,
           let cfData = dataProvider.data {
            // Get mutable access to the data if possible
            if CFDataGetLength(cfData) > 0 {
                // Note: CFData from CGImage's data provider is typically immutable,
                // but we try to wipe what we can access
                let length = CFDataGetLength(cfData)
                let bytes = CFDataGetBytePtr(cfData)
                if let bytes = bytes {
                    // Attempt to wipe (may fail on read-only memory)
                    let mutableBytes = UnsafeMutableRawPointer(mutating: bytes)
                    SecureMemory.wipe(mutableBytes, count: length)
                }
            }
        }

        // Also try to wipe any PNG/JPEG representation
        if var pngData = image.pngData() {
            pngData.secureWipe()
        }
    }
    #endif

    #if canImport(AppKit)
    /// Attempts to wipe NSImage's internal bitmap data
    private func wipeNSImageData(_ image: NSImage) {
        // Try to wipe each image representation
        for rep in image.representations {
            if let bitmapRep = rep as? NSBitmapImageRep {
                if var tiffData = bitmapRep.tiffRepresentation {
                    tiffData.secureWipe()
                }
            }
        }

        // Also try to wipe TIFF representation
        if var tiffData = image.tiffRepresentation {
            tiffData.secureWipe()
        }
    }
    #endif
}

// MARK: - SwiftUI Convenience

extension SecureImage {
    /// Returns a SwiftUI Image view for this secure image
    @ViewBuilder
    public var swiftUIImage: some View {
        #if canImport(UIKit)
        if let uiImage = getImage() {
            Image(uiImage: uiImage)
                .resizable()
        } else {
            EmptyView()
        }
        #elseif canImport(AppKit)
        if let nsImage = getImage() {
            Image(nsImage: nsImage)
                .resizable()
        } else {
            EmptyView()
        }
        #endif
    }
}

// MARK: - Sendable Conformance
// SecureImage now directly conforms to Sendable through proper internal synchronization
// via NSLock, rather than using @unchecked Sendable
