//
//  AlbumManager.swift
//  Lucent
//
//  Created by Claude Code on 11/23/2024.
//

import Foundation

/// Manages album operations including CRUD and photo assignments
actor AlbumManager {
    // MARK: - Singleton

    static let shared = AlbumManager()

    // MARK: - Storage

    private let fileManager = FileManager.default
    private let albumsURL: URL
    private static let albumsFileName = "albums.json"

    // MARK: - In-Memory Store

    private var albums: [UUID: Album] = [:]
    private var isInitialized = false

    // MARK: - Error Types

    /// Album errors with sanitized user-facing messages
    enum AlbumError: Error, LocalizedError {
        case initializationFailed
        case albumNotFound
        case invalidAlbumName
        case systemAlbumModification
        case saveFailed(reason: String)
        case loadFailed(reason: String)
        case photoStorageError(Error)

        /// User-facing error description - intentionally generic for security
        var errorDescription: String? {
            switch self {
            case .initializationFailed:
                return "Failed to initialize albums"
            case .albumNotFound:
                return "Album not found"
            case .invalidAlbumName:
                return "Album name cannot be empty"
            case .systemAlbumModification:
                return "Cannot modify system albums"
            case .saveFailed:
                // Don't expose internal reason to users
                return "Failed to save album"
            case .loadFailed:
                // Don't expose internal reason to users
                return "Failed to load albums"
            case .photoStorageError:
                // Don't expose underlying error to users
                return "Failed to update photo"
            }
        }

        /// Detailed error info for logging (use with privacy: .private)
        var debugDescription: String {
            switch self {
            case .initializationFailed:
                return "Album storage initialization failed"
            case .albumNotFound:
                return "Album ID not found in storage"
            case .invalidAlbumName:
                return "Invalid album name (empty or whitespace)"
            case .systemAlbumModification:
                return "Attempted to modify system album"
            case .saveFailed(let reason):
                return "Album save failed: \(reason)"
            case .loadFailed(let reason):
                return "Album load failed: \(reason)"
            case .photoStorageError(let error):
                return "Photo storage error: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Initialization

    private init() {
        // Compute albums URL - fall back to temp directory if Documents unavailable (should never happen)
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())

        if fileManager.urls(for: .documentDirectory, in: .userDomainMask).isEmpty {
            AppLogger.storage.error("CRITICAL: Could not access Documents directory for AlbumManager")
        }

        let baseURL = documentsURL.appendingPathComponent("LucentVault", isDirectory: true)
        let metadataURL = baseURL.appendingPathComponent("Metadata", isDirectory: true)
        self.albumsURL = metadataURL.appendingPathComponent(Self.albumsFileName)
    }

    // MARK: - Public Methods

    /// Initializes the album manager
    func initialize() throws {
        guard !isInitialized else { return }

        do {
            try loadAlbums()

            // Ensure system albums exist
            try createSystemAlbumsIfNeeded()

            isInitialized = true
        } catch {
            throw AlbumError.initializationFailed
        }
    }

    // MARK: - Album CRUD

    /// Creates a new album
    /// - Parameters:
    ///   - name: Album name
    ///   - description: Optional description
    ///   - themeColor: Optional theme color
    /// - Returns: Created album
    func createAlbum(
        name: String,
        description: String? = nil,
        themeColor: String? = nil
    ) throws -> Album {
        try ensureInitialized()

        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw AlbumError.invalidAlbumName
        }

        let album = Album(
            name: name,
            description: description,
            themeColor: themeColor
        )

        albums[album.id] = album
        try saveAlbums()

        return album
    }

    /// Retrieves an album by ID
    /// - Parameter id: Album identifier
    /// - Returns: Album if found
    func getAlbum(id: UUID) throws -> Album {
        try ensureInitialized()

        guard let album = albums[id] else {
            throw AlbumError.albumNotFound
        }

        return album
    }

    /// Lists all albums
    /// - Parameter includeSystem: Whether to include system albums
    /// - Returns: Array of albums
    func listAlbums(includeSystem: Bool = true) throws -> [Album] {
        try ensureInitialized()

        if includeSystem {
            return Array(albums.values).sorted { $0.dateCreated < $1.dateCreated }
        } else {
            return Array(albums.values)
                .filter { !$0.isSystemAlbum }
                .sorted { $0.dateCreated < $1.dateCreated }
        }
    }

    /// Updates an album
    /// - Parameter album: Updated album
    func updateAlbum(_ album: Album) throws {
        try ensureInitialized()

        guard albums[album.id] != nil else {
            throw AlbumError.albumNotFound
        }

        guard !album.isSystemAlbum else {
            throw AlbumError.systemAlbumModification
        }

        var updatedAlbum = album
        updatedAlbum.dateModified = Date()
        albums[album.id] = updatedAlbum
        try saveAlbums()
    }

    /// Deletes an album
    /// - Parameter id: Album identifier
    func deleteAlbum(id: UUID) async throws {
        try ensureInitialized()

        guard let album = albums[id] else {
            throw AlbumError.albumNotFound
        }

        guard !album.isSystemAlbum else {
            throw AlbumError.systemAlbumModification
        }

        // Remove album reference from all photos in the album
        for photoId in album.photoIds {
            try await removePhotoFromAlbumMetadata(photoId: photoId, albumName: album.name)
        }

        albums.removeValue(forKey: id)
        try saveAlbums()
    }

    // MARK: - Photo Operations

    /// Adds a photo to an album
    /// - Parameters:
    ///   - photoId: Photo identifier
    ///   - albumId: Album identifier
    func addPhotoToAlbum(photoId: UUID, albumId: UUID) async throws {
        try ensureInitialized()

        guard var album = albums[albumId] else {
            throw AlbumError.albumNotFound
        }

        // Update album
        album.addPhoto(photoId)
        albums[albumId] = album

        // Update photo metadata
        do {
            try await addPhotoToAlbumMetadata(photoId: photoId, albumName: album.name)
        } catch {
            throw AlbumError.photoStorageError(error)
        }

        try saveAlbums()
    }

    /// Removes a photo from an album
    /// - Parameters:
    ///   - photoId: Photo identifier
    ///   - albumId: Album identifier
    func removePhotoFromAlbum(photoId: UUID, albumId: UUID) async throws {
        try ensureInitialized()

        guard var album = albums[albumId] else {
            throw AlbumError.albumNotFound
        }

        // Update album
        album.removePhoto(photoId)
        albums[albumId] = album

        // Update photo metadata
        do {
            try await removePhotoFromAlbumMetadata(photoId: photoId, albumName: album.name)
        } catch {
            throw AlbumError.photoStorageError(error)
        }

        try saveAlbums()
    }

    /// Adds multiple photos to an album
    /// - Parameters:
    ///   - photoIds: Array of photo identifiers
    ///   - albumId: Album identifier
    func addPhotosToAlbum(photoIds: [UUID], albumId: UUID) async throws {
        for photoId in photoIds {
            try await addPhotoToAlbum(photoId: photoId, albumId: albumId)
        }
    }

    /// Gets all albums containing a specific photo
    /// - Parameter photoId: Photo identifier
    /// - Returns: Array of albums
    func getAlbumsForPhoto(photoId: UUID) throws -> [Album] {
        try ensureInitialized()

        return Array(albums.values).filter { album in
            album.photoIds.contains(photoId)
        }
    }

    /// Gets photos in an album
    /// - Parameter albumId: Album identifier
    /// - Returns: Array of EncryptedPhoto objects
    func getPhotosInAlbum(albumId: UUID) async throws -> [EncryptedPhoto] {
        try ensureInitialized()

        guard let album = albums[albumId] else {
            throw AlbumError.albumNotFound
        }

        let storage = SecurePhotoStorage.shared
        var photos: [EncryptedPhoto] = []

        for photoId in album.photoIds {
            if let photo = try? await storage.getPhoto(id: photoId) {
                photos.append(photo)
            }
        }

        // Sort photos according to album's sort order
        return sortPhotos(photos, by: album.sortOrder)
    }

    /// Sets the cover photo for an album
    /// - Parameters:
    ///   - albumId: Album identifier
    ///   - photoId: Photo identifier (nil to clear)
    func setCoverPhoto(albumId: UUID, photoId: UUID?) throws {
        try ensureInitialized()

        guard var album = albums[albumId] else {
            throw AlbumError.albumNotFound
        }

        album.setCoverPhoto(photoId)
        albums[albumId] = album
        try saveAlbums()
    }

    // MARK: - System Albums

    /// Gets the All Photos album
    func getAllPhotosAlbum() throws -> Album {
        try ensureInitialized()
        return albums[Album.allPhotosAlbum().id]!
    }

    /// Gets the Favorites album
    func getFavoritesAlbum() throws -> Album {
        try ensureInitialized()
        return albums[Album.favoritesAlbum().id]!
    }

    /// Gets the Recent album
    func getRecentAlbum() throws -> Album {
        try ensureInitialized()
        return albums[Album.recentAlbum().id]!
    }

    /// Syncs system albums with photo storage
    func syncSystemAlbums() async throws {
        try ensureInitialized()

        let storage = SecurePhotoStorage.shared
        let allPhotos = try await storage.listAllPhotos()

        // Update All Photos album
        var allPhotosAlbum = try getAllPhotosAlbum()
        allPhotosAlbum.photoIds = allPhotos.map { $0.id }
        albums[allPhotosAlbum.id] = allPhotosAlbum

        // Update Favorites album
        var favoritesAlbum = try getFavoritesAlbum()
        favoritesAlbum.photoIds = allPhotos.filter { $0.metadata.isFavorite }.map { $0.id }
        albums[favoritesAlbum.id] = favoritesAlbum

        // Update Recent album (last 30 days)
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        var recentAlbum = try getRecentAlbum()
        recentAlbum.photoIds = allPhotos.filter { $0.dateAdded > thirtyDaysAgo }.map { $0.id }
        albums[recentAlbum.id] = recentAlbum

        try saveAlbums()
    }

    // MARK: - Private Methods

    private func ensureInitialized() throws {
        if !isInitialized {
            try initialize()
        }
    }

    private func createSystemAlbumsIfNeeded() throws {
        let systemAlbums = [
            Album.allPhotosAlbum(),
            Album.favoritesAlbum(),
            Album.recentAlbum()
        ]

        for album in systemAlbums {
            if albums[album.id] == nil {
                albums[album.id] = album
            }
        }

        try saveAlbums()
    }

    private func loadAlbums() throws {
        guard fileManager.fileExists(atPath: albumsURL.path) else {
            // No albums file yet - start fresh
            albums = [:]
            return
        }

        do {
            let data = try Data(contentsOf: albumsURL)
            let albumArray = try JSONDecoder().decode([Album].self, from: data)
            albums = Dictionary(uniqueKeysWithValues: albumArray.map { ($0.id, $0) })
        } catch {
            throw AlbumError.loadFailed(reason: error.localizedDescription)
        }
    }

    /// File permissions: 0600 (owner read/write only)
    private static let filePermissions: Int = 0o600

    private func saveAlbums() throws {
        let albumArray = Array(albums.values)

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(albumArray)
            try data.write(to: albumsURL)

            // Set strict file permissions on albums file
            try fileManager.setAttributes(
                [.posixPermissions: Self.filePermissions],
                ofItemAtPath: albumsURL.path
            )
        } catch {
            throw AlbumError.saveFailed(reason: error.localizedDescription)
        }
    }

    private func addPhotoToAlbumMetadata(photoId: UUID, albumName: String) async throws {
        let storage = SecurePhotoStorage.shared
        var photo = try await storage.getPhoto(id: photoId)
        photo.metadata.addToAlbum(albumName)
        try await storage.updateMetadata(id: photoId, metadata: photo.metadata)
    }

    private func removePhotoFromAlbumMetadata(photoId: UUID, albumName: String) async throws {
        let storage = SecurePhotoStorage.shared
        var photo = try await storage.getPhoto(id: photoId)
        photo.metadata.removeFromAlbum(albumName)
        try await storage.updateMetadata(id: photoId, metadata: photo.metadata)
    }

    private func sortPhotos(_ photos: [EncryptedPhoto], by order: PhotoSortOrder) -> [EncryptedPhoto] {
        switch order {
        case .dateAddedNewest:
            return photos.sorted { $0.dateAdded > $1.dateAdded }
        case .dateAddedOldest:
            return photos.sorted { $0.dateAdded < $1.dateAdded }
        case .dateTakenNewest:
            return photos.sorted { $0.displayDate > $1.displayDate }
        case .dateTakenOldest:
            return photos.sorted { $0.displayDate < $1.displayDate }
        case .filename:
            return photos.sorted { $0.filename < $1.filename }
        case .fileSize:
            return photos.sorted { $0.metadata.fileSize > $1.metadata.fileSize }
        case .custom:
            return photos // Keep original order for custom
        }
    }
}
