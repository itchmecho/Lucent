# PhotoKeepSafe - Xcode Project Setup Instructions

Since Xcode's project file format is complex and creating it manually can be error-prone, follow these instructions to create the project correctly using Xcode's GUI.

## Creating the Project in Xcode

### Step 1: Create New Project

1. Open Xcode
2. Select **File > New > Project** (or press Cmd+Shift+N)
3. In the template chooser:
   - Select **Multiplatform** tab at the top
   - Choose **App** template
   - Click **Next**

### Step 2: Configure Project Options

Enter the following settings exactly:

- **Product Name:** `PhotoKeepSafe`
- **Team:** Leave blank or select your team if you have one
- **Organization Identifier:** `com.photokeepsafe` (or your own)
- **Bundle Identifier:** Will auto-populate as `com.photokeepsafe.app`
- **Interface:** Select **SwiftUI**
- **Language:** Select **Swift**
- **Storage:** CoreData (uncheck)
- **Include Tests:** Check this box

Click **Next**

### Step 3: Choose Location

1. Navigate to: `/Users/sam/Documents/github/`
2. In the "Save As" field, it should show `PhotoKeepSafe`
3. **IMPORTANT:** Uncheck "Create Git repository" (since we already have one)
4. Click **Create**

### Step 4: Configure Deployment Targets

For **iOS Target:**
1. Select the project in the Project Navigator (blue icon at top)
2. Select the **PhotoKeepSafe (iOS)** target
3. In the **General** tab:
   - Set **Minimum Deployments** to **iOS 18.0**
   - Under **Supported Destinations**, ensure iPhone and iPad are checked

For **macOS Target:**
1. Select the **PhotoKeepSafe (macOS)** target
2. In the **General** tab:
   - Set **Minimum Deployments** to **macOS 15.0**

### Step 5: Configure Build Settings

1. Select the project (not a target) in the Project Navigator
2. Select the **Build Settings** tab
3. Search for "Swift Language Version"
4. Set it to **Swift 6** for all targets

### Step 6: Verify Test Targets

Make sure the following test targets exist:
- PhotoKeepSafeTests (iOS)
- PhotoKeepSafeTests (macOS)
- PhotoKeepSafeUITests (iOS)
- PhotoKeepSafeUITests (macOS)

If they don't all exist, Xcode should have created at least iOS versions automatically.

### Step 7: Move Existing Files (If Any)

If you already have code files in the directory:

1. In Xcode's Project Navigator, right-click on the `PhotoKeepSafe` group
2. Select **Add Files to "PhotoKeepSafe"...**
3. Select the files you want to add
4. Make sure to:
   - Check "Copy items if needed" (if you want duplicates removed)
   - Select the appropriate targets (iOS and/or macOS)

## Verifying the Setup

### Build Each Platform

1. **For iOS:**
   - Select scheme: **PhotoKeepSafe (iOS)** from the scheme dropdown
   - Select a simulator or device
   - Press Cmd+B to build
   - Press Cmd+R to run

2. **For macOS:**
   - Select scheme: **PhotoKeepSafe (macOS)** from the scheme dropdown
   - Select "My Mac"
   - Press Cmd+B to build
   - Press Cmd+R to run

### Run Tests

1. Press Cmd+U to run all tests
2. Or use Product > Test

## Project Structure

Your final project structure should look like this:

```
PhotoKeepSafe/
├── PhotoKeepSafe.xcodeproj/
│   ├── project.pbxproj
│   └── project.xcworkspace/
├── PhotoKeepSafe/
│   ├── PhotoKeepSafeApp.swift      # Main app entry point
│   ├── ContentView.swift            # Main view
│   ├── Assets.xcassets (iOS)/       # iOS assets
│   ├── Assets.xcassets (macOS)/     # macOS assets
│   └── PhotoKeepSafe.entitlements   # macOS entitlements
├── PhotoKeepSafeTests/
│   └── PhotoKeepSafeTests.swift
├── PhotoKeepSafeUITests/
│   ├── PhotoKeepSafeUITests.swift
│   └── PhotoKeepSafeUITestsLaunchTests.swift
├── .gitignore
└── README.md
```

## Key Features Confirmed

- **Platform Support:** iOS 18+, iPadOS 18+, macOS 15+
- **UI Framework:** SwiftUI
- **App Lifecycle:** SwiftUI App (not AppDelegate)
- **Language:** Swift 6
- **Testing:** Unit Tests and UI Tests included
- **Multi-platform:** Shared code between iOS and macOS

## Troubleshooting

### If the project already exists in the location:

Xcode will warn you. You have two options:
1. Delete the existing files first
2. Choose a different location and manually move files later

### If build fails:

1. Clean build folder: **Product > Clean Build Folder** (Cmd+Shift+K)
2. Delete derived data: **Xcode > Settings > Locations > Derived Data** and click the arrow to open in Finder, then delete
3. Restart Xcode

### If schemes are missing:

1. Select **Product > Scheme > Manage Schemes**
2. Click the + button to add missing schemes
3. Ensure "Show" is checked for all schemes you want to use

## Alternative: Using xcodegen

If you prefer automation, you can use `xcodegen`:

1. Install xcodegen: `brew install xcodegen`
2. Create a `project.yml` file (see below)
3. Run: `xcodegen generate`

### project.yml for xcodegen:

```yaml
name: PhotoKeepSafe
options:
  bundleIdPrefix: com.photokeepsafe
  deploymentTarget:
    iOS: "18.0"
    macOS: "15.0"
settings:
  SWIFT_VERSION: "6.0"
targets:
  PhotoKeepSafe (iOS):
    type: application
    platform: iOS
    sources:
      - PhotoKeepSafe/Shared
      - PhotoKeepSafe/iOS
    settings:
      PRODUCT_BUNDLE_IDENTIFIER: com.photokeepsafe.app
      INFOPLIST_KEY_UIApplicationSceneManifest_Generation: YES
      INFOPLIST_KEY_UILaunchScreen_Generation: YES
  PhotoKeepSafe (macOS):
    type: application
    platform: macOS
    sources:
      - PhotoKeepSafe/Shared
      - PhotoKeepSafe/macOS
    settings:
      PRODUCT_BUNDLE_IDENTIFIER: com.photokeepsafe.app
      ENABLE_HARDENED_RUNTIME: YES
  PhotoKeepSafeTests (iOS):
    type: bundle.unit-test
    platform: iOS
    sources:
      - PhotoKeepSafeTests
    dependencies:
      - target: PhotoKeepSafe (iOS)
  PhotoKeepSafeTests (macOS):
    type: bundle.unit-test
    platform: macOS
    sources:
      - PhotoKeepSafeTests
    dependencies:
      - target: PhotoKeepSafe (macOS)
  PhotoKeepSafeUITests (iOS):
    type: bundle.ui-testing
    platform: iOS
    sources:
      - PhotoKeepSafeUITests
    dependencies:
      - target: PhotoKeepSafe (iOS)
  PhotoKeepSafeUITests (macOS):
    type: bundle.ui-testing
    platform: macOS
    sources:
      - PhotoKeepSafeUITests
    dependencies:
      - target: PhotoKeepSafe (macOS)
```

## Next Steps

Once your project is set up:

1. Review the starter code in `PhotoKeepSafeApp.swift` and `ContentView.swift`
2. Start building your features
3. Run tests regularly with Cmd+U
4. Commit your changes to git

Happy coding!
