# Authentication System - Quick Start Guide

## Basic Integration (Already Done!)

The authentication system is already integrated into LucentApp.swift. To enable it:

```swift
// In your app or settings view
AppLockManager.shared.enableAppLock()
```

That's it! The authentication overlay will now appear when the app starts or returns from background.

## Quick Examples

### 1. Enable App Lock with Custom Settings

```swift
// Enable with 5-minute timeout
AppLockManager.shared.enableAppLock(
    requireOnLaunch: true,
    timeout: 300
)
```

### 2. Check Authentication Status

```swift
if AppLockManager.shared.isAuthenticated {
    // User is authenticated - show secure content
} else {
    // User needs to authenticate
}
```

### 3. Manual Authentication

```swift
Task {
    let success = await AppLockManager.shared.authenticate(
        reason: "Access your secure photos"
    )
    if success {
        // Proceed with sensitive operation
    }
}
```

### 4. Setup Passcode Programmatically

```swift
let passcodeManager = PasscodeManager()

if passcodeManager.setPasscode("1234") {
    print("Passcode created successfully!")
}
```

### 5. Create a Settings Toggle

```swift
struct SecuritySettingsView: View {
    @StateObject private var appLock = AppLockManager.shared

    var body: some View {
        Form {
            Toggle("Enable App Lock", isOpen: $appLock.isAppLockEnabled)

            if appLock.isAppLockEnabled {
                Picker("Lock After", selection: $appLock.lockTimeout) {
                    Text("Immediately").tag(0.0)
                    Text("1 minute").tag(60.0)
                    Text("5 minutes").tag(300.0)
                    Text("15 minutes").tag(900.0)
                }
            }
        }
    }
}
```

## Testing the System

### Test on Simulator
1. Open Xcode
2. Select "Lucent (iOS)" scheme
3. Run on iPhone simulator
4. Use Features > Face ID > Enrolled to enable Face ID
5. Use Features > Face ID > Matching Face to authenticate

### Test on Device
1. Build to a physical device with Face ID/Touch ID
2. The system will automatically detect available biometrics
3. Fallback to passcode is available if biometrics fail

## Customization

### Change Lock Timeout Options

```swift
// Set immediate lock
AppLockManager.shared.lockTimeout = 0

// Set 1 minute
AppLockManager.shared.lockTimeout = 60

// Set 5 minutes
AppLockManager.shared.lockTimeout = 300
```

### Disable Requiring Auth on Launch

```swift
AppLockManager.shared.requireAuthOnLaunch = false
```

### Check Biometric Type

```swift
let biometricManager = BiometricAuthManager()
biometricManager.checkBiometricAvailability()

switch biometricManager.biometricType {
case .faceID:
    print("Device has Face ID")
case .touchID:
    print("Device has Touch ID")
case .none:
    print("No biometrics available")
}
```

## Common Use Cases

### Protected Settings Screen
```swift
struct ProtectedSettingsView: View {
    @State private var isAuthenticated = false

    var body: some View {
        if isAuthenticated {
            // Show sensitive settings
            settingsContent
        } else {
            AuthenticationView(appLockManager: AppLockManager.shared)
                .onAppear {
                    Task {
                        isAuthenticated = await AppLockManager.shared.authenticate()
                    }
                }
        }
    }
}
```

### Disable App Lock
```swift
Button("Disable App Lock") {
    AppLockManager.shared.disableAppLock()
}
```

### Force Lock Now
```swift
Button("Lock App") {
    AppLockManager.shared.lockApp()
}
```

## Troubleshooting

### Face ID Not Working in Simulator
- Go to Features > Face ID > Enrolled
- Then Features > Face ID > Matching Face to authenticate

### Passcode Not Saving
- Check that passcode is 4-6 digits
- Verify keychain access in entitlements

### App Not Locking
- Make sure `isAppLockEnabled` is set to `true`
- Check that timeout hasn't elapsed

## File Locations

All authentication files are in:
- **Security Logic**: `/Users/sam/Documents/Github/Lucent/Lucent/Shared/Security/Authentication/`
- **UI Views**: `/Users/sam/Documents/Github/Lucent/Lucent/Shared/Views/Authentication/`
- **App Integration**: `/Users/sam/Documents/Github/Lucent/Lucent/Shared/LucentApp.swift`

## Ready to Use!

The authentication system is fully functional and ready to use. Just enable app lock and you're protected!
