# Lucent

A secure photo storage application for iOS, iPadOS, and macOS with a beautiful liquid glass aesthetic.

## Requirements

- iOS 18.0+
- iPadOS 18.0+
- macOS 15.0+
- Xcode 16.0+
- Swift 6.0+

## Project Structure

The project is organized as a multi-platform application with shared code:

```
Lucent/
├── Shared/              # Shared code between platforms
│   ├── LucentApp.swift
│   └── ContentView.swift
├── iOS/                 # iOS-specific resources
│   └── Assets.xcassets
├── macOS/               # macOS-specific resources
│   ├── Assets.xcassets
│   └── Lucent.entitlements
├── LucentTests/         # Unit tests
└── LucentUITests/       # UI tests
```

## Features

- Multi-platform support (iOS, iPadOS, macOS)
- SwiftUI-based modern interface
- SwiftUI App lifecycle (no AppDelegate/SceneDelegate)
- Secure photo storage
- Unit and UI testing support

## Building

1. Open `Lucent.xcodeproj` in Xcode
2. Select the desired target:
   - Lucent (iOS)
   - Lucent (macOS)
3. Choose your destination (Simulator, Device, or Mac)
4. Press Cmd+R to build and run

## Testing

The project includes both Unit Tests and UI Tests:

- Unit Tests: `LucentTests`
- UI Tests: `LucentUITests`

Run tests with Cmd+U or through the Test Navigator.

## License

Copyright (c) 2024. All rights reserved.
