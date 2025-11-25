# Contributing to Lucent

## Architecture Overview

### Core Layers

```
┌─────────────────────────────────────────────────┐
│                   UI Layer                       │
│  (SwiftUI Views, ViewModels)                     │
├─────────────────────────────────────────────────┤
│               Storage Layer                      │
│  SecurePhotoStorage, AlbumManager, TagManager    │
├─────────────────────────────────────────────────┤
│               Security Layer                     │
│  EncryptionManager, KeychainManager, Auth        │
├─────────────────────────────────────────────────┤
│               Platform Layer                     │
│  CryptoKit, LocalAuthentication, FileManager     │
└─────────────────────────────────────────────────┘
```

### Key Components

| Component | Responsibility |
|-----------|----------------|
| `SecurePhotoStorage` | Encrypted photo storage actor |
| `EncryptionManager` | AES-256-GCM encryption/decryption |
| `KeychainManager` | Secure key storage in iOS Keychain |
| `ThumbnailManager` | Thumbnail generation and caching |
| `BiometricAuthManager` | Face ID/Touch ID authentication |
| `PasscodeManager` | Passcode hashing and verification |
| `PrivacyProtectionManager` | Screenshot detection, app preview blur |

### Data Flow

```
Photo Import:
UIImage → JPEG Data → Encrypt(AES-GCM) → Write(.enc file)
                   → Generate Thumbnail → Encrypt → Write(_thumb.enc)
                   → Update photo_index.json

Photo Display:
Read(.enc file) → Decrypt → SecureImage → SwiftUI Image
                         → Wipe on dismiss
```

## Error Handling Guidelines

### Use `throws` for:
- Operations that can fail due to external factors
- Operations that have multiple failure modes
- Async operations
- Storage/network/file system operations

```swift
// ✅ Preferred: Throwing functions
func savePhoto(data: Data) async throws -> EncryptedPhoto
func encrypt(data: Data) throws -> Data
func authenticate(reason: String) async throws -> Bool
```

### Use `Result` when:
- You need to return errors as values (e.g., for combining multiple operations)
- Working with APIs that require Result (Combine, etc.)
- Rare - prefer throws in most cases

```swift
// ✅ Use Result when errors need to be values
func validatePasscode(_ passcode: String) -> Result<Void, ValidationError>
```

### Use `Optional` when:
- Absence of value is expected and not an error
- Searching/finding operations (nil = not found, not an error)
- Never use Optional to hide errors

```swift
// ✅ Optional for "not found" scenarios
func findPhoto(byTag tag: String) -> Photo?  // No photo with that tag (not an error)
```

### Never use `Bool` for:
- Operations that can fail (use throws instead)
- Operations where error information is important

```swift
// ❌ Avoid Bool returns for operations that can fail
func setPasscode(_ passcode: String) -> Bool  // What went wrong? Unknown!

// ✅ Use throws instead
func setPasscode(_ passcode: String) throws  // Caller knows exactly what failed
```

## Error Message Guidelines

### User-facing errors (`errorDescription`)
- Keep messages generic to prevent information leakage
- Don't expose file paths, OSStatus codes, or system details
- Focus on what the user can do

```swift
public var errorDescription: String? {
    switch self {
    case .saveFailed:
        return "Failed to save secure data"  // ✅ Generic
    case .fileReadError:
        return "Failed to read file"  // ✅ No path exposed
    }
}
```

### Debug errors (`debugDescription`)
- Include technical details for logging
- Use with OSLog `privacy: .private`
- Include identifiers, paths, and error codes

```swift
var debugDescription: String {
    switch self {
    case .saveFailed(let status):
        return "Keychain save failed with OSStatus: \(status)"  // ✅ Technical details
    case .fileReadError(let url):
        return "Failed to read file at: \(url.path)"  // ✅ Full path for debugging
    }
}
```

## Concurrency Guidelines

### Use actors for:
- Shared mutable state that needs isolation
- When async/await is acceptable at call sites

### Use `@unchecked Sendable` with locks for:
- Performance-critical synchronous operations
- When blocking behavior is acceptable
- Always document why it's safe:

```swift
public final class EncryptionManager: @unchecked Sendable {
    // Note: @unchecked Sendable is valid because all mutable state access
    // is synchronized through self.queue (a serial DispatchQueue)

    private let queue = DispatchQueue(label: "com.lucent.encryption")
    private var cachedKey: SymmetricKey?  // Protected by queue.sync
}
```

### Use `NSLock` for:
- Simple mutable state in classes
- When you need fine-grained control

```swift
public final class SecureBuffer: @unchecked Sendable {
    // Note: @unchecked Sendable is valid because all mutable state access
    // is synchronized through self.lock (an NSLock)

    private let lock = NSLock()
    private var _data: Data  // Protected by lock
}
```

## Security Guidelines

### Memory Management
- Use `SecureImage` for decrypted photos (auto-wipes on dealloc)
- Use `SecureBuffer` for temporary sensitive data
- Call `.wipe()` explicitly when done with sensitive data
- Clear caches on memory warnings

### Encryption
- Always use AES-256-GCM (authenticated encryption)
- Store keys in Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
- Use biometric protection when available (`.biometryCurrentSet` flag)

### File Permissions
- Directories: `0o700` (owner read/write/execute only)
- Files: `0o600` (owner read/write only)
- Always set permissions immediately after creation

## Dependency Injection Guidelines

### Singleton Pattern with DI Support

The preferred pattern allows both singleton usage and dependency injection:

```swift
public final class EncryptionManager {
    /// Shared singleton for production use
    public static let shared = EncryptionManager()

    private let keychainManager: KeychainManager

    /// Public init for testing and custom configurations
    /// Production code should use `.shared`
    public init(keychainManager: KeychainManager = .shared) {
        self.keychainManager = keychainManager
    }
}
```

**Benefits:**
- ✅ `EncryptionManager.shared` works (production code)
- ✅ `EncryptionManager(keychainManager: mock)` works (testing)
- ✅ No breaking changes for existing code

### When to Use Each Approach

**Use `.shared` singleton when:**
- Writing production code
- Simplicity is more important than flexibility
- No need to mock the dependency

**Use DI (constructor injection) when:**
- Writing unit tests
- Need to control behavior for testing
- Need to inject mock/stub implementations

### Testing with DI

```swift
// Test can inject mock dependencies
func testEncryption() throws {
    let mockKeychain = MockKeychainManager()
    let encryptionManager = EncryptionManager(keychainManager: mockKeychain)

    // Test with controlled behavior
    mockKeychain.retrieveKeyResult = testKeyData
    let encrypted = try encryptionManager.encrypt(data: testData)

    XCTAssertTrue(mockKeychain.retrieveKeyCalled)
}
```

### Classes Supporting DI

The following classes already support dependency injection:
- `EncryptionManager(keychainManager:)`
- `KeychainManager(accessGroup:)`

### Classes Using Private Init (Singletons Only)

These classes currently only support singleton access:
- `SecurePhotoStorage.shared`
- `AlbumManager.shared`
- `TagManager.shared`
- `ThumbnailManager.shared`

**Note:** Converting actors to support DI requires careful consideration of Swift 6 concurrency rules.

## Code Style

### Comments
- Only add comments where logic isn't self-evident
- Don't add comments to code you didn't modify
- Use `// MARK: -` for section headers

### Documentation
- All public APIs should have doc comments
- Include usage examples for complex APIs
- Document thread safety guarantees

### Logging
- Use `AppLogger` (OSLog-based) throughout
- Use `.private` for sensitive data
- Use `.public` for identifiers that aid debugging
