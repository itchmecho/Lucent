//
//  Strings.swift
//  Lucent
//
//  Centralized localization strings for type-safe access
//

import Foundation

/// Type-safe access to localized strings throughout the app
enum L10n {

    // MARK: - Common

    enum Common {
        static let appName = String(localized: "common.app_name", defaultValue: "Lucent")
        static let ok = String(localized: "common.ok", defaultValue: "OK")
        static let cancel = String(localized: "common.cancel", defaultValue: "Cancel")
        static let done = String(localized: "common.done", defaultValue: "Done")
        static let delete = String(localized: "common.delete", defaultValue: "Delete")
        static let confirm = String(localized: "common.confirm", defaultValue: "Confirm")
        static let error = String(localized: "common.error", defaultValue: "Error")
        static let success = String(localized: "common.success", defaultValue: "Success")
        static let loading = String(localized: "common.loading", defaultValue: "Loading...")
        static let save = String(localized: "common.save", defaultValue: "Save")
        static let edit = String(localized: "common.edit", defaultValue: "Edit")
        static let add = String(localized: "common.add", defaultValue: "Add")
        static let create = String(localized: "common.create", defaultValue: "Create")
        static let move = String(localized: "common.move", defaultValue: "Move")
        static let export = String(localized: "common.export", defaultValue: "Export")
        static let share = String(localized: "common.share", defaultValue: "Share")
        static let new = String(localized: "common.new", defaultValue: "New")
        static let unknown = String(localized: "common.unknown", defaultValue: "Unknown")
    }

    // MARK: - Tabs

    enum Tabs {
        static let photos = String(localized: "tabs.photos", defaultValue: "Photos")
        static let settings = String(localized: "tabs.settings", defaultValue: "Settings")
        static let albums = String(localized: "tabs.albums", defaultValue: "Albums")
    }

    // MARK: - Photos

    enum Photos {
        static let title = String(localized: "photos.title", defaultValue: "Photos")
        static let noPhotosTitle = String(localized: "photos.no_photos_title", defaultValue: "No Photos Yet")
        static let noPhotosMessage = String(localized: "photos.no_photos_message", defaultValue: "Your secure photo vault is ready.\nTap the + button to add photos.")
        static let loadingPhoto = String(localized: "photos.loading_photo", defaultValue: "Loading photo...")
        static let deletePhotoTitle = String(localized: "photos.delete_photo_title", defaultValue: "Delete Photo")
        static let deletePhotoMessage = String(localized: "photos.delete_photo_message", defaultValue: "Are you sure you want to delete this photo? This action cannot be undone.")

        static func deletePhotosTitle(_ count: Int) -> String {
            count == 1
                ? String(localized: "photos.delete_photo_title", defaultValue: "Delete Photo?")
                : String(format: String(localized: "photos.delete_photos_title", defaultValue: "Delete %d Photos?"), count)
        }

        static func deletePhotosMessage(_ count: Int) -> String {
            count == 1
                ? String(localized: "photos.delete_single_message", defaultValue: "This photo will be permanently deleted. This action cannot be undone.")
                : String(format: String(localized: "photos.delete_multiple_message", defaultValue: "These %d photos will be permanently deleted. This action cannot be undone."), count)
        }

        static func exportPhotosTitle(_ count: Int) -> String {
            count == 1
                ? String(localized: "photos.export_photo_title", defaultValue: "Export Photo?")
                : String(format: String(localized: "photos.export_photos_title", defaultValue: "Export %d Photos?"), count)
        }

        static func exportPhotosMessage(_ count: Int) -> String {
            count == 1
                ? String(localized: "photos.export_single_message", defaultValue: "This photo will be decrypted and saved to your photo library.")
                : String(format: String(localized: "photos.export_multiple_message", defaultValue: "These %d photos will be decrypted and saved to your photo library."), count)
        }

        static let exportToLibrary = String(localized: "photos.export_to_library", defaultValue: "Export to Photo Library")

        static func photoCount(_ count: Int) -> String {
            count == 1
                ? String(localized: "photos.photo_count_single", defaultValue: "1 photo")
                : String(format: String(localized: "photos.photo_count", defaultValue: "%d photos"), count)
        }
    }

    // MARK: - Import

    enum Import {
        static let addPhotos = String(localized: "import.add_photos", defaultValue: "Add Photos")
        static let chooseMethod = String(localized: "import.choose_method", defaultValue: "Choose how to add photos to your vault")
        static let selectFromLibrary = String(localized: "import.select_from_library", defaultValue: "Select from Library")
        static let takePhoto = String(localized: "import.take_photo", defaultValue: "Take Photo")
        static let importing = String(localized: "import.importing", defaultValue: "Importing...")

        static func importingProgress(_ current: Int, _ total: Int) -> String {
            String(format: String(localized: "import.importing_progress", defaultValue: "Importing %d of %d"), current, total)
        }

        static let importComplete = String(localized: "import.import_complete", defaultValue: "Import Complete")
        static let permissionRequired = String(localized: "import.permission_required", defaultValue: "Photo Library Access Required")
        static let permissionMessage = String(localized: "import.permission_message", defaultValue: "Lucent needs access to your photo library to import photos.")
        static let openSettings = String(localized: "import.open_settings", defaultValue: "Open Settings")
    }

    // MARK: - Albums

    enum Albums {
        static let title = String(localized: "albums.title", defaultValue: "Albums")
        static let library = String(localized: "albums.library", defaultValue: "Library")
        static let myAlbums = String(localized: "albums.my_albums", defaultValue: "My Albums")
        static let noAlbumsTitle = String(localized: "albums.no_albums_title", defaultValue: "No Albums Yet")
        static let noAlbumsMessage = String(localized: "albums.no_albums_message", defaultValue: "Create your first album to organize your photos")
        static let createAlbum = String(localized: "albums.create_album", defaultValue: "Create Album")
        static let deleteAlbum = String(localized: "albums.delete_album", defaultValue: "Delete Album")
        static let albumName = String(localized: "albums.album_name", defaultValue: "Album Name")
        static let enterAlbumName = String(localized: "albums.enter_album_name", defaultValue: "Enter album name")
        static let description = String(localized: "albums.description", defaultValue: "Description")
        static let enterDescription = String(localized: "albums.enter_description", defaultValue: "Enter a description")

        // System albums
        static let allPhotos = String(localized: "albums.all_photos", defaultValue: "All Photos")
        static let favorites = String(localized: "albums.favorites", defaultValue: "Favorites")
        static let recents = String(localized: "albums.recents", defaultValue: "Recents")

        static let moveToAlbum = String(localized: "albums.move_to_album", defaultValue: "Move to Album")
        static let createNewAlbum = String(localized: "albums.create_new_album", defaultValue: "Create New Album")
        static let photosToMove = String(localized: "albums.photos_to_move", defaultValue: "Photos to Move")
    }

    // MARK: - Tags

    enum Tags {
        static let title = String(localized: "tags.title", defaultValue: "Tags")
        static let addTags = String(localized: "tags.add_tags", defaultValue: "Add Tags")
        static let tagName = String(localized: "tags.tag_name", defaultValue: "Tag Name")
        static let createNewTag = String(localized: "tags.create_new_tag", defaultValue: "Create New Tag")
        static let selectedTags = String(localized: "tags.selected_tags", defaultValue: "Selected Tags")
        static let photosToTag = String(localized: "tags.photos_to_tag", defaultValue: "Photos to Tag")
    }

    // MARK: - Authentication

    enum Auth {
        static let photosProtected = String(localized: "auth.photos_protected", defaultValue: "Your photos are protected")
        static let usePasscode = String(localized: "auth.use_passcode", defaultValue: "Use Passcode")

        static func unlockWith(_ method: String) -> String {
            String(format: String(localized: "auth.unlock_with", defaultValue: "Unlock with %@"), method)
        }

        static let unlockReason = String(localized: "auth.unlock_reason", defaultValue: "Unlock Lucent to access your photos")

        // Biometric types
        static let faceID = String(localized: "auth.face_id", defaultValue: "Face ID")
        static let touchID = String(localized: "auth.touch_id", defaultValue: "Touch ID")
        static let opticID = String(localized: "auth.optic_id", defaultValue: "Optic ID")
        static let biometrics = String(localized: "auth.biometrics", defaultValue: "Biometrics")

        // Passcode
        static let enterPasscode = String(localized: "auth.enter_passcode", defaultValue: "Enter Passcode")
        static let createPasscode = String(localized: "auth.create_passcode", defaultValue: "Create Passcode")
        static let confirmPasscode = String(localized: "auth.confirm_passcode", defaultValue: "Confirm Passcode")
        static let wrongPasscode = String(localized: "auth.wrong_passcode", defaultValue: "Wrong Passcode")
        static let passcodeMismatch = String(localized: "auth.passcode_mismatch", defaultValue: "Passcodes don't match")
    }

    // MARK: - Settings

    enum Settings {
        static let title = String(localized: "settings.title", defaultValue: "Settings")

        // Sections
        static let security = String(localized: "settings.security", defaultValue: "Security")
        static let storage = String(localized: "settings.storage", defaultValue: "Storage")
        static let appearance = String(localized: "settings.appearance", defaultValue: "Appearance")
        static let backupData = String(localized: "settings.backup_data", defaultValue: "Backup & Data")
        static let about = String(localized: "settings.about", defaultValue: "About")

        // Security
        static let autoLock = String(localized: "settings.auto_lock", defaultValue: "Auto-lock")
        static let autoLockTimer = String(localized: "settings.auto_lock_timer", defaultValue: "Auto-lock Timer")

        static func useBiometricToUnlock(_ biometric: String) -> String {
            String(format: String(localized: "settings.use_biometric_to_unlock", defaultValue: "Use %@ to unlock"), biometric)
        }

        static let changePasscode = String(localized: "settings.change_passcode", defaultValue: "Change Passcode")
        static let requireOnLaunch = String(localized: "settings.require_on_launch", defaultValue: "Require on Launch")
        static let lockWhenAppCloses = String(localized: "settings.lock_when_app_closes", defaultValue: "Lock when app closes")

        // Auto-lock options
        static let immediate = String(localized: "settings.immediate", defaultValue: "Immediate")
        static let oneMinute = String(localized: "settings.one_minute", defaultValue: "1 Minute")
        static let fiveMinutes = String(localized: "settings.five_minutes", defaultValue: "5 Minutes")
        static let fifteenMinutes = String(localized: "settings.fifteen_minutes", defaultValue: "15 Minutes")
        static let never = String(localized: "settings.never", defaultValue: "Never")

        // Storage
        static let totalStorage = String(localized: "settings.total_storage", defaultValue: "Total Storage")
        static let photosStored = String(localized: "settings.photos_stored", defaultValue: "Photos Stored")
        static let clearThumbnailCache = String(localized: "settings.clear_thumbnail_cache", defaultValue: "Clear Thumbnail Cache")
        static let clearCacheMessage = String(localized: "settings.clear_cache_message", defaultValue: "This will clear cached thumbnails and free up space. Thumbnails will be regenerated when needed.")
        static let cacheCleared = String(localized: "settings.cache_cleared", defaultValue: "Thumbnail cache has been cleared.")

        // Appearance
        static let system = String(localized: "settings.system", defaultValue: "System")
        static let light = String(localized: "settings.light", defaultValue: "Light")
        static let dark = String(localized: "settings.dark", defaultValue: "Dark")
        static let showPhotoCounts = String(localized: "settings.show_photo_counts", defaultValue: "Show Photo Counts")
        static let displayCountsOnAlbums = String(localized: "settings.display_counts_on_albums", defaultValue: "Display counts on albums")
        static let showThumbnails = String(localized: "settings.show_thumbnails", defaultValue: "Show Thumbnails")
        static let displayPhotoPreviewsInGrid = String(localized: "settings.display_photo_previews_in_grid", defaultValue: "Display photo previews in grid")

        // Backup & Data
        static let exportMetadata = String(localized: "settings.export_metadata", defaultValue: "Export Metadata")
        static let nonSensitiveDataOnly = String(localized: "settings.non_sensitive_data_only", defaultValue: "Non-sensitive data only")
        static let exportMetadataMessage = String(localized: "settings.export_metadata_message", defaultValue: "This will export non-sensitive metadata (dates, tags, albums) to a file. Photos and encryption keys will NOT be included.")
        static let localStorageOnly = String(localized: "settings.local_storage_only", defaultValue: "Local Storage Only")
        static let localStorageWarning = String(localized: "settings.local_storage_warning", defaultValue: "Photos are stored only on this device. Back up your device regularly.")

        // About
        static let version = String(localized: "settings.version", defaultValue: "Version")
        static let build = String(localized: "settings.build", defaultValue: "Build")
        static let privacyPolicy = String(localized: "settings.privacy_policy", defaultValue: "Privacy Policy")
        static let privacyMessage = String(localized: "settings.privacy_message", defaultValue: "Lucent is committed to your privacy. All photos are stored locally on your device with end-to-end encryption. No data is collected or transmitted.")
        static let openSourceLicenses = String(localized: "settings.open_source_licenses", defaultValue: "Open Source Licenses")
        static let licensesMessage = String(localized: "settings.licenses_message", defaultValue: "This app is built with open source software. License information will be available in a future update.")
        static let madeWithCare = String(localized: "settings.made_with_care", defaultValue: "Made with care for your privacy")

        // Change passcode
        static let changePasscodeTitle = String(localized: "settings.change_passcode_title", defaultValue: "Change Passcode")
        static let changePasscodeMessage = String(localized: "settings.change_passcode_message", defaultValue: "This feature will allow you to change your passcode. Implementation coming soon.")
    }

    // MARK: - Alerts

    enum Alerts {
        static let operationFailed = String(localized: "alerts.operation_failed", defaultValue: "Operation Failed")
        static let unknownError = String(localized: "alerts.unknown_error", defaultValue: "An unknown error occurred")
        static let operationSuccess = String(localized: "alerts.operation_success", defaultValue: "Operation completed successfully")
    }

    // MARK: - Metadata

    enum Metadata {
        static let dateAdded = String(localized: "metadata.date_added", defaultValue: "Date Added")
        static let dateTaken = String(localized: "metadata.date_taken", defaultValue: "Date Taken")
        static let location = String(localized: "metadata.location", defaultValue: "Location")
        static let camera = String(localized: "metadata.camera", defaultValue: "Camera")
        static let dimensions = String(localized: "metadata.dimensions", defaultValue: "Dimensions")
        static let fileSize = String(localized: "metadata.file_size", defaultValue: "File Size")
        static let format = String(localized: "metadata.format", defaultValue: "Format")
    }

    // MARK: - Slideshow

    enum Slideshow {
        static let play = String(localized: "slideshow.play", defaultValue: "Play")
        static let pause = String(localized: "slideshow.pause", defaultValue: "Pause")
        static let exit = String(localized: "slideshow.exit", defaultValue: "Exit Slideshow")
    }

    // MARK: - Search

    enum Search {
        static let title = String(localized: "search.title", defaultValue: "Search")
        static let placeholder = String(localized: "search.placeholder", defaultValue: "Search photos...")
        static let noResults = String(localized: "search.no_results", defaultValue: "No Results")
        static let noResultsMessage = String(localized: "search.no_results_message", defaultValue: "Try searching with different terms")
    }
}
