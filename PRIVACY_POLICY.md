# Privacy Policy for Lucent Photo Vault

**Last Updated: November 24, 2024**

## Our Commitment to Your Privacy

Lucent is built with privacy as its foundation. We believe your photos should remain yours—encrypted, secure, and completely under your control. This privacy policy explains exactly what data Lucent collects, how it's stored, and what we do (and don't do) with your information.

## Data Collection

### What We Collect

Lucent collects and stores the following data **locally on your device only**:

1. **Photos You Import**: The photos you choose to secure within Lucent
2. **Photo Metadata**: Basic information embedded in your photos, including:
   - Original filename
   - File size
   - Date photo was taken (EXIF data)
   - Camera make and model (EXIF data)
   - Location data (GPS coordinates from EXIF data, if present)
   - Image dimensions
   - Date added to Lucent
   - Albums you've organized photos into

### What We DON'T Collect

- **No User Accounts**: Lucent does not require registration, login, or any personal information
- **No Analytics**: We do not track how you use the app
- **No Usage Data**: We don't know how many photos you store, which features you use, or when you use the app
- **No Device Information**: We don't collect device identifiers, IP addresses, or system information
- **No Contacts or Communications**: We never access your contacts, messages, or other apps

## How Your Data is Stored

### Local Storage Only

All your data is stored exclusively on your device:

- Photos are encrypted using industry-standard **AES-256 encryption** via Apple's CryptoKit framework
- Encrypted photos are stored in your device's local file system
- Photo metadata is stored locally and cannot be accessed without your device
- **No cloud storage**: Your photos never leave your device
- **No remote servers**: Lucent does not connect to any servers or online services

### Encryption Details

- All photos are encrypted immediately upon import
- Encryption keys are stored securely in your device's keychain
- Decryption only occurs temporarily when you:
  - View a photo
  - Export a photo to your device's photo library
  - Share a photo using the system share sheet
- Decrypted data is automatically wiped from device memory after use

## Permissions

### Photo Library Access (Write-Only)

Lucent requests permission to **add photos to your device's photo library** for the following purpose only:

- **Exporting Photos**: When you choose to export photos from Lucent back to your device's photo library

**Important**: Lucent requests **write-only** (addOnly) permission, meaning:
- Lucent can save photos TO your library when you export
- Lucent CANNOT read or access photos already in your library
- Lucent CANNOT delete or modify photos in your library

This permission is optional and only required if you want to export photos.

## Data Sharing and Third Parties

### No Third-Party Services

Lucent does not integrate with or share data with any third-party services:

- ❌ No analytics services (Google Analytics, Firebase, etc.)
- ❌ No advertising networks
- ❌ No crash reporting services
- ❌ No cloud storage providers
- ❌ No social media integrations
- ❌ No tracking or marketing services

### No Network Requests

Lucent **makes zero network requests**. The app functions completely offline and never:
- Connects to the internet
- Sends data to external servers
- Checks for updates remotely
- Communicates with any external services

### User-Initiated Sharing Only

The only way data leaves Lucent is when **you explicitly choose** to:
1. **Export photos** to your device's photo library
2. **Share photos** using the system share sheet (Messages, AirDrop, Mail, etc.)

When you share or export photos:
- Photos are temporarily decrypted in device memory
- You control where photos are shared using Apple's system share sheet
- Decrypted data is immediately wiped from memory after sharing/exporting
- Lucent does not store or track what you share or where you share it

## Data Security

### Encryption

- **Algorithm**: AES-256-GCM (Advanced Encryption Standard with Galois/Counter Mode)
- **Key Management**: Encryption keys stored in Apple's Secure Enclave via Keychain
- **Implementation**: Apple's CryptoKit framework (platform security best practices)

### Secure Deletion

When you delete photos from Lucent:
- Encrypted files are securely overwritten multiple times
- Files are then permanently deleted from storage
- Cached thumbnails are removed
- Metadata is erased
- **Note**: This does not affect copies you've exported or shared outside of Lucent

### Memory Protection

- Decrypted photo data exists in memory only during viewing, export, or sharing
- Secure memory buffers with automatic wiping
- No decrypted data persists in RAM after use
- No temporary files created on disk

## Your Rights and Control

### Complete Data Control

You have complete control over your data:

- **View**: Access all your stored photos and metadata at any time
- **Export**: Export photos back to your device's photo library whenever you want
- **Delete**: Permanently delete individual photos or all photos
- **No Lock-In**: Your data is stored locally—you can delete the app and all data at any time

### Data Deletion

To delete your data:
1. **Delete Individual Photos**: Use the delete function within the app for specific photos
2. **Delete All Data**: Uninstall the app from your device—this removes all encrypted photos, metadata, and encryption keys

**Note**: Once you delete the app or delete photos, your data is permanently gone and cannot be recovered. Make sure to export any photos you want to keep before deletion.

## Children's Privacy

Lucent does not collect any personal information from anyone, including children under 13. Since the app stores all data locally on the device and makes no network requests, there is no data collection or transmission that would fall under COPPA (Children's Online Privacy Protection Act) requirements.

## Changes to This Policy

Since Lucent does not collect any user data or make network requests, this privacy policy is unlikely to change substantially. However, if we make significant changes to how the app works that affect privacy:

- We will update this policy
- The "Last Updated" date will be changed
- Material changes will be noted in app update release notes

## International Users

Lucent works the same way regardless of where you are located:
- All data stored locally on your device
- No data crosses international borders
- No servers in any jurisdiction
- GDPR, CCPA, and other privacy regulations compliance through zero data collection

## Technical Transparency

### Open Questions About Our App?

We believe in transparency. Here's what's technically happening:

- **Data at Rest**: All photos encrypted with AES-256-GCM on device storage
- **Data in Transit**: No data in transit—app never connects to internet
- **Data in Use**: Photos temporarily decrypted in secure memory buffers during viewing
- **Access Control**: Device passcode/biometric authentication protects device access
- **No Backdoors**: No remote access, no hidden features, no way for us to access your data

## Contact Us

If you have questions about this privacy policy or how Lucent works, you can:

- **Report Issues**: Open an issue on our GitHub repository (if applicable)
- **Email**: [Insert contact email here]

Please note: Since we don't collect any user data, we cannot retrieve, modify, or delete data on your behalf. All data management must be done within the app on your device.

---

## Summary (TL;DR)

**What Lucent Does:**
- ✅ Encrypts your photos locally with AES-256
- ✅ Stores everything on your device only
- ✅ Keeps your photos completely private and secure

**What Lucent Doesn't Do:**
- ❌ No user accounts or authentication
- ❌ No cloud storage or syncing
- ❌ No analytics or tracking
- ❌ No third-party services
- ❌ No network requests
- ❌ No data collection beyond your photos

**Your Control:**
- You decide what photos to import
- You decide when to export or share
- You decide when to delete
- We never see your photos or data

**Bottom Line**: Lucent is a truly private photo vault. Your photos stay on your device, encrypted and secure. We can't access them, we don't track you, and we don't collect any data. Your privacy is absolute.

---

*This privacy policy applies to Lucent Photo Vault for iOS and macOS.*
