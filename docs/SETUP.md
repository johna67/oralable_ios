# Setup Guide - Oralable iOS

This guide will help you set up the Oralable iOS project for development, testing, and deployment.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Initial Setup](#initial-setup)
- [Configuration](#configuration)
- [Building](#building)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)

## Prerequisites

### Required Software

1. **macOS**: 13.0 (Ventura) or later
2. **Xcode**: 15.0 or later
   - Download from [Mac App Store](https://apps.apple.com/us/app/xcode/id497799835)
   - Or download from [Apple Developer](https://developer.apple.com/xcode/)

3. **iOS Device** (for BLE testing)
   - iOS 15.0 or later
   - Physical device required (simulator can't access Bluetooth)

4. **Git**: For version control
   ```bash
   # Check if git is installed
   git --version

   # Install via Homebrew if needed
   brew install git
   ```

### Required Accounts

1. **Apple Developer Account**
   - Free account: Limited to 3 devices, 7-day certificates
   - Paid account ($99/year): Full capabilities, TestFlight, App Store

2. **App Store Connect** (for subscriptions)
   - Required for StoreKit testing
   - Set up in-app purchase products

## Initial Setup

### 1. Clone the Repository

```bash
# Clone via HTTPS
git clone https://github.com/johna67/oralable_ios.git

# Or clone via SSH
git clone git@github.com:johna67/oralable_ios.git

# Navigate to project directory
cd oralable_ios
```

### 2. Open in Xcode

```bash
open OralableApp/OralableApp.xcodeproj
```

### 3. Select Development Team

1. Open the project navigator (⌘+1)
2. Select the **OralableApp** project
3. Select the **OralableApp** target
4. Go to **Signing & Capabilities** tab
5. Under **Signing**, select your **Team**

### 4. Update Bundle Identifier (if needed)

If you get signing errors:

1. Change **Bundle Identifier** to something unique:
   ```
   com.yourcompany.oralable
   ```
2. Update in **all targets**:
   - OralableApp
   - OralableAppTests
   - OralableAppUITests

## Configuration

### App Capabilities

The following capabilities are required and should already be configured:

#### 1. HealthKit

- ✅ Already enabled in `OralableApp.entitlements`
- Required for reading/writing health data

**Permissions in Info.plist**:
```xml
<key>NSHealthShareUsageDescription</key>
<string>We need access to read your health data for comprehensive analysis.</string>
<key>NSHealthUpdateUsageDescription</key>
<string>We need access to write health data to your Health app.</string>
```

#### 2. Sign in with Apple

- ✅ Already enabled
- Required for user authentication

#### 3. iCloud

- ✅ CloudKit enabled
- Container: `iCloud.jacdentalsolutions.OralableApp`

**To use your own container**:
1. Go to Signing & Capabilities
2. Under iCloud, change the container identifier
3. Update in code if hardcoded anywhere

#### 4. Background Modes

- ✅ Bluetooth LE accessories enabled
- Allows BLE communication in background

### StoreKit Configuration

#### Option 1: Use Existing Configuration (Recommended for Testing)

The project is configured with these product IDs:
- Monthly: `com.oralable.mam.subscription.monthly`
- Yearly: `com.oralable.mam.subscription.yearly`
- Lifetime: `com.oralable.mam.lifetime`

For testing in simulator/device without App Store Connect:

1. **Create StoreKit Configuration File**:
   - File > New > File...
   - iOS > Resource > StoreKit Configuration File
   - Name it `Products.storekit`

2. **Add Products**:
   ```
   + Add Subscription Group: "Premium Subscriptions"
     + Add Subscription: "monthly"
       - Product ID: com.oralable.mam.subscription.monthly
       - Reference Name: Monthly Subscription
       - Price: $9.99
       - Duration: 1 Month

     + Add Subscription: "yearly"
       - Product ID: com.oralable.mam.subscription.yearly
       - Reference Name: Yearly Subscription
       - Price: $99.99 (or your preferred price)
       - Duration: 1 Year

   + Add Non-Consumable: "lifetime"
     - Product ID: com.oralable.mam.lifetime
     - Reference Name: Lifetime Access
     - Price: $299.99
   ```

3. **Enable StoreKit Configuration**:
   - Select scheme in Xcode toolbar
   - Edit Scheme > Run > Options
   - StoreKit Configuration: Select `Products.storekit`

#### Option 2: Configure Your Own Products

1. **Update Product IDs** in `SubscriptionManager.swift`:
   ```swift
   private enum ProductIdentifier {
       static let monthlySubscription = "your.product.id.monthly"
       static let yearlySubscription = "your.product.id.yearly"
       static let lifetimePurchase = "your.product.id.lifetime"
   }
   ```

2. **Create products in App Store Connect**
3. **Update StoreKit configuration file** to match

### Environment Configuration

#### Development
- Uses local data storage
- Debug mode enabled
- Subscription simulator available

#### Production
- iCloud sync enabled
- Real StoreKit products
- Analytics enabled (if configured)

## Building

### Build for Simulator

```bash
# List available simulators
xcrun simctl list devices

# Build for specific simulator
xcodebuild \
  -project OralableApp/OralableApp.xcodeproj \
  -scheme OralableApp \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  clean build
```

### Build for Device

```bash
# Build for device (replace with your device ID)
xcodebuild \
  -project OralableApp/OralableApp.xcodeproj \
  -scheme OralableApp \
  -destination 'platform=iOS,id=YOUR_DEVICE_ID' \
  clean build
```

### Build Configurations

- **Debug**: Development builds with debugging symbols
- **Release**: Optimized builds for App Store

To build Release:
```bash
xcodebuild \
  -project OralableApp/OralableApp.xcodeproj \
  -scheme OralableApp \
  -configuration Release \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  clean build
```

## Testing

### Running Unit Tests

```bash
# Run all tests
xcodebuild test \
  -project OralableApp/OralableApp.xcodeproj \
  -scheme OralableApp \
  -destination 'platform=iOS Simulator,name=iPhone 15'

# Run specific test class
xcodebuild test \
  -project OralableApp/OralableApp.xcodeproj \
  -scheme OralableApp \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:OralableAppTests/DashboardViewModelTests

# Run specific test method
xcodebuild test \
  -project OralableApp/OralableApp.xcodeproj \
  -scheme OralableApp \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:OralableAppTests/DashboardViewModelTests/testInitialState
```

### Running in Xcode

1. Open test navigator (⌘+6)
2. Click play button next to test class or method
3. Or press ⌘+U to run all tests

### Test Coverage

Generate test coverage report:

1. Edit Scheme > Test > Options
2. Enable "Code Coverage"
3. After running tests: Report Navigator (⌘+9) > Coverage

### BLE Testing

**Important**: BLE testing requires a physical device.

1. Connect iOS device via USB or WiFi
2. Trust computer on device
3. Select device as destination in Xcode
4. Run app (⌘+R)
5. Enable Bluetooth on device
6. Pair with BLE device

## Troubleshooting

### Common Issues

#### 1. Signing Errors

**Problem**: "Failed to code sign OralableApp"

**Solutions**:
- Select correct development team
- Update bundle identifier to unique value
- Check certificates in Xcode Preferences > Accounts

#### 2. HealthKit Errors

**Problem**: "HealthKit not available on simulator"

**Solution**: HealthKit requires physical device for full testing

#### 3. StoreKit Errors

**Problem**: "No products available"

**Solutions**:
- Ensure StoreKit configuration file is set in scheme
- Check product IDs match
- Wait a few minutes after creating products
- Check internet connection

#### 4. iCloud Errors

**Problem**: "CloudKit container not found"

**Solutions**:
- Create container in Certificates, Identifiers & Profiles
- Update container identifier in capabilities
- Sign in to iCloud on device/simulator

#### 5. Build Errors

**Problem**: "Build failed" or "Cannot find type"

**Solutions**:
```bash
# Clean build folder
⌘+Shift+K (or Product > Clean Build Folder)

# Delete derived data
rm -rf ~/Library/Developer/Xcode/DerivedData

# Reset package caches (if using SPM)
File > Packages > Reset Package Caches
```

#### 6. BLE Connection Issues

**Problem**: Can't discover or connect to device

**Solutions**:
- Ensure Bluetooth is enabled on iOS device
- Check device is powered on and in pairing mode
- Reset Bluetooth settings
- Check BLE permissions in Settings > Oralable
- Try restarting both devices

### Getting Help

1. Check [GitHub Issues](https://github.com/johna67/oralable_ios/issues)
2. Review [PPG Debugging Guide](../OralableApp/OralableApp/PPG_DEBUGGING_GUIDE.md)
3. Join discussions on [GitHub Discussions](https://github.com/johna67/oralable_ios/discussions)

## Next Steps

After setup is complete:

1. Read [ARCHITECTURE.md](ARCHITECTURE.md) to understand the codebase
2. Review [CONTRIBUTING.md](CONTRIBUTING.md) for development guidelines
3. Check [PPG_DEBUGGING_GUIDE.md](../OralableApp/OralableApp/PPG_DEBUGGING_GUIDE.md) for device-specific debugging

## Additional Resources

- [Apple Developer Documentation](https://developer.apple.com/documentation/)
- [SwiftUI Tutorials](https://developer.apple.com/tutorials/swiftui)
- [Combine Framework](https://developer.apple.com/documentation/combine)
- [StoreKit Documentation](https://developer.apple.com/documentation/storekit)
- [HealthKit Documentation](https://developer.apple.com/documentation/healthkit)

---

**Last Updated**: November 11, 2025
