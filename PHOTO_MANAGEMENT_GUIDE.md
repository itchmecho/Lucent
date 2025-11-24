# Photo Management Features - Implementation Guide

## Overview

This guide documents the Phase 3 Management features implemented for Lucent. These features provide comprehensive photo management capabilities including deletion, organization, export, and sharing.

## Architecture

### Core Managers

#### 1. PhotoManagementManager
**Location**: `/Lucent/Shared/Storage/PhotoManagementManager.swift`

Handles core photo operations:
- Single and batch photo deletion
- Moving photos to/from albums
- Toggling favorites
- Adding/removing tags
- All operations use secure deletion (DOD 5220.22-M standard)

**Usage**:
```swift
// Delete a photo
try await PhotoManagementManager.shared.deletePhoto(id: photoId)

// Move to album
try await PhotoManagementManager.shared.moveToAlbum(
    photoId: photoId,
    albumName: "Vacation"
)

// Toggle favorite
let isFavorite = try await PhotoManagementManager.shared.toggleFavorite(photoId: photoId)

// Add tag
try await PhotoManagementManager.shared.addTag(to: photoId, tag: "Nature")

// Batch operations
let results = await PhotoManagementManager.shared.deletePhotos(ids: photoIds)
```

#### 2. ExportManager
**Location**: `/Lucent/Shared/Storage/ExportManager.swift`

Manages secure photo export to device photo library:
- Permission management
- Single and batch export
- Temporary file export for sharing
- Automatic memory cleanup after export

**Usage**:
```swift
// Check/request permission
let hasPermission = ExportManager.shared.checkPhotoLibraryPermission()
let granted = await ExportManager.shared.requestPhotoLibraryPermission()

// Export to photo library
try await ExportManager.shared.exportPhoto(id: photoId)

// Batch export
let results = await ExportManager.shared.exportPhotos(ids: photoIds)

// Export to temporary file (for sharing)
let tempURL = try await ExportManager.shared.exportToTemporaryFile(photoId: photoId)
// ... use tempURL ...
await ExportManager.shared.cleanupTemporaryFile(at: tempURL)
```

#### 3. ShareManager
**Location**: `/Lucent/Shared/Storage/ShareManager.swift`

Handles secure photo sharing with automatic cleanup:
- Prepares photos for sharing by decrypting to temp files
- Tracks active temporary files
- Provides SwiftUI share sheet integration
- Automatic cleanup after sharing

**Usage**:
```swift
// Prepare single photo
let shareResult = try await ShareManager.shared.preparePhotoForSharing(photoId: photoId)

// Present share sheet (iOS)
let activityVC = ShareManager.shared.createShareSheet(for: [shareResult])

// Clean up after sharing
await ShareManager.shared.cleanupSharedPhoto(shareResult)

// SwiftUI integration
.shareSheet(
    isPresented: $showShareSheet,
    shareResult: shareResult,
    onDismiss: {
        Task {
            await ShareManager.shared.cleanupSharedPhoto(shareResult)
        }
    }
)
```

### View Models

#### MultiSelectViewModel
**Location**: `/Lucent/Shared/ViewModels/MultiSelectViewModel.swift`

Manages multi-select state and batch operations:
- Selection state management
- Batch operations (delete, export, move, favorite, tag)
- Progress tracking
- Error handling

**Usage**:
```swift
@StateObject private var multiSelect = MultiSelectViewModel()

// Toggle multi-select mode
multiSelect.toggleMultiSelectMode()

// Select/deselect photos
multiSelect.toggleSelection(for: photoId)
multiSelect.selectAll(photos)
multiSelect.deselectAll()

// Batch operations
await multiSelect.deleteSelected()
await multiSelect.exportSelected()
await multiSelect.moveSelectedToAlbum("Vacation")
await multiSelect.setSelectedFavorites(true)
await multiSelect.addTagsToSelected(["Nature", "Landscape"])

// Prepare for sharing
if let shareResults = await multiSelect.prepareSelectedForSharing() {
    // Show share sheet
}
```

### UI Components

#### 1. PhotoActionsView
**Location**: `/Lucent/Shared/Views/Components/PhotoActionsView.swift`

Action menu for single photo operations:
- Favorite/unfavorite
- Move to album
- Add tags
- Share
- Export
- Delete

**Usage**:
```swift
.sheet(isPresented: $showActions) {
    PhotoActionsView(photo: photo, onAction: { action in
        switch action {
        case .favorite:
            // Handle favorite
        case .share:
            // Handle share
        // ... etc
        }
    })
}

// Or use context menu
.photoContextMenu(photo: photo, onAction: handleAction)
```

#### 2. BatchActionsView
**Location**: `/Lucent/Shared/Views/Components/PhotoActionsView.swift`

Action menu for multiple selected photos:
- Add/remove favorites
- Move to album
- Add tags
- Share
- Export
- Delete

**Usage**:
```swift
.sheet(isPresented: $showBatchActions) {
    BatchActionsView(
        selectedCount: multiSelect.selectedCount,
        onAction: handleBatchAction
    )
}
```

#### 3. Confirmation Dialogs
**Location**: `/Lucent/Shared/Views/Components/ConfirmationDialogs.swift`

Reusable confirmation dialogs for destructive operations:
- Delete confirmation
- Export confirmation
- Move to album sheet
- Add tags sheet
- Operation progress view
- Error/success alerts

**Usage**:
```swift
// Delete confirmation
.deletePhotoConfirmation(
    isPresented: $showDeleteConfirmation,
    photoCount: selectedCount,
    onConfirm: {
        // Perform deletion
    }
)

// Export confirmation
.exportPhotoConfirmation(
    isPresented: $showExportConfirmation,
    photoCount: selectedCount,
    onConfirm: {
        // Perform export
    }
)

// Move to album
.sheet(isPresented: $showMoveToAlbum) {
    MoveToAlbumSheet(
        availableAlbums: albums,
        photoCount: selectedCount,
        onMove: { albumName in
            // Move photos
        }
    )
}

// Add tags
.sheet(isPresented: $showAddTags) {
    AddTagsSheet(
        availableTags: tags,
        photoCount: selectedCount,
        onAddTags: { tags in
            // Add tags
        }
    )
}
```

## Security Features

### 1. Secure Deletion
All photo deletions use the DOD 5220.22-M standard:
- 3-pass overwrite with random data
- Thumbnail also securely deleted
- Metadata cleaned from index
- Memory cleared

### 2. Export Security
- Photos decrypted only when needed
- Decrypted data cleared from memory after export
- Temporary files use secure deletion
- No caching of decrypted images

### 3. Share Security
- Temporary files tracked and cleaned up
- Automatic cleanup on app termination
- Share sheet excludes risky activities
- Memory cleared after sharing

## Integration Example

See `/Lucent/Shared/Views/PhotoManagementExampleView.swift` for a complete working example.

### Basic Integration Steps

1. **Add MultiSelectViewModel to your view**:
```swift
@StateObject private var multiSelect = MultiSelectViewModel()
```

2. **Add toolbar for multi-select mode**:
```swift
.toolbar {
    ToolbarItem(placement: .topBarTrailing) {
        if multiSelect.isMultiSelectMode {
            Button("Actions") {
                showBatchActions = true
            }
        } else {
            Button("Select") {
                multiSelect.toggleMultiSelectMode()
            }
        }
    }
}
```

3. **Handle photo tap in grid**:
```swift
.onTapGesture {
    if multiSelect.isMultiSelectMode {
        multiSelect.toggleSelection(for: photo.id)
    } else {
        // Open photo viewer
    }
}
```

4. **Add long press for multi-select**:
```swift
.onLongPressGesture {
    multiSelect.enterMultiSelectMode(selecting: photo.id)
}
```

5. **Show actions and confirmations**:
```swift
.sheet(isPresented: $showActions) {
    PhotoActionsView(photo: photo, onAction: handleAction)
}
.deletePhotoConfirmation(
    isPresented: $showDeleteConfirmation,
    photoCount: multiSelect.selectedCount,
    onConfirm: { await multiSelect.deleteSelected() }
)
```

## Best Practices

### 1. Always Clean Up Share Results
```swift
.shareSheet(
    isPresented: $showShareSheet,
    shareResults: shareResults ?? [],
    onDismiss: {
        Task {
            if let results = shareResults {
                await ShareManager.shared.cleanupPreparedPhotos(results)
            }
        }
    }
)
```

### 2. Handle Errors Gracefully
```swift
.operationErrorAlert(
    isPresented: .constant(multiSelect.errorMessage != nil),
    error: multiSelect.errorMessage
)
```

### 3. Show Progress for Long Operations
```swift
if multiSelect.isOperationInProgress {
    OperationProgressView(operation: "Deleting photos...")
}
```

### 4. Request Permissions Before Export
```swift
private func handleExport() {
    Task {
        if !ExportManager.shared.checkPhotoLibraryPermission() {
            let granted = await ExportManager.shared.requestPhotoLibraryPermission()
            guard granted else {
                // Show permission denied message
                return
            }
        }
        try await ExportManager.shared.exportPhoto(id: photoId)
    }
}
```

### 5. Batch Operations Return Results
```swift
let results = await multiSelect.deleteSelected()
// results is a dictionary: [UUID: Result<Void, Error>]
// Check results for partial failures
```

## Testing Checklist

- [ ] Single photo deletion works
- [ ] Batch photo deletion works
- [ ] Move to existing album works
- [ ] Create new album and move works
- [ ] Add existing tags works
- [ ] Create new tags and add works
- [ ] Single photo export works
- [ ] Batch photo export works
- [ ] Photo library permission request works
- [ ] Single photo share works
- [ ] Batch photo share works
- [ ] Share cleanup happens after dismissal
- [ ] Multi-select mode toggles correctly
- [ ] Selection state updates in real-time
- [ ] Context menu shows correct actions
- [ ] Confirmation dialogs appear for destructive actions
- [ ] Error messages display correctly
- [ ] Success messages display correctly
- [ ] Progress indicators show during operations
- [ ] Memory is cleared after export/share
- [ ] Temporary files are cleaned up

## Future Enhancements

1. **Undo/Redo**: Add operation history for undoing deletions
2. **Smart Albums**: Dynamic albums based on metadata/tags
3. **Bulk Import**: Import multiple photos at once
4. **Advanced Filters**: Filter by date range, tags, albums
5. **Photo Editing**: Basic editing before export/share
6. **AirDrop Integration**: Direct AirDrop support
7. **Cloud Backup**: Optional encrypted cloud backup
8. **Duplicate Detection**: Identify and merge duplicates

## Performance Considerations

- Batch operations process photos sequentially to avoid memory spikes
- Thumbnails cached separately from full images
- Metadata operations don't load full photo data
- Secure deletion runs on background queue
- Share preparation happens asynchronously
- Export manager handles permission caching

## Troubleshooting

### Photos not deleting
- Check SecurePhotoStorage.deletePhoto() logs
- Verify file permissions
- Ensure photo exists in index

### Export failing
- Check photo library permissions in Settings
- Verify decrypted data is valid image
- Check available storage space

### Share not working
- Ensure temporary directory is accessible
- Check cleanup is happening after share
- Verify ShareManager active files list

### Multi-select state issues
- Ensure MultiSelectViewModel is @StateObject
- Check selection changes propagate to UI
- Verify exitMultiSelectMode() is called

## File Locations Summary

```
Lucent/Shared/
├── Storage/
│   ├── PhotoManagementManager.swift    # Core management operations
│   ├── ExportManager.swift              # Export to photo library
│   └── ShareManager.swift               # Share with cleanup
├── ViewModels/
│   └── MultiSelectViewModel.swift       # Multi-select state
├── Views/
│   ├── Components/
│   │   ├── PhotoActionsView.swift      # Action menus
│   │   └── ConfirmationDialogs.swift   # Confirmation UI
│   └── PhotoManagementExampleView.swift # Integration example
└── Models/
    ├── EncryptedPhoto.swift
    ├── PhotoMetadata.swift
    └── Album.swift
```
