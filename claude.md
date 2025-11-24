# PhotoKeepSafe - Claude Project Guidelines

**See workspace communication & development guidelines**: [../CLAUDE.md](../CLAUDE.md) and [../CLAUDE-GUIDELINES.md](../CLAUDE-GUIDELINES.md)

This file contains project-specific information. General guidelines are documented in the workspace root.

## Project Management

**📋 IMPORTANT**: [PROJECT-ROADMAP.md](PROJECT-ROADMAP.md) contains the complete task list and development phases.
- **Always check and update the roadmap** when completing tasks or making significant progress
- Mark tasks as complete with [x] when done
- Add notes and decisions to the appropriate sections
- This is the user's first iOS/iPadOS/macOS app - provide clear guidance

## Project Overview

A Swift-based iOS/iPadOS/macOS app for securely storing photos locally with advanced encryption, replacing the stock 'hidden' feature with true security-first design and modern liquid glass aesthetics.

## Key Features

- **Security First**: End-to-end encryption for all stored photos with biometric authentication
- **Local Storage**: All photos stored locally on device, no cloud dependency
- **Liquid Glass UI**: Modern, translucent interface using latest iOS design patterns
- **Universal App**: Native support for iPhone, iPad, and Mac (Catalyst or SwiftUI)
- **Privacy Focused**: No analytics, no tracking, no external data transmission

## Technology Stack

- **Language**: Swift (latest stable version)
- **Framework**: SwiftUI for cross-platform UI
- **Security**: CryptoKit for encryption, LocalAuthentication for biometrics
- **Storage**: Core Data or FileManager for encrypted photo storage
- **Target Platforms**: iOS 18+, iPadOS 18+, macOS 15 (Sequoia)+
- **Design**: Leverages latest iOS 18 features and design language

## File Structure

```
PhotoKeepSafe/
├── PhotoKeepSafe/              # Main app target
│   ├── App/                    # App lifecycle and configuration
│   ├── Views/                  # SwiftUI views
│   │   ├── Components/        # Reusable UI components (liquid glass)
│   │   └── Screens/           # Main app screens
│   ├── Models/                # Data models
│   ├── Security/              # Encryption and authentication logic
│   ├── Storage/               # Photo storage management
│   └── Resources/             # Assets, colors, fonts
├── PhotoKeepSafeTests/        # Unit tests
└── PhotoKeepSafeUITests/      # UI tests
```

## Important Notes

- **SECURITY IS PARAMOUNT**: All photo data must be encrypted at rest
- **No Compromises**: Never trade security for convenience or features
- **Biometric Lock**: App requires Face ID/Touch ID for access
- **Screenshot Protection**: Implement screenshot detection and warnings
- **Memory Security**: Clear photo data from memory when app backgrounds
- **Liquid Glass Aesthetic**: Use translucent backgrounds, blur effects, depth, and subtle animations

## Common Development Tasks

### Building the Project

```bash
xcodebuild -scheme PhotoKeepSafe -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build
```

### Testing

```bash
# Run all tests
xcodebuild test -scheme PhotoKeepSafe -destination 'platform=iOS Simulator,name=iPhone 15 Pro'

# Security tests must pass before any commit
xcodebuild test -scheme PhotoKeepSafe -only-testing:PhotoKeepSafeTests/SecurityTests
```

### Code Signing & Distribution

- Development: Use automatic signing for testing
- Release: Manual signing with distribution certificate
- Target: App Store distribution (future TestFlight beta)

## Versioning

This project uses semantic versioning:
- Version is stored in Xcode project settings (MARKETING_VERSION)
- Build number in CFBundleVersion
- Update both version and build number for releases
- Document changes in release notes

## Security Requirements Checklist

- [ ] All photos encrypted with AES-256
- [ ] Biometric authentication required on app launch
- [ ] Secure enclave key storage
- [ ] Photo thumbnails also encrypted
- [ ] App locks when backgrounded
- [ ] Screenshot detection implemented
- [ ] No photo data in app previews/screenshots
- [ ] Memory cleared on app termination
- [ ] No logging of sensitive data
- [ ] Security audit before v1.0 release

## Design Guidelines

### Liquid Glass Aesthetic
- Use `.ultraThinMaterial` and `.thinMaterial` backgrounds
- Implement blur effects with `VisualEffectView`
- Layer translucent cards with subtle shadows
- Smooth, physics-based animations
- Depth through layering and parallax
- Vibrant colors behind frosted glass surfaces
- Rounded corners and soft edges throughout

## Additional Resources

- [Apple CryptoKit Documentation](https://developer.apple.com/documentation/cryptokit)
- [SwiftUI Design Guidelines](https://developer.apple.com/design/human-interface-guidelines/designing-for-ios)
- [Local Authentication Framework](https://developer.apple.com/documentation/localauthentication)
